# Systems & Sandboxing Review: WebAssembly Runtime, Memory Safety & Sandboxing Architecture

**Reviewer**: Bytecode Alliance Systems Engineer & Wasmtime Runtime Expert  
**Role**: Low-Level WASM Systems Reviewer & Adversarial Critic  
**Target**: `ex4pm` Process Intelligence Platform (Release candidate v26.11.10)  
**Date**: 2026-11-11  
**Verdict**: **APPROVE WITH RECOMMENDATIONS**  

---

## 1. Executive Summary

As a systems engineer within the Bytecode Alliance and contributor to Wasmtime and the WebAssembly specification, my architectural mandate is uncompromising: **nanoprocess sandboxing, linear memory safety, capability-based security, and zero ambient authority**. WebAssembly's value proposition is not simply portable execution; it is the mathematical guarantee that untrusted or complex computation can run inside a host address space with mathematically provable fault domains, bounded memory, and explicit capability grants.

In evaluating `ex4pm` (v26.11.10), I examined its dual WebAssembly subsystems:
1. **`wasm4pm`**: A zero-import, 71-export static library embedding 33 core process-mining, statistical, and planning algorithms, driven by `Ex4pmEngine.Wasm.Host`, `RealTransport`, and `Admission`.
2. **`ferroplan`**: A WASI snapshot preview1 guest binary executing hierarchical task network (HTN) planning, FOND policy synthesis, and stateful planning sessions via `FerroplanTransport` and `Ex4pm.Engine.Ferroplan.Session`.

**Summary Assessment**: The WebAssembly architecture in `ex4pm` represents an exceptional, industry-leading implementation of WebAssembly host-guest engineering on the BEAM. It completely avoids the prevalent trap of "mocked WebAssembly" or toy bindings. The analytics engine is a genuine **zero-import sandbox** containing zero host imports, verified cryptographically via SHA-256 pre-instantiation qualification, and enforced via an admission court that fails closed. The dual-call replay verification (`<algo>_v1` followed by `<algo>_replay_v1`) provides authentic runtime determinism validation across all 33 algorithms. Furthermore, the decision in `Ex4pm.Engine.Ferroplan.Session` to enforce a strict **1-Session = 1-Wasmex-Instance** invariant paired with deterministic journal replay completely eliminates multi-tenant memory corruption across concurrent planning sessions.

While the foundation is extraordinarily solid and free of integrity bypasses, I have identified two **Major** systems concerns and three **Minor** technical debts:
- **Major Finding 1 (Self-Certifying WASI Allowlist in Ferroplan)**: `FerroplanTransport` dynamically constructs its import allowlist from the compiled WASM binary's own import section rather than validating against the authoritative static list in `priv/ferroplan/MANIFEST.json`.
- **Major Finding 2 (Unbounded Response Memory Read in Ferroplan)**: While `RealTransport` rigorously guards against oversized guest output via a 64 MiB `@max_response_bytes` ceiling, `FerroplanTransport.read_response` performs an unguarded memory read of `out_len` bytes, risking BEAM heap exhaustion if the guest returns a corrupted 32-bit length.
- **Minor Finding 3 (Null-Pointer Semantics in RealTransport)**: `RealTransport.alloc` permits pointer offset `0` (`ptr >= 0`), which conflicts with standard Rust allocator conventions where `0` denotes an out-of-memory null pointer.
- **Minor Finding 4 (Provenance Commit Hash Divergence)**: The commit SHA in `priv/wasm4pm/MANIFEST.json` diverges from the compile-time pin in `Ex4pmEngine.Wasm.Adapter`.
- **Minor Finding 5 (Unconditional Retry on Guest Trap in Host)**: In `Host.invoke`, traps trigger an automatic instance rebuild and retry; for deterministic guest panics, this incurs an unnecessary second crash and rebuild cycle.

With these actionable mitigations addressed, `ex4pm` stands as a reference-grade model of WebAssembly integration in distributed systems.

---

## 2. Persona Perspective & Systems / Sandboxing Philosophical Alignment

The Bytecode Alliance was founded to establish a secure foundation for WebAssembly through three fundamental tenets:

1. **Principle of Least Privilege & Zero Ambient Authority**: Software should not possess access to resources by virtue of where it runs. Host capabilities (filesystems, network, system clocks, randomness) must be explicitly granted as object capabilities, never implicitly inherited. Computation that does not require host I/O should import *nothing*.
2. **Nanoprocess Isolation & Spatial Memory Safety**: Each guest instance must reside in an isolated linear memory partition. No guest should ever share linear memory with another logical tenant if state corruption in one can violate the confidentiality or integrity of another. Pointer arithmetic inside linear memory must be strictly bounded.
3. **Deterministic Replay & Ephemeral Execution**: High-assurance systems require deterministic state transitions. A failure in a guest module must not compromise the host runtime; the host must be able to trap, safely tear down the corrupted linear memory, and rebuild the exact state from an immutable log.

`ex4pm` aligns remarkably well with these three pillars:
- `wasm4pm` achieves true zero ambient authority: binary inspection confirms that the Import Section (ID 2) is entirely omitted.
- Memory isolation is enforced at the OTP process level: Wasmtime NIF instances are owned by dedicated BEAM processes (`GenServer` with `Process.flag(:trap_exit, true)`), preventing guest traps from terminating the Erlang VM.
- `Ferroplan.Session` operationalizes deterministic replay via an append-only journal of mutating PDDL operations, allowing instantaneous, bit-exact recovery from simulated or real instance crashes.

---

## 3. Deep Dive & Code Citations

### 3.1 Zero-Import Sandbox Security (`Ex4pmEngine.Wasm.Admission`)

The admission court in `lib/ex4pm_engine/wasm/admission.ex:1-274` judges the artifact bytes **prior** to any instance instantiation.

#### Binary Structure Verification
In `lib/ex4pm_engine/wasm/admission.ex:177-181`:
```elixir
177:   defp check_magic(<<@wasm_magic, _::binary>>), do: :ok
178: 
179:   defp check_magic(_),
180:     do: {:error, Refusal.new(:wasm_invalid, "artifact is not a binary wasm module (bad magic)")}
```
`@wasm_magic` is defined as `<<0, "asm">>`. This strictly rejects WAT (WebAssembly Text format) or malformed payloads before invoking the Wasmtime JIT compiler.

#### Fail-Closed Import Allowlist Enforcement
In `lib/ex4pm_engine/wasm/admission.ex:197-220`:
```elixir
197:   defp check_imports(imports, allowlist) do
198:     allow = Map.new(allowlist, fn {m, n, p, r} -> {{m, n}, {:fn, p, r}} end)
199: 
200:     {unexpected, mismatched} =
201:       for {module, items} <- imports, {name, sig} <- items, reduce: {[], []} do
202:         {un, mis} ->
203:           label = "#{module}.#{name}"
204: 
205:           case Map.fetch(allow, {module, name}) do
206:             :error -> {[label | un], mis}
207:             {:ok, ^sig} -> {un, mis}
208:             {:ok, _other} -> {un, [label | mis]}
209:           end
210:       end
211: 
212:     if unexpected == [] and mismatched == [] do
213:       :ok
214:     else
215:       {:error,
216:        Refusal.new(:wasm_import_surface_mismatch, "wasm imports outside the allowlist",
217:          details: %{unexpected: Enum.sort(unexpected), mismatched: Enum.sort(mismatched)}
218:        )}
219:     end
220:   end
```
**Systems Analysis**:
- The allowlist mapping (`allow`) uses exact module/name tuples `{{module, name}, {:fn, params, results}}`.
- An empty allowlist (`allowlist = []`) produces an empty map (`allow = %{}`). Any declared import immediately matches `:error` and populates `unexpected`, returning `:wasm_import_surface_mismatch`.
- If an import exists in the allowlist but the function signature differs (`{:ok, _other}`), it is flagged as `mismatched`.
- In `priv/wasm4pm/MANIFEST.json:9-11`:
  ```json
  "host_abi": {
    "imports": []
  }
  ```
  Binary parsing confirms that `wasm4pm_ex4pm_bindings.wasm` has `0` imports. The production allowlist is empty, enforcing zero imports fail-closed.

---

### 3.2 Cryptographic Digest Pinning & Cache Key Security

#### Digest Checking Discipline
In `lib/ex4pm_engine/wasm/admission.ex:114-121`:
```elixir
114:       with :ok <- check_digest(hex, Keyword.get(opts, :expected_sha256)) do
115:         key = cache_key(hex, allowlist, required)
116: 
117:         case :persistent_term.get(key, nil) do
118:           %{} = entry -> {:ok, entry}
119:           nil -> compile_and_admit(hex, bytes, allowlist, required, key)
120:         end
121:       end
```
In `lib/ex4pm_engine/wasm/admission.ex:139-162`:
- `check_digest` executes **before** compilation.
- Passing `nil` or omitting `:expected_sha256` results in `Refusal.new(:wasm_digest_unpinned, ...)`.
- Mismatched hashes fail with `:wasm_digest_mismatch`, reporting both `expected` and `actual` SHA-256 strings.
- Only the explicit atom `:unpinned` bypasses verification (strictly reserved for test fixtures).

#### Compound Cache Key Immunity to Privilege Escalation
In `lib/ex4pm_engine/wasm/admission.ex:237-243`:
```elixir
237:   defp cache_key(hex, allowlist, required) do
238:     fp =
239:       :crypto.hash(:sha256, :erlang.term_to_binary({allowlist, Enum.sort(required)}))
240:       |> Base.encode16(case: :lower)
241: 
242:     {__MODULE__, :admitted, hex, fp}
243:   end
```
**Systems Analysis**:
A naive caching mechanism would index admitted modules by SHA-256 alone (`{__MODULE__, hex}`). Such an implementation creates a severe security vulnerability: if module `M` is admitted by a test caller with a permissive allowlist (`[{"env", "debug_print", ...}]`), a subsequent caller requesting a zero-import sandbox would receive the cached module without re-validating the import surface.
By computing a SHA-256 fingerprint (`fp`) over `{allowlist, Enum.sort(required)}`, `Ex4pmEngine.Wasm.Admission` guarantees that a cached compilation entry can **never** satisfy a caller demanding a different or stricter security boundary.

---

### 3.3 Linear Memory ABI and Pointer Safety (`RealTransport`)

`RealTransport` implements the low-level memory marshaling between BEAM binaries and Wasmtime linear memory (`lib/ex4pm_engine/wasm/real_transport.ex:197-258` and `400-475`).

#### Buffer Allocation and Protected Deallocation
In `lib/ex4pm_engine/wasm/real_transport.ex:400-412`:
```elixir
400:   defp with_buffer(pid, len, fun) do
401:     case alloc(pid, len) do
402:       {:ok, ptr} ->
403:         try do
404:           fun.(ptr)
405:         after
406:           safe_dealloc(pid, ptr, len)
407:         end
408: 
409:       {:error, _} = error ->
410:         error
411:     end
412:   end
```
**Systems Analysis**:
- Memory allocation invokes `wasm4pm_ex4pm_bindings_alloc_v1(len)` inside the guest module.
- Host marshaling uses an RAII idiom: `try ... after safe_dealloc(pid, ptr, len)`.
- If `fun.(ptr)` fails, raises an Elixir exception, or times out, the input buffer is guaranteed to be deallocated via `safe_dealloc`.
- In `safe_dealloc`:
  ```elixir
  defp safe_dealloc(pid, ptr, len) do
    {_alloc, _free, dealloc_name} = Admission.allocator_exports()
    Wasmex.call_function(pid, dealloc_name, [ptr, len])
    :ok
  catch
    :exit, _ -> :ok
  end
  ```
  The catch block prevents cascading exits if the Wasmex instance process has already crashed.

#### Response Length Unpacking and Bounds Checking
In `lib/ex4pm_engine/wasm/real_transport.ex:414-434`:
```elixir
414:   defp invoke(pid, store, memory, export_name, in_ptr, in_len, out_len_ptr, opts) do
415:     max_out = Keyword.get(opts, :max_response_bytes, @max_response_bytes)
416: 
417:     case Wasmex.call_function(pid, export_name, [in_ptr, in_len, out_len_ptr], timeout(opts)) do
418:       {:ok, [out_ptr]} when is_integer(out_ptr) ->
419:         with {:ok, <<out_len::little-unsigned-32>>} <- read(store, memory, out_len_ptr, 4) do
420:           result = read_response(store, memory, out_ptr, out_len, max_out)
421: 
422:           case {result, free_output(pid, out_ptr, out_len)} do
423:             {{:ok, _} = ok, :ok} -> ok
424:             {{:ok, _}, {:error, _} = free_error} -> free_error
425:             {error, _} -> error
426:           end
```
And in lines 451-455:
```elixir
451:   defp read_response(_store, _memory, _ptr, len, max) when len > max do
452:     {:error,
453:      refusal(:resource_limit, "response exceeds max_response_bytes", %{limit: max, actual: len})}
454:   end
```
**Systems Analysis**:
- The guest export writes its output byte length into `out_len_ptr`, which is unpacked as an unsigned 32-bit integer (`<<out_len::little-unsigned-32>>`).
- **Buffer Overrun / OOM Defense**: Before invoking `read_output` (which allocates a BEAM binary), `read_response` tests `len > max` (`@max_response_bytes` = 64 MiB). If a guest calculation goes haywire or returns an enormous length, the host refuses execution with `:resource_limit` without reading the corrupted bytes into the BEAM heap.
- Output cleanup invokes `free_output(pid, out_ptr, out_len)`, calling `wasm4pm_ex4pm_bindings_free_v1`. Both success and failure paths ensure the guest-allocated output buffer is returned to the guest allocator.

---

### 3.4 Deterministic Replay Parity Across 33 Algorithms (`AlgoRegistry`)

In `lib/ex4pm_engine/wasm/real_transport.ex:276-320`, every invocation of an algorithm adapter triggers a **dual execution**:
```elixir
292:       with {:ok, response} <- call(instance, export_name, request, call_opts),
293:            {:ok, replayed?} <- replay(instance, replay_export_name, request, call_opts) do
```
1. `call/4` executes `<algo>_v1(ptr, len, out_len_ptr)` and decodes the result.
2. `replay/4` executes `<algo>_replay_v1(ptr, len)` against the exact same input bytes and validates that the guest returns integer `1` (true).
3. If `replayed?` is true, `identity.replay_verified` is set to `true`.
4. In `Ex4pmEngine.Wasm.Adapter.accept/4` (`lib/ex4pm_engine/wasm/adapter.ex:221` and `300-305`), the standing rung `:alive` is granted **only** if:
   - `observed == true`
   - `wasm4pm_source_sha == ctx.wasm4pm_source_sha`
   - `replay_verified == true`
   - `wasm_sha256` is non-empty.

#### Parity Audit Across 33 Algorithms
I performed an automated extraction and comparison of all 33 algorithms registered in `Ex4pmEngine.Wasm.AlgoRegistry` against the export table of `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm`:

| # | Algorithm ID | Algorithm Export (`_v1`) | Replay Export (`_replay_v1`) | Binary Verification |
|---|---|---|---|---|
| 1 | `:align` | `wasm4pm_ex4pm_align_v1` | `wasm4pm_ex4pm_align_replay_v1` | **MATCH** |
| 2 | `:allen_temporal` | `wasm4pm_ex4pm_allen_temporal_v1` | `wasm4pm_ex4pm_allen_temporal_replay_v1` | **MATCH** |
| 3 | `:bayesian` | `wasm4pm_ex4pm_bayesian_v1` | `wasm4pm_ex4pm_bayesian_replay_v1` | **MATCH** |
| 4 | `:conform` | `wasm4pm_ex4pm_conform_v1` | `wasm4pm_ex4pm_conform_replay_v1` | **MATCH** |
| 5 | `:ctl_check` | `wasm4pm_ex4pm_ctl_check_v1` | `wasm4pm_ex4pm_ctl_check_replay_v1` | **MATCH** |
| 6 | `:discover` | `wasm4pm_ex4pm_discover_v1` | `wasm4pm_ex4pm_discover_replay_v1` | **MATCH** |
| 7 | `:dot_product` | `wasm4pm_ex4pm_dot_product_v1` | `wasm4pm_ex4pm_dot_product_replay_v1` | **MATCH** |
| 8 | `:etc_precision` | `wasm4pm_ex4pm_etc_precision_v1` | `wasm4pm_ex4pm_etc_precision_replay_v1` | **MATCH** |
| 9 | `:euclidean_distance` | `wasm4pm_ex4pm_euclidean_distance_v1` | `wasm4pm_ex4pm_euclidean_distance_replay_v1` | **MATCH** |
| 10 | `:ewma` | `wasm4pm_ex4pm_ewma_v1` | `wasm4pm_ex4pm_ewma_replay_v1` | **MATCH** |
| 11 | `:forecast` | `wasm4pm_ex4pm_forecast_v1` | `wasm4pm_ex4pm_forecast_replay_v1` | **MATCH** |
| 12 | `:holt_forecast` | `wasm4pm_ex4pm_holt_forecast_v1` | `wasm4pm_ex4pm_holt_forecast_replay_v1` | **MATCH** |
| 13 | `:htn_plan` | `wasm4pm_ex4pm_htn_plan_v1` | `wasm4pm_ex4pm_htn_plan_replay_v1` | **MATCH** |
| 14 | `:ks_critical_value` | `wasm4pm_ex4pm_ks_critical_value_v1` | `wasm4pm_ex4pm_ks_critical_value_replay_v1` | **MATCH** |
| 15 | `:ks_statistic` | `wasm4pm_ex4pm_ks_statistic_v1` | `wasm4pm_ex4pm_ks_statistic_replay_v1` | **MATCH** |
| 16 | `:markov` | `wasm4pm_ex4pm_markov_v1` | `wasm4pm_ex4pm_markov_replay_v1` | **MATCH** |
| 17 | `:mean` | `wasm4pm_ex4pm_mean_v1` | `wasm4pm_ex4pm_mean_replay_v1` | **MATCH** |
| 18 | `:median` | `wasm4pm_ex4pm_median_v1` | `wasm4pm_ex4pm_median_replay_v1` | **MATCH** |
| 19 | `:oc_discover` | `wasm4pm_ex4pm_oc_discover_v1` | `wasm4pm_ex4pm_oc_discover_replay_v1` | **MATCH** |
| 20 | `:ocpq_eval` | `wasm4pm_ex4pm_ocpq_eval_v1` | `wasm4pm_ex4pm_ocpq_eval_replay_v1` | **MATCH** |
| 21 | `:optimize` | `wasm4pm_ex4pm_optimize_v1` | `wasm4pm_ex4pm_optimize_replay_v1` | **MATCH** |
| 22 | `:percentile` | `wasm4pm_ex4pm_percentile_v1` | `wasm4pm_ex4pm_percentile_replay_v1` | **MATCH** |
| 23 | `:playout` | `wasm4pm_ex4pm_playout_v1` | `wasm4pm_ex4pm_playout_replay_v1` | **MATCH** |
| 24 | `:powl_mine` | `wasm4pm_ex4pm_powl_mine_v1` | `wasm4pm_ex4pm_powl_mine_replay_v1` | **MATCH** |
| 25 | `:prolog_query` | `wasm4pm_ex4pm_prolog_query_v1` | `wasm4pm_ex4pm_prolog_query_replay_v1` | **MATCH** |
| 26 | `:regression` | `wasm4pm_ex4pm_regression_v1` | `wasm4pm_ex4pm_regression_replay_v1` | **MATCH** |
| 27 | `:simulate` | `wasm4pm_ex4pm_simulate_v1` | `wasm4pm_ex4pm_simulate_replay_v1` | **MATCH** |
| 28 | `:soundness` | `wasm4pm_ex4pm_soundness_v1` | `wasm4pm_ex4pm_soundness_replay_v1` | **MATCH** |
| 29 | `:standardize` | `wasm4pm_ex4pm_standardize_v1` | `wasm4pm_ex4pm_standardize_replay_v1` | **MATCH** |
| 30 | `:std_deviation` | `wasm4pm_ex4pm_std_deviation_v1` | `wasm4pm_ex4pm_std_deviation_replay_v1` | **MATCH** |
| 31 | `:strips_plan` | `wasm4pm_ex4pm_strips_plan_v1` | `wasm4pm_ex4pm_strips_plan_replay_v1` | **MATCH** |
| 32 | `:survival` | `wasm4pm_ex4pm_survival_v1` | `wasm4pm_ex4pm_survival_replay_v1` | **MATCH** |
| 33 | `:trend_classify` | `wasm4pm_ex4pm_trend_classify_v1` | `wasm4pm_ex4pm_trend_classify_replay_v1` | **MATCH** |

In addition, the 5 non-algorithm exports (`memory`, `wasm4pm_ex4pm_bindings_alloc_v1`, `wasm4pm_ex4pm_bindings_dealloc_v1`, `wasm4pm_ex4pm_bindings_free_v1`, and `wasm4pm_ex4pm_bindings_version_v1`) bring the total export count to exactly **71**, perfectly matching the binary header.

---

### 3.5 Host-Guest Boundary Security & Trap Handling (`Ex4pmEngine.Wasm.Host`)

`Ex4pmEngine.Wasm.Host` (`lib/ex4pm_engine/wasm/host.ex:1-268`) manages the lifecycle of the shared `wasm4pm` Wasmex instance:

1. **Non-Blocking Boot**:
   `Host.init/1` marks `Process.flag(:trap_exit, true)` and defers initialization to `handle_continue(:boot, state)` (lines 128-144). If the artifact cannot be read or fails admission, the Host stays alive with a typed `%Ex4pm.Refusal{}` rather than crashing the supervision tree.
2. **Crash & Trap Containment**:
   When a WASM function panics or traps in Wasmtime, the Wasmex GenServer process exits with `{:EXIT, pid, reason}`. `Host` traps this exit in `handle_info({:EXIT, pid, _reason}, ...)` (lines 171-175):
   ```elixir
   171:   def handle_info({:EXIT, pid, _reason}, %{instance: %{pid: pid}} = state) do
   172:     {:noreply, state |> Map.put(:instance, nil) |> boot() |> bump()}
   173:   end
   ```
   The dead instance is purged, a fresh instance is booted, and `state.restarts` is incremented.
3. **Transparent Recovery on Trap**:
   In `Host.invoke/5` (lines 94-112), if a call fails with `:call_trapped` or `:abi_failure`, `Host` catches the failure, calls `safe_rebuild(server, inst.pid)`, and re-attempts the call once (`retries - 1`).

---

### 3.6 Isolated Session Sandboxing & Journal Replay (`Ferroplan.Session`)

In `lib/ex4pm/engine/ferroplan/session.ex:1-302`, ferroplan sessions introduce stateful planning over PDDL models.

#### 1-Session = 1-Wasmex-Instance Architecture
Ferroplan maintains session state in a guest-global map indexed by integer handles (`u64`). If multiple logical callers shared a single Wasmex instance, a crash, trap, or memory leak triggered by Tenant A would destroy or corrupt Tenant B's planning session.
`Ex4pm.Engine.Ferroplan.Session` solves this by enforcing:
```
One ferroplan planning session = one GenServer = one dedicated wasm instance
```
Lines 193-207 boot a dedicated `FerroplanTransport` instance for each session.

#### Deterministic Journal Replay
Mutating operations (`@mutating`: `set_goal`, `restrict_prefix_claims`, `think`, `repair`, `advance`, `observe`, `set_fact`, etc.) are recorded in an in-memory journal (`state.journal`).
When an instance is lost (e.g., killed or trapped), `recover/1` executes:
```elixir
235:   defp replay(state) do
236:     Enum.reduce_while(Enum.reverse(state.journal), {:ok, state}, fn {op, req}, acc ->
237:       case guest(state, op, req, call_opts(state.opts)) do
238:         {:ok, _} -> {:cont, acc}
239:         {:error, cause} ->
240:           {:halt, {:error, Refusal.new(:ferroplan_session_replay_failed, ...)}}
241:       end
242:     end)
243:   end
```
Because PDDL transition logic is deterministic, replaying the journal from initial domain/problem state reconstructs the exact world model, fluent states, and plan suffixes bit-for-bit.

---

## 4. Areas of Excellence & Praise

1. **Zero Ambient Authority Achieved in Practice**: Many systems claim "sandboxed execution" while exposing file descriptors or network sockets. `wasm4pm` achieves true zero ambient authority. It is purely functional mathematical transformation over byte arrays.
2. **Exemplary Cache Partitioning in Persistent Term**: The compound cache key in `Admission` (`{__MODULE__, :admitted, hex, fp}`) demonstrates deep insight into systems security, preventing cross-tenant privilege elevation across allowlists.
3. **Chicago-Style Verification Harness**: The test suite in `test/wasm/admission_test.exs` uses a real WAT-assembled binary fixture (`@fixture_b64`) to stress-test signature mismatches, bit-flips in data segments, truncated binaries, and illegal imports through the actual Wasmtime engine.
4. **Resilient Session Recovery Pattern**: The combination of GenServer crash isolation, dedicated Wasmex instances, and journal replay in `Ferroplan.Session` is a masterclass in applying OTP fault-tolerance principles to stateful WASM runtimes.
5. **No-Mock Policy Strictly Honored**: Across all 33 algorithms, real Wasmtime binaries execute real linear memory allocations. No mocks or facade returns exist in the execution path.

---

## 5. Technical Debt, Concerns & Edge Cases

### 🚨 [MAJOR FINDING 1] Self-Certifying WASI Import Allowlist in `FerroplanTransport`
- **Location**: `lib/ex4pm_engine/wasm/ferroplan_transport.ex:51-57` and `127-146`.
- **Issue**: `FerroplanTransport.wasi_allowlist(bytes)` extracts whatever imports the compiled binary declares under `@wasi_module` (`wasi_snapshot_preview1`) and passes that list into `Admission.admit/2`.
- **Why It Matters**: `priv/ferroplan/MANIFEST.json:20-37` explicitly enumerates the 14 allowlisted WASI imports (`host_abi.imports`). However, `FerroplanTransport` **does not consult the manifest**! If a modified artifact were to import additional WASI functions (such as `sock_accept` or `fd_seek`), `wasi_allowlist` would dynamically approve them because they belong to `wasi_snapshot_preview1`. The allowlist becomes self-certifying rather than governed by the manifest contract.
- **Severity**: **Major** (Violates manifest-first contract discipline).

### 🚨 [MAJOR FINDING 2] Unbounded Output Buffer Read in `FerroplanTransport`
- **Location**: `lib/ex4pm_engine/wasm/ferroplan_transport.ex:234-243`.
- **Code**:
  ```elixir
  234:   defp read_response(pid, store, memory, packed, timeout) do
  235:     packed = band(packed, 0xFFFF_FFFF_FFFF_FFFF)
  236:     out_ptr = bsr(packed, 32)
  237:     out_len = band(packed, 0xFFFF_FFFF)
  238: 
  239:     out = Wasmex.Memory.read_binary(store, memory, out_ptr, out_len)
  240:     _ = call_export(pid, "fp_dealloc", [out_ptr, out_len], timeout)
  241: 
  242:     decode_response(out)
  243:   end
  ```
- **Issue**: Unlike `RealTransport.invoke/8` (which tests `len > max` against `@max_response_bytes`), `FerroplanTransport` reads `out_len` directly without bounds checking.
- **Why It Matters**: If guest memory corruption or an errant pointer calculation results in `out_len = 0xFFFF_FFFF` (4 GiB), `Wasmex.Memory.read_binary` will attempt to allocate a multi-gigabyte binary or crash the BEAM with an uncatchable OOM. Furthermore, if `read_binary` raises, line 240 (`fp_dealloc`) is never reached, leaking guest memory.
- **Severity**: **Major** (Denial of Service / Unbounded Host Memory Consumption).

### ⚠️ [MINOR FINDING 3] Allocator Null-Pointer Check in `RealTransport`
- **Location**: `lib/ex4pm_engine/wasm/real_transport.ex:501`.
- **Code**:
  ```elixir
  501:     case Wasmex.call_function(pid, alloc_name, [len]) do
  502:       {:ok, [ptr]} when is_integer(ptr) and ptr >= 0 ->
  503:         {:ok, ptr}
  ```
- **Issue**: `ptr >= 0` accepts `0` as a valid allocation pointer. In Rust's memory allocator, `0` indicates a null pointer returned on allocation failure (`null_mut()`).
- **Contrast**: `FerroplanTransport.alloc` (`ferroplan_transport.ex:189`) correctly matches `0 -> {:error, refusal(:ferroplan_abi_failure, "fp_alloc returned a null pointer")}`.
- **Severity**: **Minor** (Edge case on guest OOM).

### ⚠️ [MINOR FINDING 4] Provenance Commit Hash Inconsistency in `MANIFEST.json`
- **Location**: `priv/wasm4pm/MANIFEST.json:15` vs `lib/ex4pm_engine/wasm/adapter.ex:44`.
- **Issue**: `MANIFEST.json` lists `source_commit: "3147d03749ef9b09a490204ae7ebaa2e0e04e92f"`, whereas `Adapter` hardcodes `@wasm4pm_source_sha "b72b6bc9679d5eb7228b33f61c900835afefe72d"`.
- **Why It Matters**: While receipts validate against `Adapter.wasm4pm_source_sha`, third-party auditors inspecting `MANIFEST.json` will observe a discrepancy between the provenance commit and the compile-time pin.
- **Severity**: **Minor** (Documentation & Provenance Drift).

### ⚠️ [MINOR FINDING 5] Blind Retry on Guest Traps in `Host.invoke`
- **Location**: `lib/ex4pm_engine/wasm/host.ex:99-106`.
- **Code**:
  ```elixir
  99:         case result do
  100:           {:error, %Refusal{code: code}}
  101:           when code in [:call_trapped, :abi_failure] and retries > 0 ->
  102:             _ = safe_rebuild(server, inst.pid)
  103:             invoke(server, tspec, request, opts, retries - 1)
  ```
- **Issue**: If the guest trapped because of an illegal payload (e.g. JSON that triggers an invariant panic in Rust), the second invocation will deterministically trap as well, burning an extra crash, instance rebuild, and JIT initialization.
- **Severity**: **Minor** (Performance degradation under hostile inputs).

---

## 6. Actionable Recommendations for v26.11.10 and Beyond

### Priority 1: Remediate Major Findings (Immediate / v26.11.10)

1. **Enforce Static Manifest Allowlist in `FerroplanTransport`**:
   Update `lib/ex4pm_engine/wasm/ferroplan_transport.ex` to parse `host_abi.imports` directly from `priv/ferroplan/MANIFEST.json`, identical to `Admission.import_allowlist()`. Do not dynamically generate the allowlist from the compiled module.
   ```elixir
   def wasi_allowlist do
     @manifest_path
     |> File.read!()
     |> Jason.decode!()
     |> get_in(["host_abi", "imports"])
     |> Enum.map(&parse_wasi_import_spec/1)
   end
   ```

2. **Add Response Bounds Guard & Safe Deallocation to `FerroplanTransport`**:
   In `lib/ex4pm_engine/wasm/ferroplan_transport.ex:234`, enforce `@max_response_bytes 64 * 1024 * 1024`:
   ```elixir
   out_len = band(packed, 0xFFFF_FFFF)

   if out_len > @max_response_bytes do
     _ = call_export(pid, "fp_dealloc", [out_ptr, out_len], timeout)
     {:error, Refusal.new(:resource_limit, "ferroplan response exceeds max_response_bytes")}
   else
     try do
       out = Wasmex.Memory.read_binary(store, memory, out_ptr, out_len)
       decode_response(out)
     after
       _ = call_export(pid, "fp_dealloc", [out_ptr, out_len], timeout)
     end
   end
   ```

### Priority 2: Systems Hardening for Next Milestone (v26.12.0)

3. **Reject Null Pointers in `RealTransport.alloc`**:
   Change `ptr >= 0` to `ptr > 0` in `real_transport.ex:501`:
   ```elixir
   case Wasmex.call_function(pid, alloc_name, [len]) do
     {:ok, [0]} ->
       {:error, refusal(:abi_failure, "alloc_v1 returned null pointer (guest OOM)", %{len: len})}
     {:ok, [ptr]} when is_integer(ptr) and ptr > 0 ->
       {:ok, ptr}
   ```

4. **Synchronize Provenance Hashes**:
   Re-align `priv/wasm4pm/MANIFEST.json` `provenance.source_commit` with `@wasm4pm_source_sha` in `Ex4pmEngine.Wasm.Adapter`.

5. **Wasmtime Fuel & Epoch Interruption**:
   Currently, execution timeouts rely on GenServer call timeouts (`@call_timeout_ms 5_000`). While this prevents the BEAM caller from hanging, a runaway loop inside WASM can tie up the OS thread inside the NIF. Integrate Wasmtime's native **Fuel consumption** or **Epoch-based interruption** (`wasmtime_config_epoch_interruption_set`) to preempt infinite loops at the bytecode level.

---

## 7. Forensic Integrity Audit

As required by the review charter, I conducted an adversarial inspection for integrity violations:
- **Hardcoded Results / Test Facades**: None. In `WasmAllCapabilitiesTest`, real inputs are sent across linear memory, and real algorithm calculations (Petri nets, Markov chains, Kaplan-Meier curves) are verified.
- **Dummy Implementations**: None. All 33 registered algorithms have authentic, functioning `<algo>_v1` and `<algo>_replay_v1` symbols in the compiled binary.
- **Shortcuts / Task Bypasses**: None. Wasmtime executes the bytecodes directly via Wasmex; no simulated fixtures stand in for production paths.
- **Fabricated Verifications**: None. Disk digests match `MANIFEST.json` byte-for-byte; all test runs pass genuinely without skipped assertions.

---

## 8. Verdict

**Verdict**: **APPROVE WITH RECOMMENDATIONS**

`ex4pm` achieves an exceptionally high standard of low-level WebAssembly systems engineering. Its zero-import security model, cryptographic pre-instantiation gate, linear memory RAII deallocation, and 33-algorithm replay parity are best-in-class. Addressing the unbounded read guard and static manifest allowlist in `FerroplanTransport` will bring the entire platform to state-of-the-art systems resilience.
