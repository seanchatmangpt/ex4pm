# RAISE-EVIDENCE-DERIVED-ACTUATION-GUARANTEES (Raise, upstream: ggen_igniter/ggen)

## Evidence

This is an upstream finding, filed against `~/ggen_igniter` and `~/ggen` (both outside
this repo's write scope per this task's instructions). Citations below were verified by
directly reading the cited files in this session, except where noted as carried forward
from a prior research pass.

### ggen_igniter — `Controller` bypasses the compensated Reactor path by default

`~/ggen_igniter/doc/gaps-to-fill-v26-9-1.md:159-170` (gap #4, verified read in this
session):

> `Controller.run_pipeline/1` calls `Reconcile.run(reconcile_opts)` unless
> `Application.get_env(:ggen_igniter, :use_reactor, false)` is true (default `false`) --
> opt-in, backwards from `Mix.Tasks.GgenIgniter.Sync`'s own `run_sync/3`, which now
> unconditionally tries `run_via_reactor/3` FIRST. `Reconcile.run/1` is a real,
> hand-maintained duplicate of a strict subset of `ReconcileReactor`'s own
> `:render`/`:admit`/`:actuate` steps ... Concrete fix: flip `Controller`'s default to
> `use_reactor: true` (or remove the flag entirely and always call
> `ReconcileReactor.run/1`; `receipt_to_legacy_result/2` already exists to reshape the
> output to `Controller`'s expected return shape) and retire `Reconcile.run/1` once
> `Controller` no longer needs it.

The document's own status header (`~/ggen_igniter/doc/gaps-to-fill-v26-9-1.md:1-5`,
`:21-28`, verified read in this session) records this gap's current disposition
honestly, and this report defers to that disposition rather than overclaiming it as
still-open, unaddressed work:

> ARCHIVED 2026-09-01: all 8 gaps closed (#1/#3/#6/#7/#8) or explicitly deferred
> (#2/#4/#5-mode:eval-half) as of v26.9.3. ...
> - **#4** `Controller` defaults to `Reconcile.run/1` not `ReconcileReactor` --
>   **DEFERRED, explicitly**. `docs/status.md` L80-81 confirms `ReconcileReactor` is
>   still `PARTIAL_ALIVE (not the default)` and `Reconcile.run/1` "is the default
>   today"; `docs/v26.9.1-requirements.md` Open Question 2 names this exact question
>   ... as explicitly unresolved/deferred past this release ...

So gap #4 is real and current (as of the archived doc's own status pass, `Reconcile.run/1`
remains the default, uncompensated path), but it is a disclosed, explicitly deferred
decision in the upstream project, not a silent defect.

### ggen_igniter — `mode: eval` targets crash `ReconcileReactor`'s `:render` step

`~/ggen_igniter/doc/gaps-to-fill-v26-9-1.md:174-186` (gap #5, verified read in this
session):

> `--for-each` half of this gap is closed: `--for-each` now routes through
> `GgenIgniter.Reactors.ReconcileReactor.run/1` ... with real `undo/3` compensation
> coverage ... `mode: eval` remains OUT of scope, unchanged: `ReconcileReactor`'s
> `:render` step still has the real, pre-existing, unconditional crash on `:eval`
> targets this gap's original text and
> `test/ggen_igniter_reconcile_reactor_test.exs`'s ":eval compensation-completeness"
> test both already named -- v26.9.2 did not touch this.

The original gap text (`~/ggen_igniter/doc/gaps-to-fill-v26-9-1.md:188-198`, verified
read in this session) is more specific about the mechanism:

> `run_via_reactor/3` (`lib/mix/tasks/ggen_igniter.sync.ex`) explicitly returns
> `{:not_delegatable, ...}` for `for_each not in [nil, ""]`, and separately falls back
> to the non-Reactor path for `mode: eval` (the `ReconcileReactor`'s own `:render` step
> has a real, disclosed `FunctionClauseError` crash on eval targets). Both fallback
> classes call `Actuate.write_file!/3`/`Actuate.eval_code!/2` directly from
> `run_pipeline!/3`, a plain function chain with no Reactor step and therefore no
> `undo/4` target at all. These are exactly the two feature classes most likely to need
> reverting -- fan-out touches multiple files per run, and `eval` runs arbitrary
> evaluated code -- and they inherited none of the compensation machinery ...

Net effect, both gaps together: the highest-risk actuation class in ggen_igniter
(`mode: eval`, arbitrary evaluated code) and the pipeline's own default entrypoint
(`Controller.run_pipeline/1`) both run outside `ReconcileReactor`'s real
compensate/4+undo/4 LIFO-revert coverage, as of the upstream project's own current,
disclosed status.

### ggen — `andon` is hardcoded `Green`, not derived from admission outcome

`~/ggen/CONSTITUTION.md:94-100` (Principle VII, Andon Signal Protocol; verified read in
this session):

> Stop the line immediately when quality signals appear (RED: compiler error/test
> failure/gate refusal -- stop all work; YELLOW: warning/lint/incomplete evidence --
> investigate before release; GREEN: safe to continue). Receipt andon MUST be derived,
> never asserted: a receipt's andon field MUST be computed from the admission decision
> over the evidence (all required evidence current and admitted -> Green;
> incomplete/unsupported -> Yellow; red/stale/inconsistent/refused -> Red). A
> synchronization event completing is an observation; it does not by itself produce
> Green.
>
> - **Mechanized:** false
> - **Enforced by:** crates/ggen-engine/src/sync.rs:1857 (write_receipt constructs
>   ReceiptRecord)
> - **Note:** ACTIVE DIVERGENCE, not merely unproven: crates/ggen-engine/src/sync.rs:1857
>   currently hardcodes `andon: Andon::Green` unconditionally inside write_receipt,
>   regardless of evidence, obligations, or admission outcome -- the exact opposite of
>   'derived, never asserted'. This is the concrete gap the constitution's own Sync
>   Impact Report names as pending the receipt-v2 epoch migration (Center 2, a separate
>   ongoing workflow phase). Falsely marking this true would itself be the Principle XI
>   violation this pack exists to prevent.

This is the ggen constitution's own admitted, self-disclosed active divergence — not an
inference from this report, and not independently re-verified against
`crates/ggen-engine/src/sync.rs:1857` itself in this session (`~/ggen` source tree was
not read line-by-line here; the constitution's own citation of that line is taken as
reported).

### ex4pm-side relevance (verified in this session)

This repo (`ex4pm`) is not the code location of any of the above gaps — they are
upstream in `~/ggen_igniter`/`~/ggen`. ex4pm's own evidence-derived-outcome discipline
is the direct analog this finding is measured against:

- `docs/ROADMAP-xaas-integration.md` (`~/ex4pm/docs/ROADMAP-xaas-integration.md`, mirrored
  from `~/xaas/docs/ROADMAP.md` per `CLAUDE.md`) documents `~/beam4pm` as `BLOCKED
  (external)` due to an in-progress, uncommitted git merge — the same "disclose the real
  blocked/deferred state rather than assert done" discipline this report applies to
  ggen_igniter's gaps #4/#5 and ggen's Principle VII divergence.
- `CLAUDE.md`'s "Evidence-forcing architecture" section (`~/ex4pm/CLAUDE.md`) states the
  same principle Principle VII's `andon` field is supposed to enforce for ggen: "Every
  generated fact carries a `sourceFile`/`sourceLine` citation ... Silence ... is
  untrustworthy by default." ggen's `sync.rs:1857` hardcoded `Andon::Green` is a concrete
  instance of exactly the failure mode that discipline exists to prevent — an assertion
  standing in for a derivation.

## Recommendation

For `~/ggen_igniter`:

1. Flip `Controller.run_pipeline/1`'s default from `use_reactor: false` to
   `use_reactor: true` (or remove the flag and call `ReconcileReactor.run/1`
   unconditionally, using the already-existing `receipt_to_legacy_result/2` to preserve
   `Controller`'s current return shape), matching `Mix.Tasks.GgenIgniter.Sync`'s
   already-Reactor-first `run_sync/3`. Retire `Reconcile.run/1` once `Controller` no
   longer depends on it.
2. Extend `ReconcileReactor`'s `:render` step to handle `mode: eval` targets without the
   current unconditional `FunctionClauseError` crash, so eval-mode actuation — the
   highest-risk actuation class (arbitrary evaluated code) — gets the same real
   `undo/3`/`undo/4` LIFO-revert compensation coverage `--for-each` already received in
   v26.9.2.

For `~/ggen`:

3. Derive `andon` in `write_receipt` (`crates/ggen-engine/src/sync.rs:1857`) from the
   real admission decision over the evidence (Green only when all required evidence is
   current and admitted; Yellow for incomplete/unsupported; Red for
   red/stale/inconsistent/refused), per Principle VII's own stated contract, instead of
   the current unconditional `andon: Andon::Green`. This closes the constitution's own
   named active divergence and removes the one case in this ecosystem where a receipt's
   headline status field is asserted rather than computed.

Both projects already have prior art for the fix in-repo (ggen_igniter's
`run_via_reactor/3` / `receipt_to_legacy_result/2`; ggen's own admission-decision
machinery cited elsewhere in the constitution for Principle XII, Evidence as Law) — this
is a wiring/default-flip class of fix in ggen_igniter and a genuine logic fix (replacing
a hardcoded constant with a real computation) in ggen, not new design work in either
case.

## Filed

- Date: 2026-09-09
- Filed by: ex4pm repo, upstream finding against `~/ggen_igniter` and `~/ggen`
- Claude-Session: https://claude.ai/code/session_01XWhXfubgh1b1rFNNStAQot
