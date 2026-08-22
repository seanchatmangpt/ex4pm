# ex4pm architecture

## Preserve

ex4pm preserves the wasm4pm evidence law: claims may not exceed the exact subject, runtime, authority, receipt, and replay evidence supporting them. It does not preserve incidental language or product-shell choices.

Canonical semantic objects remain in `ex4pm_core`. Execution is a projection of admitted process semantics, not a second source of process truth.

## Fence

A process-mining result is not authority to modify an external process. Discovery, conformance, simulation, and optimization are SELECT/CONSTRUCT surfaces. `Ex4pm.Evidence.BRCE` is the exclusive DO boundary.

Reactor is the single workflow execution kernel. ex4pm does not own a competing planner, scheduler, retry loop, saga executor, or task-supervisor workflow engine. `Ex4pm.Reactor` extends the Ash ecosystem by delegating directly to `Ash.Reactor`, which itself extends Reactor.

## Calculus

Objects:

- observations and admitted event logs;
- process models and POWL partial orders;
- Reactor plans as executable projections;
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
POWL -> Reactor.Builder -> Reactor.Planner -> Reactor ExecutionPlan
Reactor ExecutionPlan x Authority -> Reactor.Executor -> BRCE executions -> receipts
Receipt -> replay verification -> standing
```

Admission rejects malformed event identity, malformed object references, unsupported algorithms, invalid POWL partial orders, Reactor planning failures, unavailable engines, missing authority, and replay drift.

Closure is bounded by semantic-model capability, Reactor capability, runtime availability, authority, deterministic identity, and replayability.

## Canonical execution kernel

For executable POWL partial orders, every predecessor relation is lowered to a Reactor result dependency. Incomparable POWL elements have no dependency edge and remain eligible for Reactor-managed concurrency. A pure collector depends on every terminal task so the completed Reactor retains all terminal results without creating another scheduler.

`Ex4pm.Runtime.Plan.layers` is retained as a reversible semantic/inspection projection and compatibility surface. It is not an execution schedule. `Reactor.Planner` owns dependency planning and `Reactor.Executor` owns ready-step selection, concurrency, and lifecycle execution.

Every POWL task is represented by an `Ex4pm.Runtime.ReactorStep`. The step crosses `Ex4pm.Evidence.BRCE` exactly once before calling the admitted task executor. Reactor retries are disabled at this boundary (`max_retries: 0`) so consequential re-actuation cannot be introduced as ambient scheduler policy.

Distributed POWL execution does not introduce a second scheduler. `Ex4pm.Runtime.Distributed` computes deterministic placement and injects a remote task runner into the same Reactor execution. The remote node owns BRCE for the actual task callback; pending/outcome receipts are replay-verified and mirrored to the origin ledger.

## POWL 2.0 boundary

A POWL partial-order node maps directly to an acyclic Reactor dependency graph. Generalized/cyclic POWL 2.0 choice semantics must not be encoded as cyclic Reactor dependencies because Reactor plans are DAGs. A cyclic language must instead be admitted and unfolded into finite Reactor execution fragments through Reactor's composition/dynamic-step facilities.

This architecture therefore establishes Reactor execution canonicality without claiming that every POWL 2.0 generalized-choice construct has already earned language-equivalence standing. Full equivalence requires a falsifiable correspondence court showing that compiled Reactor traces admit exactly the bounded POWL language: no missing legal trace and no extra illegal trace.

## Exclusions

- An adapter module existing is not proof its external runtime is available.
- An Ash record is a projection, not the canonical observation.
- A Broadway callback is not an actuation authority.
- A POWL task function is not executable until BRCE admits authority.
- `POWL.layers/1` is not a scheduler.
- Distributed placement is not an executor.
- A POWL cycle is not a Reactor dependency cycle.
- `:wasm` does not invent a string ABI for wasm4pm wasm-bindgen builds.

## Falsifiers

Any of the following prevents an `ALIVE` claim for the affected rail:

- subject hash drift;
- unknown engine/algorithm;
- unavailable configured runtime;
- malformed OCEL reference;
- cyclic POWL partial-order graph;
- Reactor dependency-planning failure;
- any custom ex4pm workflow scheduler bypassing Reactor;
- unreceipted task callback;
- automatic retry of a failed BRCE task without new authority;
- missing authority capability;
- pending receipt without terminal outcome;
- distributed receipt-chain mismatch;
- outcome/artifact hash mismatch;
- replay mismatch;
- non-zero required verification command.

## Extension graph

The engine behaviour admits additional lawful implementations: GPU/Nx, distributed BEAM, CLI-port, WASI component, Rustler NIF, remote service, and independent reference oracle. New candidates extend the registry; they do not replace existing candidates by default.

Reactor extensions similarly preserve composition rather than create side runtimes: Ash-specific work belongs in `Ash.Reactor`; ex4pm-specific process semantics and evidence belong around the same Reactor plan/execution boundary.

The hash layer identifies its algorithm. SHA-256 is the zero-dependency default. A future BLAKE3 provider can be admitted without changing receipt semantics because algorithm identity is part of each digest.
