# ex4pm v26.8.23 Requirements

Derived from the repository work completed during the preceding 24 hours and the open final-crown branch.

## Governing invariant

`observation -> parse -> route -> admit/refuse -> construct -> BRCE -> DO -> receipt -> replay -> standing`

v26.8.23 does not redesign that architecture. It converts the previous day's qualification machinery into an executable dated release contract.

## Required release obligations

1. **POWL correspondence** — bounded soundness and completeness, independent semantic oracle, generated corpus, sabotage detection, and formal Lean elaboration.
2. **Compiler refinement** — the production Elixir/Reactor lowering must be compared against the admitted formal/canonical dependency graph rather than certified by definition.
3. **Exact-head CI** — compile, umbrella tests, formatting, source capsule, formatter capsule, Chicago court, and planner capsule must execute against the admitted subject SHA.
4. **Planner OCI** — the pinned `ex4pm-plan` source must build, execute inside its exact OCI capsule, be admitted through `Ex4pm.plan/2`, and replay its receipt.
5. **Reference rails** — `:beam`, `:ex4pm_plan`, `:wasm`, `:nif`, and `:remote` must execute exact reference subjects. Shared capabilities are compared only within lawful capability-indexed equivalence classes.
6. **Distributed ambiguity closure** — pre-DO refusal, during-DO ambiguity, no automatic retry authority, and durable receipt closure remain mandatory.
7. **Independent verification** — stored standing is ignored; source/tree, artifact bytes, command logs, result hashes, topology attestations, and receipt replay are recomputed independently.
8. **Sabotage court** — every critical defect class must be detected; no survived mutation can coexist with release `ALIVE`.
9. **Global topology** — five independently identified hosts, at least two regions, at least three independently attested failure domains, TLS identity, mixed-version refusal, clock-skew safety, and external fault injection. This obligation belongs to external infrastructure authority and may not be inferred from labels or adapter configuration.
10. **Package inspection** — every public package surface must identify version `26.8.23`; package construction and inspection precede any Hex publish actuation.

## Standing rule

The executable contract is `ALIVE` only when every obligation is `ALIVE`. Missing external topology evidence yields `PARTIAL_ALIVE`; explicit `BLOCKED`, `BUILD_BROKEN`, or `REFUSED` evidence dominates and yields `BLOCKED`. No manual override exists.

## DfCM boundary

Repository CI automatically executes reversible repository-owned courts. External infrastructure mutation is never hidden inside pull-request CI. A separately authorized infrastructure court observes or actuates global topology and manufactures its own evidence bundle.
