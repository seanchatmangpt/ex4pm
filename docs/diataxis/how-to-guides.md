# How-To Guides

Problem-oriented recipes for ex4pm. Every module, function, option, and refusal
code below is taken verbatim from the source in `/Users/sac/ex4pm/lib/` — no
invented APIs. Line citations are to the working tree at HEAD.

## How to ingest XES XML

`Ex4pm.ingest_xes/2` (`lib/ex4pm.ex:98`) parses XES XML through
`Ex4pm.XES.parse/2` (`lib/ex4pm/xes.ex:10`). Option `:case_object_type` sets the
object type each trace becomes (default `"Case"`).

```elixir
{:ok, log} = Ex4pm.ingest_xes(File.read!("trace.xes"))
{:ok, log} = Ex4pm.ingest_xes(xml, case_object_type: "Order")
```

A log with no `<trace>` elements refuses with `:empty_xes`; non-binary input
refuses (`lib/ex4pm/xes.ex:10,87`). Parsing rejects DTDs (`SweetXml.parse(xml,
dtd: :none)`).

## How to run wasm statistics and forecast a series

`Ex4pm.statistics/3` (`lib/ex4pm.ex:295`) executes real wasm4pm algorithms as
receipted CONSTRUCT runs, engine `:wasm_<op>`, transport supplied by the
supervised `Ex4pmEngine.Wasm.Host` (or an explicit `:<op>_wasm_fun`).

```elixir
{:ok, run} = Ex4pm.statistics(:mean, [1.0, 2.0, 3.0])
{:ok, run} = Ex4pm.statistics(:percentile, data, p: 90.0)
{:ok, run} = Ex4pm.statistics(:ks_statistic, {sample_a, sample_b})
{:ok, run} = Ex4pm.forecast(series, method: :holt, alpha: 0.3, beta: 0.5)
```

Supported ops and data shapes (table in `lib/ex4pm.ex:276-288`): `:mean`,
`:median`, `:std_deviation` (list of numbers); `:percentile` (`:p` default
`50.0`); `:standardize`; `:dot_product`, `:euclidean_distance` (`{a, b}`);
`:ks_statistic` (`{sample_a, sample_b}`); `:ks_critical_value` (`{n, m}`,
`:alpha` default `0.05`); `:regression` (`{x, y}`); `:forecast` (`:alpha`
default `0.3`); `:holt_forecast` (`:alpha`/`:beta` default `0.5`); `:ewma`;
`:trend_classify`. Wrong shape refuses with `:invalid_statistics_input`; unknown
op refuses `:unsupported_statistics_operation` (`lib/ex4pm.ex:307-312`).

`Ex4pm.forecast/2` (`lib/ex4pm.ex:327`) is a convenience over `statistics/3`
with `:method` `:forecast | :holt | :ewma`; other methods refuse
`:invalid_forecast_method`.

## How to inspect wasm/ferroplan health without executing

`Ex4pm.wasm/1` (`lib/ex4pm.ex:359`) lists all 33 wasm4pm algorithm engines as
`%{id, algorithm, export, standing, reason, executed: false}` — inspection, not
execution. `Ex4pm.health/1` (`lib/ex4pm.ex:393`) probes the bundled artifacts
(`probe: true` default, `probe: false` to inspect only):

```elixir
Ex4pm.wasm() |> Enum.filter(&(&1.standing == :blocked))
%{standing: standing, wasm4pm: w, ferroplan: f} = Ex4pm.health()
```

Standing ladder (`lib/ex4pm.ex:658-661`): `:blocked` (absent/unadmitted),
`:partial_alive` (admitted, unprobed), `:alive` (probe executed), `:build_broken`
(probe failed).

## How to start a streaming observation pipeline

`Ex4pm.stream/2` (`lib/ex4pm.ex:411`) starts the supervised Broadway pipeline
(`lib/ex4pm/stream.ex:39`, `Ex4pm.Stream.Pipeline.start_link/1`).

```elixir
{:ok, pid} =
  Ex4pm.stream(events, sink: fn %Ex4pm.Event{} = event -> IO.inspect(event.activity) end)
```

Required options: `:sink` (1-arity fn receiving each normalized `%Ex4pm.Event{}`)
and `:events`. Optional: `:objects` (map of objects shared across events),
`:name`, `:producer_concurrency`, `:processor_concurrency`, `:max_demand`,
`:min_demand`, `:ack_target` (`lib/ex4pm/stream.ex:47-56,62-68`). Raw map events
are normalized per message via `Ex4pm.OCEL.normalize/1`; failures fail the
Broadway message with the `%Ex4pm.Refusal{}`. Sinks receive observations only —
no ambient DO authority (`lib/ex4pm/stream.ex:39` moduledoc).

## How to ingest a batch envelope (deduplicated)

`Ex4pm.Stream.Ingest.ingest_envelope/2` (`lib/ex4pm/stream/ingest.ex:19`)
validates the envelope with `Ex4pm.OCEL.validate_envelope/1`
(`lib/ex4pm/ocel.ex:415-468`): required keys `schema` (string), `producer`
(map), `sequence` (integer), `events` (list/map); optional `previous_digest`,
`objects`, `object_relationships`. Missing keys refuse `:missing_envelope_*`;
non-map refuses `:invalid_envelope`.

If an outcome receipt already exists for the envelope's normalized subject
content hash, it short-circuits with `status: :duplicate_ignored` plus
`original_receipt_hash` (`lib/ex4pm/stream/ingest.ex:77`) — no second event, no
second receipt.

## How to route a planning problem

`Ex4pm.plan/2` (`lib/ex4pm.ex:181`) routes (first match wins,
`lib/ex4pm.ex:482-503`):

| condition | engine |
|---|---|
| `engine: :ferroplan` | `:ferroplan` (PDDL `plan`) |
| `engine: :wasm_strips_plan` / `:strips_plan` | `:wasm_strips_plan` |
| `engine: :wasm_htn_plan` / `:htn_plan` | `:wasm_htn_plan` |
| no `:engine`, problem has binary `domain` + `problem` keys, no `:ex4pm_plan_fun` | `:ferroplan` |
| otherwise | `:ex4pm_plan` (needs `:ex4pm_plan_fun`) |

```elixir
{:ok, run} = Ex4pm.plan(%{domain: pddl_text, problem: pddl_text})
```

Non-map problems refuse `:invalid_planning_problem`; ferroplan digest mismatch
refuses `:ferroplan_digest_mismatch`.

## How to run a ferroplan operation

`Ex4pm.ferroplan/3` (`lib/ex4pm.ex:247`) runs an admitted, digest-pinned
ferroplan wasm artifact. Ops (`lib/ex4pm.ex:229-238`): `:plan`,
`:plan_production`, `:hierarchical_plan`, `:fond_policy`, `:fond_policy_validate`
/`:fond_validate`, `:explain`, `:readiness`, `:version`.

```elixir
{:ok, run} = Ex4pm.ferroplan(:plan, %{domain: pddl, problem: pddl},
  ferroplan_artifact: "path/to/ferroplan.wasm",
  ferroplan_expected_sha256: "...")
```

Absent/pinned/digest-mismatched artifacts refuse `:engine_blocked`; unknown ops
refuse `:ferroplan_unsupported_operation`.

## How to compare two engines on the same subject

```elixir
Ex4pm.differential(:discover, log, :beam, :wasm_discover, prefer_wasm: true)
```

`Ex4pm.differential/5` (`lib/ex4pm.ex:455`) delegates to
`Ex4pm.Engine.Differential.compare/5` (`lib/ex4pm/engine/differential.ex`).

## How to choose a wasm engine over beam

Implicit selection never lets a Host-fallback wasm engine displace `:beam`
(`lib/ex4pm/engine.ex:154-173`). Opt in one of three ways:

```elixir
Ex4pm.discover(log, prefer_wasm: true)
Ex4pm.discover(log, engine: :wasm_discover)
Ex4pm.discover(log, discover_wasm_fun: my_transport_fn)
```

An explicit `:engine` never silently falls back (`lib/ex4pm.ex:41` moduledoc).

## How to project into the Ash domain

Pass `project?: true` to any analytical call. `Ex4pm.ingest/2` attaches the
dataset projection under `log.metadata.projections`
(`lib/ex4pm.ex:84-89`); discovery adds a model projection and a receipt
projection (`lib/ex4pm.ex:743-773`).

```elixir
{:ok, log} = Ex4pm.ingest(raw, project?: true)
{:ok, run} = Ex4pm.discover(log, object_type: "Order", project?: true)
length(run.projections)  #=> 2
```

## How to query the capability manifest

`Ex4pm.Information.list/0`, `describe/1`, `manifest/0`
(`lib/ex4pm/information.ex:20-49`) give read-only introspection;
`Ex4pm.Information.execute/2` (`lib/ex4pm/information.ex:53`) routes a map
request through the Reactor information plane; `dispatch_json/2` (line 98)
accepts raw JSON bytes (max 32 MiB, `@max_json_bytes` line 14).

## How to verify the release contracts

```elixir
{:ok, contract} = Ex4pm.contracts()
contract.standing  #=> :alive
map_size(contract.artifacts)  #=> 4  (ontology, SHACL, WIT, receipt schema)
```

`Ex4pm.contracts/0` (`lib/ex4pm.ex:75`) delegates to `Ex4pm.Contracts.verify/0`
(`lib/ex4pm/contracts.ex:57`). The Mix tasks `mix ex4pm.release.contract` and
`mix ex4pm.validate_self` (`lib/mix/tasks/`) run the same checks from CI.

## How to diagnose the build environment

Mix tasks in `lib/mix/tasks/`: `mix ex4pm.wasm.doctor`,
`mix ex4pm.wasm.verify`, `mix ex4pm.health`, `mix ex4pm.qualification`,
`mix ex4pm.lint.truth`, `mix ex4pm.audit.chicago`, `mix ex4pm.audit.bullshit`,
`mix ex4pm.rails.court`, `mix ex4pm.exposure.court`, `mix ex4pm.crown` (see
`preferred_cli_env` in `mix.exs` for the full list).

## See Also

- `reference.md` — exhaustive function index
- `tutorials.md` — first-session walkthrough
- `explanation.md` — why receipts and BRCE
