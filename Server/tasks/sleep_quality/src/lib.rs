use std::env;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

use serde::{Serialize, Deserialize};
use pyo3::prelude::*;
use bincode;

use tfhe::{set_server_key, CompressedServerKey, CompactCiphertextList, FheUint4, FheUint8, FheUint10, CompactPublicKey, ClientKey, ConfigBuilder};
use tfhe::prelude::*;

pub mod sleep_analysis;

// Compiles and installs the Rust project as a Python module, using maturin
// with release optimizations, and the manifest is located at tasks/sleep_quality/Cargo.toml.
// maturin develop --release --manifest-path tasks/sleep_quality/Cargo.toml

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

fn deserialize_fheuint8(path: &str) -> FheUint8 {
    // Read and deserializes the encrypted output as `FheUint8` from a binary file.
    let serialized_ct = fs::read(path).unwrap();
    bincode::deserialize(&serialized_ct).unwrap()
}

// Sleep data: (stage_id, slot_start, slot_end)
// inBed = 0
// asleepUnspecified = 1
// awake = 2
// asleepCore = 3
// asleepDeep = 4
// asleepREM = 5

#[pyfunction]
pub fn generate_files(clear_data: Vec<(u8, u16, u16)>, uid: &str) -> PyResult<u8> {

    let current_dir = env::current_dir().unwrap();
    println!("Starting sleep quality test with rust... from directory: {}", current_dir.display());

    let sk_path = format!("./project/uploaded_files/{}.serverKey", uid);
    let ck_path = format!("./project/uploaded_files/{}.clientKey", uid);
    
    let input_path = format!("./project/uploaded_files/{}.sleep_quality.input.fheencrypted", uid);

    println!("sk_path    : {}", sk_path);
    println!("ck_path    : {}", ck_path);
    println!("input_path : {}", input_path);

    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);

    let compressed_server_key = CompressedServerKey::new(&client_key);
    let compressed_size = bincode::serialize(&compressed_server_key).unwrap().len();
    println!("Server key generated (compressed size: {} bytes)", compressed_size);

    let sks = compressed_server_key.decompress();
    let decompressed_size = bincode::serialize(&sks).unwrap().len();
    println!("Server key (decompressed size: {} bytes)", decompressed_size);

    set_server_key(sks.clone());

    let public_key = CompactPublicKey::new(&client_key);
    let mut builder = CompactCiphertextList::builder(&public_key);
    
    for (val_u4, val_u10_1, val_u10_2) in clear_data {
        builder.push_with_num_bits(val_u4 as u8, 4);
        builder.push_with_num_bits(val_u10_1 as u16, 10);
        builder.push_with_num_bits(val_u10_2 as u16, 10);
    }
    let compact_list = builder.build();
    
    serialize_compressed_key(&compressed_server_key, &sk_path);
    serialize_client_key(&client_key, &ck_path);
    serialize_compactciphertextlist(&compact_list, &input_path);

    Ok(1)
}


#[pyfunction]
pub fn run(uid: &str) -> PyResult<u8> {

    // Call main.rs
    let _status = Command::new("cargo")
        .args(&[
            "run", "--bin", "sleep_quality", "--manifest-path", "tasks/sleep_quality/Cargo.toml", "--", uid
        ])
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .expect("Failed to test sleep_analysis use-case.");

    Ok(1)
}


#[pyfunction]
pub fn decrypt(uid: &str) -> PyResult<u8> { 

    let ck_path = format!("./project/uploaded_files/{}.clientKey", uid);
    let output_path = format!("./project/uploaded_files/{}.sleep_quality.output.fheencrypted", uid);
    
    println!("ck_path: {}", ck_path);
    println!("output_path: {}", output_path);

    let deserialize_ck = deserialize_client_key(&ck_path);

    // Retrive the encrypted result
    let encrypted_output = deserialize_fheuint8(&output_path);
    let file_size = fs::metadata(&output_path).unwrap().len();
    println!("Final score retieved at: {} (size: {})\n", output_path, file_size);

    // Decrypt the output
    let decrypted_response: u8 = encrypted_output.decrypt(&deserialize_ck);
    println!("Final score: {}", decrypted_response);

    // Return the result
    Ok(decrypted_response)

}


#[pymodule]
fn sleep_quality(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(generate_files, m)?)?;
    m.add_function(wrap_pyfunction!(run, m)?)?;
    m.add_function(wrap_pyfunction!(decrypt, m)?)?;
    Ok(())
}
