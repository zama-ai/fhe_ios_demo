import os
import shutil
import uuid
from pathlib import Path
import sys
import random

# Ensure the tests directory is in the Python path to find test modules
sys.path.insert(0, str(Path(__file__).parent.resolve()))

# For ad_targeting, we'll need parts of its test setup logic
import numpy as np
import pickle as pkl
import json
import concrete_ml_extensions as fhext

# For Rust tasks, import their Python modules
import weight_stats # from tasks/weight_stats (after maturin develop)
import sleep_quality # from tasks/sleep_quality (after maturin develop)

# --- Configuration ---
NUM_SETS_PER_TASK = 20  # Generate this many unique key/input sets per task
BASE_OUTPUT_DIR = Path("./project/uploaded_files/stress_data_pool")

# Ad Targeting specific config
AD_TARGETING_CRYPTO_DTYPE = np.uint64
AD_TARGETING_BITS_RESERVED = 11
AD_TARGETING_DATA_PATH = Path("./tasks/ad_targeting/data/onehot_ads.pkl")

# Sleep Quality sample data
GOOD_NIGHT_SAMPLE_DATA = [
    (0, 0, 210), (0, 240, 570), (2, 0, 30), (5, 30, 60), (3, 60, 90),
    (4, 90, 120), (3, 120, 150), (5, 150, 180), (2, 180, 240),
    (3, 240, 300), (5, 300, 330), (4, 330, 390), (2, 390, 420),
    (5, 420, 450), (4, 450, 510), (3, 510, 540), (5, 540, 570)
]
# Weight Stats sample data
WEIGHT_STATS_SAMPLE_DATA = [68.0, 65.0, 69.0, 70.0, 70.5, 67.0, 71.0]

def generate_fhext_params_for_ad_targeting():
    params_json = json.loads(fhext.default_params())
    params_json["bits_reserved_for_computation"] = AD_TARGETING_BITS_RESERVED
    return fhext.MatmulCryptoParameters.deserialize(json.dumps(params_json))

def encrypt_ad_targeting_input(clear_data, crypto_params, pkey):
    clear_data = clear_data.astype(AD_TARGETING_CRYPTO_DTYPE)
    return fhext.encrypt_matrix(pkey=pkey, crypto_params=crypto_params, data=clear_data)

def generate_for_ad_targeting(output_dir, user_prefix):
    task_name = "ad_targeting"
    server_key_file = output_dir / f"{user_prefix}.serverKey"
    input_file = output_dir / f"{user_prefix}.{task_name}.input.fheencrypted"

    random_input = np.random.randint(0, 2, (1, 62))

    crypto_params = generate_fhext_params_for_ad_targeting()
    pkey, ckey = fhext.create_private_key(crypto_params) # pkey is client, ckey is server

    encrypted_input_matrix = encrypt_ad_targeting_input(random_input, crypto_params, pkey)

    with open(server_key_file, "wb") as f:
        f.write(ckey.serialize())
    with open(input_file, "wb") as f:
        f.write(encrypted_input_matrix.serialize())

    # We don't need to save the pkey for the stress test, server only needs ckey (serverKey)
    print(f"Generated ad_targeting data for {user_prefix}")

def generate_for_sleep_quality(output_dir, user_prefix):
    task_name = "sleep_quality"
    # sleep_quality.generate_files directly writes to UPLOAD_FOLDER with the given uid
    # We need to adapt this to write to our target dir or move files after generation.
    # For simplicity, we'll generate them in UPLOAD_FOLDER then move them.

    temp_uid_for_generation = str(uuid.uuid4()) # Temporary UID for the library function

    # Path names the library will create:
    # <UPLOAD_FOLDER>/<temp_uid_for_generation>.serverKey
    # <UPLOAD_FOLDER>/<temp_uid_for_generation>.sleep_quality.input.fheencrypted

    # Slightly vary data (e.g., pick a sub-segment or shuffle)
    sample_len = len(GOOD_NIGHT_SAMPLE_DATA)
    start_idx = random.randint(0, sample_len // 2)
    end_idx = random.randint(start_idx + 3, sample_len) # ensure at least a few records
    current_data = GOOD_NIGHT_SAMPLE_DATA[start_idx:end_idx]
    if not current_data: # fallback
        current_data = GOOD_NIGHT_SAMPLE_DATA[:5]

    sleep_quality.generate_files(current_data, temp_uid_for_generation)

    # Now move the generated files to our stress pool
    generated_sk_path = Path("./project/uploaded_files") / f"{temp_uid_for_generation}.serverKey"
    generated_input_path = Path("./project/uploaded_files") / f"{temp_uid_for_generation}.{task_name}.input.fheencrypted"
    # We also need to copy the clientKey if we were to decrypt, but for server stress test it's not needed by server.
    # generated_ck_path = Path("./project/uploaded_files") / f"{temp_uid_for_generation}.clientKey"


    target_sk_path = output_dir / f"{user_prefix}.serverKey"
    target_input_path = output_dir / f"{user_prefix}.{task_name}.input.fheencrypted"

    shutil.move(str(generated_sk_path), str(target_sk_path))
    shutil.move(str(generated_input_path), str(target_input_path))

    # Clean up clientKey if generated and not needed
    ck_to_remove = Path("./project/uploaded_files") / f"{temp_uid_for_generation}.clientKey"
    if ck_to_remove.exists():
        ck_to_remove.unlink()

    print(f"Generated sleep_quality data for {user_prefix}")


def generate_for_weight_stats(output_dir, user_prefix):
    task_name = "weight_stats"
    # Similar to sleep_quality, adapt file locations
    temp_uid_for_generation = str(uuid.uuid4())

    # Vary data
    num_weights = random.randint(3, len(WEIGHT_STATS_SAMPLE_DATA))
    current_data = random.sample(WEIGHT_STATS_SAMPLE_DATA, num_weights)
    # Add slight random variation to weights
    current_data = [w + random.uniform(-0.5, 0.5) for w in current_data]


    weight_stats.generate_files(current_data, temp_uid_for_generation)

    generated_sk_path = Path("./project/uploaded_files") / f"{temp_uid_for_generation}.serverKey"
    generated_input_path = Path("./project/uploaded_files") / f"{temp_uid_for_generation}.{task_name}.input.fheencrypted"

    target_sk_path = output_dir / f"{user_prefix}.serverKey"
    target_input_path = output_dir / f"{user_prefix}.{task_name}.input.fheencrypted"

    shutil.move(str(generated_sk_path), str(target_sk_path))
    shutil.move(str(generated_input_path), str(target_input_path))

    ck_to_remove = Path("./project/uploaded_files") / f"{temp_uid_for_generation}.clientKey"
    if ck_to_remove.exists():
        ck_to_remove.unlink()

    print(f"Generated weight_stats data for {user_prefix}")


def main():
    if BASE_OUTPUT_DIR.exists():
        print(f"Cleaning up existing stress data pool directory: {BASE_OUTPUT_DIR}")
        shutil.rmtree(BASE_OUTPUT_DIR)
    BASE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Ensure tools for Rust tasks are available
    try:
        import weight_stats
        import sleep_quality
    except ImportError:
        print("ERROR: Could not import 'weight_stats' or 'sleep_quality'.")
        print("Ensure you have run 'maturin develop --release' for these tasks:")
        print("  maturin develop --release --manifest-path tasks/weight_stats/Cargo.toml")
        print("  maturin develop --release --manifest-path tasks/sleep_quality/Cargo.toml")
        exit(1)

    # Ensure tools for ad_targeting are available
    try:
        import concrete_ml_extensions
    except ImportError:
        print("ERROR: Could not import 'concrete_ml_extensions'.")
        print("Ensure it's installed in your environment.")
        exit(1)
    if not AD_TARGETING_DATA_PATH.exists():
        print(f"ERROR: Ad targeting data file not found: {AD_TARGETING_DATA_PATH}")
        exit(1)


    task_generators = {
        "ad_targeting": generate_for_ad_targeting,
        "sleep_quality": generate_for_sleep_quality,
        "weight_stats": generate_for_weight_stats,
    }

    for task_name, generator_func in task_generators.items():
        task_output_dir = BASE_OUTPUT_DIR / task_name
        task_output_dir.mkdir(exist_ok=True)
        print(f"\nGenerating data for task: {task_name} into {task_output_dir}")
        for i in range(NUM_SETS_PER_TASK):
            user_prefix = f"stress_user_{i}"
            try:
                generator_func(task_output_dir, user_prefix)
            except Exception as e:
                print(f"ERROR generating data for {task_name}, user {user_prefix}: {e}")
                # Decide if you want to stop or continue
                # raise # uncomment to stop on first error

    print(f"\nGenerated {NUM_SETS_PER_TASK} unique key/input sets for each task in {BASE_OUTPUT_DIR}")

if __name__ == "__main__":
    main()