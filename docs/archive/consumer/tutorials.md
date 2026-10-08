# Tutorial: Your First ex4pm Pipeline

This tutorial walks a downstream consumer — an app that depends on the `ex4pm` package —
through a first end-to-end run: ingest a small event log, discover a process model, check
conformance, run a simulation, and inspect the contract hash. It assumes you have just added
the dependency and run `mix deps.get` for the first time. Nothing here touches ex4pm's own
internal development tooling; every command is something your application would run at
runtime.

## Prerequisites

- Elixir 1.18+ / OTP 27+ (matching what `ex4pm` itself targets)
- A mix project of your own

## 1. Add the dependency

In your application's `mix.exs`, add `ex4pm` to `deps/0`:

```elixir
defp deps do
  [
    {:ex4pm, "~> 26.9"}
  ]
end
```

If you are working against a local checkout instead of a published hex release, use a path
dependency:

```elixir
defp deps do
  [
    {:ex4pm, path: "../ex4pm"}
  ]
end
```

Fetch it:

```bash
mix deps.get
```

Confirm it compiles into your project:

```bash
iex -S mix
```

```elixir
iex> Ex4pm.contracts() |> elem(0)
:ok
```

If that returns `:ok`, the dependency is wired up correctly and the contract artifacts
(ontology, SHACL shapes, WIT world, receipt JSON Schema) are readable from your app.

## 2. Ingest a small OCEL event log

`Ex4pm.ingest/2` normalizes a raw OCEL-v2-shaped map into ex4pm's canonical `Ex4pm.EventLog`
IR. Start with a tiny order-fulfillment log with two objects and three events:

```elixir
raw_log = %{
  "events" => [
    %{
      "id" => "e1",
      "type" => "place order",
      "time" => "2026-09-01T10:00:00Z",
      "relationships" => [%{"objectId" => "o1", "qualifier" => "order"}]
    },
    %{
      "id" => "e2",
      "type" => "pick items",
      "time" => "2026-09-01T11:00:00Z",
      "relationships" => [
        %{"objectId" => "o1", "qualifier" => "order"},
        %{"objectId" => "o2", "qualifier" => "item"}
      ]
    },
    %{
      "id" => "e3",
      "type" => "ship order",
      "time" => "2026-09-01T12:00:00Z",
      "relationships" => [%{"objectId" => "o1", "qualifier" => "order"}]
    }
  ],
  "objects" => [
    %{"id" => "o1", "type" => "order"},
    %{"id" => "o2", "type" => "item"}
  ]
}

{:ok, log} = Ex4pm.ingest(raw_log)
```

`log` is now a canonical `%Ex4pm.EventLog{}` struct — the shared representation every other
`Ex4pm` function accepts as its `subject`.

### Ingesting XES instead

If your source data is IEEE XES XML rather than OCEL, use `Ex4pm.ingest_xes/2` in exactly the
same place — it returns the same canonical `Ex4pm.EventLog` shape, with `source_format: :xes`:

```elixir
xes_xml = File.read!("path/to/log.xes")

{:ok, log} = Ex4pm.ingest_xes(xes_xml)
```

Both `ingest/2` and `ingest_xes/2` return `{:error, %Ex4pm.Refusal{}}` — never raise — on
malformed or empty input, so a `with`/`case` around the call is the right pattern in your own
code:

```elixir
case Ex4pm.ingest(raw_log) do
  {:ok, log} -> log
  {:error, %Ex4pm.Refusal{} = refusal} -> handle_refusal(refusal)
end
```

## 3. Discover a process model

`Ex4pm.discover/2` runs process discovery over a log (or any subject `Ex4pm.ingest/2` would
accept) and returns a receipted `%Ex4pm.Run{}`:

```elixir
{:ok, run} = Ex4pm.discover(log)

run.standing
# => :alive (or another standing atom — see "Reading a Run" below)

model = run.value
```

`run.value` is the discovered process model (a POWL-shaped result for the default `:beam`
engine). You can pass a raw subject directly too — `discover/2` will normalize it via the same
path as `ingest/2`:

```elixir
{:ok, run} = Ex4pm.discover(raw_log)
```

## 4. Check conformance

`Ex4pm.conform/3` checks a log against a model and returns another receipted `%Ex4pm.Run{}`:

```elixir
{:ok, conformance_run} = Ex4pm.conform(log, model)

conformance_run.standing
conformance_run.value
```

`conform/3` takes the log (or a raw subject), the model to check against, and an optional
keyword list of engine options — the same three-argument shape as `discover/2`'s two plus the
model in between.

## 5. Run a simulation

`Ex4pm.simulate/2` runs simulation over a model (not a log) and, like the other analytical
operations, returns a receipted `%Ex4pm.Run{}`:

```elixir
{:ok, simulation_run} = Ex4pm.simulate(model)

simulation_run.value
```

## 6. Reading a Run

`Ex4pm.discover/2`, `Ex4pm.conform/3`, and `Ex4pm.simulate/2` all return the same
`%Ex4pm.Run{}` shape:

```elixir
%Ex4pm.Run{
  operation: :discover,
  subject_hash: "...",
  standing: :alive,
  value: model,
  receipt: %Ex4pm.Evidence.Receipt{},
  pending: %Ex4pm.Evidence.Receipt{},
  engine_result: %Ex4pm.Engine.Result{},
  projections: []
}
```

`standing` tells you whether the operation actually succeeded (`:alive`) or hit a degraded
condition (`:blocked`, `:partial_alive`, etc.) — always check it rather than assuming success
from a bare `{:ok, run}` match. `receipt` is the outcome receipt for this operation; you can
independently verify it later with `Ex4pm.replay/2`:

```elixir
{:ok, verified} = Ex4pm.replay(run.receipt.hash)
```

## 7. Inspect the contract hash

`Ex4pm.contracts/0` returns the hashed manifest of ex4pm's canonical semantic surface — the
RDF/Turtle ontology, SHACL shapes, WIT component world, and receipt JSON Schema — bundled into
one combined hash:

```elixir
{:ok, manifest} = Ex4pm.contracts()

manifest.version
manifest.contract_hash
manifest.standing
# => :alive
```

Pin `manifest.contract_hash` in your own integration tests to detect, at build time, whether
the version of `ex4pm` your app depends on has changed its ontology or receipt schema out from
under you.

## Next steps

- Explore `Ex4pm.capabilities/2` to see which engines are available (and their evidence
  standing) for a given operation before you call it.
- Read the receipt/replay contract in `Ex4pm.Evidence` if your application needs to audit or
  independently re-verify a run after the fact.
- See the how-to guides for narrower, task-oriented recipes once you're comfortable with this
  end-to-end flow.
