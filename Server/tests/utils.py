import os
import re
import json
import time
import requests
import base64
import yaml
import subprocess

from typing import List
from pathlib import Path

ID_PATTERN = re.compile(r"^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$")

# Chargement du fichier YAML
with open("tasks.yaml", encoding="utf8", mode="r") as file:
    TASK_CONFIG = yaml.safe_load(file)

PORT = os.getenv('FASTAPI_HOST_PORT_HTTP') if os.getenv('MODE') == 'dev' else os.getenv('FASTAPI_HOST_PORT_HTTPS')
URL = f"{os.getenv('URL')}:{PORT}"

SHARED_DIR = os.getenv("SHARED_DIR")
ENV = os.getenv("COMPOSE_PROJECT_NAME")
REDIS_CONTAINER_NAME = os.getenv("REDIS_CONTAINER_NAME")
CELERY_WORKER_COUNT = int(os.getenv("CELERY_WORKER_COUNT_USECASE_QUEUE"))
CELERY_WORKER_CONCURRENCY = int(os.getenv("CELERY_WORKER_CONCURRENCY_USECASE_QUEUE"))

POLL_INTERVAL = 2
TIME_OUT = 3 * 60 * 60
UPLOAD_FOLDER = Path(f"./project/{SHARED_DIR}")


def save_output_file(path, content, mode="wb"):
    with open(path, mode) as f:
        f.write(content)


def inspect_celery(task="active"):

    out = subprocess.run(
            ["docker", "exec", "-i", f"{ENV}_service_celery_usecases_1", "celery", "-A", "server.celery_app", "inspect", task],
            check=True,
            capture_output=True,
            text=True
    ).stdout

    celery_tasks = [m.group(1) for m in re.finditer(r"'id': '([a-f0-9\-]+)'", out)]

    return celery_tasks


def inspect_redis(queue="usecases"):

    out = subprocess.run([
        "docker", "exec", "-i", REDIS_CONTAINER_NAME, "redis-cli", "LRANGE", queue, "0", "-1"
    ], check=True, capture_output=True, text=True).stdout.strip().splitlines()

    pending_tasks_redis = [json.loads(line)["headers"]["id"] for line in out]

    return pending_tasks_redis


def clean_redis():

    subprocess.run([
        "docker", "exec", "-i", REDIS_CONTAINER_NAME, "redis-cli", "FLUSHALL"
    ], check=True)


def add_key_api(task_name: str, serverkey_path: str) -> str:
    """Upload the server key"""
    with open(serverkey_path, "rb") as f:
        response = requests.post(f"{URL}/add_key", files={"key": f}, data={"task_name": task_name})
        response.raise_for_status()
        uid = response.json()["uid"]
        print(f"[Server side | UID={uid}] Uploading server key: `{serverkey_path}`")
    return uid 


def start_task_api(uid: str, task_name: str, input_path: str) -> str:
    """Start n tasks."""
    with open(input_path, "rb") as f:
        response = requests.post(
            f"{URL}/start_task",
            files={"encrypted_input": f},
            data={"uid": uid, "task_name": task_name}
        )
        task_id = response.json()["task_id"]
        response.raise_for_status()
        print(f"[Server side | TASK_ID={task_id}] Uploading encrypted input: `{input_path}`")
        
    return task_id


def cancel_task_api(uid, task_id):
    """Cancel a task via the API."""
    response = requests.post(f"{URL}/cancel_task?task_id={task_id}&uid={uid}")
    response.raise_for_status()
    time.sleep(3)
    data = response.json()
    return data.get("status"), data.get("details")


def cancel_tasks_and_clear_redis(uid: str, tasks_list: List) -> None:
    """Cancel all tasks in the list and clean Redis data-base."""

    # Cancel all created tasks
    for task_id in tasks_list:
        cancel_task_api(uid, task_id)

    # Clean all Redis dababases (broker and backend)
    clean_redis()


def get_status_api(uid, task_id):
    """Get task status via the API."""
    response = requests.get(f"{URL}/get_task_status", params={"task_id": task_id, "uid": uid})
    response.raise_for_status()
    return response.json()["status"], response.json()["details"]


def get_task_result_api(uid, task_id, task_name, prefix=None):
    """Get task result via the API. and save the output."""
    response = requests.get(f"{URL}/get_task_result", params={"task_name": task_name, "task_id": task_id, "uid": uid})
    response.raise_for_status()

    output_paths = []
    uid = prefix if prefix is not None else uid
    config_output_files = TASK_CONFIG["tasks"][task_name]["output_files"]
    if "Content-Disposition" in response.headers:
        output_path = Path(f"{UPLOAD_FOLDER}/{uid}.{task_name}.output.fheencrypted")
        print(f"Streaming result received! Saving output in {output_path}...")
        save_output_file(output_path, response.content)
        output_paths.append(output_path)
    else:
        data = response.json()
        for config in config_output_files:
            key = config["key"]
            filename = config["filename"].replace("{uid}", f"test_{task_name}")
            output_path = Path(f"{UPLOAD_FOLDER}/{filename}")
            print(f"JSON result received! Saving output in {output_path}...")
            save_output_file(output_path, base64.b64decode(data[key]))
            output_paths.append(output_path)

    return output_paths


def poll_task_result_until_ready(uid: str, task_id: str, task_name: str, prefix=None):
    """Polls the task result until success or timeout, and saves the output file(s).

    Returns:
        (uid, task_id)

    Raises:
        RuntimeError
        TimeoutError
    """
    for attempt in range(TIME_OUT):
        time.sleep(POLL_INTERVAL)
        
        status, details = get_status_api(uid, task_id)

        if status in ["success", "completed"]:
            output_paths = get_task_result_api(uid, task_id, task_name, prefix)
            return output_paths
        else:
            print(f"⏳[Server side] Poll attempt {attempt + 1}/{TIME_OUT} ({status=} | {details=})")
            continue

    raise TimeoutError("Task did not complete within timeout")


def list_current_tasks_api():
    """Get tasks list via the API."""
    response = requests.get(f"{URL}/list_current_tasks")
    response.raise_for_status()
    data = response.json()
    return data


def run_task_on_server(
    task_name: str,
    serverkey_path: str,
    input_path: str,
    prefix=None):

    """Runs an FHE task on a server.

    This function performs the following steps:
    1. Uploads a server key to the server.
    2. Uploads encrypted input data and starts a task.
    3. Polls the server periodically until the task is complete or timeout is reached.
    4. Retrieves and saves the result (streamed file or JSON response, based on the task
    configuration file).

    Args:
        task_name (str): Name of the task to execute.
        serverkey_path (str): Path of the serialized server key file.
        input_path (str): Path of the encrypted input file.
        prefix Optional[str]: Prefix for the path where the result will be saved. If not provided, a random UID will be assigned.

    Returns:
        (uid, task_id): tuple, representing the unique user identifier and task identifier.

    Raises:
        RuntimeError
            If the server returns an HTTP error.
        TimeoutError
            If the task does not complete within the TIME_OUT duration.
    """
   
    # 1. Upload the server key
    uid = add_key_api(task_name, serverkey_path)
    
    # 2. Start task
    task_id = start_task_api(uid, task_name, input_path)

    data = list_current_tasks_api()
    print(f"{len(data)} task (s) in progress")

    # 3. Poll for result   
    output_paths = poll_task_result_until_ready(uid, task_id, task_name, prefix)
    
    return uid, task_id, output_paths


def assert_status(actual_status, actual_details, expected_status, expected_msg_pattern):
    if isinstance(expected_status, str):
        expected_status = [expected_status]
    assert actual_status in expected_status, f"❌ Expected status `{expected_status}`, but got: `{actual_status}`"
    assert re.search(expected_msg_pattern, actual_details), f"❌ Message mismatch:\nExpected pattern: `{expected_msg_pattern}`\nActual: `{actual_details}`"
