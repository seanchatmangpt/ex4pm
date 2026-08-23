use rustler::Term;

#[rustler::nif]
fn qualification_probe(value: i64, _opts: Term) -> i64 {
    value.saturating_mul(2)
}

#[rustler::nif]
fn panic_probe() -> i64 {
    panic!("ex4pm qualification panic probe")
}

rustler::init!("Elixir.Ex4pm.Qualification.ReferenceNif");
