import os
import time
import sleep_quality

def run_sleep_quality(night, uid):
    """Test the sleep quality function for a good sleep scenario (score > 3)."""
    print("\nTest good sleep scenario...")
    
    start_time = time.time()

    ck_path = f"./project/uploaded_files/{uid}.clientKey"
    sk_path = f"./project/uploaded_files/{uid}.serverKey"

    input_path = f"./project/uploaded_files/{uid}.sleep_quality.input.fheencrypted"
    output_path = f"./project/uploaded_files/{uid}.sleep_quality.output.fheencrypted"

    sleep_quality.generate_files(night, uid)
    
    assert os.path.exists(sk_path), f"Missing file: {sk_path=}"
    assert os.path.exists(ck_path), f"Missing file: {ck_path=}"
    assert os.path.exists(input_path), f"Missing file: {input_path=}"
    
    sleep_quality.run(uid)
    
    assert os.path.exists(output_path), f"Missing file: {output_path=}"

    # Decrypt and check results
    score = sleep_quality.decrypt(uid)

    end_time = time.time() - start_time
    print(f"Execution time: {end_time:.2f} seconds")
    
    assert isinstance(score, int), "Score should be an integer."
    return score


def test_bad_night():
    bad_night = [
        (0,   0, 120), # 3
    ]
    uid = "test_bad_night"
    score = run_sleep_quality(bad_night, uid)
    print("Bad night ===", score)
    

def test_good_night():
    good_night = [
#        (3, 0, 150),   # asleepCore
        (4, 150, 710), # asleepDeep # 2
 #       (5, 710, 800), # asleepREM
    ]
    uid = "test_good_night"
    score = run_sleep_quality(good_night, uid)
    print("Good night ===", score)
    