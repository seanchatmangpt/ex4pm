# Tutorial: Your First ex4pm Session

Learning-oriented walkthrough of the ex4pm evidence/BRCE calculus, end to end:
`observation -> parse -> route -> admit | refuse -> construct -> BRCE -> DO -> receipt ->
replay -> bounded standing`. Every command below is real and copy-pasteable against this
repo (`/Users/sac/ex4pm`). Audience: an AI agent or engineer meeting the codebase for the
first time who needs to discover every real capability, not just the happy path.

Grounded in the public API of `lib/ex4pm.ex` (`Ex4pm`), `lib/ex4pm/core`, `lib/ex4pm/engine`,
`lib/ex4pm/evidence`, and `lib/ex4pm/runtime`. See `../ROADMAP-xaas-integration.md` and the
root `CLAUDE.md` for architectural context.

## 1. Setup

```bash
cd /Users/sac/ex4pm
mix deps.get
```

Start an interactive session with the whole library loaded:

```bash
iex -S mix
```

Everything from here runs inside that `iex` shell unless marked `bash`.

## 2. Ingest: turn raw observations into a canonical EventLog

`Ex4pm.ingest/2` normalizes a raw OCEL-v2-shaped map via `Ex4pm.OCEL.normalize/1` into the
canonical `%Ex4pm.EventLog{}` IR (`lib/ex4pm/core`).

```elixir
raw = %{
  "eventTypes" => [%{"name" => "place_order"}, %{"name" => "ship_order"}],
  "objectTypes" => [%{"name" => "order"}],
  "events" => [
    %{
      "id" => "e1",
      "type" => "place_order",
      "time" => "2026-01-01T10:00:00Z",
      "relationships" => [%{"objectId" => "o1", "qualifier" => "order"}]
    },
    %{
      "id" => "e2",
      "type" => "ship_order",
      "time" => "2026-01-01T12:00:00Z",
      "relationships" => [%{"objectId" => "o1", "qualifier" => "order"}]
    }
  ],
  "objects" => [%{"id" => "o1", "type" => "order"}]
}

{:ok, log} = Ex4pm.ingest(raw)
# log is a canonical %Ex4pm.EventLog{}
```

To project the ingested dataset into the Ash domain layer at the same time:

```elixir
{:ok, log} = Ex4pm.ingest(raw, project?: true)
```

### 2a. Ingest a real XES sample instead

`Ex4pm.ingest_xes/2` parses XES XML (DTD disabled) via `Ex4pm.XES.parse/2`, then normalizes
through the same `Ex4pm.OCEL.normalize/1` path, tagging `source_format: :xes`.

```elixir
xml = File.read!("test/fixtures/sepsis.xes")
{:ok, xes_log} = Ex4pm.ingest_xes(xml)
```

(If no fixture exists at that path, use `find test -iname "*.xes"` from `bash` to locate one,
or supply any well-formed XES document you have on disk.)

### 2b. Ingest via the CLI

`Ex4pm.CLI.main/1` (`lib/ex4pm/cli.ex`) dispatches `doctor` (engine
capabilities + contract standing), `contracts` (full verified contract JSON), `discover
<file> [object-type]`, and `discover-xes <file> [case-object-type]` — each prints
`run.standing` and `run.receipt.hash`.

`mix escript.build` currently fails with `Could not generate escript, please set
:main_module in your project configuration` — `mix.exs` has no `escript:` project key
pointing at `Ex4pm.CLI`, so no `./ex4pm` binary exists yet. Until that's added, invoke the
CLI module directly instead:

```bash
mix run -e 'Ex4pm.CLI.main(["doctor"])'
mix run -e 'Ex4pm.CLI.main(["discover", "path/to/ocel-v2.json", "order"])'
```

## 3. Discover: mine a process model from the EventLog

`Ex4pm.discover/2` resolves the subject to an `EventLog`, runs `Engine.execute(:discover, log,
opts)` through the evidence-ranked candidate engines (`lib/ex4pm/engine`), and wraps the
result in a receipted `%Ex4pm.Run{}` — a pending and an outcome receipt are written to the
configured `Ex4pm.Evidence.Store` before the call returns.

```elixir
run = Ex4pm.discover(log)
run.standing        # :alive | :partial_alive | :blocked | ...
run.value           # the discovered process model
run.receipt          # %Ex4pm.Evidence.Receipt{} outcome
run.engine_result    # %Ex4pm.Engine.Result{}
```

Inspect which engines are even eligible to run `:discover` before committing to one:

```elixir
Ex4pm.capabilities(:discover)
# => list of %Ex4pm.Core.Capability{} — one per registered engine's standing
```

Force a specific engine (see `Ex4pm.Engine.Registry.engines/0` for the full candidate list —
`:beam`, `:ex4pm_plan`, `:cmca_wasm`, `:wasm`, `:nif`, `:remote`, plus ~18 wasm4pm wrappers):

```elixir
run = Ex4pm.discover(log, engine: :beam)
```

## 4. Conform: check the EventLog against the discovered model

`Ex4pm.conform/3` runs `Engine.execute(:conform, {log, model}, opts)`.

```elixir
conform_run = Ex4pm.conform(log, run.value)
conform_run.standing
conform_run.value   # conformance result (fitness/precision-style output from the engine)
```

For the full 5-axis conformance vector (fitness, precision, policy_conformance,
lifecycle_conformance, causal_conformance, overall_score) with structured violations, call the
evidence-layer function directly:

```elixir
{:ok, vector} = Ex4pmEvidence.Conformance.evaluate(log, run.value)
# or via the Ex4pm.Evidence.* alias:
{:ok, vector} = Ex4pm.Evidence.Conformance.evaluate(log, run.value)
```

## 5. Simulate: run the model forward

`Ex4pm.simulate/2` runs `Engine.execute(:simulate, model, opts)`, keyed by
`Ex4pm.Core.Hash.digest(model)`.

```elixir
sim_run = Ex4pm.simulate(run.value)
sim_run.standing
sim_run.value
```

## 6. Optimize: propose candidate interventions

`Ex4pm.optimize/3` runs `Engine.execute(:optimize, {log, model}, opts)`; candidate
interventions can optionally be projected into the domain layer.

```elixir
opt_run = Ex4pm.optimize(log, run.value)
opt_run.value   # candidate interventions
```

## 7. Plan: analytical CONSTRUCT via the pinned ex4pm-plan bridge

`Ex4pm.plan/2` requires a map `problem`. It defaults `engine: :ex4pm_plan` and runs
`Engine.execute(:plan, problem, opts)` — a receipted analytical CONSTRUCT with no ambient
cloud credentials. Non-map input is refused.

```elixir
plan_run = Ex4pm.plan(%{
  domain: "order_fulfillment",
  initial_state: %{order: :placed},
  goal_state: %{order: :shipped}
})
plan_run.standing
```

If the `:ex4pm_plan` bridge is not configured/available in your environment, expect
`:partial_alive` or a typed refusal rather than a crash — this is the intended evidence
behavior, not a bug: see `Ex4pm.Engine.Ex4pmPlan` (`lib/ex4pm/engine`).

## 8. Operate: the sole DO-authority path (BRCE-gated)

`Ex4pm.operate/3` is the **only** function in this codebase that crosses into BRCE-gated DO
execution. It requires an explicit `authority` map and a `%Ex4pm.POWL{}` (or a precompiled
`%Ex4pm.Runtime.Plan{}`) as the subject.

### 8a. Build a POWL model

```elixir
{:ok, powl} = Ex4pm.POWL.new(
  [%{id: "place_order", intent: fn -> {:ok, :placed} end},
   %{id: "ship_order", intent: fn -> {:ok, :shipped} end}],
  [{"place_order", "ship_order"}]
)
Ex4pm.POWL.layers(powl)   # topological execution layers
```

### 8b. Compile and execute under explicit authority

```elixir
authority = %{capabilities: [:do]}

{:ok, plan} = Ex4pm.Runtime.compile(powl)
{:ok, execution} = Ex4pm.operate(powl, authority)
```

Internally, `Ex4pm.operate/3` calls `Ex4pm.Runtime.compile/1` then `Ex4pm.Runtime.execute/3`,
which routes **every individual POWL task** through `Ex4pm.Evidence.BRCE.execute/5` — no task
callback runs without a pending receipt written before invocation and an outcome receipt
(`:alive` on success, `:blocked` on exception/throw) written after. Omitting `:do` from
`authority[:capabilities]` (and no matching `:allow` entry) causes `BRCE.admit/2` to refuse
with `:authority_denied` or `:authority_required` before anything executes.

## 9. Replay: independently verify a receipt

Every receipted operation above (`discover`/`conform`/`simulate`/`optimize`/`plan`/`operate`)
writes receipts you can independently re-verify without trusting the stored standing field.

```elixir
hash = run.receipt.hash
{:ok, verified} = Ex4pm.replay(hash)
```

`Ex4pm.replay/2` looks the receipt up in the configured `Ex4pm.Evidence.Store` and verifies it
via `Ex4pm.Evidence.Replay.Chain.verify/2`, which independently recomputes the outcome
receipt's hash, fetches and verifies its pending parent, and confirms subject/operation/
authority correspondence between the two — catching tampering or parent mismatch, not just a
missing row.

## 10. Differential check: cross-verify two engines agree

```elixir
Ex4pm.differential(:discover, log, :beam, :wasm)
```

`Ex4pm.differential/5` delegates to `Ex4pm.Engine.Differential.compare/5`, running the same
operation/subject through two named engines and diffing their results — useful whenever more
than one engine candidate reports `:alive`/`:partial_alive` for the same operation.

## 11. Contracts: verify the semantic surface is intact

Before trusting any of the above, you can independently attest the ontology/SHACL/WIT/receipt
schema bundle is present and unmodified:

```elixir
Ex4pm.contracts()
# => {:ok, %{version: "0.1.0", artifacts: ..., contract_hash: "sha256:...", standing: :alive}}
```

This delegates to `Ex4pm.Contracts.verify/0` (`lib/ex4pm/contracts.ex`), which re-reads all four
canonical artifacts from disk, hashes them, and checks each for required terms (e.g. the WIT
world must contain `discover:`, `conform:`, `simulate:`).

## 12. What a successful run looks like

A complete session that touches every phase of the calculus produces, in order:

1. `{:ok, %Ex4pm.EventLog{}}` from `Ex4pm.ingest/2` or `Ex4pm.ingest_xes/2`.
2. A `%Ex4pm.Run{standing: :alive, ...}` from `Ex4pm.discover/2`, with a non-nil
   `run.receipt.hash`.
3. `%Ex4pm.Run{}` results from `Ex4pm.conform/3`, `Ex4pm.simulate/2`, `Ex4pm.optimize/3`, each
   independently receipted (check `run.receipt.hash` differs per call, chained via
   `parent_hash` back to their own pending receipts).
4. A `%Ex4pm.Run{}` (or typed refusal, if `:ex4pm_plan` is unconfigured) from `Ex4pm.plan/2`.
5. `{:ok, execution}` from `Ex4pm.operate/3` — the *only* step above that actually invoked DO
   callbacks, each one individually receipted via `Ex4pm.Evidence.BRCE.execute/5`.
6. `{:ok, verified}` from `Ex4pm.replay/2` for at least one receipt hash collected above,
   confirming the chain independently re-derives rather than merely re-reads.

If any step instead returns `{:error, %Ex4pm.Refusal{}}`, that is not a failure of the
tutorial — refusals are typed, first-class evidence outcomes in this codebase (see
`Ex4pm.Refusal.new/3`, `lib/ex4pm/core`). Read the `.code` and `.message` fields; they name
exactly which admission check failed (e.g. `:invalid_planning_problem`,
`:invalid_operable_subject`, `:authority_denied`, `:receipt_not_found`).

## See Also

- `../ROADMAP-xaas-integration.md` — external integration requirements referencing
  `Ex4pm.OCEL.validate_envelope/1` and the `POST /api/v1/ocel/events` HTTP ingress
- `AGENTS.md` (repo root) — the full observation -> ... -> bounded standing contract
- `docs/ARCHITECTURE.md` (repo root) — architectural detail behind this tutorial
- `docs/CHICAGO.md` (repo root) — the Chicago-school testing discipline enforced by
  `mix chicago` and `ex4pm.audit.chicago`, relevant when writing tests against the flows above
- `lib/ex4pm/qualification` — `mix ex4pm.lint.truth`, `mix ex4pm.powl.court`,
  `mix ex4pm.sabotage.court`, `mix ex4pm.crown` — the anti-overclaiming qualification suite
  that independently re-verifies claims like the ones this tutorial walks through
