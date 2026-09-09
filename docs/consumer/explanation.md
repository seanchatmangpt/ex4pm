# Understanding ex4pm as a Dependency

This document explains what you are actually depending on when you add `ex4pm_core` and/or
`ex4pm_contracts` to your app's `mix.exs`, and why the library's API is shaped the way it is.
It is written for engineers deciding whether and how to depend on ex4pm, not for ex4pm's own
contributors — it does not cover umbrella layout, internal Mix tasks, or the qualification
suite. If you want task-oriented "how do I call X" recipes, look for a HOWTO doc instead; this
one is about the underlying model.

## What ex4pm actually is

ex4pm is a BEAM-native Elixir library, not a network service. When your app depends on it,
`Ex4pm.*` modules run **in your own BEAM VM**, in your own process, using your own supervision
tree if you choose to start one (for example `Ex4pm.stream/2`, which starts a Broadway
pipeline under whatever supervisor you give it). There is no ex4pm daemon to stand up, no port
to open, and no client/server protocol between your app and ex4pm's core logic.

This matters for how you reason about it operationally:

- Calling `Ex4pm.discover/2` is a function call, not an RPC. Latency, backpressure, and
  failure modes are the ones you already understand for in-process Elixir code — not network
  timeouts or serialization boundaries.
- There is nothing to deploy or version-skew against at runtime. The version you get is
  whatever `ex4pm_core`/`ex4pm_contracts` version your `mix.lock` pins, resolved the same way
  as any other hex dependency.
- Some operations *do* reach outside your VM — `Ex4pm.plan/2` talks to the pinned `ex4pm-plan`
  cloud planning worker, and `Ex4pm.cmca/2` crosses a pinned `wasm4pm` bridge. Those are the
  exceptions, not the rule, and they are explicit at the call site (see
  [The DfCM engine-candidate model](#the-dfcm-engine-candidate-model-beamwasmnimplanremote)
  below) rather than hidden inside an otherwise-local API.

Concretely, the surface you depend on is `Ex4pm` (the top-level orchestration API in
`lib/ex4pm.ex`) plus supporting modules: `Ex4pm.OCEL`/`Ex4pm.XES` for ingestion,
`Ex4pm.OCEL2` for object-centric views, `Ex4pm.POWL` for building workflow models,
`Ex4pm.Evidence.*` for the receipt ledger, `Ex4pm.Engine.*` for engine introspection, and
`Ex4pm.Contracts` for the canonical ontology/SHACL/WIT/JSON-Schema artifacts.

## Ingesting your event data

Before running any analysis, your raw event data has to become a canonical
`Ex4pm.EventLog`. ex4pm gives you three ways in:

```elixir
{:ok, log} = Ex4pm.ingest(raw_ocel_map)          # OCEL-v2-tolerant map/list input
{:ok, log} = Ex4pm.ingest_xes(xml_binary)         # IEEE XES XML
{:ok, log} = Ex4pm.OCEL.normalize(raw_ocel_map)   # lower-level, same normalization
```

All three converge on the same `Ex4pm.EventLog` IR — the shape every downstream `Ex4pm.*`
operation (`discover`, `conform`, `simulate`, `optimize`) expects. `Ex4pm.OCEL2` then lets you
derive object-centric views (`object_trace/2`, `attribute_history/3`,
`object_relationships_for/2`) from an already-ingested log without ex4pm introducing a second,
competing representation for you to reconcile.

Malformed input does not raise — it returns `{:error, %Ex4pm.Refusal{}}`, a typed struct
(code, message, subject, details) you pattern-match on like any other tagged result.

## SELECT / CONSTRUCT / DO: why `operate/3` is different from everything else

Every other top-level `Ex4pm` function — `discover/2`, `conform/3`, `simulate/2`,
`optimize/3`, `plan/2`, `cmca/2` — is **analytical**: it reads your data (and, for `plan`/
`cmca`, an admitted problem description) and returns a result. Nothing in your system of
record changes because you called it. ex4pm's internal vocabulary calls this SELECT/CONSTRUCT:
querying and deriving facts.

`Ex4pm.operate/3` is different. It compiles a `Ex4pm.POWL` workflow model (or an already
compiled `Ex4pm.Runtime.Plan`) and **executes** it — this is the one call in the public API
that can produce a real, consequential state change (invoking a task callback that does
something in the world, not just computes a value). ex4pm's internal vocabulary calls this DO.

The practical consequence for you as a caller: `operate/3` requires an explicit `authority`
argument, and the actual invocation happens under `Ex4pm.Evidence.BRCE` — the single boundary
in ex4pm that is permitted to run a state-changing callback. You do not call `BRCE` directly
in normal use (`operate/3` does that for you), but understanding that it's there explains two
things you'll observe:

1. **Authority is not optional or ambient.** `operate/3`'s `authority` argument is checked
   against the operation before your workflow's callbacks run at all
   (`Ex4pm.Evidence.BRCE.admit/2` is the underlying check). If your authority doesn't cover
   the operation, you get a refusal back — not a partially-executed workflow.
2. **You cannot accidentally trigger a DO from an analytical call.** `discover/2`, `conform/3`,
   `simulate/2`, `optimize/3`, `plan/2`, and `cmca/2` never take an `authority` argument and
   never reach BRCE, precisely because they are CONSTRUCT-only. If you need read-only insight
   plus no risk of side effects — even by mistake — those are the calls to use; `operate/3` is
   the one to call deliberately, and only when you mean to execute something.

For you, this mostly changes one thing: don't reach for `operate/3` when you want an answer,
and expect `operate/3` calls to need an authority map you construct deliberately, not one that
defaults to "allow everything."

## Why results come back receipted instead of as bare values

Every analytical operation (`discover`, `conform`, `simulate`, `optimize`, `plan`, `cmca`)
returns `{:ok, %Ex4pm.Run{}}`, not a bare result:

```elixir
%Ex4pm.Run{
  operation: :discover,
  subject_hash: "...",
  standing: :alive,
  value: %{...},          # the actual analytical result
  receipt: %Ex4pm.Evidence.Receipt{...},
  pending: %Ex4pm.Evidence.Receipt{...},
  engine_result: %Ex4pm.Engine.Result{...},
  projections: []
}
```

`value` is your answer; the rest is the evidence trail. Before the engine ran, ex4pm persisted
a **pending** receipt recording the intent (subject hash, operation, engine). After it
finished, ex4pm persisted an **outcome** receipt recording the actual standing (`:alive`,
`:blocked`, etc.) and result. Both are stored in the receipt ledger
(`Ex4pm.Evidence.Store`), and the outcome receipt is what you get back as `run.receipt`.

Why this matters to you as a consumer, not just as internal bookkeeping:

- **You can independently re-verify a result later**, without re-running the analysis or
  trusting the original call, via `Ex4pm.replay/2` (or the lower-level
  `Ex4pm.Evidence.Replay.verify/1`): it recomputes the receipt's hash and confirms the standing
  still checks out, returning a typed error (`:invalid_receipt` / `:replay_mismatch`) if it
  doesn't. This is useful if you persist a receipt hash in your own system and want to prove,
  at audit time, that the recorded outcome hasn't been tampered with or silently invalidated.
- **You get a query trail, not just a point value.** `Ex4pm.Evidence.Store.get_by_subject/1`
  and `get_by_parent/1` let you look up every receipt tied to a subject, or trace a
  pending → outcome chain, which is useful if your app needs to show "what analyses have run
  against this dataset" rather than only "what's the latest answer."
- **`standing` is a first-class part of the result**, not something you infer from whether the
  call raised. A `:blocked` standing on an otherwise-successful function return tells you the
  engine ran but the result shouldn't be trusted as fully conclusive — see the next section for
  why that happens.

If you don't need the audit trail, you can just pattern-match on `{:ok, %Ex4pm.Run{value:
value}}` and use `value` — the receipt is always there, but nothing forces you to inspect it.

## The DfCM engine-candidate model (`:beam`/`:wasm`/`:nim`/`:plan`/`:remote`)

Every analytical operation is actually executed by one of several **candidate engines** —
ex4pm calls this DfCM (discover-from-candidate-model). Candidates you may see selected
include `:beam` (native deterministic Elixir), a WASM engine running via Wasmtime, a
configured native NIF, the pinned `:ex4pm_plan` cloud worker, or a configured `:remote`
callback. `Ex4pm.Engine.Registry` holds the ordered list of candidates for each operation.

You don't normally choose an engine — `Ex4pm.Engine.execute/3` (invoked internally by
`Ex4pm.discover/2` and friends) selects one for you, evidence-ranked, unless you pass
`engine: :some_id` explicitly in `opts`. What you should understand as a consumer is what
happens when an engine isn't available:

- `Ex4pm.capabilities/2` (or `Ex4pm.Engine.candidates/2`) lists every candidate for an
  operation along with its **capability standing**: `:unsupported`, `:blocked`,
  `:partial_alive`, or `:alive`. Call this before you depend on a specific engine being
  present in your deployment.
- If the engine your call resolves to isn't actually usable — e.g. no WASM runtime configured,
  no NIF loaded, the `ex4pm_plan` bridge not reachable — you get back a typed
  `:unsupported`/`:blocked` result or refusal, **not a crash**. ex4pm treats "this engine edge
  isn't available in your environment" as a normal, inspectable outcome, the same way a
  missing optional dependency should behave, rather than letting an absent engine surface as
  an unhandled exception deep in your call stack.
- This is also why `run.standing` can be something other than `:alive` even when the function
  call itself returns `{:ok, run}`: the engine that ran may have run in a degraded or partial
  mode (`:partial_alive`), and that's visible to you in the receipt rather than silently
  collapsed into "success."
- `Ex4pm.differential/5` lets you compare two engines' results for the same operation and
  subject — useful if your app cares whether a faster/cheaper engine (e.g. `:beam`) agrees
  with a more expensive one (e.g. `:ex4pm_plan`) before you trust the cheaper one in
  production.

The practical upshot: don't assume every engine candidate is present in every deployment of
your app. Check `Ex4pm.capabilities/2` for the operations you rely on, and handle
`:unsupported`/`:blocked` standings as an expected branch in your code, not an error path you
bolt on after the fact.

## Building and executing POWL workflow models

If your app needs to model and run a workflow (as opposed to only analyzing existing event
logs), `Ex4pm.POWL.new/3` builds a validated partial-order workflow from tasks and edges —
duplicate, cycle, and unknown-reference checks happen at construction time, returning
`{:error, %Ex4pm.Refusal{}}` rather than letting an invalid model reach execution.
`Ex4pm.POWL.layers/1` gives you the topological layering of a valid model, useful for
scheduling or displaying execution order before you commit to running it.

To actually run one, pass the `%Ex4pm.POWL{}` (or an already-compiled `%Ex4pm.Runtime.Plan{}`)
to `Ex4pm.operate/3` with an explicit authority — see
[SELECT / CONSTRUCT / DO](#select--construct--do-why-operate3-is-different-from-everything-else)
above.

## The contracts artifacts

`Ex4pm.Contracts.verify/0` (wrapped as `Ex4pm.contracts/0`) gives you the canonical RDF/Turtle
ontology, SHACL shapes, WIT component-world contract, and receipt JSON Schema, plus a combined
hash covering all four. If your app generates code from ex4pm's ontology (for example with
ggen) or validates payloads against its SHACL shapes, treat these files —
resolvable via `Ex4pm.Contracts.artifacts/0` and readable via `Ex4pm.Contracts.read/1` — as
the source of truth rather than hand-copying schema definitions into your own repo. The
combined `contract_hash` returned by `verify/0` lets you detect when the version of ex4pm
you've pinned has actually changed its semantic surface, independent of the hex package
version string.

## See Also

- `lib/ex4pm.ex` — the full top-level `Ex4pm` module this document is grounded in
- `Ex4pm.Evidence.BRCE`, `Ex4pm.Evidence.Receipt`, `Ex4pm.Evidence.Store` — the receipt/
  authority machinery referenced above
- `Ex4pm.Engine.Registry` — the DfCM candidate engine list and selection logic
- `Ex4pm.Contracts` — the canonical ontology/SHACL/WIT/JSON-Schema artifact API
