# Algorithm Registry Generation

`lib/ex4pm_engine/wasm/algo_registry.ex` and `test/algo_registry_test.exs` are
generated projections. Do not edit them. The authority is the RDF graph.

## Pipeline

```text
priv/ontology/ex4pm.ttl            (ex4pmal:RegisteredAlgorithm, stl:StandingClaim + transitions)
+ priv/ggen/vendor/*.ttl            (vendored marketplace packs, sha256-locked)
  -> merged scratch TTL             (.ggen_igniter_tmp/, never committed)
  -> gates (SPARQL, zero rows)      (pack gates 010/030/040/050, standing-ladder 010, local 010/020)
  -> priv/ggen/queries/registered_algorithms.rq  (ORDER BY algorithm_id)
  -> priv/ggen/templates/algo_registry{.ex,_test.exs}.eex
  -> lib/ex4pm_engine/wasm/algo_registry.ex, test/algo_registry_test.exs
```

Run: `mix ex4pm.ggen.sync` (units `algo_registry`, `algo_registry_test`), then
`mix ex4pm.ggen.verify_determinism --all`. The public API is
`AlgoRegistry.algo_specs/0` (`%{module, algorithm_id, export_name,
replay_export_name, standing}`, same keys as `RealTransport.algo_specs/0` plus
`standing`) and `AlgoRegistry.algorithm_ids/0`.

## Add an algorithm

1. Add the `epm:AlgorithmBinding` individual to the pack
   (`~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack/ontology.ttl`), bump the pack
   version, run the pack's own gates.
2. Re-vendor (below).
3. Add the `ex4pmal:RegisteredAlgorithm`, `stl:StandingClaim` and its evidenced
   `stl:StandingTransition` individuals for it to `priv/ontology/ex4pm.ttl`
   (copy an existing `ex4pmal:reg_*` / `ex4pmal:claim_*` block). The local gate
   `010_every_binding_registered.rq` refuses a binding without a registration.
4. Write the leaf adapter `lib/ex4pm_engine/wasm/<algorithm_id>.ex`
   (`mix ex4pm.engine.gen.adapter <algorithm_id>`); the generated test refuses a
   registered module that is not loadable or whose `wasm_export/0` differs.
5. `mix ex4pm.ggen.sync && mix ex4pm.ggen.verify_determinism --all`.

## Update a vendored pack

```bash
priv/ggen/vendor/sync.sh [~/ggen-marketplace]
mix ex4pm.ggen.sync && mix ex4pm.ggen.verify_determinism --all
```

`sync.sh` copies `ontology.ttl` and `gates/*.rq` of each pack, rewrites
`PACKS.lock.json` (pack name, version, source git sha, tree-dirty flag, sha256
per file) and the generated `provenance.ttl` (the `prov:Entity` identity of each
pack). It is deterministic: same inputs, byte-identical lock. Both mix tasks
refuse a vendored file whose sha256 differs from the lock. Registrations cite
the pack through `prov:wasDerivedFrom ex4pmal:pack_ex4pm_wasm4pm_bindings_pack`;
version and hash live only in `provenance.ttl`, so they cannot drift by hand.

If a pack declares an `algorithm_id` that a local overlay also declares, gate
`020_unique_algorithm_id.rq` fires; delete the overlay. (No overlay exists today:
pack 0.1.2 already carries all 33 bindings.)

## Standing rungs

`stl:hasStanding` uses the 10-rung `standing-ladder-pack` ladder
(UNKNOWN, OBSERVED, VALIDATED, DERIVED, CANDIDATE, EXPERIMENTALLY_SUPPORTED,
ADMITTED, MANUFACTURED, ACTUATED, VERIFIED). It is not the 6-state
`Ex4pm.Standing` and is deliberately not mapped onto it. Gate
`standing-ladder-pack/010_no_skipped_states.rq` refuses a claim unless every
rung from UNKNOWN to its current rung has a single-step transition with a
non-empty `stl:evidenceRef`, and `stl:aboutFact` is a typed individual.

| Rung | Evidence required (checkable) |
|---|---|
| OBSERVED | binding declared in the vendored pack; adapter declares the same export |
| VALIDATED | pack gates and local registry gates return zero rows on the merged graph |
| DERIVED | registry row derived by the query; `verify_determinism` byte-identical |
| CANDIDATE | selected for a named use, cited by the consumer that selects it |
| EXPERIMENTALLY_SUPPORTED | a real-WASM test run (`test/wasm/*edge_cases_test.exs`, tag `real_wasm`) against the exact artifact, with the run's output and artifact sha256 cited |
| ADMITTED | an admission receipt for the exact subject (BRCE path) |
| MANUFACTURED / ACTUATED / VERIFIED | construct receipt, observed actuation, replay-verified receipt respectively |

All 33 registrations are currently at DERIVED. The real-WASM tests exist, but
no run against the exact artifact was recorded when these claims were written,
so none is promoted to EXPERIMENTALLY_SUPPORTED. Raising a rung means adding the
next `stl:StandingTransition` with its real evidence and changing
`stl:hasStanding`; the gate refuses it otherwise.

## Orphan removed

`priv/ggen/units/standing_coded/` (an `ex4pm.dev` ontology and query) was
unreferenced anywhere in the repository except by its own `generatedFrom`
triple; the live `standing_coded` unit reads `priv/ontology/ex4pm.ttl`. It was
deleted; it remains recoverable from git history.
