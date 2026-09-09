# ex4pm Reference

Information-oriented, exhaustive capability index of the ex4pm umbrella (12 apps). Each H2
covers one app's public functions and Mix tasks, taken verbatim from a freshly-gathered
per-app capability inventory. Use this to grep for a capability by module/function name.
See `~/ex4pm/CLAUDE.md` for the governing calculus
(`observation -> parse -> route -> admit | refuse -> construct -> BRCE -> DO -> receipt ->
replay -> bounded standing`) that these capabilities implement.

## apps/ex4pm (public orchestration API, package `:ex4pm`)

| Function | Purpose |
| --- | --- |
| `Ex4pm.Run` (struct) | Public evidence envelope for an analytical operation: operation, subject_hash, standing, value, receipt, pending, engine_result, projections |
| `Ex4pm.contracts/0` | Delegates to `Ex4pm.Contracts.verify/0`; returns the umbrella's combined contract hash/verification |
| `Ex4pm.ingest/2` (raw, opts \\ []) | Normalizes raw OCEL input via `OCEL.normalize/1`, optionally projects the dataset, returns `{:ok, EventLog}` |
| `Ex4pm.ingest_xes/2` (xml, opts \\ []) | Parses XES XML via `XES.parse/2`, optionally projects dataset, returns `{:ok, EventLog}` |
| `Ex4pm.discover/2` (subject, opts \\ []) | Resolves subject to an EventLog, runs `Engine.execute(:discover, log, opts)`, wraps in a receipted Run |
| `Ex4pm.conform/3` (subject, model, opts \\ []) | Runs `Engine.execute(:conform, {log, model}, opts)`, returns receipted Run |
| `Ex4pm.simulate/2` (model, opts \\ []) | Runs `Engine.execute(:simulate, model, opts)` keyed by `Core.Hash.digest(model)`, returns receipted Run |
| `Ex4pm.optimize/3` (subject, model, opts \\ []) | Runs `Engine.execute(:optimize, {log, model}, opts)`, returns receipted Run |
| `Ex4pm.plan/2` (problem, opts \\ []) | For a map problem, defaults engine to `:ex4pm_plan`, runs `Engine.execute(:plan, problem, opts)`; non-map returns `{:error, Refusal.new(:invalid_planning_problem, ...)}` |
| `Ex4pm.cmca/2` (problem, opts \\ []) | For a map problem, defaults engine to `:cmca_wasm`, computes a BCINR CMCA consequence allocation via the pinned wasm4pm bridge; non-map returns `{:error, Refusal.new(:invalid_cmca_problem, ...)}` |
| `Ex4pm.operate/3` (subject, authority, opts \\ []) | Sole DO-authority path: for `%POWL{}` compiles via `Runtime.compile/1` then `Runtime.execute/3`; for `%Runtime.Plan{}` executes directly; other subjects refused |
| `Ex4pm.stream/2` (events, opts) when is_list(opts) | Starts `Ex4pm.Stream.Pipeline.start_link/1` with events merged into opts |
| `Ex4pm.capabilities/2` (operation \\ :discover, opts \\ []) | Delegates to `Engine.candidates/2`, lists evidence-ranked engine candidates for an operation |
| `Ex4pm.differential/5` (operation, subject, left_engine, right_engine, opts \\ []) | Delegates to `Ex4pm.Engine.Differential.compare/5` |
| `Ex4pm.replay/2` (hash, opts \\ []) when is_binary(hash) | Looks up a receipt by hash, verifies via `Ex4pm.Evidence.Replay.Chain.verify/2`; `{:error, Refusal.new(:receipt_not_found, ...)}` if absent |
| `Ex4pm.Qualification.environment/0` | Builds a self-hashed observation of the current BEAM runtime/node/distribution posture |
| `Ex4pm.Qualification.execution_semantics/1` (%{subject_hash:, layers:}) | Reduces a layered execution trace to per-layer `:result`, self-hashed to a semantic_hash |

### Mix tasks — apps/ex4pm

| Task | Purpose |
| --- | --- |
| `mix ex4pm.ocel_to_latex [path_to_ocel_ndjson] [--output path]` | `Mix.Tasks.Ex4pm.OcelToLatex`: reads an IEEE OCEL 2.0 NDJSON log, calls `Ex4pmEngine.OcelToLatex.export_latex/2` to emit LaTeX benchmark tables |
| `mix ex4pm.validate_self --path <ocel_ndjson> --limit <n>` | `Mix.Tasks.Ex4pm.ValidateSelf`: runs `Reactor.run(Ex4pmEngine.Reactors.SelfConformanceReactor, ...)` against a real OCEL log; prints discovery, 5D conformance vector, EARL Turtle proof, final receipted STANDING; exits 1 on error |

## apps/ex4pm_cli

| Function | Purpose |
| --- | --- |
| `Ex4pm.CLI.main/1` | Escript entrypoint; dispatches on argv to `doctor`/`contracts`/`discover`/`discover-xes`/`help` subcommands (only public function; all other helpers are `defp`) |
| `Mix.Tasks.Ex4pm.Gen.Blueprint.run/1` | `@impl Mix.Task` entrypoint for `mix ex4pm.gen.blueprint ResourceName action1 action2 ...`; validates args, calls `generate_blueprint/2` |
| `Mix.Tasks.Ex4pm.Gen.Blueprint.generate_blueprint/2` | Builds an `Ash.Resource` module source string modeling a 1-safe Workflow Net (states/actions -> Ash actions + `to_workflow_net/0`); prints a "Generated" message but returns the string — no `File.write` call found in this function |

### Mix tasks — apps/ex4pm_cli

| Task | Purpose |
| --- | --- |
| `mix ex4pm.gen.blueprint ResourceName action1 action2 action3 ...` | `Mix.Tasks.Ex4pm.Gen.Blueprint` (`@shortdoc "Generates an Ash process resource blueprint"`) |

CLI verbs exposed via `Ex4pm.CLI.main/1` (not separate public functions, but the operational
surface of this app):

| Verb | Purpose |
| --- | --- |
| `doctor` | Lists discover-engine capabilities via `Ex4pm.capabilities(:discover)` plus contract standing/hash via `Ex4pm.contracts()` |
| `contracts` | Dumps the full verified contract JSON |
| `discover <ocel-v2.json> [object-type]` | Reads a JSON OCEL file, calls `Ex4pm.discover/2`, prints standing/receipt hash/model |
| `discover-xes <log.xes> [case-object-type]` | Ingests XES via `Ex4pm.ingest_xes/2`, then discovers |

## apps/ex4pm_contracts

| Function | Purpose |
| --- | --- |
| `Ex4pm.Contracts.version/0` | Returns `@contract_version` string (`"0.1.0"`) |
| `Ex4pm.Contracts.artifacts/0` | Returns map of artifact id => absolute resolved path (ontology/shacl/wit/receipt_schema) under `priv/` |
| `Ex4pm.Contracts.manifest/0` | Reads all four canonical artifacts, builds manifest with per-artifact id/path/size/hash/version; `{:error, Refusal}` if any artifact missing |
| `Ex4pm.Contracts.verify/0` | Runs manifest + required-terms check; returns `{:ok, %{version, artifacts, contract_hash, standing: :alive}}` or `{:error, Refusal}` |
| `Ex4pm.Contracts.read/1` | Reads raw bytes of one contract artifact by atom id; `{:error, Refusal.new(:unknown_contract_artifact, ...)}` or `{:error, Refusal.new(:contract_artifact_missing, ...)}` |

No Mix tasks defined in this app.

## apps/ex4pm_core

| Function | Purpose |
| --- | --- |
| `Ex4pm.Standing.rank/1` (standing) | Maps a standing atom (alive/partial_alive/blocked/build_broken/unsupported/unknown) to an integer rank |
| `Ex4pm.Standing.min/2` (left, right) | Returns the lower-ranked (more pessimistic) of two standings |
| `Ex4pm.Standing.to_string/1` (standing) | Renders a standing atom as an upcased string |
| `Ex4pm.Refusal.new/3` (code, message, opts \\ []) | Constructs a typed `%Ex4pm.Refusal{}` struct |
| `Ex4pm.Refusal.exception/1` (opts) | Builds a `%Ex4pm.Refusal{}` from a keyword list for use as an Elixir exception |
| `Ex4pm.Subject.new/3` (kind, value, metadata \\ %{}) | Builds an immutable `%Ex4pm.Subject{}` identity carrier by hashing value |
| `Ex4pm.Core.Hash.digest/2` (term, algorithm \\ :sha256) | Deterministic content hash (`"sha256:<hex>"`) of any term, canonicalizing maps/structs/lists |
| `Ex4pm.Core.OLAP.slice/3` (log, dimension, value) | Filters an EventLog to events matching one dimension value |
| `Ex4pm.Core.OLAP.dice/2` (log, filters) | Filters an EventLog to events matching multiple `{dimension, value}` pairs (AND) |
| `Ex4pm.Core.OLAP.roll_up/3` (log, dimension, aggregate_fn) | Groups EventLog events by dimension (`:activity`, `:day`, `:month`, `{:attribute, key}`), applies aggregate_fn per group |
| `Ex4pm.Core.OLAP.drill_down/3` (log, dimension, finer_dimension) | Expands a coarse dimension grouping into a nested map |
| `Ex4pm.OCEL.normalize/1` (raw_or_event_log) | Normalizes a raw OCEL-v2-shaped map (or passes through an EventLog) into canonical `%Ex4pm.EventLog{}` IR |
| `Ex4pm.OCEL.flatten/2` (log, object_type_or_nil) | Projects an EventLog into per-object (or whole-log) chronologically ordered event traces |
| `Ex4pm.OCEL.validate_envelope/1` (payload) | Validates a batch-ingestion envelope map (schema, producer, sequence, events, previous_digest) |
| `Ex4pm.OCEL2.object_trace/2` (log, object_id) | Returns the full time-ordered event sequence for one object id |
| `Ex4pm.OCEL2.attribute_history/3` (log, object_id, attribute_name) | Reconstructs chronological value-change history for one dynamic object attribute |
| `Ex4pm.OCEL2.object_relationships_for/2` (log, object_id) | Returns qualifier-typed O2O relationships touching one object id |
| `Ex4pm.POWL.new/3` (tasks, edges, metadata \\ %{}) | Constructs a validated, acyclic `%Ex4pm.POWL{}` partial-order workflow model |
| `Ex4pm.POWL.layers/1` (powl) | Computes topological layers (parallel-execution batches) via indegree reduction |
| `Ex4pm.XES.parse/2` (xml, opts \\ []) | Securely parses XES XML (DTD disabled) into canonical `%Ex4pm.EventLog{}` IR via `Ex4pm.OCEL.normalize/1`, tags `source_format: :xes` |
| `Ex4pmCore.ProcessIR.new/1` (attrs \\ %{}) | Constructs and validates `%Ex4pmCore.ProcessIR{}` (activities/choices/loops/partial_orders/guards/policies/objects/relationships) |
| `Ex4pmCore.ProcessIR.validate/1` (ir) | Re-validates referential integrity, acyclic partial orders, policy targets |
| `Ex4pmCore.ProcessIR.add_activity/2`, `add_choice/2`, `add_loop/2`, `add_partial_order/2`, `add_guard/2`, `add_policy/2`, `add_object/2`, `add_relationship/2` | Each adds/normalizes one construct into the ProcessIR and re-validates+re-hashes it |
| `Ex4pmCore.ProcessIR.digest/1` (ir) | Deterministic content hash of the ProcessIR via `Ex4pm.Core.Hash.digest/1` |
| `Ex4pmCore.ProcessIR.to_canonical_map/1` (ir) | Converts the ProcessIR struct tree into a plain serializable map |
| `Ex4pm.Core.ProcessIR` | Thin `defdelegate` alias module forwarding `new/1`, `validate/1`, all `add_*/2`, `digest/1`, `to_canonical_map/1` to `Ex4pmCore.ProcessIR` |

No Mix tasks defined in this app.

## apps/ex4pm_domain

| Function | Purpose |
| --- | --- |
| `Ex4pmDomain` (module) | `Ash.Domain` declaring OCEL 2.0 control-plane resources: Agent, AgentRun, Event, Object, EventObject, ObjectObject, ConformanceResult, Refusal, Receipt, CapabilityReceipt, plus wasm4pm-parity cognition/BEAMOps resources |
| `Ex4pm.Domain` (module) | Second `Ash.Domain` declaring the resources actually used by the projector: Agent, AgentRun, Event, Object, EventObject, ObjectObject, ProcessVariant, ConformanceResult, Refusal, Dataset, ProcessModel, Intervention, ReceiptProjection, EngineCapability; ProcessModel has a `:topology` calculation; Intervention is an `AshStateMachine` (proposed->admitted->actuated->verified, or refused) |
| `Ex4pmDomain.Manager.upsert_agent/1` | Creates or updates an Agent record by id |
| `Ex4pmDomain.Manager.upsert_run/1` | Creates or updates an AgentRun record by id |
| `Ex4pmDomain.Manager.create_event/1` | Inserts an Event record |
| `Ex4pmDomain.Manager.upsert_object/1` | Creates or updates an Object record by id |
| `Ex4pmDomain.Manager.create_event_object/1` | Inserts an EventObject (E2O) link record |
| `Ex4pmDomain.Manager.create_object_object/1` | Inserts an ObjectObject (O2O) link record |
| `Ex4pmDomain.Manager.record_conformance/1` | Inserts a ConformanceResult record |
| `Ex4pmDomain.Manager.record_refusal/1` | Inserts a Refusal record |
| `Ex4pmDomain.Manager.record_receipt/1` | Inserts a Receipt record |
| `Ex4pmDomain.Manager.list_agents/0` | Reads all Agent records |
| `Ex4pmDomain.Manager.list_events/1` (default limit 100) | Reads Event records, takes up to `limit` |
| `Ex4pm.Domain.Projector.dataset/1` | Projects an `Ex4pm.EventLog` into a Dataset record |
| `Ex4pm.Domain.Projector.event/1` | Projects an `Ex4pm.Event` struct into an Event record |
| `Ex4pm.Domain.Projector.object/1` | Projects an `Ex4pm.ObjectRef` struct into an Object record |
| `Ex4pm.Domain.Projector.event_object/3` (event_id, object_id, qualifier \\ "involved") | Projects an E2O relation into an EventObject record |
| `Ex4pm.Domain.Projector.object_object/3` (source_id, target_id, qualifier \\ "related") | Projects an O2O relation into an ObjectObject record |
| `Ex4pm.Domain.Projector.agent/1` | Projects a raw attrs map into an Agent record |
| `Ex4pm.Domain.Projector.agent_run/1` | Projects a raw attrs map into an AgentRun record |
| `Ex4pm.Domain.Projector.variant/3` (path, count, object_type \\ nil) | Projects a discovered process variant into a ProcessVariant record |
| `Ex4pm.Domain.Projector.conformance_result/1` | Projects a raw attrs map into a ConformanceResult record |
| `Ex4pm.Domain.Projector.refusal/1` | Two clauses: projects a core `Ex4pm.Refusal` struct, or a raw attrs map, into a Refusal record |
| `Ex4pm.Domain.Projector.process_model/1` | Projects an `Ex4pm.Engine.Result` (`operation: :discover`) into a ProcessModel record, computing model_hash via `Ex4pm.Core.Hash.digest/1` |
| `Ex4pm.Domain.Projector.intervention/2` (subject_hash, candidate map) | Projects a candidate intervention into an Intervention record with status `:constructed` |
| `Ex4pm.Domain.Projector.receipt/1` | Projects an `Ex4pm.Evidence.Receipt` struct into a ReceiptProjection record |
| `Ex4pm.Domain.Projector.capability/1` | Projects an `Ex4pm.Core.Capability` struct into an EngineCapability record |
| `Ex4pm.Domain.Projector.project_log/1` | Bulk-projects an entire EventLog (dataset, all objects, all events + E2O relations, all O2O relations) in one call |
| `Ex4pm.Domain.ProcessGraphProjector.topology/1` | Takes a process-model map (nodes/edges), builds a real temporary `:digraph`, returns `%{topsort: [...] | nil, components: [[...]]}` (topsort nil on a real cycle); also implements `Ash.Resource.Calculation` for ProcessModel's `:topology` |

No Mix tasks defined in this app (grep for `defmodule Mix.Tasks` returned zero matches).

## apps/ex4pm_engine (module prefix `Ex4pm.Engine` / `Ex4pmEngine`, version 26.8.22)

| Function | Purpose |
| --- | --- |
| `Ex4pm.Engine.candidates/2` | Returns `Ex4pm.Core.Capability` list (inspected, not executed) for every registered engine's standing for a given operation |
| `Ex4pm.Engine.select/2` | Picks the highest-evidence-ranked available engine module for an operation (or resolves explicit `:engine` opt), else refuses |
| `Ex4pm.Engine.execute/3` | Selects an engine then calls its `execute/3`, returning `{:ok, Ex4pm.Engine.Result.t()} | {:error, term}` |
| `Ex4pm.Engine.Registry.engines/0` | The fixed ordered list of 25 candidate engine modules |
| `Ex4pm.Engine.Registry.candidates/2` | Per-engine Capability standing computation (supports?/available? inspection only) |
| `Ex4pm.Engine.Registry.select/2` | Explicit-or-preference-ranked engine selection logic |
| `Ex4pm.Engine.Beam` (behaviour: `id/0`, `supports?/2`, `available?/2`, `execute/3`) | Native deterministic dispatch for `:cognition`/`:discover`/`:conform`/`:simulate`/`:optimize` and other operations |
| `Ex4pm.Engine.Beam.case_fitness_scores/2` | Per-case ARIS-scale (0-100) fitness scoring given traces and model edges |
| `Ex4pm.Engine.Cognition.execute/3` (default opts []) | Multi-clause dispatcher for cognition operations: `:bayesian_infer`, `:prolog_query`, `:plan`, `:temporal_relate`, `:ltl_check`, `:pareto_rank`, `:cost_evaluate`, `:adversarial_audit`, `:interview_evaluate`, `:ocpq_query`, `:survival_fit`, `:survival_predict`, `:causal_discover`, `:markov_fit`, `:critical_path`, `:optimal_alignment`, `:prove_soundness`, `:powl_to_net`, `:etc_precision`, `:dapn_execute`, `:ltlf_evaluate`, `:choreography_verify` |
| `Ex4pm.Engine.Wasm` (behaviour: `id/0`, `supports?/2`, `available?/2`, `execute/3`) | Real Wasmex/Wasmtime execution of an admitted WASM artifact with digest-based identity admission |
| `Ex4pm.Engine.Nif` (behaviour: `id/0`, `supports?/2`, `available?/2`, `execute/3`) | Configured native NIF module execution; `:alive` only with exact source_sha/library_digest/toolchain identity, else `:partial_alive` |
| `Ex4pm.Engine.Remote` (behaviour: `id/0`, `supports?/2`, `available?/2`, `execute/3`) | Explicit authenticated remote engine callback (3-arity fun) with tls/mtls + image_digest + receipt_verified identity admission |
| `Ex4pm.Engine.Ex4pmPlan` (behaviour: `id/0`, `supports?/2`, `available?/2`, `execute/3`, `protocol/0`, `source_sha/0`) | Pinned ex4pm-plan cloud planning worker bridge (only `:plan` op with `:astar` planner) |
| `Ex4pm.Engine.CmcaWasm` (behaviour: `id/0`, `supports?/2`, `available?/2`, `execute/3`, `protocol/0`, `bcinr_source_sha/0`, `wasm4pm_source_sha/0`, `kernel/0`) | CMCA WASM bridge (only `:cmca` op, requires configured `:cmca_wasm_fun/2`) |
| `Ex4pm.Engine.Differential.compare/5` | Runs the same operation/subject through two named engines and diffs results |
| `Ex4pm.Engine.Differential.dataframe/1` | Builds an Explorer DataFrame from an `Ex4pm.EventLog` |
| `Ex4pm.Engine.OnlineMiner` (GenServer): `start_link/1`, `ingest/2`, `get_summary/1`, `get_dfg/1`, `get_fleet_status/1`, `get_variants/1`, `get_conformance/1`, `reset/1` | Streaming/online process-mining server incrementally building a DFG, variants, conformance summary from ingested events |

### Mix tasks — apps/ex4pm_engine

| Task | Purpose |
| --- | --- |
| `mix ex4pm.engine.gen.adapter <algorithm_id> [--export NAME]` | `Mix.Tasks.Ex4pm.Engine.Gen.Adapter`: Igniter-based codegen scaffolding a new `Ex4pmEngine.Wasm.<AlgorithmId>` thin adapter delegating to `Ex4pm.Engine.Wasm.execute/3`, generates `lib/ex4pm_engine/wasm/<algorithm_id>.ex` with `algorithm_id/0`, `export/0`, `execute/2` |

## apps/ex4pm_evidence

| Function | Purpose |
| --- | --- |
| `Ex4pm.Evidence.Receipt.pending/4` (subject_hash, operation, authority, metadata \\ %{}) | Constructs a hashed `:pending` receipt, capturing operation/authority/started_at before DO is invoked |
| `Ex4pm.Evidence.Receipt.outcome/4` (pending, result, standing, metadata \\ %{}) | Constructs a hashed `:outcome` receipt linked via parent_hash to a pending receipt |
| `Ex4pm.Evidence.Store.start_link/1` | Starts the ETS-backed GenServer receipt ledger |
| `Ex4pm.Evidence.Store.put/2` (receipt, server \\ __MODULE__) | Inserts a receipt into the ETS ledger by hash |
| `Ex4pm.Evidence.Store.get/2` (hash, server) | Looks up a single receipt by its hash |
| `Ex4pm.Evidence.Store.get_by_subject/2` (subject_hash, server) | Returns all receipts for a subject, newest first |
| `Ex4pm.Evidence.Store.get_by_parent/2` (parent_hash, server) | Returns all outcome receipts chained to a given pending receipt |
| `Ex4pm.Evidence.Store.all/1` (server) | Returns every receipt in the ledger, newest first |
| `Ex4pm.Evidence.Store.history/2` (limit \\ 50, server) | Returns the most recent N receipts |
| `Ex4pm.Evidence.Replay.verify/1` (receipt) | Independently recomputes a receipt's hash from payload fields, confirms it matches |
| `Ex4pm.Evidence.Replay.Chain.verify/2` (receipt, store) | Chain-aware replay: verifies outcome receipt's hash, fetches/verifies pending parent, confirms subject/operation/authority correspondence |
| `Ex4pm.Evidence.BRCE.execute/5` (subject_hash, operation, authority, fun/0, opts \\ []) | Exclusive DO boundary: admits authority, persists pending receipt, invokes `fun.()`, persists outcome receipt (`:alive` or `:blocked`) |
| `Ex4pm.Evidence.BRCE.admit/2` (authority, operation) | Authorization check: requires `:do` in capabilities or operation in `:allow` list; returns `:ok` or typed Refusal |
| `Ex4pm.Evidence.DetsStore.start_link/1` (opts: path, table) | Starts a DETS-backed (restart-durable) alternative receipt store GenServer |
| `Ex4pm.Evidence.Application.start/2` | OTP application callback; supervises `Ex4pm.Evidence.Store` under `Ex4pm.Evidence.Supervisor` (one_for_one) |
| `Ex4pmEvidence.Engine.build_earl_assertion/1` (opts) | Builds a W3C EARL 1.0 test-assertion map + Turtle RDF for pass/fail/cantTell outcome |
| `Ex4pmEvidence.Engine.build_sosa_observation/1` (opts) | Builds a W3C SOSA/SSN telemetry observation with QUDT numeric value + unit, as map + Turtle |
| `Ex4pmEvidence.Engine.build_prov_lineage/1` (opts) | Builds a W3C PROV-O execution lineage graph (Activity/Agent/Entity), map + Turtle |
| `Ex4pmEvidence.Engine.build_dcat_catalog_record/1` (opts) | Builds a W3C DCAT 3 Catalog/Dataset/Distribution record, map + Turtle |
| `Ex4pmEvidence.Engine.build_spdx_manifest/1` (opts) | Builds an SPDX 3.0 package manifest with real SHA-256 file checksums, map + Turtle |
| `Ex4pmEvidence.CapabilityMesh.record_capability/4` (agent_id, capability_name, outcome, opts \\ []) | Builds an EARL assertion, computes a SHA-256 Merkle leaf digest chained to prev_root, persists an Ash `Ex4pmDomain.CapabilityReceipt` |
| `Ex4pmEvidence.Conformance.evaluate/3` (event_log, model_or_ir, opts \\ []) | Computes a 5-axis conformance Vector (fitness, precision, policy/lifecycle/causal conformance, overall_score) with Violation records |
| `Ex4pm.Evidence.Conformance.evaluate/3` | Alias/`defdelegate` to `Ex4pmEvidence.Conformance.evaluate/3` |

No Mix tasks defined in this app (confirmed by grep — zero matches).

## apps/ex4pm_information

| Function | Purpose |
| --- | --- |
| `Ex4pm.Information.protocol/0` | Returns protocol string constant `"ex4pm.information/1"` |
| `Ex4pm.Information.release/0` | Returns release version string `"26.8.22"` |
| `Ex4pm.Information.manifest/0` | Direct fast-path: full capability manifest (architecture, public/candidate capabilities, transport graph) without Reactor |
| `Ex4pm.Information.list/0` | Direct fast-path: sorted list of public capability id strings from Registry |
| `Ex4pm.Information.describe/1` | Direct fast-path: describes one capability by id string (delegates to `Registry.describe/1`); refuses non-binary input |
| `Ex4pm.Information.execute/2` | Main entrypoint: normalizes+admits a request map, runs through `Ex4pm.Information.Flow` Reactor graph (parse->route->admit/refuse->construct->BRCE->DO->receipt) |
| `Ex4pm.Information.dispatch_json/2` | JSON-in/JSON-out wrapper around `execute/2`: enforces 33,554,432 byte max request size, decodes JSON, re-encodes via `Protocol.json_safe/1` |
| `Ex4pm.Information.Registry.public_capabilities/0` | Lists closed, static table of admitted capabilities: `system.doctor`, `system.contracts`, `engine.candidates`, `ash.catalog`, `ash.read`, `process.ingest`, `process.ingest_xes`, `process.discover`, `process.discover_file`, `process.discover_xes`, `process.discover_xes_file`, `process.conform`, `process.simulate`, `process.optimize`, `process.plan`, `receipt.replay` |
| `Ex4pm.Information.Registry.candidate_capabilities/0` | Lists not-yet-admitted candidate capabilities with standing/reason: `runtime.operate`, `ash.mutate`, `external.wasm4pm`, `external.pm4py` |
| `Ex4pm.Information.Registry.transport_graph/0` | Lists transport/client edges: `beam_in_process`, `escript`, `jsonl_stdio`, `wasm4pm`, `pm4py`, `clap_noun_verb_any`, `mcp`, with implementation status |
| `Ex4pm.Information.Registry.describe/1` | Looks up one capability's description/inputs/options by exact string id; refuses unknown ids |
| `Ex4pm.Information.Registry.admit/1` | Validates a normalized request against the matched capability's schema; returns Admitted struct or Refusal; never turns external strings into atoms/modules |
| `Ex4pm.Information.Protocol.normalize/1` | Validates/normalizes a raw request map into canonical form, computes content-addressed request_hash |
| `Ex4pm.Information.Protocol.scheduler_limits/2` | Computes bounded Reactor timeout/max_concurrency/async? (default 30s/max 120s, default concurrency 4/max 64) |
| `Ex4pm.Information.Protocol.response/4` | Assembles final protocol-versioned response envelope from admitted request + execution + pending + outcome |
| `Ex4pm.Information.Protocol.refusal_response/2` | Builds a typed refusal response body from an `Ex4pm.Refusal` |
| `Ex4pm.Information.Protocol.error_response/2` | Builds a generic (non-refusal) error response body |
| `Ex4pm.Information.Protocol.refusal_map/1` | Converts an `Ex4pm.Refusal` struct into a plain JSON-safe map |
| `Ex4pm.Information.Protocol.json_safe/1` | Recursively converts arbitrary Elixir terms (structs, MapSets, DateTime/Date/Time, tuples, atoms, PIDs, refs, functions) into JSON-encodable values |
| `Ex4pm.Information.Interop.encode_model/1` | Projects an internal DFG or variants process-model map into the canonical wire-format JSON map |
| `Ex4pm.Information.Interop.decode_model/1` | Decodes a canonical JSON interchange model back into internal form; currently only admits type `"dfg"` |
| `Ex4pm.Information.Interop.event_log_summary/1` | Projects an `Ex4pm.EventLog` into a compact JSON-safe summary |
| `Ex4pm.Information.Interop.run_value/1` | Extracts and JSON-safe-encodes the value carried by an `Ex4pm.Run` (special-cases `:discover` via `encode_model/1`) |
| `Ex4pm.Information.Interop.underlying_receipts/1` | Extracts the receipt hash list backing a given `Ex4pm.Run` |
| `Ex4pm.Information.Interop.run_provenance/1` | Builds a provenance map (operation, subject_hash, engine, algorithm, engine_evidence) from an `Ex4pm.Run` |
| `Ex4pm.Information.AshCatalog.catalog/0` | Lists every public Ash resource in `Ex4pm.Domain` as a resource descriptor (read-only introspection) |
| `Ex4pm.Information.AshCatalog.resources/0` | Returns sorted, de-duplicated `Ash.Domain.Info` resource modules for `Ex4pm.Domain` |
| `Ex4pm.Information.AshCatalog.admit_read/3` | Resolves+admits an external (resource_name, action_name, params) triple into a safe `{resource, action}` pair without manufacturing atoms/modules |
| `Ex4pm.Information.AshCatalog.read/3` | Executes one already-admitted Ash read action given resolved `{resource, action}`, params, context |
| `Ex4pm.Information.AshCatalog.resolve_resource/1` | Resolves a public resource by exact string name against the already-loaded catalog |
| `Ex4pm.Information.AshCatalog.resource_descriptor/1` | Builds the JSON-safe descriptor for one Ash resource |
| `Ex4pm.Information.Handlers.execute/2` | Explicit dispatch table (one clause per capability handler atom); the only bridge from admitted Registry handler ids to real Ex4pm/Ash calls |
| `Ex4pm.Information.MermaidExport.to_mermaid!/2` | Renders a Reactor module (e.g. `Ex4pm.Information.Flow`) as a Mermaid flowchart binary via vendored `Reactor.Mermaid` |
| `Ex4pm.Information.ReceiptMiddleware` | `Reactor.Middleware` (`init/1`, `complete/2`, `error/2`, `event/3`) emitting `:telemetry` events for every Reactor run/step lifecycle transition; never writes a receipt itself |

No Mix tasks defined in this app.

## apps/ex4pm_qualification

| Function | Purpose |
| --- | --- |
| `Ex4pm.Qualification.LieFinder.scan/1` (root_dir \\ ".") | AST-scans `apps/*/lib/**/*.ex` for hardcoded metric numbers, direct `Ash.create(Receipt)` BRCE bypasses, bare-string `standing` assignments |
| `Ex4pm.Qualification.LieFinder.scan_file/1` | Same AST checks against a single file path |
| `Ex4pm.Qualification.LieFinder.inspect_ast/2` | Prewalks a parsed AST + file path applying the three lie-detection rules |
| `Ex4pm.Qualification.ChicagoAuditor.audit/0` | Scans `apps/*/test/**/*.exs` source text against hardcoded lists of 34 Ash resources, 10 Reactor sagas, 6 mining algorithms plus test count; returns utilization-percentage map and `:alive` standing |
| `Ex4pm.Qualification.Scanners.MetricLinter.scan/1` (root_dir \\ ".") | Tier-1 AST scan for hardcoded numeric literals assigned to fitness/precision/p_production_success/prob_success |
| `Ex4pm.Qualification.Scanners.MetricLinter.scan_file/1` | Single-file variant |
| `Ex4pm.Qualification.Scanners.ProductionPurger.scan/1` (root_dir \\ ".") | Tier-2 AST scan for defmodule names containing Mock/Fake/Stub outside test code |
| `Ex4pm.Qualification.Scanners.ProductionPurger.scan_file/1` | Single-file variant |
| `Ex4pm.Qualification.Scanners.BrceEnforcer.scan/1` (root_dir \\ ".") | Tier-4 AST scan for direct `Ash.create(Receipt, ...)` calls bypassing `Ex4pm.Evidence.BRCE` |
| `Ex4pm.Qualification.Scanners.BrceEnforcer.scan_file/1` | Single-file variant |
| `Ex4pm.Qualification.Crown.finalize/1` (crown map) | Runs `Verifier.verify/1`; on success stamps standing="ALIVE", verifier_identity, evidence_hash; `{:error, reason}` on failure |
| `Ex4pm.Qualification.Crown.finalize_file/2` (input_path, output_path) | Reads+decodes input, calls `finalize/1`, writes finalized crown as pretty JSON |
| `Ex4pm.Qualification.Verifier.verify/1` (crown map) | Independent re-derivation of crown standing: SHAs, POWL flags, rails, global evidence, command exit codes, falsifiers, evidence hash match |
| `Ex4pm.Qualification.Verifier.evidence_hash/1` (crown map) | Computes canonical `Ex4pm.Core.Hash` digest of the crown map with `standing`/`evidence_hash` stripped |
| `Ex4pm.Qualification.Rails.required/0` | Returns required engine-rail list `[:beam, :ex4pm_plan, :wasm, :nif, :remote]` |
| `Ex4pm.Qualification.Rails.verify/1` (list of `%Ex4pm.Engine.Result{}`) | Confirms all 5 required rails report `:alive`, and matching operations produce identical canonical result hash (differential court) |
| `Ex4pm.Qualification.Powl.Correspondence.check/2` (model, bound) | One-shot bounded correspondence check between POWL model and its Reactor compilation |
| `Ex4pm.Qualification.Powl.Correspondence.court/0` | Runs baseline bounded POWL/Reactor correspondence court end to end |
| `Ex4pm.Qualification.Powl.Correspondence.sabotage/3` (model, bound, mutation) | Injects one of a fixed mutation set (extra_trace/missing_trace/wrong_order/duplicate_execution/lost_terminal/wrong_bound); returns whether `:detected` |
| `Ex4pm.Qualification.Powl.PropertyCorpus.run/1` (count \\ default) | Generates and courts `count` randomized/generated POWL correspondence property cases |
| `Ex4pm.Qualification.Powl.PropertyCorpus.invalid_identity_court/0` | Courts a corpus of deliberately-invalid POWL identities to confirm correct rejection |
| `Ex4pm.Qualification.Powl.PropertyCorpus.case_model/1` (id) | Builds the deterministic POWL model fixture for property-corpus case `id` |
| `Ex4pm.Qualification.Powl.BoundedUnfolder.language/2` (model, bound) | Independent bounded lowering of a POWL model into its finite linear-trace language via Reactor fragments |
| `Ex4pm.Qualification.Powl.ReferenceOracle.language/2` (model, bound) | Independent reference-oracle computation of the same bounded trace language |
| `Ex4pm.Qualification.Powl.Semantics.identity/2` (model, bound) | Computes the bounded POWL semantic identity used to compare model vs. compiled-Reactor behavior |
| `Ex4pm.Qualification.Powl.TraceCanonicalizer.canonicalize/1` (traces) | Canonicalizes a list of bounded POWL linear traces into a comparable normal form |
| `Ex4pm.Qualification.Powl.Certificate.new/4` (bound, oracle, compiled, fragments) | Constructs the correspondence-court result certificate struct/map |
| `Ex4pm.Qualification.ReferenceNif.load_nif/0`, `.qualification_probe/2`, `.panic_probe/0` | NIF loader and stub entry points (`@moduledoc false`; `erlang.nif_error` until native lib loaded), the reference `:nif` rail fixture for `Rails.verify/1` |

### Mix tasks — apps/ex4pm_qualification

| Task | Purpose |
| --- | --- |
| `mix ex4pm.lint.truth [root]` | Runs `LieFinder.scan/1`; raises on any ungrounded-claim/hardcoded-metric/BRCE-bypass finding |
| `mix ex4pm.audit.bullshit` | Runs `MetricLinter.scan/0`, `ProductionPurger.scan/0`, `BrceEnforcer.scan/0`, `LieFinder.scan/0` together; prints per-tier violation count, raises if any tier found violations |
| `mix ex4pm.audit.chicago` | Runs `ChicagoAuditor.audit/0`; prints Ash-resource/Reactor/algorithm test-utilization percentages and stateful test counts; warns (no raise) if <100% |
| `mix ex4pm.powl.court` | Runs baseline `Correspondence.court/0`, a 2048-case `PropertyCorpus.run/1`, and `PropertyCorpus.invalid_identity_court/0`; raises on any error |
| `mix ex4pm.sabotage.court` | Builds a fixed loop/sequence POWL model, asserts all 6 sabotage mutations are `:detected`; raises listing survivors if any go undetected |
| `mix ex4pm.crown <input> [output]` | Reads crown evidence JSON (arg or `EX4PM_CROWN_INPUT` env var), calls `Crown.finalize_file/2`, writes verified/stamped crown (default `artifacts/qualification/ex4pm-final-crown-v1.json`); raises "crown refused" on failure |

## apps/ex4pm_runtime

| Function | Purpose |
| --- | --- |
| `Ex4pm.Runtime.compile/1` | Lowers an admitted `%Ex4pm.POWL{}` model into a Reactor-planned `%Ex4pm.Runtime.Plan{}`; `{:error, %Ex4pm.Refusal{}}` on non-POWL input or Reactor build/plan failure |
| `Ex4pm.Runtime.execute/3` (opts default []) | BRCE-governed execution facade: runs a compiled `%Plan{}` through `Reactor.run/4`, routing every task through `BRCE.execute/5`; `{:ok, execution}` or typed Refusal/failure map |
| `Ex4pm.Runtime.reactor_step_name/1` | Deterministic `{:ex4pm_task, task_id_string}` Reactor step name for a given POWL task id |
| `Ex4pm.Reactor.__using__/1` (macro) | `use Ex4pm.Reactor` delegates straight to `use Ash.Reactor`; ex4pm does not own a competing Reactor DSL |
| `Ex4pm.Reactor.compile/1` | Thin delegate to `Ex4pm.Runtime.compile/1` |
| `Ex4pm.Reactor.execute/3` | Thin delegate to `Ex4pm.Runtime.execute/3` |
| `Ex4pm.Runtime.Application.start/2` | OTP Application callback; starts one_for_one `Ex4pm.Runtime.Supervisor` with no children currently registered |
| `Ex4pm.Runtime.Distributed.execute/3` | Evidence-bounded distributed POWL execution: admits requested nodes, builds task->node placement, drives `Runtime.execute/3` dispatching each task to its placed node |
| `Ex4pm.Runtime.Distributed.execute_remote_task/4` and `/5` | Executes one POWL task's intent under `BRCE.execute/5` on the calling (remote) node, tags receipt metadata with distributed:true, executing_node, execution_id |
| `Ex4pm.Runtime.Distributed.concurrency_probe/1` | Sleeps delay_ms, returns start/finish system-time + `Node.self()`, empirically measures real concurrent execution across nodes |
| `Ex4pm.Runtime.Distributed.security_posture/0` | Reports whether OTP distribution is alive and whether its transport is encrypted (inet_tls/inet6_tls) |
| `Ex4pm.Runtime.Intent.operation/1` | Derives a canonical operation identifier from a task's `:intent` (atom-keyed, string-keyed, or falls back to `{:powl_task, task.id}`) |
| `Ex4pm.Runtime.Intent.execute/1` | Executes a task's intent: 0-arity fun, `{module, function, args}` MFA, literal `:value`, or fallback Reactor step name/BRCE placeholder |
| `Ex4pm.Runtime.PlanningPool.new/1` | Allocates a new bounded planning pool with `limit` concurrent slots (delegates to ConcurrencyTracker) |
| `Ex4pm.Runtime.PlanningPool.acquire/2` (default how_many=1) | Acquires slots from a pool |
| `Ex4pm.Runtime.PlanningPool.release/2` (default how_many=1) | Releases previously acquired slots back to a pool |
| `Ex4pm.Runtime.PlanningPool.release_on_exit/2` (default pid=self()) | Auto-releases the calling process's acquired slots when it exits |
| `Ex4pm.Runtime.PlanningPool.destroy/1` | Tears down a pool (does not affect slots already acquired by users) |
| `Ex4pm.Runtime.PlanningPool.status/1` | Returns `{:ok, available, limit}` or `{:error, reason}` for a pool |
| `Ex4pm.Runtime.PowlExecutor.start_link/3` (arity 2/3) | Starts a `gen_state_machine`-based token-marking executor for a POWL net given an initial marking and transitions |
| `Ex4pm.Runtime.PowlExecutor.fire/2` | Fires a given transition_id via `GenStateMachine.call`, mutating the net's token marking |
| `Ex4pm.Runtime.PowlExecutor.marking/2` | Returns the executor's current token marking |
| `Ex4pm.Runtime.ReactorStep.run/3` | Canonical Reactor step callback executing one admitted POWL task within the ex4pm runtime_context (delegates to task_runner/BRCE path); an internal `@moduledoc false` collector-step submodule has a second `run/3` returning `{:ok, :complete}` |

No Mix tasks defined in this app; the OTP supervision tree (`Ex4pm.Runtime.Application`) is
currently empty (one_for_one supervisor with no children registered).

## apps/ex4pm_stream

| Function | Purpose |
| --- | --- |
| `Ex4pm.Stream.Producer.start_link/1` | Starts the finite Broadway GenStage producer over a supplied enumerable of admitted observation events |
| `Ex4pm.Stream.Producer.ack/3` | `Broadway.Acknowledger` callback; sends `{:ex4pm_stream_ack, successful, failed}` to a pid ack_target, no-ops otherwise |
| `Ex4pm.Stream.Pipeline.start_link/1` | Starts the Broadway pipeline (producer + processors) wiring a caller-supplied sink callback and object map |
| `Ex4pm.Stream.Pipeline.handle_message/3` | Broadway callback; for a raw `%Ex4pm.Event{}` calls sink directly, for raw non-normalized data runs `Ex4pm.OCEL.normalize/1` first |
| `Ex4pm.Stream.Ingest.ingest_envelope/2` | Validates an OCEL producer envelope, checks idempotency, normalizes into a log, forwards events to an OnlineMiner process, records pending+outcome ingestion receipts, optionally invokes a broadcaster/1 callback |
| `Ex4pm.Stream.Metrics.metrics/0` | Returns the list of `Telemetry.Metrics` definitions (counters for processed/failed Broadway messages/batches, duration distribution) |
| `Ex4pm.Stream.Metrics.child_spec/1` | `Supervisor.child_spec/1`-compatible spec starting `TelemetryMetricsPrometheus.Core` with this module's metrics |
| `Ex4pm.Stream.Metrics.scrape/0` | Scrapes the default-named (`:ex4pm_stream_prometheus_metrics`) Prometheus reporter, returns real Prometheus-format text |
| `Ex4pm.Stream.Metrics.scrape/1` | Scrapes a named Prometheus reporter, returns real Prometheus-format text |
| `Ex4pm.Stream.Metrics.default_name/0` | Returns the default reporter name atom `:ex4pm_stream_prometheus_metrics` |
| `Ex4pm.Stream.SensorSink.new/1` | Builds sensor-abstraction state (threshold, rising_activity, falling_activity, per-sensor last_state, emitted count) |
| `Ex4pm.Stream.SensorSink.sample/2` | Folds one raw `{value, timestamp, sensor_id}` reading into the abstraction state, returning `{new_state, event_or_nil}` |
| `Ex4pm.Stream.SensorSink.sample_all/2` | Folds a list of raw readings through `sample/2`, returning final state and ordered list of abstracted events |
| `Ex4pm.Stream.SensorSink.handle_message/2` | Broadway sink-compatible message handler; unwraps `%Broadway.Message{data: reading}`, abstracts via `sample/2`, forwards emitted event to `context.forward/1` |

No Mix tasks defined in this app.

## apps/ex4pm_web

| Function | Purpose |
| --- | --- |
| `Ex4pmWeb.OcelController.ingest/2` | `POST /api/v1/ocel/events`: ingests an OCEL2 event envelope via `Ex4pm.Stream.Ingest.ingest_envelope/2`, projects log/refusal into domain layer, broadcasts over `Phoenix.PubSub` topic `process_intelligence:live`, returns 201/422/400 JSON |
| `Ex4pmWeb.HealthController.health/2` | `GET /health,/healthz`: liveness JSON (status ok, standing :alive, `Node.list()`) |
| `Ex4pmWeb.HealthController.ready/2` | `GET /health/ready,/readyz`: readiness check confirming `Ex4pm.Engine.OnlineMiner` and `Ex4pm.Evidence.Store` processes alive; 503 with per-component status otherwise |
| `Ex4pmWeb.Router.router/0` | `Phoenix.Router` macro entrypoint (`use Ex4pmWeb, :router`); defines HTTP surface (see table below) |
| `Ex4pmWeb.controller/0`, `live_view/0`, `live_component/0`, `html/0`, `verified_routes/0`, `static_paths/0`, `__using__/1` | Phoenix web-context boilerplate macros (controller/LiveView/component wiring, not app capabilities) |
| `Ex4pmWeb.Application.start/2` | OTP application start: supervises `Ex4pmWeb.Telemetry`, `Phoenix.PubSub` (`Ex4pmWeb.PubSub`), `Ex4pm.Engine.OnlineMiner` (with PubSub-broadcasting subscriber), `Ex4pmEngine.Autonomic.ClosedLoop` (3000ms interval), `Ex4pmWeb.Endpoint` |
| `Ex4pmWeb.Application.config_change/3` | Phoenix endpoint hot-config-reload callback |

### HTTP/LiveView routes — apps/ex4pm_web

| Route | Purpose |
| --- | --- |
| `POST /api/v1/ocel/events` | `Ex4pmWeb.OcelController.ingest/2` — OCEL2 event envelope ingest |
| `GET /health`, `/healthz` | `Ex4pmWeb.HealthController.health/2` — liveness |
| `GET /health/ready`, `/readyz` | `Ex4pmWeb.HealthController.ready/2` — readiness |
| `/` | LiveView |
| `/dashboard` | `DashboardLive` |
| `/process-intelligence/live` | `ProcessIntelligenceLive` |
| `/powl-miner` | `PowlMinerLive` |
| `/admin` | AshAdmin UI for the domain projection |

No Mix tasks defined in this app (grep for `defmodule Mix.Tasks` under `apps/ex4pm_web/lib`
returned no matches).

## See Also

- `/Users/sac/ex4pm/CLAUDE.md` — umbrella architecture, evidence/BRCE calculus, commands
- `docs/ARCHITECTURE.md` — full architectural contract (per CLAUDE.md)
- `docs/CHICAGO.md` — Chicago-style distribution qualification (`mix chicago`)
- `docs/ROADMAP-xaas-integration.md` — external xaas integration requirements
- `AGENTS.md` — BRCE authority-domain contract (SELECT/CONSTRUCT/DO separation)
