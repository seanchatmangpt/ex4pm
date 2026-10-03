# Tutorial: Your First ex4pm Session

Learning-oriented walkthrough of the ex4pm evidence calculus, end to end. Every
command below is real and verified against `/Users/sac/ex4pm/lib/` and the
passing assertions in `test/ex4pm_test.exs`. Audience: an engineer or agent
meeting the library for the first time.

The governing pipeline every state change passes through is
`observation -> parse -> route -> admit | refuse -> construct -> BRCE -> DO ->
receipt -> replay -> bounded standing` (see `explanation.md` in this directory).

## 1. Setup

```elixir
Mix.install([{:ex4pm, "~> 26.10"}])
```

Or, from a clone of this repository:

```bash
cd /Users/sac/ex4pm
mix deps.get
iex -S mix
```

Everything below runs inside that `iex` shell.

## 2. Ingest: raw observation to canonical EventLog

`Ex4pm.ingest/2` (`lib/ex4pm.ex:84`) normalizes a raw OCEL-v2-shaped map via
`Ex4pm.OCEL.normalize/1` (`lib/ex4pm/ocel.ex:103`) into one canonical
`%Ex4pm.EventLog{}` struct (`lib/ex4pm/ocel.ex:72`). The raw shape is tolerant:
events and objects may be maps keyed by id or lists; keys may be atoms or
strings; an event's object references may arrive as `"objects"`, `"object_ids"`,
or `"ocel:omap"` (`lib/ex4pm/ocel.ex` `extract_object_ids/1`, lines 309-334).

The payload below is copied from the fixture in `test/ex4pm_test.exs` (`@raw`,
lines 4-25) whose end-to-end test passes:

```elixir
raw = %{
  "objects" => %{
    "o1" => %{"type" => "Order"},
    "o2" => %{"type" => "Order"}
  },
  "events" => %{
    "e1" => %{"activity" => "create", "timestamp" => "2026-01-01T00:00:00Z", "objects" => ["o1"]},
    "e2" => %{"id" => "e2", "activity" => "ship", "timestamp" => "2026-01-01T00:01:00Z",
             "objects" => ["o1"]},
    "e3" => %{"activity" => "create", "timestamp" => "2026-01-01T00:02:00Z", "objects" => ["o2"]},
    "e4" => %{"activity" => "ship", "timestamp" => "2026-01-01T00:04:00Z", "objects" => ["o2"]}
  }
}
{:ok, log} = Ex4pm.ingest(raw)
```

Missing `events`/`objects` keys produce a typed refusal
(`:missing_events`, `:missing_objects`); a non-map input produces
`:invalid_observation` (`lib/ex4pm/ocel.ex:101-126`).

## 3. Discover: mine a model, receipted

```elixir
{:ok, discovery} = Ex4pm.discover(log, object_type: "Order")
discovery.standing
#=> :alive
```

`Ex4pm.discover/2` (`lib/ex4pm.ex:114`) runs `Ex4pm.Engine.execute(:discover,
log, opts)`; with no explicit `:engine` the registry selects by evidence rank
(`lib/ex4pm/engine.ex:105-152`) — `:beam` unless a wasm transport is explicit.
The returned `%Ex4pm.Run{}` (`lib/ex4pm.ex:1-25`) carries `:standing`,
`:value` (the discovered `%Ex4pm.POWL{}` model), a pending and an outcome
`%Ex4pm.Evidence.Receipt{}` (`:pending`, `:receipt`), and the
`%Ex4pm.Engine.Result{}`.

## 4. Replay the receipt chain

```elixir
{:ok, %{replay: :chain_match}} = Ex4pm.replay(discovery.receipt.hash)
```

`Ex4pm.replay/2` (`lib/ex4pm.ex:465`) looks the receipt up in
`Ex4pm.Evidence.Store` and verifies the parent chain via
`Ex4pm.Evidence.Replay.Chain.verify/2`
(`lib/ex4pm/evidence/replay_chain.ex:7-32`), returning `{:ok, %{replay:
:chain_match, ...}}` on success. Unknown hashes refuse with `:receipt_not_found`.

## 5. Conform, simulate, optimize

```elixir
{:ok, conformance} = Ex4pm.conform(log, discovery.value, object_type: "Order")
conformance.value.fitness
#=> 1.0

{:ok, simulation} = Ex4pm.simulate(discovery.value)
simulation.value.paths
#=> [["create", "ship"]]

{:ok, optimization} = Ex4pm.optimize(log, discovery.value)
[%{mode: :construct_only} | _] = optimization.value.candidates
```

All three are CONSTRUCT-only: they record a pending and an outcome receipt
through `Ex4pm.Evidence.Store` (`lib/ex4pm/evidence.ex:78-202`) and never touch
the world.

## 6. Operate: the only DO path

```elixir
{:ok, model} = Ex4pm.POWL.new([%{id: "a"}, %{id: "b"}], [{"a", "b"}])

# Refusal without authority:
{:error, %{failure: %Ex4pm.Refusal{code: :authority_required}}} =
  Ex4pm.operate(model, nil)

# Execution with explicit DO capability:
{:ok, %{standing: :alive, execution: execution}} =
  Ex4pm.operate(model, %{id: "operator", capabilities: [:do]})
length(execution.receipt_hashes)
#=> 2
```

`Ex4pm.operate/3` (`lib/ex4pm.ex:422-442`) accepts a `%Ex4pm.POWL{}` (compiled
via `Ex4pm.Runtime.compile/1`, `lib/ex4pm/runtime.ex:19`) or an already
compiled `%Ex4pm.Runtime.Plan{}`; anything else refuses with
`:invalid_operable_subject`. Every task callback crosses
`Ex4pm.Evidence.BRCE.execute/5` (`lib/ex4pm/evidence.ex:265`), which first
admits the authority map (`Ex4pm.Evidence.BRCE.admit/2`,
`lib/ex4pm/evidence.ex:277-298`): the authority must carry `capabilities:
[:do | ...]` or `allow: [...]` naming the operation. `:authority_denied`,
`:authority_required` are the refusal codes.

## 7. Where to go next

- Problem-oriented recipes: `how-to-guides.md`
- Full function index: `reference.md`
- Why receipts, standing, and BRCE: `explanation.md`
