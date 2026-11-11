# ex4pm-009: WebAssembly Zero-Import Sandboxing, Cryptographic Admission, and 33-Algorithm Registry

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: Bytecode Alliance & WASM Systems Security Architect
- **Domain**: WebAssembly 2.0, Wasmex/Wasmtime, Zero-Trust Sandboxing, SHA-256 Digest Pinning, Memory Safety
- **Target Files**: `lib/ex4pm_engine/wasm/admission.ex`, `lib/ex4pm_engine/wasm/algo_registry.ex`, `lib/ex4pm_engine/wasm/host.ex`

---

## 1. Context & Architecture

Running high-performance analytical algorithms inside the Erlang VM introduces risk if executed as raw C NIFs: a single memory segmentation fault or unhandled panic in the NIF will crash the entire BEAM node, killing all tenant processes.

To achieve native C/Rust execution performance with memory safety and zero risk of node termination, `ex4pm` runs compiled algorithms as **sandboxed WebAssembly binaries** via `Wasmex` (backed by the Bytecode Alliance `Wasmtime` engine).

However, a runtime sandbox alone is insufficient without strict **admission control**:
1. Untrusted or mutated WASM binaries must be rejected before compilation.
2. The guest binary must have zero capability to access host resources: **zero-import enforcement**.
3. All exported function interfaces must be structurally verified.
4. Binary integrity must be cryptographically pinned via SHA-256 manifests.

```text
                  Untrusted WebAssembly Binary (.wasm)
                                   │
                                   ▼
                 Ex4pmEngine.Wasm.Admission.admit/2
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
   Check Magic Bytes         SHA-256 Digest Pin     Zero-Import Check
   Must be <<0, "asm">>      Must match MANIFEST     Imports MUST BE []
         │                         │                         │
         └─────────────────────────┼─────────────────────────┘
                                   │
                                   ▼
                     Required Exports Validation
               ├── memory export
               ├── Allocator trio: alloc_v1, free_v1, dealloc_v1
               └── 33 Algorithm + Replay Export Pairs
                                   │
                                   ▼
                   Cache in :persistent_term
                                   │
                                   ▼
            Admitted Candidate Instance in Sandboxed Host
```

---

## 2. Scope & Technical Specification

### 2.1 The Zero-Import Policy
In `lib/ex4pm_engine/wasm/admission.ex:55-82`:
- The Host ABI specifies `host_abi.imports: []` in `priv/wasm4pm/MANIFEST.json`.
- The admission court inspects the WASM module's declared import section.
- If the binary imports *any* external function (e.g. WASI filesystem, environment variables, network sockets, clock), admission **fails immediately**:
  `{:error, %Ex4pm.Refusal{code: :unauthorized_wasm_imports, details: %{imports: found_imports}}}`
- **Security Guarantee**: The guest code cannot escape its dedicated linear memory sandbox.

### 2.2 Cryptographic Digest Pinning
- Binary path: `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm` (Size: 2.38 MB).
- Manifest path: `priv/wasm4pm/MANIFEST.json`.
- Expected SHA-256 digest: Computed at build time and committed to the manifest.
- When `Admission.admit/2` evaluates a binary:
  - If no digest is provided, rejects with `:wasm_digest_unpinned`.
  - If the computed SHA-256 of the byte slice does not equal the manifest pin, rejects with `:wasm_digest_mismatch`.

### 2.3 Structural Export Inspection & 33-Algorithm Registry
In `lib/ex4pm_engine/wasm/algo_registry.ex`:
- Defines 33 registered algorithms spanning process mining, conformance, graph analysis, and probabilistic inference:
  - Discovery: `alpha_miner`, `inductive_miner`, `heuristic_miner`, `split_miner`, `dfg_builder`
  - Conformance: `token_replay`, `alignments`, `footprint_matrix`, `precision_tbr`, `generalization`
  - Simulation & Performance: `stochastic_simulation`, `critical_path`, `bottleneck_analyzer`, `resource_profile`
  - Cognition & AI: `bayesian_inference`, `markov_chain`, `prolog_engine`, `causal_discovery`
  - Formal Verification: `workflow_soundness`, `reachability_graph`, `t_invariants`, `s_invariants`
  - And 10 additional domain algorithms.
- Each algorithm registers:
  1. `algo_id` (e.g. `:inductive_miner`)
  2. `export_name` (e.g. `"algo_inductive_miner_v1"`)
  3. `replay_export` (e.g. `"replay_inductive_miner_v1"`)
  4. Evidentiary standing rung (e.g. `:alive`)
- Admission verifies that every one of the 70 required exports exists in the WASM header before instantiating the module.

### 2.4 Persistent Term Caching & Host Resilience
- Once admitted, `{engine, module}` is cached in Erlang's `:persistent_term` indexed by `{sha256_digest, allowlist, required_exports}` for zero-allocation reuse.
- `Ex4pmEngine.Wasm.Host` runs as a supervised GenServer with `Process.flag(:trap_exit, true)`.
- If a guest call traps (e.g. out of memory in guest linear heap), `Host` catches the trap, isolates the crash, resets the instance, and increments `:restart_count` without crashing the BEAM.

---

## 3. Work Completed

1. **Deterministic Code Generation**:
   - `AlgoRegistry` deterministically generated from `priv/ontology/ex4pm.ttl` and vendored packs via `mix ex4pm.ggen.sync`.
   - Determinism double-checked via `mix ex4pm.ggen.verify_determinism --all`.
2. **Admission Court Test Hardening**:
   - Tested admission with tampered WASM binaries (modified 1 byte) -> verified refusal with `:wasm_digest_mismatch`.
   - Tested admission with injected host imports -> verified refusal with `:unauthorized_wasm_imports`.
3. **Hex Packaging Size Optimization**:
   - Confirmed both `wasm4pm_ex4pm_bindings.wasm` and `ferroplan_wasm.wasm` bundle cleanly into Hex tarball (`2.0 MB` compressed, well within 8.0 MB ceiling).

---

## 4. Acceptance Criteria

- [x] Zero-import policy strictly enforced; modules with host imports are rejected.
- [x] SHA-256 digest pinning strictly enforced against `priv/wasm4pm/MANIFEST.json`.
- [x] All 33 algorithms in `AlgoRegistry` are verified and exposed.
- [x] `Ex4pmEngine.Wasm.Host` traps exits and recovers gracefully from guest traps.
- [x] `mix ex4pm.exposure.court` passes with 100% algorithm and op coverage.
- [x] `mix ex4pm.ggen.verify_determinism --all` confirms byte-identical generation.

---

## 5. Verification Method

1. **WASM Exposure Court**:
   ```bash
   mix ex4pm.exposure.court
   ```
   *Expected Output*: Confirms all 33 WASM algorithms and Ferroplan operations are exposed and documented.

2. **GGen Determinism Check**:
   ```bash
   mix ex4pm.ggen.verify_determinism --all
   ```
   *Expected Output*: Byte-diff matches 100% with generated registry.

---

## 6. History & Receipts

- **2026-09-12**: Admission court implemented with zero-import allowlist checking.
- **2026-10-17**: Pinned wasm4pm commit `3147d03` with 70 ABI exports.
- **2026-11-10**: Verified 33 algorithms and zero-import sandbox for v26.11.10.
