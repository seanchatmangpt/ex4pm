# ex4pm Consumer API Reference

This is a Diataxis REFERENCE document for downstream consumers of the `ex4pm` hex
package family (`ex4pm_core`, `ex4pm_contracts`, and the top-level `ex4pm` umbrella
app) — apps that add ex4pm as a dependency and call into it. It is information-oriented
and exhaustive over the public API surface only: no internal Mix tasks, no
qualification-suite tooling, no umbrella build/test infrastructure, no contributor
workflow. Each H2 below is one consumer-relevant module; each table row is one public
function a dependent app can call, with its arity and one-line purpose. Use this as a
lookup table — grep the module or function name you need.

## Ex4pm

Top-level public orchestration API. This is the single entry point most consumers
depend on ex4pm for: ingest event data, run analytical operations, execute POWL models
under receipted authority, stream events, and inspect/replay evidence.

| Function | Purpose |
| --- | --- |
| `contracts/0` | Returns the hashed contract manifest (ontology + SHACL + WIT + JSON Schema), via `Ex4pm.Contracts.verify/0`. |
| `ingest/2` | Normalizes raw input (`raw`, `opts \\ []`) into a canonical `Ex4pm.EventLog` via `Ex4pm.OCEL.normalize/1`; pass `project?: true` to also produce Ash dataset projections. |
| `ingest_xes/2` | Parses XES XML (`xml`, `opts \\ []`) into a canonical `Ex4pm.EventLog` via `Ex4pm.XES.parse/2`; same `project?` option as `ingest/2`. |
| `discover/2` | Runs process discovery over a log/subject (`subject`, `opts \\ []`), returns a receipted `%Ex4pm.Run{}`. |
| `conform/3` | Runs conformance checking of a log against a model (`subject`, `model`, `opts \\ []`), returns a receipted `%Ex4pm.Run{}`. |
| `simulate/2` | Runs simulation over a model (`model`, `opts \\ []`), returns a receipted `%Ex4pm.Run{}`. |
| `optimize/3` | Runs optimization over a log + model (`subject`, `model`, `opts \\ []`), returns a receipted `%Ex4pm.Run{}` whose value may include intervention candidates. |
| `plan/2` | Runs analytical planning (`problem` map, `opts \\ []`) via the pinned `:ex4pm_plan` engine; returns a receipted `%Ex4pm.Run{}`, or a `{:error, %Ex4pm.Refusal{}}` for a non-map problem. |
| `cmca/2` | Computes a BCINR CMCA consequence allocation (`problem` map, `opts \\ []`) via the pinned `:cmca_wasm` bridge; analytical CONSTRUCT only, no DO authority. Returns a receipted `%Ex4pm.Run{}`, or a `{:error, %Ex4pm.Refusal{}}` for a non-map problem. |
| `operate/3` | Compiles and executes a `%Ex4pm.POWL{}` model or an already-compiled `%Ex4pm.Runtime.Plan{}` (`subject`, `authority`, `opts \\ []`) under BRCE — crosses into DO. Returns `{:ok, %{plan:, execution:, standing:}}`. |
| `stream/2` | Starts a Broadway-based streaming ingestion pipeline (`events`, `opts` — a keyword list). |
| `capabilities/2` | Lists candidate engines for an operation (`operation \\ :discover`, `opts \\ []`), evidence-ranked, via `Ex4pm.Engine.candidates/2`. |
| `differential/5` | Compares two engines' results for the same operation/subject (`operation`, `subject`, `left_engine`, `right_engine`, `opts \\ []`) via `Ex4pm.Engine.Differential.compare/5`. |
| `replay/2` | Looks up a receipt by hash (`hash`, `opts \\ []`) and independently verifies its replay chain via `Ex4pm.Evidence.Replay.Chain.verify/2`. |

### `Ex4pm.Run`

The public evidence envelope returned by every analytical operation above
(`discover`, `conform`, `simulate`, `optimize`, `plan`, `cmca`). Struct fields:
`operation`, `subject_hash`, `standing`, `value`, `receipt`, `pending`,
`engine_result`, `projections` (defaults to `[]`).

```elixir
{:ok, log} = Ex4pm.ingest(raw_ocel_map)
{:ok, %Ex4pm.Run{standing: standing, value: model}} = Ex4pm.discover(log)
```

## Ex4pm.Contracts

The public, hashable inventory of ex4pm's canonical semantic surface (RDF/Turtle
ontology, SHACL shapes, WIT world, receipt JSON Schema). A consumer uses this to
fetch or verify these contract artifacts and their combined hash before trusting them
as a source of truth for codegen (e.g. `ggen`) or schema validation, instead of
duplicating or hand-copying the ontology/shapes files.

| Function | Purpose |
| --- | --- |
| `version/0` | Returns the current contract version string (e.g. `"0.1.0"`). |
| `artifacts/0` | Returns a map of artifact id => resolved absolute file path (`ontology`, `shacl`, `wit`, `receipt_schema`). |
| `manifest/0` | Reads all canonical artifacts; returns `{:ok, %{id => %{path, size, hash, version}}}` or `{:error, %Ex4pm.Refusal{}}` if one is missing. |
| `verify/0` | Full contract verification: builds the manifest, checks required terms are present in each artifact, returns `{:ok, %{version, artifacts, contract_hash, standing: :alive}}` or `{:error, %Ex4pm.Refusal{}}`. |
| `read/1` | Reads the raw bytes of a single named contract artifact (`artifact_id`); returns `{:ok, bytes}` or `{:error, %Ex4pm.Refusal{}}`. |

## Ex4pm.Standing

Shared vocabulary for comparing and formatting evidence standing atoms
(`:alive`, `:blocked`, etc., any case) consistently with the rest of ex4pm.

| Function | Purpose |
| --- | --- |
| `rank/1` | Maps a standing atom to its comparable integer rank. |
| `min/2` | Returns whichever of two standings has the lower rank. |
| `to_string/1` | Renders a standing atom as an upcased string. |

## Ex4pm.Refusal

Typed refusal struct/exception used throughout ex4pm's public API instead of raw
`{:error, term}` tuples with unstructured reasons. A consumer pattern-matches on this
to handle refused operations.

| Function | Purpose |
| --- | --- |
| `new/3` | Constructs a typed refusal struct (`code`, `message`, `opts` — `subject`, `details`). |
| `exception/1` | Builds an `%Ex4pm.Refusal{}` from keyword opts; implements the `Exception` behaviour (`code`, `message`, ...). |

## Ex4pm.Subject

Immutable identity carrier used to reference the thing an operation or receipt is
about, without exposing or duplicating the raw value.

| Function | Purpose |
| --- | --- |
| `new/3` | Constructs an immutable `%Ex4pm.Subject{}` struct (`kind`, `value` — hashed via `Ex4pm.Core.Hash.digest/2`, `metadata`). |

## Ex4pm.Core.Hash

Deterministic content hashing used across ex4pm for subject identity, receipt
chaining, and contract manifests.

| Function | Purpose |
| --- | --- |
| `digest/2` | Deterministic SHA-256 content hash of a term (`term`, `opts`); canonicalizes maps/structs before hashing so key order never affects the digest. |

## Ex4pm.Core.Capability / Ex4pm.Claim

Plain public structs describing engine capabilities and evidence claims, returned by
`Ex4pm.capabilities/2` and engine-selection functions. Consumers pattern-match on
these rather than constructing them directly.

| Struct | Fields | Purpose |
| --- | --- | --- |
| `%Ex4pm.Core.Capability{}` | `id`, `kind`, `standing`, `reason`, `evidence`, `constraints` | Describes one engine's capability for an operation. |
| `%Ex4pm.Claim{}` | `id`, `kind`, `standing`, `reason`, `evidence`, `constraints` | A verified or pending evidence claim. |

## Ex4pm.OCEL

Normalizes OCEL-v2-tolerant raw event-log payloads into the canonical
`Ex4pm.EventLog` IR, validates batch ingestion envelopes, and flattens an event log
into per-object-type traces. Also defines the public structs (`Ex4pm.Event`,
`Ex4pm.ObjectRef`, `Ex4pm.ObjectRelationship`, `Ex4pm.EventRelationship`,
`Ex4pm.EventLog`) that a consumer constructs or pattern-matches against directly.

| Function | Purpose |
| --- | --- |
| `normalize/1` | Normalizes a raw OCEL-v2-like map (or an already-constructed `%Ex4pm.EventLog{}`) into the canonical IR; returns `{:ok, %Ex4pm.EventLog{}}` or `{:error, %Ex4pm.Refusal{}}`. |
| `flatten/2` | Flattens an `%Ex4pm.EventLog{}` (`log`, `object_type \\ nil`) into per-object event traces filtered by `object_type`, or the whole sorted event list when `object_type` is `nil`; returns `{:ok, traces}` or `{:error, %Ex4pm.Refusal{}}`. |
| `validate_envelope/1` | Validates a batch ingestion envelope map (`schema`, `producer`, `sequence`, `events`, `objects`, `object_relationships`); returns a normalized envelope map or `{:error, %Ex4pm.Refusal{}}`. |

## Ex4pm.OCEL2

Derives OCEL 2.0 / Event-Knowledge-Graph-style views from the canonical
`Ex4pm.EventLog` IR without introducing a competing representation. Requires a log
already normalized via `Ex4pm.OCEL.normalize/1`.

| Function | Purpose |
| --- | --- |
| `object_trace/2` | Returns the time-ordered event sequence (trace) for a single object id (`log`, `object_id`) within an `%Ex4pm.EventLog{}`. |
| `attribute_history/3` | Returns the chronological list of `AttributeChange` structs tracking every value change of one dynamic object attribute (`log`, `object_id`, `attribute`). |
| `object_relationships_for/2` | Returns the qualifier-typed O2O relationships touching a given object id (`log`, `object_id`), as source or target. |

## Ex4pm.XES

Entry point to securely ingest raw XES (IEEE process-mining XML) log bytes and
normalize them into ex4pm's canonical OCEL-based event log structure.

| Function | Purpose |
| --- | --- |
| `parse/2` (also `parse/1` via default opts) | Parses an XES XML document (`binary`, `opts \\ []`) into the canonical `%Ex4pm.EventLog{}` IR; returns `{:ok, log}` with `source_format: :xes`, or `{:error, %Ex4pm.Refusal{}}` for empty, invalid, or non-binary input. |

## Ex4pm.POWL

A canonical, validated partial-order workflow (POWL) model. Build one from tasks and
edges with built-in acyclicity and identity checks, then compute its topological
execution layers for scheduling or display.

| Function | Purpose |
| --- | --- |
| `new/3` | Constructs a validated `%Ex4pm.POWL{}` from a list of tasks and edges (`tasks`, `edges`, `opts`), with duplicate/cycle/unknown-reference checks; returns `{:ok, %Ex4pm.POWL{}}` or `{:error, %Ex4pm.Refusal{}}`. |
| `layers/1` | Computes the topological layering (list of lists of task ids) of a constructed `%Ex4pm.POWL{}` model, for scheduling or visualizing execution order. |

### `Ex4pm.POWL.Task`

`%Ex4pm.POWL.Task{id, label, intent, metadata}` — the task node shape a consumer
builds and passes into `Ex4pm.POWL.new/3`.

## Ex4pm.Evidence

The receipted state-change authority boundary. `Ex4pm.Evidence.BRCE.execute/4` is the
only way to invoke a state-changing callback with a receipted pending->outcome trail;
`Ex4pm.Evidence.Replay.verify/1` lets any party independently recompute and confirm a
receipt's hash/standing without trusting the original invocation; `Store`'s query
functions let a consumer inspect the receipt ledger.

| Function | Purpose |
| --- | --- |
| `Ex4pm.Evidence.Receipt.pending/3,4` | Constructs a pending receipt (`subject_hash`, `operation`, `authority`, `metadata \\ %{}`) recording intent before a DO. |
| `Ex4pm.Evidence.Receipt.outcome/3,4` | Constructs a terminal outcome receipt (`pending`, `result`, `standing`, `metadata \\ %{}`) from a pending receipt. |
| `Ex4pm.Evidence.Store.start_link/1` | Starts the ETS-backed receipt ledger GenServer (`opts`). |
| `Ex4pm.Evidence.Store.put/1,2` | Persists a receipt (`receipt`, `store \\ Store`). |
| `Ex4pm.Evidence.Store.get/1,2` | Fetches a receipt by hash (`hash`, `store \\ Store`). |
| `Ex4pm.Evidence.Store.get_by_subject/1,2` | Fetches receipts for a `subject_hash` (`subject_hash`, `store \\ Store`). |
| `Ex4pm.Evidence.Store.get_by_parent/1,2` | Fetches receipts whose `parent_hash` matches (`parent_hash`, `store \\ Store`) — the pending -> outcome chain. |
| `Ex4pm.Evidence.Store.all/0,1` | Lists all receipts, newest first (`store \\ Store`). |
| `Ex4pm.Evidence.Store.history/1,2` | Lists the most recent N receipts (`n`, `store \\ Store`). |
| `Ex4pm.Evidence.Replay.verify/1` | Independently recomputes a receipt's hash and confirms standing (`receipt`); returns a refusal (`:invalid_receipt` / `:replay_mismatch`) on mismatch. |
| `Ex4pm.Evidence.BRCE.execute/4,5` | The exclusive authority-gated DO boundary (`subject`, `operation`, `authority`, `callback`, `opts \\ []`): admits authority, persists a pending receipt, invokes the callback, persists the outcome receipt (`:alive`/`:blocked`) even on exception or throw. |
| `Ex4pm.Evidence.BRCE.admit/2` | Checks whether an authority map permits a given operation (`authority`, `operation`), independent of `execute/4`. |

## Ex4pm.Engine

Defines the `Ex4pm.Engine` behaviour (`id/0`, `supports?/2`, `available?/2`,
`execute/3` callbacks) and its `Registry`, which holds the ordered list of DfCM
candidate engine modules (`:beam`, `:wasm_*`, `:ex4pm_plan`, `:nif`, `:remote`, etc.)
and performs evidence-ranked or explicit engine selection/execution per operation.
Most consumers call `Ex4pm.Engine.execute/3` (or `Ex4pm.capabilities/2`) rather than
these directly, but they are the underlying public surface.

| Function | Purpose |
| --- | --- |
| `Ex4pm.Engine.candidates/2` | Lists engine candidates for an operation (`operation`, `opts \\ []`) with their capability standing (`:unsupported` / `:blocked` / `:partial_alive` / `:alive`). |
| `Ex4pm.Engine.select/2` | Selects the engine module to use for an operation (`operation`, `opts \\ []`) — evidence-ranked, or explicit via the `:engine` opt. |
| `Ex4pm.Engine.execute/3` | Selects an engine then executes the operation against a subject (`operation`, `subject`, `opts \\ []`); returns `{:ok, %Ex4pm.Engine.Result{}}` or `{:error, term()}`. |
| `Ex4pm.Engine.Registry.engines/0` | Returns the full ordered list of registered engine candidate modules. |
| `Ex4pm.Engine.Registry.candidates/2` | Same capability-listing logic as `Ex4pm.Engine.candidates/2`. |
| `Ex4pm.Engine.Registry.select/2` | Same selection logic as `Ex4pm.Engine.select/2`. |

## See Also

- `Ex4pm.contracts/0` and `Ex4pm.Contracts.verify/0` — fetch and verify the canonical
  ontology/SHACL/WIT/receipt-schema artifacts before generating code against them.
- `docs/ROADMAP-xaas-integration.md` — the concrete integration plan for a downstream
  Elixir/Phoenix/Ash consumer adding `ex4pm_core`/`ex4pm_contracts` as a dependency and
  pushing OCEL v2 events to `POST /api/v1/ocel/events`.
