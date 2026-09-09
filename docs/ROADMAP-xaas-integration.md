> Mirrored from ~/xaas/docs/ROADMAP.md (2026-09-09) -- this file is a copy, not
> the source of truth; the "Status" line below (originally "beam4pm is BLOCKED
> (external)" with an in-progress uncommitted merge) is stale as of a fresh
> read-only re-verification run from ex4pm later the same session (2026-09-09):
> beam4pm's merge IS now committed (HEAD 55fb539794f5592c94cdc7089bbc0eb0d0680666,
> "merge main into PR43 for merge verification", 2026-09-09 01:48:59 -0700, tree
> clean) -- but neither concrete xaas-blocking gap changed: gap #1 (RF3 OCEL
> oracle still needs an external Rust binary path, no priv/ bundling, still
> fixture-bound to `~/wasm4pm/fixtures/negative/`) and gap #2 (no HTTP/PubSub
> event-ingestion endpoint -- repo-wide grep for Plug/Phoenix/Bandit/cowboy in
> beam4pm's lib/ and mix.exs returned zero matches) are both confirmed STILL
> TRUE. beam4pm's own mix.exs also still has no package()/hex-publishable shape
> (app: :beam4pm, version: "0.1.0", no description/licenses/links). This
> addendum does not edit the mirrored body below -- that stays as xaas's own
> doc read it; re-sync from ~/xaas/docs/ROADMAP.md if xaas's own copy has since
> been updated to reflect the merge.
>
> This is the CONSUMER-side
> spec: xaas is a real sibling Elixir/Phoenix/Ash app that wants to depend on
> ex4pm_core/ex4pm_contracts as a real library and push OCEL v2 events to an
> ex4pm ingest endpoint. As of this addendum's re-verification, no such endpoint
> ships under this repo's lib/ — see item #3 under "What xaas needs from ex4pm"
> below for the confirmed gap. Work items below marked
> "unblocked / actionable now" are for THIS repo (ex4pm) to make true from its
> own side -- e.g. confirming ex4pm_core stays a stable, path-dependable
> package, and that ggen manufacturing of xaas's OCEL envelope code from
> ex4pm_contracts's real ontology (priv/ontology/ex4pm.ttl, priv/shacl/
> ex4pm-shapes.ttl) actually produces a working xaas-side module. beam4pm items
> are out of scope for ex4pm -- do not act on those from here.

---

# Roadmap — What xaas Needs From beam4pm and ex4pm

## Role split (explicit user decision, 2026-09-09)

**ex4pm = downstream Elixir library layer. beam4pm = the runtime.** This governs every
integration decision below:

- **ex4pm** is something xaas *imports*. `ex4pm` is a real, hex-packaged library
  (`mix.exs` has `package()`, `@version`, `description` — confirmed; ex4pm is now a
  single flat library, not an umbrella, so there is no umbrella-internal-only coupling
  to worry about) providing the canonical OCEL/XES/POWL data structs and validation
  (`Ex4pm.Core.*`) xaas's own code should depend on directly rather than re-implementing
  from read documentation. `Ex4pm.Contracts`'s real ontology (`priv/ontology/ex4pm.ttl`)
  and SHACL shapes (`priv/shacl/ex4pm-shapes.ttl`) are what `ggen_igniter` should
  generate xaas's OCEL envelope code from. **Rule: `ex4pm` may appear as a real
  `path:`/hex dependency in xaas's `mix.exs`. beam4pm never does.**
- **beam4pm** is something xaas's events flow *into* at runtime — the actual execution
  substrate (the Rust rf1-rf4 oracles, whatever receipt/actuation machinery survives
  its current merge) — reached over the network (HTTP/PubSub), never imported as a
  compile-time dependency. xaas has no business knowing beam4pm's internal module
  names; it only needs a stable network seam, which is real work still to confirm
  post-merge (see "What's needed" below).

Status: **beam4pm is BLOCKED (external)**. `~/beam4pm` has an in-progress, uncommitted
git merge (`Merge remote-tracking branch 'origin/main' into local/session-integration`)
as of 2026-09-09. Nothing here is actionable against beam4pm until that resolves.
**ex4pm is NOT blocked** — the library-dependency work (below) can proceed now.

## Why this exists

The user's stated goal: xaas's MCP (`/mcp`) and A2A (`/a2a`) actions should emit real
OCEL v2 events, and beam4pm should subscribe to that stream via xaas's existing Ash
OpenTelemetry integration — closing the "process intelligence loop" end to end. This
doc is the real, cited gap list an earlier research pass (`xaas-beam4pm-ex4pm-
integration` workflow) found between beam4pm's *actual current* capability and what
that loop needs — so the next pass that touches beam4pm has a concrete spec instead of
re-researching from zero.

## What beam4pm actually has today (as last observed, real, cited)

- `lib/beam4pm_discovery.ex` (`BeamPM.Discovery`) — pure-Elixir, GENERATED, DFG
  discovery + conformance + variant grouping over generated `BeamPM.Types` structs.
  This is the real production path, not a Rust call.
- `native/rf1-dfg-oracle/`, `rf2-conformance-oracle/`, `rf3-ocel-oracle/`,
  `rf4-oc-discovery-oracle/` — four real Rust subprocess oracles wrapping the
  `process_mining` crate (v0.6.2) directly, used as ground-truth falsifiers to check
  `BeamPM.Discovery`'s Elixir implementation against, not as a general-purpose runtime
  OCEL codec.
- `lib/beam4pm_ash_domain.ex` — a real Ash domain projection over the generated types.
- **Real, confirmed gap**: the RF3 OCEL oracle (`beam4pm_rf3_ocel.ex`, when present) is
  not hex-packaged, requires an externally-built Rust binary path with no `priv/`
  bundling step, and is fixture-bound to file paths in a sibling repo
  (`/Users/sac/wasm4pm/fixtures/negative/`). **Not usable as a path/hex dependency as
  currently structured.**
- beam4pm's file set is observed to be volatile — a set of modules present in one
  research pass (`beam4pm_rf1_dfg.ex`, `receipt_chain.ex`, `actuation.ex`,
  `process_governor.ex`, the `pro_*` family, `revenue_*`) was **absent** roughly an hour
  later in the same session, consistent with active manufacturing/merge churn, not a
  stable API surface to build against yet.

## What xaas needs, concretely (FMEA-shaped: each gap named with real severity/detection)

1. **A stable, hex-or-path-consumable OCEL v2 encode/decode API.**
   - Gap: today, real OCEL 2.0 encode/decode only exists inside the RF3 Rust oracle,
     reachable via two fixed wire ops (`ocel_stats`, `ocel_build_slim`), not a general
     `encode/1`/`decode/1` pair.
   - Severity: blocks the entire loop — without this, xaas cannot emit real OCEL v2 at
     all without re-implementing an encoder itself (which would duplicate beam4pm's
     capability, the exact thing this integration is meant to avoid).
   - What's needed: either (a) beam4pm exposes `BeamPM.RF3Ocel.Oracle` as a real,
     documented, `priv/`-bundled binary + a general encode/decode function pair, not
     just the five fixed falsifier scenarios, or (b) a new, narrower beam4pm module
     that wraps the same Rust oracle for a generic "encode this event list as OCEL v2
     JSON" call xaas can invoke per MCP/A2A action.

2. **A real event-ingestion endpoint or subscription API beam4pm can offer xaas.**
   - Gap: not yet confirmed to exist (research on `ex4pm_stream`/`ex4pm_web` was
     in-flight when beam4pm's merge state was discovered; do not assume a webhook/
     PubSub endpoint exists until re-verified against the post-merge tree).
   - What's needed: a real HTTP or PubSub subscription point beam4pm listens on, so
     xaas's `Xaas.Telemetry.OcelAshEmitter` (or a new MCP/A2A-scoped emitter) can push
     events without beam4pm having to poll xaas.

3. **A stable module surface to build xaas's own emitter against.**
   - Gap: the volatility observed above means committing to specific beam4pm module
     names/functions right now would likely break within the session. Do not wire
     xaas's emitter against `beam4pm_rf1_dfg.ex`/`receipt_chain.ex`/etc. by name until
     their presence and shape are re-confirmed post-merge.
   - What's needed: either a tagged/released beam4pm commit xaas can pin a path
     dependency to, or confirmation the merge has landed and the module set is stable.

## Explicitly NOT needed from beam4pm

- Billing/entitlement/tenancy integration — a prior research pass confirmed
  `beam4pm_billing.ex`/`entitlement.ex`/`pro_tenancy.ex` solve a different problem
  (licensing beam4pm itself) than xaas's own `Xaas.Billing`/`Ledger`/`Accounts`
  domains. Do not merge these.
- A rewrite of `BeamPM.Discovery`'s pure-Elixir DFG/conformance algorithms — that's a
  real, working, already-correct implementation; xaas needs an event *pipe* into the
  process-intelligence loop, not a reimplementation of the discovery math.

## What xaas needs from ex4pm (unblocked — real, actionable now)

1. **Real path dependency, not read-and-copy.** `Xaas.Telemetry.OcelForwarder`
   (`lib/xaas/telemetry/ocel_forwarder.ex`, built this session) currently hand-builds
   and hand-documents the envelope shape by reading `Ex4pm.Core`'s source — a
   duplicated, driftable understanding of a real dependency. Fix: add
   `{:ex4pm, path: "../ex4pm"}` to `mix.exs`, call
   `Ex4pm.OCEL.validate_envelope/1` (or its real builder function) directly before
   POSTing, so a future ex4pm contract change fails xaas's own compile/test instead of
   silently drifting apart.
2. **ggen_igniter against `Ex4pm.Contracts`'s real ontology, not LLM handwriting.**
   `Ex4pm.Contracts` holds a real, hashed, versioned RDF ontology
   (`priv/ontology/ex4pm.ttl`) and SHACL shapes (`priv/shacl/ex4pm-shapes.ttl`) —
   exactly the input shape `xaas_library_pack`'s own ggen pipeline already consumes for
   `Xaas.Library`. `OcelForwarder` should have been generated from this ontology, not
   hand-written. Point `ggen_igniter` at it and regenerate the envelope
   builder/validator; keep the hand-written version only until the generated one is
   proven to pass the same real test (`test/xaas/telemetry/ocel_forwarder_test.exs`),
   then retire the hand-written one.
3. **No real production HTTP ingest endpoint exists yet — this is a gap, not a
   confirmed seam.** In the current flattened-library tree there is no `Ex4pmWeb`,
   `router.ex`, or `OcelController` anywhere under `lib/`. A `POST /api/v1/ocel/events`
   → `OcelController.ingest/2` route exists only under `test/demo_web/` (a Phoenix
   demo/test harness used for e2e testing, not shipped library code) —
   `test/demo_web/lib/ex4pm_web/router.ex` and
   `test/demo_web/lib/ex4pm_web/controllers/ocel_controller.ex`. Before xaas can push
   events to ex4pm over HTTP, either a real `ex4pm_web`-equivalent app needs to ship
   under `lib/` in this repo, or xaas needs a different network seam (a Phoenix
   endpoint xaas hosts itself that calls `Ex4pm.OCEL.validate_envelope/1` in-process via
   the path dependency from item 1, rather than POSTing to ex4pm). Item 1's path
   dependency does not depend on this gap closing — it only requires `Ex4pm.Core`/
   `Ex4pm.OCEL` functions, which are real and callable today.

## Sequencing (HDDL-shaped — see `docs/hddl/`)

This is a `(CLOSE-FMEA-GAP mcp-a2a-ocel-emission)`-style compound task once beam4pm is
unblocked, composing:

1. `find-gap` — DONE (this doc; re-verify against post-merge beam4pm before trusting).
2. `identify-write-convention` — re-run against beam4pm's real OCEL/event-write pattern
   once the merge lands (not yet done; the pre-merge pattern may not survive it).
3. `design-grant-resource` → in this context, "design the real integration seam"
   (a new thin beam4pm module, or a hex release, or a shared contract package).
4–7 (`build`/`bind`/`wire-audit`/`prove-avatars`): unchanged shape from
   `docs/hddl/actor-binding-fix.hddl`, re-instantiated with `?s` = "MCP+A2A OCEL
   emission" once 1–3 are re-confirmed live.

## Explicit trigger to resume

Resume this work only after the user confirms beam4pm's merge is committed/resolved.
Re-run step 1 (re-verify beam4pm's real current module set) before touching anything
— per this doc's own observed volatility finding, do not trust this doc's own module
citations without a fresh read.
