# Ferroplan Runtime

ex4pm embeds the ferroplan planner as a WASI WebAssembly module and executes it in-process
through Wasmex/Wasmtime. This supersedes the earlier design in which ferroplan planning was
reached only as a remote HTTP route on beam4pm (see the supersession notes in
`EX4PM-THINNING-BEAM4PM-ENRICHMENT.md` and `BEAM4PM-OPENAPI-GGEN-IGNITER-PLAN.md`).

Status of this document: the implementation is landing concurrently. Everything below is the
intended contract. Items marked **(unverified)** have not been observed executing at the time
of writing; check the module source and `MANIFEST.json` before relying on them.

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
- Pin: `priv/ferroplan/MANIFEST.json` records the sha256 of the artifact (and, intended, the
  source git sha and toolchain used to build it). The manifest is the admission input; the
  runtime never trusts a `.wasm` file whose digest it has not compared to the pin.
- Until the artifact exists on disk, `Ex4pm.Engine.Ferroplan.wasm_built?/0` returns `false`
  and every planning call returns a typed refusal rather than raising.

## Transport: `Ex4pmEngine.Wasm.FerroplanTransport`

Wasmex GenServer wrapping the WASI module. JSON ABI over linear memory with three exports:

| Export | Role |
|---|---|
| `fp_alloc(len)` | allocate `len` bytes in guest memory, return pointer |
| `fp_call(ptr, len)` | consume a UTF-8 JSON request at `ptr`/`len`, return a pointer/length to a JSON response |
| `fp_dealloc(ptr, len)` | release a buffer previously returned by `fp_alloc` or `fp_call` |

Per call: host `fp_alloc` -> write request JSON -> `fp_call` -> read response JSON ->
`fp_dealloc` both buffers -> decode. The exact request/response envelope (operation names,
field names) is defined by the `ferroplan-wasm` crate **(unverified here; read the crate's
ABI module for the authoritative schema)**. Admission precedes instantiation: the transport
asks `Ex4pmEngine.Wasm.Admission` to admit the artifact digest against the manifest pin and
refuses to start on mismatch.

## Facade: `Ex4pm.Engine.Ferroplan`

| Function | Intent |
|---|---|
| `plan/4` | classical planning from domain + problem (PDDL) with options |
| `plan_production/4` | planning for production-style problems **(exact input shape unverified)** |
| `readiness/1` | report whether the artifact is present, admitted, and instantiable |
| `version/1` | version string reported by the guest module |
| `hierarchical_plan` | HTN/HDDL decomposition planning |
| `fond_policy` | FOND policy synthesis (strong/strong-cyclic) |
| `wasm_built?/0` | whether `priv/ferroplan/ferroplan_wasm.wasm` exists on disk |

Arities for `hierarchical_plan` and `fond_policy` follow the landed module; consult its
`@spec`s.

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
must not reintroduce an HTTP fallback to beam4pm for planning.

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

`ALGORITHM-REGISTRY-GENERATION.md` · `EX4PM-THINNING-BEAM4PM-ENRICHMENT.md` ·
`BEAM4PM-OPENAPI-GGEN-IGNITER-PLAN.md`
