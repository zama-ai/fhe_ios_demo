use tfhe::prelude::*;
use tfhe::FheUint64;

const SECRET_KEYS: [u64; 3] = [958128024866275, 6668561499863873, 3642403660346225];
const LCG_MULT: u64 = 6_364_136_223_846_793_005;
const LCG_INC: u64 = 1;
const NGRAM_LEN: usize = 4;
const H: usize = NGRAM_LEN - 1;
const DETECTION_THRESHOLD: f64 = 0.6;

fn lcg_accumulate(mut acc: FheUint64, data: &[FheUint64]) -> FheUint64 {
    for d in data {
        acc = &acc + d;
        acc = acc * LCG_MULT;
        acc = acc + LCG_INC;
    }
    acc
}

fn lsb(x: &FheUint64) -> FheUint64 {
    x & FheUint64::encrypt_trivial(1u64)
}

fn window_g_sum(ctx: &[FheUint64], cur: &FheUint64, enc_keys: &[FheUint64]) -> FheUint64 {
    let ctx_hash = lcg_accumulate(enc_keys[0].clone(), ctx);
    let mut g_sum = FheUint64::encrypt_trivial(0u64);
    for (l, enc_k) in enc_keys.iter().enumerate() {
        let l_enc = FheUint64::encrypt_trivial(l as u64);
        let tok_hash = lcg_accumulate(enc_k.clone(), &[ctx_hash.clone(), cur.clone(), l_enc]);
        let shifted = if l == 0 {
            tok_hash
        } else {
            &tok_hash >> (l as u64)
        };
        g_sum = &g_sum + lsb(&shifted);
    }
    g_sum
}

pub fn fhe_detect(enc_tokens: Vec<FheUint64>) -> (FheUint64, FheUint64, FheUint64) {
    let windows = enc_tokens.len().saturating_sub(H);
    if windows == 0 {
        let zero = FheUint64::encrypt_trivial(0u64);
        return (zero.clone(), zero.clone(), zero);
    }

    let enc_keys: Vec<FheUint64> = SECRET_KEYS
        .iter()
        .map(|&k| FheUint64::encrypt_trivial(k))
        .collect();
    let mut total_g_enc = FheUint64::encrypt_trivial(0u64);

    for i in 0..windows {
        total_g_enc = &total_g_enc + window_g_sum(&enc_tokens[i..i + H], &enc_tokens[i + H], &enc_keys);
    }
    let denom = FheUint64::encrypt_trivial((windows * SECRET_KEYS.len()) as u64);

    let threshold_denom = FheUint64::encrypt_trivial(1000u64);
    let threshold_num = FheUint64::encrypt_trivial((DETECTION_THRESHOLD * 1000.0) as u64);
    
    let flag = (&total_g_enc * &threshold_denom).gt(&(&denom * &threshold_num));
    let flag_u64 = FheUint64::cast_from(flag);

    let scale_factor = FheUint64::encrypt_trivial(1_000_000u64);
    let score_scaled = (&total_g_enc * &scale_factor) / &denom;

    (flag_u64, score_scaled, total_g_enc)
} 