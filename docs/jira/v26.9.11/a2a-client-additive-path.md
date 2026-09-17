# Additive A2A.Client path alongside existing route-table client

## Summary

Adds `Ex4pm.Engine.Beam4pmA2A`, a new real `A2A.Client`-based path to beam4pm's
newly-mounted A2A agent (`BeamPM.A2AAgent` at `/a2a`), targeting the same two
curated skills already exposed as `ash_ai` tools on the beam4pm side:
`read_ocel_events` (`BeamPM.Ash.Resources.OcelEvent`, `:read`) and
`read_conformance_results` (`BeamPM.Ash.Resources.ConformanceResult`, `:read`).

This is purely additive: `Ex4pm.Engine.Beam4pm` (the existing hand-rolled
AshJsonApi route-table client) is untouched, not deprecated, and no existing
caller is migrated onto the new path. Which path ex4pm prefers for which calls
remains an open, later decision.

## Status

Done - already merged/committed.

## Commits

- `9c6d950` feat(engine): additive A2A.Client path to beam4pm, alongside existing route-table client

## Changes

- Added `Ex4pm.Engine.Beam4pmA2A`, a new client module using `A2A.Client` to
  call beam4pm's `/a2a` A2A agent mount (`BeamPM.A2AAgent`).
- Added client-side dependency `{:a2a, "~> 0.2"}`. Confirmed via
  `/Users/sac/ash_a2a`'s own `deps/mix.exs` that `A2A.Client` lives in the
  `:a2a` package itself, while `:ash_a2a` is the server-side Spark DSL
  extension beam4pm uses (not needed client-side here). `{:req, "~> 0.5"}`
  was already a dependency.
- Left `Ex4pm.Engine.Beam4pm` (the existing AshJsonApi route-table client)
  fully untouched — no deprecation, no caller migration.
- Added real Chicago-style test coverage:
  - `test/engine_beam4pm_a2a_test.exs`
  - `test/support/micro_beam4pm_a2a.ex` — a real `A2A.Agent` GenServer
    fixture (same `MicroBeam4pm` convention as the existing AshJsonApi
    fixture), served over a real Bandit + `A2A.Plug` + `Plug.Router`
    mirroring beam4pm's real `/a2a` mount shape.
  - Tests exercise real `A2A.Client.discover/2` and `send_message/3` calls
    over the full real JSON-RPC round trip — no mocks.

## Verification

Per the commit message:

- `mix compile --warnings-as-errors`: exit 0, zero warnings.
- `mix test test/engine_beam4pm_a2a_test.exs`: 9 tests, 0 failures.
- `mix test test/engine_beam4pm_test.exs` (existing route-table client):
  13 tests, 0 failures — completely unaffected.
- `mix test` (full suite): 551 tests, 88 failures, all pre-existing
  "wasm artifact not built" environment-gap failures in
  `Ex4pmEngine.Wasm.*`/`WasmAllCapabilitiesTest`, none touching
  `Beam4pm`/`Beam4pmA2A`/`Engine.*`.

## Related

None stated — no PR numbers or branch names are mentioned in the commit
subject or body.
