# ex4pm Reference

Information-oriented capability index of the ex4pm library (one flat Mix app,
`:ex4pm`, version 26.10.2 at HEAD). Every function below is taken verbatim from
the source in `/Users/sac/ex4pm/lib/`; line citations are to the working tree.

## Core orchestration API (`lib/ex4pm.ex`)

| Function | Returns | Notes |
|---|---|---|
| `Ex4pm.contracts/0` | `{:ok, map()} \| {:error, term()}` | verifies canonical contract artifacts (`Ex4pm.Contracts.verify/0`) |
| `Ex4pm.ingest/2` (raw, opts \\ []) | `{:ok, EventLog.t()} \| {:error, term()}` | OCEL-v2 normalize; `:project?` attaches projections |
| `Ex4pm.ingest_xes/2` (xml, opts \\ []) | same | XES parse; `:case_object_type` (default `"Case"`) |
| `Ex4pm.discover/2` (subject, opts \\ []) | `{:ok, Run.t()} \| {:error, Refusal.t()}` | raw map or EventLog; refusals `:no_available_engine`, `:engine_blocked`, `:unknown_engine` |
| `Ex4pm.conform/3` (subject, model, opts \\ []) | same | refusals as discover |
| `Ex4pm.simulate/2` (model, opts \\ []) | same | subject keyed by `Ex4pm.Core.Hash.digest(model)` |
| `Ex4pm.optimize/3` (subject, model, opts \\ []) | same | intervention candidates |
| `Ex4pm.plan/2` (problem, opts \\ []) | same | routing table in `lib/ex4pm.ex:482-503`; non-map → `:invalid_planning_problem` |
| `Ex4pm.cmca/2` (problem, opts \\ []) | same | BCINR CMCA via `:cmca_wasm`; non-map → `:invalid_cmca_problem` |
| `Ex4pm.ferroplan/3` (op, subject \\ %{}, opts \\ []) | same | ops `:plan`, `:plan_production`, `:hierarchical_plan`, `:fond_policy`, `:fond_policy_validate`, `:fond_validate`, `:explain`, `:readiness`, `:version` |
| `Ex4pm.statistics/3` (op, data, opts \\ []) | same | ops listed at `lib/ex4pm.ex:66-68` |
| `Ex4pm.forecast/2` (series, opts \\ []) | same | `:method :forecast \| :holt \| :ewma` |
| `Ex4pm.wasm/1` (opts \\ []) | `[map()]` | 33 algorithm engines, `executed: false` |
| `Ex4pm.health/1` (opts \\ []) | `map()` | `%{standing, wasm4pm: map, ferroplan: map}`; `:probe` default `true` |
| `Ex4pm.stream/2` (events, opts) | term | starts `Ex4pm.Stream.Pipeline` |
| `Ex4pm.operate/3` (subject, authority, opts \\ []) | `{:ok, map()} \| {:error, term()}` | only DO path; POWL or compiled Plan |
| `Ex4pm.capabilities/2` (operation \\ :discover, opts \\ []) | `[Ex4pm.Core.Capability.t()]` | inspection only |
| `Ex4pm.differential/5` (op, subject, left, right, opts \\ []) | term | `Ex4pm.Engine.Differential.compare/5` |
| `Ex4pm.replay/2` (hash, opts \\ []) | `{:ok, term()} \| {:error, term()}` | `:receipt_not_found` when absent |

Common options (moduledoc, `lib/ex4pm.ex:37-47`): `:engine`, `:store`,
`:project?`, `:<algo>_wasm_fun`, `:wasm_default`, `:prefer_wasm`,
`:ferroplan_artifact`, `:ferroplan_expected_sha256`.

## Core structs and modules (`lib/ex4pm/core.ex`, `lib/ex4pm/ocel.ex`)

| Item | Purpose |
|---|---|
| `Ex4pm.Standing` (`core.ex:1`) | `rank/1` (`:alive` 4 … `:unknown` 0), `min/2`, `to_string/1`; accepts SCREAMING_CASE aliases |
| `Ex4pm.Refusal` (`core.ex:30`) | typed refusal `%{code, message, subject, details}`; `new/3`, `exception/1` |
| `Ex4pm.Subject` (`core.ex:58`) | `new/3` — identity carrier hash-keyed via `Ex4pm.Core.Hash.digest/2` |
| `Ex4pm.Core.Hash` (`core.ex:76`) | `digest/2` — `"sha256:" <> hex`, map-key-canonicalized `term_to_binary` |
| `Ex4pm.Core.Capability` (`core.ex:116`) | engine capability descriptor struct |
| `Ex4pm.Claim` (`core.ex:132`) | verified/pending claim struct |
| `Ex4pm.Event` (`ocel.ex:1`) | `%{id, activity, timestamp, object_ids, relationships, attributes}` |
| `Ex4pm.ObjectRef` (`ocel.ex:7`) | value-time attribute log; `attribute_at/3` resolves as-of values |
| `Ex4pm.ObjectRelationship` (`ocel.ex:60`) | O2O relationship `%{source_id, target_id, qualifier}` |
| `Ex4pm.EventRelationship` (`ocel.ex:66`) | E2O relationship `%{object_id, qualifier}` |
| `Ex4pm.EventLog` (`ocel.ex:72`) | `%{events, objects, subject, object_relationships, source_format: :ocel_v2, metadata}` |
| `Ex4pm.OCEL.normalize/1` (`ocel.ex:103`) | tolerant OCEL map → `{:ok, EventLog}`; refusals `:missing_events`, `:missing_objects`, `:invalid_observation`, `:missing_object_id`, `:missing_object_type`, `:missing_event_id`, `:missing_activity`, `:missing_timestamp` |
| `Ex4pm.OCEL.flatten/2` (`ocel.ex:128`) | flatten log to traces by object type (or `nil` → single pseudo-trace); `:empty_flattening` refusal |
| `Ex4pm.OCEL.validate_envelope/1` (`ocel.ex:415`) | batch envelope validation; `:missing_envelope_schema`, `:missing_envelope_producer`, `:missing_envelope_sequence`, `:missing_envelope_events`, `:invalid_envelope` |
| `Ex4pm.XES.parse/2` (`xes.ex:10`) | XES XML → EventLog; `:case_object_type`; `:empty_xes` refusal |

## Evidence (`lib/ex4pm/evidence.ex`)

| Item | Purpose |
|---|---|
| `Ex4pm.Evidence.Receipt` (`evidence.ex:1`) | struct `pending/4` + `outcome/4`; content-addressed `hash` over payload |
| `Ex4pm.Evidence.Store` (`evidence.ex:78`) | ETS GenServer ledger: `put/2`, `get/2`, `get_by_subject/2`, `get_by_parent/2`, `all/1`, `history/2` |
| `Ex4pm.Evidence.Replay.verify/1` (`evidence.ex:211`) | recompute a receipt hash; `:replay_mismatch` / `:invalid_receipt` refusals |
| `Ex4pm.Evidence.Replay.Chain.verify/2` (`evidence/replay_chain.ex`) | verify outcome against parent in store; `replay: :chain_match` |
| `Ex4pm.Evidence.BRCE.execute/5` (`evidence.ex:265`) | sole DO boundary: admit → pending → run → outcome receipt |
| `Ex4pm.Evidence.BRCE.admit/2` (`evidence.ex:277`) | authority map needs `capabilities` incl. `:do` or `allow` naming the operation; `:authority_denied`, `:authority_required` |
| `Ex4pm.Evidence.Batch` (`evidence/batch.ex`) | batched receipt persistence |
| `Ex4pm.Evidence.DetsStore` (`evidence/dets_store.ex`) | disk-backed store |
| `Ex4pm.Evidence.GitContainment` (`evidence/git_containment.ex`) | git-subject containment checks |

## Engine (`lib/ex4pm/engine.ex`, `lib/ex4pm/engine/`)

| Item | Purpose |
|---|---|
| `Ex4pm.Engine` behaviour (`engine.ex:17`) | callbacks `id/0`, `supports?/2`, `available?/1`, `execute/3` |
| `Ex4pm.Engine.Registry.engines/0` (`engine.ex:79`) | algo engines (ranks from generated `Ex4pmEngine.Wasm.AlgoRegistry`) + `:beam`, `:ex4pm_plan`, `:cmca_wasm`, `:wasm`, `:nif`, `:remote`, `:wasm_remote`, `:ferroplan` |
| `Ex4pm.Engine.candidates/2` (`engine.ex:28`) | `[%Ex4pm.Core.Capability{}]`, standing `:partial_alive`/`:blocked`/`:unsupported` |
| `Ex4pm.Engine.select/2` (`engine.ex:29`) | explicit `:engine` never falls back; implicit ranked selection |
| `Ex4pm.Engine.execute/3` (`engine.ex:31`) | select then run |
| `Ex4pm.Engine.Result` (`engine.ex:1`) | `%{engine, operation, algorithm, subject_hash, standing, value, evidence}` |
| `Ex4pm.Engine.Beam` (`engine/beam.ex`) | evidenced fallback engine for discover/conform/simulate/optimize |
| `Ex4pm.Engine.Ferroplan` (`engine/ferroplan.ex`) | digest-pinned ferroplan wasm engine |
| `Ex4pm.Engine.Differential.compare/5` (`engine/differential.ex`) | two-engine comparison |
| `Ex4pm.Engine.OnlineMiner` (`engine/online_miner.ex`) | streaming discovery |
| `Ex4pm.Engine.Ex4pmPlan`, `CmcaWasm`, `Nif`, `Remote`, `WasmRemote` | planning / CMCA / remote transports |

## POWL and Runtime (`lib/ex4pm/powl.ex`, `lib/ex4pm/runtime.ex`)

| Item | Purpose |
|---|---|
| `Ex4pm.POWL.new/3` (`powl.ex:16`) | build acyclic task/edge model; `%Ex4pm.POWL.Task{}` nodes carry `:id`, `:label`, `:intent` |
| `Ex4pm.POWL.layers/1` (`powl.ex:24`) | topological layers |
| `Ex4pm.Runtime.compile/1` (`runtime.ex:19`) | POWL → `%Ex4pm.Runtime.Plan{}` (Reactor); `:reactor_compile_failed`, `:invalid_runtime_model` refusals |
| `Ex4pm.Runtime.execute/3` (`runtime.ex:64`) | BRCE per task; opts `:max_concurrency`, `:task_executor`, `:store`, `:timeout`, `:max_iterations`; returns `%{plan_hash, subject_hash, layers, standing: :alive, runtime: :reactor, receipt_hashes, ...}` |
| `Ex4pm.Runtime.Intent.execute/1` (`runtime/intent.ex`) | default task executor: fun / MFA / value intents |
| `Ex4pm.Runtime.Distributed` (`runtime/distributed.ex`) | distributed runtime |
| `Ex4pm.Runtime.Intent` (`runtime/intent.ex`) | shared intent projection |

## Stream (`lib/ex4pm/stream.ex`, `lib/ex4pm/stream/`)

| Item | Purpose |
|---|---|
| `Ex4pm.Stream.Pipeline.start_link/1` (`stream.ex:47`) | Broadway pipeline; required `:sink`, `:events`; optional `:objects`, `:name`, `:producer_concurrency`, `:processor_concurrency`, `:max_demand`, `:min_demand`, `:ack_target` |
| `Ex4pm.Stream.Producer` (`stream.ex:1`) | finite GenStage producer over an enumerable |
| `Ex4pm.Stream.Ingest.ingest_envelope/2` (`stream/ingest.ex:19`) | validated batch ingest, dedup via outcome receipt, `:duplicate_ignored` |
| `Ex4pm.Stream.DriftSink` (`stream/drift_sink.ex`) | drift observation sink |
| `Ex4pm.Stream.Metrics` (`stream/metrics.ex`) | stream metrics |
| `Ex4pm.Stream.SensorSink` (`stream/sensor_sink.ex`) | sensor observation sink |

## Information plane (`lib/ex4pm/information.ex`)

| Item | Purpose |
|---|---|
| `Ex4pm.Information.protocol/0` / `release/0` (`information.ex:17-18`) | `"ex4pm.information/1"` / `"26.8.22"` |
| `Ex4pm.Information.manifest/0` (`information.ex:20`) | capabilities + candidate capabilities + transport graph |
| `Ex4pm.Information.list/0` / `describe/1` (`information.ex:38-49`) | read-only introspection |
| `Ex4pm.Information.execute/2` (`information.ex:53`) | map request through Reactor flow |
| `Ex4pm.Information.dispatch_json/2` (`information.ex:98`) | raw JSON bytes, max 32 MiB |
| `Ex4pm.Information.Registry` | `public_capabilities/0`, `admit/1`, `describe/1` |

## Contracts and qualification

| Item | Purpose |
|---|---|
| `Ex4pm.Contracts` (`contracts.ex:1`) | `version/0`, `artifacts/0`, `manifest/0`, `verify/0`, `read/1` |
| `Ex4pm.Qualification` (`qualification.ex:1`) | runtime qualification environment; `mix ex4pm.qualification` |
| `Ex4pm.Domain.Projector` (`lib/ex4pm/domain/projector.ex`) | `dataset/1`, `process_model/1`, `intervention/2`, `receipt/1`, `project_log/1` |

## Mix tasks (`lib/mix/tasks/`)

`mix ex4pm.health`, `mix ex4pm.qualification`, `mix ex4pm.validate_self`,
`mix ex4pm.release.contract`, `mix ex4pm.wasm.doctor`, `mix ex4pm.wasm.verify`,
`mix ex4pm.lint.truth`, `mix ex4pm.audit.chicago`, `mix ex4pm.audit.bullshit`,
`mix ex4pm.exposure.court`, `mix ex4pm.rails.court`, `mix ex4pm.crown`,
`mix ex4pm.ferroplan.{plan,readiness,verify,version}`,
`mix ex4pm.ggen.sync`, `mix ex4pm.ggen.verify_determinism`,
`mix ex4pm.engine.gen.adapter`, `mix ex4pm.gen.blueprint`,
`mix ex4pm.ocel_to_latex`.

## Standing vocabulary

`:unknown` / `:partial_alive` / `:alive` / `:blocked` / `:build_broken` /
`:unsupported` (SCREAMING_CASE aliases accepted; `Ex4pm.Standing.rank/1`,
`lib/ex4pm/core.ex:4-17`).
