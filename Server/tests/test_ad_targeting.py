import time 
import json

import pickle as pkl
import numpy as np
import pytest

import concrete_ml_extensions as fhext

from utils import *


# Unsigned integers [0, 2⁶⁴ - 1]
CRYPTO_DTYPE = np.uint64
BITS_RESERVED_FOR_COMPUTATION=11

@pytest.fixture
def generate_fhext_params():
    """Initialize cryptographic parameters."""
    params_json = json.loads(fhext.default_params())
    params_json["bits_reserved_for_computation"] = BITS_RESERVED_FOR_COMPUTATION
    crypto_params = fhext.MatmulCryptoParameters.deserialize(json.dumps(params_json))
    return crypto_params


@pytest.fixture
def generate_fhext_keys(generate_fhext_params):
    """Generate private and evaluation keys."""
    pkey, eval_key = fhext.create_private_key(generate_fhext_params)
    return pkey, eval_key


def encrypt(random_input, crypto_params, pkey):
    random_input = random_input.astype(CRYPTO_DTYPE)
    encrypted_input = fhext.encrypt_matrix(
        pkey=pkey, crypto_params=crypto_params, data=random_input
    )
    return encrypted_input


def decrypt(output_path, pkey, crypto_params):

    # Read the encrypted file, computed in the serve
    with open(output_path, "rb") as binary_file:
        encrypted_serialized_output = binary_file.read()
        encrypted_output = fhext.CompressedResultEncryptedMatrix.deserialize(encrypted_serialized_output)

    # Decrypt the result
    decrypted_output = fhext.decrypt_matrix(
        encrypted_output,
        pkey,
        crypto_params,
        num_valid_glwe_values_in_last_ciphertext=858,
    ).astype(np.int64)[0]
    
    return decrypted_output


def test_ad_targeting(generate_fhext_params, generate_fhext_keys):
    
    print("\nRun test_ad_targeting")
    
    start_time = time.time()
    
    uid = "test_ad_targeting"
    serverkey_path = f"./project/uploaded_files/{uid}.serverKey"
    input_path = f"./project/uploaded_files/{uid}.ad_targeting.input.fheencrypted"
    output_path = f"./project/uploaded_files/{uid}.ad_targeting.output.fheencrypted"
    data_path = "./tasks/ad_targeting/data/onehot_ads.pkl"
    
    crypto_params = generate_fhext_params
    
    pkey, ckey = generate_fhext_keys
            
    with open(data_path, "rb") as f:
        clear_matrix = pkl.load(f)
        clear_matrix = clear_matrix.astype(CRYPTO_DTYPE)

    random_input = np.random.randint(0, 2, (1, 62))

    encrypted_input = encrypt(random_input, crypto_params, pkey)
    
    with open(serverkey_path, "wb") as binary_file:
        binary_file.write(ckey.serialize())
                
    with open(input_path, "wb") as binary_file:
        binary_file.write(encrypted_input.serialize())
    
    # monkeypatch.setattr(sys, "argv", ["ad_targeting.py", str(uid)])
    # ad_targeting.main()
    
    run_task_on_server("ad_targeting", serverkey_path, input_path, output_path)

    decrypted_output = decrypt(output_path, pkey, crypto_params).reshape(1, clear_matrix.shape[0])
    expected_output = np.dot(random_input, clear_matrix.T).reshape(1, clear_matrix.shape[0])
    
    print(f"Expected output  : {expected_output}")
    print(f"Decrypted output : {decrypted_output}")
    
    assert np.array_equal(decrypted_output, expected_output)
    
    end_time = time.time() - start_time
    print(f"Test execution time: {end_time:.2f} seconds")
