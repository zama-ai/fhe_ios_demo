#!/usr/bin/env python3

import pickle as pkl
import sys

import concrete_ml_extensions as fhext
import numpy as np

from time import time

def main():
    if len(sys.argv) < 2:
        print("No arguments provided.")
        return

    uid = sys.argv[1]

    print("\n========\n")

    device = "cuda" if fhext.is_cuda_enabled() and fhext.is_cuda_available() else "cpu"

    print(f"CLI Args: {uid}")
    print(f"Device: {device}")

    sk_path = f"/project/uploaded_files/{uid}.serverKey"
    input_path = f"/project/uploaded_files/{uid}.ad_targeting.input.fheencrypted"
    output_path = f"/project/uploaded_files/{uid}.ad_targeting.output.fheencrypted"

    print(f"Paths:\n" f"\tsk: {sk_path}\n" f"\tin: {input_path}\n" f"\tout: {output_path}")

    # Load the serialized key
    with open(sk_path, "rb") as binary_file:
        serialized_ckey = binary_file.read()

    # Deserialize compressed key
    compression_key = fhext.deserialize_compression_key(serialized_ckey)

    print("ServerKey set")

    # Load the encrypted input matrix
    with open(input_path, "rb") as binary_file:
        serialized_ciphertext = binary_file.read()

    # Deserialize the encrypted matrix
    deserialized_encrypted_a = fhext.EncryptedMatrix.deserialize(serialized_ciphertext)

    # Load clear data
    with open("data/onehot_ads.pkl", "rb") as f:
        b = pkl.load(f).T

    # Unsigned integers [0, 2⁶⁴ - 1]
    CRYPTO_DTYPE = np.uint64
    b = b.astype(CRYPTO_DTYPE)

    start_time = time()
    # Perform matrix multiplication
    encrypted_scores = fhext.matrix_multiplication(
        encrypted_matrix=deserialized_encrypted_a, data=b, compression_key=compression_key
    )
    end_time = time() - start_time
    print(f"Ad targeting use-case: execution time = {end_time:.2f}s with {device =}")

    # Save the encrypted result
    with open(output_path, "wb") as binary_file:
        binary_file.write(encrypted_scores.serialize())

    print("Successful end")
    print("\n========\n")

    return encrypted_scores.serialize()


if __name__ == "__main__":
    main()
