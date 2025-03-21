import os
import time

import numpy as np

import weight_stats

def test_weight_stats():
    print("\nweight_stats module loaded, calling compute_stats()...")
    
    weights_list = [68.0, 65.0, 69.0, 70.0, 70.5]
    
    uid = "test_weight_stats"
    
    ck_path = f"./project/uploaded_files/{uid}.clientKey"
    sk_path = f"./project/uploaded_files/{uid}.serverKey"

    input_path = f"./project/uploaded_files/{uid}.weight_stats.input.fheencrypted"
    
    output_avg_path = f"./project/uploaded_files/{uid}.outputAvg.weight_stats.fheencrypted"
    output_min_path = f"./project/uploaded_files/{uid}.outputMin.weight_stats.fheencrypted"
    output_max_path = f"./project/uploaded_files/{uid}.outputMax.weight_stats.fheencrypted"
    
    start_time = time.time()
    
    weight_stats.generate_files(weights_list, uid)

    assert os.path.exists(sk_path), f"Missing file: {sk_path=}"
    assert os.path.exists(ck_path), f"Missing file: {ck_path=}"
    assert os.path.exists(input_path), f"Missing file: {input_path=}"
    
    weight_stats.run(uid)

    assert os.path.exists(output_avg_path), f"Missing file: {output_avg_path=}"
    assert os.path.exists(output_min_path), f"Missing file: {output_min_path=}"
    assert os.path.exists(output_max_path), f"Missing file: {output_max_path=}"

    # Decrypt and check results
    decrypted_avg, decrypted_min, decrypted_max = weight_stats.decrypt_weight_stats(uid)

    assert np.mean(weights_list) * 10 == decrypted_avg, f"Expected avg: {np.mean(weights_list)}, got: {decrypted_avg}"
    assert np.min(weights_list) * 10 == decrypted_min, f"Expected min: {np.min(weights_list)}, got: {decrypted_min}"
    assert np.max(weights_list) * 10 == decrypted_max, f"Expected max: {np.max(weights_list)}, got: {decrypted_max}"

    end_time = time.time() - start_time
    print(f"Test execution time: {end_time:.2f} seconds")

