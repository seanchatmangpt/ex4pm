# crate reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### BasicPredicate

| `t` | type | @type t :: {:e2o, event_var :: String.t(), object_var :: String.t(), qualifier :: String.t() | nil} | {:o2o, source_var :: String.t(), target_var :: String.t(), qualifier :: String.t() | nil} | {:tbe, ev_a :: String.t(), ev_b :: String.t(), op :: atom(), threshold_ms :: number()} |  |  |  |  |


### BindingBox

| `BindingBox` | struct | defstruct vars, predicates, metadata: %{} |  |  |  |  |


### Data

| `Data` | struct | defstruct marking, transitions |  |  |  |  |


### Ex4pm

| `capabilities` | function | capabilities/2 |  |  |  |  |

| `cmca` | function | cmca/2 |  |  |  |  |

| `conform` | function | conform/3 |  |  |  |  |

| `contracts` | function | contracts/0 |  |  |  |  |

| `differential` | function | differential/5 |  |  |  |  |

| `discover` | function | discover/2 |  |  |  |  |

| `ferroplan` | function | ferroplan/3 |  |  |  |  |

| `forecast` | function | forecast/2 |  |  |  |  |

| `health` | function | health/1 |  |  |  |  |

| `ingest` | function | ingest/2 |  |  |  |  |

| `ingest_xes` | function | ingest_xes/2 |  |  |  |  |

| `operate` | function | operate/3 |  |  |  |  |

| `optimize` | function | optimize/3 |  |  |  |  |

| `plan` | function | plan/2 |  |  |  |  |

| `replay` | function | replay/2 |  |  |  |  |

| `simulate` | function | simulate/2 |  |  |  |  |

| `statistics` | function | statistics/3 |  |  |  |  |

| `stream` | function | stream/2 |  |  |  |  |

| `wasm` | function | wasm/1 |  |  |  |  |

| `run_result` | type | @type run_result :: {:ok, Ex4pm.Run.t()} | {:error, Refusal.t()} |  |  |  |  |


### Ex4pm.Claim

| `Ex4pm.Claim` | struct | defstruct id, kind, standing, reason, evidence: %{}, constraints: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), kind: atom(), standing: atom(), reason: String.t() | nil, evidence: map(), constraints: map() } |  |  |  |  |


### Ex4pm.Core.Capability

| `Ex4pm.Core.Capability` | struct | defstruct id, kind, standing, reason, evidence: %{}, constraints: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t() | atom(), kind: atom(), standing: atom(), reason: String.t() | nil, evidence: map(), constraints: map() } |  |  |  |  |


### Ex4pm.Core.Hash

| `digest` | function | digest/2 |  |  |  |  |

| `digest` | type | @type digest :: String.t() |  |  |  |  |


### Ex4pm.Engine.Discovery.Incremental

| `dfg` | function | dfg/1 |  |  |  |  |

| `finalize` | function | finalize/1 |  |  |  |  |

| `from_events` | function | from_events/2 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `update` | function | update/2 |  |  |  |  |

| `Ex4pm.Engine.Discovery.Incremental` | struct | defstruct case_id_fun: nil, last_activity: %{}, edges: %{}, activities: %{}, starts: %{}, ends: %{}, event_count: 0 |  |  |  |  |

| `edge` | type | @type edge :: {String.t(), String.t()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ case_id_fun: (Event.t() -> term()), last_activity: %{optional(term()) => String.t()}, edges: %{optional(edge()) => non_neg_integer()}, activities: %{optional(String.t()) => non_neg_integer()}, starts: %{optional(String.t()) => non_neg_integer()}, ends: %{optional(String.t()) => non_neg_integer()}, event_count: non_neg_integer() } |  |  |  |  |


### Ex4pm.Engine.Discovery.InductiveMiner

| `alphabet` | function | alphabet/1 |  |  |  |  |

| `detect_exclusive_choice_cut` | function | detect_exclusive_choice_cut/2 |  |  |  |  |

| `detect_sequence_cut` | function | detect_sequence_cut/2 |  |  |  |  |

| `directly_follows_graph` | function | directly_follows_graph/1 |  |  |  |  |

| `mine` | function | mine/1 |  |  |  |  |

| `activity` | type | @type activity :: String.t() |  |  |  |  |

| `event_log` | type | @type event_log :: [trace()] |  |  |  |  |

| `trace` | type | @type trace :: [activity()] |  |  |  |  |


### Ex4pm.Engine.Ferroplan

| `artifact_path` | function | artifact_path/1 |  |  |  |  |

| `available?` | function | available?/1 |  |  |  |  |

| `execute` | function | execute/3 |  |  |  |  |

| `explain` | function | explain/4 |  |  |  |  |

| `fond_policy` | function | fond_policy/3 |  |  |  |  |

| `fond_policy_validate` | function | fond_policy_validate/3 |  |  |  |  |

| `fond_validate` | function | fond_validate/3 |  |  |  |  |

| `hddl_solve` | function | hddl_solve/4 |  |  |  |  |

| `hierarchical_plan` | function | hierarchical_plan/3 |  |  |  |  |

| `id` | function | id/0 |  |  |  |  |

| `plan` | function | plan/4 |  |  |  |  |

| `plan_production` | function | plan_production/4 |  |  |  |  |

| `readiness` | function | readiness/1 |  |  |  |  |

| `supports?` | function | supports?/2 |  |  |  |  |

| `version` | function | version/1 |  |  |  |  |

| `wasm_built?` | function | wasm_built?/1 |  |  |  |  |

| `opts` | type | @type opts :: keyword() |  |  |  |  |

| `plan_arg` | type | @type plan_arg :: binary() | map() |  |  |  |  |

| `problem_json` | type | @type problem_json :: binary() | map() |  |  |  |  |

| `response` | type | @type response :: {:ok, map()} | {:error, Refusal.t() | term()} |  |  |  |  |


### Ex4pm.Engine.Ferroplan.Host

| `fetch` | function | fetch/2 |  |  |  |  |

| `handle_call` | function | handle_call/3 |  |  |  |  |

| `init` | function | init/1 |  |  |  |  |

| `stop_all` | function | stop_all/0 |  |  |  |  |


### Ex4pm.Event

| `Ex4pm.Event` | struct | defstruct id, activity, timestamp, object_ids: [], relationships: [], attributes: %{} |  |  |  |  |


### Ex4pm.EventLog

| `Ex4pm.EventLog` | struct | defstruct events, objects, subject, object_relationships: [], source_format: :ocel_v2, metadata: %{} |  |  |  |  |


### Ex4pm.EventRelationship

| `Ex4pm.EventRelationship` | struct | defstruct object_id, qualifier, attributes: %{} |  |  |  |  |


### Ex4pm.OCEL

| `flatten` | function | flatten/2 |  |  |  |  |

| `normalize` | function | normalize/1 |  |  |  |  |

| `validate_envelope` | function | validate_envelope/1 |  |  |  |  |


### Ex4pm.ObjectRef

| `attribute_at` | function | attribute_at/3 |  |  |  |  |

| `Ex4pm.ObjectRef` | struct | defstruct id, type, attributes: %{} |  |  |  |  |


### Ex4pm.ObjectRelationship

| `Ex4pm.ObjectRelationship` | struct | defstruct source_id, target_id, qualifier, attributes: %{} |  |  |  |  |


### Ex4pm.Refusal

| `exception` | function | exception/1 |  |  |  |  |

| `new` | function | new/3 |  |  |  |  |

| `Ex4pm.Refusal` | struct | defstruct code, message, subject, details: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ code: atom(), message: String.t(), subject: term() | nil, details: map() } |  |  |  |  |


### Ex4pm.Run

| `Ex4pm.Run` | struct | defstruct operation, subject_hash, standing, value, receipt, pending, engine_result, projections: [] |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ operation: atom(), subject_hash: String.t(), standing: atom(), value: term(), receipt: term(), pending: term(), engine_result: Ex4pm.Engine.Result.t() | nil, projections: list() } |  |  |  |  |


### Ex4pm.Runtime.PowlExecutor

| `fire` | function | fire/2 |  |  |  |  |

| `init` | function | init/1 |  |  |  |  |

| `marking` | function | marking/1 |  |  |  |  |

| `marking` | function | marking/3 |  |  |  |  |

| `start_link` | function | start_link/3 |  |  |  |  |

| `marking` | type | @type marking :: %{optional(place) => non_neg_integer()} |  |  |  |  |

| `place` | type | @type place :: term() |  |  |  |  |

| `transition` | type | @type transition :: %{inputs: [place], outputs: [place]} |  |  |  |  |

| `transition_id` | type | @type transition_id :: term() |  |  |  |  |

| `transitions` | type | @type transitions :: %{optional(transition_id) => transition} |  |  |  |  |


### Ex4pm.Standing

| `min` | function | min/2 |  |  |  |  |

| `rank` | function | rank/1 |  |  |  |  |

| `to_string` | function | to_string/1 |  |  |  |  |


### Ex4pm.Stream.SensorSink

| `handle_message` | function | handle_message/2 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `sample` | function | sample/2 |  |  |  |  |

| `sample_all` | function | sample_all/2 |  |  |  |  |

| `Ex4pm.Stream.SensorSink` | struct | defstruct threshold: 0.0, rising_activity: "threshold_crossed_above", falling_activity: "threshold_crossed_below", last_state: %{}, emitted: 0 |  |  |  |  |

| `reading` | type | @type reading :: {number(), DateTime.t() | non_neg_integer(), String.t()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ threshold: number(), rising_activity: String.t(), falling_activity: String.t(), last_state: %{optional(String.t()) => :above | :at_or_below}, emitted: non_neg_integer() } |  |  |  |  |


### Ex4pm.Subject

| `new` | function | new/3 |  |  |  |  |

| `Ex4pm.Subject` | struct | defstruct id, kind, hash, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t() | nil, kind: atom(), hash: String.t(), metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR

| `add_activity` | function | add_activity/2 |  |  |  |  |

| `add_choice` | function | add_choice/2 |  |  |  |  |

| `add_guard` | function | add_guard/2 |  |  |  |  |

| `add_loop` | function | add_loop/2 |  |  |  |  |

| `add_object` | function | add_object/2 |  |  |  |  |

| `add_partial_order` | function | add_partial_order/2 |  |  |  |  |

| `add_policy` | function | add_policy/2 |  |  |  |  |

| `add_relationship` | function | add_relationship/2 |  |  |  |  |

| `digest` | function | digest/1 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `to_canonical_map` | function | to_canonical_map/1 |  |  |  |  |

| `validate` | function | validate/1 |  |  |  |  |

| `Ex4pmCore.ProcessIR` | struct | defstruct id, name: "", version: "1.0.0", activities: %{}, choices: %{}, loops: %{}, partial_orders: %{}, guards: %{}, policies: %{}, objects: %{}, relationships: %{}, root: nil, metadata: %{}, subject: nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), name: String.t(), version: String.t(), activities: %{optional(String.t()) => Activity.t()}, choices: %{optional(String.t()) => Choice.t()}, loops: %{optional(String.t()) => Loop.t()}, partial_orders: %{optional(String.t()) => PartialOrder.t()}, guards: %{optional(String.t()) => Guard.t()}, policies: %{optional(String.t()) => Policy.t()}, objects: %{optional(String.t()) => ObjectType.t()}, relationships: %{optional(String.t()) => Relationship.t()}, root: String.t() | term() | nil, metadata: map(), subject: Subject.t() | nil } |  |  |  |  |


### Ex4pmCore.ProcessIR.Activity

| `Ex4pmCore.ProcessIR.Activity` | struct | defstruct id, label, object_types: [], lifecycle_states: ["create", "start", "complete"], attributes: %{}, guards: [], metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), label: String.t(), object_types: [String.t()], lifecycle_states: [String.t()], attributes: map(), guards: [String.t()], metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR.Choice

| `Ex4pmCore.ProcessIR.Choice` | struct | defstruct id, branches, type: :xor, conditions: %{}, default_branch: nil, metadata: %{} |  |  |  |  |

| `choice_type` | type | @type choice_type :: :xor | :or | :deferrable | :choice_graph |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), branches: [String.t()], type: choice_type(), conditions: %{optional(String.t()) => String.t()}, default_branch: String.t() | nil, metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR.Guard

| `Ex4pmCore.ProcessIR.Guard` | struct | defstruct id, expression, description: "", metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), expression: map() | String.t() | term(), description: String.t(), metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR.Loop

| `Ex4pmCore.ProcessIR.Loop` | struct | defstruct id, body, redo, exit: nil, loop_condition: nil, max_iterations: nil, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), body: String.t(), redo: String.t(), exit: String.t() | nil, loop_condition: String.t() | nil, max_iterations: non_neg_integer() | nil, metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR.ObjectType

| `Ex4pmCore.ProcessIR.ObjectType` | struct | defstruct id, name: nil, attributes: %{}, lifecycle_states: [], cardinality: :many, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), name: String.t() | nil, attributes: map(), lifecycle_states: [String.t()], cardinality: :one | :many | String.t(), metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR.PartialOrder

| `Ex4pmCore.ProcessIR.PartialOrder` | struct | defstruct id, nodes, edges, metadata: %{} |  |  |  |  |

| `edge` | type | @type edge :: {String.t(), String.t()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), nodes: [String.t()], edges: [edge()], metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR.Policy

| `Ex4pmCore.ProcessIR.Policy` | struct | defstruct id, type, target_activities: [], target_objects: [], rules: %{}, description: "", metadata: %{} |  |  |  |  |

| `policy_type` | type | @type policy_type :: :sod | :bod | :sla | :mandatory | :forbidden | :cardinality | :custom |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), type: policy_type(), target_activities: [String.t()], target_objects: [String.t()], rules: map(), description: String.t(), metadata: map() } |  |  |  |  |


### Ex4pmCore.ProcessIR.Relationship

| `Ex4pmCore.ProcessIR.Relationship` | struct | defstruct id, source, target, type: :o2o, qualifier: "related", cardinality: "1..*", metadata: %{} |  |  |  |  |

| `rel_type` | type | @type rel_type :: :o2o | :o2m | :m2m | :e2o |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), source: String.t(), target: String.t(), type: rel_type(), qualifier: String.t(), cardinality: String.t(), metadata: map() } |  |  |  |  |


### Ex4pmEngine.Cognition.Ocpq

| `build_index` | function | build_index/1 |  |  |  |  |

| `evaluate_box` | function | evaluate_box/3 |  |  |  |  |

| `evaluate_box_indexed` | function | evaluate_box_indexed/3 |  |  |  |  |

| `evaluate_query` | function | evaluate_query/2 |  |  |  |  |

| `evaluate_query_indexed` | function | evaluate_query_indexed/2 |  |  |  |  |


### Ex4pmEngine.WorkflowNet

| `enabled_transitions` | function | enabled_transitions/2 |  |  |  |  |

| `fire` | function | fire/3 |  |  |  |  |

| `new` | function | new/4 |  |  |  |  |

| `simulate_traces` | function | simulate_traces/2 |  |  |  |  |

| `validate_structure` | function | validate_structure/1 |  |  |  |  |

| `verify_soundness` | function | verify_soundness/2 |  |  |  |  |

| `Ex4pmEngine.WorkflowNet` | struct | defstruct id, places, transitions, arcs, source_place, sink_place, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t() | nil, places: %{optional(String.t()) => Place.t()}, transitions: %{optional(String.t()) => Transition.t()}, arcs: [Arc.t()], source_place: String.t(), sink_place: String.t(), metadata: map() } |  |  |  |  |


### Ex4pmEngine.WorkflowNet.Arc

| `Ex4pmEngine.WorkflowNet.Arc` | struct | defstruct source, target, weight: 1, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ source: String.t(), target: String.t(), weight: pos_integer(), metadata: map() } |  |  |  |  |


### Ex4pmEngine.WorkflowNet.Place

| `Ex4pmEngine.WorkflowNet.Place` | struct | defstruct id, name: nil, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), name: String.t() | nil, metadata: map() } |  |  |  |  |


### Ex4pmEngine.WorkflowNet.SoundnessReport

| `Ex4pmEngine.WorkflowNet.SoundnessReport` | struct | defstruct sound?, definition_3_3_valid?: true, one_safe?: true, option_to_complete?: true, proper_completion?: true, no_dead_transitions?: true, dead_transitions: [], livelock_detected?: false, livelocks: [], deadlocks: [], unbounded_places: [], reachable_markings_count: 0, terminal_markings: [], violations: [], details: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ sound?: boolean(), definition_3_3_valid?: boolean(), one_safe?: boolean(), option_to_complete?: boolean(), proper_completion?: boolean(), no_dead_transitions?: boolean(), dead_transitions: [String.t()], livelock_detected?: boolean(), livelocks: [list()], deadlocks: [map()], unbounded_places: [String.t()], reachable_markings_count: non_neg_integer(), terminal_markings: [map()], violations: [String.t()], details: map() } |  |  |  |  |


### Ex4pmEngine.WorkflowNet.Transition

| `Ex4pmEngine.WorkflowNet.Transition` | struct | defstruct id, label: nil, silent?: false, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), label: String.t() | nil, silent?: boolean(), metadata: map() } |  |  |  |  |


### Ex4pmEvidence.Conformance

| `evaluate` | function | evaluate/3 |  |  |  |  |


### Ex4pmEvidence.Conformance.Vector

| `Ex4pmEvidence.Conformance.Vector` | struct | defstruct fitness, precision, policy_conformance, lifecycle_conformance, causal_conformance, overall_score, details: %{}, violations: [], standing: :alive, subject_hash: nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ fitness: float(), precision: float(), policy_conformance: float(), lifecycle_conformance: float(), causal_conformance: float(), overall_score: float(), details: map(), violations: [Ex4pmEvidence.Conformance.Violation.t()], standing: Ex4pm.Standing.t(), subject_hash: String.t() | nil } |  |  |  |  |


### Ex4pmEvidence.Conformance.Violation

| `Ex4pmEvidence.Conformance.Violation` | struct | defstruct dimension, rule, message, case_id: nil, object_id: nil, events: [], details: %{} |  |  |  |  |

| `dimension` | type | @type dimension :: :fitness | :precision | :policy | :lifecycle | :causal |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ dimension: dimension(), rule: atom() | String.t(), message: String.t(), case_id: String.t() | nil, object_id: String.t() | nil, events: [String.t()], details: map() } |  |  |  |  |


### FlowerFallback

| `FlowerFallback` | struct | defstruct activities, reason |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{activities: [String.t()], reason: String.t()} |  |  |  |  |


### IndexContext

| `IndexContext` | struct | defstruct event_map, events_by_type, objects_by_type, e2o_set, o2o_set, o2o_by_source, e2o_by_object, time_map |  |  |  |  |


### ProcessTree

| `ProcessTree` | struct | defstruct kind, label, children: |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ kind: :leaf | :sequence | :exclusive_choice | :tau, label: String.t() | nil, children: [t()] } |  |  |  |  |


### QueryTree

| `QueryTree` | struct | defstruct root_box, children: [], min_children: 0, max_children: :infinity |  |  |  |  |


### VarDecl

| `VarDecl` | struct | defstruct name, kind, types: |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `t` | type | @type t :: {:e2o, event_var :: String.t(), object_var :: String.t(), qualifier :: String.t() | nil} | {:o2o, source_var :: String.t(), target_var :: String.t(), qualifier :: String.t() | nil} | {:tbe, ev_a :: String.t(), ev_b :: String.t(), op :: atom(), threshold_ms :: number()} |  |  |  |  |

| `BindingBox` | struct | defstruct vars, predicates, metadata: %{} |  |  |  |  |

| `Data` | struct | defstruct marking, transitions |  |  |  |  |

| `capabilities` | function | capabilities/2 |  |  |  |  |

| `cmca` | function | cmca/2 |  |  |  |  |

| `conform` | function | conform/3 |  |  |  |  |

| `contracts` | function | contracts/0 |  |  |  |  |

| `differential` | function | differential/5 |  |  |  |  |

| `discover` | function | discover/2 |  |  |  |  |

| `ferroplan` | function | ferroplan/3 |  |  |  |  |

| `forecast` | function | forecast/2 |  |  |  |  |

| `health` | function | health/1 |  |  |  |  |

| `ingest` | function | ingest/2 |  |  |  |  |

| `ingest_xes` | function | ingest_xes/2 |  |  |  |  |

| `operate` | function | operate/3 |  |  |  |  |

| `optimize` | function | optimize/3 |  |  |  |  |

| `plan` | function | plan/2 |  |  |  |  |

| `replay` | function | replay/2 |  |  |  |  |

| `simulate` | function | simulate/2 |  |  |  |  |

| `statistics` | function | statistics/3 |  |  |  |  |

| `stream` | function | stream/2 |  |  |  |  |

| `wasm` | function | wasm/1 |  |  |  |  |

| `run_result` | type | @type run_result :: {:ok, Ex4pm.Run.t()} | {:error, Refusal.t()} |  |  |  |  |

| `Ex4pm.Claim` | struct | defstruct id, kind, standing, reason, evidence: %{}, constraints: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), kind: atom(), standing: atom(), reason: String.t() | nil, evidence: map(), constraints: map() } |  |  |  |  |

| `Ex4pm.Core.Capability` | struct | defstruct id, kind, standing, reason, evidence: %{}, constraints: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t() | atom(), kind: atom(), standing: atom(), reason: String.t() | nil, evidence: map(), constraints: map() } |  |  |  |  |

| `digest` | function | digest/2 |  |  |  |  |

| `digest` | type | @type digest :: String.t() |  |  |  |  |

| `dfg` | function | dfg/1 |  |  |  |  |

| `finalize` | function | finalize/1 |  |  |  |  |

| `from_events` | function | from_events/2 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `update` | function | update/2 |  |  |  |  |

| `Ex4pm.Engine.Discovery.Incremental` | struct | defstruct case_id_fun: nil, last_activity: %{}, edges: %{}, activities: %{}, starts: %{}, ends: %{}, event_count: 0 |  |  |  |  |

| `edge` | type | @type edge :: {String.t(), String.t()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ case_id_fun: (Event.t() -> term()), last_activity: %{optional(term()) => String.t()}, edges: %{optional(edge()) => non_neg_integer()}, activities: %{optional(String.t()) => non_neg_integer()}, starts: %{optional(String.t()) => non_neg_integer()}, ends: %{optional(String.t()) => non_neg_integer()}, event_count: non_neg_integer() } |  |  |  |  |

| `alphabet` | function | alphabet/1 |  |  |  |  |

| `detect_exclusive_choice_cut` | function | detect_exclusive_choice_cut/2 |  |  |  |  |

| `detect_sequence_cut` | function | detect_sequence_cut/2 |  |  |  |  |

| `directly_follows_graph` | function | directly_follows_graph/1 |  |  |  |  |

| `mine` | function | mine/1 |  |  |  |  |

| `activity` | type | @type activity :: String.t() |  |  |  |  |

| `event_log` | type | @type event_log :: [trace()] |  |  |  |  |

| `trace` | type | @type trace :: [activity()] |  |  |  |  |

| `artifact_path` | function | artifact_path/1 |  |  |  |  |

| `available?` | function | available?/1 |  |  |  |  |

| `execute` | function | execute/3 |  |  |  |  |

| `explain` | function | explain/4 |  |  |  |  |

| `fond_policy` | function | fond_policy/3 |  |  |  |  |

| `fond_policy_validate` | function | fond_policy_validate/3 |  |  |  |  |

| `fond_validate` | function | fond_validate/3 |  |  |  |  |

| `hddl_solve` | function | hddl_solve/4 |  |  |  |  |

| `hierarchical_plan` | function | hierarchical_plan/3 |  |  |  |  |

| `id` | function | id/0 |  |  |  |  |

| `plan` | function | plan/4 |  |  |  |  |

| `plan_production` | function | plan_production/4 |  |  |  |  |

| `readiness` | function | readiness/1 |  |  |  |  |

| `supports?` | function | supports?/2 |  |  |  |  |

| `version` | function | version/1 |  |  |  |  |

| `wasm_built?` | function | wasm_built?/1 |  |  |  |  |

| `opts` | type | @type opts :: keyword() |  |  |  |  |

| `plan_arg` | type | @type plan_arg :: binary() | map() |  |  |  |  |

| `problem_json` | type | @type problem_json :: binary() | map() |  |  |  |  |

| `response` | type | @type response :: {:ok, map()} | {:error, Refusal.t() | term()} |  |  |  |  |

| `fetch` | function | fetch/2 |  |  |  |  |

| `handle_call` | function | handle_call/3 |  |  |  |  |

| `init` | function | init/1 |  |  |  |  |

| `stop_all` | function | stop_all/0 |  |  |  |  |

| `Ex4pm.Event` | struct | defstruct id, activity, timestamp, object_ids: [], relationships: [], attributes: %{} |  |  |  |  |

| `Ex4pm.EventLog` | struct | defstruct events, objects, subject, object_relationships: [], source_format: :ocel_v2, metadata: %{} |  |  |  |  |

| `Ex4pm.EventRelationship` | struct | defstruct object_id, qualifier, attributes: %{} |  |  |  |  |

| `flatten` | function | flatten/2 |  |  |  |  |

| `normalize` | function | normalize/1 |  |  |  |  |

| `validate_envelope` | function | validate_envelope/1 |  |  |  |  |

| `attribute_at` | function | attribute_at/3 |  |  |  |  |

| `Ex4pm.ObjectRef` | struct | defstruct id, type, attributes: %{} |  |  |  |  |

| `Ex4pm.ObjectRelationship` | struct | defstruct source_id, target_id, qualifier, attributes: %{} |  |  |  |  |

| `exception` | function | exception/1 |  |  |  |  |

| `new` | function | new/3 |  |  |  |  |

| `Ex4pm.Refusal` | struct | defstruct code, message, subject, details: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ code: atom(), message: String.t(), subject: term() | nil, details: map() } |  |  |  |  |

| `Ex4pm.Run` | struct | defstruct operation, subject_hash, standing, value, receipt, pending, engine_result, projections: [] |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ operation: atom(), subject_hash: String.t(), standing: atom(), value: term(), receipt: term(), pending: term(), engine_result: Ex4pm.Engine.Result.t() | nil, projections: list() } |  |  |  |  |

| `fire` | function | fire/2 |  |  |  |  |

| `init` | function | init/1 |  |  |  |  |

| `marking` | function | marking/1 |  |  |  |  |

| `marking` | function | marking/3 |  |  |  |  |

| `start_link` | function | start_link/3 |  |  |  |  |

| `marking` | type | @type marking :: %{optional(place) => non_neg_integer()} |  |  |  |  |

| `place` | type | @type place :: term() |  |  |  |  |

| `transition` | type | @type transition :: %{inputs: [place], outputs: [place]} |  |  |  |  |

| `transition_id` | type | @type transition_id :: term() |  |  |  |  |

| `transitions` | type | @type transitions :: %{optional(transition_id) => transition} |  |  |  |  |

| `min` | function | min/2 |  |  |  |  |

| `rank` | function | rank/1 |  |  |  |  |

| `to_string` | function | to_string/1 |  |  |  |  |

| `handle_message` | function | handle_message/2 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `sample` | function | sample/2 |  |  |  |  |

| `sample_all` | function | sample_all/2 |  |  |  |  |

| `Ex4pm.Stream.SensorSink` | struct | defstruct threshold: 0.0, rising_activity: "threshold_crossed_above", falling_activity: "threshold_crossed_below", last_state: %{}, emitted: 0 |  |  |  |  |

| `reading` | type | @type reading :: {number(), DateTime.t() | non_neg_integer(), String.t()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ threshold: number(), rising_activity: String.t(), falling_activity: String.t(), last_state: %{optional(String.t()) => :above | :at_or_below}, emitted: non_neg_integer() } |  |  |  |  |

| `new` | function | new/3 |  |  |  |  |

| `Ex4pm.Subject` | struct | defstruct id, kind, hash, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t() | nil, kind: atom(), hash: String.t(), metadata: map() } |  |  |  |  |

| `add_activity` | function | add_activity/2 |  |  |  |  |

| `add_choice` | function | add_choice/2 |  |  |  |  |

| `add_guard` | function | add_guard/2 |  |  |  |  |

| `add_loop` | function | add_loop/2 |  |  |  |  |

| `add_object` | function | add_object/2 |  |  |  |  |

| `add_partial_order` | function | add_partial_order/2 |  |  |  |  |

| `add_policy` | function | add_policy/2 |  |  |  |  |

| `add_relationship` | function | add_relationship/2 |  |  |  |  |

| `digest` | function | digest/1 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `to_canonical_map` | function | to_canonical_map/1 |  |  |  |  |

| `validate` | function | validate/1 |  |  |  |  |

| `Ex4pmCore.ProcessIR` | struct | defstruct id, name: "", version: "1.0.0", activities: %{}, choices: %{}, loops: %{}, partial_orders: %{}, guards: %{}, policies: %{}, objects: %{}, relationships: %{}, root: nil, metadata: %{}, subject: nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), name: String.t(), version: String.t(), activities: %{optional(String.t()) => Activity.t()}, choices: %{optional(String.t()) => Choice.t()}, loops: %{optional(String.t()) => Loop.t()}, partial_orders: %{optional(String.t()) => PartialOrder.t()}, guards: %{optional(String.t()) => Guard.t()}, policies: %{optional(String.t()) => Policy.t()}, objects: %{optional(String.t()) => ObjectType.t()}, relationships: %{optional(String.t()) => Relationship.t()}, root: String.t() | term() | nil, metadata: map(), subject: Subject.t() | nil } |  |  |  |  |

| `Ex4pmCore.ProcessIR.Activity` | struct | defstruct id, label, object_types: [], lifecycle_states: ["create", "start", "complete"], attributes: %{}, guards: [], metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), label: String.t(), object_types: [String.t()], lifecycle_states: [String.t()], attributes: map(), guards: [String.t()], metadata: map() } |  |  |  |  |

| `Ex4pmCore.ProcessIR.Choice` | struct | defstruct id, branches, type: :xor, conditions: %{}, default_branch: nil, metadata: %{} |  |  |  |  |

| `choice_type` | type | @type choice_type :: :xor | :or | :deferrable | :choice_graph |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), branches: [String.t()], type: choice_type(), conditions: %{optional(String.t()) => String.t()}, default_branch: String.t() | nil, metadata: map() } |  |  |  |  |

| `Ex4pmCore.ProcessIR.Guard` | struct | defstruct id, expression, description: "", metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), expression: map() | String.t() | term(), description: String.t(), metadata: map() } |  |  |  |  |

| `Ex4pmCore.ProcessIR.Loop` | struct | defstruct id, body, redo, exit: nil, loop_condition: nil, max_iterations: nil, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), body: String.t(), redo: String.t(), exit: String.t() | nil, loop_condition: String.t() | nil, max_iterations: non_neg_integer() | nil, metadata: map() } |  |  |  |  |

| `Ex4pmCore.ProcessIR.ObjectType` | struct | defstruct id, name: nil, attributes: %{}, lifecycle_states: [], cardinality: :many, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), name: String.t() | nil, attributes: map(), lifecycle_states: [String.t()], cardinality: :one | :many | String.t(), metadata: map() } |  |  |  |  |

| `Ex4pmCore.ProcessIR.PartialOrder` | struct | defstruct id, nodes, edges, metadata: %{} |  |  |  |  |

| `edge` | type | @type edge :: {String.t(), String.t()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), nodes: [String.t()], edges: [edge()], metadata: map() } |  |  |  |  |

| `Ex4pmCore.ProcessIR.Policy` | struct | defstruct id, type, target_activities: [], target_objects: [], rules: %{}, description: "", metadata: %{} |  |  |  |  |

| `policy_type` | type | @type policy_type :: :sod | :bod | :sla | :mandatory | :forbidden | :cardinality | :custom |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), type: policy_type(), target_activities: [String.t()], target_objects: [String.t()], rules: map(), description: String.t(), metadata: map() } |  |  |  |  |

| `Ex4pmCore.ProcessIR.Relationship` | struct | defstruct id, source, target, type: :o2o, qualifier: "related", cardinality: "1..*", metadata: %{} |  |  |  |  |

| `rel_type` | type | @type rel_type :: :o2o | :o2m | :m2m | :e2o |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), source: String.t(), target: String.t(), type: rel_type(), qualifier: String.t(), cardinality: String.t(), metadata: map() } |  |  |  |  |

| `build_index` | function | build_index/1 |  |  |  |  |

| `evaluate_box` | function | evaluate_box/3 |  |  |  |  |

| `evaluate_box_indexed` | function | evaluate_box_indexed/3 |  |  |  |  |

| `evaluate_query` | function | evaluate_query/2 |  |  |  |  |

| `evaluate_query_indexed` | function | evaluate_query_indexed/2 |  |  |  |  |

| `enabled_transitions` | function | enabled_transitions/2 |  |  |  |  |

| `fire` | function | fire/3 |  |  |  |  |

| `new` | function | new/4 |  |  |  |  |

| `simulate_traces` | function | simulate_traces/2 |  |  |  |  |

| `validate_structure` | function | validate_structure/1 |  |  |  |  |

| `verify_soundness` | function | verify_soundness/2 |  |  |  |  |

| `Ex4pmEngine.WorkflowNet` | struct | defstruct id, places, transitions, arcs, source_place, sink_place, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t() | nil, places: %{optional(String.t()) => Place.t()}, transitions: %{optional(String.t()) => Transition.t()}, arcs: [Arc.t()], source_place: String.t(), sink_place: String.t(), metadata: map() } |  |  |  |  |

| `Ex4pmEngine.WorkflowNet.Arc` | struct | defstruct source, target, weight: 1, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ source: String.t(), target: String.t(), weight: pos_integer(), metadata: map() } |  |  |  |  |

| `Ex4pmEngine.WorkflowNet.Place` | struct | defstruct id, name: nil, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), name: String.t() | nil, metadata: map() } |  |  |  |  |

| `Ex4pmEngine.WorkflowNet.SoundnessReport` | struct | defstruct sound?, definition_3_3_valid?: true, one_safe?: true, option_to_complete?: true, proper_completion?: true, no_dead_transitions?: true, dead_transitions: [], livelock_detected?: false, livelocks: [], deadlocks: [], unbounded_places: [], reachable_markings_count: 0, terminal_markings: [], violations: [], details: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ sound?: boolean(), definition_3_3_valid?: boolean(), one_safe?: boolean(), option_to_complete?: boolean(), proper_completion?: boolean(), no_dead_transitions?: boolean(), dead_transitions: [String.t()], livelock_detected?: boolean(), livelocks: [list()], deadlocks: [map()], unbounded_places: [String.t()], reachable_markings_count: non_neg_integer(), terminal_markings: [map()], violations: [String.t()], details: map() } |  |  |  |  |

| `Ex4pmEngine.WorkflowNet.Transition` | struct | defstruct id, label: nil, silent?: false, metadata: %{} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), label: String.t() | nil, silent?: boolean(), metadata: map() } |  |  |  |  |

| `evaluate` | function | evaluate/3 |  |  |  |  |

| `Ex4pmEvidence.Conformance.Vector` | struct | defstruct fitness, precision, policy_conformance, lifecycle_conformance, causal_conformance, overall_score, details: %{}, violations: [], standing: :alive, subject_hash: nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ fitness: float(), precision: float(), policy_conformance: float(), lifecycle_conformance: float(), causal_conformance: float(), overall_score: float(), details: map(), violations: [Ex4pmEvidence.Conformance.Violation.t()], standing: Ex4pm.Standing.t(), subject_hash: String.t() | nil } |  |  |  |  |

| `Ex4pmEvidence.Conformance.Violation` | struct | defstruct dimension, rule, message, case_id: nil, object_id: nil, events: [], details: %{} |  |  |  |  |

| `dimension` | type | @type dimension :: :fitness | :precision | :policy | :lifecycle | :causal |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ dimension: dimension(), rule: atom() | String.t(), message: String.t(), case_id: String.t() | nil, object_id: String.t() | nil, events: [String.t()], details: map() } |  |  |  |  |

| `FlowerFallback` | struct | defstruct activities, reason |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{activities: [String.t()], reason: String.t()} |  |  |  |  |

| `IndexContext` | struct | defstruct event_map, events_by_type, objects_by_type, e2o_set, o2o_set, o2o_by_source, e2o_by_object, time_map |  |  |  |  |

| `ProcessTree` | struct | defstruct kind, label, children: |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ kind: :leaf | :sequence | :exclusive_choice | :tau, label: String.t() | nil, children: [t()] } |  |  |  |  |

| `QueryTree` | struct | defstruct root_box, children: [], min_children: 0, max_children: :infinity |  |  |  |  |

| `VarDecl` | struct | defstruct name, kind, types: |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
