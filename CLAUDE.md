# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ex4pm is a BEAM-native, evidence-oriented process-intelligence system (Elixir umbrella project,
OTP 27 / Elixir 1.18.4, see `.tool-versions`). It implements a governing calculus for every
state change:

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
mix test.stress              # stress benchmark suite (apps/ex4pm_engine/test/benchmarks)
mix ex4pm.lint.truth           # anti-overclaiming static lint (see ex4pm_qualification below)
mix ex4pm.powl.court             # POWL/Reactor correspondence court (baseline + generated + invalid-identity)
mix ex4pm.sabotage.court           # proves POWL correspondence sabotage/mutation is detected
mix ex4pm.crown <input> [output]     # finalize/verify the detached v26.8.22 crown receipt

# single test / one app
mix test apps/ex4pm_engine/test/some_test.exs
mix test apps/ex4pm_engine/test/some_test.exs:42
mix do --app ex4pm_engine test

# Playwright e2e (against a running server, baseURL http://127.0.0.1:30080)
npm run test:e2e
npx playwright test tests/e2e/aalst_adversarial.spec.ts
```

`mix verify` (the real gate, defined in the root `mix.exs` `aliases/0`) runs, in order:
`format --check-formatted`, `compile --warnings-as-errors`, `ex4pm.lint.truth`, `test`,
`ex4pm.powl.court`, `ex4pm.sabotage.court`. CI runs this plus the Chicago crown twice (plain
distribution, then `inet_tls` distribution) — see `docs/CHICAGO.md`.

## Umbrella architecture

Apps under `apps/`, dependency order roughly bottom-to-top:

- **`ex4pm_contracts`** — canonical RDF/Turtle ontology, SHACL shapes, WIT component-world
  contract, JSON Schema for receipts. `Ex4pm.contracts/0` hashes all four artifacts into one
  contract hash. This is the canonical public semantic surface; everything else projects from it.
- **`ex4pm_core`** — canonical observation IR (`Ex4pm.EventLog`), OCEL/XES normalization, POWL
  process-model representation, capabilities, hashing. Canonical semantic objects live here —
  never make an adapter's incidental representation canonical without an admitted equivalence
  proof.
- **`ex4pm_evidence`** — receipts, replay, receipt store, and `Ex4pm.Evidence.BRCE` (the only
  authority allowed to execute a state-changing callback).
- **`ex4pm_engine`** — the DfCM (discover-from-candidate-model) engine calculus and registry.
  Candidate engines coexist and are evidence-ranked, never silently dropped:
  - `:beam` — native deterministic Elixir (discovery/conformance/simulation);
  - `:ex4pm_plan` — pinned ex4pm-plan cloud planning worker protocol (exact source SHA +
    protocol version pinned; see README "ex4pm-plan bridge");
  - `:wasm` — real Wasmex/Wasmtime execution of admitted WASM artifacts;
  - `:nif` — configured native NIF module;
  - `:remote` — configured remote engine callback.
  An unavailable engine edge yields a typed standing/refusal, not silent disappearance.
- **`ex4pm_runtime`** — POWL planning plus receipted OTP execution; owns the Phoenix/LiveView
  app (`Ex4pm.Runtime.Application`) via `phoenix`, `phoenix_live_view`, `bandit`.
- **`ex4pm_stream`** — Broadway-based ingestion with backpressure and acknowledgement; the sink
  callback receives observations only, never ambient DO authority.
- **`ex4pm_domain`** — Ash/ETS semantic control-plane projection (datasets, process models,
  interventions, capabilities, receipt projections) plus AshAdmin. Projection is explicit via
  `Ex4pm.Domain.Projector` so persistence can't silently drift from semantic truth.
- **`ex4pm_information`** — Reactor-based information-plane app (see
  `docs/REACTOR_INFORMATION_PLANE.md`).
- **`ex4pm`** — public orchestration API (`Ex4pm.ingest/1`, `Ex4pm.discover/2`,
  `Ex4pm.conform/2`, `Ex4pm.simulate/2`, `Ex4pm.optimize/2`, `Ex4pm.plan/2`, `Ex4pm.replay/1`,
  `Ex4pm.contracts/0`). `plan/2` is analytical CONSTRUCT (explicit planner transport, receipted
  result, no ambient cloud credentials); `operate/3` requires an explicit authority map and
  crosses the BRCE boundary for every task callback.
- **`ex4pm_web`** — web surface (controllers, LiveViews, components).
- **`ex4pm_cli`** — command-line projection (`Ex4pm.Cli`), plus `mix ex4pm.gen.blueprint`.
- **`ex4pm_qualification`** — the anti-cheat/qualification suite: `ex4pm.lint.truth` (static
  anti-overclaiming lint), `ex4pm.audit.bullshit`, `ex4pm.audit.chicago`, `ex4pm.powl.court`,
  `ex4pm.sabotage.court`, `ex4pm.crown` (all defined as `Mix.Tasks.Ex4pm.*` under
  `apps/ex4pm_qualification/lib/mix/tasks/`). This app enforces that standing claims
  (ALIVE/PARTIAL_ALIVE/etc.) are backed by real executed evidence, not inspection or stubs.

Cross-cutting: `formal/` holds a Lean formalization (`Ex4pmFormal`); `qualification/` holds
reference NIF/WASM fixtures used by the qualification suite; `scripts/` has standalone
Python utilities (`emit-ocel.py`, `verify-final-crown.py`); `tests/e2e/` is the Playwright
adversarial suite (Dr. Wil van der Aalst-themed) that drives the running app — AshAdmin deep
matrix/gap audit, POWL Miner LiveView, autonomic telemetry, and live BEAM-CLI-vs-OCEL
cross-referencing specs live there.

## Testing discipline (Chicago school — enforced, not just preferred)

Real collaborators, state-based assertions; `unittest.mock`/mocking-equivalents over
collaborators this codebase owns are banned by default. `mix chicago` and
`ex4pm.audit.chicago` exist specifically to keep this honest at the OTP-distribution level
(real `peer` nodes, real Wasmtime, real Broadway backpressure — not mocked equivalents). See
`docs/CHICAGO.md` for the full non-circular-worlds model and falsifier list before touching
anything under `ex4pm_qualification` or distribution/replay code.

## ex4pm-plan / wasm4pm bridges

- The planning worker adapter (`Ex4pm.Engine.Ex4pmPlan`) is pinned to an exact upstream source
  SHA and protocol version; a response without observed capsule identity (source SHA + image
  digest, replay-verified) stays `PARTIAL_ALIVE`, and a mismatched observed source is refused.
- `Ex4pm.Engine.Wasm` only executes a configured export/parameter contract against an admitted
  WASM artifact — it does not assume a generic OCEL string ABI, and does not claim historical
  wasm4pm bundles already implement the WIT component world.

## External integration: xaas wants to depend on ex4pm (real, active)

`~/xaas` (a real sibling Elixir/Phoenix/Ash app) wants `ex4pm_core`/`ex4pm_contracts`
as a real library dependency and to push OCEL v2 events to this app's real
`POST /api/v1/ocel/events` endpoint (`ex4pm_web/lib/ex4pm_web/{router,controllers/
ocel_controller}.ex`). Full requirements: `docs/ROADMAP-xaas-integration.md` (mirrored
from `~/xaas/docs/ROADMAP.md`).

**Role split, explicit user decision:** ex4pm is the downstream library layer other
Elixir apps import (`ex4pm_core` already has a real hex-publishable shape — `package()`,
`@version`, `description` in its `mix.exs`); beam4pm is a separate runtime reached only
over the network, never as a compile-time dependency of anything outside its own repo.

**What that roadmap asks of this repo specifically**, if you're the one picking this
up:
1. Confirm `ex4pm_core` stays a stable, `path:`-dependable package — no accidental
   umbrella-only coupling that would break a sibling app depending on it directly.
2. Confirm `Ex4pm.OCEL.validate_envelope/1` (or the real, current envelope builder) is
   a genuinely public, documented function xaas can call after adding the dependency —
   not an internal implementation detail that happens to be public today.
3. `ex4pm_contracts`'s real ontology (`priv/ontology/ex4pm.ttl`) and SHACL shapes
   (`priv/shacl/ex4pm-shapes.ttl`) are meant to be ggen'd by xaas's `ggen_igniter`
   pipeline to generate xaas-side OCEL envelope code — this repo doesn't need to do
   anything for that except keep those contract files real and versioned (which
   `ex4pm_contracts`'s own moduledoc says it already does via hash manifests).

beam4pm-specific items in that roadmap are explicitly out of scope for this repo.
