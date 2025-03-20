import json
import pickle as pkl
import sys
import os
from pathlib import Path

import numpy as np
import pytest

import concrete_ml_extensions as fhext

ROOT_DIR = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT_DIR / "tasks" / "ad_targeting" / "src"
sys.path.insert(0, str(SRC_DIR))

import ad_targeting


# Unsigned integers [0, 2⁶⁴ - 1]
CRYPTO_DTYPE = np.uint64


@pytest.fixture
def generate_fhext_params():
    """Initialize cryptographic parameters."""
    params_json = json.loads(fhext.default_params())
    params_json["bits_reserved_for_computation"] = 11
    crypto_params = fhext.MatmulCryptoParameters.deserialize(json.dumps(params_json))
    return crypto_params


@pytest.fixture
def generate_fhext_keys(generate_fhext_params):
    """Generate private and evaluation keys."""
    pkey, eval_key = fhext.create_private_key(generate_fhext_params)
    return pkey, eval_key


def generate_random_input():    
    random_input = np.random.randint(0, 2, (1, 62))
    return random_input


def encrypt_random_input(random_input, crypto_params, pkey):
    random_input = random_input.astype(CRYPTO_DTYPE)
    encrypted_input = fhext.encrypt_matrix(
        pkey=pkey, crypto_params=crypto_params, data=random_input
    )
    return encrypted_input


def decrypt_output(uid, pkey, crypto_params):
    output_path = f"uploaded_files/{uid}.ad_targeting.output.fheencrypted"

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


def test_local_ad_targeting(generate_fhext_params, generate_fhext_keys, monkeypatch):
    
    UID = 727

    folder = Path("uploaded_files")
    folder.mkdir(parents=True, exist_ok=True)
    
    server_key_path = folder / f"{UID}.serverKey"
    encrypted_input_path = folder / f"{UID}.ad_targeting.input.fheencrypted"
    encrypted_output_path = folder / f"{UID}.ad_targeting.output.fheencrypted"
    data_path = Path(__file__).parent.parent / "tasks" / "ad_targeting" / "data"
    
    crypto_params = generate_fhext_params
    pkey, ckey = generate_fhext_keys
        
    file_path = os.path.join(data_path, "onehot_ads.pkl")
    with open(file_path, "rb") as f:
        clear_matrix = pkl.load(f)
        clear_matrix = clear_matrix.astype(CRYPTO_DTYPE)

    random_input = generate_random_input()
    encrypted_input = encrypt_random_input(random_input, crypto_params, pkey)
    
    with open(server_key_path, "wb") as binary_file:
        binary_file.write(ckey.serialize())
        
    with open(encrypted_input_path, "wb") as binary_file:
        binary_file.write(encrypted_input.serialize())
    
    monkeypatch.setattr(sys, "argv", ["ad_targeting.py", str(UID)])
    ad_targeting.main()

    decrypted_output = decrypt_output(UID, pkey, crypto_params).reshape(1, clear_matrix.shape[0])
    expected_output = np.dot(random_input, clear_matrix.T).reshape(1, clear_matrix.shape[0])
    
    assert np.array_equal(decrypted_output, expected_output)

    server_key_path.unlink(missing_ok=True)
    encrypted_input_path.unlink(missing_ok=True)
    encrypted_output_path.unlink(missing_ok=True)
