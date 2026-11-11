# v26.11.10 Release Plan

## Charter / Define

### Objective
Execute the comprehensive release campaign for `ex4pm` version **v26.11.10** across three coordinated milestones:
1. **Milestone 1 — Multi-Agent Expert Architecture Review Wave**: Launch and synthesize 10 domain-expert persona reviews (Zach Daniel, Joe Armstrong, José Valim, Chris McCord, Dave Thomas, Andy Hunt, Wil van der Aalst, Leslie Lamport, Bytecode Alliance, and SRE/Observability) evaluating all facets of the BEAM-native process intelligence platform.
2. **Milestone 2 — Release Documentation & Work Orders**: Populate `docs/jira/v26.11.10/` with the canonical Jira-style release plan (`PLAN.md`), HDDL 2.1 hierarchical task network planning models (`v26.11.10.domain.hddl`, `v26.11.10.problem.hddl`), Product Requirements Document (`PRD-v26.11.10.md`), Architecture Requirements Document (`ARD-v26.11.10.md`), cryptographic Campaign Receipt (`CAMPAIGN-RECEIPT.md`), and 10 detailed work orders (`001-smalt-bridge.md` through `010-review-synthesis.md`).
3. **Milestone 3 — Verification & Hex Publishing**: Synchronize version metadata across `mix.exs` (`@version "26.11.10"`), `CHANGELOG.md` (`## [26.11.10] - 2026-11-10` with explicit "Public contract" subsection), and `README.md` (`{:ex4pm, "~> 26.11.10"}`); execute the full 9-gate `mix verify` verification ladder; build the Hex package artifact; and publish `v26.11.10` to Hex.pm under authenticated credentials.

### Release Scope & Boundaries
- **Repository**: `seanchatmangpt/ex4pm` on branch `main`.
- **Governing Calculus**:
  $$\mathcal{A} = \mu(\mathcal{O}^*), \quad \mathcal{R} = \mathrm{receipt}(\mathcal{A})$$
- **Authority Discipline**:
  - `SELECT`, `CONSTRUCT`, and `DO` are strictly partitioned authority domains.
  - Analytical engine operations (`discover/2`, `conform/3`, `simulate/2`, `plan/2`, `cmca/2`, etc.) execute exclusively as **CONSTRUCT-only** candidates.
  - External state transitions and actuation execute exclusively through `Ex4pm.Evidence.BRCE` under a persisted pending receipt terminating in an outcome receipt (`:alive` or `:blocked`).
  - Zero unreceipted actuation.

---

## Measure — Current State

### Git HEAD and Commit History
- **Current HEAD**: `e384dd18f58f1c3af8bb6024c1871ce7011426f4` on branch `main` (`origin/main`, `origin/HEAD`).
- **Base Tag**: `v26.10.8` (`9f6103a01c99782606ad06ba345ff97361d8af56`).
- **Recent Campaign Commits (`git log -n 5 --oneline`)**:
  ```text
  e384dd1 fix(refusal): add mode and missing_tokens fields to Ex4pm.Refusal
  5ba156e fix(docs): point ex_doc extras at archived ARD path; drop moved consumer/ extras
  6a00297 fix: unblock verify — Ash string-length config + loud-skip ephemeral rdflib courts
  852215c Merge elixir/types-engine-core: @spec coverage (F11) — resolved with F4 decode logic
  744299e Merge otp27/json-hot-path: Jason -> OTP 27 :json at NDJSON hot path (F4)
  ```

### Hex.pm Registry State
- **Active Environment Authentication**: `mix hex.user whoami` confirms authenticated user `seanchatman`.
- **Remote Package Status (`mix hex.info ex4pm`)**:
  - Published releases on Hex.pm:
    - `26.10.17` (Published 2026-10-18)
    - `26.10.8` (Published 2026-10-17)
    - `26.10.1` (Published 2026-10-01)
    - `26.9.30` (Published 2026-10-01)
    - `26.9.9` (Published 2026-09-09)
  - **Immutability Finding**: Version `26.10.17` was published to Hex.pm on 2026-10-18 without an existing git tag on `main`. Because Hex releases are strictly immutable, bumping to `@version "26.11.10"` is required to publish the accumulated improvements.

### Working Tree Improvements
The uncommitted working tree incorporates key release features that will be formalized and verified under v26.11.10:
1. `priv/smalt/powl_bridge.exs`: File-level bridge translating Smalt OCEL/POWL models into `ex4pm` structures.
2. `lib/ex4pm/ocel.ex`: OTP 27 `:json` integration for ultra-low latency NDJSON parsing.
3. `lib/ex4pm/core.ex`: Extended `%Ex4pm.Refusal{}` supporting `mode` and `missing_tokens`.
4. `priv/wasm4pm/`: Updated WASM engine artifacts (`wasm4pm_ex4pm_bindings.wasm` and `MANIFEST.json`).
5. `priv/ggen/vendor/`: Locked packs and provenance metadata.

---

## Explore — Multi-Agent Review Wave & Subsystem Synthesis

### 10 Persona Architectural Reviews
Ten specialized review agents have evaluated `ex4pm` across distinct architectural dimensions. Their detailed reports are filed in `docs/jira/v26.11.10/reviews/`:

| Persona | Domain | Focus Modules | Key Findings & Recommendations |
|---------|--------|---------------|--------------------------------|
| **Zach Daniel** | Ash Framework & Spark DSL | `lib/ex4pm_domain.ex`, `lib/ex4pm_domain/`, `lib/ex4pm_domain/verifiers/verify_soundness.ex`, `lib/ex4pm_core/extractor/` | 34 Ash resources model OCEL 2.0 entities, conformance results, and cognition models. Spark DSL compile-time verification (`VerifySoundness`) halts compilation if state machines fail reachability, liveness, or 1-safety. Extractors cleanly map Ash resources, transitions, and Reactor DAGs to `Ex4pmCore.ProcessIR`. Recommended adding explicit typed calculations for event-object cardinality. |
| **Joe Armstrong** | Erlang/OTP Principles & Concurrency | `lib/ex4pm/application.ex`, `lib/ex4pm/runtime/powl_executor.ex`, `lib/ex4pm/engine/ferroplan/session_supervisor.ex` | Supervision trees follow robust `rest_for_one` patterns between `Registry` and `DynamicSupervisor` in Ferroplan. `PowlExecutor` uses `gen_state_machine` to enforce 1-safe Petri-net token games. WASM host handles process crashes cleanly without bringing down the BEAM node. Recommended explicit crash telemetry events on WASM trap recovery. |
| **José Valim** | Functional Elixir & Idioms | `lib/ex4pm/core.ex`, `lib/ex4pm/ocel.ex`, `lib/ex4pm/ocel_writer.ex`, `lib/ex4pm_engine/` | Strict immutable data structures (`Ex4pm.Subject`, `Ex4pm.EventLog`, `Ex4pm.Evidence.Receipt`). Chunked iodata streaming in `OCEL.Writer` avoids term-materialization spikes. Typed refusals (`%Ex4pm.Refusal{}`) replace runtime exceptions. Gradual typing `@spec` coverage in Elixir 1.17+ is clean. Recommended standardizing error tuple returns across all public helpers. |
| **Chris McCord** | Phoenix & LiveView Presentation | `test/demo_web/lib/ex4pm_web/`, `live/dashboard_live.ex`, `live/powl_miner_live.ex` | Interactive LiveView demo suite in `test/demo_web/` provides real-time Mermaid diagrams, POWL tri-views (Choice Graph, Petri Net, BPMN 2.0), and PubSub receipt streaming. Test-scoping isolates web runtime dependencies from the core hex package. Recommended adding client-side diagram caching for multi-megabyte event logs. |
| **Dave Thomas** | Pragmatic Craftsmanship & Ergonomics | `lib/ex4pm.ex`, `docs/diataxis/`, `docs/guides/` | Clean high-level API in `Ex4pm` (`discover/2`, `conform/3`, `simulate/2`, `plan/2`). Diátaxis documentation structure clearly separates tutorials, how-to guides, reference, and explanation. API follows Chesterton's fence principle. Recommended enriching CLI helper documentation with copy-pasteable examples. |
| **Andy Hunt** | Architecture Orthogonality & Contracts | `lib/ex4pm/contracts.ex`, `lib/ex4pm/gall.ex`, `lib/ex4pm/evidence.ex` | Orthogonal design between domain resources, engines, and evidence ledgers. RFC 8785 canonical JSON hashing in `Ex4pm.Gall` ensures deterministic receipt hashes across node boundaries. `Ex4pm.Contracts.verify/0` enforces invariant boundaries. Recommended expanding contract test suites for cross-node replication. |
| **Wil van der Aalst** | Process Mining & POWL Calculus | `lib/ex4pm/ocel.ex`, `lib/ex4pm/powl.ex`, `lib/ex4pm/engine/online_miner.ex` | OCEL 2.0 object-centric event log support strictly normalizes events, objects, and relationships. Partial Order Workflow Nets (POWL) model concurrency, loops, and choices with mathematical precision. Directly-follows graph (DFG) discovery and conformance checking adhere to foundational process-mining principles. Recommended adding alignment-based replay fitness metrics. |
| **Leslie Lamport** | Formal Methods & Temporal Logic | `lib/ex4pm_engine/workflow_net/`, `lib/ex4pm_domain/verifiers/verify_soundness.ex` | State machine soundness verified through reachability graph construction. 1-safety token game proves no place accumulates unbounded tokens. Temporal invariants (termination, proper completion, absence of deadlocks) formally checked. Recommended publishing formal TLA+ specifications for multi-node receipt consensus. |
| **Bytecode Alliance** | WASM Systems & Sandboxing | `lib/ex4pm_engine/wasm/host.ex`, `lib/ex4pm_engine/wasm/admission.ex`, `priv/wasm4pm/` | Wasmex zero-import sandbox provides complete host isolation. Admission court verifies SHA-256 digest pins, validates magic bytes, enforces zero host imports, and verifies the 33-algorithm export registry. Memory pointers adhere to `alloc_v1`/`free_v1` ABI boundaries. Recommended adding linear memory growth ceilings per tenant. |
| **SRE / Observability** | Streaming Pipelines & Reliability | `lib/ex4pm/stream.ex`, `lib/ex4pm_engine/reactors/chicago/middlewares/chicago_audit_middleware.ex` | Broadway pipelines configure bounded concurrency (`schedulers_online()`) and demand backpressure (`max_demand: 10`, `min_demand: 5`). Sinks receive candidate observations with zero actuation authority. Chicago audit middleware logs full event-execution traces. Recommended adding OpenTelemetry span propagation across WASM calls. |

---

## Develop — Work Orders and Release Execution

### Work Order Inventory (`001` through `010`)
Detailed work order specifications are materialized in `docs/jira/v26.11.10/`:
1. `001-smalt-bridge.md`: Smalt OCEL-to-ex4pm file-level bridge (`priv/smalt/powl_bridge.exs`).
2. `002-ash-dsl-soundness.md`: Ash resources, Spark DSL compile-time verification (`VerifySoundness`), and ProcessIR extractors.
3. `003-otp-supervision-resilience.md`: OTP supervision tree, GenStateMachine POWL execution, and Ferroplan session isolation with journal replay.
4. `004-elixir-idioms-typing.md`: Elixir 1.17/1.20 idioms, typed error handling via `%Ex4pm.Refusal{}`, and comprehensive `@spec` coverage.
5. `005-phoenix-liveview-observability.md`: Phoenix 1.7 LiveView interactive demo suite, PubSub streaming, and AshAdmin UI.
6. `006-pragmatic-craftsmanship-api.md`: Pragmatic craftsmanship, DRY, Diátaxis documentation, and public API ergonomics.
7. `007-process-mining-powl-ocel.md`: OCEL 2.0 normalization, chunked iodata streaming, and POWL discovery/conformance/simulation.
8. `008-formal-methods-soundness.md`: Formal methods, state-machine soundness, 1-safety token game, and temporal invariant verification.
9. `009-wasm-sandbox-admission.md`: Wasmex zero-import sandbox, SHA-256 digest pinning, and 33-algorithm registry admission.
10. `010-review-synthesis.md`: Synthesis of the 10 expert persona reviews, action items, verification ladder, and Hex publishing.

### Release Execution Phases
- **Phase 1: Release Packaging & Metadata Alignment**
  - Update `mix.exs`: `@version "26.11.10"`.
  - Update `CHANGELOG.md`: add entry `## [26.11.10] - 2026-11-10` with explicit "Public contract" subsection.
  - Update `README.md`: set dependency snippet to `{:ex4pm, "~> 26.11.10"}`.
  - Stage and commit all uncommitted files and documentation.
- **Phase 2: Verification Ladder Execution (`mix verify`)**
  Execute the complete 9-gate verification ladder:
  1. `mix format --check-formatted` (Enforces standard code formatting)
  2. `mix compile --warnings-as-errors` (Compiles all modules with zero warnings)
  3. `mix ex4pm.lint.truth` (Runs Anti-Cheat static linter)
  4. `mix ex4pm.exposure.court` (Verifies exposure completeness for algorithms and ferroplan ops)
  5. `mix ex4pm.ggen.verify_determinism --all` (Verifies byte-determinism of generated code)
  6. `mix test --include integration --include stress` (Full test suite execution)
  7. `mix ex4pm.powl.court` (Bounded and generated POWL correspondence courts)
  8. `mix ex4pm.sabotage.court` (Sabotage detection across 6 mutation vectors)
  9. `mix ex4pm.ggen.verify_determinism --all` (Secondary determinism gate)
- **Phase 3: Hex Tarball Build & Publication**
  - Run `mix hex.build` to generate `ex4pm-26.11.10.tar` (~2.0 MB).
  - Verify package contents and checksum.
  - Run `mix hex.publish --yes` using authenticated `seanchatman` credentials.
  - Create annotated Git tag `v26.11.10` and push to origin.

---

## Definition of Done (DoD)

A release candidate qualifies for v26.11.10 release completion when all of the following conditions are witnessed and evidenced:
- [x] All 10 persona architectural reviews completed and recorded in `docs/jira/v26.11.10/reviews/`.
- [x] All 10 numbered work orders (001-010) authored and filed in `docs/jira/v26.11.10/`.
- [x] HDDL 2.1 domain (`v26.11.10.domain.hddl`) and problem (`v26.11.10.problem.hddl`) files authored with balanced syntax and verified grammar.
- [x] Product Requirements Document (`PRD-v26.11.10.md`) and Architecture Requirements Document (`ARD-v26.11.10.md`) fully specified.
- [x] Campaign Receipt (`CAMPAIGN-RECEIPT.md`) binds Git HEAD, base tag, campaign commits, witnessed gates, and standing.
- [ ] Version bumped to `"26.11.10"` in `mix.exs`.
- [ ] `CHANGELOG.md` updated with `## [26.11.10] - 2026-11-10` and explicit "Public contract" subsection.
- [ ] `README.md` updated with `{:ex4pm, "~> 26.11.10"}`.
- [ ] `mix verify` passes all 9 gates with exit code 0.
- [ ] `mix hex.build` produces clean tarball.
- [ ] `mix hex.publish` executes successfully with 200/201 response from Hex.pm.
- [ ] Forensic integrity audit verifies zero unreceipted actuation, genuine logic, and valid receipts.
