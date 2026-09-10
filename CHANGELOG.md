# Changelog

All notable changes to `ex4pm` are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

**Convention going forward:** one entry per version bump (matching the
`@version` in `mix.exs` and the corresponding git tag/Hex release). Every
entry that touches the public contract — `Ex4pm.OCEL.validate_envelope/1`'s
required envelope keys, `Ex4pm.Stream.Ingest.ingest_envelope/1,2`'s options,
or `Ex4pm.Evidence.BRCE.execute/4`'s authority-map shape — must say so
explicitly in a "Public contract" subsection, including an explicit
"UNCHANGED" statement when a release does not touch it. Don't assume
silence means unchanged; state it.

## [26.9.10] - 2026-09-10

### Changed

- **Renamed forward-declared beam4pm planning service identifiers** away
  from the `ferroplan` brand name: `ex4pmb:ferroplan_hierarchical_plan` ->
  `ex4pmb:htn_plan` and `ex4pmb:ferroplan_fond_policy` -> `ex4pmb:fond_policy`
  in `priv/ontology/ex4pm.ttl`, with matching `ex4pmb:operation` and
  `ex4pmb:jsonApiType` literal renames. `ex4pmb:planningType`
  `"Hierarchical"`/`"Fond"` are unchanged (mirror the Rust `PlanningType`
  enum verbatim). The underlying beam4pm-side Rust crate keeps its real name
  `ferroplan` — only ex4pm/ash_ex4pm-side generated identifiers changed.
  Regenerated `lib/ex4pm/engine/beam4pm.ex` now exposes `:htn_plan` /
  `:fond_policy` route-table keys and `htn_plan/2` / `fond_policy/2`
  functions in place of the old `ferroplan_*` names. No deprecation alias:
  these individuals were `forward_declared` and never released under the
  old names. Both services remain `ex4pmb:status "forward_declared"` — the
  sibling beam4pm-side dispatch work landed (`htn_plan`/`fond_policy` are
  live in beam4pm's ferroplan-wasm dispatch table, GATE ENGINE DISPATCH
  32/32), but beam4pm has no `AshJsonApi`/`json_api` routing layer anywhere
  to mount a matching route, so these stay not-yet-reachable from ex4pm.

### Public contract

UNCHANGED beyond the identifier rename above — both services were
`forward_declared` (not reachable) before and after this release, so there
is no live public-contract surface being renamed out from under a caller.

## [26.9.9] - 2026-09-09

### Changed

- **Umbrella → flat library.** The multi-app umbrella (`ex4pm_core`,
  `ex4pm_contracts`, `ex4pm_evidence`, `ex4pm_engine`, `ex4pm_runtime`,
  `ex4pm_stream`, `ex4pm_domain`, `ex4pm_information`, `ex4pm_qualification`,
  `ex4pm_web`, `ex4pm_cli`, `ex4pm_manifest`, plus the `apps/` umbrella root)
  was flattened into a single hex-publishable Mix app, `:ex4pm`
  (`725f495`). All library modules (`Ex4pm.Core.*`, `Ex4pm.Evidence.*`,
  `Ex4pm.Engine.*`, `Ex4pm.Runtime.*`, `Ex4pm.Stream.*`, `Ex4pm.Domain.*`,
  `Ex4pm.Information.*`, `Ex4pm.Qualification.*`) now live under `lib/`
  in one app instead of separate umbrella apps under `apps/`. The
  Phoenix/LiveView demo app moved to `test/demo_web/` and compiles only in
  `:test`. Downstream consumers pinning `{:ex4pm, "~> 26.9"}` now get the
  whole library from a single `path:`/hex dependency — there is no more
  umbrella-only internal coupling to worry about.
- Docs and Chicago-distribution bootstrap updated to describe/start the
  flat `:ex4pm` app rather than the retired umbrella/`:ex4pm_runtime`
  (`6f35d45`, `18c6d53`, `d5bbc35`).
- Added `Ex4pm.Engine.Beam4pm`, a ggen-sync-generated zero-config Ash
  JSON:API client engine adapter, plus a real contract-validation test
  against a live `AshJsonApi` instance (`fc4bde4`, `37fc868`).
- Added `mix ex4pm.ggen.sync` and `mix ex4pm.ggen.verify_determinism` Mix
  tasks for driving and verifying the ggen code-generation pipeline used to
  produce `Ex4pm.Engine.Beam4pm` (`66f8e71`, with Chicago-style test
  coverage added in `8dad2d6`, `99b5e11`).
- Added OCEL2/OLAP core additions, discovery/conformance extensions, a
  stream sink, and a Chicago net-partition test (`9df2384`); added
  per-case ARIS-scale (0-100) conformance fitness scoring (`e1eb78a`).

### Fixed

- `OcelNotifier` now really ingests emitted events via
  `Ex4pm.Stream.Ingest.ingest_envelope/1` instead of a no-op path
  (`1bcc81f`).
- Reactor completion/error paths now emit real OCEL events instead of
  no-ops (`4893278`).
- `Ex4pm.OCEL` now handles OCEL 2.0's list-of-`{name,value}`-pairs shape
  for an event's/object's explicit `"attributes"` sub-key, in addition to
  the plain-map shape — fixes an unhandled `BadMapError` on ingesting
  fixtures using the list shape, and a double-nesting bug on the
  object-side attribute extraction (`7fd2bd1`).
- Derived OCEL flakiness thresholds from real live file state instead of
  stale hardcoded numbers (`e5d22a0`).

### Public contract

**UNCHANGED in this release**, confirmed against `git log` for each file:

- `Ex4pm.OCEL.validate_envelope/1` (`lib/ex4pm/ocel.ex`) — required
  envelope keys (`schema`, `producer` map, integer `sequence`, `events`
  list/map) are unchanged; the only change to this file since the last
  release (`7fd2bd1`) is unrelated attribute-normalization logic for
  individual events/objects, not the envelope-validation function or its
  required keys.
- `Ex4pm.Stream.Ingest.ingest_envelope/1,2` (`lib/ex4pm/stream/ingest.ex`)
  — unchanged since the umbrella-flattening commit (`725f495`), which
  moved the module but did not alter its signature or options.
- `Ex4pm.Evidence.BRCE.execute/4` (`lib/ex4pm/evidence.ex`, defined as
  `execute/5` with a defaulted `opts \\ []`, called as arity 4 in the
  documented authority-gated-callback contract) — unchanged since the
  umbrella-flattening commit (`725f495`); no commit since has touched
  `lib/ex4pm/evidence.ex`.

## Earlier history

Tags `v26.8.27` and `v26.8.28` exist in git history predating this file's
introduction. No changelog entries were written for them retroactively —
this file starts recording from `26.9.9` forward, per the convention above.
