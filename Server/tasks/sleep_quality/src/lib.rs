use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

use serde::{Serialize, Deserialize};
use pyo3::prelude::*;
use bincode;

use tfhe::{set_server_key, CompressedServerKey, CompactCiphertextList, FheUint4, FheUint8, FheUint10, CompactPublicKey, ClientKey, ConfigBuilder};
use tfhe::prelude::*;

pub mod sleep_analysis;

const UPLOAD_FOLDER: &str = "./project/uploaded_files";

#[derive(Serialize, Deserialize)]
pub struct EncryptedRecord {
    pub stage_id: FheUint4,
    pub slot_start: FheUint10,
    pub slot_end: FheUint10,
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


pub fn encrypt_brut_data(
    clear_data: &[(u8, u16, u16)],
    client_key: &ClientKey,
) -> Vec<EncryptedRecord> {
    // Sleep data: (stage_id, slot_start, slot_end)
    // stage_id:
        // inBed = 0
        // asleepUnspecified = 1
        // awake = 2
        // asleepCore = 3
        // asleepDeep = 4
        // asleepREM = 5
    clear_data
        .iter()
        .map(|&(stage_id, slot_start, slot_end)| EncryptedRecord {
            stage_id: FheUint4::encrypt(stage_id, client_key),
            slot_start: FheUint10::encrypt(slot_start, client_key),
            slot_end: FheUint10::encrypt(slot_end, client_key),
        })
        .collect()
}


#[pyfunction]
pub fn generate_files(clear_data: Vec<(u8, u16, u16)>, uid: &str) -> PyResult<u8> {

    let sk_path = format!("{}/{}.serverKey", UPLOAD_FOLDER, uid);
    let ck_path = format!("{}/{}.clientKey", UPLOAD_FOLDER, uid);
    let input_path = format!("{}/{}.sleep_quality.input.fheencrypted", UPLOAD_FOLDER, uid);

    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);

    let compressed_server_key = CompressedServerKey::new(&client_key);

    let sks = compressed_server_key.decompress();

    set_server_key(sks.clone());

    let public_key = CompactPublicKey::new(&client_key);
    let mut builder = CompactCiphertextList::builder(&public_key);
    
    for (val_u4, val_u10_1, val_u10_2) in clear_data {
        let _ = builder.push_with_num_bits(val_u4 as u8, 4);
        let _ = builder.push_with_num_bits(val_u10_1 as u16, 10);
        let _ = builder.push_with_num_bits(val_u10_2 as u16, 10);
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
            "run", "--release", "--bin", "sleep_quality", "--manifest-path", "tasks/sleep_quality/Cargo.toml", "--", uid
        ])
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .expect("Failed to test sleep_analysis use-case.");

    Ok(1)
}


#[pyfunction]
pub fn decrypt(ck_path: &str, output_path: &str) -> PyResult<u8> {

    let deserialize_ck = deserialize_client_key(&ck_path);

    // Retrive the encrypted result
    let encrypted_output = deserialize_fheuint8(&output_path);

    // Decrypt the output
    let decrypted_response: u8 = encrypted_output.decrypt(&deserialize_ck);

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
