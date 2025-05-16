import concurrent.futures
import time
import random
import os
import uuid
import shutil
from pathlib import Path
import sys
from dotenv import load_dotenv

# Ensure the tests directory is in the Python path to find utils
sys.path.insert(0, str(Path(__file__).parent.resolve()))

# Load environment configuration
environment = os.getenv('environment', 'dev')
env_file = f".env_{environment}"
if not os.path.exists(env_file):
    print(f"❌ Environment file {env_file} not found!")
    sys.exit(1)
load_dotenv(env_file)

import utils as test_utils # This will load TASK_CONFIG etc.

# Configuration
NUM_CONCURRENT_USERS = 100          # Number of simulated concurrent user workflows
TEST_DURATION_SECONDS = 60 * 60     # How long the main test loop should run
TASK_TYPES = ["ad_targeting", "sleep_quality", "weight_stats"]

# Directory where generate_stress_data.py places the unique key/input pairs
STRESS_DATA_POOL_DIR = Path("./project/uploaded_files/stress_data_pool")

# Statistics
stats = {
    "workflows_initiated": 0,
    "tasks_completed_successfully": 0,
    "tasks_failed": 0,
    "total_successful_task_duration": 0.0,
    "errors": [],
    "data_pool_exhausted_count": 0,
}

def record_error(task_name, client_uid, error_message, server_uid=None, task_id=None):
    """Records an error encountered during a task."""
    stats["tasks_failed"] += 1
    error_tuple = (task_name, client_uid, server_uid, task_id, str(error_message)[:200])
    stats["errors"].append(error_tuple)

available_data_files = {}

def load_data_pool():
    """Loads pre-generated server key and input data file pairs from the STRESS_DATA_POOL_DIR."""
    print(f"Loading data pool from: {STRESS_DATA_POOL_DIR}")
    if not STRESS_DATA_POOL_DIR.exists():
        print(f"ERROR: Stress data pool directory not found: {STRESS_DATA_POOL_DIR}")
        print("Please run 'python tests/generate_stress_data.py' first.")
        exit(1)

    for task_name in TASK_TYPES:
        task_pool_dir = STRESS_DATA_POOL_DIR / task_name
        if not task_pool_dir.exists():
            print(f"Warning: No data pool found for task '{task_name}' in {task_pool_dir}")
            available_data_files[task_name] = []
            continue

        server_keys = sorted(list(task_pool_dir.glob("*.serverKey")))

        pairs = []
        for sk_path in server_keys:
            prefix = sk_path.name.replace(".serverKey", "")
            expected_input_name = f"{prefix}.{task_name}.input.fheencrypted"
            input_path_match = task_pool_dir / expected_input_name
            if input_path_match.exists():
                pairs.append((sk_path, input_path_match))
            else:
                print(f"Warning: Missing input file for server key {sk_path.name} in {task_pool_dir}")

        available_data_files[task_name] = pairs
        if not pairs:
            print(f"Warning: No valid key/input pairs found for task '{task_name}' in {task_pool_dir}")
        else:
            print(f"Loaded {len(pairs)} key/input pairs for task '{task_name}'.")

    if not any(available_data_files.values()):
        print("ERROR: No data found in the stress data pool for any configured task type. Exiting.")
        exit(1)


def get_random_data_pair(task_name):
    """Gets a random (sk_path, input_path) pair for the task.
        Returns None if pool is empty for that task.
    """
    if task_name not in available_data_files or not available_data_files[task_name]:
        stats["data_pool_exhausted_count"] += 1
        print(f"Warning: Data pool exhausted or not available for task '{task_name}'.")
        return None, None

    return random.choice(available_data_files[task_name])


def run_single_user_workflow(user_id_num):
    """Simulates a single user performing a full task lifecycle using pre-generated unique data."""
    stats["workflows_initiated"] += 1
    workflow_start_time = time.monotonic()

    task_name = random.choice(TASK_TYPES)

    # Get paths to a pre-generated server key and its corresponding input data
    user_server_key_path, user_input_data_path = get_random_data_pair(task_name)

    if not user_server_key_path or not user_input_data_path:
        record_error(task_name, f"user_{user_id_num}_datapool_fail", "Failed to get data pair from pool.")
        return {"status": "error", "details": "Data pool exhausted for task."}

    # The "client_side_file_uid" is derived from the pre-generated file names' prefix
    client_side_file_uid = user_server_key_path.name.replace(".serverKey", "")

    server_generated_uid = None
    task_id = None
    output_paths_final = None

    try:
        # Add Key to server
        server_generated_uid = test_utils.add_key_api(task_name, str(user_server_key_path))
        if not server_generated_uid or not test_utils.ID_PATTERN.match(server_generated_uid):
            raise Exception(f"add_key_api failed or returned invalid UID: {server_generated_uid}")

        # Start Task on server
        task_id = test_utils.start_task_api(server_generated_uid, task_name, str(user_input_data_path))
        if not task_id or not test_utils.ID_PATTERN.match(task_id):
            raise Exception(f"start_task_api failed or returned invalid task_id: {task_id}")

        # Poll for task result and get output file paths
        output_paths_final = test_utils.poll_task_result_until_ready(
            server_generated_uid, task_id, task_name, prefix=None
        )

        if not output_paths_final or not all(p.exists() for p in output_paths_final):
            raise Exception(f"Output files not found or incomplete after polling: {output_paths_final}")

        stats["tasks_completed_successfully"] += 1
        task_duration = time.monotonic() - workflow_start_time
        stats["total_successful_task_duration"] += task_duration
        return {"status": "success", "duration": task_duration}

    except Exception as e:
        record_error(task_name, client_side_file_uid, e, server_generated_uid, task_id)
        return {"status": "error", "details": str(e)}
    finally:
        # Remove output files generated by this workflow run.
        # Input files from the pool are NOT deleted, allowing reuse.
        if output_paths_final:
            for p in output_paths_final:
                if p.exists():
                    p.unlink(missing_ok=True)
        elif server_generated_uid:
            stream_out_guess = test_utils.UPLOAD_FOLDER / f"{server_generated_uid}.{task_name}.output.fheencrypted"
            if stream_out_guess.exists(): stream_out_guess.unlink(missing_ok=True)
            if task_name in test_utils.TASK_CONFIG["tasks"]:
                for out_conf in test_utils.TASK_CONFIG["tasks"][task_name]["output_files"]:
                    fname_template = out_conf["filename"]
                    actual_fname = fname_template.replace("{uid}", server_generated_uid)
                    json_out_guess = test_utils.UPLOAD_FOLDER / actual_fname
                    if json_out_guess.exists(): json_out_guess.unlink(missing_ok=True)


def main():
    # Print environment information
    print("\n--- Environment Configuration ---")
    print(f"Environment: {environment}")
    print(f"Mode: {os.getenv('MODE', 'unknown')}")
    print(f"URL: {test_utils.URL}")
    print(f"Port: {os.getenv('FASTAPI_HOST_PORT_HTTP') if os.getenv('MODE') == 'dev' else os.getenv('FASTAPI_HOST_PORT_HTTPS')}")
    print(f"Use TLS: {os.getenv('USE_TLS', 'false')}")
    print("--------------------------------\n")

    load_data_pool()
    print(f"Starting stress test with {NUM_CONCURRENT_USERS} concurrent users for {TEST_DURATION_SECONDS} seconds.")
    print(f"Targeting server: {test_utils.URL}")

    overall_start_time = time.monotonic()
    futures = []
    user_counter = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=NUM_CONCURRENT_USERS) as executor:
        while time.monotonic() - overall_start_time < TEST_DURATION_SECONDS:
            if len(futures) < NUM_CONCURRENT_USERS :
                user_counter += 1
                future = executor.submit(run_single_user_workflow, user_counter)
                futures.append(future)

            # Process completed futures to free up slots and catch exceptions early
            done_futures = [f for f in futures if f.done()]
            for f_idx, f in enumerate(done_futures):
                futures.remove(f)
                try:
                    f.result()
                except Exception as exc:
                    print(f'Workflow (an earlier one, possibly user_{user_counter - len(futures) - len(done_futures) + f_idx}) generated an exception: {exc}')

            if len(futures) >= NUM_CONCURRENT_USERS:
                time.sleep(0.1) # Sleep briefly if all workers are busy to avoid tight spinning

        print(f"\nTest duration ({TEST_DURATION_SECONDS}s) elapsed. Waiting for {len(futures)} active workflows to complete...")

        for future in concurrent.futures.as_completed(futures):
            try:
                future.result()
            except Exception as exc:
                print(f'Workflow generated an exception during final completion: {exc}')

    # Print Summary
    print("\n--- Stress Test Summary ---")
    print(f"Test Duration: {TEST_DURATION_SECONDS}s")
    print(f"Target Concurrent User Workflows: {NUM_CONCURRENT_USERS}")
    print(f"Total User Workflows Initiated: {stats['workflows_initiated']}")
    print(f"Tasks Completed Successfully: {stats['tasks_completed_successfully']}")
    print(f"Tasks Failed (due to API errors or exceptions): {stats['tasks_failed']}")
    print(f"Data Pool Exhaustion Count for a Task: {stats['data_pool_exhausted_count']}")

    if stats["tasks_completed_successfully"] > 0:
        avg_task_duration = stats["total_successful_task_duration"] / stats["tasks_completed_successfully"]
        print(f"Average Successful Task Duration (client-side, end-to-end): {avg_task_duration:.2f}s")

    if stats["errors"]:
        print(f"\n--- Error Details (Sample - First {min(10, len(stats['errors']))}) ---")
        for i, detail_tuple in enumerate(stats["errors"][:10]):
            print(f"{i+1}. Task: {detail_tuple[0]}, ClientFileUID: {detail_tuple[1]}, ServerUID: {detail_tuple[2]}, TaskID: {detail_tuple[3]}, Msg: {detail_tuple[4]}")
        if len(stats["errors"]) > 10:
            print(f"... and {len(stats['errors']) - 10} more errors.")

if __name__ == "__main__":
    main()