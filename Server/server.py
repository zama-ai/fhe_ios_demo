"""Deployment server with individual routes for each task.

Routes:
    - /add_key
    - /tasks
    - /{task_name}
    - /logs
"""

import asyncio
import base64
import io
import logging
import os
import subprocess
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Dict

import uvicorn
import yaml
from fastapi import FastAPI, Form, HTTPException, UploadFile, Response
from fastapi.responses import JSONResponse, StreamingResponse

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

app = FastAPI(debug=False)

FILES_FOLDER = Path(__file__).parent / "uploaded_files"
FILES_FOLDER.mkdir(exist_ok=True)  # Ensure the directory exists

# Load task configuration
CONFIG_FILE = Path(__file__).parent / "tasks.yaml"
try:
    with open(CONFIG_FILE, "r") as file:
        config = yaml.safe_load(file)
    logger.info("Loaded task configuration from tasks.yaml")
except Exception as e:
    logger.error(f"Failed to load configuration file: {e}")
    raise e

tasks = config.get("tasks", {})
PORT = os.environ.get("PORT", "5000")

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
async def add_key(key: UploadFile):
    """Save the evaluation key.

    Arguments:
        key (UploadFile): evaluation key

    Returns:
        Dict[str, str]
            - uid: a unique identifier
    """
    uid = str(uuid.uuid4())
    logger.info(f"Received new key upload. Assigned UID: {uid}")

    # Write uploaded ServerKey to disk
    try:
        file_content = await key.read()
        file_path = FILES_FOLDER / f"{uid}.serverKey"
        with open(file_path, "wb") as f:
            f.write(file_content)
        file_size = file_path.stat().st_size  # Get file size in bytes
        logger.info(f"Saved server key to {file_path} (Size: {file_size} bytes)")
    except Exception as e:
        logger.error(f"Error saving server key: {e}")
        raise HTTPException(status_code=500, detail="Failed to save server key.")

    return {"uid": uid}


@app.get("/tasks")
def get_tasks():
    """List available tasks based on configuration.

    Returns:
        Dict[str, List[str]]: Available task names
    """
    logger.info("Fetching list of available tasks.")
    return {"tasks": list(tasks.keys())}


def create_task_endpoint(task_name: str, task_config: Dict[str, Any]) -> Callable:
    """Creates an endpoint function for a given task.

    Args:
        task_name (str): The name of the task.
        task_config (Dict[str, Any]): The configuration for the task.

    Returns:
        Callable: The endpoint function.
    """
    binary = task_config["binary"]
    response_type = task_config.get("response_type", "stream")
    output_files = task_config.get("output_files", [])

    async def task_endpoint(input: UploadFile, uid: str = Form(...)):
        """Handle the specific task.

        Arguments:
            input (UploadFile): Input file for the task.
            uid (str): UID of the public key to use.

        Returns:
            StreamingResponse or JSONResponse: Result of the task.
        """
        with task_logger.task_context(task_name):
            task_logger.info(f"Received request from UID: {uid}")

            # Use input_filename from task_config if specified, otherwise default
            input_filename_template = task_config.get(
                "input_filename", "{uid}.{task}.input.fheencrypted"
            )
            input_filename = input_filename_template.format(uid=uid, task=task_name)
            input_file_path = FILES_FOLDER / input_filename
            task_logger.debug(f"Input file path: {input_file_path}")

            # Save the input file
            try:
                file_content = await input.read()
                with open(input_file_path, "wb") as f:
                    f.write(file_content)
                file_size = input_file_path.stat().st_size  # Get file size in bytes
                task_logger.info(f"Saved input file to {input_file_path} (Size: {file_size} bytes)")
            except Exception as e:
                task_logger.error(f"Error saving input file: {e}")
                raise HTTPException(status_code=500, detail="Failed to save input file.")

            # Execute the corresponding Rust binary using subprocess
            task_logger.info(f"Executing {task_name}")
            try:
                start_time = time.time()
                process = await asyncio.create_subprocess_exec(
                    f"./{binary}",
                    uid,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                stdout, stderr = await process.communicate()
                execution_time = time.time() - start_time

                if process.returncode != 0:
                    task_logger.error(f"Error executing {binary}: {stderr.decode()}")
                    raise HTTPException(
                        status_code=500, detail=f"Error executing {binary}: {stderr.decode()}"
                    )

                task_logger.info(
                    f"FHE execution of {task_name} completed in {execution_time:.2f} seconds"
                )
                if stderr:
                    task_logger.warning(f"Error output from {binary}:\n{stderr.decode()}")
            except subprocess.CalledProcessError as e:
                task_logger.error(f"Error executing {binary}: {e.stderr}")
                raise HTTPException(status_code=500, detail=f"Error executing {binary}: {e.stderr}")

            # Handle outputs based on the configuration
            if response_type == "stream":
                # Expect a single output file
                if not output_files:
                    task_logger.error("No output files defined for streaming response.")
                    raise HTTPException(
                        status_code=500, detail="No output files defined for streaming response."
                    )

                output_file_config = output_files[0]
                output_filename_template = output_file_config["filename"]
                output_filename = output_filename_template.format(uid=uid, task=task_name)
                output_file_path = FILES_FOLDER / output_filename
                task_logger.debug(f"Output file path: {output_file_path}")

                if not output_file_path.exists():
                    task_logger.error(f"Output file {output_filename} not found.")
                    raise HTTPException(
                        status_code=500, detail=f"Output file {output_filename} not found."
                    )

                try:
                    file_size = output_file_path.stat().st_size  # Get file size in bytes
                    with open(output_file_path, "rb") as f:
                        data = f.read()
                    task_logger.info(
                        f"Streaming output file {output_filename} to client (Size: {file_size} bytes)"
                    )
                    return StreamingResponse(
                        io.BytesIO(data),
                        media_type="application/octet-stream",
                        headers={"Content-Disposition": f"attachment; filename={output_filename}"},
                    )
                except Exception as e:
                    task_logger.error(f"Error reading output file: {e}")
                    raise HTTPException(status_code=500, detail="Failed to read output file.")

            elif response_type == "json":
                response_data = {}
                for output_file_config in output_files:
                    filename_template = output_file_config["filename"]
                    output_filename = filename_template.format(uid=uid, task=task_name)
                    key = output_file_config.get("key", output_filename)
                    response_format = output_file_config.get("response_type", "base64")

                    output_file_path = FILES_FOLDER / output_filename
                    task_logger.debug(f"Processing output file: {output_file_path}")

                    if not output_file_path.exists():
                        task_logger.error(f"Output file {output_filename} not found.")
                        raise HTTPException(
                            status_code=500, detail=f"Output file {output_filename} not found."
                        )

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
                        )

                task_logger.info(f"Returning JSON response for task '{task_name}'")
                return JSONResponse(content=response_data)
            else:
                task_logger.error(f"Unsupported response type: {response_type}")
                raise HTTPException(
                    status_code=500, detail=f"Unsupported response type: {response_type}"
                )

    return task_endpoint


# Dynamically create routes for each task
for task_name, task_config in tasks.items():
    # Define the endpoint path
    endpoint_path = f"/{task_name}"
    # Create the endpoint function
    endpoint_func = create_task_endpoint(task_name, task_config)
    # Add the route to the FastAPI app
    app.add_api_route(
        endpoint_path,
        endpoint_func,
        methods=["POST"],
        name=task_name,
        summary=f"Execute the {task_name} task",
        description=f"Process input data using the {task_name} task.",
    )
    logger.info(f"Added endpoint for task '{task_name}' at '{endpoint_path}'")


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
        with open(LOG_FILE, "r") as log_file:
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
        logger.error(f"Error serving logs: {e}")
        return Response(content="An error occurred while fetching logs.", status_code=500)


@app.get("/robots.txt")
def robots():
    content = "User-agent: *\nDisallow: /"
    return Response(content=content, media_type="text/plain")

if __name__ == "__main__":
    logger.info(f"Starting server on port {PORT}")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(PORT),
        ssl_keyfile="/project/key.pem",
        ssl_certfile="/project/cert.pem",
    )
