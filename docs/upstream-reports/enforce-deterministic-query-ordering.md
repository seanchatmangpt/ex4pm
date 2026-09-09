# ENFORCE-DETERMINISTIC-QUERY-ORDERING (Eliminate, upstream: ggen_igniter/ggen)

## Evidence

- `~/ggen_igniter/lib/mix/tasks/ggen_igniter.sync.ex:55-58` — the `--engine` CLI flag
  documentation: `One of: oxigraph, sparql, qlever. Default: oxigraph.` — `sparql` remains a
  selectable engine value, not removed or refused. Verified directly in this session.
- `~/ggen_igniter/lib/mix/tasks/ggen_igniter.sync.ex:692` (region 690-694) — an example
  invocation still documents `--engine sparql` as a supported, working option
  (`--engine sparql \\`). Verified directly in this session.
- `~/ggen_igniter/lib/ggen_igniter/query.ex` moduledoc (lines 3-21) — discloses an
  empirically confirmed data-corruption bug: the pure-Elixir `sparql` hex package (v0.3.12,
  the engine selected by `--engine sparql`) does not correctly honor `ORDER BY`. A join-shaped
  query mirroring real gate fixtures (`?field ex:fieldOf ?entity ; ex:fieldOrder ?field_order .
  ?entity ex:entityStruct ?entity_struct .` with `ORDER BY ?field_order` over 10 rows) came back
  in reverse order (`[9, 8, 7, 6, 5, 4, 3, 2, 1, 0]` instead of the requested ascending
  `[0, 1, ..., 9]`). The native oxigraph engine (Rustler NIF, spec-conformant SPARQL 1.1)
  returned the correct ascending order on the same query. Verified directly in this session.
- `~/ggen/crates/ggen-config/src/manifest/validation.rs:119` — `strict_mode` hard-refuses at
  compile time with `E0011` (`error[E0011]: Inference rule '{}' CONSTRUCT query lacks ORDER
  BY` / `non-deterministic triple ordering is rejected`) when a CONSTRUCT query lacks
  `ORDER BY`. Verified directly in this session (as reported by the prior research pass; not
  independently re-verified beyond confirming the cited line content, which matches).
- `~/ggen/crates/ggen-config/src/manifest/validation.rs:203` — the equivalent hard refusal for
  SELECT queries, `E0013` (`error[E0013]: Generation rule '{}' SELECT query lacks ORDER BY` /
  `non-deterministic row ordering is rejected`), with both errors offering the same escape
  hatch: `Or set \`strict_mode = false\` in [validation] to downgrade to a warning`. Verified
  directly in this session.
- `~/xaas/priv/packs/xaas_library_pack/` — a `find` for `.rq` files under paths containing
  `gates` or `queries` in this pack directory returned **28 matching files**, consistent with
  14 byte-identical `.rq` files duplicated across `gates/` and `queries/` subdirectories (14 x
  2 = 28) as reported by the prior research pass. Existence and count of `.rq` files under
  those paths verified directly in this session; byte-identity of each pair was not
  independently re-diffed in this run and is cited as reported by the prior research pass.

## Recommendation

1. **Deprecate, then hard-refuse, `--engine sparql` in `ggen_igniter.sync.ex`.** The Rust
   `ggen` core already treats non-deterministic ordering as a compile-time refusal
   (E0011/E0013) rather than a silent correctness bug. `ggen_igniter` should apply the same
   discipline to its own known-broken engine selector instead of leaving it as a documented,
   selectable default-adjacent option: first emit a deprecation warning on `--engine sparql`
   pointing at the oxigraph default and the moduledoc's disclosed reversal bug, then remove the
   `sparql` value from the accepted `--engine` enum entirely once downstream callers have
   migrated off it. Do not leave a known row-reversal bug reachable as a supported CLI value.
2. **Single-source xaas's gates/queries `.rq` files.** Byte-identical duplication across
   `priv/packs/xaas_library_pack/gates/` and `.../queries/` is a desync risk each time either
   copy is edited without the other. Symlink one directory's `.rq` files into the other (or
   generate both from one canonical source at pack-build time) so there is exactly one writable
   copy per query.

## Filed

- Date: 2026-09-09
- Claude-Session: https://claude.ai/code/session_01XWhXfubgh1b1rFNNStAQot
