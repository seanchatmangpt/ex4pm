# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ex4pm is a BEAM-native, evidence-oriented process-intelligence system: a single, flat,
hex-publishable Mix library (app `:ex4pm`, OTP 27 / Elixir 1.18.4, see `.tool-versions`). All
library code lives under `lib/`, namespaced by concern (`Ex4pm.Core`, `Ex4pm.Engine`,
`Ex4pm.Evidence`, `Ex4pm.Runtime`, `Ex4pm.Domain`, `Ex4pm.Information`, `Ex4pm.Stream`,
`Ex4pm.Qualification`); the Phoenix/LiveView demo web app lives outside the published library
under `test/demo_web/`. It implements a governing calculus for every state change:

```
observation -> parse -> route -> admit | refuse -> construct -> BRCE -> DO -> receipt -> replay -> bounded standing
```

`SELECT`, `CONSTRUCT`, and `DO` are separate authority domains. Only `Ex4pm.Evidence.BRCE` may
authorize a state-changing callback; a pending receipt must exist before invocation and an
outcome receipt must terminate every attempted invocation. See `AGENTS.md` and
`docs/ARCHITECTURE.md` for the full contract.

Evidence/standing vocabulary used throughout code, tests, and docs — use it precisely, don't
invent synonyms: `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN | UNSUPPORTED` and
typed `REFUSED`. Inspection is not execution; a configured adapter is not an executed adapter; a
receipt-shaped map is not a replay-verified receipt.

## Commands

```bash
mix deps.get              # fetch deps (run once / after mix.lock changes)
mix verify                 # full repo-wide gate — run this before claiming anything is done
mix chicago                 # only tests tagged :chicago, deterministic seed 0 (OTP distribution qualification)
mix test.stress              # stress benchmark suite (test/benchmarks)
mix ex4pm.lint.truth           # anti-overclaiming static lint (see Ex4pm.Qualification below)
mix ex4pm.powl.court             # POWL/Reactor correspondence court (baseline + generated + invalid-identity)
mix ex4pm.sabotage.court           # proves POWL correspondence sabotage/mutation is detected
mix ex4pm.crown <input> [output]     # finalize/verify the detached v26.8.22 crown receipt

# single test
mix test test/ex4pm_engine/some_test.exs
mix test test/ex4pm_engine/some_test.exs:42

# Playwright e2e (against a running server, baseURL http://127.0.0.1:30080)
npm run test:e2e
npx playwright test tests/e2e/aalst_adversarial.spec.ts
```

`mix verify` (the real gate, defined in the root `mix.exs` `aliases/0`) runs, in order:
`format --check-formatted`, `compile --warnings-as-errors`, `ex4pm.lint.truth`, `test`,
`ex4pm.powl.court`, `ex4pm.sabotage.court`. CI runs this plus the Chicago crown twice (plain
distribution, then `inet_tls` distribution) — see `docs/CHICAGO.md`.

## Flat library architecture

One Mix app (`:ex4pm`). All library code lives under `lib/ex4pm/`, organized into namespaced
directories rather than separate OTP apps — each directory below is a logical module grouping,
not a compile boundary:

- **`lib/ex4pm/contracts.ex`** — canonical RDF/Turtle ontology, SHACL shapes, WIT component-world
  contract, JSON Schema for receipts. `Ex4pm.contracts/0` hashes all four artifacts into one
  contract hash. This is the canonical public semantic surface; everything else projects from it.
- **`lib/ex4pm/core/`** — canonical observation IR (`Ex4pm.EventLog`), OCEL/XES normalization, POWL
  process-model representation, capabilities, hashing. Canonical semantic objects live here —
  never make an adapter's incidental representation canonical without an admitted equivalence
  proof.
- **`lib/ex4pm/evidence/`** — receipts, replay, receipt store, and `Ex4pm.Evidence.BRCE` (the only
  authority allowed to execute a state-changing callback).
- **`lib/ex4pm/engine/`** — the DfCM (discover-from-candidate-model) engine calculus and registry.
  Candidate engines coexist and are evidence-ranked, never silently dropped:
  - `:beam` — native deterministic Elixir (discovery/conformance/simulation);
  - `:ex4pm_plan` — pinned ex4pm-plan cloud planning worker protocol (exact source SHA +
    protocol version pinned; see README "ex4pm-plan bridge");
  - `:wasm` — real Wasmex/Wasmtime execution of admitted WASM artifacts;
  - `:nif` — configured native NIF module;
  - `:remote` — configured remote engine callback.
  An unavailable engine edge yields a typed standing/refusal, not silent disappearance.
- **`lib/ex4pm/runtime/`** — POWL planning plus receipted OTP execution (`Ex4pm.Runtime.Application`).
- **`lib/ex4pm/stream/`** — Broadway-based ingestion with backpressure and acknowledgement; the sink
  callback receives observations only, never ambient DO authority.
- **`lib/ex4pm/domain/`** — Ash/ETS semantic control-plane projection (datasets, process models,
  interventions, capabilities, receipt projections) plus AshAdmin. Projection is explicit via
  `Ex4pm.Domain.Projector` so persistence can't silently drift from semantic truth.
- **`lib/ex4pm/information/`** — Reactor-based information-plane module namespace (see
  `docs/REACTOR_INFORMATION_PLANE.md`).
- **`lib/ex4pm.ex`** — public orchestration API (`Ex4pm.ingest/1`, `Ex4pm.discover/2`,
  `Ex4pm.conform/2`, `Ex4pm.simulate/2`, `Ex4pm.optimize/2`, `Ex4pm.plan/2`, `Ex4pm.replay/1`,
  `Ex4pm.contracts/0`). `plan/2` is analytical CONSTRUCT (explicit planner transport, receipted
  result, no ambient cloud credentials); `operate/3` requires an explicit authority map and
  crosses the BRCE boundary for every task callback.
- **`lib/ex4pm/cli.ex`** — command-line projection (`Ex4pm.Cli`), plus `mix ex4pm.gen.blueprint`.
- **`lib/ex4pm/qualification/`** — the anti-cheat/qualification suite: `ex4pm.lint.truth` (static
  anti-overclaiming lint), `ex4pm.audit.bullshit`, `ex4pm.audit.chicago`, `ex4pm.powl.court`,
  `ex4pm.sabotage.court`, `ex4pm.crown` (all defined as `Mix.Tasks.Ex4pm.*` under
  `lib/mix/tasks/`). This module namespace enforces that standing claims
  (ALIVE/PARTIAL_ALIVE/etc.) are backed by real executed evidence, not inspection or stubs.

The Phoenix/LiveView demo web app (controllers, LiveViews, components, router) is not part of
the published library — it lives under `test/demo_web/lib/ex4pm_web/` and is compiled only in
`:test` (see `elixirc_paths/1` in the root `mix.exs`).

Cross-cutting: `formal/` holds a Lean formalization (`Ex4pmFormal`); `qualification/` holds
reference NIF/WASM fixtures used by the qualification suite; `scripts/` has standalone
Python utilities (`emit-ocel.py`, `verify-final-crown.py`); `tests/e2e/` is the Playwright
adversarial suite (Dr. Wil van der Aalst-themed) that drives the running demo app — AshAdmin
deep matrix/gap audit, POWL Miner LiveView, autonomic telemetry, and live BEAM-CLI-vs-OCEL
cross-referencing specs live there.

## Testing discipline (Chicago school — enforced, not just preferred)

Real collaborators, state-based assertions; `unittest.mock`/mocking-equivalents over
collaborators this codebase owns are banned by default. `mix chicago` and
`ex4pm.audit.chicago` exist specifically to keep this honest at the OTP-distribution level
(real `peer` nodes, real Wasmtime, real Broadway backpressure — not mocked equivalents). See
`docs/CHICAGO.md` for the full non-circular-worlds model and falsifier list before touching
anything under `lib/ex4pm/qualification/` or distribution/replay code.

## ex4pm-plan / wasm4pm bridges

- The planning worker adapter (`Ex4pm.Engine.Ex4pmPlan`) is pinned to an exact upstream source
  SHA and protocol version; a response without observed capsule identity (source SHA + image
  digest, replay-verified) stays `PARTIAL_ALIVE`, and a mismatched observed source is refused.
- `Ex4pm.Engine.Wasm` only executes a configured export/parameter contract against an admitted
  WASM artifact — it does not assume a generic OCEL string ABI, and does not claim historical
  wasm4pm bundles already implement the WIT component world.

## External integration: xaas wants to depend on ex4pm (real, active)

`~/xaas` (a real sibling Elixir/Phoenix/Ash app) wants `ex4pm` (for the `Ex4pm.Core`/
`Ex4pm.Contracts` namespaces) as a real library dependency and to push OCEL v2 events to this
app's real `POST /api/v1/ocel/events` endpoint (`test/demo_web/lib/ex4pm_web/{router,
controllers/ocel_controller}.ex`). Full requirements: `docs/ROADMAP-xaas-integration.md`
(mirrored from `~/xaas/docs/ROADMAP.md`).

**Role split, explicit user decision (2026-09-09):** ex4pm is the downstream library
layer other Elixir apps import — now that ex4pm is a single flat library (no more separate
`ex4pm_core`/`ex4pm_contracts` umbrella apps), the whole `:ex4pm` package is what a real
`path:`/hex dependency in xaas's `mix.exs` would point at (`ex4pm`'s root `mix.exs` already
has a real hex-publishable shape: `package()`, `@version`, `description`). There is no
umbrella-only coupling left to worry about — `Ex4pm.Core.*`/`Ex4pm.Contracts` are ordinary
modules inside the one published app.
beam4pm is a separate runtime (the actual execution substrate — Rust rf1-rf4 oracles,
whatever receipt/actuation machinery survives its current merge) reached only over the
network (HTTP/PubSub), never as a compile-time dependency of anything outside its own
repo — xaas has no business knowing beam4pm's internal module names.

**Status per the roadmap, as of 2026-09-09: beam4pm is BLOCKED (external)** — `~/beam4pm`
has an in-progress, uncommitted git merge; nothing in the roadmap is actionable against
beam4pm until that resolves, and the roadmap's own explicit resume trigger says not to
touch it again until the user confirms that merge is committed. **ex4pm is NOT
blocked** — the three items below can proceed independently of beam4pm's state.

**What that roadmap asks of this repo specifically**, if you're the one picking this
up:
1. Confirm `ex4pm` stays a stable, `path:`-dependable package — flattening to one app
   removed the umbrella-only coupling risk (no separate `ex4pm_core` app to accidentally
   depend on internals of); a sibling app depending on `:ex4pm` directly now gets the
   whole library, so keep the public surface (`Ex4pm.*`, `Ex4pm.Core.*`, `Ex4pm.Contracts`)
   deliberately curated.
2. Confirm `Ex4pm.OCEL.validate_envelope/1` (or the real, current envelope builder) is
   a genuinely public, documented function xaas can call after adding the dependency —
   not an internal implementation detail that happens to be public today.
3. `Ex4pm.Contracts`'s real ontology (`priv/ontology/ex4pm.ttl`) and SHACL shapes
   (`priv/shacl/ex4pm-shapes.ttl`) are meant to be ggen'd by xaas's `ggen_igniter`
   pipeline to generate xaas-side OCEL envelope code — this repo doesn't need to do
   anything for that except keep those contract files real and versioned (which
   `Ex4pm.Contracts`'s own moduledoc says it already does via hash manifests). The
   consuming side of this (adding the `path:` dependency, wiring `ggen_igniter`,
   generating the envelope builder to replace xaas's hand-written
   `Xaas.Telemetry.OcelForwarder`) lives in `~/xaas`, not here — see `~/xaas/CLAUDE.md`
   and `~/xaas/docs/ROADMAP.md` for that side's own doctrine and non-negotiable
   discipline (Chicago-style testing, Ash policy floor, BRCE-gated DO, no-overclaiming).
4. `POST /api/v1/ocel/events` → `Ex4pmWeb.OcelController.ingest/2`
   (`test/demo_web/lib/ex4pm_web/{router,controllers/ocel_controller}.ex`) stays the
   real network seam xaas reaches at runtime — confirmed present as of this note.
   Adding `ex4pm` as xaas's compile-time dependency (item 1) is for shared types
   and validation only; it does not change xaas calling this endpoint over HTTP rather
   than in-process.

beam4pm-specific items in that roadmap are explicitly out of scope for this repo, and
are BLOCKED per the status above regardless.
