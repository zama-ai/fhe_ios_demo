use tfhe::{set_server_key, CompressedServerKey, FheUint16};
use std::path::Path;
use std::fs;
use std::io::Cursor;
use std::env;

// Usage: ./rust_binary 1234
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() == 1 {
        println!("No arguments provided.");
    }
    
    let uid = &args[1];

    let sk_path = format!("/project/uploaded_files/{}.add_42.serverKey", uid);
    let input_path = format!("/project/uploaded_files/{}.add_42.input.fheencrypted", uid);
    let output_path = format!("/project/uploaded_files/{}.add_42.output.fheencrypted", uid);

    let compressed = deserialize_compressed_server_key(&sk_path);
    let decompressed = compressed.decompress();
    set_server_key(decompressed);
    
    let input: FheUint16 = deserialize_fheuint16(&input_path);
    let result = input + 42;
    
    serialize_fheuint16(result, &output_path);

    Ok(())
}

fn deserialize_compressed_server_key(path: &str) -> CompressedServerKey {
    let path_sk: &Path = Path::new(path);
    let serialized_sk = fs::read(path_sk).unwrap();
    let mut serialized_data = Cursor::new(serialized_sk);
    let res = bincode::deserialize_from(&mut serialized_data).unwrap();
    return res;
}

fn deserialize_fheuint16(path: &str) -> FheUint16 {
    let path_fheuint: &Path = Path::new(path);
    let serialized_fheuint = fs::read(path_fheuint).unwrap();
    let mut serialized_data = Cursor::new(serialized_fheuint);
    let res = bincode::deserialize_from(&mut serialized_data).unwrap();
    return res;
}

fn serialize_fheuint16(fheuint: FheUint16, path: &str) {
    let mut serialized_ct = Vec::new();
    bincode::serialize_into(&mut serialized_ct, &fheuint).unwrap();
    let path_ct: &Path = Path::new(path);
    fs::write(path_ct, serialized_ct).unwrap();
}
