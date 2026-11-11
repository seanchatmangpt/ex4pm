# Architectural & Erlang/OTP Review: ex4pm (v26.11.10)

**Reviewer**: Joe Armstrong (Co-inventor of Erlang)  
**Role**: Expert Architectural Reviewer — Erlang/OTP Concurrency, Fault Isolation, Process Boundaries & Supervision Topologies  
**Target Milestone**: v26.11.10 Hex.pm Production Release  
**Working Directory**: `/Users/sac/ex4pm`  
**Date**: November 11, 2026  

---

## 1. Executive Summary

When Robert Virding, Mike Williams, and I designed Erlang at the Ericsson Computer Science Lab in the late 1980s, we were trying to solve a very concrete industrial problem: how to build fault-tolerant systems that run forever, handle thousands of concurrent telephone calls, and never stop for software upgrades or hardware faults. We didn't invent processes or message passing to look clever; we invented them because **the real world is concurrent**, hardware fails, programmers make mistakes, and **if you cannot isolate a crash, you cannot build a reliable system**.

Looking at `ex4pm` through the lens of Erlang and OTP philosophy is deeply fascinating. This is a system tackling process mining, Petri-net token games, and automated planning on the BEAM. It integrates WebAssembly runtimes (`wasm4pm` and `ferroplan`) alongside Elixir and Ash. 

There is an enormous amount of brilliant, principled engineering here:
1. **The Separation of Calculation (`CONSTRUCT`) and Consequence (`DO`)**: In `Ex4pm.Evidence.BRCE`, state-changing actuation requires an explicit, audited receipt boundary. Candidate generation does not mutate the external world. That is pure Erlang thinking—computation is functional and side-effects are quarantined.
2. **True Ephemeral Process Isolation in Planning Sessions**: In `Ex4pm.Engine.Ferroplan.Session`, each planning session is an isolated `GenServer` running with `restart: :temporary`, paired with its own dedicated WASM instance. If a guest traps, only that session dies. The guest memory is discarded, and the session can recover deterministically by replaying its operational journal.
3. **The `rest_for_one` Session Topology**: In `Ex4pm.Engine.Ferroplan.SessionSupervisor`, pairing a `Registry` (`keys: :unique`) with a `DynamicSupervisor` under a `:rest_for_one` strategy is textbook OTP: if the Registry dies, all child sessions whose names are registered in it are terminated and restarted cleanly, preventing dangling registrations.

However, alongside these architectural triumphs, my inspection has surfaced several serious **OTP anti-patterns, process boundary violations, and concurrency failure modes**:
1. **The Orphan Supervisor Anti-Pattern (`Ex4pm.Engine.Ferroplan.Sessions.ensure_started/0`)**: `SessionSupervisor` is not in the top-level application supervision tree. Instead, it is lazily started via `Process.unlink(pid)` by whichever arbitrary caller process needs it first. It runs unlinked and unsupervised. If `SessionSupervisor` crashes, nothing restarts it.
2. **Missing Exit Trapping in `Ex4pm.Engine.Ferroplan.Host` (`lib/ex4pm/engine/ferroplan.ex:27`)**: `Ferroplan.Host` manages WASM instances linked to itself, but **it fails to trap exits (`Process.flag(:trap_exit, true)` is absent)**. If a guest WASM instance crashes abnormally, the exit signal propagates directly to `Ferroplan.Host`, killing it and blowing away the entire map of running instances across all users on that node.
3. **Asynchronous Registry De-registration Race (`lib/ex4pm/engine/ferroplan/sessions.ex:150-156`)**: In `Sessions.list/0`, `Registry.select` is called directly without verifying `Process.alive?/1`. When a session terminates, the caller receiving `{:DOWN, ...}` immediately queries `Sessions.list/0` before the Registry partition process has processed its own monitor message, causing test failures (witnessed in `test/engine_ferroplan_session_test.exs:80`).
4. **Petri-Net Multiset Input Flaw in `PowlExecutor` (`lib/ex4pm/runtime/powl_executor.ex:98-106`)**: `PowlExecutor` uses `GenStateMachine` to model the token game. But transitions with multiset input requirements (multiple tokens from the same place) evaluate `Enum.all?(inputs, fn p -> Map.get(marking, p, 0) > 0 end)`, allowing transitions requiring multiple tokens to fire with only one token!
5. **Unbounded Memory & Synchronous Callback Execution in `OnlineMiner` (`lib/ex4pm/engine/online_miner.ex:214, 446`)**: `OnlineMiner` is a single GenServer accumulating every event in memory forever (`traces: %{}`) without eviction or TTL, creating an inevitable out-of-memory crash in production. Furthermore, it executes user-supplied subscriber functions synchronously inside its server loop, allowing any slow subscriber to stall event ingestion.
6. **Slot Leakage on Abnormal Termination in `PlanningPool` (`lib/ex4pm/runtime/planning_pool.ex:45-49`)**: When acquiring more than 1 slot and registering `release_on_exit`, `Reactor.Executor.ConcurrencyTracker` only releases a single slot on `:DOWN`, permanently leaking capacity.

**Verdict**: **APPROVE WITH RECOMMENDATIONS**. The underlying process isolation model and journal replay architecture are sound, robust, and aligned with BEAM principles. Resolving the supervision and concurrency boundary findings outlined below will make `ex4pm` an industrial-strength showcase of Erlang/OTP engineering.

---

## 2. Persona Perspective & Philosophical Alignment

When we wrote systems at Ericsson, we distilled our experience into five core aphorisms. Let us evaluate `ex4pm` against each of them.

### 2.1 The World is Concurrent
> *"The world is parallel. If you want to write programs that model the world, your programs should be parallel."*

In process mining, events arrive from multiple distributed services, agents, and users simultaneously. In `ex4pm`, concurrent execution is respected:
- Multiple ferroplan sessions run in parallel across isolated processes (`test/engine_ferroplan_session_test.exs:153` proves 20 concurrent sessions run with zero state leakage).
- POWL process models execute their token games within dedicated state machine processes (`PowlExecutor`).
- However, `OnlineMiner` attempts to funnel *all* distributed event telemetry across all agents into a single GenServer via synchronous `handle_call({:ingest, ...})`. This turns concurrency into a serialization queue.

### 2.2 Processes Have Independent Life and Share Nothing
> *"A process is an isolated island of memory with a mailbox. No shared memory. If you want to communicate, you send a message."*

Where `ex4pm` adheres to this rule, it is brilliant:
- `Ex4pm.Engine.Ferroplan.Session` does not share WASM memory between sessions. Every session allocates its own WASM instance and keeps its guest handle private. If one session crashes or corrupts its memory, no other session is affected.
- But where NIFs and WASM runtimes enter the picture (`Wasmex`), programmers often forget that **a NIF can bring down the entire BEAM node**. Running native code inside a BEAM process does not grant magic memory protection if the native code segfaults. `ex4pm` correctly isolates WASM instances inside separate processes, but must respect the boundary between Erlang exit signals and native crashes.

### 2.3 "Let It Crash" and the Error Kernel
> *"Do not program defensively. Let the process crash. Another process—a supervisor—will clean up and decide what to do."*

The "Let it crash" philosophy does not mean "ignore errors and let the system burn down." It means:
- The **Error Kernel** (the critical state that must never be corrupted) must be small, verified, and protected.
- Workers that do dirty, fallible work should be ephemeral (`restart: :temporary`). When they crash, they die completely and drop their state.
- `Ex4pm.Engine.Ferroplan.Session` is a masterclass in this: it uses `restart: :temporary` (line 24). It does not try to catch low-level WASM traps and limp along with corrupted memory. When the WASM instance dies, the GenServer receives `{:EXIT, pid, reason}`, discards the dead instance, and transitions to a known clean state. It can then replay its journal from scratch.
- But `Ex4pm.Engine.Ferroplan.Host` breaks this rule by failing to trap exits, meaning a crash in a guest worker crashes the supervisor/host!

### 2.4 Supervision Hierarchies: Who Watches the Watchers?
> *"Supervisors supervise workers and other supervisors. There must always be a root. If an orphan process is floating in space, who restarts it when it dies?"*

An OTP application should have a clear, unbroken supervision tree stemming from the Application callback down to the leaves.
- In `lib/ex4pm/application.ex`, we see `Supervisor.start_link(children, strategy: :one_for_one, name: Ex4pm.Supervisor)`.
- But where is `SessionSupervisor`? It is absent!
- Instead, `Sessions.ensure_started/0` starts `SessionSupervisor` lazily, unlinks it (`Process.unlink(pid)`), and lets it float detached from the OTP supervision tree. That is an orphan. If `SessionSupervisor` crashes, it stays dead.

### 2.5 Message Passing Semantics and Backpressure
> *"Send and pray is fine for notifications, but when you want certainty, use a call. When you call, think about timeouts. And never do slow work in a server's message loop."*

In `lib/ex4pm/engine/online_miner.ex`, lines 446-455:
```elixir
  defp maybe_notify(%{subscriber: subscriber} = state, event_type, payload)
       when is_function(subscriber, 2) do
    try do
      subscriber.(event_type, %{state: state, payload: payload})
    rescue
      _ -> :ok
    end
  end
```
Executing an arbitrary anonymous function `subscriber.(...)` synchronously inside the GenServer's `handle_call` callback violates message-passing hygiene. If the subscriber performs disk I/O, database access, or sleeps, the entire `OnlineMiner` GenServer stops responding to all clients!

---

## 3. Deep Dive & Code Citations

Let us examine the exact source code locations and analyze their behavior.

### 3.1 `Ex4pm.Application` (`lib/ex4pm/application.ex:1-41`)
```elixir
13:   @impl true
14:   def start(_type, _args) do
15:     children =
16:       [{Ex4pm.Evidence.Store, name: Ex4pm.Evidence.Store}] ++
17:         wasm_host_children()
18: 
19:     Supervisor.start_link(children, strategy: :one_for_one, name: Ex4pm.Supervisor)
20:   end
21: 
22:   # `config :ex4pm, :wasm_host, true | false` (default true). A missing or
23:   # unadmitted artifact never fails boot: the Host starts and reports a typed
24:   # refusal instead.
25:   defp wasm_host_children do
26:     if Application.get_env(:ex4pm, :wasm_host, true) do
27:       [
28:         Ex4pmEngine.Wasm.Host,
29:         %{
30:           id: Ex4pm.Engine.Ferroplan.Host,
31:           start:
32:             {GenServer, :start_link,
33:              [Ex4pm.Engine.Ferroplan.Host, %{}, [name: Ex4pm.Engine.Ferroplan.Host]]},
34:           restart: :permanent
35:         }
36:       ]
37:     else
38:       []
39:     end
40:   end
```
**Observation**:
The top-level supervisor starts `Ex4pm.Evidence.Store`, `Ex4pmEngine.Wasm.Host`, and `Ex4pm.Engine.Ferroplan.Host` under a `:one_for_one` strategy.
**Analysis**:
1. `Ex4pm.Evidence.Store` is the persistence layer for receipts and audit trails. Putting it under `:one_for_one` is appropriate.
2. Missing from this tree: `Ex4pm.Engine.Ferroplan.SessionSupervisor`, `Ex4pm.Engine.OnlineMiner`, and any runtime supervisors for POWL execution.
3. Because `SessionSupervisor` is omitted here, it is forced to be started lazily in userland, breaking the unified OTP supervision tree.

---

### 3.2 The Orphan Supervisor Anti-Pattern (`SessionSupervisor` & `Sessions`)
**Location**: `lib/ex4pm/engine/ferroplan/session_supervisor.ex:1-38` and `lib/ex4pm/engine/ferroplan/sessions.ex:43-64`

In `session_supervisor.ex`:
```elixir
30:   def init(_opts) do
31:     children = [
32:       {Registry, keys: :unique, name: @registry},
33:       {DynamicSupervisor, strategy: :one_for_one, name: @dynamic}
34:     ]
35: 
36:     Supervisor.init(children, strategy: :rest_for_one)
37:   end
```
This supervision structure is genuinely exemplary:
- If `DynamicSupervisor` crashes, only the child sessions die. `Registry` stays alive.
- If `Registry` crashes, the strategy is `:rest_for_one`: the `DynamicSupervisor` is terminated and restarted, killing all existing sessions. This is essential because the names registered in the old Registry are dead; restarting the sessions ensures they re-register in the new Registry.

**The Fatal Flaw**: Look at how `SessionSupervisor` is actually started in `lib/ex4pm/engine/ferroplan/sessions.ex:43-64`:
```elixir
43:   def ensure_started do
44:     case Process.whereis(SessionSupervisor) do
45:       pid when is_pid(pid) ->
46:         :ok
47: 
48:       nil ->
49:         case SessionSupervisor.start_link([]) do
50:           {:ok, pid} ->
51:             Process.unlink(pid)
52:             :ok
53: 
54:           {:error, {:already_started, _}} ->
55:             :ok
...
```
**Analysis**:
Line 51 calls `Process.unlink(pid)`!
Why did the developer write `Process.unlink(pid)`? Because whoever called `Sessions.ensure_started/0` (often a short-lived Task, HTTP request, or test process) would otherwise link to `SessionSupervisor`. When that caller terminated, `SessionSupervisor` would be dragged down with it!
So the developer unlinked it. But unlinking a supervisor leaves it **completely unparented**. It is not part of `Ex4pm.Supervisor`. If `SessionSupervisor` crashes (e.g. from an unhandled exit or memory pressure), nothing in the BEAM restarts it!
This is the classic **Orphan Supervisor Anti-Pattern**.

---

### 3.3 `Ex4pm.Engine.Ferroplan.Session` Isolation and Journal Replay
**Location**: `lib/ex4pm/engine/ferroplan/session.ex:1-302`

```elixir
24:   use GenServer, restart: :temporary
...
70:   def init(args) do
71:     Process.flag(:trap_exit, true)
...
154:   def handle_info({:EXIT, pid, _reason}, %{transport: pid} = state),
155:     do: {:noreply, %{state | transport: nil}}
```
And recovery via journal replay (lines 131-139, 235-249):
```elixir
131:   def handle_call(:recover, _from, state) do
132:     stop_transport(state)
133:     state = %{state | transport: nil, handle: nil}
134: 
135:     case boot(state) do
136:       {:ok, state} -> {:reply, {:ok, info(state)}, state}
137:       {:error, refusal, state} -> {:reply, {:error, refusal}, state}
138:     end
139:   end
```
```elixir
235:   defp replay(state) do
236:     Enum.reduce_while(Enum.reverse(state.journal), {:ok, state}, fn {op, req}, acc ->
237:       case guest(state, op, req, call_opts(state.opts)) do
238:         {:ok, _} -> {:cont, acc}
239:         {:error, cause} -> {:halt, {:error, ...}}
240:       end
241:     end)
242:   end
```
**Analysis & Praise**:
This is exceptional Erlang engineering:
1. `restart: :temporary` means if the `Session` GenServer itself dies, the `DynamicSupervisor` does NOT restart it automatically. This prevents resurrecting a session with invalid external client references.
2. `Process.flag(:trap_exit, true)` ensures that when the child WASM transport process (`state.transport`) crashes or traps, `Session` receives `{:EXIT, pid, reason}` and sets `state.transport = nil`.
3. Calls while the transport is dead return a clear, typed refusal (`:ferroplan_session_instance_lost`).
4. Calling `recover/1` allocates a completely fresh WASM instance, allocates a new guest handle, and deterministically replays every mutating operation from `state.journal`.
5. This is true fault tolerance: the failure is confined to the WASM worker, the session state is preserved in the Elixir heap, and recovery is deterministic.

---

### 3.4 Asynchronous Registry De-registration Race
**Location**: `lib/ex4pm/engine/ferroplan/sessions.ex:150-156`

```elixir
150:   @spec list() :: [session_id()]
151:   def list do
152:     Registry.select(SessionSupervisor.registry(), [{{:"$1", :_, :_}, [], [:"$1"]}])
153:     |> Enum.sort()
154:   rescue
155:     ArgumentError -> []
156:   end
```
In `test/engine_ferroplan_session_test.exs:80-104`:
```elixir
98:     ref = Process.monitor(pid)
99:     assert {:error, %Refusal{code: :ferroplan_engine_error}} = Sessions.free(id)
100:     assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
101:     refute Process.alive?(pid)
102:     refute id in Sessions.list()
```
**Witnessed Failure**:
```
  1) test free removes the process and the guest handle is rejected (Ex4pm.EngineFerroplanSessionTest)
     test/engine_ferroplan_session_test.exs:80
     Refute with in failed
     code:  refute id in Sessions.list()
     left:  "fps_a196206f5445022f"
     right: ["fps_a196206f5445022f"]
     stacktrace:
       test/engine_ferroplan_session_test.exs:102: (test)
```
**Analysis**:
Why did `refute id in Sessions.list()` fail immediately after receiving `assert_receive {:DOWN, ...}`?
Because of how Elixir's `Registry` is implemented:
- When a process registered with `Registry` terminates, the Registry partition process that monitors it receives a `{:DOWN, ...}` message and deletes the key from its ETS table.
- In the test, the test runner process ALSO monitors `pid`.
- The exit signal reaches the test runner's monitor, delivering `{:DOWN, ...}` to the test.
- The test runner immediately executes `Sessions.list/0`.
- BUT the Registry partition process has not yet scheduled or executed its `{:DOWN, ...}` handler!
- The dead process's key is still present in the Registry ETS table!

Notice that in `Sessions.lookup/1` (`sessions.ex:204-210`), the author already knew this:
```elixir
  defp lookup(session_id) do
    case Session.whereis(session_id) do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: {:ok, pid}, else: not_found(session_id)
...
```
`lookup/1` checks `Process.alive?(pid)`. But `Sessions.list/0` does NOT check `Process.alive?(pid)`! It simply selects all keys from the ETS table.
**Fix**: `Sessions.list/0` must filter out keys whose registered PIDs are no longer alive:
```elixir
def list do
  SessionSupervisor.registry()
  |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  |> Enum.filter(fn {_id, pid} -> Process.alive?(pid) end)
  |> Enum.map(&elem(&1, 0))
  |> Enum.sort()
rescue
  ArgumentError -> []
end
```

---

### 3.5 `Ex4pm.Runtime.PowlExecutor` and the Multiset Token Bug
**Location**: `lib/ex4pm/runtime/powl_executor.ex:1-116`

```elixir
22:   use GenStateMachine, callback_mode: :state_functions
...
67:   @impl GenStateMachine
68:   def init(%Data{} = data), do: {:ok, :marking, data}
69: 
70:   # state name is :marking throughout — this is a single-state token-game
71:   # machine, all the interesting transitions live in the *data*.
72:   def marking(:enter, _old_state, _data), do: :keep_state_and_data
...
78:   def marking({:call, from}, {:fire, transition_id}, %Data{} = data) do
79:     case Map.fetch(data.transitions, transition_id) do
...
84:         if enabled?(data.marking, inputs) do
85:           new_marking =
86:             data.marking
87:             |> consume(inputs)
88:             |> produce(outputs)
...
98:   defp enabled?(marking, inputs) do
99:     Enum.all?(inputs, fn place -> Map.get(marking, place, 0) > 0 end)
100:   end
101: 
102:   defp consume(marking, inputs) do
103:     Enum.reduce(inputs, marking, fn place, acc ->
104:       Map.update(acc, place, 0, &max(&1 - 1, 0))
105:     end)
106:   end
```
**Analysis**:
1. **The Single-Mode State Machine**: The module uses `GenStateMachine` with `callback_mode: :state_functions`. But the machine has only *one* state: `:marking`. In OTP, `gen_statem` is designed for systems that transition between distinct states (e.g. `:idle -> :running -> :terminated`). When there is only one state and all state changes are data transformations inside `%Data{}`, a standard `GenServer` is the idiomatic OTP abstraction. Alternatively, if `GenStateMachine` is retained, it should model genuine Petri-net lifecycle states: `:active`, `:quiescent` (no transitions enabled), and `:terminal` (tokens in sink places).
2. **The Multiset Input Bug**: Look at line 98:
   `Enum.all?(inputs, fn place -> Map.get(marking, place, 0) > 0 end)`
   In Petri nets and POWL models, transitions can have input arc weights > 1, represented as duplicate entries in `inputs` (e.g. `inputs: [:p1, :p1]`).
   If place `:p1` currently has **1 token**, what happens?
   - `Enum.all?` checks `:p1` the first time: `1 > 0` (true).
   - `Enum.all?` checks `:p1` the second time: `1 > 0` (true).
   - `enabled?` returns `true`!
   - Then `consume` runs:
     - First `:p1`: `max(1 - 1, 0) = 0`.
     - Second `:p1`: `max(0 - 1, 0) = 0`.
   - The transition fires successfully, consuming 2 required tokens when only 1 existed!
   - This breaks Petri-net token conservation laws.

**Fix**: `inputs` must be treated as a multiset (frequency map of place => required tokens):
```elixir
defp enabled?(marking, inputs) do
  required = Enum.frequencies(inputs)
  Enum.all?(required, fn {place, count} -> Map.get(marking, place, 0) >= count end)
end

defp consume(marking, inputs) do
  required = Enum.frequencies(inputs)
  Enum.reduce(required, marking, fn {place, count}, acc ->
    Map.update(acc, place, 0, &max(&1 - count, 0))
  end)
end
```

---

### 3.6 Host Supervision and the NIF Reality (`Ex4pmEngine.Wasm.Host`)
**Location**: `lib/ex4pm_engine/wasm/host.ex:1-268`

```elixir
129:   @impl true
130:   def init(opts) do
131:     Process.flag(:trap_exit, true)
...
170:   @impl true
171:   def handle_info({:EXIT, pid, _reason}, %{instance: %{pid: pid}} = state) do
172:     {:noreply, state |> Map.put(:instance, nil) |> boot() |> bump()}
173:   end
```
**Analysis**:
1. `Host` traps exits and restarts its Wasmex instance when it receives `{:EXIT, pid, reason}`.
2. **Lack of Intensity Bounds**: Standard OTP supervisors enforce `{max_restarts, max_seconds}` (e.g. maximum 3 restarts in 5 seconds). `Host` has no intensity check. If a corrupted WASM binary or memory state causes the instance to crash immediately upon boot or the first call, `Host` will thrash in a tight crash-reboot loop, consuming 100% CPU. A standard sliding window restart counter should be implemented.
3. **The NIF Reality Check**: `Wasmex` executes via a Rust NIF using Wasmtime. Wasmtime safely catches WASM bytecode traps (e.g. division by zero, out of bounds memory). However, if the Rust runtime itself panics or aborts, **the entire BEAM operating system process crashes immediately**. NIF crashes cannot be trapped by `Process.flag(:trap_exit, true)`. Architecture documentation should clearly acknowledge that NIF fault tolerance is bounded by Rust runtime integrity.
4. **Test Environment Fragility (`test/wasm/host_test.exs:11-14`)**:
   In `Host.artifact_path/1`, fallback to `Application.app_dir(:ex4pm, "priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm")` is built-in. But in `test/wasm/host_test.exs`, `@artifact` hardcodes:
   `Path.expand("~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm")`.
   Because this path does not exist on standard test runner machines, all 6 tests in `host_test.exs` were silently skipped during test execution unless `EX4PM_WASM_ARTIFACT` was passed manually. The test should default to the bundled artifact in `priv/wasm4pm/`.

---

### 3.7 `Ex4pm.Engine.Ferroplan.Host` Missing Exit Traps
**Location**: `lib/ex4pm/engine/ferroplan.ex:1-64`

```elixir
1: defmodule Ex4pm.Engine.Ferroplan.Host do
...
6:   use GenServer
...
26:   @impl true
27:   def init(state), do: {:ok, state}
...
58:   defp start(key, artifact, opts, state) do
59:     case Ex4pmEngine.Wasm.FerroplanTransport.start(artifact, Keyword.delete(opts, :wasm_sha256)) do
60:       {:ok, pid} -> {:reply, {:ok, pid}, Map.put(state, key, pid)}
61:       {:error, _} = err -> {:reply, err, state}
62:     end
63:   end
```
**Analysis of Blast Radius**:
Look at line 27: `def init(state), do: {:ok, state}`.
`Process.flag(:trap_exit, true)` is **NOT** called.
In line 59, `FerroplanTransport.start` calls `Wasmex.start_link`.
Because `start` is executed inside `Ferroplan.Host`'s message loop, the resulting `pid` is **linked to `Ferroplan.Host`**.
When that WASM instance crashes with an abnormal exit:
- Because `Ferroplan.Host` does NOT trap exits, the exit signal kills `Ferroplan.Host` immediately.
- `Ex4pm.Supervisor` restarts `Ferroplan.Host` with an empty state (`%{}`).
- The entire cache of active WASM instances across all other callers is wiped out!
**Fix**: `Ferroplan.Host` must call `Process.flag(:trap_exit, true)` in `init/1` and implement `handle_info({:EXIT, pid, _reason}, state)` to prune dead pids from `state`.

---

### 3.8 `Ex4pm.Engine.OnlineMiner` Unbounded Memory & In-Loop Callbacks
**Location**: `lib/ex4pm/engine/online_miner.ex:1-473`

```elixir
66:     state = %{
...
73:       # trace_id => [%Event{}]
74:       traces: %{},
...
214:     trace = Map.get(state.traces, run_id, [])
215:     new_trace = [event | trace]
216:     new_traces = Map.put(state.traces, run_id, new_trace)
```
And the variant recalculation on every event:
```elixir
319:     trace_path = new_trace |> Enum.reverse() |> Enum.map(& &1.activity)
320:     new_variants = update_variants(state.variants, trace, trace_path)
```
And subscriber notification:
```elixir
446:   defp maybe_notify(%{subscriber: subscriber} = state, event_type, payload)
447:        when is_function(subscriber, 2) do
448:     try do
449:       subscriber.(event_type, %{state: state, payload: payload})
450:     rescue
451:       _ -> :ok
452:     end
453:   end
```
**Analysis**:
1. **Unbounded Memory Accumulation**: `state.traces` stores every single `%Event{}` ever ingested. In a streaming production process intelligence system, millions of events will accumulate in the GenServer's heap. This will eventually trigger memory exhaustion and kill the node.
2. **Quadratic Ingestion Complexity**: In line 319, for every single ingested event, `new_trace` is reversed (`Enum.reverse(new_trace)`). If a trace has 5,000 events, every new event reverses a 5,000-element list.
3. **In-Loop Callback Execution**: Executing `subscriber.(event_type, ...)` inside `handle_call` blocks the GenServer from processing any other incoming events until the subscriber returns. If the subscriber takes 100ms, max throughput drops to 10 events/second.
**Fix**:
- Introduce a sliding window (e.g. keeping only the last $N$ traces or last $K$ events per trace) or persist completed traces to an ETS table or database.
- Keep `trace_path` in forward order or store only activity names.
- Decouple notifications using asynchronous messaging: `send(subscriber_pid, {:event, event_type, payload})` or a `Registry`-based pubsub pattern.

---

### 3.9 `PlanningPool` Slot Leakage on Process Termination
**Location**: `lib/ex4pm/runtime/planning_pool.ex:1-58`

```elixir
34:   def acquire(pool_key, how_many \\ 1) do
35:     ConcurrencyTracker.acquire(pool_key, how_many)
36:   end
...
46:   def release_on_exit(pool_key, pid \\ self()) do
47:     ConcurrencyTracker.release_on_exit(pool_key, pid)
48:   end
```
Examining the underlying `deps/reactor/lib/reactor/executor/concurrency_tracker.ex:49-65`:
```elixir
49:   def handle_cast({:release_on_exit, pid, pool_key}, state) do
50:     ref = Process.monitor(pid)
51:     {:noreply, %{state | releases: Map.put(state.releases, ref, pool_key)}}
52:   end
...
56:   def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
57:     case Map.pop(state.releases, ref) do
...
62:       {pool_key, releases} ->
63:         release(pool_key)
64:         {:noreply, %{state | releases: releases}}
65:     end
66:   end
```
Notice line 63: `release(pool_key)`.
In `ConcurrencyTracker.release(key, how_many \\ 1)`, the default `how_many` is `1`.
If a worker acquires **3 slots** (`PlanningPool.acquire(pool, 3)`) and registers `PlanningPool.release_on_exit(pool)`, when that worker terminates, `ConcurrencyTracker` only releases **1 slot**. The other 2 slots are leaked permanently!
Furthermore, requiring callers to manually remember to call `release_on_exit` is error-prone.
**Fix**: `PlanningPool` should provide a functional bracket pattern:
```elixir
def with_slot(pool_key, how_many \\ 1, fun) do
  case acquire(pool_key, how_many) do
    {:ok, ^how_many} ->
      try do
        fun.()
      after
        release(pool_key, how_many)
      end
    {:ok, granted} ->
      release(pool_key, granted)
      {:error, :insufficient_slots}
  end
end
```

---

## 4. Areas of Excellence & Praise

It is important to emphasize what `ex4pm` gets magnificently right.

### 4.1 Pure Calculation (`CONSTRUCT`) vs Consequential Actuation (`DO`)
The system strictly enforces the Chatman equation:
$$A = \mu(O^*), \quad R = \text{receipt}(A)$$
Candidate process models, Petri nets, and PDDL plans are created with `authority: :construct_only`. They are pure data structures. They cannot trigger external I/O, modify production databases, or actuate hardware. Only `Ex4pm.Evidence.BRCE` possesses the authority to actuate, and it does so exclusively after writing a pending cryptographic receipt. This cleanly maps to pure functional programming on the BEAM.

### 4.2 Ephemeral Session Workers with Deterministic Journal Replay
In `Ex4pm.Engine.Ferroplan.Session`, managing C-like WASM guest memory by pairing each session with a dedicated GenServer running with `restart: :temporary` is brilliant. Instead of creating a complicated C-level garbage collection or state rollback system, `ex4pm` embraces the Erlang way: when memory is corrupted, discard the process and let it die. Replay the operations from the journal. This is robust, predictable, and simple.

### 4.3 Zero-Import WASM Admission and Digest Pinning
In `Ex4pmEngine.Wasm.Admission`, before any WASM bytecode is instantiated, its SHA-256 digest is verified against a locked manifest (`MANIFEST.json`), its imports are restricted to an explicit allowlist (defaulting to empty for pure computation), and required exports are verified. Untrusted or mutated bytecode is refused before it can execute.

### 4.4 Real OTP Process Modeling
The authors did not fake concurrency with synchronous mocks. Real `Registry` partitions, `DynamicSupervisor` trees, `GenStateMachine` callbacks, and `Task.async_stream` pipelines are used throughout. The test suite verifies real multi-process behavior under concurrency.

---

## 5. Technical Debt, Concerns & Edge Cases

| # | Severity | Component | File:Line | Issue Description |
|---|----------|-----------|-----------|-------------------|
| 1 | **Major** | `Ferroplan.Host` | `lib/ex4pm/engine/ferroplan.ex:27` | Does not trap exits. An abnormal crash in a linked WASM instance kills the Host and wipes the instance cache. |
| 2 | **Major** | `SessionSupervisor` | `lib/ex4pm/engine/ferroplan/sessions.ex:51` | Started unlinked (`Process.unlink/1`) outside `Ex4pm.Supervisor`. An unparented orphan supervisor. |
| 3 | **Major** | `Sessions.list/0` | `lib/ex4pm/engine/ferroplan/sessions.ex:152` | Queries `Registry.select` without checking `Process.alive?/1`, causing race conditions on de-registration. |
| 4 | **Major** | `PowlExecutor` | `lib/ex4pm/runtime/powl_executor.ex:98` | Multiset input place bug: transitions requiring multiple tokens from one place can fire with only one token. |
| 5 | **Major** | `OnlineMiner` | `lib/ex4pm/engine/online_miner.ex:214, 446` | Unbounded memory growth in `traces: %{}` and synchronous execution of subscriber callbacks in message loop. |
| 6 | **Minor** | `PlanningPool` | `lib/ex4pm/runtime/planning_pool.ex:47` | `release_on_exit` only releases 1 slot in ConcurrencyTracker even if multiple slots were acquired. |
| 7 | **Minor** | `HostTest` | `test/wasm/host_test.exs:11` | Hardcoded artifact path causes tests to be skipped unless `EX4PM_WASM_ARTIFACT` is set in env. |
| 8 | **Minor** | `Wasm.Host` | `lib/ex4pm_engine/wasm/host.ex:172` | Restarts crashed instances without intensity bounds (could tight-loop on permanent faults). |

---

## 6. Actionable Recommendations for v26.11.10 and Beyond

### Phase 1: Immediate Hardening (v26.11.10)

1. **Trap Exits in `Ferroplan.Host`**:
   Add `Process.flag(:trap_exit, true)` to `Ex4pm.Engine.Ferroplan.Host.init/1` and implement `handle_info({:EXIT, pid, _reason}, state)` to safely clean up the crashed instance from `state` without taking down the Host.
2. **Filter Dead PIDs in `Sessions.list/0`**:
   Update `Sessions.list/0` to verify `Process.alive?(pid)` for each item returned by `Registry.select`, matching the defensive pattern already used in `Sessions.lookup/1`.
3. **Fix Petri Net Multiset Tokens in `PowlExecutor`**:
   Replace `Enum.all?` in `PowlExecutor.enabled?/2` with multiset frequency counting (`Enum.frequencies(inputs)`) to ensure transitions requiring $N$ tokens at place $P$ only fire when $P \ge N$.
4. **Fix Test Fallback in `test/wasm/host_test.exs`**:
   Update `@artifact` in `host_test.exs` to fall back to `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm` so the host test suite runs automatically in standard `mix test` environments.

### Phase 2: Structural Supervision & State Improvements (v26.11.x)

1. **Attach `SessionSupervisor` to the Application Tree**:
   Add `Ex4pm.Engine.Ferroplan.SessionSupervisor` directly to the children list in `Ex4pm.Application.start/2`. Deprecate `Process.unlink/1` in `Sessions.ensure_started/0`.
2. **Bound Memory in `OnlineMiner`**:
   Add an eviction policy (sliding window of maximum $N$ traces or TTL expiration) to `state.traces`.
3. **Asynchronous Telemetry Dispatch in `OnlineMiner`**:
   Change `maybe_notify` to send asynchronous messages (`send(subscriber, ...)`) or spawn an unlinked task, preventing subscriber latency from blocking event ingestion.
4. **Add Safe Bracket API to `PlanningPool`**:
   Expose `PlanningPool.with_slot(pool, slots, fun)` to ensure slots are always released even if the user function raises an exception.

### Phase 3: Architectural Evolution (v26.12.0+)

1. **Evolve `PowlExecutor` to Model Lifecycle States**:
   Transition `PowlExecutor` from a single-mode machine (`:marking`) to a true `gen_statem` with lifecycle states: `:active`, `:blocked` (deadlocked / no transitions enabled), and `:completed` (tokens reached terminal sink places).
2. **Partitioned Concurrency for `OnlineMiner`**:
   Instead of a single GenServer for all traces, shard incoming events across a pool of trace workers using consistent hashing on `run_id`, allowing linear scaling across multiple BEAM schedulers.

---

## 7. Verdict & Concluding Remarks

### **Verdict**: `APPROVE WITH RECOMMENDATIONS`

The design of `ex4pm` demonstrates a deep, genuine respect for the strengths of the Erlang runtime. The separation of candidate construction from side-effect actuation, the ephemeral process encapsulation of WASM planning instances, and the deterministic journal recovery are triumphs of robust systems design. 

The issues identified in this review—orphan supervisors, exit trapping gaps, multiset token handling, and registry timing races—are classic distributed systems edge cases that can be cleanly remedied following the recommendations above.

As I always used to say: *"Make it work, then make it beautiful, then if you really have to, make it fast."* `ex4pm` works, and its core foundations are sound. With these OTP refinements in place, it will be truly beautiful.

---
*Joe Armstrong*  
Co-inventor of Erlang  
Review completed: November 11, 2026
