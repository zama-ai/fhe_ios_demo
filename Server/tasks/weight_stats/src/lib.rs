use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

use serde::{Serialize, Deserialize};
use pyo3::prelude::*;
use bincode;

use tfhe::{set_server_key, CompressedServerKey, CompactCiphertextList, FheUint4, FheUint16, FheUint10, CompactPublicKey, ClientKey, ConfigBuilder};
use tfhe::prelude::*;

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

    let sk_path = format!("{}/{}.serverKey", UPLOAD_FOLDER, uid);
    let ck_path = format!("{}/{}.clientKey", UPLOAD_FOLDER, uid);
    let input_path = format!("{}/{}.weight_stats.input.fheencrypted", UPLOAD_FOLDER, uid);

    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);
    let compressed_server_key = CompressedServerKey::new(&client_key);

    let sks = compressed_server_key.decompress();

    set_server_key(sks.clone());

    let clear_data: Vec<u16> = clear_data.into_iter().map(|w| (w * 10.0) as u16).collect();

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
            "run", "--release", "--bin", "weight_stats", "--manifest-path", "tasks/weight_stats/Cargo.toml", "--", &uid
        ])
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .expect("Failed to test weight_stats use-case.");
        
    Ok(1)
}


#[pyfunction]
pub fn decrypt(ck_path: &str, output_avg_path: &str, output_min_path: &str, output_max_path: &str) -> PyResult<(u16, u16, u16)> {

    let deserialize_ck = deserialize_client_key(&ck_path);

    // Retrive the encrypted result
    let avg_encrypted_output = deserialize_fheuint16(&output_avg_path);
    let min_encrypted_output = deserialize_fheuint16(&output_min_path);
    let max_encrypted_output = deserialize_fheuint16(&output_max_path);

    // Decrypt the output
    let decrypted_avg_weight: u16 = avg_encrypted_output.decrypt(&deserialize_ck);
    let decrypted_min_weight: u16 = min_encrypted_output.decrypt(&deserialize_ck);
    let decrypted_max_weight: u16 = max_encrypted_output.decrypt(&deserialize_ck);

    Ok((decrypted_avg_weight, decrypted_min_weight, decrypted_max_weight))
}
    

#[pymodule]
fn weight_stats(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(generate_files, m)?)?;
    m.add_function(wrap_pyfunction!(run, m)?)?;
    m.add_function(wrap_pyfunction!(decrypt, m)?)?;
    Ok(())
}
