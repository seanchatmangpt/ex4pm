# Product Requirements Document (PRD) — ex4pm v26.11.10

## 1. Source / Background

`ex4pm` is a BEAM-native process intelligence system providing OCEL 2.0 ingest, Partial Order Workflow Net (POWL) discovery, conformance checking, simulation, BRCE-gated actuation, deterministic receipt emission, and replay.

The release of **v26.11.10** is motivated by operational needs and repository progression:
1. **Hex Immutability & Version Gap**: On 2026-10-18, package release `26.10.17` was published to Hex.pm under user `seanchatman`. Because Hex.pm package releases are strictly immutable, subsequent enhancements and bug fixes accumulated on `main` (commit `e384dd1`) cannot be re-published as `26.10.17`. A new canonical release, `v26.11.10`, is required to distribute these capabilities to the Elixir/BEAM ecosystem.
2. **High-Performance Ingest (OTP 27 `:json`)**: High-throughput NDJSON event log ingestion previously bottlenecked on general-purpose decoding. Re-routing the NDJSON decode hot path to the Erlang/OTP 27 native `:json` module delivers significant memory reduction and throughput acceleration.
3. **Operational Refusal Granularity**: Production process mining pipelines require actionable, typed diagnostic reasons when event streams violate conformance or tokens are missing. Adding `mode` and `missing_tokens` to `%Ex4pm.Refusal{}` provides this machine-readable clarity.
4. **Smalt OCEL Modeling Integration**: Smalt OCEL models must interoperate with `ex4pm` without requiring complex distributed dependencies; a dedicated file-level bridge (`priv/smalt/powl_bridge.exs`) bridges this gap.
5. **Gradual Typing Hardening**: Aligning with Elixir 1.17/1.20 gradual type system initiatives, strict `@spec` coverage across all core and engine modules ensures static dialyzer cleanliness.
6. **10-Persona Expert Architecture Wave**: A comprehensive multi-agent architectural review across 10 expert domains (Zach Daniel, Joe Armstrong, José Valim, Chris McCord, Dave Thomas, Andy Hunt, Wil van der Aalst, Leslie Lamport, Bytecode Alliance, and SRE) provides authoritative validation and future roadmap guidance.

---

## 2. Product Outcome

A production-certified, immutable release of `ex4pm` published to Hex.pm as version **26.11.10**, providing:
- High-throughput OCEL 2.0 event log ingestion with native OTP 27 `:json` decoding.
- Comprehensive POWL process discovery and conformance verification backed by 33 sandboxed WASM algorithms.
- Enforced compile-time workflow soundness via Spark DSL AST validation (`VerifySoundness`).
- Fully receipted execution via `Ex4pm.Evidence.BRCE` ensuring zero unreceipted side effects.
- Clean verification against the 9-gate repository verification ladder (`mix verify`).

---

## 3. Problem Statement

1. **Ingest Serialization Bottleneck**: Ingestion of large OCEL 2.0 NDJSON logs (millions of events) incurs substantial CPU and GC overhead when parsing via external libraries. Native OTP 27 `:json` decoding must be leveraged on the ingest hot path.
2. **Opaque Conformance Refusal Diagnostics**: When token-game replay or conformance checking fails, consumers need precise details on which Petri-net markings or mode transitions stalled.
3. **External Model Interoperability**: Smalt process models and benchmarks require a standardized translation layer to convert Smalt event objects into ex4pm POWL representations.
4. **Static Type Ambiguity**: Dynamic typing in process-mining algorithms risks undetected edge-case crashes unless strictly bounded by `@spec` definitions and dialyzer checks.
5. **Architecture Drift & Lack of Peer Critique**: Complex distributed process intelligence systems risk architectural divergence unless systematically evaluated by experts in DSL design, OTP concurrency, functional idioms, formal verification, and systems isolation.

---

## 4. Functional Requirements

### R1. Multi-Agent Review Synthesis
- **Description**: Synthesize 10 independent architectural reviews from domain-expert personas into the release plan and roadmap.
- **Personas**:
  1. *Zach Daniel*: Ash Framework, 34 domain resources, Spark DSL compile-time verification (`VerifySoundness`), and ProcessIR extraction.
  2. *Joe Armstrong*: Erlang/OTP principles, process tree fault tolerance, `gen_state_machine` token execution, and Ferroplan session isolation with journal replay.
  3. *José Valim*: Functional Elixir idioms, immutable structs, chunked iodata streaming, typed refusals (`%Ex4pm.Refusal{}`), and `@spec` gradual typing.
  4. *Chris McCord*: Phoenix 1.7 LiveView suite (`test/demo_web/`), PubSub event feeds, tri-view POWL visualization, and test dependency isolation.
  5. *Dave Thomas*: Pragmatic craftsmanship, API ergonomics (`lib/ex4pm.ex`), Chesterton's fence, and Diátaxis documentation structure.
  6. *Andy Hunt*: Orthogonal architecture, `Ex4pm.Contracts`, invariant boundaries, and RFC 8785 canonical JSON hashing (`Ex4pm.Gall`).
  7. *Wil van der Aalst*: Process mining foundations, OCEL 2.0 object-centric event logs, POWL mathematical calculus, DFG discovery, and conformance checking.
  8. *Leslie Lamport*: Formal methods, reachability graph soundness, 1-safety token game proofs, and temporal safety/liveness invariants.
  9. *Bytecode Alliance*: WASM systems architecture, Wasmex zero-import sandbox, SHA-256 digest pinning, and 33-algorithm `AlgoRegistry`.
  10. *SRE / Observability*: Broadway streaming pipelines (`schedulers_online()` concurrency, demand backpressure), Prometheus/telemetry metrics, and audit middleware.
- **Deliverables**: Detailed critique documents in `docs/jira/v26.11.10/reviews/` and synthesized action items in work orders `001`-`010`.

### R2. Smalt OCEL Bridge
- **Description**: Provide a file-level bridge translating Smalt OCEL 2.0 logs and models directly into `ex4pm` data structures.
- **Locus**: `priv/smalt/powl_bridge.exs`.
- **Capabilities**:
  - Parse Smalt event log specifications.
  - Map Smalt object types and event-to-object relations into `Ex4pm.EventLog` and Ash domain entities.
  - Convert Smalt process topologies into `Ex4pm.POWL` trees.

### R3. Refusal Enhancements & Mode Field
- **Description**: Extend `%Ex4pm.Refusal{}` with structured diagnostic fields.
- **Locus**: `lib/ex4pm/core.ex`.
- **Fields Added**:
  - `mode: atom()` (e.g., `:token_shortfall`, `:unsupported_operator`, `:unpinned_digest`, `:conformance_violation`).
  - `missing_tokens: non_neg_integer() | nil` (quantifying tokens missing during Petri-net replay).
- **Semantics**: Preserves all existing refusal codes while providing granular diagnostic metadata for upstream automated recovery.

### R4. OTP 27 JSON Hot Path
- **Description**: Transition NDJSON decoding in high-throughput streaming ingest to Erlang/OTP 27 native `:json`.
- **Locus**: `lib/ex4pm/ocel.ex`.
- **Capabilities**:
  - Direct calls to `:json.decode/1` on line-delimited JSON chunks.
  - Fallback / compatibility guarantees across supported BEAM environments.
  - Preserves byte-for-byte fidelity with RFC 8259 JSON compliance.

### R5. Core `@spec` Typing & Dialyzer Cleanliness
- **Description**: Enforce comprehensive `@spec` and `@type` declarations across `ex4pm_core` and `ex4pm_engine`.
- **Locus**: `lib/ex4pm_core/` and `lib/ex4pm_engine/`.
- **Capabilities**:
  - Complete type signatures on all public and internal boundary functions.
  - Clean compilation under `mix compile --warnings-as-errors`.
  - Compatibility with Elixir 1.17+ gradual type checker and Dialyzer PLT files.

### R6. WASM 33-Algorithm Sandboxed Execution
- **Description**: Ensure all 33 process-mining algorithms declared in `Ex4pmEngine.Wasm.AlgoRegistry` run under zero-import Wasmex sandboxes.
- **Locus**: `lib/ex4pm_engine/wasm/`, `priv/wasm4pm/`.
- **Invariants**:
  - SHA-256 digest pinned to `priv/wasm4pm/MANIFEST.json`.
  - Zero host imports (`host_abi.imports: []`).
  - Linear memory pointer discipline (`alloc_v1`, `free_v1`, `dealloc_v1`).
  - Automatic host recovery upon guest traps.

### R7. Hex.pm v26.11.10 Release
- **Description**: Package and publish the verified release artifact to Hex.pm.
- **Locus**: `mix.exs`, `CHANGELOG.md`, `README.md`.
- **Metadata**:
  - Version: `26.11.10`.
  - Package files: `["lib", "priv", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]`.
  - Size ceiling: Under 8 MB (actual tarball ~2.0 MB).
  - Credentials: User `seanchatman`.

---

## 5. Acceptance Criteria

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| **AC-1** | Review Synthesis | All 10 persona reviews authored in `docs/jira/v26.11.10/reviews/` and summarized in `PLAN.md`. |
| **AC-2** | Smalt Bridge | `priv/smalt/powl_bridge.exs` exists and converts Smalt models without runtime errors. |
| **AC-3** | Refusal Fields | `%Ex4pm.Refusal{}` struct contains `:mode` and `:missing_tokens` with correct types. |
| **AC-4** | OTP 27 JSON | `lib/ex4pm/ocel.ex` executes `:json.decode/1` on NDJSON hot paths. |
| **AC-5** | Typing Cleanliness | `mix compile --warnings-as-errors` passes with 0 warnings on OTP 27+ / Elixir 1.17+. |
| **AC-6** | WASM Admission | `Ex4pmEngine.Wasm.Admission` passes digest verification and exposes all 33 algorithms. |
| **AC-7** | Hex Release | `mix hex.build` creates valid tarball; `mix hex.publish` succeeds; version `26.11.10` appears on Hex.pm. |

---

## 6. Verification Ladder

Every release candidate must pass all 9 gates of `mix verify` in sequence:
1. `mix format --check-formatted`: Formatter cleanliness across entire repository.
2. `mix compile --warnings-as-errors`: Zero compiler warnings under `MIX_ENV=test`.
3. `mix ex4pm.lint.truth`: Static truth-linter checking zero fabricated or hardcoded results.
4. `mix ex4pm.exposure.court`: Proves full exposure of all wasm4pm algorithms and ferroplan operations.
5. `mix ex4pm.ggen.verify_determinism --all`: Byte-identical determinism of generated registry code.
6. `test --include integration --include stress`: Complete test suite execution.
7. `mix ex4pm.powl.court`: Bounded and property-corpus POWL/Reactor correspondence.
8. `mix ex4pm.sabotage.court`: Sabotage detection across 6 mutation vectors.
9. `mix ex4pm.ggen.verify_determinism --all`: Final determinism verification.

---

## 7. Release Rules

1. **Zero Unreceipted Actuation**: No state change or external DO may execute without a prior pending receipt and terminating outcome receipt via `Ex4pm.Evidence.BRCE`.
2. **Zero Path/Git Dependencies**: `mix.exs` must contain only hex packages with semantic version constraints (`~>` or `>=`).
3. **Public Contract Documentation**: `CHANGELOG.md` entry `## [26.11.10] - 2026-11-10` must contain an explicit "Public contract" subsection describing changes or affirming "UNCHANGED".
4. **Digest Immutability**: Any modification to `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm` must update `priv/wasm4pm/MANIFEST.json` digest pin before verification.
