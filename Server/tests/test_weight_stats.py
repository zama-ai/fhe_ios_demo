import os
import time

import numpy as np

import weight_stats

from utils import *


def test_weight_stats():
    print("\n Run test_weight_stats")
    
    weights_list = [68.0, 65.0, 69.0, 70.0, 70.5]
    
    uid = "test_weight_stats"
    ck_path = f"{UPLOAD_FOLDER}/{uid}.clientKey"
    serverkey_path = f"{UPLOAD_FOLDER}/{uid}.serverKey"
    input_path = f"{UPLOAD_FOLDER}/{uid}.weight_stats.input.fheencrypted"
    
    start_time = time.time()
    
    weight_stats.generate_files(weights_list, uid)

    assert os.path.exists(serverkey_path), f"Missing file: {serverkey_path=}"
    assert os.path.exists(ck_path), f"Missing file: {ck_path=}"
    assert os.path.exists(input_path), f"Missing file: {input_path=}"

    _, _, output_paths = run_task_on_server("weight_stats", serverkey_path, input_path, prefix=uid)

    assert all([os.path.exists(p) for p in output_paths]), f"Missing file: {ck_path=}"

    # Decrypt and check results
    decrypted_avg, decrypted_min, decrypted_max = weight_stats.decrypt(str(ck_path), *(str(p) for p in output_paths))
    assert np.mean(weights_list) * 10 == decrypted_avg, f"Expected avg: {np.mean(weights_list)}, got: {decrypted_avg}"
    assert np.min(weights_list) * 10 == decrypted_min, f"Expected min: {np.min(weights_list)}, got: {decrypted_min}"
    assert np.max(weights_list) * 10 == decrypted_max, f"Expected max: {np.max(weights_list)}, got: {decrypted_max}"

    end_time = time.time() - start_time
    print(f"Test execution time: {end_time:.2f} seconds")

