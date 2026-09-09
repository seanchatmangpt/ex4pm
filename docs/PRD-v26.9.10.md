# PRD — ex4pm v26.9.10

## Source

This PRD is derived from real operational evidence, not speculation: a series
of beam4pm scheduled-task ("WS lane") receipts pasted into this session
(2026-08-29 through 2026-09-01/09-08), covering `ALIVE[WS3_CHICAGO_MERGE_50]`,
`ALIVE[WS3_FORTUNE5_RUNTIME_VALUE_50]`, `PARTIAL_ALIVE[MERGED_LOCAL_CAPSULE_
NAMESPACE_UNAVAILABLE]` receipts, a root-cause analysis of a real
`BUILD_BROKEN[TAKT_SHORTFALL]` failure (WS4's 50 constructed commits sitting
in an unmerged PR, not contained in default history), and the corrective
factory-architecture directive that followed it. beam4pm is architecturally
independent of ex4pm (confirmed this session — no `path:`/hex dependency
either direction) and this PRD does not propose one. What it proposes is
extracting the **real, evidence-load-bearing patterns** those receipts
exhibit into `ex4pm` itself, since they are structurally identical to
capabilities `ex4pm`'s own governing calculus (`observation -> parse -> route
-> admit | refuse -> construct -> BRCE -> DO -> receipt -> replay -> bounded
standing`) already claims to provide, and `ex4pm`'s current code (verified
below) does not yet fully cover them.

## What the evidence shows, precisely

1. **Reason-coded standing is real production usage beam4pm invented for
   itself.** Every receipt uses a `STANDING[REASON_CODE]` shape:
   `ALIVE[WS3_CHICAGO_MERGE_50]`, `PARTIAL_ALIVE[MERGED_LOCAL_CAPSULE_
   NAMESPACE_UNAVAILABLE]`, `BUILD_BROKEN[TAKT_SHORTFALL]`. Checked against
   `lib/ex4pm/core.ex`: `Ex4pm.Standing` is a bare atom
   (`rank/1`, `min/2`, `to_string/1`) with no reason/code payload. beam4pm
   had to invent its own bracket convention outside ex4pm's vocabulary to say
   something ex4pm's own vocabulary can't currently express.

2. **A durable, resumable batch-ledger concept is real and currently
   missing.** The RCA is explicit: "the architecture currently treats '50'
   as an instruction inside an automation prompt, rather than as a
   scheduler-level completion invariant," and the fix specified a concrete
   durable-state shape: `{base, target, admitted, qualified, published,
   merged, next_cell, standing}`, with a resume rule ("if execution budget
   ends anywhere: persist exact continuation state; next invocation resumes
   immediately; orientation/select work is prohibited"). Checked against
   `lib/ex4pm/evidence.ex`: `Ex4pm.Evidence.Receipt`/`Store`/`Replay`/`BRCE`
   exist and are real, but there is no batch/ledger primitive above a single
   receipt — nothing to resume a bounded multi-step transaction across
   process/session boundaries the way the RCA's `next_cell`/`qualified`
   state needs to.

3. **Containment proofs ("N ahead, 0 behind, X is an ancestor of Y") are a
   real, repeated verification shape** across every receipt (git
   ancestor/behind-count checks) that is structurally the same claim
   `Ex4pm.replay/2` already makes for a receipt chain, just applied to git
   history specifically. No git-containment helper exists in `lib/ex4pm/`
   today (checked: `Ex4pm.replay/2` operates on receipt hashes, not on git
   refs).

4. **The metric that mattered under real pressure was throughput of
   qualifying units through a pipeline, not raw commit count** — "Chicago-
   qualified commits newly merged / scheduled invocation," with a stated
   floor (`250 Chicago-merged commits/hour` across 5 lanes) and a named
   secondary diagnostic ("commits per observable factory action" — cheap
   proxy for hidden-turn efficiency, since `model_turns=UNSUPPORTED
   [NOT_EXPOSED]` was correctly refused rather than fabricated). This *is*
   process discovery/conformance over an event log — exactly ex4pm's own
   domain (`Ex4pm.discover/2`, `Ex4pm.conform/2`) — but applied here to a
   CI/manufacturing pipeline's own event stream, which nothing in ex4pm
   currently demonstrates as a worked example.

5. **The `UNSUPPORTED[NOT_EXPOSED]` refusal for unobservable model-turn
   count is a real validation of ex4pm's own evidence discipline** —
   independent confirmation (from a system that isn't ex4pm and doesn't
   depend on it) that "never fabricate an unobservable metric, emit a typed
   refusal instead" is the right discipline. No code follows from this
   directly; it's evidence the existing `UNKNOWN | PARTIAL_ALIVE | ALIVE |
   BLOCKED | BUILD_BROKEN | UNSUPPORTED` vocabulary is well-founded, not
   over-engineered.

## Requirements for v26.9.10

### R1 — `Ex4pm.Standing.Coded`: reason-coded standing

Add a coded-standing type alongside the existing bare-atom `Ex4pm.Standing`
(not replacing it — bare atoms stay valid for callers that don't need a
reason): `%Ex4pm.Standing.Coded{standing: atom(), code: String.t() | nil}`,
with `Ex4pm.Standing.Coded.new/2`, a `to_string/1` that renders
`"ALIVE[WS3_CHICAGO_MERGE_50]"`-shaped output matching the real convention
already in production use, and a `parse/1` that round-trips it back into
`{standing, code}`. `rank/1`/`min/2` should accept either the bare atom or
the coded struct (dispatch on the `.standing` field when given a struct).

### R2 — `Ex4pm.Evidence.Batch`: durable, resumable batch ledger

A new module modeling exactly the shape the RCA specified as missing:

```elixir
%Ex4pm.Evidence.Batch{
  id: String.t(),
  base: String.t(),
  target: non_neg_integer(),
  admitted: non_neg_integer(),
  qualified: non_neg_integer(),
  published: non_neg_integer(),
  merged: non_neg_integer(),
  next_cell: String.t() | nil,
  standing: Ex4pm.Standing.Coded.t()
}
```

Public API: `new/2` (id, target), `advance/2` (batch, delta-map — bumps
counters, updates `next_cell`), `resume/1` (given a batch struct, e.g. read
back from wherever the caller persists it, returns whether continuation is
required or work is prohibited — mirrors the RCA's rule 2: "if active batch
exists, NEVER start another batch, continue it"), `quota_met?/1` (checks
`qualified >= target`), `close/1` (transitions standing to
`Ex4pm.Standing.Coded.new(:alive, id <> "_50")` when `qualified >= target`,
else a coded `:build_broken` with a `"TAKT_SHORTFALL"`-shaped code).
**ex4pm itself does not persist this anywhere** (no database, no file store
beyond what `Ex4pm.Evidence.Store` already does for receipts) — persistence
is the caller's job, same as `Ex4pm.Evidence.Store` already being an
in-memory GenServer a caller can swap. This is a data-shape + transition-
logic contract, not a new storage subsystem.

### R3 — `Ex4pm.Evidence.GitContainment`: git ancestor/behind-count verification

A small, real wrapper (subprocess-based, real `git` calls — Chicago
discipline, no libgit2 binding needed for this scope) exposing:
`ancestor?/2` (is commit A an ancestor of ref B), `ahead_behind/2` (returns
`%{ahead: n, behind: n}` for two refs, matching the "55 commits ahead, 0
behind" shape every receipt reports), and `containment_receipt/3` (base,
qualified_head, final_ref — returns a receipted map combining both checks,
directly usable as evidence in a caller's own standing computation). This
turns a pattern every WS lane currently hand-rolls via ad hoc `git`
invocations into one reusable, tested primitive.

### R4 — Worked example: mining a CI/manufacturing pipeline as an OCEL v2 log

Add `docs/consumer/how-to-guides.md` (or a new example doc) section: "How to
mine your own CI/scheduled-task pipeline for throughput and conformance."
Concretely: model each qualifying-commit/crown/merge/repair event as an OCEL
v2 event (`event_type` = "commit_qualified" | "crown_run" | "merge" |
"rca_repair", `object_type` = "batch"/"lane"), ingest via `Ex4pm.ingest/2`,
run `Ex4pm.discover/2` to get the real directly-follows graph of a lane's
actual behavior, and `Ex4pm.conform/2` against a declared expected model
(e.g. "quota-closing merge event must occur within N hours of batch start").
This is the concrete mechanism that would have surfaced WS4's
`50 constructed != 50 contained` gap automatically (a real conformance
violation — an expected "merge" event absent within the window) instead of
requiring a human to manually cross-reference scheduler logs against merge
timestamps, which is what actually happened in the source incident. This
requirement produces documentation and a runnable example only — no new
library code beyond what R1-R3 add.

## Explicitly out of scope

- No dependency from beam4pm (or any consumer) on this release is implied
  or required — R1-R3 are opt-in library capabilities; beam4pm's own WS
  lanes remain free to keep their bracket convention/git-plumbing as-is.
- No change to `ex4pm`'s core OCEL/POWL/discovery/conformance algorithms —
  R4 is a documentation/example use of what already exists (`Ex4pm.ingest/2`,
  `discover/2`, `conform/2`), not new algorithmic work.
- No scheduler/orchestration code — the RCA's "scheduler ≠ factory" fix
  belongs to whatever runs the scheduled tasks (outside ex4pm's scope
  entirely); ex4pm only provides the data shapes (R1, R2) and verification
  primitive (R3) a factory implementation would use.

## Verification plan (once implemented)

- `Ex4pm.Standing.Coded.to_string/1` round-trips every real example standing
  string quoted in the source receipts above (`ALIVE[WS3_CHICAGO_MERGE_50]`,
  `PARTIAL_ALIVE[MERGED_LOCAL_CAPSULE_NAMESPACE_UNAVAILABLE]`,
  `BUILD_BROKEN[TAKT_SHORTFALL]`) as literal test fixtures — not invented
  examples.
- `Ex4pm.Evidence.Batch` state machine tested against the exact RCA-specified
  transition rules (resume-first, never-start-second-batch-while-active,
  quota-gated close) as explicit Chicago-style tests, one per rule.
- `Ex4pm.Evidence.GitContainment` tested against a real, disposable git repo
  fixture created and torn down per test (real `git` subprocess calls, no
  mocking, matching this repo's own testing discipline) with real ahead/
  behind counts asserted, not fabricated.
- R4's example doc includes a runnable snippet exercised in CI the same way
  other `docs/consumer/*.md` examples are (per the existing Diataxis
  tutorial pattern already in this repo).
