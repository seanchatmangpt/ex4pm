# ex4pm-002: Ash Domain Architecture, Spark DSL Soundness Verification, and ProcessIR Extractors

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: Zach Daniel (Ash Framework & Declarative Modeling Architect)
- **Domain**: Ash 3.0 Ecosystem, Spark DSL Extensions, Compile-Time Verifiers, ProcessIR Introspection
- **Target Files**: `lib/ex4pm_domain.ex`, `lib/ex4pm_domain/verifiers/verify_soundness.ex`, `lib/ex4pm_core/extractor/*`

---

## 1. Context & Architecture

Process mining tools typically treat runtime processes as opaque event logs, disassociated from the business domain models that generated them. In `ex4pm`, the semantic control plane is represented through **Ash Framework 3.0** resources, backed by ETS for high-speed in-memory operations and declarative extensions powered by **Spark**.

Crucially, rather than deferring soundness verification to post-hoc runtime failures, `ex4pm` leverages **Spark compile-time DSL verifiers** to enforce structural correctness on state machines before the BEAM boots.

```text
┌────────────────────────────────────────────────────────┐
│               Compile-Time Spark Phase                 │
│                                                        │
│  ChangeOrder (Ash.Resource + SoundStateMachine DSL)    │
│                           │                            │
│                           ▼                            │
│      Ex4pmDomain.Verifiers.VerifySoundness             │
│                           │                            │
│           Evaluates to_workflow_net/0                  │
│                           │                            │
│                           ▼                            │
│      Ex4pmEngine.SoundnessProver.verify_soundness/1    │
│           ├── Liveness                                 │
│           ├── Proper Completion                        │
│           ├── No Dead Transitions                      │
│           └── 1-Safety Token Game                      │
│                           │                            │
│        [Pass] ────────────┴──────────── [Fail]         │
│          ▼                                 ▼           │
│    Emits Bytecode               Raises Spark.Error     │
└────────────────────────────────────────────────────────┘
```

---

## 2. Scope & Technical Specification

### 2.1 Ash Domain Inventory (`Ex4pmDomain`)
`lib/ex4pm_domain.ex` declares 34 Ash resources with `AshAdmin.Domain` integration (`admin do show?(true) end`):
1. **OCEL 2.0 Canonical Entities**: `Event`, `Object`, `EventObject`, `ObjectObject`.
2. **Process Mining & Conformance**: `ConformanceResult`, `PowlModel`, `ChangeOrder`, `WorkOrder`, `Incident`.
3. **Evidence & Actuation Ledger**: `Receipt`, `CapabilityReceipt`, `Refusal`, `RefusalTelemetry`.
4. **Cognition & Multi-Model Engines**: `CognitionBreed`, `BayesianNetwork`, `PrologKb`, `Plan`, `MarkovModel`, `CriticalPathNetwork`, `ParetoFront`, `AiroRiskDescription`.
5. **Infrastructure & Cluster Topology**: `ClusterNode`, `Deployment`, `MetricProbe`, `BEAMOps.KanbanCard`, `BEAMOps.SopsSecret`, `BEAMOps.TerraformResource`, `BEAMOps.DockerImage`, `BEAMOps.CiPipelineJob`, `BEAMOps.AlertRule`.

### 2.2 Compile-Time Verification (`VerifySoundness`)
- Located at `lib/ex4pm_domain/verifiers/verify_soundness.ex`.
- Invoked automatically via `Spark.Dsl.Extension` on resources using `Ex4pmDomain.Extensions.SoundStateMachine`.
- Verifies that:
  - If a resource defines a workflow net (`to_workflow_net/0`), the net is analyzed via `Ex4pmEngine.SoundnessProver.verify_soundness/1`.
  - Proper termination: starting from initial marking, final marking is reachable.
  - Absence of deadlocks: no marking reachable from initial marking is a non-terminal deadlock.
  - Liveness: every transition can be fired in at least one reachable marking.
  - 1-Safety: places never accumulate > 1 token under safe execution.
  - Any violation immediately halts compilation with an explicit `Spark.Error.DslError`.

### 2.3 ProcessIR Automatic Extractors (`lib/ex4pm_core/extractor/`)
The canonical `Ex4pmCore.ProcessIR` enables bidirectional mapping between declarative specifications and analytical process models:
1. `Ash` (`extractor/ash.ex`): Introspects Ash resource actions, attributes, and identities into `ProcessIR.Activity` and `ProcessIR.Relationship`.
2. `AshStateMachine` (`extractor/ash_state_machine.ex`): Introspects `AshStateMachine.Info.states/1` and `transitions/1` into branching `ProcessIR.Choice` structures.
3. `Reactor` (`extractor/reactor.ex`): Translates step DAG dependencies (`wait_for`), compensation rollbacks, and around hooks into `ProcessIR.PartialOrder` and guarded execution policies.

---

## 3. Work Completed

1. **Ash Resource Standardization**:
   - Verified all 34 resources compile under Ash 3.31+ with strict type checking.
   - Enforced string length codepoint configuration (`Application.put_env(:ash, :default_string_length_count, :codepoints)` in `mix.exs:15`).
2. **Compile-Time Soundness Verification**:
   - Integrated `VerifySoundness` into `ChangeOrder` and workflow resources.
   - Confirmed compile-time failure generation when an unsound transition (e.g. unreachable state or terminal leak) is declared.
3. **ProcessIR Extractor Parity**:
   - Unit-tested extractors across Ash resources, state machines, and Chicago Reactor sagas.
   - Verified that extracted models roundtrip into POWL trees and Petri nets without semantic loss.

---

## 4. Acceptance Criteria

- [x] All 34 Ash resources load into `Ex4pmDomain` and expose administrative views in `AshAdmin`.
- [x] `Ex4pmDomain.Verifiers.VerifySoundness` executes at compile-time as part of the Spark lifecycle.
- [x] Unsound state machine topologies fail `mix compile` with informative `Spark.Error.DslError` messages.
- [x] ProcessIR extractors for Ash, AshStateMachine, and Reactor generate valid `Ex4pmCore.ProcessIR` data structures.
- [x] Zero compilation warnings under `mix compile --warnings-as-errors`.

---

## 5. Verification Method

1. **Compiler Warning & DSL Check**:
   ```bash
   mix compile --warnings-as-errors
   ```
   *Expected Output*: Exit code 0, 438 files compiled cleanly.

2. **Domain Resource Introspection Test**:
   ```bash
   mix test test/ex4pm_domain_test.exs
   ```
   *Expected Output*: Verifies resource enumeration, ETS backing, and Spark verification execution.

---

## 6. History & Receipts

- **2026-09-28**: Initial Spark extension and verifier implementation.
- **2026-10-18**: Expanded resource inventory to 34 resources including BEAMOps and cognition entities.
- **2026-11-10**: Verified compile-time soundness gating and Ash 3.31 compatibility for v26.11.10 release.
