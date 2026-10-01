# ferroplan wasm artifact

`ferroplan_wasm.wasm` is the `ferroplan-wasm` crate (WASI linear-memory JSON ABI:
`fp_alloc`/`fp_call`/`fp_dealloc`/`memory`), built from `/Users/sac/ferroplan` at the SHA in
`MANIFEST.json`:

```bash
cargo build -p ferroplan-wasm --release --target wasm32-wasip1
```

Copy `target/wasm32-wasip1/release/ferroplan_wasm.wasm` here and refresh `MANIFEST.json`
(sha256, size, imports). Host must supply the WASI snapshot_preview1 imports listed there.
