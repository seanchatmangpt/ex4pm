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

## [26.10.8] - 2026-10-08

Version alignment release: `@version` 26.10.1 → 26.10.8, aligning the ex4pm
and ash_ex4pm release trains on one version point. No code changes in this
release; it also lands the previously in-flight 26.10.2/26.10.3 changelog
entries whose code (OCEL writer, ETS evidence-store indexes) was already on
main.

### Public contract

- `Ex4pm.OCEL.validate_envelope/1` required envelope keys: UNCHANGED.
- `Ex4pm.Stream.Ingest.ingest_envelope/1,2` options: UNCHANGED.
- `Ex4pm.Evidence.BRCE.execute/4` authority-map shape: UNCHANGED.

## [26.10.3] - 2026-10-03

New: `Ex4pm.OCEL.Writer` — the OCEL 2.0 JSON writer now lives DOWN-STACK in
ex4pm (engine owns the wire format), pairing with the reader
`Ex4pm.OCEL.normalize/1`. Consumers (ash_ex4pm, ash_pplan) project from the
canonical `Ex4pm.EventLog` IR instead of building the envelope themselves.
Surface: `encode/1` → `{:ok, String.t()}`, `encode_iodata/1` → `{:ok, iodata}`
(per-event chunked so a 100k-event log never materializes one giant term),
`encode_gzip/1` → `{:ok, binary}` via `:zlib` (no new deps). Laws, each
court-witnessed in `test/ocel_writer_test.exs`: round-trip
(`normalize(Jason.decode!(encode(log)))` reconstructs same events/objects),
byte-identity (`IO.iodata_to_binary(encode_iodata(log)) == encode(log)`),
gzip round-trip, and flat reductions/event scaling (1k vs 10k, ±5%).
Non-`EventLog` subjects return `{:error, %Ex4pm.Refusal{}}` (never-raise).

### Public contract

- ADDED: `Ex4pm.OCEL.Writer.encode/1`, `encode_iodata/1`, `encode_gzip/1`
  (`lib/ex4pm/ocel_writer.ex`) — new public surface.
- `Ex4pm.OCEL.validate_envelope/1` required envelope keys: UNCHANGED.
- `Ex4pm.Stream.Ingest.ingest_envelope/1,2` options: UNCHANGED.
- `Ex4pm.Evidence.BRCE.execute/4` authority-map shape: UNCHANGED.

## [26.10.2] - 2026-10-01

Performance: `Ex4pm.Evidence.Store` keeps ETS secondary indexes on `subject_hash`
and `parent_hash`, so `get_by_subject/1` and `get_by_parent/1` are indexed lookups
instead of full-table scans (PR #53). The indexes stay exact even if a caller
replaces an existing receipt hash. Invariant coverage for the indexed lookups in
`test/evidence_store_index_test.exs`.

### Public contract

- `Ex4pm.OCEL.validate_envelope/1` required envelope keys: UNCHANGED.
- `Ex4pm.Stream.Ingest.ingest_envelope/1,2` options: UNCHANGED.
- `Ex4pm.Evidence.BRCE.execute/4` authority-map shape: UNCHANGED.

## [26.10.1] - 2026-10-01

Real wasm4pm and ferroplan execution are first-class: the wasm4pm artifact is bundled and served by a
supervised host with zero config, all 33 algorithms are engine candidates, ferroplan is complete
(facade, sessions, generated-contract checks) and every call is observable. The remote-runtime engines
are removed.

### Removed (BREAKING)

- `Ex4pm.Engine.Beam4pm` and `Ex4pm.Engine.Beam4pmA2A` (the HTTP/A2A client engines), the `:beam4pm` engine
  option, their ggen units/templates/query, the `ex4pmb:` Beam4pm service graph in the ontology, their test
  servers, and the `:req`/`:a2a`/`:ash_json_api`/`:open_api_spex` direct dependencies that existed only for them.
  Ferroplan no longer has any remote route: it runs in-process from the bundled artifact. Consumers of the old
  generated ferroplan routes (e.g. `ash_ex4pm`) must call `Ex4pm.Engine.Ferroplan`.

### Added

- **Zero-config wasm4pm.** `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm` (2,204,812 bytes, sha256 `92eacdcb…`,
  0 imports, 70 exports) is bundled and sha-pinned in `priv/wasm4pm/MANIFEST.json` with provenance and
  `scripts/refresh-wasm4pm-artifact.sh`. `Ex4pmEngine.Wasm.Host` (supervised, `config :ex4pm, :wasm_host`) admits it,
  restarts on trap and serves adapters without per-call transports (`wasm_default: false` opts out).
- All 33 AlgoRegistry algorithms are `Ex4pm.Engine` candidates (the 14 Phase-4 statistics were missing), ranked from
  the generated registry (`ex4pmal:engineRank`). Implicit selection keeps `:beam` for discover/conform/simulate/
  optimize unless `prefer_wasm: true`, an explicit `engine:`, or an explicit `<algo>_wasm_fun` is given.
- Public API: `Ex4pm.health/1`, `wasm/1`, `ferroplan/3` (receipted), `statistics/3`, `forecast/2`; `Ex4pm.plan/2`
  routes PDDL text / `engine: :ferroplan` to ferroplan. CLI `health`, `wasm verify`, `ferroplan`, `forecast`;
  mix tasks `ex4pm.wasm.verify|doctor`, `ex4pm.ferroplan.verify|version|readiness|plan`, `ex4pm.health`.
- Ferroplan: ops `hddl_solve`, `fond_policy_validate`, `fond_validate`, `explain` exposed; `hierarchical_plan/3`
  and `fond_policy/3` take the problem JSON (no domain); `Ex4pm.Engine.Ferroplan.Sessions` runs the 28
  `session_*` ops (one supervised wasm instance per session, journal recovery, CONSTRUCT-only); the transport
  accepts non-object JSON responses.
- `Ex4pm.Engine.CallLog` (telemetry `[:ex4pm,:engine,:call,:stop]` + an OCEL 2.0 event per wasm/ferroplan call),
  `FerroplanRepairReactor` (proposal only, `actuation: :requires_brce`), `Ex4pm.Stream.DriftSink`, information-plane
  capabilities `engine.wasm.run`/`engine.ferroplan.run`/`engine.standing`.
- `mix ex4pm.exposure.court` (in `verify`): every algorithm, wasm export and ferroplan op must have an adapter,
  engine op, documented public function and real-wasm test; `--require-real` executes them. Lint rule
  `:skipped_real_exec`; CI builds before testing and compares the artifact sha to its pin.
- HexDocs module groups, guides (real wasm, planning with ferroplan, choosing an engine), runnable examples.

### Changed

- `RealTransport.default_transport` forwards `:timeout` and size limits (previously ignored).
- Test helper `Ex4pm.Test.WasmArtifact`; `EX4PM_WASM_REQUIRED=1` fails instead of skipping.

### Public contract

- `Ex4pm.OCEL.validate_envelope/1`, `Ex4pm.Stream.Ingest.ingest_envelope/1,2` and
  `Ex4pm.Evidence.BRCE.execute/4` — **UNCHANGED**.
- Engine surface — **CHANGED**: Beam4pm engines removed (above); `Ex4pm.Engine.Ferroplan.hierarchical_plan/3` and
  `fond_policy/3` signatures changed; `Ex4pm.Engine.execute(:plan, engine: :ferroplan)` now supported.
- Public API — **ADDED**: `Ex4pm.health/1`, `wasm/1`, `ferroplan/3`, `statistics/3`, `forecast/2`.

## [26.9.30] - 2026-09-30

Version bump 26.9.24 -> 26.9.30. Adds `Ex4pm.Aloop`, OCEL 2.0 value-time object
attributes, idempotent ingestion, and the pack-driven WASM surface: sha256-pinned,
zero-import artifact admission (`Ex4pmEngine.Wasm.Admission`) and a generated algorithm
registry. Package `files` now includes README.md, CHANGELOG.md and LICENSE. The Hex
package does not bundle the wasm artifact (see README).

### Added

- **Native ferroplan runtime.** `Ex4pm.Engine.Ferroplan` embeds the ferroplan WASI wasm
  (`priv/ferroplan/ferroplan_wasm.wasm`, sha256-pinned in `priv/ferroplan/MANIFEST.json`,
  built from ferroplan 0.29.0 `2a2e1d8`) through `Ex4pmEngine.Wasm.FerroplanTransport`
  (admission: digest pin + WASI import allowlist + required exports; typed
  `%Ex4pm.Refusal{}`, no raises). Facade: `plan/4`, `plan_production/4` (candidate-only,
  `:partial_alive`), `readiness/1`, `version/1`, `hierarchical_plan/4`, `fond_policy/4`,
  `hddl_solve/4`, `wasm_built?/0`; explicit selection via `engine: :ferroplan`.
  `fond_policy_validate` returns a typed unsupported refusal (not exposed by the wasm).
  See `docs/FERROPLAN-RUNTIME.md`.
- `scripts/falsify-wasm-e2e.sh` / `mix falsify.wasm` (typed exit codes),
  `test/wasm/pack_drift_test.exs`, `EX4PM_WASM_REQUIRED` / `EX4PM_WASM_ARTIFACT`
  / `EX4PM_WASM_SHA256` for real-artifact tests; `docs/ALGORITHM-REGISTRY-GENERATION.md`.
- **`Ex4pm.Aloop` module added (`64c157d`).** Independent online process intelligence
  over ALOOP OCEL 2.0 event logs: ingest/episode segmentation, loop-depth/recurrence,
  human causal edges, provider replacement with substitution-equivalence verdicts,
  orphan-DO and unconsumed-receipt detection, DFG/variants/precision, conformance
  divergences, repair/replan chains, and a deterministic JSON-encodable
  `analysis_receipt/1`.
- **`Ex4pm.EconomicISA` (`d1ff769`, PR #45).** Compact economic-activity instruction
  set for nexus/edge execution: the common-path wire representation is exactly one
  byte (`0x00` reserved UNKNOWN/NULL, `0xFF` escape prefix for extended semantic
  identifiers) over nine sparse opcode ranges. `to_event/2` projects a byte activity
  into the existing canonical OCEL-v2-compatible `Ex4pm.Event` IR (stamping
  `economic_opcode`/`economic_category`/`economic_isa` attributes) — deliberately
  no competing event-log format.
- **`Ex4pm.Gall` (`8a68c2c` + `7c9d2f9` + `088df36`).** v26.9.18 GALL-015..020
  process-law qualification surfaces: corpus identity (`Corpus` fixtures/manifest
  digest), canonical POWL-like reference algebra with dual ingress — semantic spec
  and WF-net (`Powl.from_semantic/1`, `Powl.from_wfnet/1`, `equivalent?/2`), OCPQ
  reference evaluation (`Ocpq.evaluate/2`), rule-constrained discovery
  (`Discovery.discover/2`), candidate-only compliance prediction with integer
  `score_bp` scores (`Compliance.train/predict/evaluate`), and a deterministic
  process-compute dispatcher (`Compute.select/2`, versioned selection digests).
  Typed refusals throughout; the cross-language `Portable` envelope (RFC 8785
  subset canonical JSON) carries `authority: "NONE"` — the namespace observes and
  does not actuate.

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
- **BREAKING (Beam4pm engine surface):** the forward-declared `:ferroplan_hierarchical_plan`
  and `:ferroplan_fond_policy` routes (previously refused `:beam4pm_route_not_live`) are
  removed from `Ex4pm.Engine.Beam4pm`; ferroplan is native (above).
- `mix ex4pm.engine.gen.adapter` is now a thin wrapper over `ggen sync run`
  in `ggen/bindings/` with typed refusals.
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
- `Ex4pmEngine.Wasm.RealTransport.start/1,2` and `call`/`replay` — **CHANGED**: now
  return `%Ex4pm.Refusal{}` errors where they previously returned bare error terms
  (WASM transport surface only; not one of the three contract surfaces above).

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
