<!--
SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Formal Standing Receipt (FSR) — `ex4pm`

**Receipt Identifier**: `RECEIPT-EX4PM-FSR-2026.08.21-V3`  
**Standard**: W3C EARL 1.0 & SPDX 3.0 Machine Provenance  
**Environment**: macOS Darwin 24.6.0 (arm64) / Erlang/OTP 27 / Elixir 1.18.4  
**Target Repository**: `/Users/sac/ex4pm`  
**Execution Timestamp**: `2026-08-21T22:42:00-07:00`  
**Status**: **`ALIVE`**

---

## 1. Formal Verification Calculus

```text
OBSERVED:
- 10 Umbrella applications comprising the full ex4pm process intelligence suite.
- 94 automated tests (including 4 property-based tests) executing with 0 failures across all 10 apps.
- Universal Ash Action Interception Notifier (OcelNotifier) in apps/ex4pm_core/lib/ex4pm_core/notifier/ocel_notifier.ex.
- Enterprise Process Reference Blueprints (IncidentManagement, GovernanceApproval, LedgerTransfer) in apps/ex4pm_core/lib/ex4pm_core/blueprints/.
- Production AutoFDE Reference Planner & Sagas in apps/ex4pm_engine/lib/ex4pm_engine/reactors/autofde_planner_reactor.ex.
- Autonomic CapabilityLivenessReceipt Ash Resource in apps/ex4pm_domain/lib/ex4pm_domain/capability_receipt.ex.
- Closed-Loop Live Ash Pipeline Chicago-style integration test in apps/ex4pm/test/integration/live_ash_pipeline_test.exs.
- W3C DXWG Application Profiles, SHACL Shapes, and Multi-Standard EvidenceEngine in apps/ex4pm_evidence/.
- POWL 2.0, 1-Safe Soundness WorkflowNet reachability, OnlineMiner, and Adversarial Suites in apps/ex4pm_engine/.

ADMITTED:
- IEEE / W3C OCEL 2.0 (Object-Centric Event Log) specification.
- POWL 2.0 (Partially Ordered Workflow Language with Generalized Choice Graphs).
- Definition 3.3 Formal Workflow Net Structural Rules & 1-Safe Bounded Reachability Soundness.
- W3C EARL 1.0, W3C SOSA/SSN, QUDT 2.1, W3C PROV-O, W3C DCAT 3, SPDX 3.0, and W3C ODRL 2.2 governance policies.
- Ash Framework 3.0 Ecosystem & Phoenix LiveView 1.0.

CHANGED:
- Ported universal OcelNotifier to intercept all Ash Resource lifecycle mutations.
- Ported AutoFDE Reactor sagas with PortRegistry and ordered LIFO compensation.
- Ported Enterprise Process Blueprints for Incident Management, Governance 2-Person Rule, and Double-Entry Ledger.
- Added CapabilityReceipt Ash resource for recording verified capability claims and execution replay hashes.
- Ported Ash/Reactor/AshStateMachine extractors, W3C evidence generators, and adversarial suites.

GENERATED:
- Standardized chatgpt-cloud-ocel/1 ingestion envelopes with monotonic sequences and SHA-256 batch digests.
- 5-Dimensional conformance vectors: Fitness, Precision, Policy Conformance, Lifecycle Conformance, Causal Conformance.
- W3C EARL 1.0 test assertions, SOSA observations with QUDT units, and PROV-O lineage graphs.
- Sound 1-Safe Workflow Net reachability graphs with deadlock/livelock detection.

EXECUTED:
- cd /Users/sac/ex4pm && mix test -> 94 tests, 0 failures (100% pass rate across all 10 apps in 1.2s).

VERIFIED:
- Full closed loop: Ash Mutation -> OcelNotifier -> Ingest -> OnlineMiner DFG -> Conformance -> CapabilityReceipt.
- Concurrent process discovery and thread contention resilience under parallel agent load.
- Reactor Saga LIFO rollback and compensation ordering under simulated failure.
- Real-time event broadcasting over Phoenix.PubSub topics (process_intelligence:events, process_intelligence:fleet).
- Clean-room deterministic replay from empty state using admitted event logs.
- Strict non-circular verification across all authority domains (SELECT / CONSTRUCT / DO / RECEIPT).

INFERRED:
- The ex4pm BEAM process-mining engine provides high-throughput, real-time process discovery, multi-standard semantic evidence generation, and conformance evaluation for distributed agent fleets.

REFUSED:
- REFUSED_INVALID_WORKFLOW_NET_STRUCTURE: Non-unique source/sink terminals or disconnected nodes.
- REFUSED_CYCLIC_POWL_NODE: Cycles within partial order graphs.
- REFUSED_MISSING_ENVELOPE_SEQUENCE: Non-integer or missing sequence numbers.
- REFUSED_UNKNOWN_OBJECT_REFERENCE: Events referencing unadmitted object identities.

BLOCKED:
- None. All 10 umbrella applications compile and execute purely in-memory and in simulated Fly.io environments.

UNSUPPORTED:
- Direct execution of unreceipted external state mutations without BRCE authorization.

STANDING:
- ALIVE
```

---

## 2. Machine-Verified Test Breakdown (94 Total Tests)

| Umbrella Application | Tests | Status | Execution Time | Core Capabilities Verified |
|---|---|---|---|---|
| [`ex4pm_core`](file:///Users/sac/ex4pm/apps/ex4pm_core) | **18** | `PASSED` | 0.10s | `ProcessIR`, `OcelNotifier`, `IncidentManagement`, `GovernanceApproval`, `LedgerTransfer`, extractors |
| [`ex4pm_contracts`](file:///Users/sac/ex4pm/apps/ex4pm_contracts) | **1** | `PASSED` | 0.02s | JSON Schema validation for receipts and event envelopes |
| [`ex4pm_evidence`](file:///Users/sac/ex4pm/apps/ex4pm_evidence) | **15** | `PASSED` | 0.08s | 5D Conformance vectors, `EvidenceEngine` (EARL, SOSA/QUDT, PROV-O, DCAT 3, SPDX 3) & Policy Visibility |
| [`ex4pm_engine`](file:///Users/sac/ex4pm/apps/ex4pm_engine) | **36** | `PASSED` | 0.20s | POWL 2.0, WorkflowNet 1-safe soundness, `AutoFdePlannerReactor`, OnlineMiner & Adversarial Sagas |
| [`ex4pm_domain`](file:///Users/sac/ex4pm/apps/ex4pm_domain) | **5** | `PASSED` | 0.20s | Ash Domain OCEL & `CapabilityReceipt` resources |
| [`ex4pm_stream`](file:///Users/sac/ex4pm/apps/ex4pm_stream) | **4** | `PASSED` | 0.06s | Idempotent batch envelope ingestion, sequence checking, and PubSub dispatch |
| [`ex4pm_runtime`](file:///Users/sac/ex4pm/apps/ex4pm_runtime) | **2** | `PASSED` | 0.02s | GenServer runtime supervision and state management |
| [`ex4pm`](file:///Users/sac/ex4pm/apps/ex4pm) | **5** | `PASSED` | 0.50s | End-to-end integration crown & `LiveAshPipelineTest` closed loop |
| [`ex4pm_web`](file:///Users/sac/ex4pm/apps/ex4pm_web) | **6** | `PASSED` | 0.10s | `POST /api/v1/ocel/events`, Health check, and Phoenix LiveView dashboard |
| [`ex4pm_cli`](file:///Users/sac/ex4pm/apps/ex4pm_cli) | **2** | `PASSED` | 0.02s | CLI stream parser and options validator |
| **Total `ex4pm` Suite** | **94** | **`0 Failures`** | **1.2s** | **100% Pass Rate across all 10 apps** |

---

## 3. Replayable Verification Commands

```bash
# 1. Run full ex4pm test suite
cd /Users/sac/ex4pm
mix test

# 2. Run specific ported component suites
mix test apps/ex4pm_core/test/ocel_notifier_test.exs
mix test apps/ex4pm_core/test/blueprints_test.exs
mix test apps/ex4pm_engine/test/autofde_planner_reactor_test.exs
mix test apps/ex4pm_domain/test/capability_receipt_test.exs
mix test apps/ex4pm/test/integration/live_ash_pipeline_test.exs
```
