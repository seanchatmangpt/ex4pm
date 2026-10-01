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

## [Unreleased]

### Changed
- `Ex4pmEngine.Wasm.RealTransport` now admits the WASM artifact through
  `Ex4pmEngine.Wasm.Admission` before instantiation: sha256 digest pin
  (`priv/wasm4pm/MANIFEST.json`, pinned to the zero-import build), an import
  allowlist (empty: the artifact may import nothing), required-export check,
  and typed `%Ex4pm.Refusal{}` errors with request/response size caps. The
  87 `__wbindgen_*` stub imports are gone (artifact now has 0 imports).
- `RealTransport.algo_specs/0` delegates to the GENERATED
  `Ex4pmEngine.Wasm.AlgoRegistry` (33 algorithms), generated from
  `priv/ontology/ex4pm.ttl` plus the vendored
  `ex4pm-wasm4pm-bindings-pack` 0.1.2 (`priv/ggen/vendor/`, hash-locked).
  The 19 Phase 1-3 leaf adapters are byte-identical to the pack's render.
- `mix ex4pm.engine.gen.adapter` is now a thin wrapper over `ggen sync run`
  in `ggen/bindings/` with typed refusals.

### Added
- `scripts/falsify-wasm-e2e.sh` / `mix falsify.wasm` (typed exit codes),
  `test/wasm/pack_drift_test.exs`, `EX4PM_WASM_REQUIRED` / `EX4PM_WASM_ARTIFACT`
  / `EX4PM_WASM_SHA256` for real-artifact tests.
- `docs/ALGORITHM-REGISTRY-GENERATION.md`.

### Public contract
UNCHANGED (`Ex4pm.OCEL.validate_envelope/1`, `Ex4pm.Stream.Ingest.ingest_envelope/1,2`,
`Ex4pm.Evidence.BRCE.execute/4`). `RealTransport.start/1,2` and `call/replay`
now return `%Ex4pm.Refusal{}` errors where they previously returned bare
error terms (WASM transport surface only).

## [26.9.30] - 2026-09-30

Version bump 26.9.24 -> 26.9.30 for Hex dry-run publish readiness; package `files`
now includes README.md, CHANGELOG.md and LICENSE. Contents of the former Unreleased
section ship in this release.

### Public contract

UNCHANGED by the version bump itself (see entries below for contract notes).

### Added

- **`Ex4pm.Aloop` module added (`64c157d`).** Independent online process intelligence
  over ALOOP OCEL 2.0 event logs: ingest/episode segmentation, loop-depth/recurrence,
  human causal edges, provider replacement with substitution-equivalence verdicts,
  orphan-DO and unconsumed-receipt detection, DFG/variants/precision, conformance
  divergences, repair/replan chains, and a deterministic JSON-encodable
  `analysis_receipt/1`.

### Changed

- **Duplicate ingestion envelopes are now short-circuited, not re-ingested.**
  `Ex4pm.Stream.Ingest.ingest_envelope/1,2` detects a re-submitted envelope by its
  normalized subject content hash (`log.subject.hash`, deterministic and invariant
  across retries) and returns `{:ok, %{status: :duplicate_ignored, ...,
  original_receipt_hash: h}}` — no second OCEL event, no second receipt, no
  `Ex4pm.Engine.OnlineMiner` forward. The `sequence` check is now a pure validation
  check (`check_sequence/1`); it no longer carries idempotency semantics
  (`8f5d524`).
- **`Ex4pm.ObjectRef.attributes` is a real OCEL 2.0 value-time log, not a snapshot.**
  `%{name => [%{value: v, time: t}, ...]}`, one entry per admitted `{value, time}`
  pair, `nil`-time entries first and ascending by `time`; OCEL 2.0 list-shape
  repeated attribute names append entries rather than last-one-wins. New
  `Ex4pm.ObjectRef.attribute_at/3` resolves a value as of a timestamp (`59501af`).

### Public contract

- `Ex4pm.Stream.Ingest.ingest_envelope/1,2` (`lib/ex4pm/stream/ingest.ex`) —
  **CHANGED** (`8f5d524`): signature and options unchanged, but the success result
  on the duplicate path is now `{:ok, %{status: :duplicate_ignored, subject_hash:
  <hash>, event_count: <n>, object_count: <n>, sequence: <n>, agent_id: <id>,
  run_id: <id>, original_receipt_hash: <hash>}}` instead of a second full ingest
  result; the first-ingest success result shape is unchanged.
- `Ex4pm.OCEL.validate_envelope/1` (`lib/ex4pm/ocel.ex`) — required envelope keys
  (`schema`, `producer` map, integer `sequence`, `events` list/map) **UNCHANGED**;
  the `59501af` change alters the `%Ex4pm.ObjectRef{}` `attributes` field
  representation produced by normalization, not envelope validation.
- `Ex4pm.Evidence.BRCE.execute/4` (`lib/ex4pm/evidence.ex`) — authority-map shape
  **UNCHANGED**.
- `Ex4pm.Aloop` (`lib/ex4pm/aloop.ex`) — **ADDED** (`64c157d`): new public module,
  24 public functions from `event_classes/0` through `analysis_receipt/1`; additive
  only — the three contract surfaces above are untouched.

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
