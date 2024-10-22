"""Deployment server.

Routes:
    - Add a key
    - Compute
"""

import io
import os
import uuid
from pathlib import Path
from typing import Dict

import uvicorn
from fastapi import FastAPI, UploadFile, Form
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse

if __name__ == "__main__":
    app = FastAPI(debug=False)

    FILES_FOLDER = Path(__file__).parent / "uploaded_files"
    FILES_FOLDER.mkdir(exist_ok=True)  # Ensure the directory exists

    PORT = os.environ.get("PORT", "5000")

    @app.post("/add_key")
    async def add_key(key: UploadFile):
        """Save the evaluation key.

        Arguments:
            key (UploadFile): evaluation key

        Returns:
            Dict[str, str]
                - uid: uid a personal uid
        """
        uid = str(uuid.uuid4())

        # Write uploaded ServerKey to disk
        file_content = await key.read()
        file_path = FILES_FOLDER / f"{uid}.serverKey"
        with open(file_path, "wb") as f:
            f.write(file_content)
    
        return {"uid": uid}

    @app.post("/compute")
    async def compute(input: UploadFile, uid: str = Form()):
        """Compute the circuit over encrypted input.

        Arguments:
            model_input (UploadFile): input of the circuit
            uid (str): uid of the public key to use

        Returns:
            StreamingResponse: the result of the circuit
        """

        # Write uploaded input to disk
        file_content = await input.read()
        file_path = FILES_FOLDER / f"{uid}.input.fheencrypted"
        with open(file_path, "wb") as f:
            f.write(file_content)

        commandline = f'./rust_binary {uid}'
        stream = os.popen(commandline)
        output_from_commandline = stream.read()
        print(output_from_commandline)
        
        file_path = FILES_FOLDER / f"{uid}.output.fheencrypted"

        with open(file_path, "rb") as f:
            data = f.read()
            
        encrypted_results = data

        return StreamingResponse(
            io.BytesIO(encrypted_results),
        )

    @app.post("/stats")
    async def stats(input: UploadFile, uid: str = Form()):
        """Get stats (min/max/avg) over encrypted input (array of int).

        Arguments:
            model_input (UploadFile): input array
            uid (str): uid of the public key to use

        Returns:
            StreamingResponse: the result of the circuit
        """

        # Write uploaded input to disk
        file_content = await input.read()
        file_path = FILES_FOLDER / f"{uid}.inputList.fheencrypted"
        with open(file_path, "wb") as f:
            f.write(file_content)

        commandline = f'./rust_array_stats {uid}'
        stream = os.popen(commandline)
        output_from_commandline = stream.read()
        print(output_from_commandline)

        avg_path = FILES_FOLDER / f"{uid}.outputAvg.fheencrypted"
        min_path = FILES_FOLDER / f"{uid}.outputMin.fheencrypted"
        max_path = FILES_FOLDER / f"{uid}.outputMax.fheencrypted"

        with open(avg_path, "rb") as f:
            avg = f.read()
            
        with open(min_path, "rb") as f:
            min = f.read()
        
        with open(max_path, "rb") as f:
            max = f.read()
        
        response_data = {
            "min": min,
            "max": max,
            "avg": avg
        }

        return JSONResponse(content=response_data)

    uvicorn.run(app, host="0.0.0.0", port=int(PORT))
