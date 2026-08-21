# ex4pm agent contract

## Governing law

ex4pm is an evidence-oriented BEAM process-intelligence system. Preserve the sequence:

parse -> route -> admit/refuse -> construct -> BRCE -> DO -> receipt -> replay -> standing.

SELECT, CONSTRUCT, and DO are separate authority domains. Only `Ex4pm.Evidence.BRCE` may authorize a state-changing callback. A pending receipt must exist before callback invocation and an outcome receipt must terminate every attempted invocation.

## DfCM

Preserve the maximal reversible lawful candidate graph before selecting an implementation. A failed BEAM, WASM, NIF, remote, stream, or projection edge is topology, not proof that the entire graph is impossible. Selection must be explicit or evidence-ranked.

## Evidence vocabulary

Use `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN | UNSUPPORTED` and typed `REFUSED`. Inspection is not execution. A configured adapter is not an executed adapter. A receipt-shaped map is not a replay-verified receipt.

## Editing surfaces

Canonical semantic objects live in `ex4pm_core`. Engine, runtime, stream, domain, CLI, and future web surfaces are projections/adapters. Never make an adapter's incidental representation canonical without an admitted equivalence proof.

## Verification

Prefer `mix verify`. For a narrower repair, run the owning app test first, then expand. Exact-head CI supplements local proof; it does not replace local proof when a local BEAM is available.
