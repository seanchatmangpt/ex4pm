> Mirrored from ~/xaas/docs/ROADMAP.md (2026-09-09) -- this file is a copy, not
> the source of truth; re-sync from ~/xaas/docs/ROADMAP.md if xaas's own copy has
> since changed.
>
> This is the CONSUMER-side spec: xaas is a real sibling Elixir/Phoenix/Ash app
> that wants to depend on ex4pm as a real library and push OCEL v2 events to an
> ex4pm ingest endpoint. Work items below are for THIS repo (ex4pm) to make true
> from its own side -- e.g. confirming ex4pm stays a stable, path-dependable
> package, and that ggen manufacturing of xaas's OCEL envelope code from
> ex4pm's real ontology (priv/ontology/ex4pm.ttl, priv/shacl/ex4pm-shapes.ttl)
> actually produces a working xaas-side module.

---

# Roadmap — What xaas Needs From ex4pm

## Role split

**ex4pm = downstream Elixir library layer.** `ex4pm` is something xaas *imports*. It is
a real, hex-packaged library (`mix.exs` has `package()`, `@version`, `description`;
ex4pm is a single flat library, not an umbrella) providing the canonical OCEL/XES/POWL
data structs and validation (`Ex4pm.Core.*`) xaas's own code should depend on directly
rather than re-implementing from read documentation. `Ex4pm.Contracts`'s real ontology
(`priv/ontology/ex4pm.ttl`) and SHACL shapes (`priv/shacl/ex4pm-shapes.ttl`) are what
`ggen_igniter` should generate xaas's OCEL envelope code from. **Rule: `ex4pm` may appear
as a real `path:`/hex dependency in xaas's `mix.exs`.**

## Why this exists

The user's stated goal: xaas's MCP (`/mcp`) and A2A (`/a2a`) actions should emit real
OCEL v2 events that reach ex4pm's process-intelligence loop via xaas's existing Ash
OpenTelemetry integration.

## What xaas needs from ex4pm

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
