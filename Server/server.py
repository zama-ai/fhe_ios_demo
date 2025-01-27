"""Deployment server.

We use Celery for asynchronous processing (polling approach).

Routes:
    - /add_key
    - /get_use_cases
    - /start_task  
    - /get_task_status
    - /get_task_result
    - /cancel_task
"""
import re

import base64
import datetime
import io
import logging
import os
import subprocess
import time
import uuid
from contextlib import contextmanager
from glob import glob
from pathlib import Path
from pprint import pformat
from typing import Dict, List

import uvicorn
import yaml
from celery import Celery
from celery.result import AsyncResult
from dotenv import load_dotenv
from fastapi import (
    Depends,
    FastAPI,
    Form,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
)
from fastapi.responses import JSONResponse, StreamingResponse
import redis
import os
import json
from urllib.parse import urlparse

# Load environment variables from '.env' file
load_dotenv(dotenv_path="./.env")

# Configure logging
LOG_FILE = Path(__file__).parent / "server.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(),  # Also log to stderr for Docker logs
    ],
)
logger = logging.getLogger(__name__)

# Environment variables
PORT = os.getenv("CONTAINER_PORT")
BROKER_URL = os.getenv("CELERY_BROKER_URL")
BACKEND_URL = os.getenv("CELERY_RESULT_BACKEND")

REDIS_URL = os.getenv("CELERY_BROKER_URL")
PARSED_URL = urlparse(REDIS_URL)

CERTS_PATH = os.getenv("CONTAINER_CERTS_PATH")
CERT = os.getenv("CERT_FILE_NAME")
PRIVKEY = os.getenv("PRIVKEY_FILE_NAME")

SHARED_DIR = os.getenv("SHARED_DIR")
FILES_FOLDER = Path(__file__).parent / SHARED_DIR
FILES_FOLDER.mkdir(exist_ok=True)

BACKUP_DIR = os.getenv("BACKUP_DIR")
BACKUP_FOLDER = Path(__file__).parent / BACKUP_DIR
BACKUP_FOLDER.mkdir(exist_ok=True)

# Instanciate FastAPI app
app = FastAPI(debug=False)

# Load task configuration
CONFIG_FILE = Path(__file__).parent / "tasks.yaml"
try:
    with open(CONFIG_FILE, "r", encoding="utf-8") as file:
        config = yaml.safe_load(file)
        tasks = config.get("tasks", {})
    logger.info("Loaded task configuration from 'tasks.yaml'")
except Exception as e:
    logger.error("Failed to load configuration file: `%s`", e)
    raise e

# Instanciate Celery app
try:
    celery_app = Celery(
        "tasks",
        broker=BROKER_URL,
        backend=BACKEND_URL,
        broker_connection_retry_on_startup=True,
    )

    celery_app.conf.update(
        timezone="Europe/Paris",
        enable_utc=True,
        task_track_started=True,  # This will enable the STARTED status
        result_expires=60 * 60 * 24 * 30,  # One-month history
        task_acks_late=True,  # Redispatch unfinished tasks
        task_acks_on_failure_or_timeout=False,  # Avoid marking a task as “acknowledged” if it crashes
        broker_transport_options={"visibility_timeout": 60 * 1},  # X seconds before the  before an abandoned task becomes available again
        worker_prefetch_multiplier=1,  # How many tasks a Celery worker will prefetch before starting execution
    )

except Exception as e:
    celery_app = None
    logger.error(f"❌ Failed to initialize Celery app: {e}")
    raise RuntimeError("Celery initialization failed") from e


# Instanciate Redis data-base
try:
    redis_bd = redis.Redis(
        host=PARSED_URL.hostname,
        port=PARSED_URL.port,
        db=int(PARSED_URL.path.lstrip('/')),
        decode_responses=True,
    )
    redis_bd.ping()
    logger.info("Connected to Redis successfully!")

except redis.ConnectionError:
    redis_bd = None
    logger.error("❌ Failed to connect to Redis!")


async def get_task_id(request: Request, task_id: str = Query(None), task_id_form: str = Form(None)):
    """Retieve the `task_id` from Query, Form, or Request Body."""
    form_data = await request.form()
    return task_id or task_id_form or form_data.get("task_id")


async def get_task_name(
    request: Request, task_name: str = Query(None), task_name_form: str = Form(None)
):
    """Retieve the `task_name` from Query, Form, or Request Body."""
    form_data = await request.form()
    return task_name or task_name_form or form_data.get("task_name")


async def get_uid(request: Request, uid: str = Query(None), uid_form: str = Form(None)):
    """Retrieve the `uid` from Query, Form, or Request Body."""
    form_data = await request.form()
    return uid or uid_form or form_data.get("uid")


class TaskLogger:
    def __init__(self, logger):
        self._logger = logger
        self._task_name = None

    @contextmanager
    def task_context(self, task_name):
        old_task_name = self._task_name
        self._task_name = task_name
        try:
            yield self
        finally:
            self._task_name = old_task_name

    def _log(self, level, msg, *args, **kwargs):
        if self._task_name:
            msg = f"[{self._task_name}] {msg}"
        return getattr(self._logger, level)(msg, *args, **kwargs)

    def info(self, msg, *args, **kwargs):
        return self._log("info", msg, *args, **kwargs)

    def error(self, msg, *args, **kwargs):
        return self._log("error", msg, *args, **kwargs)

    def warning(self, msg, *args, **kwargs):
        return self._log("warning", msg, *args, **kwargs)

    def debug(self, msg, *args, **kwargs):
        return self._log("debug", msg, *args, **kwargs)


# Replace the existing logger with our wrapped version
task_logger = TaskLogger(logger)


def generate_filename(config, file_type, args) -> str:
    """Generates a filename based on a given configuration.

    Args:
        config (dict): Configuration dictionary containing filename templates.
        file_type (str): Type of file, either "output" or "input".
        args (dict): Dictionary with formatting arguments (e.g., uid, task_name).

    Returns:
        str: The generated filename based on the template.
    """
    assert file_type in ["input", "output"], f"`{file_type}` not supported."
    template = "{uid}" if file_type == "output" else "{uid}.{task_name}"
    filename_template = config.get("filename", f"{template}.{file_type}.fheencrypted")
    return filename_template.format(**args)


def ensure_file_exists(file_path, error_message) -> None:
    """Ensures that the specified file exists; otherwise, logs an error and raises an exception.

    Args:
        file_path (Path): The path of the file to check.
        error_message (str): The error message to log and include in the exception.

    Raises:
        HTTPException: Raised with status code 500 if the file does not exist.
    """
    if not file_path.exists():
        task_logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)
    else:
        task_logger.debug(f"Output file path: `{file_path}` exists.")


def fetch_file_content(output_file_path: Path, task_id: str, backup: bool):
    """Reads a file, optionally saves a backup, and returns its content.

    Args:
        output_file_path (Path): The path of the file to read.
        task_id (str): The task id used for backup naming.
        backup (bool): Whether to save a backup of the file.

    Returns:
        bytes: The content of the file.

    Raises:
        HTTPException: Raised with status code 500 if the file cannot be read.
    """
    ensure_file_exists(
        output_file_path, error_message=f"Output file `{output_file_path.name}` not found."
    )
    try:
        data = output_file_path.read_bytes()
        task_logger.info(
            f"Processed output file `{output_file_path}` to client (Size: `{len(data)}` bytes)"
        )
    except Exception as e:
        task_logger.error(f"Error reading output file `{output_file_path.name}`: `{e}`")
        raise HTTPException(
            status_code=500, detail=f"Failed to read output file `{output_file_path.name}`."
        ) from e

    if backup:
        backup_path = BACKUP_FOLDER / f"backup.{task_id}.{output_file_path.name}"
        try:
            backup_path.write_bytes(data)
            task_logger.debug(f"Backup saved at `{backup_path}`")
        except Exception as e:
            task_logger.warning(f"Failed to create backup `{backup_path}`: {e}")

    return data


@app.post("/add_key")
async def add_key(key: UploadFile = Form(...), task_name=Depends(get_task_name)) -> Dict:
    """Save the evaluation key on the server side.

    Args:
        key (UploadFile): The evaluation key
        task_name (str): The name of the task

    Returns:
        Dict[str, str]
            - uid: a unique identifier
    """
    logger.info("******* Endpoint/add_key *******")

    uid = str(uuid.uuid4())
    logger.info("Received new key upload. Assigned UID: `%s`", uid)

    # Write uploaded ServerKey to disk
    try:
        file_content = await key.read()
        file_path = FILES_FOLDER / f"{uid}.{task_name}.serverKey"
        with open(file_path, "wb") as f:
            f.write(file_content)
        file_size = file_path.stat().st_size  # Get file size in bytes
        logger.info("Saved server key to `%s` (Size: `%s` bytes)", file_path, file_size)

    except Exception as e:
        task_logger.error("Error saving server key: `%s`", e)
        raise HTTPException(status_code=500, detail="Failed to save server key.") from e

    return {"uid": uid}


@app.get("/get_use_cases")
def get_use_cases() -> Dict:
    """List available use-cases based on configuration.

    Returns:
        Dict[str, List[str]]: Available use-case names
    """
    logger.info("******* Endpoint/get_use_cases *******")
    available_use_cases = list(tasks.keys())
    logger.info("Fetching list of available use-cases: %s", available_use_cases)
    return {"Use-cases": available_use_cases}


@celery_app.task(name="tasks.run_binary_task")
def run_binary_task(binary: str, uid: str, task_name: str) -> Dict:
    """Executes a binary command as a Celery task.

    Args:
        binary (str): The name of the executable binary to run.
        uid (str): The unique key identifier.
        task_name (str): The name of the task to execute.

    Returns:
        Dict: A dictionary containing the command's stdout, stderr, and the returned code.

    Raises:
        subprocess.CalledProcessError: Raised if the binary execution fails.
    """
    logger.info("******* run_binary_task *******")

    commandline = [f"./{binary}", uid]

    try:
        # Result is a subprocess.CompletedProcess object, and Celery can't store that in Redis.
        start_time = time.time()
        result = subprocess.run(commandline, capture_output=True, check=True, text=True)
        execution_time = time.time() - start_time

        task_logger.info(f"Task: `{task_name}` completed in {execution_time:.2f}s")

        if result.stderr:
            task_logger.error(f"Error from `{binary}`:\n`{result.stderr}`")

    except subprocess.CalledProcessError as e:
        error_message = f"Error executing {binary}: {e.stderr}"
        task_logger.error(error_message)
        return {"status": "error", "detail": error_message}

    # Celry cannot serialize a <class 'subprocess.CompletedProcess'> object in JSON
    return {"stdout": result.stdout, "stderr": result.stderr, "returncode": result.returncode}


@app.post("/start_task")
async def start_task(
    uid: str = Form(...), task_name: str = Form(...), encrypted_input: UploadFile = Form(...)
) -> JSONResponse:
    """Starts a Celery task by processing an encrypted input file.

    Args:
        uid (str): The unique key identifier.
        task_name (str): The name of the task to be executed.
        encrypted_input (UploadFile): The encrypted input file.

    Returns:
        JSONResponse: A JSON object containing the `task_id` if the task starts successfully.

    Raises:
        HTTPException: Raised with status code 400 if the `task_name` is invalid.
        HTTPException: Raised with status code 500 if saving the file or starting the task fails.
    """
    logger.info("******* Endpoint/start_task *******")

    if task_name not in tasks:
        task_logger.error("Invalid task name: `%s`", task_name)
        raise HTTPException(status_code=400, detail=f"Task `{task_name}` does not exist.")

    binary = tasks[task_name]["binary"]

    # Use input_filename from task_config if specified, otherwise default
    input_filename = generate_filename(
        config=tasks[task_name], file_type="input", args={"uid": uid, "task_name": task_name}
    )
    input_file_path = FILES_FOLDER / input_filename
    task_logger.debug(f"Input file path: {input_file_path}")

    try:
        file_content = await encrypted_input.read()
        with open(input_file_path, "wb") as f:
            f.write(file_content)
        file_size = input_file_path.stat().st_size  # Get file size in bytes
        task_logger.info(
            f"Saved encrypted input file to `{input_file_path} `(Size: `{file_size}` bytes)"
        )

    except Exception as e:
        task_logger.error(f"Error saving input file: {e}")
        raise HTTPException(status_code=500, detail="Failed to save input file.") from e

    # Start the Celery task
    try:
        task_logger.info(f"Executing task: `{task_name}` with UID `{uid}`")
        # The .delay() function is a shortcut for .apply_async(), which sends the task to the queue.
        # The args you pass to .delay() are the arguments that will be used to execute the task.
        task = run_binary_task.delay(binary, uid, task_name)
        logger.info("Task: `%s` started successfully. TASK_ID: `%s`", task_name, task.id)

        return JSONResponse({"task_id": task.id})

    except Exception as e:
        task_logger.error(f"Failed to start task `{task_name}`: {e}")
        raise HTTPException(status_code=500, detail="Failed to start the task.") from e


@app.get("/list_current_tasks")
def list_current_tasks() -> List[Dict]:
    """Lists all Celery tasks, including pending ones in the queue.

    For workers, tasks may be active, reserved (queued), or scheduled (waiting for execution).
    If the worker is full, the tasks are queued in Radis and wait to be pickup.

    Returns:
        List[Dict]: A list of dictionaries containing task details (task_id, status, worker).
    """
    logger.info("******* Endpoint /list_current_tasks *******")

    inspector = celery_app.control.inspect()

    if inspector is None:
        task_logger.error("Celery Inspector returned `None`. No workers may be available.")
        return []

    task_states = {
        # Show the tasks that are currently active
        "active": inspector.active() or {},
        # Show the tasks that have been claimed by `workers`
        "reserved": inspector.reserved() or {},
        # Show tasks that have an ETA or are scheduled for later processing
        "scheduled": inspector.scheduled() or {},
    }
    all_tasks = []

    for state, tasks_data in task_states.items():
        for worker_name, tasks_list in tasks_data.items():
            for t in tasks_list:
                task_info = {
                    "task_id": t.get("id"),
                    "status": state,
                    "worker": worker_name,
                    # "name": t.get("name"),
                    # "args": t.get("args"),
                }
                if state == "scheduled":
                    request_info = t.get("request", {})
                    task_info.update(
                        {
                            "task_id": request_info.get("id"),
                            # "name": request_info.get("name"),
                            # "args": request_info.get("args"),
                        }
                    )
                all_tasks.append(task_info)

    #  Retrieving pending tasks from the Redis queue
    try:
        pending_tasks = redis_bd.lrange("celery", 0, -1)
        for task in pending_tasks:
            task_data = json.loads(task)
            task_info = {
                "task_id": task_data["headers"]["id"],
                "status": "queued",
                "worker": "queue",
                "details": "The task is currently in the Redis queue, waiting to be picked up by a worker."
            }
            all_tasks.append(task_info)
    except Exception as e:
        error_message =  f"Error retrieving pending tasks from REDIS: {e}"
        logger.error(error_message)

    logger.info("All tasks:\n%s", pformat(all_tasks))

    return all_tasks


@app.get("/get_task_status")
def get_task_status(task_id: str = Depends(get_task_id)) -> Dict:
    """Retrieves the status of a Celery task by its task ID.

    If no `task_id` is provided, returns an "unknown" status with details.

    Args:
        task_id (str): The ID of the task to check.

    Returns:
        Dict: A dictionary containing the task ID, status, and additional details.

    Raises:
        HTTPException: Raised if an unexpected error occurs while retrieving the task status.
    """

    logger.info("******* Endpoint/get_task_status *******")

    # Validate input: If no task_id is provided, return a list of all current tasks
    if not task_id or task_id.strip() == "":
        logger.info("No `task_id` provided. Please retry with a valid task ID.")
        logger.debug("All current tasks: %s", list_current_tasks())
        return {
            "task_id": "none",
            "status": "unknown",
            "details": "Task id is None or Empty.",
        }

    result = AsyncResult(task_id, app=celery_app)
    status = result.state.lower()

    # Mapping Celery task states to structured responses
    status_mapping = {
        "started": {
            "task_id": task_id,
            "status": "started",
            "details": "Task is still in progress.",
        },
        "success": {
            "task_id": task_id,
            "status": "success",
            "details": "Task successfully completed.",
        },
        "failure": {
            "task_id": task_id,
            "status": "failure",
            "details": str(result.info or "This task might be lost."),
        },
    }

    # If the task is "PENDING" but a saved output file exists, treat it as "completed"
    if status == "pending":
        file_pattern = f"{BACKUP_FOLDER}/backup.{task_id}.*.*.output.fheencrypted"
        matching_files = glob(file_pattern)

        if matching_files:
            file_path = Path(matching_files[0])
            file_date = file_path.stat().st_mtime  # Get file's last modified time
            date = datetime.datetime.fromtimestamp(file_date).strftime("%Y-%m-%d %H:%M:%S")

            response = {
                "task_id": task_id,
                "status": "completed",
                "details": f"Task completed on `{date}`. The result is stored.",
                "output_file_path": [str(file_path)],
            }
        else:
            try:
                queued_tasks = redis_bd.lrange("celery", 0, -1)
                queued_tasks_text = " ".join(queued_tasks)

                if re.search(rf'"id"\s*:\s*"{re.escape(task_id)}"', queued_tasks_text):
                    response = {
                        "task_id": task_id,
                        "status": "queued",
                        "details": "Task is in Redis queue, waiting for a worker to pick it up.",
                    }
                else:
                    response = {
                        "task_id": task_id,
                        "status": "unknown",
                        "details": "Unknown status: task may not exist. You may need to restart it.",
                    }
            except Exception as e:
                logger.error("Error checking Redis queue: %s", str(e))
                response = {
                    "task_id": task_id,
                    "status": "unknown",
                    "details": "Could not check Redis queue due to an error.",
                }
    else:
        # Return the corresponding status from the mapping
        response = status_mapping.get(
            status,
            {
                "task_id": task_id,
                "status": status,
                "details": str(result.info or "No additional details available."),
            },
        )

    logger.info(
        "Task ID: `%s` - status: `%s` - details: `%s`",
        response["task_id"],
        response["status"],
        response["details"],
    )

    return response


@app.post("/cancel_task")
def cancel_task(task_id: str = Depends(get_task_id)) -> Dict:
    """Attempts to cancel a running task by ID, if possible.

    Args:
        task_id (str): The ID of the task to cancel.

    Returns:
        Dict: A dictionary containing the task ID, its status, and details about the cancellation.

    Raises:
        HTTPException: Raised with status code 500 if revoking the task fails.
    """
    logger.info("******* Endpoint/cancel_task *******")
    logger.info("Cancel request received for TASK_ID: `%s`", task_id)

    # Get the current task status
    current_overall_status = get_task_status(task_id)
    current_status = current_overall_status.get("status", "unknown").lower()

    logger.info("Current status of TASK_ID `%s`: `%s`.", task_id, current_status)

    # Tasks that cannot be canceled
    non_cancellable_statuses = {
        "success",
        "completed",
        "failure",
        "revoked",
        "pending",
        "unknown",
        "error",
    }

    if current_status in non_cancellable_statuses:
        task_logger.warning("Cannot cancel TASK_ID `%s` (already finished or unknown).", task_id)
        return {
            "task_id": task_id,
            "status": current_status,
            "details": f"Cannot cancel this task (already finished or unknown). Additional info: {current_overall_status.get('details', '')}",
        }

    # Attempt to revoke the task
    try:
        celery_app.control.revoke(task_id, terminate=True, signal="SIGKILL")
        logger.info("TASK_ID `%s` revocation initiated.", task_id)
    except Exception as e:
        task_logger.error("Failed to revoke TASK_ID `%s`: %s.", task_id, str(e))
        raise HTTPException(status_code=500, detail=f"Error while revoking task: {str(e)}")

    # Wait for the state to update
    time.sleep(2)

    # Fetch the new state of the task
    new_result = AsyncResult(task_id, app=celery_app)
    new_status = new_result.state.lower()
    logger.info("New status of TASK_ID `%s`: %s.", task_id, new_status)

    return {
        "task_id": task_id,
        "status": new_status,
        "details": "Task revocation requested successfully.",
    }


@app.get("/get_task_result")
async def get_task_result(
    task_name: str = Depends(get_task_name),
    task_id: str = Depends(get_task_id),
    uid: str = Depends(get_uid),
):
    """Retrieves the final result of a completed task, returning it based on configuration.

    Args:
        task_name (str): The name of the task/
        task_id (str): The ID of the task to retrieve the result for.
        uid (str): The unique key identifier.

    Returns:
        StreamingResponse: If `response_type` is set to "stream".
        JSONResponse: If `response_type` is set to "json".

    Raises:
        HTTPException: Raised with a 400 status code if the task name is invalid.
        HTTPException: Raised with a 500 status code for unsupported response types or other errors.
    """
    logger.info("******* Endpoint/get_task_result *******")
    if task_name not in tasks:
        task_logger.error("Invalid task name: `%s`", task_name)
        raise HTTPException(status_code=400, detail=f"Task `{task_name}` does not exist.")

    # Check task configuration
    task_config = tasks.get(task_name, {})
    # Defines whether the response will be in stream or JSON format
    response_type = task_config.get("response_type", "stream")
    # Output name file as specified in the yaml task file
    output_files = task_config.get("output_files", [])
    stderr_output = ""

    # Check task status
    status = get_task_status(task_id)

    logger.info(f"Task ID: `%s` with state `%s`", task_id, status["status"])

    if status.get("status") == "started":
        logger.info("Task ID: `%s` is still in progress. Status: `%s`", task_id, status)
        return JSONResponse(
            content=status,
            status_code=200,
            headers={"status": status["status"], "job_id": task_id, "stderr": stderr_output},
        )

    if status.get("status") in ["pending", "failure", "revoked", "unknown", "error", "queue"]:
        logger.info("task_id=`%s` not strarted. Status: `%s`", task_id, status)
        return JSONResponse(
            content=status,
            status_code=200,
            headers={
                "status": status["status"],
                "job_id": status["task_id"],
                "stderr": status["details"],
            },
        )

    if status.get("status") == "completed":
        logger.info("task_id=`%s` already completed", task_id)
        backup = False  # No need for a backup if already completed

    elif status.get("status") == "success":
        logger.info("task_id=`%s` successfully completed", task_id)

        celery_result = AsyncResult(task_id, app=celery_app)
        outcome_celery = celery_result.result
        stderr_output = outcome_celery.get("stderr", "")

        backup = True
    else:
        error_message = "Unknown status"
        logger.error("task_id=`%s` has an unknown status: `%s`", task_id, status)
        raise HTTPException(status_code=500, detail=error_message)


    # Handle outputs based on the configuration
    if response_type == "stream":
        # Expect a single output file
        output_filename = (
            generate_filename(output_files[0], file_type="output", args={"uid": uid})
            if backup
            else status["output_file_path"][0]
        )
        output_file_path = FILES_FOLDER / output_filename
        data = fetch_file_content(output_file_path, task_id, backup=backup)

        return StreamingResponse(
            io.BytesIO(data),
            media_type="application/octet-stream",
            headers={
                "Content-Disposition": f"attachment; filename={output_filename}",
                "status": "success",
                "job_id": task_id,
                "stderr": stderr_output,
            },
        )
    elif response_type == "json":
        response_data = {"status": "success", "job_id": task_id, "stderr": stderr_output}

        iter_files = (
            [
                generate_output_filename(output_file_config, uid)
                for output_file_config in output_files
            ]
            if backup
            else status["file_path"]
        )

        for output_filename in iter_files:
            output_file_path = FILES_FOLDER / output_filename
            key = output_file_config.get("key", output_filename)
            response_format = output_file_config.get("response_type", "base64")
            response_data[output_filename] = output_filename
            data = fetch_file_content(output_file_path, task_id)

            response_data[key] = (
                base64.b64encode(data).decode("utf-8")
                if response_format == "base64"
                else data.decode("utf-8")
            )

        task_logger.info(f"Returning JSON response for task '{task_name}'")
        return JSONResponse(content=response_data)
    else:
        error_message = f"Unsupported response type: `{response_type}`"
        task_logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)


@app.get("/logs")
def get_logs(lines: int = 10) -> Response:
    """Serve the server log file with the specified number of last lines.

    Args:
        lines (int): Number of last log lines to display (default: 10)

    Returns:
        HTML content displaying the logs.
    """
    try:
        # Read last N lines efficiently
        with open(LOG_FILE, "r", encoding="utf-8") as log_file:
            # Use deque with maxlen for memory efficiency
            from collections import deque

            last_lines = deque(maxlen=lines)
            for line in log_file:
                last_lines.append(line)
            logs = "".join(last_lines)

        # Escape HTML characters to prevent XSS
        escaped_logs = logs.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

        html = f"""
        <html>
            <head>
                <title>Server Logs</title>
                <style>
                    body {{
                        font-family: 'Courier New', monospace;
                        background-color: #f5f5f5;
                        margin: 0;
                        padding: 20px;
                    }}
                    .container {{
                        background-color: white;
                        border-radius: 8px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                        padding: 20px;
                        max-width: 1200px;
                        margin: 0 auto;
                    }}
                    h1 {{
                        color: #333;
                        border-bottom: 2px solid #eee;
                        padding-bottom: 10px;
                        margin-top: 0;
                    }}
                    .log-container {{
                        background-color: #f8f9fa;
                        border: 1px solid #eee;
                        border-radius: 4px;
                        padding: 15px;
                        overflow-x: auto;
                    }}
                    pre {{
                        margin: 0;
                        font-size: 14px;
                        line-height: 1.5;
                    }}
                    .controls {{
                        margin-bottom: 15px;
                    }}
                    select {{
                        padding: 5px;
                        border-radius: 4px;
                        border: 1px solid #ddd;
                    }}
                    .button {{
                        padding: 8px 15px;
                        border: none;
                        border-radius: 4px;
                        background-color: #007bff;
                        color: white;
                        cursor: pointer;
                        margin-left: 15px;
                    }}
                    .button:hover {{
                        background-color: #0056b3;
                    }}
                    #autoRefresh {{
                        margin-left: 15px;
                    }}
                </style>
                <script>
                    let autoRefreshInterval;

                    function toggleAutoRefresh() {{
                        const checkbox = document.getElementById('autoRefresh');
                        if (checkbox.checked) {{
                            autoRefreshInterval = setInterval(refreshLogs, 5000);
                        }} else {{
                            clearInterval(autoRefreshInterval);
                        }}
                    }}

                    function refreshLogs() {{
                        fetch(window.location.href)
                            .then(response => response.text())
                            .then(html => {{
                                const parser = new DOMParser();
                                const doc = parser.parseFromString(html, 'text/html');
                                document.querySelector('.log-container').innerHTML = 
                                    doc.querySelector('.log-container').innerHTML;
                            }});
                    }}

                    // Initialize auto-refresh on page load
                    window.onload = function() {{
                        document.getElementById('autoRefresh').checked = true;
                        toggleAutoRefresh();
                    }}
                </script>
            </head>
            <body>
                <div class="container">
                    <h1>Server Logs</h1>
                    <div class="controls">
                        <form method="get" style="display: inline-block;">
                            Show last: 
                            <select name="lines" onchange="this.form.submit()">
                                <option value="10" {"selected" if lines == 10 else ""}>10 lines</option>
                                <option value="50" {"selected" if lines == 50 else ""}>50 lines</option>
                                <option value="100" {"selected" if lines == 100 else ""}>100 lines</option>
                                <option value="500" {"selected" if lines == 500 else ""}>500 lines</option>
                            </select>
                        </form>
                        <label id="autoRefresh">
                            <input type="checkbox" onchange="toggleAutoRefresh()"> Auto-refresh
                        </label>
                    </div>
                    <div class="log-container">
                        <pre>{escaped_logs}</pre>
                    </div>
                </div>
            </body>
        </html>
        """
        return Response(content=html, media_type="text/html")
    except FileNotFoundError:
        logger.warning("Log file not found when attempting to fetch logs.")
        return Response(
            content="Log file not found. Logs might not have been generated yet.", status_code=404
        )
    except Exception as e:
        logger.error("Error serving logs: `%s`", e)
        return Response(content="An error occurred while fetching logs.", status_code=500)


@app.get("/robots.txt")
def robots():
    content = "User-agent: *\nDisallow: /"
    return Response(content=content, media_type="text/plain")

