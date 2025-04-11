import requests

import time 
import pytest

from utils import *

def cancel_task(uid, task_id):
    """Cancel a task and check if it's revoked."""
       
    response = requests.post(f"{URL}/cancel_task?task_id={task_id}&uid={uid}")
    response.raise_for_status()
    
    time.sleep(3)

    data = response.json()
    status = data.get("status")

    return status

# In rare cases, the status may be unknown/complete if the task has not yet started or has finished.
# Thus, we restart the test if it fails.
@pytest.mark.flaky(reruns=2)
@pytest.mark.parametrize("task_name,uid", [
    ("ad_targeting", "test_ad_targeting"),
    ("weight_stats", "test_weight_stats"),
])
def test_cancel_task_endpoint_success(task_name, uid):
    print("\nRun test cancel_task endpoint (expected success).")
    
    # 1. Upload the server key
    serverkey_path = f"{UPLOAD_FOLDER}/{uid}.serverKey"
    input_path = f"{UPLOAD_FOLDER}/{uid}.{task_name}.input.fheencrypted"
    
    with open(serverkey_path, "rb") as f:
        response = requests.post(f"{URL}/add_key", files={"key": f}, data={"task_name": task_name})
        response.raise_for_status()
        uid = response.json()["uid"]
    
    # 2. Start task
    with open(input_path, "rb") as f:
        response = requests.post(f"{URL}/start_task", files={"encrypted_input": f}, data={"uid": uid, "task_name": task_name})
        response.raise_for_status()
        task_id = response.json()["task_id"]
        
    # 3. Cancel task
    status = cancel_task(uid, task_id)
    assert status.lower() == "revoked", f"❌ Expected status 'revoked', but got: `{status}`"
    # If the status is Unknown, it may be due to a task being completed more quickly than expected.
    # Reducing sleep time may fix the issue.

@pytest.mark.parametrize("task_name,uid", [
    ("ad_targeting", "test_ad_targeting"),
    ("weight_stats", "test_weight_stats"),
    ("sleep_quality", "test_good_night"),
])
@pytest.mark.parametrize("wrong_task_id", ["", None, "Fake_Task_ID"])
def test_cancel_task_endpoint_failure(task_name, uid, wrong_task_id):
    print("\nRun test cancel_task endpoint (expected failure).")
    
    # 1. Upload the server key
    serverkey_path = f"{UPLOAD_FOLDER}/{uid}.serverKey"
    
    with open(serverkey_path, "rb") as f:
        response = requests.post(f"{URL}/add_key", files={"key": f}, data={"task_name": task_name})
        response.raise_for_status()
        uid = response.json()["uid"]
    
    # 2. Cancel task with wrong task_id
    status = cancel_task(uid, wrong_task_id)
    assert status.lower() == "unknown", f"❌ Expected status 'unknown', but got: `{status}`"


def test_get_use_cases_endpoint():
    print("\nRun test get_use_cases endpoint.")

    response = requests.get(f"{URL}/get_use_cases")
    response.raise_for_status()
    data = response.json()

    assert isinstance(data, dict)
    assert len(list(data.values())[0]) == len(TASK_CONFIG['tasks'].keys())
