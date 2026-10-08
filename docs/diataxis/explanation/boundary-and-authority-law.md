# Boundary and authority law (core engine)

This document explains the authority chain as implemented in the **ex4pm core
engine** (`/Users/sac/ex4pm`), not the Ash projection layer. Where a concept
exists only in the wrapper, that is stated explicitly and the reader is pointed
at the sibling repo (`~/ash_ex4pm`, which pins `{:ex4pm, "== 26.10.1"}` in its
`mix.exs`). Everything below is grounded in ex4pm's own source.

## The authority chain

~~~text
KNOWN != PROJECTED != AVAILABLE != ADMITTED != ALIVE != AUTHORIZED != DO
~~~

The core engine implements each `!=` as real, separately-typed code:

- **KNOWN** — a capability is enumerated in the closed capability registry
  (`lib/ex4pm/information/registry.ex:3` — "Closed capability registry and
  admission boundary"; public capabilities at
  `lib/ex4pm/information/registry.ex:298`).
- **PROJECTED** — in the core engine, PROJECTION and KNOWN collapse into the
  same registry entry: declaring a capability in
  `lib/ex4pm/information/registry.ex` is what makes it reachable at all. The
  *projection* as a separate concept — a registry entry that can be absent
  from the Ash-facing export while present in the engine — exists only in the
  wrapper layer (`ash_ex4pm`'s registry/projection machinery, see the
  sibling's `docs/diataxis/reference/api.md`, "Boundary and planning law").
- **AVAILABLE** — `Ex4pm.Engine` behaviour callback `available?/1`
  (`lib/ex4pm/engine.ex:22`): an engine callback that answers "is this engine
  present and invocable?" (e.g. is the pinned wasm artifact on disk). It is
  *engine presence*, not runtime evidence.
- **ADMITTED** — `Ex4pm.Evidence.BRCE.admit/2` (`lib/ex4pm/evidence.ex:277`):
  the request is checked against an explicit authority map
  (`:do` capability or operation in `:allow`); missing map ⇒
  `:authority_required`; map without the operation ⇒ `:authority_denied`.
- **ALIVE** — a result carries `standing` only from an executed, receipted run.
  Standing is a bounded, reason-coded vocabulary
  (`%Ex4pm.Standing.Coded{standing: atom(), code: string}`,
  `lib/ex4pm/standing_coded.ex:4`), default `:partial_alive` on replay
  (`lib/ex4pm/evidence.ex:252`), and is *observed* by executing one cheap
  admitted operation (`engine.standing` capability,
  `lib/ex4pm/information/registry.ex:100`).
- **AUTHORIZED** — a distinct step: admitted ≠ authorized. An analytical run
  is receipted with `authority: nil` (`lib/ex4pm.ex:701` — `receipted_run`
  passes `nil` authority); the receipt records the authority hash as `nil`
  and carries no DO authority. `Receipt.pending/4` hashes the authority map
  into `authority_hash` (see `Ex4pm.Evidence.Receipt` at `lib/ex4pm/evidence.ex:1-36`).
- **DO** — consequential execution is exclusive to `Ex4pm.operate/3`
  (`lib/ex4pm.ex:422`): "every task callback crosses BRCE" and goes through
  `Ex4pm.Evidence.BRCE.execute/5` (`lib/ex4pm/evidence.ex:265`, invoked from
  `lib/ex4pm/runtime.ex:125`)). Everything else —
  `discover/2 conform/3 simulate/2 optimize/3 plan/2 cmca/2 ferroplan/3
  statistics/3 forecast/2` — is CONSTRUCT-only
  (`lib/ex4pm.ex` moduledoc, "Only `operate/3` crosses the BRCE/DO boundary").

## Analytical runs are receipted but authority-less

Every analytical function records a pending and an outcome receipt through
`Ex4pm.Evidence.Store` and returns `{:ok, %Ex4pm.Run{}}` or
`{:error, %Ex4pm.Refusal{}}` (moduledoc of `Ex4pm`, `lib/ex4pm.ex:28-35`).
`receipted_run/3` (`lib/ex4pm.ex:697`) mints a `:pending` receipt with
`authority: nil` (see `Ex4pm.Evidence.Receipt.pending/4`,
`lib/ex4pm/evidence.ex:18`), runs the engine, records the outcome with the
engine standing, and returns a `Run`. The receipt carries identity
(subject hash), operation, and standing — but `authority_hash: nil` and no DO
authority. CONSTRUCT ≠ DO is enforced structurally, not by convention.

## The `receipted_action` / `do_authority?` vocabulary is wrapper-only

The named concepts `available?/1` **vs** `standing/1` as a projection-level
pair, and "only `receipted_action` declares `do_authority?` true" — these are
**Ash-layer** facts. There is no `do_authority?` flag and no `receipted_action`
module in ex4pm core; the core analogue is:

- `do_authority: Ex4pm.Evidence.BRCE` named in the information-plane
  architecture (`lib/ex4pm/information.ex:27`) — DO authority lives in the
  BRCE module, not in any capability entry.
- Candidate capabilities that would require DO are declared `admitted: false`
  with typed reasons and a named boundary:
  `runtime.operate` — `:requires_typed_runtime_plan_and_explicit_do_authority`,
  boundary `:brce` (`lib/ex4pm/information/registry.ex:214-221`);
  `ash.mutate` — `:generic_mutation_would_collapse_action_and_authority_boundaries`
  (registry.ex:222-228). The wrapper-side counterparts are `AshEx4pm.Changes.
  ReceiptedAction` (around_action, `do_authority?` true) and
  `AshEx4pm.Changes.BrceGate` (admission-only, `do_authority?` false) —
  documented in `~/ash_ex4pm/docs/diataxis/reference/api.md` ("Boundary and
  planning law"). Those changes live in the sibling repo; ex4pm core has no
  Ash changes.

## ferroplan is a no-DO planning law

Ferroplan is boundary `:construct` in the wrapper's registry; in the core
engine the same law is expressed without a boundary tag, by construction:

- `Ex4pm.ferroplan/3` runs a receipted CONSTRUCT run: "Runs a ferroplan
  operation as a receipted CONSTRUCT run (admitted wasm artifact,
  digest-pinned)" (`lib/ex4pm.ex:220-235`). The capability entry
  `engine.ferroplan.run` states the law in its description: "candidate output,
  never actuation" (`lib/ex4pm/information/registry.ex:89-98`).
- A plan, repair, probe, policy or replan is a candidate, not authorization.
  Consequential execution of that plan requires `Ex4pm.operate/3` with an
  explicit authority map, through BRCE.

## Divergence is detected, not assumed away

The event-log side of the law: an `actuate` activity not followed by a
`receipt.persist` event is an orphan DO, enumerated by
`Ex4pm.Aloop.orphan_dos/1` (`lib/ex4pm/aloop.ex:254`) and flagged as
`:unreceipted_do` divergence (`lib/ex4pm/aloop.ex:387-395`);
`every_do_receipted?/1` (`lib/ex4pm/aloop.ex:280`) is the whole-log predicate.
This makes "every DO is receipted" a checkable invariant on real logs, not a
prose claim.

## Cross-reference: the Ash-layer variant

The wrapper-side variant of this law — `available?/1` vs `standing/1`,
`receipted_action` declaring `do_authority?`, `brce_admission` as boundary
`:admit`, `do_authority?` false, and ferroplan boundary `:construct` — lives in
`~/ash_ex4pm/docs/diataxis/reference/api.md` ("Boundary and planning law"),
implemented in `AshEx4pm.Changes.ReceiptedAction` /
`AshEx4pm.Changes.BrceGate` / `AshEx4pm.Errors.Refused` in the `ash_ex4pm`
repo. It is an external sibling (`docs/README.md`, "Family"), not a dependency
of this engine.

## Falsifiers

- "DO happens without authority" — `Ex4pm.operate(subject, nil)` refuses with
  `:authority_required` (via `BRCE.admit/2`, `lib/ex4pm/evidence.ex:293`).
- "An analytical result is ALIVE on its own" — analytical receipts carry
  `authority_hash: nil`; the best standing an analytical replay can confirm is
  `:partial_alive` (`lib/ex4pm/evidence.ex:252`).
- "A ferroplan plan is authorization" — `engine.ferroplan.run` returns
  candidate output with a receipt whose `authority_hash` is nil; no DO occurs
  unless `operate/3` is invoked with a non-nil authority map that admits the
  operation.
