"""Deployment server.

We use Celery for asynchronous processing (polling approach).

Routes:
    - /logs
    - /add_key
    - /get_use_cases
    - /start_task  
    - /get_task_status
    - /get_task_result
    - /cancel_task
"""
import base64
import datetime
import io
import time
import uuid

from glob import glob
from typing import List

from celery.result import AsyncResult
from fastapi import (
    Depends,
    FastAPI,
    Form,
    HTTPException,
    Response,
    UploadFile,
)
from fastapi.responses import JSONResponse, StreamingResponse
import json

from utils import * 
from task_executor import *

# Instanciate FastAPI app
app = FastAPI(debug=False)
logger.info(f"🚀 FastAPI server running at {URL}:{PORT}")


# Tasks that cannot be canceled
NON_CANCELLABLE_STATUSES: List = [
    "success",
    "completed",
    "failure",
    "revoked",
    "unknown",
    "error",
]


STATUS_TEMPLATES = {
    "started": {
        "status": "started",
        "details": "Task is still in progress.",
        "worker": None,
        "logger_msg": "🔄 [task_id=`{}` - uid=`{}`] is still in progress. Please wait before attempting to retrieve the result.",
    },
    "success": {
        "status": "success",
        "details": "Task successfully completed.",
        "worker": "not tracked",
        "logger_msg": "🎉 [task_id=`{}` - uid=`{}`] successfully completed.",
    },
    "completed": {
        "status": "completed",
        "details": "The task is already marked as completed in the Redis backend bd.",
        "worker": "not tracked",
        "logger_msg": "🏁 [task_id=`{}` - uid=`{}`] was already completed.",
    },
    "failure": {
        "status": "failure",
        "details": "This task might be lost.",
        "worker": None,
        "logger_msg": "❌ [task_id=`{}` - uid=`{}`] failed. Consider restarting it.",

    },
    "reserved": {
        "status": "reserved",
        "details": "This task will start soon.",
        "worker": "TBD",
        "logger_msg": "📦 [task_id=`{}` - uid=`{}`] is reserved and will start soon.",
    },
    "unknown": {
        "status": "unknown",
        "details": "Task may not exist, you may need to restart it.",
        "worker": None,
        "logger_msg": "❓ [task_id=`{}` - uid=`{}`] has unknown status. Restart may be needed.",

    },
    "queued": {
        "status": "queued",
        "details": "Task is in the Redis broker queue, waiting to be picked up by a worker.",
        "worker": "TBD",
        "logger_msg": "📥 [task_id=`{}` - uid=`{}] is queued and waiting for a worker.",

    },
    "revoked": {
        "status": "revoked",
        "details": "The task has been cancelled by the user or system.",
        "worker": None,
        "logger_msg": (
            "💀 [task_id=`{}` - uid=`{}`] is cancelled | Previous status: `{}` → New status: `{}`."
        )
    },
    "invalid_uid": {
        "status": "unknown",
        "details": "UID is None or Empty.",
        "worker": None,
        "logger_msg": "❌ [uid=`%{}] is None or Empty. Please retry with a valid UID.",
    },
    "invalid_task_id": {
        "status": "unknown",
        "details": "Task ID is None or Empty.",
        "worker": None,
        "logger_msg": "❌ [task_id=`{}`] is None or Empty. Please retry with a valid task ID.",

    },
}


@app.post("/add_key")
async def add_key(key: UploadFile = Form(...), task_name=Depends(get_task_name)) -> Dict:
    """Save the evaluation key on the server side.

    Args:
        key (UploadFile): The evaluation key.
        task_name (str): The name of the task.

    Returns:
        Dict[str, str]
            - uid: a unique identifier.
    """
    uid = str(uuid.uuid4())

    # Write uploaded ServerKey to disk
    try:
        file_content = await key.read()
        file_path = FILES_FOLDER / f"{uid}.serverKey"
        with open(file_path, "wb") as f:
            f.write(file_content)
        file_size = file_path.stat().st_size  # Get file size in bytes
        logger.info("🔐 Successfully received new key upload: `%s` (Size: `%s` bytes). Assigned UID: `%s`", file_path, file_size, uid)
    except Exception as e:
        error_message = f"❌ Failed to store the server key: `e`"
        task_logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)

    return {"uid": uid}


@app.get("/get_use_cases")
def get_use_cases() -> Dict:
    """List available use-cases based on configuration.

    Returns:
        Dict[str, List[str]]: Available use-case names.
    """
    use_cases_list = list(use_cases.keys())
    logger.info("💡 List of available use-cases: %s", use_cases_list)
    return {"Use-cases": use_cases_list}


@app.post("/start_task")
async def start_task(
    uid: str = Form(...),
    task_name: str = Form(...),
    encrypted_input: UploadFile = Form(...)
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
    if task_name not in use_cases:
        error_message = f"❌ Invalid task name: `{task_name}`"
        task_logger.error(error_message)
        raise HTTPException(status_code=400, detail=error_message)

    binary = use_cases[task_name]["binary"]

    # Get the `input_filename` as specified in the yaml configuration
    input_filename = generate_filename(
        config=use_cases[task_name], file_type="input", args={"uid": uid, "task_name": task_name}
    )
    input_file_path = FILES_FOLDER / input_filename
    task_logger.debug(f"📁 Input file path: `{input_file_path}`")

    try:
        file_content = await encrypted_input.read()
        with open(input_file_path, "wb") as f:
            f.write(file_content)
        file_size = input_file_path.stat().st_size  # Get file size in bytes
    except Exception as e:
        error_message = f"❌ Failed to save the input file `{input_file_path}`: {e}."
        task_logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)

    # Start the Celery task
    try:
        # The .delay() function is a shortcut for .apply_async(), which sends the task to the queue.
        task = run_binary_task.delay(binary, uid, task_name)
        task_logger.info(
            f"🚀 Task started [task_id=`{get_id_prefix(task.id)}` - UID=`{get_id_prefix(uid)}`] for task_name=`{task_name}`"
        )
        task_logger.debug(
            f"📁 Saved encrypted input file to `{input_file_path} `(Size: `{file_size}` bytes)"
        )
        return JSONResponse({"task_id": task.id})

    except Exception as e:
        error_message = f"❌ Failed to start task `{task_name}` with UID `{uid}`: {e}"
        task_logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)


@app.get("/list_current_tasks")
def list_current_tasks() -> List[Dict]:
    """Lists all Celery tasks, including pending ones in the queue.

    For workers, tasks may be active, reserved, queued, or scheduled.
    If the worker is full, the tasks are queued in Radis and wait to be pickup.
    With option `worker_prefetch_multiplier`, the worker is allowed to prefetch N task before
    starting the execution.

    Returns:
        List[Dict]: A list of dictionaries containing task details (task_id, status, worker).
    """
    all_tasks: List[Dict] = []

    inspector = celery_app.control.inspect()

    if not inspector:
        task_logger.error(
            "❌ Failed to inspect Celery. Inspector returned `None`. No workers may be available."
        )
        return []

    task_states = {
        # Show the tasks that are currently active
        "active": inspector.active() or {},
        # Show the tasks that have been claimed by `workers`
        "reserved": inspector.reserved() or {},
        # Show tasks that have an ETA or are scheduled for later processing
        "scheduled": inspector.scheduled() or {},
    }

    for state, tasks_data in task_states.items():
        for worker_name, tasks_list in tasks_data.items():
            for t in tasks_list:
                task_info = {
                    "task_id": t.get("id"),
                    "status": state,
                    "worker": worker_name,
                }
                if state == "scheduled":
                    request_info = t.get("request", {})
                    task_info.update(
                        {
                            "task_id": request_info.get("id"),
                        }
                    )
                all_tasks.append(task_info)

    # Retrieving pending tasks from the Redis broker queue
    try:
        pending_tasks = redis_bd_broker.lrange("usecases", 0, -1)
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
        error_message =  f"❌ Failed to retrieve pending tasks from Redis broker: {e}"
        logger.error(error_message)

    logger.info("📝 List of all tasks:\n%s", all_tasks)

    return all_tasks


@app.get("/get_task_status")
def get_task_status(task_id: str = Depends(get_task_id), uid: str = Depends(get_uid)) -> Dict:
    """Retrieves the status of a Celery task by its task ID and UID.

    If no valid `task_id` and `uid` are provided, returns an "unknown" status with details.

    Args:
        task_id (str): The ID of the task to check.
        uid (str): The unique key identifier of the task.

    Returns:
        Dict: A dictionary containing the task ID, status, worker name (if applicable), and additional details.

    Raises:
        HTTPException: Raised if an unexpected error occurs while retrieving the task status.
    """

    ttl: int = None
    response: Dict = None
    worker_name: str = "unknown"
    
    if not task_id or task_id.strip() == "":
        logger.error(STATUS_TEMPLATES['invalid_task_id']['logger_msg'].format(task_id))
        logger.debug(list_current_tasks())
        return STATUS_TEMPLATES['invalid_task_id']
    if not uid or uid.strip() == "":
        logger.error(STATUS_TEMPLATES['invalid_uid']['logger_msg'].format(uid))
        logger.debug(list_current_tasks())
        return STATUS_TEMPLATES['invalid_uid']
    task_info = {"task_id": task_id, "uid": uid}

    # Check if the task is in the Redis broker queue
    try:
        queued_tasks = redis_bd_broker.lrange("usecases", 0, -1)
        for task in queued_tasks:
            task_data = json.loads(task)
            if task_id == task_data["headers"]["id"]:
                logger.info(STATUS_TEMPLATES['queued']['logger_msg'].format(task_id, uid))            
                return {**task_info, **STATUS_TEMPLATES["queued"]}
    except Exception as e:
        logger.error("❌ Failed to check Redis broker bd: %s", str(e))

    # Check if the task is marked as completed in the Redis backend queue
    # Note: Redis only stores task statuses for a limited period of time (Time To Live)
    try:
        key = f"celery-task-meta-{task_id}"
        if redis_bd_backend.exists(key):
            raw = redis_bd_backend.get(key)
            data = json.loads(raw)
            status = data['status'].lower()
            ttl = redis_bd_backend.ttl(key)
            logger.info(f"🔍 [taks_id=`%s`] found in Redis with status=`{status}` and TTL remaining `%s` seconds", get_id_prefix(task_id), ttl)
    except Exception as e:
        logger.error("❌ Failed to check Redis backend bd: `%s`", str(e))

    # Check other status
    try:
        result = AsyncResult(task_id, app=celery_app)
        status = result.state.lower()
    except Exception as e:
        logger.error(f"❌ Failed to get task status for `%s`: `%s`", task_id, str(e))

    # We have 2 options when status = "pending",
    # either the task has been completed by Celery or the task is an undefined status
    if status == "pending":
        file_pattern = f"{BACKUP_FOLDER}/backup.{task_id}.{uid}.*output*.fheencrypted"
        matching_files = glob(file_pattern)

        # If the task is "PENDING" but a saved output file exists, treat it as "completed"
        if matching_files:
            file_path = Path(matching_files[0])
            file_date = file_path.stat().st_mtime  # Get file's last modified time
            date = datetime.datetime.fromtimestamp(file_date).strftime("%Y-%m-%d %H:%M:%S")
            response = {**task_info, **STATUS_TEMPLATES["completed"]}
            response['details'] = f"Task completed on `{date}`. The result is stored."
            response['output_file_path'] = [str(file) for file in matching_files]
        else:
            return {**task_info, **STATUS_TEMPLATES["unknown"]}

    elif status == 'started':
        response = STATUS_TEMPLATES.get(status)
        task_meta = result.backend.get_task_meta(task_id) or {}
        worker_name = task_meta.get("result", {}).get("hostname", "unknown")
        response['worker'] = worker_name

    # Case, where the status is neither 'completed', 'unknown' or 'queued'
    else:
        response = STATUS_TEMPLATES.get(
            status,
            {
                "task_id": task_id,
                "uid": uid,
                "status": status,
                "details": str(result.info or "No additional details available."),
                "worker": worker_name,
            },
        )

    if status == "success" and ttl:
        response['details'] = f"{response['details']}. TTL remaining {ttl} seconds."

    logger.info(
        f"🔍 Status [task_id=`{get_id_prefix(task_id)}` - uid=`{get_id_prefix(uid)}` ]: {response['status'].upper()} | {response['details']} | {response['worker']}"
    )

    return response


@app.post("/cancel_task")
def cancel_task(task_id: str = Depends(get_task_id), uid: str = Depends(get_uid)) -> Dict:
    """Attempts to cancel a running task by ID, if possible.

    Args:
        task_id (str): The ID of the task to cancel.
        uid (str): The unique key identifier of the task.

    Returns:
        Dict: A dictionary containing the task ID, its status, and details about the cancellation.

    Raises:
        HTTPException: Raised with status code 500 if revoking the task fails.
    """

    # Get the current task status
    initial_overall_info = get_task_status(task_id, uid)
    initial_status = initial_overall_info.get("status", "unknown").lower()

    if initial_status in NON_CANCELLABLE_STATUSES:
        logger.warning(
            f"⚠️ Cannot cancel task ID [task_id=`%s` - uid=`%s`] status = `{initial_status}`.", task_id, uid,
        )
        return {
            "task_id": task_id,
            "uid": uid,
            "status": initial_status,
            "worker": (initial_overall_info or {}).get("worker"),
            "details": f"Cannot cancel this task (status = `{initial_status}`). Additional info: {initial_overall_info.get('details', '')}",

        }

    # Attempt to revoke the task
    try:
        celery_app.control.revoke(task_id, terminate=True, signal="SIGKILL")
    except Exception as e:
        error_message = f"❌ Failed to revoke TASK_ID `{task_id}` - uid `{uid}`: `{e}`."
        task_logger.error(error_message)
        raise HTTPException(status_code=500, detail=error_message)

    # Wait for the state to update
    time.sleep(2)

    # Fetch the new state of the task
    reponse = get_task_status(task_id, uid)
    new_status = reponse["status"]

    updated_status = {
        "task_id": task_id,
        "uid": uid,
        "status": new_status,
        "details": f"Successfully cancelled the task, previous status=`{initial_status}` → new status=`{new_status}`",
    }
    
    logger.info(STATUS_TEMPLATES['revoked']['logger_msg'].format(get_id_prefix(task_id), get_id_prefix(uid), initial_status, new_status))

    return updated_status


@app.get("/get_task_result")
async def get_task_result(
    task_name: str = Depends(get_task_name),
    task_id: str = Depends(get_task_id),
    uid: str = Depends(get_uid),
):
    """Retrieves the final result of a completed task.

    Args:
        task_name (str): The name of the task.
        task_id (str): The ID of the task to retrieve the result for.
        uid (str): The unique key identifier.

    Returns:
        StreamingResponse: If `response_type` is set to "stream".
        JSONResponse: If `response_type` is set to "json".

    Raises:
        HTTPException: Raised with a 400 status code if the task name is invalid.
        HTTPException: Raised with a 500 status code for unsupported response types or other errors.
    """
    if task_name not in use_cases:
        task_logger.error("❌ Invalid task name: `{%s}`. See available options at [GET /get_use_cases]", task_name)
        raise HTTPException(status_code=400, detail=f"Task `{task_name}` does not exist.")

    # Check task configuration
    task_config = use_cases.get(task_name, {})
    # Defines whether the response will be in stream or JSON format
    response_type = task_config.get("response_type", "stream")
    # Output name file as specified in the yaml task file
    output_files = task_config.get("output_files", [])
    stderr_output = ""

    # Check task status
    response = get_task_status(task_id, uid)
    status = response.get("status")
    
    if status in STATUS_TEMPLATES and status not in ["success", "completed"]:
        logger.info(STATUS_TEMPLATES[status]['logger_msg'].format(get_id_prefix(task_id), get_id_prefix(uid)))
        return JSONResponse(
            content=status, # ?
            status_code=200,
            headers={"status": response["status"],
                     "job_id": task_id,
                     "uid": uid,
                     "stderr": response["details"],
                     "worker": response["worker"]},
        )

    if status == "completed":
        logger.info(STATUS_TEMPLATES[status]['logger_msg'].format(get_id_prefix(task_id), get_id_prefix(uid)))
        backup = False  # No need for a backup if already completed

    elif status == "success":
        logger.info(STATUS_TEMPLATES[status]['logger_msg'].format(get_id_prefix(task_id), get_id_prefix(uid)))
        celery_result = AsyncResult(task_id, app=celery_app)
        outcome_celery = celery_result.result
        stderr_output = outcome_celery.get("stderr", "")
        backup = True
    else:
        error_message = f"🚨 [task_id=`{task_id}` - uid=`{uid}`] has an undefined state (`{status}`)."
        logger.info(error_message)
        raise HTTPException(status_code=500, detail=error_message)
    
    # Handle outputs based on the configuration
    if response_type == "stream":
        # Expect a single output file
        output_filename = (
            generate_filename(output_files[0], file_type="output", args={"uid": uid})
            if backup
            else response["output_file_path"][0]
        )
        output_file_path = FILES_FOLDER / output_filename
        data = fetch_file_content(output_file_path, task_id, backup=backup)
        
        if backup:
            task_logger.info("🎉 [task_id=`%s` - uid=`%s`] successfully completed.", get_id_prefix(task_id), get_id_prefix(uid))
        else:
            task_logger.info("📜 [task_id=`%s` - uid=`%s`] already complete (Size: `%s`)", get_id_prefix(task_id), get_id_prefix(uid), len(data))

        task_logger.debug(f"Returning STREM response for task '{task_name}'")

        return StreamingResponse(
            io.BytesIO(data),
            media_type="application/octet-stream",
            headers={
                "Content-Disposition": f"attachment; filename={output_filename}",
                "status": "success",
                "job_id": task_id,
                "stderr": stderr_output,
                "task_name": task_name,
                 "worker": response["worker"],
            },
        )
    elif response_type == "json":
        response_data = {"job_id": task_id, "stderr": stderr_output, "task_name": task_name, 'output_file_path': [],  "worker": response["worker"]}
                 
        for i, output_file_config in enumerate(output_files):           
            response_format = output_file_config.get("response_type", "base64")
            key = output_file_config.get("key")
           
            if backup:
                response_data['status'] = 'success'
                output_filename = generate_filename(output_file_config, file_type="output", args={"uid": uid})
            else:
                response_data['status'] = 'completed'
                output_filename = [f for f in response["output_file_path"] if key in f.lower()][0]
            
            response_data["output_file_path"].append(output_filename)
                
            key = output_file_config.get("key", output_filename)
                
            output_file_path = FILES_FOLDER / output_filename
            
            data = fetch_file_content(output_file_path, task_id, backup=backup)

            response_data[key] = (
                base64.b64encode(data).decode("utf-8")
                if response_format == "base64"
                else data.decode("utf-8")
            )

        if backup:
            task_logger.info("🎉 [task_id=`%s` - uid=`%s`] successfully completed.", task_id, uid)
        else:
            task_logger.info("📜 [task_id=`%s` - uid=`%s`] already complete (Size: `%s`)", task_id, uid, len(data))

        task_logger.debug(f"Returning JSON response for task '{task_name}'")
        
        return JSONResponse(content=response_data)
    else:
        error_message = f"❌ Unsupported response type: `{response_type}`"
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
        logger.warning("⚠️ Log file not found when attempting to fetch logs.")
        return Response(
            content="Log file not found. Logs might not have been generated yet.", status_code=404
        )
    except Exception as e:
        logger.error("❌ Error serving logs: `%s`", e)
        return Response(content="An error occurred while fetching logs.", status_code=500)


@app.get("/robots.txt")
def robots():
    content = "User-agent: *\nDisallow: /"
    return Response(content=content, media_type="text/plain")
