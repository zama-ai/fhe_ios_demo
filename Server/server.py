"""Deployment server.

We use Celery for asynchronous processing (polling approach).

Routes:
    - /add_key         
    - /tasks         
    - /start_task  
    - /get_task_status
    - /get_task_result
    - /cancel_task
"""

import asyncio
import base64
import io
import logging
import os
import subprocess
import time
import uuid
from pprint import pformat

from dotenv import load_dotenv
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Dict

import uvicorn
import yaml
from fastapi import FastAPI, Form, HTTPException, UploadFile, Response, File, Query
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi import Request, Depends, Form, Query
from fastapi import Response

from celery import Celery
from celery.result import AsyncResult


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

CERTS_PATH = os.getenv("CONTAINER_CERTS_PATH")
CERT = os.getenv("CERT_FILE_NAME")
PRIVKEY = os.getenv("PRIVKEY_FILE_NAME")

MOUNTED_DIR = os.getenv("MOUNTED_DIR")
FILES_FOLDER = Path(__file__).parent / MOUNTED_DIR
FILES_FOLDER.mkdir(exist_ok=True)

# Instanciate FastAPI app
app = FastAPI(debug=False)

# Load task configuration
CONFIG_FILE = Path(__file__).parent / "tasks.yaml"
try:
    with open(CONFIG_FILE, "r", encoding="utf-8")  as file:
        config = yaml.safe_load(file)
        tasks = config.get("tasks", {})
    logger.info("Loaded task configuration from 'tasks.yaml'")
except Exception as e:
    logger.error("Failed to load configuration file: `%s`", e)
    raise e

# Instanciate Celery app
celery_app = Celery(
    "tasks",
    broker=BROKER_URL,
    backend=BACKEND_URL,
    broker_connection_retry_on_startup=True,
)
celery_app.conf.update(
    # task_serializer='json',
    # accept_content=['json'],
    # result_serializer='json',
    timezone='Europe/Paris',
    enable_utc=True,
    # This will enable the STARTED status.
    task_track_started=True,
    # One-day history
    result_expires=86400,
    )

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


async def get_task_id(request: Request, task_id: str = Query(None), task_id_form: str = Form(None)):
    """Retieve the `task_id` from Query, Form, or Request Body."""
    form_data = await request.form()
    return task_id or task_id_form or form_data.get("task_id")


async def get_task_name(request: Request, task_name: str = Query(None), task_name_form: str = Form(None)):
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


@app.post("/add_key")
async def add_key(key: UploadFile = Form(...), task_name = Depends(get_task_name)) -> Dict:
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
        logger.error("Error saving server key: `%s`", e)
        raise HTTPException(status_code=500, detail="Failed to save server key.") from e

    return {"uid": uid}


@app.get("/tasks")
def get_use_cases() -> Dict:
    """List available use-cases based on configuration.

    Returns:
        Dict[str, List[str]]: Available use-case names
    """
    logger.info("Fetching list of available use-cases.")
    return {"tasks": list(tasks.keys())}


@celery_app.task(name='tasks.run_binary_task')
def run_binary_task(binary: str, uid: str, task_name: str) -> Dict:
    logger.info("******* run_binary_task *******")
        
    commandline = [f"./{binary}", uid]

    try:
        # result is a subprocess.CompletedProcess object, and 
        # Celery can't store that in Redis.
        start_time = time.time()
        result = subprocess.run(
            commandline, capture_output=True, check=True, text=True
        )
        execution_time = time.time() - start_time
        
        task_logger.info(f"Task: `{task_name}` completed in {execution_time:.2f}s")
        
        if result.stderr:
            task_logger.error(f"Error from `{binary}`:\n`{result.stderr}`")
            
    except subprocess.CalledProcessError as e:
        error_message = f"Error executing {binary}: {e.stderr}"
        task_logger.error(error_message)
        return {"status": "error", "detail": error_message}
    
    # type(result): <class 'subprocess.CompletedProcess'>
    # Celry cannot serialize a CompletedProcess object in JSON
    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode
    }


@app.post("/start_task")
async def start_task(uid: str = Form(...),
                     task_name: str = Form(...),
                     encrypted_input: UploadFile = Form(...)
):
    """Star task."""
    logger.info("******* Endpoint/start_task *******")

    binary = tasks[task_name]['binary']

    # Use input_filename from task_config if specified, otherwise default
    input_filename_template = tasks[task_name].get(
        "input_filename", "{uid}.{task}.input.fheencrypted"
    )
    input_filename = input_filename_template.format(uid=uid, task=task_name)
    input_file_path = FILES_FOLDER / input_filename
    task_logger.debug(f"Input file path: {input_file_path}")

    try:
        file_content = await encrypted_input.read()
        with open(input_file_path, "wb") as f:
            f.write(file_content)
        file_size = input_file_path.stat().st_size  # Get file size in bytes
        task_logger.info(f"Saved input file to {input_file_path} (Size: {file_size} bytes)")

    except Exception as e:
        task_logger.error(f"Error saving input file: {e}")
        raise HTTPException(status_code=500, detail="Failed to save input file.") from e


    # The .delay() function is a shortcut for .apply_async(), which sends the task to the queue. 
    # The arguments you pass to .delay() are the arguments that will be used to execute the task.
    task_logger.info(f"Executing `{task_name}`")
    task = run_binary_task.delay(binary, uid, task_name)
    
    logger.info("Your TASK_ID is `%s`", task.id)

    return JSONResponse({"task_id": task.id})


@app.get("/list_current_tasks")
def list_current_tasks():
    """
    List all Celery tasks that are currently active, reserved (queued),
    or scheduled (waiting to be executed at a later time).
    Tasks that are finished (SUCCESS, FAILURE, REVOKED) won't appear here.
    """
    
    logger.info("******* Endpoint /list_current_tasks *******")

    inspector = celery_app.control.inspect()

    task_states = {
        # Show the tasks that are currently active
        "active": inspector.active() or {},
        # Show the tasks that have been claimed by workers
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
                    "state": state,
                    "worker": worker_name,
                    # "name": t.get("name"),
                    # "args": t.get("args"),                    
                }
                # For scheduled tasks, information are under "request"
                if state == "scheduled":
                    request_info = t.get("request", {})
                    task_info.update({
                        "task_id": request_info.get("id"),
                        # "name": request_info.get("name"),
                        # "args": request_info.get("args"),
                    })
                all_tasks.append(task_info)

    logger.info("All tasks:\n%s", pformat(all_tasks))

    return all_tasks


@app.get("/get_task_status")
def get_task_status(task_id: str = Depends(get_task_id)):
    """Retrieves the status of a task by task_id.
    
    If no `task_id` is provided, returns a list of all current Celery tasks (active, reserved, scheduled).
    """

    logger.info("******* Endpoint/get_task_status *******")
    if task_id is None or task_id.strip() == "":
        tasks_list = list_current_tasks()
        logger.info("`task_id=%s` is None or Empty. Returning all current tasks: %s", task_id, tasks_list)

        return tasks_list

    result = AsyncResult(task_id, app=celery_app)

    if result is None or result.state == "PENDING":
        status = {"task_id": task_id, "status": "Completely unknown status: an associated task might not even exist"}
    elif result.state == "FAILURE":
        status = {"task_id": task_id, "status": "error", "error": str(result.info or "Unknown error")}
    else:    
        status = {"task_id": task_id, "status": result.state.lower()}
        
    logger.info("For TASK_ID: `%s` - status: `%s`", task_id, status)

    return status


@app.post("/cancel_task")
def cancel_task(task_id: str = Depends(get_task_id)):
    """Cancels a running task by ID, if possible."""

    logger.info("******* Endpoint/cancel_task *******")
    logger.info("Cancel TASK_ID: `%s`", task_id)

    if task_id is None:
        return {"task_id": task_id, "error": "Missing task_id"}

    result = AsyncResult(task_id, app=celery_app)
    logger.info("Current task state: `%s`", result.state)
    
    if not result or result.state in ["SUCCESS", "FAILURE", "REVOKED", "PENDING"]:
        return {"task_id": task_id, "status": "Cannot cancel this task (already finished or unknown)."}

    # Terminate task
    celery_app.control.revoke(task_id, terminate=True, signal='SIGKILL')

    result = AsyncResult(task_id, app=celery_app)
    time.sleep(4)
    logger.info("New task state: `%s`", result.state)

    return {"task_id": task_id, "status": result.state.lower()}


@app.get("/get_task_result")
async def get_task_result(
    task_name: str = Depends(get_task_name), 
    task_id: str = Depends(get_task_id),
    uid: str = Depends(get_uid)
):
    """
    Retrieves the final result of a completed task (stream or JSON), 
    using the config in tasks.yaml to decide how to respond.
    """
    logger.info("******* Endpoint/get_task_result *******")

    # Check if the task is done
    celery_result = AsyncResult(task_id, app=celery_app)
  
    if celery_result.state != "SUCCESS":
        logger.info("task_id=`%s` is not completed.", task_id)
        return get_task_status(task_id)
    
    # Defines whether the response will be in stream or JSON format
    response_type = tasks[task_name].get("response_type", "stream")
    # Output name file as specified in the yaml task file
    output_files = tasks[task_name].get("output_files", [])
    
    outcome_celery = celery_result.result

    # Handle outputs based on the configuration
    if response_type == "stream":
        # Expect a single output file
        if not output_files:
            error_message = "No output files defined for streaming response."
            task_logger.error(error_message)
            raise HTTPException(status_code=500, detail=error_message)

        output_file_config = output_files[0]
        output_filename_template = output_file_config["filename"]
        output_filename = output_filename_template.format(uid=uid, task=task_name)
        output_file_path = FILES_FOLDER / output_filename
        task_logger.debug(f"Output file path: {output_file_path}")

        if not output_file_path.exists():
            error_message = f"Output file `{output_filename}` not found."
            task_logger.error(error_message)
            raise HTTPException(status_code=500, detail=error_message)

        try:
            file_size = output_file_path.stat().st_size  # Get file size in bytes
            with open(output_file_path, "rb") as f:
                data = f.read()
            task_logger.info(
                f"Streaming output file `{output_filename}` to client (Size: {file_size} bytes)"
            )
            
            return StreamingResponse(
                io.BytesIO(data),
                media_type="application/octet-stream",
                headers={
                    "Content-Disposition": f"attachment; filename={output_filename}",
                    "status": "success",
                    "job_id": task_id,
                    "stderr": outcome_celery['stderr'],
            },
            )
        except Exception as e:
            task_logger.error(f"Error reading output file: {e}")
            raise HTTPException(status_code=500, detail="Failed to read output file.") from e

    elif response_type == "json":
        response_data = {}
        for output_file_config in output_files:
            filename_template = output_file_config["filename"]
            output_filename = filename_template.format(uid=uid, task=task_name)
            key = output_file_config.get("key", output_filename)
            response_format = output_file_config.get("response_type", "base64")

            response_data[output_filename] = output_filename
            response_data['status'] = "success"
            response_data['job_id'] = task_id
            response_data['stderr'] = outcome_celery['stderr']
            
            output_file_path = FILES_FOLDER / output_filename
            task_logger.debug(f"Processing output file: `{output_file_path}`")

            if not output_file_path.exists():
                error_message = f"Output file `{output_filename}` not found."
                task_logger.error(error_message)
                raise HTTPException(status_code=500, detail=error_message)
                
            try:
                file_size = output_file_path.stat().st_size  # Get file size in bytes
                with open(output_file_path, "rb") as f:
                    data = f.read()

                if response_format == "base64":
                    encoded_data = base64.b64encode(data).decode("utf-8")
                    response_data[key] = encoded_data
                    task_logger.info(
                        f"Processed output file {output_filename} (Size: {file_size} bytes) as base64."
                    )
                else:
                    response_data[key] = data.decode("utf-8")
                    task_logger.info(
                        f"Processed output file {output_filename} (Size: {file_size} bytes) as UTF-8 string."
                    )
            except Exception as e:
                task_logger.error(f"Error processing output file {output_filename}: {e}")
                raise HTTPException(
                    status_code=500,
                    detail=f"Error processing output file {output_filename}.",
                ) from e
                
        task_logger.info(f"Returning JSON response for task '{task_name}'")
        return JSONResponse(content=response_data)
    else:
        error_message = f"Unsupported response type: {response_type}"
        task_logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)


@app.get("/logs")
def get_logs(lines: int = 10):
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


if __name__ == "__main__":
    logger.info("Starting server on port `%s`", PORT)
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(PORT),
        ssl_keyfile=f"{CERTS_PATH}/{PRIVKEY}",
        ssl_certfile=f"{CERTS_PATH}/{CERT}",
    )
