use tfhe::{set_server_key, CompressedServerKey, CompactCiphertextList, CompactCiphertextListExpander, FheUint16};
use tfhe::prelude::*;
use std::path::Path;
use std::fs;
use std::io::Cursor;
use std::env;

// Usage: ./rust_binary 1234
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() == 1 {
        return Err("No arguments provided.".into());
    }
    
    let uid = &args[1];

    let sk_path = format!("/project/uploaded_files/{}.serverKey", uid);
    let input_path = format!("/project/uploaded_files/{}.weight_stats.input.fheencrypted", uid);
    let output_avg_path = format!("/project/uploaded_files/{}.outputAvg.weight_stats.fheencrypted", uid);
    let output_min_path = format!("/project/uploaded_files/{}.outputMin.weight_stats.fheencrypted", uid);
    let output_max_path = format!("/project/uploaded_files/{}.outputMax.weight_stats.fheencrypted", uid);

    let compressed = deserialize_compressed_server_key(&sk_path);
    let decompressed = compressed.decompress();
    set_server_key(decompressed);

    let compact_list = deserialize_list(&input_path);
    let expanded = compact_list.expand().unwrap();
    
    let (min, max, avg) = compute_min_max_avg(&expanded);
    
    serialize_fheuint16(min, &output_min_path);
    serialize_fheuint16(max, &output_max_path);
    serialize_fheuint16(avg, &output_avg_path);

    Ok(())
}

fn compute_min_max_avg(expanded: &CompactCiphertextListExpander) -> (FheUint16, FheUint16, FheUint16) {
    assert!(expanded.len() > 0, "array is empty, no min/max/avg to compute");
    
    let first: FheUint16 = expanded.get::<FheUint16>(0).unwrap().unwrap();
    let mut min: FheUint16 = first.clone();
    let mut max: FheUint16 = first.clone();
    let mut sum: FheUint16 = first.clone();

    for i in 1..expanded.len() {
        let value: FheUint16 = expanded.get::<FheUint16>(i).unwrap().unwrap();
        min = min.min(&value);
        max = max.max(&value);
        sum += value;
    }

    let avg = sum / expanded.len() as u16;
    (min, max, avg)
}

fn deserialize_compressed_server_key(path: &str) -> CompressedServerKey {
    let path_sk: &Path = Path::new(path);
    let serialized_sk = fs::read(path_sk).unwrap();
    let mut serialized_data = Cursor::new(serialized_sk);
    let res = bincode::deserialize_from(&mut serialized_data).unwrap();
    return res;
}

fn deserialize_list(path_string: &str) -> CompactCiphertextList {
    let path: &Path = Path::new(path_string);
    let serialized_list = fs::read(path).unwrap();
    let mut serialized_data = Cursor::new(serialized_list);
    let res = bincode::deserialize_from(&mut serialized_data).unwrap();
    return res;
}

fn serialize_fheuint16(fheuint: FheUint16, path: &str) {
    let mut serialized_ct = Vec::new();
    bincode::serialize_into(&mut serialized_ct, &fheuint).unwrap();
    let path_ct: &Path = Path::new(path);
    fs::write(path_ct, serialized_ct).unwrap();
}
