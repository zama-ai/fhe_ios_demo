import time
import weight_stats

def test_weight_stats():
    print("\nweight_stats module loaded, calling compute_stats()...")
    start_time = time.time()
    weight_stats.compute_stats()
    end_time = time.time() - start_time
    print(f"Test execution time: {end_time:.2f} seconds")
    