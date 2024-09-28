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
from fastapi import FastAPI, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, StreamingResponse

if __name__ == "__main__":
    app = FastAPI(debug=False)

    FILE_FOLDER = Path(__file__).parent

    PORT = os.environ.get("PORT", "5000")

    KEYS: Dict[str, bytes] = {}

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

        KEYS[uid] = await key.read()
        return {"uid": uid}

    @app.post("/compute")
    async def compute(model_input: UploadFile, uid: str = Form()):
        """Compute the circuit over encrypted input.

        Arguments:
            model_input (UploadFile): input of the circuit
            uid (str): uid of the public key to use

        Returns:
            StreamingResponse: the result of the circuit
        """

        # Using the evaluation key from the client
        key = KEYS[uid]

        # FIXME: do real computations, by replacing the commandline by the Rust compiled binary
        commandline = 'ls'
        stream = os.popen(commandline)
        output_from_commandline = stream.read()

        encrypted_results = f"{output_from_commandline}".encode('UTF-8')

        return StreamingResponse(
            io.BytesIO(encrypted_results),
        )

    uvicorn.run(app, host="0.0.0.0", port=int(PORT))
