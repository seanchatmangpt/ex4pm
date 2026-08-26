# ARD v26.9.x — Phase-1 wasm4pm Process-Intelligence Bindings

Status: DEVELOP. Extends ARD-v26.8.22's wasm4pm standing model
(inspection → native execution → WASM construction → WASM execution →
replay → artifact identity) from CMCA-only to a second, non-BCINR
family of algorithms. ARD-v26.8.22 is unmodified — this is a new
milestone document, not an edit to a frozen one.

## 1. Scope

Five algorithm bindings ("Phase 1"), matching `Ex4pm.Engine.Beam`'s
`supports?/2` surface (`discover`, `conform`, `simulate`, `optimize`) plus
POWL base-case mining (`powl_mine`, new operation atom):

| algorithm_id | Elixir engine | wasm4pm export | Elixir adapter |
|---|---|---|---|
| `discover` | `wasm_discover` | `wasm4pm_ex4pm_discover_v1` | `Ex4pmEngine.Wasm.Discover` |
| `conform` | `wasm_conform` | `wasm4pm_ex4pm_conform_v1` | `Ex4pmEngine.Wasm.Conform` |
| `simulate` | `wasm_simulate` | `wasm4pm_ex4pm_simulate_v1` | `Ex4pmEngine.Wasm.Simulate` |
| `optimize` | `wasm_optimize` | `wasm4pm_ex4pm_optimize_v1` | `Ex4pmEngine.Wasm.Optimize` |
| `powl_mine` | `wasm_powl_mine` | `wasm4pm_ex4pm_powl_mine_v1` | `Ex4pmEngine.Wasm.PowlMine` |

**Explicit non-goal:** the remaining ~65 modules under
`apps/ex4pm_engine/lib/ex4pm_engine/` (alignment, ETC precision, LTLf,
soundness proving, Petri-net/OCPN simulation variants, planning/cognition,
causal/Bayesian inference, survival analysis, etc.) are **not** covered by
this milestone. Extending coverage is adding one `epm:AlgorithmBinding`
RDF individual to `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack`
plus the matching Rust export and Elixir adapter (`use
Ex4pmEngine.Wasm.Adapter, algorithm_id: ..., ...` — three lines), not a
new one-off integration.

## 2. Source pin

- Repo: `seanchatmangpt/wasm4pm`
- Branch: `feat/ex4pm-wasm4pm-bindings-phase1`
- Exact source SHA: `435d5e0f8850898c5adb377542002adb4057c056`
- Crate: `crates/wasm4pm-ex4pm-bindings`, `crate-type = ["rlib", "cdylib"]`,
  raw `extern "C"` exports (no wasm-bindgen JS glue), matching
  `wasm4pm-cmca`'s convention.

## 3. Algorithm scope honesty

Each export is a real, correct, **minimal** implementation — not full
parity with the native Elixir modules it stands in for:

- `discover`: directly-follows-graph construction (activity set + edge
  frequency), not inductive mining.
- `conform`: directly-follows fitness (fraction of traces whose every
  consecutive pair is a model edge), not alignment-based fitness/precision.
- `simulate`: deterministic seeded-walk (xorshift64 PRNG) over a
  directly-follows graph, not full Petri-net token-game simulation.
- `optimize`: DAG longest-path (critical path by duration), not Pareto
  multi-objective optimization.
- `powl_mine`: sequence/leaf/flower base-case detection only (no
  exclusive-choice/parallel/loop cut detection yet) — a genuine "flower"
  fallback is reported honestly rather than guessing an unverified cut.

This is documented in `crates/wasm4pm-ex4pm-bindings/src/lib.rs`'s module
doc comment as well, so the scope claim lives next to the code it
describes.

## 4. ABI

Every `<algorithm_id>_v1` export takes a UTF-8 JSON request buffer
(`ptr: *const u8, len: usize`) and returns an owned `(ptr, len)` response
buffer (JSON `{"result": ..., "digest": "<fnv1a-hex>"}` on success,
`{"error": "..."}` on failure), released via
`wasm4pm_ex4pm_bindings_free_v1`. Each export pairs with an
`<algorithm_id>_replay_v1` export (recompute-and-compare) mirroring
`wasm4pm-cmca`'s `cmcaReplay` pattern.

## 5. Standing model (six states, adapted from ARD-v26.8.22 §6)

Same six-state conjunction as CMCA, minus the BCINR-specific source pin
(this is not BCINR-owned math — `epm:bcinrLike false` on every
`epm:AlgorithmBinding` individual records this explicitly):

1. **Inspection** — crate/export exists (`epm:AlgorithmBinding` in the
   `ex4pm-wasm4pm-bindings-pack` ontology).
2. **Native execution** — `cargo test -p wasm4pm-ex4pm-bindings` passes
   (7 tests, verified 2026-08-26).
3. **WASM construction** — `cargo build --target wasm32-unknown-unknown
   --release` produces a real `.wasm` (verified 2026-08-26, 329126 bytes).
4. **WASM execution** — host (Wasmex, via `Ex4pm.Engine.Wasm`'s existing
   raw-WASM route) invokes the export.
5. **Replay** — host separately invokes `<algorithm_id>_replay_v1`.
6. **Artifact identity** — exact `.wasm` SHA-256 observed
   (`c330d780610dd7ca528178043582971bce41179aba442b5cf74caf75aa160f49`
   for the pinned source SHA above, release profile).

`Ex4pmEngine.Wasm.<Algo>.execute/3` reaches `:alive` only when the
transport-reported identity binds all six states exactly (receipt schema,
`algorithm_id`, `wasm_export`, `wasm4pm_source_sha`, non-empty
request/result digests, `observed: true`, matching `wasm4pm_source_sha`,
`replay_verified: true`, non-empty `wasm_sha256`) — else `:partial_alive`,
same discipline as `Ex4pm.Engine.CmcaWasm`. States 4 and 5 (real Wasmex
invocation of the raw ptr/len ABI from Elixir, not just an injected
transport reporting them) are the remaining gap before
`.github/workflows/wasm4pm-bindings-integration.yml` can assert `:alive`
end-to-end rather than admission-shape only — tracked as follow-on work,
not silently claimed done.

## 6. Registry wiring

`Ex4pm.Engine.Registry`'s `@engines`/`preference/1` (`apps/ex4pm_engine/
lib/ex4pm/engine.ex`) ranks `wasm_discover(0) < wasm_conform(1) <
wasm_simulate(2) < wasm_optimize(3) < wasm_powl_mine(4) < beam(5) < ...` —
each Phase-1 WASM engine is preferred over `:beam` once `:alive`/
`:partial_alive`; `:beam` remains registered and unmodified as the
evidenced fallback. Per ARD-v26.8.22's own discipline and
[[testing-chicago-style]]: nothing is deleted pre-emptively. Removing
`Ex4pm.Engine.Beam`'s `discover`/`conform`/`simulate`/`optimize` branches
is a separate, later step gated on each WASM adapter independently
reaching `:alive` in real CI, not on this milestone landing.

## See also

- `docs/ARD-v26.8.22.md` — the CMCA precedent this extends
- `docs/PRD-v26.8.22.md` — CMCA product requirements (unmodified)
- `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack/` — the generative
  pack this crate and its ontology were authored from
- `apps/ex4pm_engine/lib/ex4pm_engine/wasm/adapter.ex` — the shared
  six-state adapter macro
