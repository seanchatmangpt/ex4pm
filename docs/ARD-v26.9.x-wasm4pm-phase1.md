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

## 7. Phase 2 — thin wrappers over already-implemented wasm4pm algorithms

Per user directive: "the math should already be implemented in
~/wasm4pm." Phase 2 is a *binding* pass, not a reimplementation pass — 8
algorithms, each a thin `extern "C"` wrapper in
`crates/wasm4pm-ex4pm-bindings/src/phase2.rs` (branch
`feat/ex4pm-wasm4pm-bindings-phase2`, wasm4pm source SHA `a0eb15207
3b5f096881e8f60d0955ca5b881705a`) calling a real, pre-existing pure-Rust
function or method:

| algorithm_id | wasm4pm source | crate |
|---|---|---|
| `survival` | `miniml::kaplan_meier_impl` | `miniml-core` |
| `markov` | `miniml::compute_steady_state_impl` | `miniml-core` |
| `bayesian` | `miniml::bayesian_linear_regression_impl` | `miniml-core` |
| `ocpq_eval` | `ocpq::ocpq_eval_json` | `ocpq` |
| `strips_plan` | `wasm4pm_cognition::breeds::strips::Strips` (`CognitionBreed::run`) | `wasm4pm-cognition` |
| `htn_plan` | `wasm4pm_cognition::breeds::htn_planning::HtnPlanning` | `wasm4pm-cognition` |
| `ctl_check` | `wasm4pm_cognition::breeds::ctl_check::CtlCheck` | `wasm4pm-cognition` |
| `allen_temporal` | `wasm4pm_cognition::breeds::allen_temporal::AllenTemporal` | `wasm4pm-cognition` |

Elixir adapters (`Ex4pmEngine.Wasm.{Survival,Markov,Bayesian,OcpqEval,
StripsPlan,HtnPlan,CtlCheck,AllenTemporal}`) and the Rust `lib.rs`/
`phase2.rs`/`Cargo.toml` were generated with a real `ggen sync run`
against `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack` (not
hand-authored, unlike Phase 1) — the pack's `templates/elixir_adapter.tmpl`
uses a **templated `to:`** (`to: "apps/.../wasm/{{ row.algorithm_id }}.ex"`)
so one template + one SPARQL query over 13 `epm:AlgorithmBinding`
individuals produces all 13 adapter files (5 Phase-1 + 8 Phase-2) in a
single pipeline run — verified via `ggen sync run --dry-run` reporting
all 13 paths under `"written"`, then a real (non-dry-run) `ggen sync run`
producing byte-identical adapter shapes to the hand-authored Phase-1
files (diff showed only moduledoc wording differences), then re-run for
real (non-dry-run) `mix compile`/`mix test` against the copied output.

**Deferred, not silently dropped** — 7 of the original 15 Phase-2
candidates:

- `align`, `etc_precision`, `soundness`, `playout`, `oc_discover`,
  `causal_footprint` (`wasm4pm` main crate): each is exposed only through
  a `#[wasm_bindgen]` function built on an internal `JsValue`/object-
  handle store (`get_or_init_state().with_petri_net(handle, ...)`), which
  requires a JS host (Node/browser) to satisfy `wasm-bindgen`'s import
  ABI — the same reason `wasm4pm-cmca`'s own CI resorts to `wasm-pack
  build --target nodejs` + `node`, not a raw Wasmtime call. This is
  architecturally incompatible with `wasm4pm-ex4pm-bindings`'s raw
  ptr/len `extern "C"` ABI (built for a bare Wasmtime/Wasmex host, no JS
  runtime). Binding these needs either running through Node (breaking
  the raw-ABI symmetry with every other Phase-1/Phase-2 export) or a
  small upstream visibility change in `wasm4pm/src/*.rs` exposing the
  pure, `JsValue`-free helper functions those `#[wasm_bindgen]` functions
  already call internally (e.g. `compute_trace_alignment` in
  `alignments.rs`, currently private) — real, named follow-on work.
- `prolog_query` (`prolog8`): `Kernel`/`Catalog`/`Rule8`/`QueryAtom8`/
  `FactBlock8` don't derive `Serialize`/`Deserialize` and require a
  predicate-catalog registration step before any fact/rule/query is
  admitted — genuine integration work beyond a thin wrapper, not a
  blocker in the JsValue sense.

CPM (no full critical-path-method implementation found anywhere in the
workspace) and quantum/hypergraph/topos modeling (not found anywhere)
remain **open gaps**, restated from the original 15-candidate scope —
not claimed as bound by this or any prior pass.

Registry: `Ex4pm.Engine.Registry`'s `preference/1`
(`apps/ex4pm_engine/lib/ex4pm/engine.ex`) ranks the 8 new `:wasm_*`
engines at 5-12 (between the 5 Phase-1 engines at 0-4 and `:beam` at 13),
extending the same "WASM wins once alive, `:beam` stays as fallback"
discipline. 8 new operation atoms introduced
(`:survival`/`:markov`/`:bayesian`/`:ocpq_eval`/`:strips_plan`/
`:htn_plan`/`:ctl_check`/`:allen_temporal`) — none existed on
`Ex4pm.Engine.Beam` before; `:beam` is unmodified.

15 cargo tests pass in `wasm4pm-ex4pm-bindings` (7 Phase-1 + 8 Phase-2,
each asserting real computed values — e.g. the `markov` test asserts the
exact steady-state `[0.5, 0.5]` for a symmetric 2-state chain, not just
absence of a crash). A real `wasm32-unknown-unknown` release artifact
builds (2,700,990 bytes, SHA-256
`76ff026b0ae6dacfb6edadea98d62156bd862a09ff83c98382d2137bfde7fe5f`) with
all 8 new export symbols confirmed present by scanning the compiled
binary for their exact `extern "C"` names.
