# Choosing an engine

ex4pm keeps every candidate engine and ranks them by capability and evidence; an unavailable
engine yields a typed standing or refusal, not silent disappearance.

| Engine id | What it is | Needs | Selected |
|---|---|---|---|
| `:beam` | native deterministic Elixir | nothing | default fallback (rank 19) |
| `:wasm_<algo>` (33, `Ex4pmEngine.Wasm.*`) | admitted wasm4pm-ex4pm-bindings, real Wasmex | admitted artifact + transport (`Ex4pmEngine.Wasm.Host`, `RealTransport`, or `:<algo>_wasm_fun`) | ranked ahead of `:beam` for discover/conform/simulate/optimize/etc. but available only when a transport exists |
| `:ferroplan` | PDDL/HTN/FOND planner, wasm32-wasip1 | bundled `priv/ferroplan` artifact + pin | explicit only (`engine: :ferroplan`) |
| `:ex4pm_plan` | pinned cloud planning worker protocol | worker transport; source SHA + protocol pin | default for `Ex4pm.plan/2` |
| `:cmca_wasm` | CMCA consequence allocation | `:wasm_path`/`:wasm_contract` | default for `Ex4pm.cmca/2` |
| `:wasm` | generic raw wasm route | `:wasm_path` + `:wasm_contract` (export/parameter) | explicit |
| `:nif` | configured native NIF module | configured module | explicit |
| `:remote` | configured remote callback | callback | explicit |

Authority: every engine here is SELECT/CONSTRUCT. Only `Ex4pm.Evidence.BRCE` authorizes a
state-changing callback.

## Standing vocabulary

`UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN | UNSUPPORTED`, plus typed `REFUSED`
(atoms in code are lowercase, `:alive` etc.).

- `ALIVE`: exact admitted subject, observed execution in this run.
- `PARTIAL_ALIVE`: admitted/valid but identity or replay not fully observed.
- `BLOCKED`: prerequisite absent (e.g. no transport, no artifact).
- `UNSUPPORTED`: engine does not offer the operation.
- `REFUSED`: an `%Ex4pm.Refusal{}` with a code naming the failed term.

`Ex4pm.capabilities/2` is inspection (`executed: false`); a configured adapter or present file is
not an executed adapter.

## Cross-checking

`Ex4pm.differential/5` compares engines on the same subject, e.g. a wasm engine against `:beam`.

See also `docs/guides/real-wasm.md` and `docs/guides/planning-with-ferroplan.md`.
