use std::env;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

use serde::{Serialize, Deserialize};
use pyo3::prelude::*;
use bincode;

use tfhe::{set_server_key, CompressedServerKey, CompactCiphertextList, FheUint4, FheUint16, FheUint10, CompactPublicKey, ClientKey, ConfigBuilder};
use tfhe::prelude::*;

// Compiles and installs the Rust project as a Python module, using maturin
// with release optimizations, and the manifest is located at tasks/weight_stats/Cargo.toml.
// maturin develop --release --manifest-path tasks/weight_stats/Cargo.toml

#[derive(Serialize, Deserialize)]
pub struct EncryptedRecord {
    pub stage_id: FheUint4,
    pub slot_start: FheUint10,
    pub slot_end: FheUint10,
}


pub fn encrypt_brut_data(
    clear_data: &[(u8, u16, u16)],
    client_key: &ClientKey,
) -> Vec<EncryptedRecord> {
    clear_data
        .iter()
        .map(|&(stage_id, slot_start, slot_end)| EncryptedRecord {
            stage_id: FheUint4::encrypt(stage_id, client_key),
            slot_start: FheUint10::encrypt(slot_start, client_key),
            slot_end: FheUint10::encrypt(slot_end, client_key),
        })
        .collect()
}


fn serialize_compressed_key(compressed_server_key: &CompressedServerKey, path: &str) {
    // Serializes a compressed server key and saves it to a file.
    let serialized_ct = bincode::serialize(compressed_server_key).expect("Failed to serialize key.");
    let path_ct = Path::new(path);
    fs::write(path_ct, &serialized_ct).expect("Failed to write serialized key to file.");
}


fn serialize_compactciphertextlist(encrypted_data: &CompactCiphertextList, path: &str) {
    // Serializes an encrypted `CompactCiphertextList` and saves it to a file.
    let encrypted_data = bincode::serialize(encrypted_data).expect("Failed to serialize encrypted data.");
    let path_ct = Path::new(path);
    fs::write(path_ct, &encrypted_data).expect("Failed to write serialized encrypted data to file.");
}


fn deserialize_fheuint16(path: &str) -> FheUint16 {
    let serialized_ct = fs::read(path).unwrap();
    bincode::deserialize(&serialized_ct).unwrap()
}

fn mean(data: &[u16]) -> u16 {
    let sum: u32 = data.iter().map(|&x| x as u32).sum();
    (sum / (data.len() as u32)) as u16
}

fn max(data: &[u16]) -> u16 {
    *data.iter().max().expect("Empty vector.")
}

fn min(data: &[u16]) -> u16 {
    *data.iter().min().expect("Empty vector.")
}


#[pyfunction]
pub fn compute_stats() -> PyResult<u8> {

    let current_dir = env::current_dir().unwrap();
    println!("Starting weight stats test... from directory: {}", current_dir.display());
    let uid = "test_weight_stats";

    let sk_path = format!("./project/uploaded_files/{}.serverKey", uid);
    let input_path = format!("./project/uploaded_files/{}.weight_stats.input.fheencrypted", uid);
    let output_avg_path = format!("./project/uploaded_files/{}.outputAvg.weight_stats.fheencrypted", uid);
    let output_min_path = format!("./project/uploaded_files/{}.outputMin.weight_stats.fheencrypted", uid);
    let output_max_path = format!("./project/uploaded_files/{}.outputMax.weight_stats.fheencrypted", uid);
    println!("sk_path    : {}", sk_path);
    println!("input_path : {}", input_path);
    println!("output_avg_path: {}", output_avg_path);
    println!("output_min_path: {}", output_min_path);
    println!("output_max_path: {}", output_max_path);

    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);
    let compressed_server_key = CompressedServerKey::new(&client_key);

    let compressed_size = bincode::serialize(&compressed_server_key).unwrap().len();
    println!("Server key generated (compressed size: {} bytes)", compressed_size);

    let sks = compressed_server_key.decompress();
    let decompressed_size = bincode::serialize(&sks).unwrap().len();
    println!("Server key (decompressed size: {} bytes)", decompressed_size);

    set_server_key(sks.clone());
    serialize_compressed_key(&compressed_server_key, &sk_path);

    let clear_data: Vec<f64> = vec![68.0, 65.0, 69.0, 70.0, 70.5];
    println!("Original weight : {:?}", clear_data);

    let clear_data: Vec<u16> = clear_data.into_iter().map(|w| (w * 10.0) as u16).collect();
    println!("Original weight * 10: {:?}", clear_data);

    let public_key = CompactPublicKey::new(&client_key);
    let mut builder = CompactCiphertextList::builder(&public_key);
    
    for val_u16 in &clear_data {
        builder.push_with_num_bits(*val_u16, 16);
    }

    let compact_list = builder.build();
    
    serialize_compactciphertextlist(&compact_list, &input_path);

    // Call main.rs
    let _status = Command::new("cargo")
        .args(&[
            "run", "--bin", "weight_stats", "--manifest-path", "tasks/weight_stats/Cargo.toml", "--", uid
        ])
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .expect("Failed to test weight_stats use-case.");
        
    // Retrive the encrypted result
    let avg_encrypted_output = deserialize_fheuint16(&output_avg_path);
    let file_size = fs::metadata(&output_avg_path).unwrap().len();
    println!("Avg weight retieved at: {} (size: {})", output_avg_path, file_size);

    let min_encrypted_output = deserialize_fheuint16(&output_min_path);
    let file_size = fs::metadata(&output_min_path).unwrap().len();
    println!("Min weight retieved at: {} (size: {})", output_min_path, file_size);

    let max_encrypted_output = deserialize_fheuint16(&output_max_path);
    let file_size = fs::metadata(&output_max_path).unwrap().len();
    println!("Max weight retieved at: {} (size: {})", output_max_path, file_size);

    // Decrypt the output
    let decrypted_avg_weight: u16 = avg_encrypted_output.decrypt(&client_key);
    println!("Avg weight: {}", decrypted_avg_weight);
    let decrypted_min_weight: u16 = min_encrypted_output.decrypt(&client_key);
    println!("Min weight: {}", decrypted_min_weight);
    let decrypted_max_weight: u16 = max_encrypted_output.decrypt(&client_key);
    println!("Max weight: {}", decrypted_max_weight);

    assert!(mean(&clear_data) == decrypted_avg_weight);
    assert!(max(&clear_data) == decrypted_max_weight);
    assert!(min(&clear_data) == decrypted_min_weight);

    let clear_avg = mean(&clear_data);
    let clear_max = max(&clear_data);
    let clear_min = min(&clear_data);
    
    assert_eq!(
        clear_avg,
        decrypted_avg_weight,
        "Error: computed average weight does not match the expected value. Expected: {}, got: {}",
        decrypted_avg_weight,
        clear_avg
    );
    assert_eq!(
        clear_max,
        decrypted_max_weight,
        "Error: computed maximum weight does not match the expected value. Expected: {}, got: {}",
        decrypted_max_weight,
        clear_max
    );
    assert_eq!(
        clear_min,
        decrypted_min_weight,
        "Error: computed minimum weight does not match the expected value. Expected: {}, got: {}",
        decrypted_min_weight,
        clear_min
    );
    
    Ok(1)
}


#[pymodule]
fn weight_stats(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(compute_stats, m)?)?;
    Ok(())
}
