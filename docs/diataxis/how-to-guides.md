# How-To Guides

Problem-oriented recipes for working with ex4pm. Each section names the exact real
module, function, or Mix task in this codebase — no invented commands. Audience: an
AI agent or engineer that needs to discover and use every real capability exposed by
this repo. See `docs/ARCHITECTURE.md` and `AGENTS.md` for the governing calculus this
codebase implements (`observation -> parse -> route -> admit | refuse -> construct ->
BRCE -> DO -> receipt -> replay -> bounded standing`).

## How to ingest OCEL v2 events over HTTP

POST an OCEL 2.0 event envelope to `Ex4pmWeb.OcelController.ingest/2`
(`test/demo_web/lib/ex4pm_web/controllers/ocel_controller.ex`), routed at
`POST /api/v1/ocel/events` (`test/demo_web/lib/ex4pm_web/router.ex`).

```bash
curl -X POST http://127.0.0.1:30080/api/v1/ocel/events \
  -H "Content-Type: application/json" \
  -d '{"schema": "ocel2", "producer": "my-agent", "sequence": 0, "events": [...]}'
```

What happens on the server, in order:

1. `Ex4pm.Stream.Ingest.ingest_envelope/2` (`lib/ex4pm/stream`) validates the
   envelope via `Ex4pm.OCEL.validate_envelope/1`, checks idempotency (non-negative
   `sequence`), normalizes into a canonical `%Ex4pm.EventLog{}`, forwards events to
   `Ex4pm.Engine.OnlineMiner`, and records pending+outcome ingestion receipts via
   `Ex4pm.Evidence.Store`.
2. The controller projects the resulting log or refusal into the domain layer via
   `Ex4pm.Domain.Projector.project_log/1` or `.refusal/1`.
3. It broadcasts `{:ocel_ingested, envelope}` or `{:refusal_emitted, refusal}` over
   `Phoenix.PubSub` topic `"process_intelligence:live"` (consumed by
   `ProcessIntelligenceLive`).
4. Returns `201` on success, `422` on a typed refusal, `400` on malformed input.

Check liveness/readiness before ingesting at scale:

```bash
curl http://127.0.0.1:30080/health          # or /healthz
curl http://127.0.0.1:30080/health/ready    # or /readyz — confirms OnlineMiner + Evidence.Store alive
```

Both are `Ex4pmWeb.HealthController` (`health/2`, `ready/2`).

## How to ingest OCEL/XES in-process (no HTTP)

Use the public orchestration API directly instead of the HTTP boundary:

```elixir
{:ok, event_log} = Ex4pm.ingest(raw_ocel_map, project?: true)
{:ok, event_log} = Ex4pm.ingest_xes(xml_string, project?: true)
```

`Ex4pm.ingest/2` normalizes via `Ex4pm.OCEL.normalize/1`; `Ex4pm.ingest_xes/2` parses
via `Ex4pm.XES.parse/2` (DTD disabled) then normalizes. Both live in `lib/ex4pm.ex`.

## How to run the full verification gate (`mix verify`)

```bash
cd /Users/sac/ex4pm
mix deps.get
mix verify
```

`mix verify` is defined in the root `mix.exs` `aliases/0` and runs, in order:
`format --check-formatted`, `compile --warnings-as-errors`, `ex4pm.lint.truth`,
`test`, `ex4pm.powl.court`, `ex4pm.sabotage.court`. Run this before claiming any
change is done — no status claim is valid without pasting this command's real
output.

## How to run the Chicago-style OTP-distribution qualification (`mix chicago`)

```bash
mix chicago
```

Runs only tests tagged `:chicago` with a deterministic seed (0), exercising real
`peer` node distribution, real Wasmtime, and real Broadway backpressure — never
mocked equivalents (`docs/CHICAGO.md` has the full non-circular-worlds model).
`Ex4pm.Qualification.ChicagoAuditor.audit/0` (invoked by `mix ex4pm.audit.chicago`,
see below) independently measures how much of the Ash-resource/Reactor/algorithm
surface these tests actually exercise.

## How to run the stress benchmark suite

```bash
mix test.stress
```

Runs the benchmark suite under `test/benchmarks`.

## How to run each `ex4pm_qualification` Mix task

All tasks are defined under `lib/mix/tasks/`.

### `mix ex4pm.lint.truth [root]`

Runs `Ex4pm.Qualification.LieFinder.scan/1` over the codebase (or a given root).
AST-scans `lib/**/*.ex` for hardcoded metric numbers, direct
`Ash.create(Receipt, ...)` calls that bypass BRCE, and bare-string `standing`
assignments. Raises on any finding; otherwise prints a truthful-codebase
confirmation. Part of `mix verify`.

```bash
mix ex4pm.lint.truth
```

### `mix ex4pm.audit.bullshit`

Runs `MetricLinter.scan/0`, `ProductionPurger.scan/0`, `BrceEnforcer.scan/0`, and
`LieFinder.scan/0` together across the whole codebase. Prints a per-tier violation
count; raises if any tier found violations.

```bash
mix ex4pm.audit.bullshit
```

### `mix ex4pm.audit.chicago`

Runs `Ex4pm.Qualification.ChicagoAuditor.audit/0`. Cross-references
`test/**/*.exs` against hardcoded lists of 34 Ash resources, 10 Reactor
sagas, and 6 mining algorithms, printing a per-category utilization-percentage
map. Warns (does not raise) if utilization is below 100%.

```bash
mix ex4pm.audit.chicago
```

### `mix ex4pm.powl.court`

Runs the POWL/Reactor correspondence court: baseline
`Ex4pm.Qualification.Powl.Correspondence.court/0`, a 2048-case
`Ex4pm.Qualification.Powl.PropertyCorpus.run/1`, and
`Ex4pm.Qualification.Powl.PropertyCorpus.invalid_identity_court/0`. Proves, via a
two-sided bounded oracle-vs-compiled-Reactor comparison, that POWL process models
and their compiled Reactor executions are behaviorally identical up to a
trace-length bound — and that deliberately-invalid POWL identities are correctly
rejected. Raises on any `{:error, reason}`. Part of `mix verify`.

```bash
mix ex4pm.powl.court
```

### `mix ex4pm.sabotage.court`

Builds a fixed loop/sequence POWL model and asserts that all 6 sabotage mutations
(`extra_trace`, `missing_trace`, `wrong_order`, `duplicate_execution`,
`lost_terminal`, `wrong_bound`) injected via
`Ex4pm.Qualification.Powl.Correspondence.sabotage/3` are `:detected`. Proves the
correspondence court is not vacuously passing — it actually catches mutation.
Raises, listing survivors, if any mutation goes undetected. Part of `mix verify`.

```bash
mix ex4pm.sabotage.court
```

### `mix ex4pm.crown <input> [output]`

Finalizes/verifies the detached v26.8.22 crown receipt. Reads a crown evidence JSON
file (positional `input` arg or `EX4PM_CROWN_INPUT` env var), calls
`Ex4pm.Qualification.Crown.finalize_file/2`, which independently re-derives every
check via `Ex4pm.Qualification.Verifier.verify/1` — 40-hex source/tree SHAs, POWL
soundness/completeness/correspondence/sabotage/compiler_refinement flags,
non-empty `artifact_digest`/`result_hash` for all 5 required engine rails
(`Ex4pm.Qualification.Rails.required/0`: `:beam`, `:ex4pm_plan`, `:wasm`, `:nif`,
`:remote`), global multi-host/region/fault-domain + safety flags, command exit
codes, and falsifiers — before stamping `standing: "ALIVE"` and writing the
verified crown to `output` (default
`artifacts/qualification/ex4pm-final-crown-v1.json`). Raises `"crown refused"` on
verification failure — never silently accepts an unverifiable crown.

```bash
mix ex4pm.crown path/to/crown-input.json artifacts/qualification/ex4pm-final-crown-v1.json
```

## How to add a new DfCM engine candidate

The engine graph lives in `lib/ex4pm/engine`. There are two paths depending on
what kind of engine you're adding.

### Scaffold a new WASM adapter (thin wrapper pattern)

```bash
mix ex4pm.engine.gen.adapter <algorithm_id> [--export NAME]
```

`Mix.Tasks.Ex4pm.Engine.Gen.Adapter`
(`lib/mix/tasks/ex4pm.engine.gen.adapter.ex`) is an
Igniter-based codegen task that scaffolds
`lib/ex4pm_engine/wasm/<algorithm_id>.ex` defining
`Ex4pmEngine.Wasm.<CamelizedId>` with `algorithm_id/0`, `export/0`, `execute/2`
wired through `Ex4pm.Engine.Wasm.execute/3` — following the
`Ex4pmEngine.Wasm.Mean` reference pattern.

### Add a fully custom engine module

1. Implement the `Ex4pm.Engine` behaviour: `id/0`, `supports?/2`, `available?/2`,
   `execute/3`. See any of `Ex4pm.Engine.Beam`, `Ex4pm.Engine.Wasm`,
   `Ex4pm.Engine.Nif`, or `Ex4pm.Engine.Remote` for reference shapes.
2. Register the module in `Ex4pm.Engine.Registry.engines/0` (the fixed ordered
   list of candidate engine modules) so it's discoverable.
3. `Ex4pm.Engine.Registry.select/2` ranks candidates by preference (wasm-native
   engines rank above `:beam`, which ranks above `:ex4pm_plan`/`:cmca_wasm`/
   `:wasm`/`:nif`/`:remote`) and only ever picks an `available?/2`-true, evidence
   -ranked candidate — never silently drops an unavailable one, it reports typed
   standing instead (`Ex4pm.Engine.candidates/2`).
4. Non-native engines must prove exact artifact/identity admission (source SHA,
   digest, or receipt-verified transport) to reach `:alive` standing; otherwise
   they report `:partial_alive`.
5. Verify integration with the cross-engine differential court:
   `Ex4pm.Engine.Differential.compare/5` (compare two engines on the same
   subject) and, at qualification time, `Ex4pm.Qualification.Rails.verify/1`
   (requires all 5 required rails `:alive` and result-hash agreement across
   engines computing the same shared operation).

Inspect what's currently registered and their standing without executing
anything:

```elixir
Ex4pm.capabilities(:discover)   # delegates to Ex4pm.Engine.candidates/2
```

## How to call `Ex4pm.operate/3` with an explicit authority map

`Ex4pm.operate/3` (`lib/ex4pm.ex`) is the sole DO-authority path in the
public API — it is the only public entrypoint that crosses the BRCE boundary.

```elixir
authority = %{capabilities: [:do], principal: "agent-id"}
# or: %{allow: [:some_operation]}

case Ex4pm.operate(powl_or_plan_subject, authority, opts) do
  {:ok, execution} -> execution
  {:error, refusal} -> refusal
end
```

Behavior by subject type:

- `%Ex4pm.POWL{}` — compiled via `Ex4pm.Runtime.compile/1` into a
  `%Ex4pm.Runtime.Plan{}`, then executed via `Ex4pm.Runtime.execute/3`.
- `%Ex4pm.Runtime.Plan{}` — executed directly via `Ex4pm.Runtime.execute/3`.
- Any other subject — `{:error, Refusal.new(:invalid_operable_subject, ...)}`.

Under the hood, `Ex4pm.Runtime.execute/3` runs the compiled plan through
`Reactor.run/4`, routing every individual POWL task through
`Ex4pm.Evidence.BRCE.execute/5`. `BRCE.execute/5`:

1. Admits the authority via `Ex4pm.Evidence.BRCE.admit/2` — requires `:do` in
   `authority.capabilities`, or the operation present in `authority.allow`.
   Returns `:ok` or a typed `Refusal` (`:authority_denied` /
   `:authority_required`).
2. Persists a pending receipt (`Ex4pm.Evidence.Receipt.pending/4`) before
   invocation.
3. Invokes the task callback.
4. Persists an outcome receipt (`Ex4pm.Evidence.Receipt.outcome/4`) — standing
   `:alive` on success, `:blocked` on exception/throw. No attempted invocation
   can go un-receipted.

For distributed (multi-node) execution, use `Ex4pm.Runtime.Distributed.execute/3`
instead — same BRCE-gated per-task receipting, but with task placement across
specific BEAM nodes and real transport-encryption reporting
(`Ex4pm.Runtime.Distributed.security_posture/0`).

## How to replay a receipt

```elixir
{:ok, verification} = Ex4pm.replay(receipt_hash)
```

`Ex4pm.replay/2` (`lib/ex4pm.ex`) looks up the receipt by hash in the
configured `Ex4pm.Evidence.Store`, then verifies it via
`Ex4pm.Evidence.Replay.Chain.verify/2`. Returns
`{:error, Refusal.new(:receipt_not_found, ...)}` if the hash is absent.

`Replay.Chain.verify/2` (`lib/ex4pm/evidence`):

1. Verifies the outcome receipt's own hash by independently recomputing it from
   its payload fields (`Ex4pm.Evidence.Replay.verify/1`).
2. Fetches and verifies its `parent_hash`-linked pending receipt the same way.
3. Confirms subject/operation/authority correspondence between the pending and
   outcome receipt — detecting tampering or parent mismatch.

To inspect the receipt ledger directly:

```elixir
Ex4pm.Evidence.Store.get(hash, store)
Ex4pm.Evidence.Store.get_by_subject(subject_hash, store)
Ex4pm.Evidence.Store.get_by_parent(pending_hash, store)   # chained outcome receipts
Ex4pm.Evidence.Store.history(50, store)                    # most recent N receipts
```

## How to add `ex4pm` as a path dependency from a sibling app (xaas)

`ex4pm` is now a single flat library (no separate `ex4pm_core`/`ex4pm_contracts` umbrella
apps) — the whole package is meant to be depended on directly by sibling Elixir apps for
its `Ex4pm.Core.*` canonical types and `Ex4pm.Contracts` ontology/SHACL/WIT/schema surface,
which `ggen_igniter` on the xaas side is meant to consume.

1. In `~/xaas/mix.exs`, add a `path:` dependency:

   ```elixir
   {:ex4pm, path: "../ex4pm"}
   ```

2. Confirm the contract surface is intact before trusting downstream generation:

   ```elixir
   {:ok, %{version:, artifacts:, contract_hash:, standing: :alive}} = Ex4pm.Contracts.verify()
   ```

   `Ex4pm.Contracts.verify/0` (`lib/ex4pm/contracts.ex`) re-reads all four canonical
   artifacts from disk (`priv/ontology/ex4pm.ttl`, `priv/shacl/ex4pm-shapes.ttl`,
   `priv/wit/ex4pm.wit`, `priv/schema/receipt.schema.json`), computes a combined
   `contract_hash`, and checks each artifact's bytes for required terms — a
   drift/tamper check. `Ex4pm.contracts/0` (`lib/ex4pm.ex`) delegates to this.

3. Use `Ex4pm.OCEL.validate_envelope/1` (`lib/ex4pm/core`) as the public,
   documented envelope-validation function for xaas-side OCEL envelope
   construction — it validates a batch-ingestion envelope map (schema, producer,
   sequence, events, previous_digest) and returns a normalized envelope or a
   typed `Refusal`.

4. At runtime, xaas still reaches ex4pm over the network, not in-process: push
   OCEL v2 events to `POST /api/v1/ocel/events`
   (`Ex4pmWeb.OcelController.ingest/2`, see "How to ingest OCEL v2 events over
   HTTP" above). The `path:` dependency is for shared types and validation only
   — it does not change xaas calling this endpoint over HTTP rather than
   in-process.

5. `beam4pm` (a separate runtime, execution substrate) is out of scope for this
   dependency — it is reached only over the network (HTTP/PubSub) and is never a
   compile-time dependency of xaas or any app outside its own repo. As of
   `docs/ROADMAP-xaas-integration.md`, `beam4pm` integration is `BLOCKED
   (external)` pending an in-progress git merge in `~/beam4pm`; the three steps
   above are not blocked by that and can proceed independently.

See `docs/ROADMAP-xaas-integration.md` for the full requirements this recipe
implements.

## How to run bounded OLAP analytics over an event log

```elixir
Ex4pm.Core.OLAP.slice(log, :activity, "Create Order")
Ex4pm.Core.OLAP.dice(log, [{:activity, "Create Order"}, {:day, ~D[2026-01-01]}])
Ex4pm.Core.OLAP.roll_up(log, :activity, fn events -> length(events) end)
Ex4pm.Core.OLAP.drill_down(log, :month, :day)
```

All four are in `lib/ex4pm/core`, operating over a canonical `%Ex4pm.EventLog{}`.

## How to inspect OCEL2 object-centric relations

```elixir
Ex4pm.OCEL2.object_trace(log, object_id)
Ex4pm.OCEL2.attribute_history(log, object_id, attribute_name)
Ex4pm.OCEL2.object_relationships_for(log, object_id)
```

`lib/ex4pm/ocel2.ex`. `object_trace/2` returns the full time-ordered event sequence
for one object; `attribute_history/3` reconstructs chronological value-change
history as `%Ex4pm.AttributeChange{}` records; `object_relationships_for/2`
returns qualifier-typed O2O relationships in either direction.

## How to compute a 5-dimensional conformance vector

```elixir
Ex4pmEvidence.Conformance.evaluate(event_log_or_raw_ocel_map, model_or_ir, opts \\ [])
# or: Ex4pm.Evidence.Conformance.evaluate/3 (alias)
```

`lib/ex4pm/evidence`. Computes a `Vector` (fitness, precision,
policy_conformance, lifecycle_conformance, causal_conformance, overall_score)
plus a list of structured `Violation` records. Accepts a raw OCEL map
(auto-normalized) or an `%Ex4pm.EventLog{}`.

## How to generate standards-compliant evidence artifacts (RDF/Turtle)

```elixir
Ex4pmEvidence.Engine.build_earl_assertion(opts)       # W3C EARL 1.0 test assertion
Ex4pmEvidence.Engine.build_sosa_observation(opts)     # W3C SOSA/SSN + QUDT observation
Ex4pmEvidence.Engine.build_prov_lineage(opts)         # W3C PROV-O execution lineage
Ex4pmEvidence.Engine.build_dcat_catalog_record(opts)  # W3C DCAT 3 catalog record
Ex4pmEvidence.Engine.build_spdx_manifest(opts)        # SPDX 3.0 manifest w/ real SHA-256
```

All in `lib/ex4pm/evidence`; each returns a map plus Turtle RDF.

## How to run a self-conformance pass from the CLI

```bash
mix ex4pm.validate_self --path <ocel_ndjson> --limit <n>
```

`Mix.Tasks.Ex4pm.ValidateSelf` (`lib/mix/tasks/ex4pm.validate_self.ex`)
starts the app, runs `Reactor.run(Ex4pmEngine.Reactors.SelfConformanceReactor, ...)`
against a real OCEL log, and prints discovery results, the 5-dimensional
conformance vector, a W3C EARL 1.0 evidence proof in Turtle, and the final
receipted standing. Exits 1 on `{:error, reason}`.

## How to export OCEL benchmark data to LaTeX

```bash
mix ex4pm.ocel_to_latex [path_to_ocel_ndjson] [--output path]
```

`Mix.Tasks.Ex4pm.OcelToLatex` (`lib/mix/tasks/ex4pm.ocel_to_latex.ex`)
reads an IEEE OCEL 2.0 NDJSON log and calls
`Ex4pmEngine.OcelToLatex.export_latex/2` to emit publication-ready LaTeX benchmark
tables (default output
`docs/thesis/chapters/generated_ocel_benchmark_tables.tex`).

## How to drive ex4pm from the CLI

`mix.exs` has no `escript:` config block, so there is no `./ex4pm` binary to
build or run. Invoke `Ex4pm.CLI.main/1` (`lib/ex4pm/cli.ex`) directly via
`mix run`:

```bash
mix run -e 'Ex4pm.CLI.main(["doctor"])'                                # engine capabilities + contract standing/hash
mix run -e 'Ex4pm.CLI.main(["contracts"])'                             # full verified contract JSON
mix run -e 'Ex4pm.CLI.main(["discover", "<ocel-v2.json>", "<object-type>"])'
mix run -e 'Ex4pm.CLI.main(["discover-xes", "<log.xes>", "<case-object-type>"])'
```

All discover paths print `run.standing` and `run.receipt.hash`, surfacing
BRCE/evidence standing at the CLI boundary — this is a read/CONSTRUCT-side
projection, never a DO path. To get a standalone `./ex4pm` binary, add an
`escript: [main_module: Ex4pm.CLI]` block to `project/0` in `mix.exs` and run
`mix escript.build` — neither is configured today.

## How to send a request through the information plane

```elixir
Ex4pm.Information.execute(request_map, opts)
# or, for a JSON-in/JSON-out boundary:
Ex4pm.Information.dispatch_json(json_binary, opts)
```

`lib/ex4pm/information`. Normalizes and admits the request via
`Ex4pm.Information.Protocol.normalize/1`, then runs it through the admitted
`Ex4pm.Information.Flow` Reactor graph (parse -> route -> admit/refuse ->
construct -> BRCE -> DO -> receipt). Capability ids are matched against a closed,
static table (`Ex4pm.Information.Registry.public_capabilities/0`) — external
strings are never turned into atoms or modules. For bounded, read-only
introspection, use the direct fast paths instead of Reactor:

```elixir
Ex4pm.Information.manifest/0   # full capability manifest
Ex4pm.Information.list/0       # sorted list of public capability ids
Ex4pm.Information.describe/1   # describe one capability by id string
```

## See Also

- `AGENTS.md` — the full observation -> parse -> route -> admit|refuse ->
  construct -> BRCE -> DO -> receipt -> replay -> bounded standing contract
- `docs/ARCHITECTURE.md` — full architecture reference
- `docs/CHICAGO.md` — the non-circular-worlds model behind `mix chicago` and the
  Chicago-school testing discipline
- `docs/ROADMAP-xaas-integration.md` — full xaas integration requirements
- `CLAUDE.md` — flat library overview, module namespace layout, evidence vocabulary
