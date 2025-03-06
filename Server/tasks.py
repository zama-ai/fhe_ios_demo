import logging
import os
import subprocess
import time

from typing import Dict
from celery import Celery

from utils import *

BROKER_URL = os.getenv("BROKER_URL")
BACKEND_URL = os.getenv("BACKEND_URL")

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
        # `task_track_started`: Enables the `STARTED` status
        task_track_started=True,
        # `result_expires`: One-month history
        result_expires=60 * 60 * 24 * 30,
        # `task_acks_late`: Redispatch unfinished tasks
        task_acks_late=True,
        # `task_acks_on_failure_or_timeout`: Avoid marking a task as “acknowledged” if it crashes
        task_acks_on_failure_or_timeout=False,
        # `broker_transport_options`: X seconds before an abandoned task becomes available again
        broker_transport_options={"visibility_timeout": 60 * 1},
        # `worker_prefetch_multiplier`: How many tasks a Celery worker prefetchs before starting it
        worker_prefetch_multiplier=1,
        task_reject_on_worker_lost=True,
    )
    logger.info("🔥 Successfully connected to Celery!")

except Exception as e:
    error_message = f"❌ Failed to initialize Celery app: `{e}`"
    logger.error(error_message)
    raise RuntimeError(error_message) from e


def execute_binary(binary: str, uid: str, task_name: str) -> Dict:
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
    commandline = [f"./{binary}", uid, task_name]

    try:
        # Result is a subprocess.CompletedProcess object, and Celery can't store that in Redis.
        start_time = time.time()
        result = subprocess.run(commandline, capture_output=True, check=True, text=True)
        execution_time = time.time() - start_time
        task_logger.info(f"🥕 ✅ [task_name=`{task_name}`]: completed in `{execution_time:.2f}`s")

    except subprocess.CalledProcessError as e:
        error_message = f"🥕 ❌ Failed to execute: `{binary}`: `{e.stderr}`"
        task_logger.error(error_message)
        return {"status": "error", "detail": error_message}

    # Celry cannot serialize a <class 'subprocess.CompletedProcess'> object in JSON
    return {"stdout": result.stdout, "stderr": result.stderr, "returncode": result.returncode}


# Queue 1: `use-cases`
@celery_app.task(name="tasks.run_binary_task", queue="usecases")
def run_binary_task(binary: str, uid: str, task_name: str) -> Dict:
    return execute_binary(binary, uid, task_name)


# Queue 2: `ads`
@celery_app.task(name="tasks.fetch_ad", queue="ads")
def fetch_ad(binary: str, uid: str) -> Dict:
    return execute_binary(binary, uid, "fetch_ad")
