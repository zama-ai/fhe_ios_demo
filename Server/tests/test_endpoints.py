import re
import requests
import time 
import pytest

from utils import *


# In rare cases, the status may be unknown/complete if the task has not yet started or has finished.
# Thus, we restart the test if it fails.
@pytest.mark.flaky()
@pytest.mark.parametrize("expected_status,expected_msg,prefix,task_name", [
    ("revoked", r"Successfully cancelled the task.*", "test_ad_targeting", "ad_targeting"),
    ("revoked", r"Successfully cancelled the task.*", "test_weight_stats", "weight_stats"),
    ("revoked", r"Successfully cancelled the task.*", "test_good_night", "sleep_quality"),
])
def test_cancel_task_endpoint_success(expected_status, expected_msg, prefix, task_name):
    print("\nRun test cancel_task endpoint (expected success).")

    # Make sure to run test_<task_name>, to generate the following files
    serverkey_test_path = f"{UPLOAD_FOLDER}/{prefix}.serverKey"
    input_test_path = f"{UPLOAD_FOLDER}/{prefix}.{task_name}.input.fheencrypted"

    # Upload the server key
    uid = add_key_api(task_name, serverkey_test_path)

    # Start task
    task_id = start_task_api(uid, task_name, input_test_path)

    time.sleep(1)

    # Cancel task
    for attempt in range(TIME_OUT):
        time.sleep(POLL_INTERVAL)
        status, details = get_status_api(uid, task_id)
        if status != 'queued':
            break

    status, details = cancel_task_api(uid, task_id)

    # If the status is Unknown, it may be due to a task being completed more quickly than expected.
    # Reducing sleep time may fix the issue.
    assert_status(status, details, expected_status, expected_msg)


@pytest.mark.parametrize("task_id,expected_status,expected_msg,prefix,task_name", [
    ("", "unknown", r"Cannot cancel this task.*Task ID is None or Empty.*", "test_weight_stats", "weight_stats"),
    ("Fake_Task_ID", "unknown", r"Cannot cancel this task.*Task may not exist.*", "test_weight_stats", "weight_stats"),
    ("Completed_Task_ID", "success", r"Cannot cancel this task.*Task successfully completed.", "test_weight_stats", "weight_stats"),
])
def test_cancel_task_endpoint_failure(task_id, expected_status, expected_msg, prefix, task_name):
    print("\nRun test cancel_task endpoint (expected failure).")

    # Make sure to run test_<task_name>, to generate the following files
    serverkey_test_path = Path(f"{UPLOAD_FOLDER}/{prefix}.serverKey")
    input_test_path = Path(f"{UPLOAD_FOLDER}/{prefix}.{task_name}.input.fheencrypted")

    # Upload the server key
    uid = add_key_api(task_name, serverkey_test_path)

    # If "Completed_Task_ID", start a real task and wait for it to complete
    if task_id == "Completed_Task_ID":
        task_id = start_task_api(uid, task_name, input_test_path)
        for attempt in range(TIME_OUT):
            time.sleep(POLL_INTERVAL)
            status, details = get_status_api(uid, task_id)
            print(f"[via API ] polling attempt {attempt + 1}/{TIME_OUT} | Status: {status} | Details: {details}")
            if status == "success":
                break

    # Cancel task with non-compliant task_id
    status, details = cancel_task_api(uid, task_id)
    assert_status(status, details, expected_status, expected_msg)


def test_get_use_cases_endpoint():
    print("\nRun test get_use_cases endpoint.")

    response = requests.get(f"{URL}/get_use_cases")
    response.raise_for_status()
    data = response.json()

    assert isinstance(data, dict)
    assert len(list(data.values())[0]) == len(TASK_CONFIG['tasks'].keys())


# The 'ad_targeting' and 'weight_stats' tasks tend to complete quickly.
# To avoid test failures due to early completion, a success flag is added in the expected status.
@pytest.mark.parametrize("task_name,expected_status,expected_msg,prefix", [
    ("ad_targeting", ["started", "success"], "Task is still in progress", "test_ad_targeting"),
    ("weight_stats", ["started", "success"], "Task is still in progress", "test_weight_stats"),
    ("sleep_quality", "started", "Task is still in progress", "test_good_night"),
])
def test_start_task_endpoint(task_name, expected_status, expected_msg, prefix):
    print(f"\nRun test start_task endpoint for `{task_name}`.")

    # Make sure to run test_<task_name>, to generate the following files
    serverkey_test_path = Path(f"{UPLOAD_FOLDER}/{prefix}.serverKey")
    input_path_test_path = Path(f"{UPLOAD_FOLDER}/{prefix}.{task_name}.input.fheencrypted")

    # Upload the server key
    uid = add_key_api(task_name, serverkey_test_path)
    assert ID_PATTERN.match(uid), f"❌ Invalid UID format, got: `{uid}`."

    # Start the task
    task_id = start_task_api(uid, task_name, input_path_test_path)
    assert ID_PATTERN.match(task_id), f"❌ Invalid task ID format, got: `{uid}`."

    # Files checks
    serverkey_shared_path = Path(f"{UPLOAD_FOLDER.name}/{uid}.serverKey")
    input_path_shared_path = Path(f"{UPLOAD_FOLDER.name}/{uid}.{task_name}.input.fheencrypted")

    assert serverkey_test_path.stat().st_size == serverkey_shared_path.stat().st_size, (
        f"❌ Server key size mismatch:\nlocal={serverkey_test_path.stat().st_size} bytes"
        f"\nremote={serverkey_shared_path.stat().st_size} bytes."
    )
    assert serverkey_test_path.read_bytes() == serverkey_shared_path.read_bytes(), (
    "❌ Server key files differ in content."
    )
    assert input_path_test_path.stat().st_size == input_path_shared_path.stat().st_size, (
        f"❌ Server key size mismatch:\nlocal={input_path_test_path.stat().st_size} bytes"
        f"\nremote={input_path_shared_path.stat().st_size} bytes."
    )
    assert input_path_test_path.read_bytes() == input_path_shared_path.read_bytes(), (
    "❌ Encrypted input files differ in content."
    )

    for attempt in range(TIME_OUT):
        time.sleep(POLL_INTERVAL)
        status, details = get_status_api(uid, task_id)
        print(f"[via API ] polling attempt {attempt + 1}/{TIME_OUT} | Status: {status} | Details: {details}")
        if status in ["started", "success"]:
            break

    # Get task status via Celery inspect
    active_tasks_celery = inspect_celery(task="active")
    print(f"[via Celery inspect | active task list = {active_tasks_celery}]")

    # Get task status via API
    status, details = get_status_api(uid, task_id)
    print(f"[via API | {status=} | {details=}")

    assert_status(status, details, expected_status, expected_msg)
    assert task_id in active_tasks_celery, f"❌ `{task_id=}` expected to be running on Celery queue, but wan't find in `{active_tasks_celery}`"

    cancel_task_api(uid, task_id)


@pytest.mark.parametrize("task_name,prefix", [
    ("sleep_quality", "test_good_night"),
    ("ad_targeting", "test_ad_targeting"),
    ("weight_stats", "test_weight_stats"),
])
def test_status_task_endpoint(task_name, prefix):
    print(f"\nRun test get_status endpoint for `{task_name}`.")

    # Make sure to run test_<task_name>, to generate the following files
    serverkey_test_path = Path(f"{UPLOAD_FOLDER}/{prefix}.serverKey")
    input_path_test_path = Path(f"{UPLOAD_FOLDER}/{prefix}.{task_name}.input.fheencrypted")

    # Upload the server key
    uid = add_key_api(task_name, serverkey_test_path)

    # Start the task
    task_id = start_task_api(uid, task_name, input_path_test_path)

    # status: 'queued' or 'started'
    # Continuously poll via the API to check whether the task has completed
    for attempt in range(TIME_OUT):
        time.sleep(POLL_INTERVAL)
        status, details = get_status_api(uid, task_id)
        print(f"[via API ] polling attempt {attempt + 1}/{TIME_OUT} | Status: {status} | Details: {details}")

        if status == "success":
            break

        if status not in ["queued", "started"]:
            raise AssertionError(f"❌ Unexpected status: `{status}` — Details: {details}")
    else:
        raise AssertionError(f"❌ Task did not complete within timeout")

    output_paths = get_task_result_api(uid, task_id, task_name)

    assert all(p.exists() for p in output_paths), f"❌ Output files not found: `{output_paths}`"
    assert all(p.stat().st_size > 1 * 1024 for p in output_paths), f"❌ Too small files: `{output_paths}`"

    # status: 'success'
    assert_status(status, details, "success", r"Task successfully completed.")

    time.sleep(5)
    
    # status: 'completed'
    status, details = get_status_api(uid, task_id)
    assert_status(status, details, "completed", r"Task completed on *.")


# In rare cases, a task may be pending when querying fasapi,
# By the time redis is queried, the task is already active.
# Thus, we restart the test if it fails.
@pytest.mark.flaky(reruns=2)
@pytest.mark.parametrize("task_name,prefix,nb_tasks", [
    ("sleep_quality", "test_good_night", 12),
])
def test_inspect_celery_redis(task_name, prefix, nb_tasks):
    print(f"\nRun test test_inspect_celery_redis, for `{task_name}`.")

    all_created_tasks = []

    # Paths for the uploaded server key and encrypted input
    serverkey_test_path = f"{UPLOAD_FOLDER}/{prefix}.serverKey"
    input_test_path = f"{UPLOAD_FOLDER}/{prefix}.{task_name}.input.fheencrypted"

    # Upload the server key
    uid = add_key_api(task_name, serverkey_test_path)

    # Launch `nb_tasks`
    all_created_tasks = [start_task_api(uid, task_name, input_test_path) for _ in range(nb_tasks)]

    # Get task status via API
    response = list_current_tasks_api()

    # Get active tasks via Celery inspect
    active_tasks_celery = inspect_celery(task="active")

    # Get pending tasks via Redis
    pending_tasks_redis = inspect_redis(queue="usecases")

    all_tasks_api = [(t['task_id'], t['status']) for t in response]
    pending_tasks_api = [t_id for t_id, s in all_tasks_api if s == "queued"]
    pending_tasks_api = [t_id for t_id, s in all_tasks_api if s == "queued"]
    active_tasks_api = [t_id for t_id, s in all_tasks_api if s == "active"]

    print(f"List of created tasks:\n{all_created_tasks}")
    print(f"[via Celery inspect] List of active tasks:\n{active_tasks_celery}]")
    print(f"[via Redis] List of pending tasks:\n{pending_tasks_redis}")
    print(f"[via API] List of current tasks:\n{all_tasks_api}")
    print(f"[via API] List of pending tasks:\n{pending_tasks_api}")
    print(f"[via API] List of active tasks :\n{active_tasks_api}")

    # Expected numbers
    expected_n_active_task = CELERY_WORKER_CONCURRENCY * CELERY_WORKER_COUNT
    expected_n_pending_task = nb_tasks - expected_n_active_task

    # Assertions
    assert len(set(pending_tasks_api) - set(pending_tasks_redis)) == 0, (
        f"Mismatch between API and Redis queued tasks, expected `{expected_n_pending_task}` tasks,"
        f"but got:\nAPI: `{pending_tasks_api=}`\nRedis: `{pending_tasks_redis=}`"
    )
    assert len(pending_tasks_api) +  len(active_tasks_api) >= nb_tasks, (
        f"Created tasks do not match the sum of active + queued:\n"
        f"Created: {all_created_tasks}\n"
        f"API reported:\nPending tasks: `{pending_tasks_api}`\nActive tasks:`{active_tasks_api}`"
    )

    status, details = get_status_api(uid, all_created_tasks[-1])
    assert_status(status, details, "queued", r"Task is in the Redis broker queue")

    cancel_tasks_and_clear_redis(uid, all_created_tasks)
