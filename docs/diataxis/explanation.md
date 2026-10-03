# ex4pm Explanation

Understanding-oriented doc: why ex4pm is shaped the way it is. Everything below
is grounded in the source at `/Users/sac/ex4pm/lib/`.

## The governing calculus

Every state change in ex4pm passes through one fixed pipeline
(`Ex4pm.Information.manifest/0`, `lib/ex4pm/information.ex:28`, names it as the
architecture invariant):

```text
observation -> parse -> route -> admit | refuse -> construct
  -> BRCE -> DO -> receipt -> replay -> bounded standing
```

- **observation** — raw input arrives: an OCEL v2 map, XES XML, a streamed
  event, an envelope. Nothing is trusted yet.
- **parse** — `Ex4pm.OCEL.normalize/1` (`lib/ex4pm/ocel.ex:103`) and
  `Ex4pm.XES.parse/2` (`lib/ex4pm/xes.ex:10`) converge on one canonical
  `%Ex4pm.EventLog{}` regardless of source format.
- **route** — a request is matched against a closed, pre-declared set: the
  engine registry (`Ex4pm.Engine.Registry.engines/0`, `lib/ex4pm/engine.ex:79`)
  or the capability registry (`Ex4pm.Information.Registry`). No atom or module
  is ever manufactured from external strings.
- **admit | refuse** — the routed request is checked against an authority map
  (`Ex4pm.Evidence.BRCE.admit/2`, `lib/ex4pm/evidence.ex:277`) or a capability
  schema. Failure produces a typed `%Ex4pm.Refusal{}` (`lib/ex4pm/core.ex:30`) —
  never an exception across the public API, never a silent drop.

## CONSTRUCT and DO are different powers

The public API splits in two (`Ex4pm` moduledoc, `lib/ex4pm.ex:29-55`):

- **CONSTRUCT** — `discover/2`, `conform/3`, `simulate/2`, `optimize/3`,
  `plan/2`, `cmca/2`, `ferroplan/3`, `statistics/3`, `forecast/2`. These run an
  engine and record a pending and an outcome receipt. They compute evidence;
  they do not act on the world.
- **DO** — exactly one entry point: `operate/3`
  (`lib/ex4pm.ex:422`). It compiles a `%Ex4pm.POWL{}` into a Reactor plan
  (`Ex4pm.Runtime.compile/1`) and executes each task through
  `Ex4pm.Evidence.BRCE.execute/5`. BRCE first admits the explicit authority map:
  no authority, no `:do` capability, no execution — `:authority_required` /
  `:authority_denied`.

This split is why every analytical function returns `{:ok, %Ex4pm.Run{}} |
{:error, %Ex4pm.Refusal{}}` and why "standing" never upgrades itself: an
analytical result is at best `:partial_alive` until something with authority
actually executes.

## Standing is a bounded vocabulary, not a status string

`Ex4pm.Standing` (`lib/ex4pm/core.ex:1-28`) defines six values with a rank
lattice (`:alive` 4 > `:partial_alive` 3 > `:blocked` 2 > `:build_broken` 1 >
`:unsupported`/`:unknown` 0) and `min/2` composition. Composed systems inherit
the minimum: `Ex4pm.health/1` computes top-level standing as `Standing.min` of
the wasm4pm and ferroplan standings (`lib/ex4pm.ex:396-401`). SCREAMING_CASE
aliases (`ALIVE`, `BLOCKED`, …) rank identically, so logs written by different
tools compare equal.

## Engines are candidates, never ambient authority

`Ex4pm.Engine` (`lib/ex4pm/engine.ex:17-36`) is a four-callback behaviour.
`Ex4pm.Engine.Registry` keeps a closed list (`engines/0`): the generated
algorithm engines (ranks from the ontology-generated
`Ex4pmEngine.Wasm.AlgoRegistry`), plus `:beam`, `:ex4pm_plan`, `:cmca_wasm`,
`:wasm`, `:nif`, `:remote`, `:wasm_remote`, and `:ferroplan`.

Two consequences:

1. **Explicit never falls back.** `engine: :ferroplan` on a machine without the
   artifact refuses `:engine_blocked`; it does not silently run `:beam`
   (`lib/ex4pm/engine.ex:128-150`).
2. **Implicit selection is evidence-ranked with an opt-in fence.** A
   Host-fallback wasm engine that merely *could* run does not displace `:beam`
   on discover/conform/simulate/optimize because the wasm and beam result shapes
   differ (`lib/ex4pm/engine.ex:154-173`). Opt in with `prefer_wasm: true`, an
   explicit `:engine`, or an explicit `<algo>_wasm_fun` transport.

`Ex4pm.capabilities/2` and `Ex4pm.wasm/1` are inspection: every entry carries
`executed: false` (`lib/ex4pm.ex:364-373`). Only `Ex4pm.health/1` with
`probe: true` (default) actually executes a probe — inspection is never
execution.

## Receipts make results replayable

Each operation writes two content-addressed receipts to `Ex4pm.Evidence.Store`
(`lib/ex4pm/evidence.ex:78-202`): a `:pending` receipt (identity: subject hash,
operation, authority hash, started-at) and a `:outcome` receipt whose payload
includes the parent hash and the artifact hash of the result
(`Receipt.pending/4`, `Receipt.outcome/4`, `lib/ex4pm/evidence.ex:21-75`).
Because hashes are `sha256:` digests over canonicalized payloads
(`Ex4pm.Core.Hash.digest/2`, `lib/ex4pm/core.ex:76-114`), anyone can recompute
them: `Ex4pm.Evidence.Replay.verify/1` re-digests a single receipt;
`Ex4pm.Evidence.Replay.Chain.verify/2` walks the parent link in the store
(`replay: :chain_match`). `Ex4pm.replay/2` is the public wrapper. If the ledger
is unavailable, standing cannot advance: BRCE refuses with
`:pending_receipt_persistence_failed` / `:outcome_receipt_persistence_failed`
rather than executing unreceipted
(`lib/ex4pm/evidence.ex:349-367`).

## Falsifiers: how to prove any claim here wrong

- "Explicit engines fall back silently" — run
  `Ex4pm.discover(log, engine: :wasm_discover)` with no artifact present; the
  result is `{:error, %Refusal{code: :engine_blocked}}`, not a beam result.
- "DO happens without authority" — `Ex4pm.operate(model, nil)` returns
  `{:error, %{failure: %Ex4pm.Refusal{code: :authority_required}}}` (asserted in
  `test/ex4pm_test.exs:59-67`).
- "Receipts are decorative" — mutate any receipt field after the fact;
  `Ex4pm.replay/2` returns `{:error, %Refusal{code: :replay_mismatch}}`.

## Where the deeper material lives

- `docs/ARCHITECTURE.md` — full architecture
- `docs/CHICAGO.md` — testing discipline
- `docs/FRONTIER-RELEASE-PROCESS-INTELLIGENCE.md` — release process
- `CHANGELOG.md` — per-version public-contract changes (26.10.x explicitly
  declares envelope/BRCE authority-shape stability in "Public contract"
  subsections)
