# Architecture & DSL Review: Ash Framework & Spark Ecosystem

**Reviewer**: Zach Daniel (Creator of Ash Framework & Spark DSL)  
**Role**: Expert Architectural Reviewer & Adversarial Critic  
**Target**: `ex4pm` Process Intelligence Platform (Release candidate v26.11.10)  
**Date**: 2026-11-11  
**Verdict**: **REQUEST_CHANGES**  

---

## 1. Executive Summary

As the designer and maintainer of Ash Framework and the Spark DSL engine, I approached the review of `ex4pm` with intense curiosity. Process mining, Petri nets, and workflow modeling are natural computational cousins to declarative resource modeling. Ash and Spark were conceived precisely to make domain concepts first-class, declarative, introspectable, and verifiable at compile-time.

There is exceptional engineering ambition in `ex4pm`: 35 domain resources modeling OCEL 2.0 entities, agent lifecycles, cognition sessions, and BEAMOps infrastructure; a universal `Ash.Notifier` targeting IEEE OCEL 2.0 streams; and an AST-to-ProcessIR extraction bridge connecting Ash resources, state machines, and Reactor SAGAs directly into formal choice graphs and partial orders.

However, beneath this impressive architectural surface lie severe DSL anti-patterns, facade verifications, and an architectural integrity violation that bypasses the declarative guarantees Ash and Spark exist to provide. Most critically, the compile-time soundness verification (`Ex4pmDomain.Verifiers.VerifySoundness`) does not verify the Ash DSL AST; instead, it executes an ad-hoc, hand-coded Elixir function (`to_workflow_net/0`) whose state transitions are decoupled from the resource's actual Ash actions. In `ProcessIncident`, `to_workflow_net/0` even invents transitions that do not exist in the action definitions. Furthermore, a dual-domain schism (`Ex4pmDomain` vs `Ex4pm.Domain`) duplicates core entities, and the ProcessIR extractors exhibit shallow introspection and inaccurate callback checks (e.g., checking `undo/3` instead of Reactor's `undo/4`).

Until these facade verifications are replaced with genuine DSL-driven introspection and the architectural schism is resolved, release v26.11.10 cannot be certified as sound.

---

## 2. Persona Perspective & Philosophical Alignment

The core philosophy of Ash Framework and Spark DSL rests on three non-negotiable pillars:

1. **Declarative Truth**: The DSL definition is the single source of truth. If behavior exists, it must be declared in the DSL (actions, changes, validations, calculations). Ad-hoc runtime escape hatches that mirror DSL declarations in duplicate code structures destroy maintainability and create drift.
2. **Compile-Time AST Introspection**: Spark DSL extensions, transformers, and verifiers operate on the **DSL State** (`dsl_state`), not on compiled module functions via `apply/3` or `function_exported?/3`. A verifier must inspect declared entities, options, and AST nodes before compilation completes.
3. **Soundness by Construction**: If a framework claims compile-time soundness of a resource's lifecycle, that proof must be mathematically derived from the *actual executable actions and transitions* of that resource. Proving an unlinked manual projection is a facade that defeats the entire purpose of formal verification.

In reviewing `ex4pm`, I evaluated how faithfully the codebase adheres to these principles across the 35 resources in `Ex4pmDomain`, the Spark verifiers, AshAdmin integration, and the ProcessIR extractors.

---

## 3. Critical Findings & Integrity Violations

### 🚨 [CRITICAL FINDING: INTEGRITY VIOLATION] Facade Verification in State Machine Soundness
- **What**: The compile-time 1-Safe Soundness check (`Ex4pmDomain.Verifiers.VerifySoundness`) does not verify the Ash resource actions or state machine DSL. Instead, it checks a disconnected, hand-written Elixir function (`to_workflow_net/0`). In `Ex4pmDomain.ProcessIncident`, `to_workflow_net/0` invents transitions (`:reopen`) that do not exist in the resource's actions, while splitting existing actions (`:investigate`).
- **Where**: 
  - `lib/ex4pm_domain/verifiers/verify_soundness.ex:20-37`
  - `lib/ex4pm_domain/change_order.ex:58-71`
  - `lib/ex4pm_domain/process_incident.ex:62-76`
- **Why**: This is a textbook facade verification. The soundness prover validates a manually fabricated map, not the actual state transitions executed by Ash changesets. If a developer adds an invalid, unsound action to `ChangeOrder` (e.g. bypassing approval), `to_workflow_net/0` remains static, and `VerifySoundness` happily reports that the resource is mathematically sound. The compiler certifies a mathematical guarantee that the runtime does not uphold.
- **Classification**: **INTEGRITY VIOLATION** (Self-certifying facade bypassing real verification).

---

## 4. Deep Dive & Code Citations

### 4.1 Spark DSL Extension Mechanics & AST Verifiers
`Ex4pmDomain.Extensions.SoundStateMachine` (`lib/ex4pm_domain/extensions/sound_state_machine.ex:1-7`) is declared as:
```elixir
defmodule Ex4pmDomain.Extensions.SoundStateMachine do
  use Spark.Dsl.Extension,
    verifiers: [Ex4pmDomain.Verifiers.VerifySoundness]
end
```
This extension declares no sections, entities, transformers, or DSL options. It exists solely to attach `VerifySoundness`.

Turning to `Ex4pmDomain.Verifiers.VerifySoundness` (`lib/ex4pm_domain/verifiers/verify_soundness.ex:19-41`):
```elixir
19:   @impl Spark.Dsl.Verifier
20:   def verify(dsl_state) do
21:     module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
22: 
23:     if function_exported?(module, :to_workflow_net, 0) do
24:       net = apply(module, :to_workflow_net, [])
25:       report = SoundnessProver.verify_soundness(net)
...
38:     else
39:       :ok
40:     end
41:   end
```
**Architectural Violations:**
1. **Bypassing DSL State**: Spark verifiers are passed `dsl_state`, which contains the parsed entities (`Spark.Dsl.Verifier.get_entities(dsl_state, [:actions])`, etc.). `VerifySoundness` completely ignores `dsl_state` except to read `:module`.
2. **Compile-Time Race & Fallback Trap**: At the time a Spark verifier runs, the module is in the middle of compilation. Unless explicitly configured with `@after_compile true` or `after_compile?: true`, module functions defined with `def` are **not** guaranteed to be exported or loaded into the code server. If `function_exported?(module, :to_workflow_net, 0)` returns `false`, line 39 returns `:ok`! The verifier silently succeeds without verifying anything.
3. **Absence of Real AST Extraction**: A proper Spark extension should synthesize the Workflow Net directly from the declared state machine transitions or actions in `dsl_state`.

### 4.2 Decoupling of Ash Actions & Hand-Rolled Workflow Nets
Compare the action definitions and `to_workflow_net/0` in `Ex4pmDomain.ProcessIncident` (`lib/ex4pm_domain/process_incident.ex`):

**The Ash Actions (lines 16-48):**
```elixir
19:     create :report do
20:       change(set_attribute(:state, :reported))
21:     end
23:     update :triage do
24:       validate(attribute_equals(:state, :reported))
25:       change(set_attribute(:state, :triaged))
26:     end
28:     update :investigate do
29:       validate(attribute_in(:state, [:triaged, :resolved]))
30:       change(set_attribute(:state, :in_progress))
31:     end
33:     update :resolve do
34:       validate(attribute_equals(:state, :in_progress))
35:       change(set_attribute(:state, :resolved))
36:     end
38:     update :close do
39:       validate(attribute_equals(:state, :resolved))
40:       change(set_attribute(:state, :closed))
41:     end
```

**The Hand-Rolled Net (lines 63-75):**
```elixir
63:   def to_workflow_net do
64:     %{
65:       places: ["p_reported", "p_triaged", "p_in_progress", "p_resolved", "p_closed"],
66:       transitions: %{
67:         triage: %{inputs: ["p_reported"], outputs: ["p_triaged"], label: "triage"},
68:         investigate: %{inputs: ["p_triaged"], outputs: ["p_in_progress"], label: "investigate"},
69:         resolve: %{inputs: ["p_in_progress"], outputs: ["p_resolved"], label: "resolve"},
70:         close: %{inputs: ["p_resolved"], outputs: ["p_closed"], label: "close"},
71:         reopen: %{inputs: ["p_resolved"], outputs: ["p_in_progress"], label: "reopen"}
72:       },
...
```
- In the actions, action `:investigate` handles transitions from *both* `:triaged` and `:resolved`.
- In `to_workflow_net/0`, `:investigate` only transitions from `p_triaged` to `p_in_progress`. A fictional transition `:reopen` is introduced from `p_resolved` to `p_in_progress`.
- A caller executing `Ash.Changeset.for_update(incident, :reopen)` will immediately crash with `NoSuchAction`, because `:reopen` does not exist on the resource.
- Furthermore, `ChangeOrder` and `ProcessIncident` hand-roll state machine attributes and validations with `attribute_equals` instead of using the official `AshStateMachine` extension! Ironically, `Ex4pm.Domain.Intervention` in `lib/ex4pm/domain.ex:360-376` *does* use `AshStateMachine` cleanly.

### 4.3 Dual-Domain Architectural Schism
The repository contains two competing domain definitions:
1. `Ex4pm.Domain` in `lib/ex4pm/domain.ex` (475 lines, 14 inline resource modules: `Agent`, `Event`, `Object`, `Intervention`, etc.).
2. `Ex4pmDomain` in `lib/ex4pm_domain.ex` (58 lines, referencing 35 separate resource files under `lib/ex4pm_domain/`).

Both domains define resources named `Agent`, `AgentRun`, `Event`, `Object`, `EventObject`, `ObjectObject`, `ConformanceResult`, and `Refusal`.
- `Ex4pm.Domain` uses inline module definitions where each resource points to `domain: Ex4pm.Domain`.
- `Ex4pmDomain` uses standalone files pointing to `domain: Ex4pmDomain`.
- This causes confusion across the codebase: some tests use `Ex4pm.Domain`, others use `Ex4pmDomain`. Having duplicate ETS table backends and parallel resource graphs violates the DRY principle and dilutes domain boundaries.

### 4.4 ProcessIR Extractors Introspection Analysis

#### 4.4.1 `Ex4pmCore.ProcessIR.Extractor.Ash` (`lib/ex4pm_core/extractor/ash.ex`)
- **Moduledoc Claim vs Reality**: The moduledoc claims to introspect "actions, attributes, calculations, aggregates, and field-level policies" (line 5). In reality, calculations and aggregates are **completely missing** from the implementation. There is not a single line calling `Ash.Resource.Info.calculations/1` or `Ash.Resource.Info.aggregates/1`.
- **Relationship Type Collapsing** (lines 178-183):
  ```elixir
  rel_type =
    case Map.get(rel, :cardinality) do
      :one -> :o2o
      :many -> :o2m
      _ -> :o2o
    end
  ```
  In Ash, relationships carry explicit types (`rel.type` in `[:belongs_to, :has_one, :has_many, :many_to_many]`). By branching solely on `:cardinality`, `:many_to_many` relationships are flattened into `:o2m` without extracting the join resource or intermediate keys, and `:belongs_to` is conflated with `:has_one`.
- **Defensive Reflection Anti-Pattern**: Lines 69-86, 114-139, 155-172 use `try ... apply(Ash.Resource.Info, ...) rescue _ -> []`. Since Ash is a direct compile-time dependency in `mix.exs`, dynamic `apply/3` and swallowing errors with catch-all rescues obscures real AST bugs.

#### 4.4.2 `Ex4pmCore.ProcessIR.Extractor.AshStateMachine` (`lib/ex4pm_core/extractor/ash_state_machine.ex`)
- Lines 21-42 query `AshStateMachine.Info.states/1`, `transitions/1`, and `initial_states/1`.
- However, as noted, neither `Ex4pmDomain.ChangeOrder` nor `Ex4pmDomain.ProcessIncident` uses `AshStateMachine`.
- As a result, attempting to extract the state machine from `ChangeOrder` yields an empty struct (`states: []`, `activities: %{}`, `choices: %{}`).
- The test in `test/extractor_test.exs:101-107` avoids this failure by only testing a dummy `MockAshResource` and asserting that it "extracts fallback gracefully".

#### 4.4.3 `Ex4pmCore.ProcessIR.Extractor.Reactor` (`lib/ex4pm_core/extractor/reactor.ex`)
- **Faulty Undo / Compensation Detection** (lines 28-32):
  ```elixir
  has_undo? = is_tuple(impl) or (is_atom(impl) and function_exported?(impl, :undo, 3))
  has_compensate? = is_tuple(impl) or (is_atom(impl) and function_exported?(impl, :compensate, 4))
  ```
  1. `is_tuple(impl)` assumes *any* tuple (e.g. `{MyStep, [opt: :val]}`) implements `undo` and `compensate`. This is completely invalid; most step options tuples do not implement undo.
  2. In `Reactor.Step`, the `undo` callback signature is arity 4: `undo(arguments, value, context, step)`. Checking `function_exported?(impl, :undo, 3)` fails to detect valid Reactor steps that implement `undo/4`!
- **Lack of Nested Step Introspection**: Lines 104-111 extract top-level steps only (`%{steps: s}`). In Reactor, steps can be grouped in sub-reactors, `group`, or `flavour`. These nested steps are omitted from the generated DAG.

### 4.5 Ash Resource Idioms & Conventions across `Ex4pmDomain`
1. **Timestamp Typing in `Ex4pmDomain.Event`** (`lib/ex4pm_domain/event.ex:55`):
   `attribute(:timestamp, :string, allow_nil?: false, public?: true)`
   In an OCEL 2.0 process mining system, timestamps are the primary temporal axis. Storing timestamps as raw `:string` forfeits Ash's built-in datetime validations, casting, ISO 8601 parsing, and temporal filtering. It should be `:utc_datetime_usec`.
2. **Missing `through` Relationships**:
   In `Event` (`event.ex:79-82`), there is `has_many(:event_objects, Ex4pmDomain.EventObject)`. But there is no `has_many(:objects, through: [:event_objects, :object])`. Navigating from an event to its related objects requires manual join traversal rather than idiomatic Ash relationship loading (`Ash.load(event, :objects)`).
3. **ETS Data Layer Configuration**:
   All 35 resources in `Ex4pmDomain` use `data_layer: Ash.DataLayer.Ets`. However, only 6 resources explicitly declare their ETS table options (`ets do private?(false) table(...) end`). The rest use anonymous generated tables.

### 4.6 AshAdmin Integration (`show?(true)`)
`Ex4pmDomain` sets:
```elixir
admin do
  show?(true)
end
```
However, out of 35 resources, only 6 have `extensions: [AshAdmin.Resource]` configured (`Receipt`, `PowlModel`, `BayesianNetwork`, `KanbanCard`, `Deployment`, `ClusterNode`).
The remaining 29 resources lack `admin` blocks. While AshAdmin displays resources in the domain by default, without resource-level `admin` blocks, admin users cannot customize display labels, configure default read actions, format complex attributes (e.g. `ocel_event`, `conformance_vector`), or prevent destructive actions in the UI.

### 4.7 Orphaned `OcelNotifier` & Flawed `Ex4pmDomain.Manager` Boilerplate
- **The Orphaned Notifier**: `Ex4pmDomain.Notifier.OcelNotifier` (`lib/ex4pm_domain/notifier/ocel_notifier.ex`) is well-designed. It intercepts Ash changesets and constructs valid OCEL 2.0 envelopes. However, **zero** production resources in `Ex4pmDomain` include `notifiers: [Ex4pmDomain.Notifier.OcelNotifier]`. It is an unused asset in production.
- **`Ex4pmDomain.Manager` Race Conditions** (`lib/ex4pm_domain/manager.ex:19-33`):
  ```elixir
  case Ash.get(Agent, agent_id, domain: Ex4pmDomain) do
    {:ok, existing} -> Ash.update(...)
    {:error, _} -> Ash.create(...)
  end
  ```
  This hand-rolled read-then-write pattern is susceptible to concurrency races. Ash provides native atomic upserts via `Ash.create(..., upsert?: true, upsert_identity: :unique_name)`. Furthermore, `Ex4pmDomain` defines no Ash code interfaces (`define ...`), forcing callers into verbose changeset boilerplate.

---

## 5. Areas of Excellence & Praise

Despite the critical architectural findings above, `ex4pm` demonstrates notable achievements in domain modeling and ecosystem integration:

1. **Rich OCEL 2.0 & Formal Method Domain Modeling**:
   The breadth of domain modeling in `Ex4pmDomain` is staggering. Defining 35 resources spanning E2O/O2O graph structures, LTLf constraints (`LtlfConstraint`), Petri nets (`PowlModel`), Bayesian networks, Markov models, and Pareto frontiers within Ash resources demonstrates deep understanding of process mining ontologies.
2. **Ash Type Compatibility Layer (`Wasm4pmCompat.AshTypes`)**:
   The use of custom Ash types for domain constraints (e.g. `Conformance.Fitness`, `Ids.EventId`, `Powl.Powl`) provides strong runtime type contracts and validations.
3. **Declarative Identities**:
   Resources like `CapabilityReceipt` and `PowlModel` make excellent use of Ash identities (`identity :unique_name, [:name], pre_check_with: Ex4pmDomain`), enabling deterministic resolution and upserts.
4. **Clean Decoupling of Public API**:
   The top-level `Ex4pm` module acts as a disciplined CONSTRUCT-only facade, directing all state mutations and DO actuation strictly through `Ex4pm.Evidence.BRCE`.

---

## 6. Technical Debt, Concerns & Edge Cases

| Area | Location | Issue | Severity |
|---|---|---|---|
| **Soundness Verifier** | `verify_soundness.ex:23` | Inspects module exports rather than AST `dsl_state`; can silently pass on uncompiled modules. | Critical |
| **Facade Net** | `process_incident.ex:63` | `to_workflow_net/0` hardcodes an unlinked Petri net with fictitious transitions (`:reopen`). | Critical |
| **Domain Duplication** | `ex4pm_domain.ex` vs `ex4pm/domain.ex` | Two separate Ash domains defining overlapping resources (`Event`, `Object`, `Agent`). | Major |
| **Extractor Gap** | `extractor/ash.ex:1` | Moduledoc claims calculation & aggregate extraction, but neither is implemented. | Major |
| **Reactor Arity Bug** | `extractor/reactor.ex:28` | Checks `undo/3` instead of `undo/4`; assumes any tuple implements `undo`. | Major |
| **Orphaned Notifier** | `ocel_notifier.ex` | `OcelNotifier` is attached to zero production resources in `Ex4pmDomain`. | Medium |
| **String Timestamps** | `event.ex:55` | Storing timestamps as `:string` instead of `:utc_datetime_usec`. | Medium |
| **AshAdmin Incompleteness** | `ex4pm_domain/*.ex` | Only 6 of 35 resources configure `AshAdmin.Resource`. | Minor |
| **Non-atomic Upserts** | `manager.ex:19` | Hand-rolled `get -> update / create` pattern instead of native Ash atomic upserts. | Minor |

---

## 7. Actionable Recommendations for v26.11.10 and Beyond

### Priority 1: Eliminate Facade Verification (v26.11.10 Milestone)
1. **Derive Workflow Nets from DSL State**:
   Rewrite `VerifySoundness` to inspect `dsl_state` directly. Extract the declared actions or `AshStateMachine` transitions from `Spark.Dsl.Verifier.get_entities(dsl_state, [:actions])`.
   Construct the Petri net / Workflow net graph programmatically from the transitions in the DSL AST, and verify that generated net.
2. **Deprecate Hand-Coded `to_workflow_net/0`**:
   Remove manual `to_workflow_net/0` maps from `ChangeOrder` and `ProcessIncident`. If a developer needs an exported net, generate `to_workflow_net/0` dynamically via a Spark DSL transformer or macro based on the verified AST.
3. **Adopt `AshStateMachine` Across Resources**:
   Refactor `ChangeOrder` and `ProcessIncident` to use the official `AshStateMachine` extension, matching what `Ex4pm.Domain.Intervention` already does.

### Priority 2: Unify the Domain Architecture
1. **Consolidate on `Ex4pmDomain`**:
   Retire the inline resource definitions in `lib/ex4pm/domain.ex`. Migrate any unique resources (such as `Intervention`) into `lib/ex4pm_domain/intervention.ex` under `Ex4pmDomain`. Ensure `Ex4pm.Domain` is either aliased to `Ex4pmDomain` or clearly documented as a deprecated projection.

### Priority 3: Fix ProcessIR Extractors
1. **Implement Calculation and Aggregate Introspection**:
   In `Ex4pmCore.ProcessIR.Extractor.Ash`, implement `Ash.Resource.Info.calculations(resource)` and `Ash.Resource.Info.aggregates(resource)`. Map calculations to computed properties on `ObjectType`.
2. **Correct Reactor Undo Callback Check**:
   Update `extractor/reactor.ex` to check `function_exported?(module, :undo, 4)` and inspect whether tuple step arguments actually resolve to a module exporting `:undo`.
3. **Enhance Relationship Modeling**:
   Inspect `rel.type` in `Ash.Resource.Info.relationships(resource)` to properly distinguish `:belongs_to`, `:has_one`, `:has_many`, and `:many_to_many`.

### Priority 4: Idiomatic Ash Domain Modernization
1. **Add Code Interfaces to `Ex4pmDomain`**:
   Replace `Ex4pmDomain.Manager` boilerplate with Ash code interfaces defined on `Ex4pmDomain`:
   ```elixir
   defines do
     define :create_event, action: :create, args: [:activity, :timestamp]
     define :upsert_agent, action: :create, upsert?: true
   end
   ```
2. **Attach `OcelNotifier`**:
   Add `notifiers: [Ex4pmDomain.Notifier.OcelNotifier]` to core mutable resources (`ChangeOrder`, `ProcessIncident`, `KanbanCard`, `Deployment`) so that business actions emit real OCEL 2.0 telemetry out of the box.
3. **Migrate Event Timestamps**:
   Change `attribute :timestamp, :string` in `Event` to `:utc_datetime_usec`.

---

## 8. Review Verdict & Acceptance Criteria

### Verdict
**REQUEST_CHANGES**

### Rationale
While `ex4pm` exhibits impressive architectural scope and vision, the presence of a **CRITICAL INTEGRITY VIOLATION** in `Ex4pmDomain.Verifiers.VerifySoundness` and `to_workflow_net/0` prevents approval. Mathematical 1-Safe Soundness is currently proven against a hand-crafted dummy projection that is decoupled from the resource's actual executable Ash actions. In `ProcessIncident`, the verified projection does not even match the actions defined in the resource. Furthermore, the dual-domain duplication and extractor defects represent significant architectural liabilities.

### Conditions for Approval
1. **Fix Soundness Verification**: `VerifySoundness` must construct the Workflow Net directly from the Ash DSL AST (`dsl_state`), or `ChangeOrder` and `ProcessIncident` must use `AshStateMachine` with an automated AST-to-net transformation. Hand-coded unlinked `to_workflow_net/0` maps must be removed or strictly verified against declared actions.
2. **Fix Extractor Defects**: Update `Reactor` extractor to check `undo/4` and resolve tuple steps safely; implement calculation/aggregate extraction in `Ash` extractor or update its moduledoc to reflect actual scope.
3. **Deprecate Domain Duplication**: Provide a clean unification plan or deprecation notice for the dual `Ex4pm.Domain` vs `Ex4pmDomain` split.
