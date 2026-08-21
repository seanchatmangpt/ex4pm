# ex4pm

ex4pm is a BEAM-native, evidence-oriented process-intelligence system derived from the semantic laws of wasm4pm rather than from its directory structure.

It keeps process semantics portable while using OTP for supervision, streaming, distributed execution, and continuously operating process intelligence.

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

`SELECT`, `CONSTRUCT`, and `DO` are intentionally separate. Hooks and planners can manufacture intents, but only the BRCE broker may execute a state-changing callback.

## DfCM engine graph

The engine registry preserves these candidates simultaneously:

- `:beam` - native deterministic Elixir algorithms;
- `:wasm` - Wasmex/Wasmtime execution of admitted WebAssembly artifacts;
- `:nif` - configured native NIF module;
- `:remote` - configured remote engine callback.

Selection is capability- and evidence-driven. An unavailable edge yields a typed standing/refusal instead of silently disappearing.

## Umbrella applications

- `ex4pm_contracts` - canonical ontology, SHACL, WIT component contract, and receipt schema;
- `ex4pm_core` - canonical observation IR, OCEL/XES normalization, POWL, capabilities, hashing;
- `ex4pm_evidence` - receipts, replay, receipt store, BRCE;
- `ex4pm_engine` - engine calculus, BEAM discovery/conformance/simulation, WASM/NIF/remote adapters, differential verification;
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
{:ok, replayed} = Ex4pm.replay(run.receipt.hash)
{:ok, contract} = Ex4pm.contracts()
```

`operate/3` is different: it requires an explicit authority map and all task callbacks cross the BRCE boundary.

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

Repository-wide standing begins at `PARTIAL_ALIVE`. Individual BEAM routes can become `ALIVE` after exact execution and replay. Optional WASM/NIF/remote routes remain `UNSUPPORTED`, `BLOCKED`, or `PARTIAL_ALIVE` until their exact runtime subjects execute.

See `docs/ARCHITECTURE.md` for the full graph and falsifiers.
