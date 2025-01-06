"""Deployment server with individual routes for each task.

Routes:
    - /add_key
    - /tasks
    - /{task_name}
"""

import io
import base64
import os
import uuid
from pathlib import Path
from typing import Dict, Callable, Any

import uvicorn
from fastapi import FastAPI, UploadFile, Form, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
import yaml
import subprocess

app = FastAPI(debug=False)

FILES_FOLDER = Path(__file__).parent / "uploaded_files"
FILES_FOLDER.mkdir(exist_ok=True)  # Ensure the directory exists

# Load task configuration
CONFIG_FILE = Path(__file__).parent / "tasks.yaml"
with open(CONFIG_FILE, 'r') as file:
    config = yaml.safe_load(file)

tasks = config.get('tasks', {})

print(f"Tasks: {tasks}")
PORT = os.environ.get("PORT", "5000")

@app.get("/")
def read_root():
    return {
        "message": "Welcome to fhe_ios_demo_server!",
        "available_routes": ["/add_key", "/tasks"]
    }

@app.post("/add_key")
async def add_key(key: UploadFile):
    """Save the evaluation key.

    Arguments:
        key (UploadFile): evaluation key

    Returns:
        Dict[str, str]
            - uid: a unique identifier
    """
    uid = 727 # str(uuid.uuid4())
    
    # Write uploaded ServerKey to disk
    file_content = await key.read()
    file_path = FILES_FOLDER / f"{uid}.serverKey"
    with open(file_path, "wb") as f:
        f.write(file_content)

    return {"uid": uid}


@app.get("/tasks")
def get_tasks():
    """List available tasks based on configuration.

    Returns:
        Dict[str, List[str]]: Available task names
    """
    return {"tasks": list(tasks.keys())}


def create_task_endpoint(task_name: str, task_config: Dict[str, Any]) -> Callable:
    """Creates an endpoint function for a given task.

    Args:
        task_name (str): The name of the task.
        task_config (Dict[str, Any]): The configuration for the task.

    Returns:
        Callable: The endpoint function.
    """

    binary = task_config["binary"]               # ex: "python" ou "sleep_quality"
    script = task_config.get("script", None)     # ex: "ad_targeting.py" ou None

    response_type = task_config.get('response_type', 'stream')
    output_files = task_config.get('output_files', [])

    async def task_endpoint(input: UploadFile, uid: str = Form(...)):
        """Handle the specific task.

        Arguments:
            input (UploadFile): Input file for the task.
            uid (str): UID of the public key to use.

        Returns:
            StreamingResponse or JSONResponse: Result of the task.
        """
        # Use input_filename from task_config if specified, otherwise default
        input_filename_template = task_config.get('input_filename', "{uid}.{task}.input.fheencrypted")
        input_filename = input_filename_template.format(uid=uid, task=task_name)
        input_file_path = FILES_FOLDER / input_filename
        # Save the input file
        file_content = await input.read()
        with open(input_file_path, "wb") as f:
            f.write(file_content)


        if script:
            # => Cas script Python
            #    python ad_targeting.py <uid>
            commandline = [binary, script, uid]
        else:
            # Execute the corresponding Rust binary using subprocess
            #    ./add_42 <uid>
            commandline = [f'./{binary}', uid]

        try:
            result = subprocess.run(
                commandline,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
                text=True
            )

            if result.stderr:
                print(f"Error from {binary}:\n{result.stderr}")
        except subprocess.CalledProcessError as e:
            print(f"Error executing {binary}: {e.stderr}")
            raise HTTPException(status_code=500, detail=f"Error executing {binary}: {e.stderr}")

        # Handle outputs based on the configuration
        if response_type == 'stream':
            # Expect a single output file
            if not output_files:
                raise HTTPException(status_code=500, detail="No output files defined for streaming response.")

            output_file_config = output_files[0]
            output_filename_template = output_file_config['filename']
            output_filename = output_filename_template.format(uid=uid, task=task_name)
            output_file_path = FILES_FOLDER / output_filename

            if not output_file_path.exists():
                print(f"Output file {output_filename} not found.")
                raise HTTPException(status_code=500, detail=f"Output file {output_filename} not found.")

            with open(output_file_path, "rb") as f:
                data = f.read()
            
            return StreamingResponse(
                io.BytesIO(data),
                media_type="application/octet-stream",
                headers={"Content-Disposition": f"attachment; filename={output_filename}"}
            )
        

        elif response_type == 'json':
            response_data = {}
            for output_file_config in output_files:
                filename_template = output_file_config['filename']
                output_filename = filename_template.format(uid=uid, task=task_name)
                key = output_file_config.get('key', output_filename)
                response_format = output_file_config.get('response_type', 'base64')

                output_file_path = FILES_FOLDER / output_filename
                if not output_file_path.exists():
                    raise HTTPException(status_code=500, detail=f"Output file {output_filename} not found.")

                with open(output_file_path, "rb") as f:
                    data = f.read()

                if response_format == 'base64':
                    encoded_data = base64.b64encode(data).decode('utf-8')
                    response_data[key] = encoded_data
                else:
                    response_data[key] = data.decode('utf-8')

            return JSONResponse(content=response_data)
        else:
            raise HTTPException(status_code=500, detail=f"Unsupported response type: {response_type}")

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
        description=f"Process input data using the {task_name} task."
    )


if __name__ == "__main__":
    print("******** Launch Unicorn Server ******** ")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(PORT),
        # ssl_keyfile="/project/key.pem",
        # ssl_certfile="/project/cert.pem"
    )