import time
import sleep_quality

def test_good_sleep():
    """Test the sleep quality function for a good sleep scenario (score > 3)."""
    print("\nTest good sleep scenario...")
    start_time = time.time()
    score = sleep_quality.test_good_sleep()
    end_time = time.time() - start_time
    print(f"Execution time: {end_time:.2f} seconds")
    print(f"Good sleep score: {score}")
    assert isinstance(score, int), "Score should be an integer."
    assert score >= 3, f"Expected score > 3 for good sleep, got {score}."

def test_bad_sleep():
    """Test the sleep quality function for a bad sleep scenario (score < 3)."""
    print("\nTest bad sleep scenario...")
    start_time = time.time()
    score = sleep_quality.test_bad_sleep()
    end_time = time.time() - start_time
    print(f"Execution time: {end_time:.2f} seconds")
    print(f"Bad sleep score: {score}")
    assert isinstance(score, int), "Score should be an integer."
    assert score <= 3, f"Expected score < 3 for bad sleep, got {score}."
