# ex4pm-006: Pragmatic Craftsmanship, Public API Ergonomics, and Diátaxis Documentation

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: Dave Thomas & Andy Hunt (The Pragmatic Programmers)
- **Domain**: Software Craftsmanship, DRY, Orthogonality, API Ergonomics, Diátaxis Documentation
- **Target Files**: `lib/ex4pm.ex`, `mix.exs`, `docs/diataxis/*`, `docs/guides/*`

---

## 1. Context & Architecture

"Care about your craft." "Don't live with broken windows." "Design by contract." In systems engineering, complexity is the primary source of operational failure. When an engine integrates Erlang concurrency, WebAssembly runtimes, RDF knowledge graphs, and automated planners, the public API must remain ruthlessly simple, orthogonal, and ergonomic.

`ex4pm` adheres to Pragmatic Programmer principles:
1. **The Single Orchestrator Facade (`lib/ex4pm.ex`)**: Developers interact with a clean, unified public interface rather than navigating internal engine subsystems.
2. **Orthogonal Separation of CONSTRUCT vs DO**: Analytical planning functions are strictly CONSTRUCT-only; they manufacture candidates with zero ambient authority. State mutation is isolated exclusively to `Ex4pm.Evidence.BRCE`.
3. **Diátaxis Documentation**: Documentation is structured according to the Diátaxis framework, separating learning from problem-solving and reference from theoretical explanation.

```text
                                  Ex4pm Public Facade (lib/ex4pm.ex)
                                                  │
            ┌─────────────────────┬───────────────┴───────────────┬─────────────────────┐
            ▼                     ▼                               ▼                     ▼
       discover/2             conform/3                       simulate/2            plan/2
  (Process Discovery)    (Conformance Checking)          (Monte Carlo Run)     (HTN/PDDL Plan)
            │                     │                               │                     │
            └─────────────────────┴───────────────┬───────────────┴─────────────────────┘
                                                  ▼
                                       CONSTRUCT-Only Boundary
                                    {:ok, %Ex4pm.Run{standing}}
                                                  │
                                                  ▼  (Caller requests actuation)
                                       Ex4pm.Evidence.BRCE.execute/4
                                          (Lawful DO with Receipt)
```

---

## 2. Scope & Technical Specification

### 2.1 Public API Ergonomics (`lib/ex4pm.ex`)
The primary orchestrator defines concise, predictable function signatures:
- `Ex4pm.ingest(raw_envelope, opts \\ [])`: Ingests and normalizes OCEL/XES into `%Ex4pm.EventLog{}`.
- `Ex4pm.discover(log, opts \\ [])`: Discovers DFG or POWL models from event logs.
- `Ex4pm.conform(log, model, opts \\ [])`: Computes trace fitness, alignment, and deviation statistics.
- `Ex4pm.simulate(model, opts \\ [])`: Executes stochastic token simulations and bottleneck analysis.
- `Ex4pm.optimize(log, model, opts \\ [])`: Explores resource re-allocation and critical path speedups.
- `Ex4pm.plan(problem, opts \\ [])`: HTN and PDDL planning via Ferroplan or native engines.
- `Ex4pm.cmca/2`, `Ex4pm.ferroplan/3`, `Ex4pm.statistics/3`, `Ex4pm.forecast/2`: High-level operational helpers.

All analytical APIs return uniform result contracts:
```elixir
{:ok, %Ex4pm.Run{value: term(), standing: Ex4pm.Standing.t(), subject_hash: String.t()}}
| {:error, %Ex4pm.Refusal{code: atom(), message: String.t(), ...}}
```

### 2.2 Strict Orthogonality: CONSTRUCT vs DO
- Calling `Ex4pm.discover/2` or `Ex4pm.plan/2` will **never** trigger side effects, database writes, external network calls, or process spawns outside the analytical sandbox.
- Planners and discovery algorithms return candidate values with `authority: :construct_only`.
- To execute an action recommended by a plan, the operator or supervisory agent must pass the candidate to `Ex4pm.Evidence.BRCE.execute(subject_hash, operation, authority_claim, fun)`.
- Enforces the Pragmatic principle: "Orthogonal systems minimize side effects."

### 2.3 Diátaxis Documentation Architecture
HexDocs navigation is organized per the 4-quadrant Diátaxis framework (`mix.exs:151-206`):
1. **Tutorials** (Learning-oriented): `docs/diataxis/tutorials.md` - Step-by-step introduction for beginners from raw JSON to discovered Petri net.
2. **How-To Guides** (Problem-oriented): `docs/diataxis/how-to-guides.md`, `docs/guides/planning-with-ferroplan.md`, `docs/guides/real-wasm.md` - Practical recipes for specific production tasks.
3. **Reference** (Information-oriented): `docs/diataxis/reference.md`, `docs/ARCHITECTURE.md`, `docs/ALGORITHM-REGISTRY-GENERATION.md` - API specifications, CLI arguments, and schema definitions.
4. **Explanation** (Understanding-oriented): `docs/diataxis/explanation.md`, `docs/diataxis/explanation/boundary-and-authority-law.md` - Deep dives into authority separation, the Chatman equation ($A = \mu(O^*)$), and evidence lattices.

---

## 3. Work Completed

1. **Facade Simplification**:
   - Refactored `lib/ex4pm.ex` to ensure all dispatch routes normalize options through keyword validation.
   - Enforced consistent return tuple typing across all 9 public functions.
2. **Diátaxis Alignment**:
   - Audited all files in `docs/diataxis/` and `docs/guides/`.
   - Verified that `mix.exs` `docs/0` configuration groups modules logically:
     - "Main API" -> `Ex4pm`
     - "Evidence & Authority" -> `Ex4pm.Evidence.BRCE`, `Ex4pm.Evidence.Store`, `Ex4pm.Evidence.Receipt`
     - "Process Mining" -> `Ex4pm.POWL`, `Ex4pm.OCEL`, `Ex4pm.EventLog`
     - "Engines & WASM" -> `Ex4pmEngine.Wasm.Host`, `Ex4pmEngine.Wasm.Admission`, `AlgoRegistry`
     - "Ash & Domain" -> `Ex4pmDomain`, `ProcessIR`

---

## 4. Acceptance Criteria

- [x] All public analytical functions in `lib/ex4pm.ex` return uniform `{:ok, %Ex4pm.Run{}} | {:error, %Ex4pm.Refusal{}}`.
- [x] Zero analytical functions perform unreceipted state mutations (strict CONSTRUCT-only).
- [x] `Ex4pm.Evidence.BRCE.execute/4` remains the sole authorized mutation portal.
- [x] Diátaxis structure is reflected in `mix.exs` documentation extras and groupings.
- [x] `mix docs` compiles cleanly with no dead cross-references.

---

## 5. Verification Method

1. **Documentation Build**:
   ```bash
   mix docs
   ```
   *Expected Output*: Generates HTML documentation under `doc/` with complete Diátaxis navigation.

2. **Public API Contract Test**:
   ```bash
   mix test test/ex4pm_test.exs
   ```
   *Expected Output*: Validates return types, option parsing, and error encapsulation for all `Ex4pm.*` functions.

---

## 6. History & Receipts

- **2026-09-18**: Public API facade drafted with CONSTRUCT-only guarantees.
- **2026-10-02**: Diátaxis structure established across `docs/diataxis/`.
- **2026-11-10**: Verified API consistency and doc build for v26.11.10.
