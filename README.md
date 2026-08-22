# ex4pm

ex4pm is a BEAM-native, evidence-oriented process-intelligence system derived from the semantic laws of wasm4pm rather than from its directory structure.

It keeps process semantics portable while using OTP for supervision, streaming, distributed execution, planning, and continuously operating process intelligence.

## Governing calculus

```text
observation
  -> parse
  -> route
  -> admit | refuse
  -> construct
  -> BRCE
  -> DO
  -> receipt
  -> replay
  -> bounded standing
```

`SELECT`, `CONSTRUCT`, and `DO` are intentionally separate. Hooks and planners can manufacture intents and candidate plans, but only the BRCE broker may execute a state-changing callback.

## DfCM engine graph

The engine registry preserves these candidates simultaneously:

- `:beam` - native deterministic Elixir algorithms;
- `:ex4pm_plan` - pinned ex4pm-plan cloud planning worker protocol;
- `:wasm` - Wasmex/Wasmtime execution of admitted WebAssembly artifacts;
- `:nif` - configured native NIF module;
- `:remote` - configured remote engine callback.

Selection is capability- and evidence-driven. An unavailable edge yields a typed standing/refusal instead of silently disappearing.

## Umbrella applications

- `ex4pm_contracts` - canonical ontology, SHACL, WIT component contract, and receipt schema;
- `ex4pm_core` - canonical observation IR, OCEL/XES normalization, POWL, capabilities, hashing;
- `ex4pm_evidence` - receipts, replay, receipt store, BRCE;
- `ex4pm_engine` - engine calculus, BEAM discovery/conformance/simulation, ex4pm-plan, WASM/NIF/remote adapters, differential verification;
- `ex4pm_runtime` - POWL planning and receipted OTP execution;
- `ex4pm_stream` - Broadway ingestion with backpressure and acknowledgement;
- `ex4pm_domain` - Ash/ETS semantic-control-plane projection;
- `ex4pm` - public orchestration API;
- `ex4pm_cli` - command-line projection.

## Public API

```elixir
{:ok, dataset} = Ex4pm.ingest(ocel_map)
{:ok, dataset} = Ex4pm.ingest_xes(xes_xml)
{:ok, run} = Ex4pm.discover(dataset, algorithm: :dfg, object_type: "Order")
{:ok, report} = Ex4pm.conform(dataset, run.value)
{:ok, paths} = Ex4pm.simulate(run.value, max_depth: 12, max_paths: 128)
{:ok, candidates} = Ex4pm.optimize(dataset, run.value)
{:ok, plan} = Ex4pm.plan(problem, ex4pm_plan_fun: planner_transport)
{:ok, replayed} = Ex4pm.replay(run.receipt.hash)
{:ok, contract} = Ex4pm.contracts()
```

`plan/2` is an analytical CONSTRUCT path. Its planner transport is explicit, its result is receipted, and an exact ex4pm-plan capsule reaches `ALIVE` only when the transport reports the pinned source identity plus an image digest and the worker reports replay verification. The planner adapter never receives ambient cloud credentials.

`operate/3` is different: it requires an explicit authority map and all task callbacks cross the BRCE boundary. A plan returned by `plan/2` has no ambient DO authority.

## ex4pm-plan bridge

The maintained planning worker is [seanchatmangpt/ex4pm-plan](https://github.com/seanchatmangpt/ex4pm-plan), an 80/20 downstream distribution of Airbus scikit-decide. The ex4pm adapter is pinned to exact worker source `e5da34c8b42089f1ebb1fd2306d95f0c4986f8c3` and protocol `ex4pm-plan/v1`.

The injected `ex4pm_plan_fun` is the cloud-placement boundary. It may launch an OCI worker through Kubernetes, AWS, Azure, GCP, Fly.io, or another scheduler, but provider credentials and launch authority remain outside the planner adapter. The callback returns the worker response and, when available, an observed capsule identity:

```elixir
fn request, opts ->
  {:ok, response,
   %{
     observed: true,
     source_sha: Ex4pm.Engine.Ex4pmPlan.source_sha(),
     image_digest: "sha256:..."
   }}
end
```

A response without observed capsule identity remains `PARTIAL_ALIVE`; a mismatched observed source is refused.

## Canonical contracts

The `ex4pm_contracts` application carries four executable identity surfaces:

- RDF/Turtle ontology for observations, models, engines, authority, actuation, and receipts;
- SHACL shapes for event/model/receipt closure;
- WIT component-world contract for portable process engines;
- JSON Schema for receipt interchange.

`Ex4pm.contracts/0` reads and hashes all four artifacts, verifies required semantic terms, and produces one contract hash. These are canonical public semantic surfaces; Ash records and engine-specific structs are projections.

## wasm4pm bridge

`Ex4pm.Engine.Wasm` is a real Wasmex-backed raw WebAssembly route. Because wasm4pm builds can expose build-specific ABIs, ex4pm does not invent an OCEL string ABI. The adapter only executes a configured export/parameter contract. A wasm4pm integration reaches `ALIVE` only when the exact artifact, export, parameters, output decoder, and replay evidence are all bound to one run.

The WIT component contract is a forward portable ex4pm engine boundary; it does not claim that arbitrary historical wasm4pm wasm-bindgen bundles already implement that component world.

## OCEL and XES

OCEL-v2-style object-centric data and XES case logs converge on the same canonical `Ex4pm.EventLog` IR. XES parsing disables DTD processing before XPath projection. A malformed activity/timestamp still reaches canonical admission and receives the same typed refusal as equivalent malformed OCEL.

## Ash control plane

Bulk event rows remain in the canonical event-log/artifact plane. Ash resources model datasets, process models, interventions, capabilities, and receipt projections. Projection is explicit via `Ex4pm.Domain.Projector` so persistence cannot silently change semantic truth.

## Streaming

`Ex4pm.Stream.Pipeline` accepts an event enumeration through Broadway, normalizes each event, provides backpressure, and invokes an explicit sink function. The sink receives observations; it does not gain ambient DO authority.

## Verification

```bash
mix deps.get
mix verify
```

The CI workflow runs formatting, warnings-as-errors compilation, umbrella tests, and uploads `mix.lock` as a reproducibility artifact.

## Standing

Repository-wide standing begins at `PARTIAL_ALIVE`. Individual BEAM routes can become `ALIVE` after exact execution and replay. The ex4pm-plan route requires exact worker/capsule identity and replay evidence before `ALIVE`; optional WASM/NIF/remote routes remain `UNSUPPORTED`, `BLOCKED`, or `PARTIAL_ALIVE` until their exact runtime subjects execute.

See `docs/ARCHITECTURE.md` for the full graph and falsifiers.
