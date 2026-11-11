# Architecture Requirements Document (ARD) — ex4pm v26.11.10

## 1. Architectural Invariants

The `ex4pm` architecture is an evidence-bounded, mathematically verified process intelligence platform. It enforces four inviolable architectural laws:

### 1.1 The Operational Equation
$$\mathcal{A} = \mu(\mathcal{O}^*), \quad \mathcal{R} = \mathrm{receipt}(\mathcal{A})$$
- $\mathcal{O}^*$: Observations that are admitted, aligned, grounded (exact Git SHA + real command execution), and bounded by explicit gates capable of refusal.
- $\mu$: Lawful manufacture; deterministic transformation producing identical outputs for identical inputs.
- $\mathcal{R}$: Immutable evidence receipts binding five required fields:
  1. *Identity*: Exact subject hash (SHA-256 or BLAKE3).
  2. *Authority*: Granted capability ceiling (`:construct_only` vs `:do`).
  3. *Consequence*: Durably recorded state transition or observation.
  4. *Replay*: Deterministic re-execution parameters.
  5. *Standing*: Scoped status (`UNKNOWN`, `PARTIAL_ALIVE`, `ALIVE`, `BLOCKED`, `BUILD_BROKEN`, `UNSUPPORTED`).

### 1.2 Separation of Authority (SELECT, CONSTRUCT, DO)
- **SELECT**: Policy and planning phase. Proposes candidates without execution authority.
- **CONSTRUCT**: Pure or read-only analytical execution (`Ex4pm.discover/2`, `conform/3`, `simulate/2`, `plan/2`). Analytical operations execute with `:construct_only` authority and return candidate runs (`%Ex4pm.Run{}`) without mutating external state.
- **DO**: Actuation phase. Modifies system state or performs external I/O.
- **The BRCE Law**: Actuation is exclusively lawful through `Ex4pm.Evidence.BRCE.execute/5`. Zero unreceipted actuation is permitted. Before callback execution, a pending receipt is persisted to `Ex4pm.Evidence.Store`. On successful completion, an outcome receipt with standing `:alive` is recorded; on error or exception, an outcome receipt with standing `:blocked` is recorded.

---

## 2. Exact Subject Identities

| Parameter | Admitted Value | Verification Method |
|---|---|---|
| **Git Repository** | `seanchatmangpt/ex4pm` | `git remote get-url origin` |
| **Branch** | `main` | `git branch --show-current` |
| **Git HEAD SHA** | `e384dd18f58f1c3af8bb6024c1871ce7011426f4` | `git rev-parse HEAD` |
| **Base Tag** | `v26.10.8` (`9f6103a01c99782606ad06ba345ff97361d8af56`) | `git rev-parse v26.10.8` |
| **Package Name** | `:ex4pm` | `mix.exs:23` (`app: :ex4pm`) |
| **Target Release Version** | `26.11.10` | `mix.exs:18` (`@version "26.11.10"`) |
| **Hex.pm Account** | `seanchatman` | `mix hex.user whoami` |
| **WASM Manifest SHA** | `priv/wasm4pm/MANIFEST.json` | `shasum -a 256 priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm` |

---

## 3. Module Boundaries & System Topology

The system comprises six clearly decoupled module boundaries:

```text
                       +---------------------------------------+
                       |              Ex4pm (API)              |
                       |       lib/ex4pm.ex (CONSTRUCT)        |
                       +---------------------------------------+
                                           |
                   +-----------------------+-----------------------+
                   |                                               |
                   v                                               v
+-------------------------------------+         +-------------------------------------+
|        Ex4pmDomain (Ash/DSL)        |         |        Ex4pm.Evidence.BRCE          |
| 34 Resources, VerifySoundness       |         |      Sole Actuation DO Boundary     |
| lib/ex4pm_domain.ex, lib/ex4pm_domain|         | lib/ex4pm/evidence.ex               |
+-------------------------------------+         +-------------------------------------+
                   |                                               |
                   v                                               v
+-------------------------------------+         +-------------------------------------+
|      Ex4pmCore.ProcessIR            |         |          Ex4pm.Runtime              |
| Workflow Nets, DAG Extractors       |         | GenStateMachine, Broadway Streams   |
| lib/ex4pm_core/                     |         | lib/ex4pm/runtime/, lib/ex4pm/stream|
+-------------------------------------+         +-------------------------------------+
                   |                                               |
                   +-----------------------+-----------------------+
                                           |
                   +-----------------------+-----------------------+
                   |                                               |
                   v                                               v
+-------------------------------------+         +-------------------------------------+
|      Ex4pmEngine.Wasm Host          |         |    Ex4pm.Engine.Ferroplan           |
| Zero-Import Wasmex Sandbox,         |         | rest_for_one Session Supervisor,    |
| AlgoRegistry (33 algorithms)        |         | Isolated Journal Replay             |
| lib/ex4pm_engine/wasm/              |         | lib/ex4pm/engine/ferroplan/         |
+-------------------------------------+         +-------------------------------------+
```

### 3.1 `Ex4pm` Orchestration Core (`lib/ex4pm.ex`)
- Entry point for high-level operations (`discover/2`, `conform/3`, `simulate/2`, `plan/2`, `cmca/2`, `statistics/3`).
- All analytical functions execute as candidate generators under `:construct_only` authority.
- Emits `%Ex4pm.Run{}` with execution metadata, candidate outputs, and receipt hashes.

### 3.2 `Ex4pmDomain` Ash Domain & Resources (`lib/ex4pm_domain.ex`, `lib/ex4pm_domain/`)
- Declarative data plane with 34 Ash resources representing OCEL 2.0 entities, conformance results, and cognition models.
- Uses `AshAdmin.Domain` with `admin do show?(true) end` for back-office introspection.
- State machines verify workflow net soundness at compile time via `VerifySoundness`.

### 3.3 `Ex4pmCore.ProcessIR` Intermediate Representation (`lib/ex4pm_core/`)
- Canonical workflow net representations: `Activity`, `Choice`, `Loop`, `PartialOrder`, `Guard`, `Policy`.
- Extractors introspect external models without coupling:
  - `AshExtractor`: introspects Ash attributes, calculations, and relationships.
  - `AshStateMachineExtractor`: maps states and transitions to Choice branches.
  - `ReactorExtractor`: introspects Reactor sagas and step dependencies into PartialOrder nets.

### 3.4 `Ex4pmEngine.Wasm` Host & Admission (`lib/ex4pm_engine/wasm/`)
- Manages zero-import sandboxed WebAssembly execution via Wasmex.
- Generated `AlgoRegistry` exposes 33 process-mining algorithms with strict standing ladders.
- Traps exits (`trap_exit: true`) to isolate guest failures and automatically reconstructs memory instances upon crash.

### 3.5 `Ex4pm.Engine.Ferroplan` Hierarchical Task Planner (`lib/ex4pm/engine/ferroplan/`)
- Manages isolated planning sessions under a `rest_for_one` supervision strategy pairing `Registry` with `DynamicSupervisor`.
- Each session is an isolated temporary GenServer with dedicated WASM memory.
- Journals mutating operations (`set_goal`, `think`, `advance`, `set_fact`) to enable deterministic replay upon instance crash recovery.

### 3.6 `Ex4pm.Runtime` Execution Engine (`lib/ex4pm/runtime/`, `lib/ex4pm/stream.ex`)
- `PowlExecutor`: GenStateMachine implementing 1-safe Petri-net token games.
- `Stream.Pipeline`: Broadway streaming ingest with bounded demand (`max_demand: 10`, `min_demand: 5`).
- `PlanningPool`: Bounded slot concurrency tracker with automatic cleanup on process termination.

---

## 4. WASM Sandbox Admission Court Invariants

Execution of WASM guest code is governed by `Ex4pmEngine.Wasm.Admission`. Before any WebAssembly module is instantiated, it must pass five mandatory admission gates:

1. **Digest Pin Verification**:
   - The SHA-256 digest of the `.wasm` binary is computed and matched against `priv/wasm4pm/MANIFEST.json` and `priv/ferroplan/MANIFEST.json`.
   - Any digest mismatch or missing pin yields a typed refusal (`{:error, %Ex4pm.Refusal{code: :wasm_digest_mismatch}}`) and halts execution immediately.
2. **Magic Bytes Validation**:
   - The binary must begin with WebAssembly magic header `<<0, 97, 115, 109, 1, 0, 0, 0>>` (`\0asm\1\0\0\0`).
3. **Zero Host Imports**:
   - The module's imported function list is checked against `MANIFEST.json`'s `host_abi.imports`.
   - The allowlist is strictly empty (`[]`). Any attempt by the guest module to import host environment functions (filesystem, network, system clocks) is rejected at admission time.
4. **Export Completeness**:
   - The module must export linear memory (`memory`) and the memory allocator trio (`alloc_v1`, `free_v1`, `dealloc_v1`).
   - Every registered algorithm in `AlgoRegistry` must have its primary export and replay export verified.
5. **Persistent Term Admission Cache**:
   - Admitted modules are compiled once and cached in `:persistent_term` indexed by `{digest, allowlist, required_exports}`, eliminating compilation latency on subsequent calls.

---

## 5. Spark DSL Compile-Time Soundness Verification

Enterprise workflow resources in `Ex4pmDomain` (such as `Ex4pmDomain.ChangeOrder`) use the `SoundStateMachine` Spark extension:

```elixir
use Ash.Resource,
  domain: Ex4pmDomain,
  data_layer: Ash.DataLayer.Ets,
  extensions: [Ex4pmDomain.Extensions.SoundStateMachine]
```

At compile time, `Ex4pmDomain.Verifiers.VerifySoundness` inspects the resource AST:
1. Verifies that the resource implements `to_workflow_net/0`.
2. Translates states and allowed transitions into a Workflow Net with designated initial place $i$ and terminal place $o$.
3. Evaluates reachability graph properties via `Ex4pmEngine.SoundnessProver.verify_soundness/1`:
   - **Liveness**: For every transition $t$, there exists a reachable marking from which $t$ can fire (no dead transitions).
   - **Proper Completion**: When place $o$ receives a token, no tokens remain in any other place.
   - **1-Safety**: No place in the net ever accumulates more than one token ($M(p) \le 1$ for all places $p$).
4. If `report.sound?` evaluates to false, the verifier raises `Spark.Error.DslError` at compile time, preventing broken state machines from ever reaching deployment.
