import time
import requests
import base64

import yaml

# Chargement du fichier YAML
with open("tasks.yaml", encoding="utf8", mode="r") as file:
    TASK_CONFIG = yaml.safe_load(file)
    
TIME_OUT = 3 * 60 * 60
POLL_INTERVAL = 5
UPLOAD_FOLDER = "./project/uploaded_files"

def save_output_file(path, content, mode="wb"):
    with open(path, mode) as f:
        f.write(content)

def run_task_on_server(
    task_name: str,
    sk_path: str,
    input_path: str,
    output_path: str,
    url: str="http://localhost:82"):

    """Runs an FHE task on a server.

    This function performs the following steps:
    1. Uploads a server key to the server.
    2. Uploads encrypted input data and starts a task.
    3. Polls the server periodically until the task is complete or timeout is reached.
    4. Retrieves and saves the result (streamed file or JSON response, based on the task
    configuration file).

    Args:
        task_name (str): Name of the task to execute.
        sk_path (str): Path of the serialized server key file.
        input_path (str): Path of the encrypted input file.
        output_path (str): Path where the streamed output file will be saved.
        url (str): URL of the task server, default is "http://localhost:82".

    Returns:
        (uid, task_id): tuple, representing the unique user identifier and task identifier.

    Raises:
        RuntimeError
            If the server returns an HTTP error.
        TimeoutError
            If the task does not complete within the TIME_OUT duration.
    """
   
    # 1. Upload the server key
    with open(sk_path, "rb") as f:
        response = requests.post(f"{url}/add_key", files={"key": f}, data={"task_name": task_name})
        response.raise_for_status()
        uid = response.json()["uid"]
        print(f"[run_task_on_server | UID={uid}] Uploading server key: {sk_path}")
    
    # 2. Start task
    with open(input_path, "rb") as f:
        response = requests.post(f"{url}/start_task", files={"encrypted_input": f}, data={"uid": uid, "task_name": task_name})
        response.raise_for_status()
        task_id = response.json()["task_id"]
        print(f"[run_task_on_server | TASK_ID={task_id}] Sending encrypted input: {input_path}")

    # 3. Poll for result   
    for attempt in range(TIME_OUT):
        time.sleep(POLL_INTERVAL)
        response = requests.get(f"{url}/get_task_result", params={"task_name": task_name, "task_id": task_id, "uid": uid})

        if response.status_code == 200:
            config_output_files = TASK_CONFIG["tasks"][task_name]["output_files"]
            if "Content-Disposition" in response.headers:
                print(f"✅ [run_task_on_server] Streaming result received! Saving output in {output_path}...")
                save_output_file(output_path, response.content)
                return uid, task_id
            
            data = response.json()
            status = data.get("status")
            
            if status not in ["success", "completed"]:
                print(f"⏳[run_task_on_server] Poll attempt {attempt + 1}/{TIME_OUT} (task in progress)")
                continue

            if status in ["success", "completed"]:
                print(f"✅ [run_task_on_server] JSON result, {status=}")
                
                for config in config_output_files:
                    key = config["key"]
                    filename = config["filename"].replace("{uid}", f"test_{task_name}")   
                    save_output_file(f"./project/uploaded_files/{filename}", base64.b64decode(data[key]))
                return uid, task_id
                        
        elif response.status_code >= 400:
            error_message = f"[run_task_on_server] Error {response.status_code}: {response.text}"
            raise RuntimeError(error_message)
        
    raise TimeoutError("Task did not complete within timeout")

