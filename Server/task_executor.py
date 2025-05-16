import os
import subprocess
import time

from typing import Dict
from urllib.parse import urlparse

import redis

from celery import Celery

from utils import *

BROKER_URL = os.getenv("BROKER_URL")
BACKEND_URL = os.getenv("BACKEND_URL")

PARSED_BROKER_URL = urlparse(BROKER_URL)
PARSED_BACKEND_URL = urlparse(BACKEND_URL)

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
        # `task_ignore_result`: The result of each task will be stored in the Redis backend
        task_ignore_result = False,
    )
    logger.info("🔥 Successfully connected to Celery!")

except Exception as e:
    celery_app = None
    error_message = f"❌ Failed to initialize Celery app: {e}"
    logger.error(error_message)
    raise RuntimeError(error_message)


# Instanciate Redis broker data-base
try:
    redis_bd_broker = redis.Redis(
                host=PARSED_BROKER_URL.hostname,
                port=PARSED_BROKER_URL.port,
                db=int(PARSED_BROKER_URL.path.lstrip('/')),  # 0
                decode_responses=True,
            )
    redis_bd_broker.ping()
    logger.info("🔥 Successfully connected to Redis broker!")
except redis.ConnectionError:
    redis_bd_broker = None
    logger.error("❌ Failed to connect to Redis broker!")

# Instanciate Redis backend data-base
try:
    redis_bd_backend = redis.Redis(
        host=PARSED_BACKEND_URL.hostname,
        port=PARSED_BACKEND_URL.port,
        db=int(PARSED_BACKEND_URL.path.lstrip('/')),  # 1
        decode_responses=True,
    )
    redis_bd_backend.ping()
    logger.info("🔥 Successfully connected to Redis backend!")
except redis.ConnectionError:
    redis_bd_backend = None
    logger.error("❌ Failed to connect to Redis backend!")


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
    commandline = [f"./{binary}", uid]
    current_task_id = celery_app.current_task.request.id if celery_app.current_task else "UnknownCeleryID"
    task_logger.info(f"EXECUTE_BINARY: Task {task_name} (UID {get_id_prefix(uid)}, CeleryID {get_id_prefix(current_task_id)}): Preparing to run command: {' '.join(commandline)}")
    
    start_time = time.time()
    try:
        result = subprocess.run(commandline, capture_output=True, check=True, text=True)
        execution_time = time.time() - start_time
        task_logger.info(f"🥕 ✅ [task_name=`{task_name}`, UID=`{get_id_prefix(uid)}`, CeleryID=`{get_id_prefix(current_task_id)}`]: completed in `{execution_time:.2f}`s. Subprocess stdout (first 200 chars): {result.stdout[:200]}, stderr (first 200 chars): {result.stderr[:200]}")
        return {"stdout": result.stdout, "stderr": result.stderr, "returncode": result.returncode, "execution_time_seconds": execution_time}

    except subprocess.CalledProcessError as e:
        execution_time = time.time() - start_time
        error_message = f"🥕 ❌ CalledProcessError for `{binary}` (UID=`{get_id_prefix(uid)}`, CeleryID=`{get_id_prefix(current_task_id)}`) after {execution_time:.2f}s: `{e.stderr}`. Stdout: `{e.stdout}`. Return code: {e.returncode}"
        task_logger.error(error_message)
        return {"status": "error", "detail": error_message, "stderr": e.stderr, "stdout": e.stdout, "returncode": e.returncode, "execution_time_seconds": execution_time}
    except subprocess.TimeoutExpired as e:
        execution_time = time.time() - start_time
        error_message = f"🥕 ❌ TimeoutExpired for `{binary}` (UID=`{get_id_prefix(uid)}`, CeleryID=`{get_id_prefix(current_task_id)}`) after {execution_time:.2f}s (timeout was {e.timeout}s). Stdout: {e.stdout.decode(errors='ignore') if e.stdout else ''}, Stderr: {e.stderr.decode(errors='ignore') if e.stderr else ''}"
        task_logger.error(error_message)
        return {"status": "error", "detail": error_message, "execution_time_seconds": execution_time}
    except Exception as e:
        execution_time = time.time() - start_time
        error_message = f"🥕 ❌ Generic Exception for `{binary}` (UID=`{get_id_prefix(uid)}`, CeleryID=`{get_id_prefix(current_task_id)}`) after {execution_time:.2f}s: {str(e)}"
        task_logger.error(error_message)
        return {"status": "error", "detail": error_message, "execution_time_seconds": execution_time}


# Queue 1: `use-cases`
@celery_app.task(name="tasks.run_binary_task", bind=True, queue="usecases")
def run_binary_task(self, binary: str, uid: str, task_name: str) -> Dict:
    task_logger.info(f"CELERY_TASK run_binary_task: Received. Binary: {binary}, UID: {get_id_prefix(uid)}, Task Name: {task_name}, Celery Task ID: {get_id_prefix(self.request.id)}")
    result = execute_binary(binary, uid, task_name)
    task_logger.info(f"CELERY_TASK run_binary_task: Completed execution for UID {get_id_prefix(uid)}, Task Name: {task_name}, Celery Task ID: {get_id_prefix(self.request.id)}. Result status: {result.get('status', 'success') if isinstance(result, dict) else 'unknown'}")
    return result


# Queue 2: `ads`
@celery_app.task(name="tasks.fetch_ad", bind=True, queue="ads")
def fetch_ad(self, binary: str, uid: str) -> Dict:
    task_logger.info(f"CELERY_TASK fetch_ad: Received. Binary: {binary}, UID: {get_id_prefix(uid)}, Celery Task ID: {get_id_prefix(self.request.id)}")
    result = execute_binary(binary, uid, "fetch_ad")
    task_logger.info(f"CELERY_TASK fetch_ad: Completed execution for UID {get_id_prefix(uid)}, Celery Task ID: {get_id_prefix(self.request.id)}. Result status: {result.get('status', 'success') if isinstance(result, dict) else 'unknown'}")
    return result
