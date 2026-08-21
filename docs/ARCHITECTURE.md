# ex4pm architecture

## Preserve

ex4pm preserves the wasm4pm evidence law: claims may not exceed the exact subject, runtime, authority, receipt, and replay evidence supporting them. It does not preserve incidental language or product-shell choices.

## Fence

A process-mining result is not authority to modify an external process. Discovery, conformance, simulation, and optimization are SELECT/CONSTRUCT surfaces. `Ex4pm.Evidence.BRCE` is the exclusive DO boundary.

## Calculus

Objects:

- observations and admitted event logs;
- process models and POWL partial orders;
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
POWL -> ExecutionPlan
ExecutionPlan x Authority -> BRCE executions -> receipts
Receipt -> replay verification -> standing
```

Admission rejects malformed event identity, malformed object references, unsupported algorithms, invalid POWL DAGs, unavailable engines, missing authority, and replay drift.

Closure is bounded by engine capability, runtime availability, authority, deterministic identity, and replayability.

## Exclusions

- An adapter module existing is not proof its external runtime is available.
- An Ash record is a projection, not the canonical observation.
- A Broadway callback is not an actuation authority.
- A POWL task function is not executable until BRCE admits authority.
- `:wasm` does not invent a string ABI for wasm4pm wasm-bindgen builds.

## Falsifiers

Any of the following prevents an `ALIVE` claim for the affected rail:

- subject hash drift;
- unknown engine/algorithm;
- unavailable configured runtime;
- malformed OCEL reference;
- cyclic POWL partial-order graph;
- unreceipted task callback;
- missing authority capability;
- pending receipt without terminal outcome;
- outcome/artifact hash mismatch;
- replay mismatch;
- non-zero required verification command.

## Extension graph

The engine behaviour admits additional lawful implementations: GPU/Nx, distributed BEAM, CLI-port, WASI component, Rustler NIF, remote service, and independent reference oracle. New candidates extend the registry; they do not replace existing candidates by default.

The hash layer similarly identifies its algorithm. SHA-256 is the zero-dependency default. A future BLAKE3 provider can be admitted without changing receipt semantics because algorithm identity is part of each digest.
