# Ferroplan Runtime

ex4pm embeds the ferroplan planner as a WASI WebAssembly module and executes it in-process
through Wasmex/Wasmtime. Ferroplan planning never leaves the process: there is no remote
route and no network fallback.

Status of this document: the implementation is merged (`Ex4pm.Engine.Ferroplan`,
`Ex4pmEngine.Wasm.FerroplanTransport`, `priv/ferroplan/{ferroplan_wasm.wasm,MANIFEST.json}`).
Statements below were checked against `lib/ex4pm/engine/ferroplan.ex`,
`lib/ex4pm_engine/wasm/ferroplan_transport.ex` and the manifest on 2026-10-01; the remaining
**(unverified)** markers name the guest-side items this repo cannot check by reading ex4pm source.

## Pipeline

```text
github.com/seanchatmangpt/ferroplan  crates/ferroplan-wasm   (target wasm32-wasip1)
  -> priv/ferroplan/ferroplan_wasm.wasm
  -> priv/ferroplan/MANIFEST.json                 (sha256 pin of the artifact)
  -> Ex4pmEngine.Wasm.Admission                   (digest admitted against the pin)
  -> Ex4pmEngine.Wasm.FerroplanTransport          (fp_alloc / fp_call / fp_dealloc, JSON ABI)
  -> Ex4pm.Engine.Ferroplan                       (public facade)
  -> consumers, e.g. AshEx4pm.FerroplanRuntime    (ash_ex4pm)
```

## Artifact and pin

- Artifact: `priv/ferroplan/ferroplan_wasm.wasm`, built from the `ferroplan-wasm` crate of
  `github.com/seanchatmangpt/ferroplan` for `wasm32-wasip1`.
- Pin: `priv/ferroplan/MANIFEST.json` records the sha256 of the artifact, size, the source
  crate version (0.29.0) and git sha, the build target/command, the WASI import allowlist, the
  required exports and the op list. The manifest is the admission input; the
  runtime never trusts a `.wasm` file whose digest it has not compared to the pin.
- Until the artifact exists on disk, `Ex4pm.Engine.Ferroplan.wasm_built?/0` returns `false`
  and every planning call returns a typed refusal rather than raising.

## Transport: `Ex4pmEngine.Wasm.FerroplanTransport`

Wasmex GenServer wrapping the WASI module. JSON ABI over linear memory with these exports
(plus `memory`; required exports are `fp_alloc fp_call fp_dealloc memory`):

| Export | Role |
|---|---|
| `fp_alloc(len)` | allocate `len` bytes in guest memory, return pointer |
| `fp_call(ptr, len)` | consume a UTF-8 JSON request `{"op": ..., ...}` at `ptr`/`len`; return packed u64 `(out_ptr << 32) \| out_len` locating the JSON response |
| `fp_dealloc(ptr, len)` | release the RESPONSE buffer (`fp_call` consumes the request buffer) |

Per call: host `fp_alloc` -> write request JSON -> `fp_call` -> read response JSON ->
`fp_dealloc` the response buffer -> decode. Errors arrive as an envelope
`{error: {code, message, retryable}}` and surface as `:ferroplan_engine_error`. Admission precedes
instantiation: `Ex4pmEngine.Wasm.Admission` checks the digest against the manifest pin and the
WASI import allowlist (`wasi_snapshot_preview1` imports only) and the transport refuses to start
on mismatch. Transport refusals beyond admission's: `:ferroplan_artifact_unreadable`,
`:ferroplan_instantiation_failed`, `:ferroplan_encoding_failed`, `:ferroplan_abi_failure`,
`:ferroplan_call_timeout`, `:ferroplan_bad_response`. A timeout or trap stops the instance.
The authoritative request schema lives in the `ferroplan-wasm` crate's `wasi_abi.rs`
**(guest side, unverified here)**.

## Facade: `Ex4pm.Engine.Ferroplan`

| Function | wasm op | Intent |
|---|---|---|
| `plan/4` | `plan` | classical planning from PDDL domain + problem text |
| `plan_production/4` | `plan_production` | production planning; authority is candidate-only |
| `hierarchical_plan/3` | `htn_plan` | HTN planning from PlanningProblem JSON (text or map) + optional limits |
| `fond_policy/3` | `fond_policy` | FOND policy synthesis; response carries a validation report |
| `hddl_solve/4` | `hddl_solve` | HDDL domain/problem text + optional limits |
| `fond_policy_validate/3`, `fond_validate/3` | same | independent policy validation |
| `explain/4` | `explain` | explain a plan against domain + problem |
| `readiness/1` | `readiness` | capability manifest + fingerprint |
| `version/1` | `version` | guest build version (observed `%{"version" => "0.29.0"}`) |
| `wasm_built?/1`, `available?/1`, `artifact_path/1` | - | file present / digest admitted / resolved path |

The `Ex4pm.Engine` behaviour (`execute/3`) exposes the same ops as `:ferroplan_*` operations
(plus the bare `:plan` when `engine: :ferroplan` is explicit) and returns an
`Ex4pm.Engine.Result` with `evidence.executed`, `wasm_sha256`, `source_version`. Options:
`:ferroplan_artifact`, `:ferroplan_expected_sha256`, `:timeout`. Refusal codes:
`:ferroplan_bad_input`, `:ferroplan_artifact_missing`, `:ferroplan_digest_unpinned`,
`:ferroplan_digest_mismatch`, `:ferroplan_engine_error`, `:ferroplan_unsupported_operation`.

The artifact manifest also lists `session_*` ops; there is no Elixir session facade today, and
any session wrapper is CONSTRUCT-only (no DO authority).

## Standing semantics

Vocabulary is the repository's: `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN |
UNSUPPORTED` and typed `REFUSED`. Atoms in code are lowercase (`:alive`, `:unknown`, ...).

- `:alive` is returned only when both hold: the artifact digest was admitted against the
  manifest pin, **and** the result came from a real guest execution in this call. Neither
  alone suffices.
- Artifact absent: not `:alive`; `wasm_built?/0` is `false` and the call refuses.
- Digest mismatch against the pin: typed refusal; the module is not instantiated.
- Artifact admitted but not executed (e.g. `readiness/1` only): at most `:partial_alive`.
- A configured transport, a present file, or a receipt-shaped map is not execution.

No stub or fake planner stands in for the guest. A test that needs `:alive` must run the real
wasm (tag `real_wasm`, consistent with `test/wasm/*edge_cases_test.exs`).

## Consumers

`ash_ex4pm` calls the facade from `AshEx4pm.FerroplanRuntime`. The consumer must pass through
the facade's standing and refusal values unchanged; it must not upgrade a standing, and it
must not introduce a network fallback for planning.

## Rebuild and re-pin

1. In a checkout of `github.com/seanchatmangpt/ferroplan`:
   `rustup target add wasm32-wasip1` then
   `cargo build --release --target wasm32-wasip1 -p ferroplan-wasm`.
   Record the source git sha and `rustc --version`.
2. Copy `target/wasm32-wasip1/release/ferroplan_wasm.wasm` to
   `/Users/sac/ex4pm/priv/ferroplan/ferroplan_wasm.wasm`.
3. Compute `shasum -a 256 priv/ferroplan/ferroplan_wasm.wasm` and update
   `priv/ferroplan/MANIFEST.json` (sha256, source sha, toolchain).
4. Run the real-wasm tests for the facade, then `mix verify`.
5. Commit the artifact and manifest together; a manifest/artifact mismatch is refused at
   admission.

## Falsifiers

- Flip one byte of the `.wasm` without updating the manifest: the facade must refuse, not
  plan.
- Delete the `.wasm`: `wasm_built?/0` is `false` and no call returns `:alive`.
- Any `:alive` result without a guest execution in the same call is a defect.

## See Also

`ALGORITHM-REGISTRY-GENERATION.md`
