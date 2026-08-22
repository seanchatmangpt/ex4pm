# ex4pm architecture

## Preserve

ex4pm preserves the wasm4pm evidence law: claims may not exceed the exact subject, runtime, authority, receipt, and replay evidence supporting them. It does not preserve incidental language or product-shell choices.

## Fence

A process-mining result is not authority to modify an external process. Discovery, conformance, simulation, and optimization are SELECT/CONSTRUCT surfaces. `Ex4pm.Evidence.BRCE` is the exclusive DO boundary.

## Calculus

Objects:

- observations and admitted event logs;
- process models and POWL 2.0 activities, strict partial orders, and choice graphs;
- engine candidates and capability claims;
- intents, authorities, pending/outcome receipts;
- semantic-control-plane projections.

Morphisms:

```text
raw -> EventLog
EventLog x Engine -> ProcessModel
EventLog x ProcessModel -> ConformanceReport
ProcessModel -> bounded simulation paths
EventLog x ProcessModel -> intervention candidates
POWL 2.0 -> bounded language materialization
POWL 2.0 -> sound WF-net projection
POWL -> ExecutionPlan
ExecutionPlan x Authority -> BRCE executions -> receipts
Receipt -> replay verification -> standing
```

POWL 2.0 keeps two graph laws separate. A partial-order relation `≺` is strict (irreflexive and transitive), while a choice graph `G = (N,E)` has distinguished source `▷` and sink `□` and may be cyclic. Every choice-graph node must lie on a `▷ -> ... -> □` path. Cyclic choice graphs denote potentially infinite languages, so enumeration is a bounded projection and cannot by itself crown unbounded language equivalence.

Admission rejects malformed event identity, malformed object references, unsupported algorithms, invalid strict partial orders, malformed choice graphs, unavailable engines, missing authority, and replay drift.

Closure is bounded by engine capability, runtime availability, authority, deterministic identity, language-materialization bounds, and replayability.

## Exclusions

- An adapter module existing is not proof its external runtime is available.
- An Ash record is a projection, not the canonical observation.
- A Broadway callback is not an actuation authority.
- A POWL task function is not executable until BRCE admits authority.
- A cyclic choice graph is not a cyclic partial order; choice-graph cycles are lawful POWL 2.0 behavior when terminal/path closure holds.
- A bounded `ℒ` materialization is not proof that an infinite cyclic language has been exhaustively enumerated.
- `:wasm` does not invent a string ABI for wasm4pm wasm-bindgen builds.

## Falsifiers

Any of the following prevents an `ALIVE` claim for the affected rail:

- subject hash drift;
- unknown engine/algorithm;
- unavailable configured runtime;
- malformed OCEL reference;
- reflexive or cyclic POWL strict-partial-order relation;
- POWL choice graph without unique `▷`/`□` terminals or source-to-sink closure;
- unreceipted task callback;
- missing authority capability;
- pending receipt without terminal outcome;
- outcome/artifact hash mismatch;
- replay mismatch;
- non-zero required verification command.

## Extension graph

The engine behaviour admits additional lawful implementations: GPU/Nx, distributed BEAM, CLI-port, WASI component, Rustler NIF, remote service, and independent reference oracle. New candidates extend the registry; they do not replace existing candidates by default.

The hash layer similarly identifies its algorithm. SHA-256 is the zero-dependency default. A future BLAKE3 provider can be admitted without changing receipt semantics because algorithm identity is part of each digest.
