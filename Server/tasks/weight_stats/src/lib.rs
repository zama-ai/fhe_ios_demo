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

const UPLOAD_FOLDER: &str = "./project/uploaded_files";

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


fn serialize_client_key(compressed_server_key: &ClientKey, path: &str) {
    // Serializes a compressed server key and saves it to a file.
    let serialized_ct = bincode::serialize(compressed_server_key).expect("Failed to serialize key.");
    let path_ct = Path::new(path);
    fs::write(path_ct, &serialized_ct).expect("Failed to write serialized key to file.");
}


fn deserialize_client_key(path: &str) -> ClientKey {
    let path_ct = Path::new(path);
    let serialized_ct = fs::read(path_ct).expect("Failed to read serialized key file.");
    bincode::deserialize(&serialized_ct).expect("Failed to deserialize client key.")
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


#[pyfunction]
pub fn generate_files(clear_data: Vec<f64>, uid: String) -> PyResult<u8> {

    let current_dir = env::current_dir().unwrap();
    println!("\n[TFHE-RS generate_files] Starting weight stats test with rust... from directory: {}", current_dir.display());

    let sk_path = format!("{}/{}.serverKey", UPLOAD_FOLDER, uid);
    let ck_path = format!("{}/{}.clientKey", UPLOAD_FOLDER, uid);
    let input_path = format!("{}/{}.weight_stats.input.fheencrypted", UPLOAD_FOLDER, uid);

    println!("[TFHE-RS generate_files] sk_path    : {}", sk_path);
    println!("[TFHE-RS generate_files] ck_path    : {}", ck_path);
    println!("[TFHE-RS generate_files] input_path : {}", input_path);

    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);
    let compressed_server_key = CompressedServerKey::new(&client_key);

    let compressed_size = bincode::serialize(&compressed_server_key).unwrap().len();
    println!("[TFHE-RS generate_files] Server key generated (compressed size: {} bytes)", compressed_size);

    let sks = compressed_server_key.decompress();
    let decompressed_size = bincode::serialize(&sks).unwrap().len();
    println!("[TFHE-RS generate_files] Server key (decompressed size: {} bytes)", decompressed_size);

    set_server_key(sks.clone());

    println!("[TFHE-RS generate_files] Original weight : {:?}", clear_data);

    let clear_data: Vec<u16> = clear_data.into_iter().map(|w| (w * 10.0) as u16).collect();
    println!("[TFHE-RS generate_files] Original weight * 10: {:?}", clear_data);

    let public_key = CompactPublicKey::new(&client_key);
    let mut builder = CompactCiphertextList::builder(&public_key);
    
    for val_u16 in &clear_data {
        let _ = builder.push_with_num_bits(*val_u16, 16);
    }

    let compact_list = builder.build();

    serialize_compressed_key(&compressed_server_key, &sk_path);
    serialize_client_key(&client_key, &ck_path);
    serialize_compactciphertextlist(&compact_list, &input_path);
    
    Ok(1)
}


#[pyfunction]
pub fn run(uid: String) -> PyResult<u8> {
    // Call main.rs
    let _status = Command::new("cargo")
        .args(&[
            "run", "--bin", "weight_stats", "--manifest-path", "tasks/weight_stats/Cargo.toml", "--", &uid
        ])
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .expect("Failed to test weight_stats use-case.");
        
    Ok(1)
}


#[pyfunction]
pub fn decrypt(uid: String) -> PyResult<(u16, u16, u16)> {

    let ck_path = format!("{}/{}.clientKey", UPLOAD_FOLDER, uid);
    let output_avg_path = format!("{}/{}.outputAvg.weight_stats.fheencrypted", UPLOAD_FOLDER, uid);
    let output_min_path = format!("{}/{}.outputMin.weight_stats.fheencrypted", UPLOAD_FOLDER, uid);
    let output_max_path = format!("{}/{}.outputMax.weight_stats.fheencrypted", UPLOAD_FOLDER, uid);

    println!("[TFHE-RS decrypt] output_avg_path: {}", output_avg_path);
    println!("[TFHE-RS decrypt] output_min_path: {}", output_min_path);
    println!("[TFHE-RS decrypt] output_max_path: {}", output_max_path);

    let deserialize_ck = deserialize_client_key(&ck_path);

    // Retrive the encrypted result
    let avg_encrypted_output = deserialize_fheuint16(&output_avg_path);
    let file_size = fs::metadata(&output_avg_path).unwrap().len();
    println!("[TFHE-RS decrypt] Avg weight retieved at: {} (size: {})", output_avg_path, file_size);

    let min_encrypted_output = deserialize_fheuint16(&output_min_path);
    let file_size = fs::metadata(&output_min_path).unwrap().len();
    println!("[TFHE-RS decrypt] Min weight retieved at: {} (size: {})", output_min_path, file_size);

    let max_encrypted_output = deserialize_fheuint16(&output_max_path);
    let file_size = fs::metadata(&output_max_path).unwrap().len();
    println!("[TFHE-RS decrypt] Max weight retieved at: {} (size: {})", output_max_path, file_size);

    // Decrypt the output
    let decrypted_avg_weight: u16 = avg_encrypted_output.decrypt(&deserialize_ck);
    println!("[TFHE-RS decrypt] Avg weight: {}", decrypted_avg_weight);
    let decrypted_min_weight: u16 = min_encrypted_output.decrypt(&deserialize_ck);
    println!("[TFHE-RS decrypt] Min weight: {}", decrypted_min_weight);
    let decrypted_max_weight: u16 = max_encrypted_output.decrypt(&deserialize_ck);
    println!("[TFHE-RS decrypt] Max weight: {}", decrypted_max_weight);

    Ok((decrypted_avg_weight, decrypted_min_weight, decrypted_max_weight))
}
    

#[pymodule]
fn weight_stats(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(generate_files, m)?)?;
    m.add_function(wrap_pyfunction!(run, m)?)?;
    m.add_function(wrap_pyfunction!(decrypt, m)?)?;
    Ok(())
}
