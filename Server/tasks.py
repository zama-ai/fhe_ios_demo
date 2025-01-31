import logging
import os
import subprocess
import time

from typing import Dict
from celery import Celery

from utils import *

BROKER_URL = os.getenv("CELERY_BROKER_URL")
BACKEND_URL = os.getenv("CELERY_RESULT_BACKEND")

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
        task_reject_on_worker_lost=True,
    )
    logger.info("🔥 Successfully connected to Celery!")

except Exception as e:
    celery_app = None
    error_message = f"❌ Failed to initialize Celery app: {e}"
    logger.error(error_message)
    raise RuntimeError(error_message)


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
    commandline = [f"./{binary}", uid]

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

