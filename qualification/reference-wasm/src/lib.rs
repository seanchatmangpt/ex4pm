#[no_mangle]
pub extern "C" fn qualification_probe(value: i32) -> i32 {
    value.saturating_mul(2)
}
