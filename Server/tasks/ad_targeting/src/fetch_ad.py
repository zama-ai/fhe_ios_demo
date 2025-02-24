#!/usr/bin/env python3

import pickle as pkl
import sys

import concrete_ml_extensions as fhext
import numpy as np
import time


def main():
    if len(sys.argv) < 2:
        print("No arguments provided.")
        return

    uid = sys.argv[1]

    print("\n========\n")
    print(f"CLI Args: {uid}")

    sk_path = f"uploaded_files/{uid}.serverKey"
    input_path = f"uploaded_files/{uid}.fetch_ad.input.fheencrypted"
    output_path = f"uploaded_files/{uid}.fetch_ad.relevent_ad.output.fheencrypted"
    output_path_metadata = f"uploaded_files/{uid}.fetch_ad.metadata.output.fheencrypted"

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
    device = "cuda" if fhext.is_cuda_enabled() and fhext.is_cuda_available() else "cpu" 
    start_time = time.time()
    deserialized_encrypted_a = fhext.EncryptedMatrix.deserialize(serialized_ciphertext)
    tot_server_time = time.time() - start_time
    print(f"Server time without serialization {tot_server_time}s on {device}. ", end='')

    # Load clear data
    with open("data/ads_numeric_representation.pkl", "rb") as f:
        ads = pkl.load(f)
    
    print(ads.shape, "ads.shape")

    # Unsigned integers [0, 2⁶⁴ - 1]
    CRYPTO_DTYPE = np.uint64
    ads = ads.astype(CRYPTO_DTYPE)

    # Perform matrix multiplication
    relevent_ad = fhext.matrix_multiplication(
        encrypted_matrix=deserialized_encrypted_a, data=ads, compression_key=compression_key
    )

    # Save the encrypted result
    with open(output_path, "wb") as binary_file:
        binary_file.write(relevent_ad.serialize())

    print("Successful end")
    print("\n========\n")

    return relevent_ad.serialize()


if __name__ == "__main__":
    main()
