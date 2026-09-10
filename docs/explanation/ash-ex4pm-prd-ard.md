# ash_ex4pm — PRD / ARD

**Status:** DRAFT, UNSTARTED. `~/ash_ex4pm` does not exist as a repo (not present under `/Users/sac`; no path/hex dependency declares it anywhere in `~/ex4pm` or `~/xaas`). This document specifies the extension; it does not scaffold it. Every upstream claim below is cited to a real file read in this session, not inferred — CONFIRMED/CONTRADICTED status is stated per claim, per the `ex4pm-ocel-emission-mechanisms` research report.

## 0. What ash_ex4pm is

An Ash extension that generates automatic OCEL 2.0 event emission for Ash resources and domains, built on top of `ex4pm`'s real canonical event pipeline (`Ex4pm.OCEL.normalize/1` → `%Ex4pm.Event{}`), and — where the research supports it — a BRCE-gate capability wiring `Ex4pm.Evidence.BRCE` ahead of state-changing actions. It is generated from the real, already-upgraded `ash-extension-core-pack` v26.9.10 (`/Users/sac/ggen-marketplace/packs/ash-extension-core-pack/pack.toml` line 3: `version = "26.9.10"`), following the six-piece Spark extension shape the pack's precedent extension `ash_r2rml` actually implements.

```
compose(
  ash-extension-core-pack@26.9.10,      # DSL entity/section/transformer/verifier/Info generator
  ex4pm/lib/ex4pm/ocel.ex,               # Ex4pm.OCEL.normalize/1 — sole canonical constructor of %Ex4pm.Event{}
  ex4pm/lib/ex4pm/stream/ingest.ex,      # Ex4pm.Stream.Ingest.ingest_envelope/2 — real ingest entrypoint
  ex4pm/lib/ex4pm/evidence/ (BRCE)       # Ex4pm.Evidence.BRCE — sole DO-authority gate (not yet wired for this use)
)
```

## 1. PRD

### 1.1 Problem

Ash resource authors who want OCEL-conformant process-mining event logs today must hand-write emission: manually construct envelopes, call into `ex4pm`'s ingestion path correctly, and (for state-changing actions) manually gate execution through `Ex4pm.Evidence.BRCE`. This drifts the same way `AshPaperTrail`/`ash_r2rml`-style hand-written integrations drift — and the research found `ex4pm`'s *own* existing "automatic" attempt at this (`Ex4pmDomain.Notifier.OcelNotifier`) is silently broken: it calls a function that does not exist, so it currently falls through to a fake-success no-op on every resource change. There is no supported, generated mechanism today.

### 1.2 Goals

1. Generate a Spark DSL extension usable at the resource level and the domain level (`use AshEx4pm.Resource` / `use AshEx4pm.Domain`, exact module names TBD — see §5) via `ash-extension-core-pack` v26.9.10.
2. Route all emitted events through the one real canonical constructor, `Ex4pm.OCEL.normalize/1` (`lib/ex4pm/ocel.ex:56/77` → private `normalize_event/2` at `lib/ex4pm/ocel.ex:219`, called via `normalize_events/1` at lines 159/173) — never hand-construct `%Ex4pm.Event{}}` elsewhere.
3. Fix, or route around, the dead `ingest_batch/1` call in `Ex4pmDomain.Notifier.OcelNotifier` (`lib/ex4pm_domain/notifier/ocel_notifier.ex:34`) so generated emission actually reaches `Ex4pm.Stream.Ingest` rather than silently no-op'ing.
4. Where the research supports it, generate an opt-in BRCE gate ahead of state-changing Ash actions using `Ex4pm.Evidence.BRCE` — deferred pending the open questions in §5 (no existing `Ex4pm.OCEL.Source` behaviour or `Ex4pm.Event.new/1` builder exists to hang this on cleanly; see §2).
5. Follow the `ash_r2rml` six-piece extension shape exactly (entity structs → `%Spark.Dsl.Entity{}`/`%Spark.Dsl.Section{}` → extension module → `Persist` transformer → `Verify` verifier → `Info` module → Igniter-gated installer) rather than inventing a new extension shape.

### 1.3 Non-goals (v1)

- Global notifier injection into an already-declared `Ash.Resource`'s own `notifiers:` list (the `AshPaperTrail.Resource.Transformers.VersionOnChange` move) — no `aex:globalNotifierInjection`-style property exists in the pack today (confirmed absent from `ontology.ttl`); named as a future CREATE, not built here.
- Per-Reactor middleware auto-injection — whether `aex:workflowReactor` already supports generating a per-Reactor `middlewares do ... end` block or only a single named reactor reference is UNVERIFIED in the pack tracker; not assumed either way, not built here.
- Fixing `Ex4pmDomain.Reactors.Middlewares.OcelEventMiddleware`'s silent `complete/2`/`error/2` no-ops (`lib/ex4pm_engine/reactors/middlewares/ocel_event_middleware.ex:18,23`) — named as a pre-existing `ex4pm` bug this document depends on but does not fix.
- Building `Ex4pm.OCEL.Source` behaviour or `Ex4pm.Event.new/1` — neither exists anywhere in `ex4pm` (confirmed zero hits); this document does not invent them, it flags their absence as a blocker.
- A repo scaffold, `mix.exs`, or any generated code for `ash_ex4pm` itself.

### 1.4 Users

- App authors with an Ash resource/domain who want OCEL emission without hand-writing envelope construction.
- The `ash-extension-core-pack` generator/pack author extending v26.9.10's vocabulary to cover this use case.

### 1.5 Functional requirements

| # | Requirement |
|---|---|
| FR1 | Resource-level DSL section (e.g. `ex4pm do ... end`) generated via `%Spark.Dsl.Section{}`, mirroring `ash_r2rml`'s `@r2rml` (`resource.ex:142-152`). |
| FR2 | `Persist` transformer compiles DSL entities into a canonical event-mapping struct and calls `Ex4pm.OCEL.normalize/1` — never a hand-rolled `%Ex4pm.Event{}}` construction. |
| FR3 | `Persist` transformer declares `after?/1` ordered after Ash's own core transformers, mirroring `ash_r2rml`'s five clauses (`resource.ex:188-194`) via the pack's `aex:afterTransformer` property. |
| FR4 | `Verify` verifier fails closed (`Spark.Error.DslError`) when the persisted mapping is absent or invalid, mirroring `ash_r2rml.Resource.Verify` (`resource.ex:492-511`). |
| FR5 | `Info` module exposes `mapping/1`, `mapping_result/1`, `mapping!/1`, `mapped?/1`-equivalents via `Spark.Dsl.Extension.get_persisted/3`. |
| FR6 | Emission path replaces the dead `Ex4pmDomain.Notifier.OcelNotifier` call (`ingest_batch/1`, `lib/ex4pm_domain/notifier/ocel_notifier.ex:34`, which does not exist) with a real call to `Ex4pm.Stream.Ingest.ingest_envelope/2` (`lib/ex4pm/stream/ingest.ex:19`), the only ingest function that actually exists. |
| FR7 | Domain-level and resource-level DSL usage both supported, via the pack's `aex:contextNormalize`/`aex:contextTargetEntity`/`aex:contextTargetField` triple. |
| FR8 (deferred) | Optional BRCE gate ahead of state-changing actions using `Ex4pm.Evidence.BRCE` — blocked pending §5 open questions; not built in v1. |
| FR9 | Igniter-gated installer (`Code.ensure_loaded?(Igniter)` branch + manual-instructions fallback), mirroring `Mix.Tasks.AshR2rml.Install` (`ash_r2rml.install.ex:5-65`). |

### 1.6 Non-functional requirements

- Chicago-style testing only: real Ash resources compiled against the real extension, real `Ex4pm.OCEL.normalize/1` calls, real `Ex4pm.Stream.Ingest.ingest_envelope/2` calls — no `Mock`/`patch`/`monkeypatch` over collaborators this codebase or `ex4pm` owns.
- Generated via `ash-extension-core-pack` v26.9.10 ontology properties only — no property invented beyond what `ontology.ttl` (lines 99-132, quoted in §3) actually defines.
- `mix ex4pm.lint.truth`-equivalent discipline for any status claim the generated extension's own docs make (UNKNOWN/PARTIAL_ALIVE/ALIVE/BLOCKED/BUILD_BROKEN/UNSUPPORTED/REFUSED vocabulary, not invented adjectives).

### 1.7 Success metric

A real Ash resource, compiled with `use AshEx4pm.Resource` (or the extension's real generated module name once built), performs a real create action; a real `%Ex4pm.Event{}}` is constructed via `Ex4pm.OCEL.normalize/1` and successfully reaches `Ex4pm.Stream.Ingest.ingest_envelope/2` (not the dead `ingest_batch/1` path) — verified by a real, currently-passing test asserting on the actual returned/ingested event struct, not a mock call-count assertion.

## 2. What already exists vs. what's new (the load-bearing finding)

**Already real and usable (confirmed by direct file read, this session and the `ex4pm-ocel-emission-mechanisms` report):**

- `Ex4pm.OCEL.normalize/1` (`lib/ex4pm/ocel.ex:56/77`) is the sole canonical path to `%Ex4pm.Event{}` — CONFIRMED. All other `%Ex4pm.Event{` hits in the repo are pattern-matches/consumers (`lib/ex4pm/engine/discovery/incremental.ex:5`, `lib/ex4pm/domain/projector.ex:39`, `lib/ex4pm/stream/sensor_sink.ex:4,7`), not constructors.
- `Ex4pm.Stream.Ingest.ingest_envelope/2` (`lib/ex4pm/stream/ingest.ex:19`) is real and loaded.
- `Ex4pmDomain.Extensions.SoundStateMachine` (`lib/ex4pm_domain/extensions/sound_state_machine.ex`) is a real, minimal, working `Spark.Dsl.Extension` skeleton (verifiers-only, 7 lines, `use Spark.Dsl.Extension, verifiers: [Ex4pmDomain.Verifiers.VerifySoundness]`, no `sections:`/`entities:`/`transformers:`) — CONFIRMED, and its verifier `Ex4pmDomain.Verifiers.VerifySoundness` exists at `lib/ex4pm_domain/verifiers/verify_soundness.ex`.
- `ash_r2rml`'s six-piece extension shape (`AshR2RML.Resource`, `resource.ex:59-167`) is real, complete, and the correct precedent to copy structurally — entity structs, `%Spark.Dsl.Entity{}`/`%Spark.Dsl.Section{}`, extension declaration with `sections:`/`transformers:`/`verifiers:`, `Persist` transformer with ordered `after?/1`, `Verify` verifier reading `Verifier.get_persisted/3`, `Info` module, Igniter-gated installer.
- `ash-extension-core-pack` v26.9.10 is real at `/Users/sac/ggen-marketplace/packs/ash-extension-core-pack/pack.toml` (line 3, `version = "26.9.10"`) and its properties `aex:afterTransformer`, `aex:normalizeModule`/`aex:normalizeFunction`, `aex:validateDelegateModule`/`aex:validateDelegateFunction`, `aex:legacyAdapterModule`/`aex:legacyAdapterFunction`, `aex:contextNormalize`/`aex:contextTargetEntity`/`aex:contextTargetField`, `aex:dualLevelFixture`, `aex:provenanceSource`, `aex:NestedEntity` map cleanly onto this design (quoted verbatim in §3).

**Broken/missing today (CONFIRMED bugs/gaps in `ex4pm` itself — explicit blockers, not glossed over):**

- **BLOCKER 1 — dead function call.** `Ex4pmDomain.Notifier.OcelNotifier` (`lib/ex4pm_domain/notifier/ocel_notifier.ex:34`) calls `apply(Ex4pm.Stream.Ingest, :ingest_batch, [envelope])`, gated by `function_exported?(Ex4pm.Stream.Ingest, :ingest_batch, 1)` (line 20). `Ex4pm.Stream.Ingest` defines only `ingest_envelope/2` — `ingest_batch/1` does not exist anywhere in the repo. The gate is always false; the `apply/3` branch is dead code; the notifier always falls through to a fake `{:ok, event}` at line 39 without ever ingesting anything. Any generated notifier that copies this pattern inherits a silent no-op.
- **BLOCKER 2 — middleware silent no-op.** `Ex4pmDomain.Reactors.Middlewares.OcelEventMiddleware`'s `complete/2` (line 18) and `error/2` (line 23) are no-ops; only `run_start`/`undo_start` event shapes actually emit OCEL-shaped messages; the catch-all `event(_event, _step, _context), do: :ok` (line 80) silently swallows everything else, including `run_complete`/`run_error`. Any Reactor-based emission path this extension might generate inherits missing completion/error events unless fixed upstream first.
- **BLOCKER 3 — missing builder API.** `Ex4pm.Event.new/1` does not exist; `Ex4pm.Event` (`lib/ex4pm/ocel.ex:1`) is a bare `defstruct` with zero functions. The only `Event.new` hit in the repo is the unrelated `Ex4pmDomain.Event` (`lib/ex4pm_domain/event.ex:1`, an `Ash.Resource`, different namespace entirely).
- **BLOCKER 4 — missing behaviour.** `Ex4pm.OCEL.Source` does not exist anywhere in `lib/` (`grep -rln "OCEL.Source\|defmodule Ex4pm.OCEL.Source"` returns zero hits). There is no contract to implement for "a resource is an OCEL event source" beyond calling `Ex4pm.OCEL.normalize/1` directly with a hand-built envelope map.
- **GAP — pack vocabulary, named honestly in the pack's own tracker** (`errc-tracker.md` lines 31-46): the pack's v26.9.10 properties cover wiring `Ex4pm.OCEL.normalize/1`/routing around the dead `ingest_batch` call, but the two load-bearing mechanisms this extension would ideally want — global notifier injection into an Ash resource's existing `notifiers:` list, and per-Reactor middleware injection — are **not** covered by anything the pack generates today. No `aex:globalNotifierInjection`-style property exists; `aex:workflowReactor` is the closest existing property but it is UNVERIFIED whether it supports a per-Reactor `middlewares do ... end` injection or only a single named reactor reference.

## 3. Architecture (ARD)

Convention: echo, don't synthesize — every decision below is copied from a real precedent (`ash_r2rml`'s `resource.ex`) and wired through a real, quoted `ash-extension-core-pack` v26.9.10 ontology property, not invented.

### 3.1 Decision: six-piece Spark extension shape, copied verbatim from `ash_r2rml`

Precedent: `AshR2RML.Resource` (`/Users/sac/ash_r2rml/lib/ash_r2rml/resource.ex:59-167`) — plain-struct DSL entity modules → `%Spark.Dsl.Entity{}`/`%Spark.Dsl.Section{}` module attributes → extension module (`use Spark.Dsl.Extension, sections:, transformers:, verifiers:`) → `Persist` transformer → `Verify` verifier → `Info` module, dual-gated by an Igniter-conditional installer. Rationale: this is the one real, complete, working shape found in this research; `ex4pm`'s own `SoundStateMachine` extension is real but only exercises the verifiers-only subset of this shape (no entities/sections), so it is confirmatory precedent, not a full template on its own.

### 3.2 Decision: transformer ordering via `aex:afterTransformer`

Ontology (`ontology.ttl:106-107`, quoted verbatim): *"0+ rows — a real Ash core transformer module name (e.g. \"Ash.Resource.Transformers.CachePrimaryKey\") this extension's Persist transformer must declare `after?/1` do: true for, verbatim ash_r2rml/lib/ash_r2rml/resource.ex:188-194's five after?/1 clauses (CachePrimaryKey, DefaultPrimaryKey, SetRelationshipInformation, BelongsToAttribute, BelongsToSourceAttribute)."* ash_ex4pm's `Persist` transformer sets this property to the same five module names so attribute/relationship/primary-key info is settled before OCEL envelope compilation runs.

### 3.3 Decision: normalize pipe via `aex:normalizeModule`/`aex:normalizeFunction`, targeting the real canonical constructor

Ontology (`ontology.ttl:109-112`, quoted verbatim): *"optional — module whose function (aex:normalizeFunction) the Persist transformer pipes the compiled map through before persisting, mirroring ash_r2rml's `AshR2RML.Mapping.normalize()` pipe (resource.ex:241) before `Transformer.persist(dsl, :ash_r2rml_public_mapping, mapping)` (resource.ex:243)."* ash_ex4pm sets `aex:normalizeModule = Ex4pm.OCEL`, `aex:normalizeFunction = :normalize` — the compiled DSL-entity map is piped through the real `Ex4pm.OCEL.normalize/1` (`lib/ex4pm/ocel.ex:56/77`) before persisting, satisfying FR2 without any hand-rolled `%Ex4pm.Event{}}` construction.

### 3.4 Decision: legacy/ingest-routing via `aex:legacyAdapterModule`/`aex:legacyAdapterFunction`, routing around BLOCKER 1

Ontology (`ontology.ttl:121-124`, quoted verbatim): *"optional — when set (with aex:legacyAdapterFunction), the generated Info module's result-tuple getter rescues to `Module.function(resource)` on any error, mirroring ash_r2rml's Info.mapping_result/1 (resource.ex:527-534, `rescue _ -> AshR2RML.Resource.LegacyAdapter.convert(resource)`)."* ash_ex4pm sets `aex:legacyAdapterModule = Ex4pm.Stream.Ingest`, `aex:legacyAdapterFunction = :ingest_envelope` (arity note: the property's contract is arity 1; `ingest_envelope/2` is arity 2 in the real source — this is a real arity mismatch to resolve during implementation, not glossed over) — this is the mechanism by which generated emission calls the function that actually exists instead of inheriting the dead `ingest_batch/1` call from `Ex4pmDomain.Notifier.OcelNotifier`.

### 3.5 Decision: business-rule delegation via `aex:validateDelegateModule`/`aex:validateDelegateFunction`

Ontology (`ontology.ttl:116-119`, quoted verbatim): *"optional — when set (with aex:validateDelegateFunction), the generated Verify module's compiled-present branch delegates business validation to `Module.function(compiled)` instead of the per-aex:Verifier `with`-chain, mirroring ash_r2rml's exact 2-branch shape (resource.ex:492-511)."* ash_ex4pm's `Verify` verifier fails closed (FR4) mirroring `AshR2RML.Resource.Verify.verify/1` (`resource.ex:492-511`): absent persisted mapping → `Spark.Error.DslError`; present → delegated validation.

### 3.6 Decision: resource/domain dual-level context via `aex:contextNormalize`/`aex:contextTargetEntity`/`aex:contextTargetField`

Ontology (`ontology.ttl:99-104`, quoted verbatim): *"boolean, default false — opt in to a generated resource/domain context-normalization transformer step, the ash_ai AshAi.Transformers.ResourceTools pattern ... detect resource-vs-domain via `Module.get_attribute(module, :spark_is) == Ash.Resource` ..."* and *"entity name (atom, no leading colon) whose instances carry the context-resolved field"* / *"field name (atom, no leading colon) on aex:contextTargetEntity that is positionally optional ... and gets filled in / validated by the normalization transformer."* ash_ex4pm sets `aex:contextNormalize = true` so the same DSL entity declared inside a resource's `ex4pm do ... end` block or a domain's block resolves its target-resource field automatically (satisfying FR7), the same mechanism `ash_ai`'s `AshAi.Tool` uses (`resource: {:optional, :resource}`).

### 3.7 Provenance tagging via `aex:provenanceSource` (adopted, not deferred)

Ontology (`ontology.ttl:113-114`, quoted verbatim): *"optional atom text (no colon), e.g. \"ash_first\" — when set, the compiled map gets a `metadata: %{source: :<value>}` field, mirroring ash_r2rml's metadata sub-map."* ash_ex4pm sets `aex:provenanceSource = :ash_ex4pm` so every OCEL envelope generated by this extension is distinguishable in `Ex4pm.Event.metadata` from hand-constructed or other-source events.

### 3.8 BRCE gate capability (deferred, not v1) — `Ex4pm.Evidence.BRCE`

`Ex4pm.Evidence.BRCE` is real (`lib/ex4pm/evidence/`) and is confirmed elsewhere in `ex4pm`'s own architecture docs as the sole authority permitted to invoke a state-changing callback (per `~/ex4pm/CLAUDE.md`: "Only `Ex4pm.Evidence.BRCE` may authorize a state-changing callback; a pending receipt must exist before invocation and an outcome receipt must terminate every attempted invocation"). This session did not re-verify `Ex4pm.Evidence.BRCE`'s actual API surface (no file:line citation for its public functions was produced by the research reports supplied) — UNVERIFIED whether it exposes a builder function `ash_ex4pm` could call ahead of an Ash action's `change`/`around_transaction` hook. No `ash-extension-core-pack` v26.9.10 property was found in the research that models "gate an action behind an external authority check" (closest candidates — `aex:validateDelegateModule`, `aex:afterTransformer` — model validation/ordering, not authorization). Flagged, not built: FR8 stays deferred to a post-v1 cycle pending a real read of `lib/ex4pm/evidence/brce.ex` (or equivalent) and a corresponding pack-property gap analysis.

### 3.9 Open questions / explicit blockers before implementation starts

1. **BLOCKER 1 (dead code):** `Ex4pmDomain.Notifier.OcelNotifier`'s `ingest_batch/1` call is dead — must be fixed upstream in `ex4pm` (add `ingest_batch/1`, or repoint the notifier at `ingest_envelope/2`) or routed around entirely by `ash_ex4pm`'s own `aex:legacyAdapterModule` wiring (§3.4) before generated emission can be trusted to actually reach `Ex4pm.Stream.Ingest`.
2. **BLOCKER 2 (middleware no-op):** `OcelEventMiddleware`'s missing `complete`/`error` emission means any Reactor-based emission path is incomplete until fixed upstream — out of scope for this document (§6) but a hard prerequisite for FR-parity with non-Reactor emission.
3. **BLOCKER 3/4 (missing APIs):** No `Ex4pm.Event.new/1`, no `Ex4pm.OCEL.Source` behaviour. `ash_ex4pm`'s generated code must call `Ex4pm.OCEL.normalize/1` directly with a plain envelope map (the only real constructor path) rather than a builder or behaviour callback — this constrains the DSL entity compile step (§4) to produce a map, not a struct, before normalization.
4. **Arity mismatch (§3.4):** `aex:legacyAdapterFunction`'s documented contract is arity 1; the real function it must call, `Ex4pm.Stream.Ingest.ingest_envelope/2`, is arity 2. Resolve via a wrapper function of arity 1 closing over the second argument, or confirm with the pack author whether `aex:legacyAdapterFunction` supports arity >1 — undecided, not assumed either way.
5. **Global notifier injection (pack gap, `errc-tracker.md:31-46`):** no `aex:globalNotifierInjection`-style property exists to append `ash_ex4pm`'s notifier into an `Ash.Resource`'s own pre-existing `notifiers:` list (the `AshPaperTrail.Resource.Transformers.VersionOnChange` move). Without it, resource authors must manually add the generated notifier module to their own `notifiers:` list — acceptable for v1, but not "automatic" in the way FR1-FR2's framing implies; named as a real future CREATE, not silently assumed solved.
6. **Per-Reactor middleware injection (pack gap):** whether `aex:workflowReactor` supports generating a per-Reactor `middlewares do ... end` injection is UNVERIFIED. Blocks any Reactor-based automatic emission path until checked against the pack's actual transformer-generation code (not just its ontology property description).
7. **BRCE gate feasibility (§3.8):** `Ex4pm.Evidence.BRCE`'s real public API was not re-verified this session — FR8 cannot move past DRAFT until that read happens.

## 4. DSL shape (illustrative, pending §3.9's blockers — not yet buildable as-is)

Resource-level, following the `ash_r2rml` precedent shape (`use Ash.Resource, extensions: [...]`, `resource.ex:142-166`):

```elixir
defmodule MyApp.Order do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshEx4pm.Resource]

  ex4pm do
    # DSL entity name/args/identifier TBD (per ash_r2rml's @class/@property shape,
    # resource.ex:68-102) -- not yet designed pending BLOCKER 3/4 resolution
    activity :order_created, on: :create
    activity :order_shipped, on: :update, only_when: &__MODULE__.shipped?/1
  end

  attributes do
    uuid_primary_key :id
    attribute :status, :atom
  end
end
```

Domain-level (`aex:contextNormalize`, §3.6):

```elixir
defmodule MyApp.Domain do
  use Ash.Domain,
    extensions: [AshEx4pm.Domain]

  ex4pm do
    provenance_source :ash_ex4pm  # aex:provenanceSource, §3.7
  end

  resources do
    resource MyApp.Order
  end
end
```

Both blocks compile through the same `Persist` transformer (§3.1) into a map piped through `Ex4pm.OCEL.normalize/1` (§3.3) and routed to `Ex4pm.Stream.Ingest.ingest_envelope/2` via the legacy-adapter wiring (§3.4) — not the dead `ingest_batch/1` path.

## 5. Open questions / explicit blockers

Consolidated from §2 and §3.9 — every gap the research actually found, none glossed over:

- **BLOCKER 1 — RESOLVED, 2026-09-09.** `Ex4pmDomain.Notifier.OcelNotifier` now calls the real `Ex4pm.Stream.Ingest.ingest_envelope/1` directly (the dead `function_exported?/3` guard over the nonexistent `ingest_batch/1` was removed), with the envelope's `"objects"` field correctly reshaped to a map keyed by object id. A real Chicago-style test (`test/ocel_notifier_test.exs`) asserts the event actually lands in `Ex4pm.Evidence.Store`'s real receipts, not just "did not crash." `mix test` 4/4 passing.
- **BLOCKER 2 — RESOLVED, 2026-09-09.** `OcelEventMiddleware.complete/2` and `error/2` now emit real OCEL-shaped messages (reactor identity, real result/error, real UTC timestamp), matching `run_start`/`undo_start`'s existing convention. New `run_complete`/`run_error` step-level clauses added. The catch-all now emits a distinguishable "unmodeled event" message rather than silently discarding — `Reactor.Middleware`'s real `step_event` type still lists several unmodeled shapes (`:run_retry`, `:compensate_*`, `:guard_*`, `:process_*`, `:undo_complete/error/retry`), so the catch-all itself stays warranted, not removed. New `test/ex4pm_engine/reactors/middlewares/ocel_event_middleware_test.exs`, 6/6 passing.
- BLOCKER 3: `Ex4pm.Event.new/1` does not exist. Still open — `ash_ex4pm` routes around it (calls `ingest_envelope/1` with a plain map directly, per §3.3's correction), not resolved upstream.
- BLOCKER 4: `Ex4pm.OCEL.Source` behaviour does not exist. Still open, same disposition as BLOCKER 3.
- Arity mismatch between `aex:legacyAdapterFunction`'s documented arity-1 contract and the real arity-2 `ingest_envelope/2` — moot in the shipped `ash_ex4pm` implementation, which calls `ingest_envelope/1` directly rather than through the pack's `aex:legacyAdapterModule` wiring; still a real, unresolved documentation/implementation gap in `ash-extension-core-pack` itself if another consumer relies on that property literally.
- Pack gap: no `aex:globalNotifierInjection`-equivalent property. Still open, unchanged.
- Pack gap: `aex:workflowReactor`'s per-Reactor middleware-injection support is UNVERIFIED. Still open, unchanged.
- `Ex4pm.Evidence.BRCE`'s real public API — RESOLVED, 2026-09-09: `execute/4,5` and `admit/2` confirmed real and directly usable (`lib/ex4pm/evidence.ex:222-344`). FR8 implemented for real as `AshEx4pm.Changes.BrceGate` in the shipped `~/ash_ex4pm`, with an honestly-disclosed scope limit (gates admission only, not the underlying DB write) — see that module's own moduledoc.
- Exact DSL entity names/args/identifiers for `ex4pm do ... end` are illustrative only (§4), not derived from a real completed design pass.

## 6. Explicitly out of scope for this document

- Does not scaffold the `ash_ex4pm` repo, `mix.exs`, or any generated code.
- Does not fix BLOCKER 1 or BLOCKER 2 in `ex4pm` itself — those are named prerequisites, to be resolved in `ex4pm` (or routed around per §3.4) before or during `ash_ex4pm` implementation, not by this document.
- Does not build `Ex4pm.Event.new/1` or `Ex4pm.OCEL.Source` — their absence is flagged as a blocker, not invented here.
- Does not resolve the pack's global-notifier-injection or per-Reactor-middleware-injection gaps — named as real future CREATE items per the pack's own `errc-tracker.md`.
- Does not finalize FR8 (BRCE gate) — deferred pending a real read of `Ex4pm.Evidence.BRCE`'s public API.
- Does not run `ash-extension-core-pack`'s generator against these properties — this is a spec for what that generation run would target, not the run itself.