"""Client script.
"""

import io
import os
from pathlib import Path

import grequests
import numpy
import requests
from sklearn.datasets import load_breast_cancer
from tqdm import tqdm

URL = os.environ.get("URL", f"https://api.zama.ai")

STATUS_OK = 200
ROOT = Path(__file__).parent / "client"
ROOT.mkdir(exist_ok=True)

if __name__ == "__main__":

    ### Real part

    # FIXME: get the real key from the iOS application
    serialized_evaluation_keys = b"fixme: some evaluation key"

    # Step 1: save keys on the server
    if True:

        response = requests.post(
            f"{URL}/add_key", files={"key": io.BytesIO(initial_bytes=serialized_evaluation_keys)}
        )

        assert response.status_code == STATUS_OK

        # This is the ID of the key, such that next time one can reuse it
        uid = response.json()["uid"]

        print(f"This user ID will be {uid}")

    # FIXME: get a real encrypted value
    encrypted_input = b"fime: some encrypted input"

    # Step 2: launch FHE computations
    if True:

        inference = grequests.post(
            f"{URL}/compute",
            files={
                "input": io.BytesIO(encrypted_input),
            },
            data={
                "uid": uid,
            },
        )

        result = grequests.map([inference])[0]

        if result is None:
            raise ValueError("Result is None, probably due to a crash on the server side.")

        assert result.status_code == STATUS_OK, "Failure in the 'compute' function"

        # print(f"\nResults:\n{result.content.decode('UTF-8')}")

    # End
    print("Successful end")
