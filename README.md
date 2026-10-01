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
- `:wasm_<algo>` - 33 per-algorithm adapters (`Ex4pmEngine.Wasm.*`) over the admitted wasm4pm-ex4pm-bindings artifact;
- `:ferroplan` - PDDL/HTN/FOND planning via the bundled, sha256-pinned ferroplan wasm (explicit `engine: :ferroplan`);
- `:nif` - configured native NIF module;
- `:remote` - configured remote engine callback.

Selection is capability- and evidence-driven. An unavailable edge yields a typed standing/refusal instead of silently disappearing.

## Installation

```elixir
def deps do
  [{:ex4pm, "~> 26.10.1"}]
end
```

## Library layout

ex4pm is a single flat, hex-publishable Mix library (app `:ex4pm`) — no separate OTP apps.
`lib/ex4pm/` is organized into namespaced module directories:

- `lib/ex4pm/aloop.ex` - independent online process intelligence over ALOOP OCEL event logs (episodes, loop depth/recurrence, causal edges, DFG/variants/precision, conformance, analysis receipts);
- `lib/ex4pm/contracts.ex` - canonical ontology, SHACL, WIT component contract, and receipt schema;
- `lib/ex4pm/core/` - canonical observation IR, OCEL/XES normalization, POWL, capabilities, hashing;
- `lib/ex4pm/evidence/` - receipts, replay, receipt store, BRCE;
- `lib/ex4pm/engine/` - engine calculus, BEAM discovery/conformance/simulation, ex4pm-plan, WASM/NIF/remote adapters, differential verification;
- `lib/ex4pm/runtime/` - POWL planning and receipted OTP execution;
- `lib/ex4pm/stream/` - Broadway ingestion with backpressure and acknowledgement;
- `lib/ex4pm/domain/` - Ash/ETS semantic-control-plane projection;
- `lib/ex4pm.ex` - public orchestration API;
- `lib/ex4pm/cli.ex` - command-line projection.

The Phoenix/LiveView demo web app lives outside the published library, under
`test/demo_web/`, compiled only in the `:test` environment.

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

The maintained planning worker is [seanchatmangpt/ex4pm-plan](https://github.com/seanchatmangpt/ex4pm-plan), an 80/20 downstream distribution of Airbus scikit-decide. The ex4pm adapter is pinned to exact worker source `99816fb389670174be44ddaaf3b42f00496e6f21` and protocol `ex4pm-plan/v1`.

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

`Ex4pm.Contracts` (`lib/ex4pm/contracts.ex`) carries four executable identity surfaces:

- RDF/Turtle ontology for observations, models, engines, authority, actuation, and receipts;
- SHACL shapes for event/model/receipt closure;
- WIT component-world contract for portable process engines;
- JSON Schema for receipt interchange.

`Ex4pm.contracts/0` reads and hashes all four artifacts, verifies required semantic terms, and produces one contract hash. These are canonical public semantic surfaces; Ash records and engine-specific structs are projections.

## wasm4pm bridge

`Ex4pm.Engine.Wasm` is the raw Wasmex-backed route: because wasm4pm builds can expose build-specific ABIs, it does not invent an OCEL string ABI and only executes a configured export/parameter contract.

The working path for the `wasm4pm-ex4pm-bindings` artifact is admission plus a real transport: `Ex4pmEngine.Wasm.Admission` (sha256 pin, compile, import allowlist, required exports) and `Ex4pmEngine.Wasm.RealTransport` (ptr/len UTF-8 JSON ABI through a real Wasmex instance). A run reaches `ALIVE` only when the exact admitted artifact, export, request and replay evidence are bound to one run. The WIT component contract remains a forward portable engine boundary; arbitrary historical wasm-bindgen bundles do not implement that component world.

There are 33 algorithm adapters in `Ex4pmEngine.Wasm.AlgoRegistry` (`ls lib/ex4pm_engine/wasm` shows 33 algorithm modules plus `adapter`, `admission`, `algo_registry`, `real_transport`, `ferroplan_transport`); the registry is generated from `priv/ontology/ex4pm.ttl` and the bindings pack, not hand-written.

### The artifact

New in 26.10.1: the admitted artifact is bundled at `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm` (zero imports, 70 function exports), and `Ex4pmEngine.Wasm.Host` (supervised by the application) boots it with no configuration. To use another build, build it with `crates/wasm4pm-ex4pm-bindings/scripts/build-wasm.sh` and set `EX4PM_WASM_ARTIFACT` / `config :ex4pm, :wasm4pm_artifact`. The digest is pinned in `priv/wasm4pm/MANIFEST.json` (override with `config :ex4pm, :wasm4pm_sha256`); a missing, mismatched or import-bearing artifact yields a typed `%Ex4pm.Refusal{}`. `artifact.path` in the manifest is informational only.

```elixir
{:ok, transports} = Ex4pmEngine.Wasm.RealTransport.all_transports("/path/to/wasm4pm_ex4pm_bindings.wasm")

{:ok, result} =
  Ex4pmEngine.Wasm.Discover.execute(:discover, %{traces: [["a", "b", "c"], ["a", "b"]]}, transports)

result.standing           #=> :alive
result.evidence.replay_verified #=> true
```

Runnable: `mix run examples/real_wasm_discover.exs`. Guide: `docs/guides/real-wasm.md`.

## Planning with ferroplan

```elixir
alias Ex4pm.Engine.Ferroplan

domain  = File.read!("test/support/fixtures/ferroplan/logistics_domain.pddl")
problem = File.read!("test/support/fixtures/ferroplan/logistics_p1.pddl")
{:ok, %{"plan" => plan}} = Ferroplan.plan(domain, problem)
```

The ferroplan wasm ships in `priv/ferroplan` with a sha256 pin; planning is CONSTRUCT-only. Runnable: `mix run examples/ferroplan_plan.exs`. Guides: `docs/guides/planning-with-ferroplan.md`, `docs/guides/choosing-an-engine.md`, reference `docs/FERROPLAN-RUNTIME.md`.

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

The CI workflow runs formatting, warnings-as-errors compilation, the full test suite, and uploads `mix.lock` as a reproducibility artifact.

## Standing

Repository-wide standing begins at `PARTIAL_ALIVE`. Individual BEAM routes can become `ALIVE` after exact execution and replay. The ex4pm-plan route requires exact worker/capsule identity and replay evidence before `ALIVE`; optional WASM/NIF/remote routes remain `UNSUPPORTED`, `BLOCKED`, or `PARTIAL_ALIVE` until their exact runtime subjects execute.

See `docs/ARCHITECTURE.md` for the full graph and falsifiers.
