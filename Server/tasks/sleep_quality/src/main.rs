use tfhe::{set_server_key, CompressedServerKey, CompactCiphertextList, CompactCiphertextListExpander, FheUint4, FheUint8, FheUint10};
use tfhe::prelude::*;
use std::path::Path;
use std::fs;
use std::io::Cursor;
use std::env;

mod sleep_analysis;
use sleep_analysis::*;

fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() == 1 {
        return Ok(());
    }

    let uid = &args[1];

    // Construct paths
    let sk_path = format!("/project/uploaded_files/{}.serverKey", uid);
    let input_path = format!("/project/uploaded_files/{}.sleep_quality.input.fheencrypted", uid);
    let output_final_score_path = format!("/project/uploaded_files/{}.sleep_quality.output.fheencrypted", uid);

    // Deserialize and set server key
    let compressed_sk = deserialize_compressed_server_key(&sk_path);
    let decompressed_sk = compressed_sk.decompress();
    set_server_key(decompressed_sk);

    // Deserialize input data
    let compact_list = deserialize_list(&input_path);

    // Expand compact list
    let expanded = compact_list.expand().unwrap();

    // Reshape expanded list into EncryptedRecords
    let encrypted_data = reshape_into_encrypted_records(&expanded);

    // Define stages
    let stages = vec![0u8, 1u8, 2u8, 3u8, 4u8, 5u8];

    // Perform sleep analysis computations
    let total_durations = compute_total_duration_per_stage(&encrypted_data, &stages);
    let (total_sleep_time, total_in_bed_time) = compute_sleep_time_from_durations(&total_durations);
    let sleep_onset_latency = compute_sleep_onset_latency(&encrypted_data);

    let sleep_efficiency_category = evaluate_sleep_efficiency(&total_sleep_time, &total_in_bed_time);
    let total_sleep_time_category = evaluate_total_sleep_time(&total_sleep_time);
    let sleep_onset_latency_category = evaluate_sleep_onset_latency(&sleep_onset_latency);

    let categories = vec![
        &sleep_onset_latency_category,
        &total_sleep_time_category,
        &sleep_efficiency_category
    ];
    let num_categories = categories.len();
    
    // Sum all categories
    let mut raw_score = FheUint8::encrypt_trivial(0u8);
    for category in categories {
        raw_score = &raw_score + category;
    }

    // Normalize to 1-5 range
    let multiplier = FheUint8::encrypt_trivial(4u8);
    let max_possible = FheUint8::encrypt_trivial((num_categories * 3) as u8);
    let final_score = (&raw_score * &multiplier) / &max_possible + 1;

    // Simplified output - only serialize final score
    serialize_fheuint8(&final_score, &output_final_score_path);

    Ok(())
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

fn reshape_into_encrypted_records(expanded: &CompactCiphertextListExpander) -> Vec<EncryptedRecord> {
    let mut records = Vec::new();
    let len: usize = expanded.len();
    assert!(len % 3 == 0, "Expanded list length is not a multiple of 3. Got '{}'", len % 3);

    let num_records = len / 3;

    for i in 0..num_records {
        let idx = i * 3;
        let stage_id: FheUint4 = expanded.get::<FheUint4>(idx).unwrap().unwrap();
        let slot_start: FheUint10 = expanded.get::<FheUint10>(idx + 1).unwrap().unwrap();
        let slot_end: FheUint10 = expanded.get::<FheUint10>(idx + 2).unwrap().unwrap();

        records.push(EncryptedRecord {
            stage_id,
            slot_start,
            slot_end,
        });
    }

    records
}

fn serialize_fheuint8(fheuint: &FheUint8, path: &str) {
    let mut serialized_ct = Vec::new();
    bincode::serialize_into(&mut serialized_ct, &fheuint).unwrap();
    let path_ct: &Path = Path::new(path);
    fs::write(path_ct, serialized_ct).unwrap();
}
