use tfhe::prelude::*;
use tfhe::*;

/// Represents an encrypted record of sleep data.
pub struct EncryptedRecord {
    pub stage_id: FheUint4,
    pub slot_start: FheUint10,
    pub slot_end: FheUint10,
}

/// Computes total duration per sleep stage.
pub fn compute_total_duration_per_stage(
    records: &[EncryptedRecord],
    stages: &[u8],
) -> Vec<(u8, FheUint10)> {
    let mut total_durations = Vec::new();

    for &stage_id in stages {
        let mut total = FheUint10::encrypt_trivial(0u16);

        for record in records {
            let is_current_stage = record.stage_id.eq(stage_id);
            let slot_duration = &record.slot_end - &record.slot_start;
            let partial_duration =
                is_current_stage.select(&slot_duration, &FheUint10::encrypt_trivial(0u16));
            total = total + partial_duration;
        }

        total_durations.push((stage_id, total));
    }

    total_durations
}

/// Computes total sleep time and total in-bed time.
pub fn compute_sleep_time_from_durations(
    total_durations: &[(u8, FheUint10)],
) -> (FheUint10, FheUint10) {
    let mut total_sleep_time = FheUint10::encrypt_trivial(0u16);
    let mut total_in_bed_time = FheUint10::encrypt_trivial(0u16);

    for (stage_id, duration) in total_durations {
        let stage_id_plain: u8 = *stage_id;

        match stage_id_plain {
            0 => {
                total_in_bed_time = &total_in_bed_time + duration;
            }
            _ => {
                total_sleep_time = &total_sleep_time + duration;
            }
        }
    }

    (total_sleep_time, total_in_bed_time)
}

/// Computes sleep onset latency.
pub fn compute_sleep_onset_latency(records: &[EncryptedRecord]) -> FheUint10 {
    let mut first_in_bed_time = FheUint10::encrypt_trivial(0u16);
    let mut first_sleep_time = FheUint10::encrypt_trivial(0u16);
    let mut found_in_bed = FheBool::encrypt_trivial(false);
    let mut found_sleep = FheBool::encrypt_trivial(false);

    for record in records {
        let is_in_bed = record.stage_id.eq(0);
        let is_sleeping = !&is_in_bed;

        // Update first in-bed time only if we haven't found it yet
        let should_update_in_bed = !&found_in_bed & &is_in_bed;
        let update_in_bed_time = &record.slot_start * &FheUint10::cast_from(should_update_in_bed.clone());
        first_in_bed_time = &first_in_bed_time + update_in_bed_time;
        found_in_bed = &found_in_bed | &is_in_bed;

        // Update first sleep time only if we haven't found it yet
        let should_update_sleep = !&found_sleep & &is_sleeping;
        let update_sleep_time = &record.slot_start * &FheUint10::cast_from(should_update_sleep.clone());
        first_sleep_time = &first_sleep_time + update_sleep_time;
        found_sleep = &found_sleep | &is_sleeping;
    }

    // Calculate the difference between first sleep time and first in-bed time
    first_sleep_time - first_in_bed_time
}

/// Evaluates total sleep time category.
pub fn evaluate_total_sleep_time(total_sleep_time: &FheUint10) -> FheUint8 {
    // Convert hours to minutes for comparison
    let seven_hours = FheUint10::encrypt_trivial(7u16 * 60);
    let six_hours = FheUint10::encrypt_trivial(6u16 * 60);
    let five_hours = FheUint10::encrypt_trivial(5u16 * 60);

    // Evaluate conditions
    let is_greater_than_7h = total_sleep_time.gt(&seven_hours);
    let is_between_6h_and_7h = total_sleep_time.le(&seven_hours) & total_sleep_time.gt(&six_hours);
    let is_between_5h_and_6h = total_sleep_time.le(&six_hours) & total_sleep_time.gt(&five_hours);
    let is_less_than_or_equal_5h = total_sleep_time.le(&five_hours);

    // Assign categories based on conditions
    let result_0 = FheUint8::cast_from(is_greater_than_7h.clone()) * 0u8;
    let result_1 = FheUint8::cast_from(is_between_6h_and_7h.clone()) * 1u8;
    let result_2 = FheUint8::cast_from(is_between_5h_and_6h.clone()) * 2u8;
    let result_3 = FheUint8::cast_from(is_less_than_or_equal_5h.clone()) * 3u8;

    // Combine results
    result_0 + result_1 + result_2 + result_3
}

/// Evaluates sleep efficiency category.
pub fn evaluate_sleep_efficiency(
    total_sleep_time: &FheUint10,
    total_in_bed_time: &FheUint10,
) -> FheUint8 {
    // Calculate sleep efficiency percentage
    let total_sleep_time = FheUint16::cast_from(total_sleep_time.clone());
    let total_in_bed_time = FheUint16::cast_from(total_in_bed_time.clone());

    // Calculate sleep efficiency percentage
    let sleep_efficiency = &total_sleep_time * 100u16;

    // Multiply thresholds by total_in_bed_time
    let threshold_85 = &total_in_bed_time * 85u16;
    let threshold_75 = &total_in_bed_time * 75u16;
    let threshold_65 = &total_in_bed_time * 65u16;

    // Evaluate conditions
    let is_greater_than_85 = sleep_efficiency.gt(&threshold_85);
    let is_between_75_and_85 =
        sleep_efficiency.le(&threshold_85) & sleep_efficiency.gt(&threshold_75);
    let is_between_65_and_75 =
        sleep_efficiency.le(&threshold_75) & sleep_efficiency.gt(&threshold_65);
    let is_less_than_or_equal_65 = sleep_efficiency.le(&threshold_65);

    // Assign categories based on conditions
    let result_0 = FheUint8::cast_from(is_greater_than_85.clone()) * 0u8;
    let result_1 = FheUint8::cast_from(is_between_75_and_85.clone()) * 1u8;
    let result_2 = FheUint8::cast_from(is_between_65_and_75.clone()) * 2u8;
    let result_3 = FheUint8::cast_from(is_less_than_or_equal_65.clone()) * 3u8;

    // Combine results
    result_0 + result_1 + result_2 + result_3
}

/// Evaluates sleep onset latency category.
pub fn evaluate_sleep_onset_latency(sleep_onset_latency: &FheUint10) -> FheUint8 {
    // Define thresholds in minutes
    let fifteen_minutes = FheUint10::encrypt_trivial(15u16);
    let thirty_minutes = FheUint10::encrypt_trivial(30u16);
    let sixty_minutes = FheUint10::encrypt_trivial(60u16);

    // Evaluate conditions
    let is_less_than_or_equal_15 = sleep_onset_latency.le(&fifteen_minutes);
    let is_between_15_and_30 =
        sleep_onset_latency.gt(&fifteen_minutes) & sleep_onset_latency.le(&thirty_minutes);
    let is_between_30_and_60 =
        sleep_onset_latency.gt(&thirty_minutes) & sleep_onset_latency.le(&sixty_minutes);
    let is_greater_than_60 = sleep_onset_latency.gt(&sixty_minutes);

    // Assign categories based on conditions
    let result_0 = FheUint8::cast_from(is_less_than_or_equal_15.clone()) * 0u8;
    let result_1 = FheUint8::cast_from(is_between_15_and_30.clone()) * 1u8;
    let result_2 = FheUint8::cast_from(is_between_30_and_60.clone()) * 2u8;
    let result_3 = FheUint8::cast_from(is_greater_than_60.clone()) * 3u8;

    // Combine results
    result_0 + result_1 + result_2 + result_3
}
