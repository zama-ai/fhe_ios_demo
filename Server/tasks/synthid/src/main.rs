use std::env;
use std::fs;
use std::path::Path;
use std::io::Cursor;
use tfhe::{ServerKey, FheUint64, set_server_key};
use tfhe::safe_serialization::safe_deserialize;

mod synthid_logic;
use synthid_logic::fhe_detect;

const SIZE_LIMIT: u64 = 1_000_000_000;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <uid>", args[0]);
        return Err("No UID provided.".into());
    }
    let uid = &args[1];
    let task_name = "synthid";

    eprintln!("[synthid_task] Processing for UID: {}", uid);

    let base_upload_path = Path::new("/project/uploaded_files");
    let sk_path = base_upload_path.join(format!("{}.serverKey", uid));
    let input_path = base_upload_path.join(format!("{}.{}.input.fheencrypted", uid, task_name));
    let output_path = base_upload_path.join(format!("{}.{}.output.fheencrypted", uid, task_name));

    eprintln!("[synthid_task] Server Key Path: {:?}", sk_path);
    eprintln!("[synthid_task] Input Path: {:?}", input_path);
    eprintln!("[synthid_task] Output Path: {:?}", output_path);

    let serialized_sk = fs::read(&sk_path).map_err(|e| {
        eprintln!("[synthid_task] Failed to read server key from {:?}: {}", sk_path, e);
        e
    })?;
    eprintln!("[synthid_task] Read {} bytes for server key.", serialized_sk.len());

    let mut cursor = Cursor::new(serialized_sk);
    let server_key: ServerKey = safe_deserialize(&mut cursor, SIZE_LIMIT).map_err(|e| {
        eprintln!("[synthid_task] Failed to deserialize ServerKey: {}", e);
        Box::<dyn std::error::Error>::from(format!("Failed to deserialize ServerKey: {}", e))
    })?;
    set_server_key(server_key);
    eprintln!("[synthid_task] Server key deserialized and set.");

    let serialized_input = fs::read(&input_path).map_err(|e| {
        eprintln!("[synthid_task] Failed to read input data from {:?}: {}", input_path, e);
        e
    })?;
    eprintln!("[synthid_task] Read {} bytes for input data.", serialized_input.len());
    let encrypted_tokens: Vec<FheUint64> = bincode::deserialize(&serialized_input).map_err(|e| {
        eprintln!("[synthid_task] Failed to deserialize Vec<FheUint64> input: {}", e);
        e
    })?;
    eprintln!("[synthid_task] Encrypted tokens deserialized. Count: {}", encrypted_tokens.len());

    if encrypted_tokens.is_empty() {
        eprintln!("[synthid_task] Warning: Input token list is empty.");
    }

    eprintln!("[synthid_task] Starting FHE detection...");
    let (flag_fhe, score_scaled_fhe, total_g_fhe) = fhe_detect(encrypted_tokens);
    eprintln!("[synthid_task] FHE detection completed.");

    let results_vec: Vec<FheUint64> = vec![flag_fhe, score_scaled_fhe, total_g_fhe];
    let serialized_output = bincode::serialize(&results_vec).map_err(|e| {
        eprintln!("[synthid_task] Failed to serialize FHE results: {}", e);
        e
    })?;
    eprintln!("[synthid_task] Results serialized, size: {} bytes.", serialized_output.len());

    fs::write(&output_path, serialized_output).map_err(|e| {
        eprintln!("[synthid_task] Failed to write output to {:?}: {}", output_path, e);
        e
    })?;
    eprintln!("[synthid_task] Encrypted output successfully written to {:?}", output_path);
    eprintln!("[synthid_task] Task for UID {} completed successfully.", uid);

    Ok(())
} 