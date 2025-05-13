import os
import time
import sleep_quality

from utils import *


def run_sleep_quality(night, uid):
    """Test the sleep quality function for a good sleep scenario (score > 3)."""

    ck_path = f"{UPLOAD_FOLDER}/{uid}.clientKey"
    serverkey_path = f"{UPLOAD_FOLDER}/{uid}.serverKey"
    input_path = f"{UPLOAD_FOLDER}/{uid}.sleep_quality.input.fheencrypted"

    start_time = time.time()

    sleep_quality.generate_files(night, uid)
    
    assert os.path.exists(serverkey_path), f"Missing file: {serverkey_path=}"
    assert os.path.exists(ck_path), f"Missing file: {ck_path=}"
    assert os.path.exists(input_path), f"Missing file: {input_path=}"

    _, _, output_path = run_task_on_server("sleep_quality", serverkey_path, input_path, prefix=uid)

    assert output_path[0].exists(), f"Missing file: {output_path=}"

    # Decrypt and check results
    score = sleep_quality.decrypt(str(ck_path), str(output_path[0]))

    end_time = time.time() - start_time
    print(f"Execution time: {end_time:.2f} seconds")
    
    assert isinstance(score, int), "Score should be an integer."
    return score


def test_bad_night():
    print("\nRun run_sleep_quality for bad sleep scenario...")

    bad_night = [
        (0,   0, 120),
        (3, 120, 150),
        (0, 150, 210),
        (4, 210, 240),
        (0, 240, 300)
    ]

    uid = "test_bad_night"
    score = run_sleep_quality(bad_night, uid)
    assert score == 5, f"Expected score for a bad night is 5, but got `{score}`"


def test_good_night():
    print("\nRun run_sleep_quality for good sleep scenario...")

    good_night = [
        (0, 0, 210),
        (0, 240, 570),
        (2, 0, 30),
        (5, 30, 60),
        (3, 60, 90),
        (4, 90, 120),
        (3, 120, 150),
        (5, 150, 180),
        (2, 180, 240),
        (3, 240, 300),
        (5, 300, 330),
        (4, 330, 390),
        (2, 390, 420),
        (5, 420, 450),
        (4, 450, 510),
        (3, 510, 540),
        (5, 540, 570)
]   
    uid = "test_good_night"
    score = run_sleep_quality(good_night, uid)
    assert score == 1, f"Expected score for a good night is 1, but got `{score}`"
