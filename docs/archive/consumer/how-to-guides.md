# ex4pm Consumer How-To Guides

This document is a Diataxis "how-to guide": problem-oriented recipes for an application
that depends on the `ex4pm` (or `ex4pm_core`) hex package, not for ex4pm's own
contributors. Every recipe cites a real public function on the `Ex4pm` module or a
sibling public module. No internal Mix tasks, umbrella-only tooling, or
qualification-suite commands appear here — those are for ex4pm's own repo, not for a
downstream consumer.

## How to add ex4pm as a dependency

### Local development: path dependency

While iterating against a local checkout of ex4pm (e.g. `~/ex4pm` next to your app),
point `mix.exs` at the path directly:

```elixir
defp deps do
  [
    {:ex4pm_core, path: "../ex4pm/apps/ex4pm_core"}
  ]
end
```

Path dependencies recompile whenever the referenced source changes, so this is the
right mode for co-developing your app against ex4pm changes that haven't been
published yet.

### Once published: hex dependency

Once `ex4pm_core` (or `ex4pm`) is published to Hex, switch the same entry to a version
requirement:

```elixir
defp deps do
  [
    {:ex4pm_core, "~> 0.1"}
  ]
end
```

Run `mix deps.get` after changing either form. Only change one consumer app's
`mix.exs` at a time when migrating from path to hex — verify `mix deps.get` and a
compile succeed before removing the path form, so you always have a working
dependency declaration to fall back to.

## How to validate an OCEL v2 envelope before sending it elsewhere

Before forwarding an OCEL v2 batch envelope (events, objects, object relationships) to
another system, validate its shape with `Ex4pm.OCEL.validate_envelope/1`:

```elixir
envelope = %{
  "schema" => "ocel2",
  "producer" => "my_app",
  "sequence" => 1,
  "events" => [
    %{"id" => "e1", "type" => "order_placed", "time" => "2026-09-09T10:00:00Z"}
  ],
  "objects" => [
    %{"id" => "o1", "type" => "order"}
  ],
  "object_relationships" => []
}

case Ex4pm.OCEL.validate_envelope(envelope) do
  {:ok, normalized_envelope} ->
    # normalized_envelope has canonical key/value shapes; safe to forward
    send_to_downstream(normalized_envelope)

  {:error, %Ex4pm.Refusal{} = refusal} ->
    # refusal.code / refusal.message / refusal.details explain what failed
    Logger.warning("OCEL envelope refused: #{refusal.message}")
end
```

`validate_envelope/1` returns the normalized envelope map on success, or a typed
`Ex4pm.Refusal` struct (never a raw error string or exception) on a malformed
envelope. Match on `{:error, %Ex4pm.Refusal{}}` rather than assuming any particular
exception type.

If you instead need to normalize a raw OCEL-v2-like payload into ex4pm's canonical
`Ex4pm.EventLog` IR (rather than just validating a batch envelope), use
`Ex4pm.ingest/2`:

```elixir
{:ok, event_log} = Ex4pm.ingest(raw_ocel_map)
```

## How to call `Ex4pm.operate/3` with an explicit authority map

`Ex4pm.operate/3` is the only entry point that crosses into state-changing execution
(DO). It requires a POWL model or a compiled `Ex4pm.Runtime.Plan`, plus an explicit
authority map — there is no ambient authority, so a call without one is refused, not
silently permitted.

```elixir
{:ok, powl_model} =
  Ex4pm.POWL.new(
    [%Ex4pm.POWL.Task{id: :ship, label: "Ship order", intent: :ship_order}],
    []
  )

authority = %{
  granted_operations: [:ship_order],
  principal: "order_service"
}

case Ex4pm.operate(powl_model, authority, []) do
  {:ok, %{plan: plan, execution: execution, standing: standing}} ->
    # standing is the evidence-standing atom (e.g. :alive, :blocked) for this DO
    handle_execution(execution, standing)

  {:error, %Ex4pm.Refusal{} = refusal} ->
    Logger.error("operate refused: #{refusal.message}")
end
```

The exact shape of the `authority` map (which keys it must carry to grant a given
operation) is defined by `Ex4pm.Evidence.BRCE.admit/2`, which `operate/3` calls
internally — build your authority map to match the operations your POWL tasks declare
via their `intent` field. A call with an authority map that doesn't grant the task's
operation returns a refusal rather than executing partially.

## How to replay a receipt via `Ex4pm.replay/2`

Every analytical operation (`discover/2`, `conform/3`, `simulate/2`, `optimize/3`,
`plan/2`, `cmca/2`) and every `operate/3` call produces a receipted evidence trail. To
independently verify a receipt's hash and standing later — without trusting the
original invocation — call `Ex4pm.replay/2` with the receipt hash:

```elixir
{:ok, run} = Ex4pm.discover(event_log, [])
receipt_hash = run.receipt.hash

case Ex4pm.replay(receipt_hash, []) do
  {:ok, verified_receipt} ->
    # the hash was independently recomputed and matches; standing is confirmed
    verified_receipt.standing

  {:error, %Ex4pm.Refusal{code: :receipt_not_found}} ->
    Logger.warning("no receipt found for hash #{receipt_hash}")

  {:error, %Ex4pm.Refusal{} = refusal} ->
    # e.g. :invalid_receipt or :replay_mismatch — the chain failed to verify
    Logger.error("replay failed: #{refusal.message}")
end
```

Pass `store: MyApp.CustomStore` in the opts keyword list if your app uses a receipt
store other than the default `Ex4pm.Evidence.Store`.

## How to check which DfCM engine candidates are available at runtime

Different operations (`:discover`, `:conform`, `:simulate`, `:optimize`, `:plan`,
`:cmca`) may have multiple candidate engines (BEAM-native, WASM, a pinned remote
planner, a NIF, etc.), each with its own evidence standing. Before relying on a
specific engine being available, inspect the candidates with `Ex4pm.capabilities/2`:

```elixir
candidates = Ex4pm.capabilities(:discover, [])

Enum.each(candidates, fn capability ->
  IO.puts("#{capability.id}: #{capability.standing} (#{capability.reason})")
end)
```

`capabilities/2` takes the operation as its first argument (defaults to `:discover`)
and returns a list of `Ex4pm.Core.Capability` structs, evidence-ranked so the
highest-standing candidate (e.g. `:alive` over `:partial_alive` over `:blocked`) comes
first. Use this to decide whether to proceed with a default engine selection, prompt
for a fallback, or surface a warning to your own users when only a degraded engine is
available for an operation you depend on.

## How to run a differential comparison between two engines

To compare two candidate engines' results for the same operation and subject — for
example, validating that a new WASM engine agrees with the established BEAM-native
engine before switching your app's default — use `Ex4pm.differential/5`:

```elixir
result =
  Ex4pm.differential(:discover, event_log, :beam, :wasm_discover, [])

case result do
  {:ok, comparison} ->
    # comparison carries both engines' results/standings and their agreement
    inspect(comparison)

  {:error, %Ex4pm.Refusal{} = refusal} ->
    Logger.error("differential comparison refused: #{refusal.message}")
end
```

The five positional arguments are: the operation atom, the subject (a log, model, or
problem map appropriate to that operation), the left engine id, the right engine id,
and an opts keyword list. Use `Ex4pm.capabilities/2` first to confirm both engine ids
you want to compare are actually registered candidates for that operation.

## How to mine your own CI/scheduled-task pipeline for throughput and conformance

If you run a CI or scheduled-task pipeline that qualifies commits, runs a crown/release
process, merges the result, and occasionally repairs a failure, you can model each of
those pipeline events as an OCEL v2 event and use ex4pm to discover the pipeline's real
directly-follows behavior and check it against an expected model — rather than manually
cross-referencing scheduler logs against merge timestamps by hand.

Model each event with `event_type` one of `"commit_qualified"`, `"crown_run"`,
`"merge"`, or `"rca_repair"`, and `object_type` `"batch"` (or `"lane"` if you track
concurrent lanes separately). First, ingest a known-good lane — one where a
`commit_qualified` run was always followed by a `crown_run` and then a `merge` — and
discover its directly-follows graph with `Ex4pm.discover/2`:

```elixir
expected_raw = %{
  "objects" => %{
    "batch-good" => %{"type" => "batch"}
  },
  "events" => %{
    "e1" => %{
      "activity" => "commit_qualified",
      "timestamp" => "2026-09-09T09:00:00Z",
      "objects" => ["batch-good"]
    },
    "e2" => %{
      "activity" => "crown_run",
      "timestamp" => "2026-09-09T09:05:00Z",
      "objects" => ["batch-good"]
    },
    "e3" => %{
      "activity" => "merge",
      "timestamp" => "2026-09-09T09:10:00Z",
      "objects" => ["batch-good"]
    }
  }
}

{:ok, expected_log} = Ex4pm.ingest(expected_raw)
{:ok, expected_model} = Ex4pm.discover(expected_log, object_type: "batch")
```

`expected_model.value` is the real discovered directly-follows graph — a map with
`edges` keyed by `{from_activity, to_activity}` tuples, plus `starts`, `ends`, and
`activities` counts:

```elixir
%{
  type: :dfg,
  edges: %{
    {"commit_qualified", "crown_run"} => %{count: 1, average_duration_ms: 300_000.0},
    {"crown_run", "merge"} => %{count: 1, average_duration_ms: 300_000.0}
  },
  object_type: "batch",
  activities: %{"commit_qualified" => 1, "crown_run" => 1, "merge" => 1},
  ends: %{"merge" => 1},
  starts: %{"commit_qualified" => 1},
  trace_count: 1
}
```

Now ingest the pipeline's actual behavior for a batch that ran `commit_qualified` and
`crown_run` but never merged — the scheduler retried the qualifying commit instead —
and check it with `Ex4pm.conform/2` against the expected model:

```elixir
actual_raw = %{
  "objects" => %{
    "batch-stalled" => %{"type" => "batch"}
  },
  "events" => %{
    "f1" => %{
      "activity" => "commit_qualified",
      "timestamp" => "2026-09-09T10:00:00Z",
      "objects" => ["batch-stalled"]
    },
    "f2" => %{
      "activity" => "crown_run",
      "timestamp" => "2026-09-09T10:05:00Z",
      "objects" => ["batch-stalled"]
    },
    "f3" => %{
      "activity" => "commit_qualified",
      "timestamp" => "2026-09-09T10:35:00Z",
      "objects" => ["batch-stalled"]
    }
  }
}

{:ok, actual_log} = Ex4pm.ingest(actual_raw)
{:ok, conformance} = Ex4pm.conform(actual_log, expected_model.value, object_type: "batch")

conformance.value.fitness
# => 0.5

conformance.value.deviations
# => %{{"crown_run", "commit_qualified"} => 1}
```

The `crown_run -> commit_qualified` deviation is the real signal: this batch's crown
ran, but instead of the expected `merge` within the modeled window, the pipeline looped
back into another qualifying-commit attempt — an expected `merge` event absent where the
model says one should follow. That is the concrete mechanism that turns a stalled,
unmerged batch into a conformance violation `Ex4pm.conform/2` surfaces automatically,
instead of requiring a human to manually diff scheduler logs against merge timestamps
after the fact. Widen the expected model (ingest more known-good lanes before calling
`Ex4pm.discover/2`) to admit legitimate variations — such as a `rca_repair` step between
`crown_run` and `merge` — without losing the check on the pipeline stalling out
entirely.

## See Also

- `Ex4pm.Contracts.verify/0` (via `Ex4pm.contracts/0`) — fetch and verify the
  ontology/SHACL/WIT/receipt-schema contract manifest and its combined hash, useful as
  a codegen source of truth (e.g. for `ggen`) rather than hand-copying schema files.
- `Ex4pm.Refusal` — the typed refusal struct returned by every function in this guide
  on failure; match on `%Ex4pm.Refusal{code: ..., message: ..., details: ...}` rather
  than a generic error tuple or exception.
- `Ex4pm.OCEL2` — derives object traces, attribute-change history, and object
  relationships from an already-normalized `Ex4pm.EventLog`, useful for drill-down
  views over data ingested via `Ex4pm.ingest/2`.
