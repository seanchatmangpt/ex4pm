# ex4pm-003: OTP Supervision Architecture, Fault Resilience, and Journaled Crash Recovery

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: Joe Armstrong (Erlang/OTP Systems & Fault-Tolerance Architect)
- **Domain**: Erlang/OTP 27 Architecture, Supervision Trees, GenStateMachine, Crash Recovery
- **Target Files**: `lib/ex4pm/application.ex`, `lib/ex4pm/engine/ferroplan/*`, `lib/ex4pm/runtime/powl_executor.ex`

---

## 1. Context & Architecture

"Make it work, then make it beautiful, then if you really have to, make it fast." More fundamentally: **"Let it crash."** In an evidence-oriented process-intelligence engine that executes WebAssembly binaries, native NIFs, and long-running planning sagas, failure is not an anomaly—it is a designed operational state.

`ex4pm` embraces the OTP philosophy:
1. No unlinked or uncontrolled concurrency.
2. Crash isolation between analytical tenants.
3. Supervision trees that prevent stale references using `:rest_for_one`.
4. Deterministic state reconstruction via journal replay rather than mutable in-memory repair.

```text
                           Ex4pm.Supervisor (:one_for_one)
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         ▼                            ▼                            ▼
  Ex4pm.Evidence.Store      Ex4pmEngine.Wasm.Host        Ferroplan.SessionSupervisor
  (ETS Receipt Ledger)     (Trap-Exit Sandboxed Host)          (:rest_for_one)
                                                                   │
                                                ┌──────────────────┴──────────────────┐
                                                ▼                                     ▼
                                       Registry (:unique)                   DynamicSupervisor
                                     (Session ID -> PID)                 (strategy: :one_for_one)
                                                                                      │
                                                                   ┌──────────────────┴──────────────────┐
                                                                   ▼                                     ▼
                                                             Session A (GenServer)                 Session B (GenServer)
                                                            [WASM Instance + Journal]             [WASM Instance + Journal]
```

---

## 2. Scope & Technical Specification

### 2.1 Ferroplan `rest_for_one` Session Supervision
In `lib/ex4pm/engine/ferroplan/session_supervisor.ex:14-38`:
- Children are ordered:
  1. `{Registry, keys: :unique, name: @registry}`
  2. `{DynamicSupervisor, strategy: :one_for_one, name: @dynamic}`
- Strategy: `:rest_for_one`.
- **Architectural Rationale**: If the Registry terminates unexpectedly, running session processes would be orphaned or mapped to invalid registration keys. Under `:rest_for_one`, the crash of the Registry automatically triggers termination and fresh restart of the DynamicSupervisor and its children, guaranteeing zero stale registry references.

### 2.2 Ferroplan Session Isolation and Journal Replay
In `lib/ex4pm/engine/ferroplan/session.ex`:
- Each planning session is a distinct GenServer registered in `SessionSupervisor.registry()`.
- Specification: `restart: :temporary` (tenants never enter crash loops).
- Memory isolation: Each session acquires its own sandboxed WebAssembly memory instance from the admitted Ferroplan module (`priv/ferroplan/ferroplan_wasm.wasm`).
- **Journal Replay Recovery**:
  - Mutating operations (`set_goal/2`, `set_fact/2`, `think/1`, `advance/1`) append structured action records to a state journal.
  - If a guest Wasm trap occurs during planning execution, the host recovers by instantiating a fresh guest instance and sequentially replaying the journal from step 0.
  - Guarantees deterministic state recovery without persisting dirty memory state.

### 2.3 GenStateMachine POWL Token Execution
In `lib/ex4pm/runtime/powl_executor.ex`:
- Implemented with `GenStateMachine` using `callback_mode: :state_functions`.
- States: `:marking`.
- Semantics: Implements the formal 1-safe Petri net token game.
- Transition firing requires token availability in all incoming places:
  ```elixir
  def handle_event({:call, from}, {:fire, transition_id}, :marking, data) do
    case check_input_tokens(transition_id, data.marking, data.net) do
      :ok ->
        new_marking = compute_next_marking(transition_id, data.marking, data.net)
        {:keep_state, %{data | marking: new_marking}, [{:reply, from, {:ok, new_marking}}]}
      {:error, missing} ->
        refusal = %Ex4pm.Refusal{code: :insufficient_tokens, missing_tokens: missing}
        {:keep_state_and_data, [{:reply, from, {:error, refusal}}]}
    end
  end
  ```
- Guarantees strict token conservation and emits typed refusals with `:missing_tokens` when tokens are depleted.

### 2.4 Bounded Concurrency & Streaming
1. `Ex4pm.Runtime.PlanningPool` (`lib/ex4pm/runtime/planning_pool.ex`): Leverages `Reactor.Executor.ConcurrencyTracker` to prevent CPU exhaustion. Sessions acquire non-blocking tokens (`acquire/2`) and register cleanup monitors (`release_on_exit/2`).
2. `Ex4pm.Stream.Pipeline` (`lib/ex4pm/stream.ex`): Broadway pipeline with bounded scheduler concurrency (`System.schedulers_online()`) and demand backpressure (`max_demand: 10`, `min_demand: 5`).

---

## 3. Work Completed

1. **Supervision Tree Validation**:
   - Verified clean application startup via `Ex4pm.Application.start/2` in all environments (`:dev`, `:test`, `:prod`).
   - Verified that `wasm_host_children/0` handles absent WASM binaries gracefully without crashing the root supervisor.
2. **Session Lifecycle & Crash Isolation**:
   - Tested session death and confirmed that one crashed session does not corrupt neighboring sessions or cause Registry leaks.
   - Verified journal replay determinism across simulated guest trap faults.
3. **GenStateMachine Token Safety**:
   - Verified state machine adherence to 1-safety invariants and typed refusal emissions.

---

## 4. Acceptance Criteria

- [x] Root supervision tree starts under `Ex4pm.Supervisor` with strategy `:one_for_one`.
- [x] `Ferroplan.SessionSupervisor` uses `:rest_for_one` ordering `{Registry, DynamicSupervisor}`.
- [x] Ferroplan sessions run with temporary restarts and dedicated WASM instances.
- [x] Journaled crash recovery correctly reconstructs planning session state.
- [x] `PowlExecutor` uses `GenStateMachine` and enforces 1-safe token conservation.
- [x] All OTP processes link cleanly and terminate without orphaned process leaks.

---

## 5. Verification Method

1. **OTP Tree & Concurrency Test Execution**:
   ```bash
   mix test test/ferroplan_runtime_test.exs test/powl_runtime_test.exs
   ```
   *Expected Output*: All OTP supervision, session registry, and GenStateMachine tests pass.

2. **Application Startup Test**:
   ```bash
   iex -S mix run -e "IO.inspect(Supervisor.which_children(Ex4pm.Supervisor))"
   ```
   *Expected Output*: Lists `Ex4pm.Evidence.Store`, `Ex4pmEngine.Wasm.Host`, and `Ex4pm.Engine.Ferroplan.Host`.

---

## 6. History & Receipts

- **2026-09-22**: Initial Ferroplan runtime and session supervisor design.
- **2026-10-05**: Added journal replay for transient WASM trap fault recovery.
- **2026-11-10**: Verified OTP 27 supervision resilience and clean shutdown for v26.11.10.
