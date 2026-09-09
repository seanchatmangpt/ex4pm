# ex4pm Explanation

Understanding-oriented reference for an AI agent or engineer who must discover and use
every real capability this codebase exposes. This document explains the *why* behind
the architecture; it is grounded in a freshly gathered per-namespace capability inventory of
`/Users/sac/ex4pm` and names no function, Mix task, or endpoint that inventory did not
contain.

## The governing calculus

Every state change in ex4pm passes through one fixed pipeline:

```text
observation -> parse -> route -> admit | refuse -> construct -> BRCE -> DO -> receipt -> replay -> bounded standing
```

- **observation** — raw input arrives: an OCEL v2 JSON payload, XES XML, a streamed
  event, an HTTP request body. Nothing has been trusted yet.
- **parse** — the raw shape is normalized into the canonical IR. `Ex4pm.OCEL.normalize/1`
  and `Ex4pm.XES.parse/2` (both in `Ex4pm.Core`, `lib/ex4pm/core/`) both converge on one
  `%Ex4pm.EventLog{}` struct regardless of source format.
- **route** — a request is matched against a closed capability table
  (`Ex4pm.Information.Registry.public_capabilities/0` in `Ex4pm.Information`) or an
  engine candidate list (`Ex4pm.Engine.Registry.engines/0` in `Ex4pm.Engine`). Routing
  never manufactures atoms or modules from external strings — every destination is a
  member of a pre-declared, static set.
- **admit | refuse** — the routed request is checked against a schema
  (`Ex4pm.Information.Registry.admit/1`) or an authority map
  (`Ex4pm.Evidence.BRCE.admit/2`). Failure produces a typed `%Ex4pm.Refusal{}`
  (`Ex4pm.Refusal.new/3`, `Ex4pm.Core`), never an exception or a silent drop.
- **construct** — analytical (non-mutating) work happens here: discovery, conformance,
  simulation, optimization, planning. This is everything reachable through
  `Ex4pm.discover/2`, `Ex4pm.conform/3`, `Ex4pm.simulate/2`, `Ex4pm.optimize/3`,
  `Ex4pm.plan/2`, `Ex4pm.cmca/2` (all in `lib/ex4pm.ex`). Construct produces
  evidence — it does not mutate durable state or execute side-effecting callbacks.
- **BRCE** — the sole boundary allowed to invoke a state-changing callback.
  `Ex4pm.Evidence.BRCE.execute/5` (`Ex4pm.Evidence`, `lib/ex4pm/evidence.ex`) admits authority, writes a
  `:pending` receipt, invokes the callback, and writes a terminating `:outcome` receipt
  (`:alive` on success, `:blocked` on exception/throw) — no invocation can escape
  without a receipt on both ends.
- **DO** — the actual state-changing effect, invoked only from inside a BRCE-wrapped
  closure. `Ex4pm.operate/3` (`lib/ex4pm.ex`) is the only public entrypoint that
  reaches DO, via `Ex4pm.Runtime.compile/1` + `Ex4pm.Runtime.execute/3`
  (`Ex4pm.Runtime`, `lib/ex4pm/runtime/`), which itself routes every individual POWL task through
  `BRCE.execute/5`.
- **receipt** — every pending/outcome pair is a hashed, content-addressed
  `%Ex4pm.Evidence.Receipt{}` (`Ex4pm.Evidence.Receipt.pending/4`,
  `Ex4pm.Evidence.Receipt.outcome/4`) persisted to `Ex4pm.Evidence.Store` (ETS) or
  `Ex4pm.Evidence.DetsStore` (restart-durable).
- **replay** — receipts are not trusted at face value; `Ex4pm.Evidence.Replay.verify/1`
  independently recomputes a single receipt's hash, and
  `Ex4pm.Evidence.Replay.Chain.verify/2` walks outcome -> pending parent and confirms
  subject/operation/authority correspondence, catching tampering or mismatch.
  `Ex4pm.replay/2` (`lib/ex4pm.ex`) is the public entrypoint.
- **bounded standing** — the pipeline terminates in a typed standing atom (see next
  section), never a bare boolean or an untyped string.

`Ex4pm.Information.execute/2` (`Ex4pm.Information`, `lib/ex4pm/information/`) is the single Reactor graph that
implements this entire calculus explicitly as a named flow
(`Ex4pm.Information.Flow`), with `Ex4pm.Information.Handlers.execute/2` as the only
bridge from an admitted capability id to a real `Ex4pm`/`Ash` function call — there is
no generic `apply`/dispatch path anywhere in that bridge.

## Why SELECT, CONSTRUCT, and DO are separate authority domains

- **SELECT** reads existing state without producing new evidence:
  `Ex4pm.Information.AshCatalog.catalog/0`, `Ex4pm.Information.AshCatalog.read/3`
  (read-only Ash actions only — `admit_read/3` explicitly refuses non-read actions),
  `Ex4pm.Evidence.Store.get/2`, `Ex4pm.capabilities/2`. Nothing here can mutate durable
  state or requires an authority map.
- **CONSTRUCT** is analytical work that produces new evidence (a discovered model, a
  conformance vector, a plan) but never mutates the domain's durable record of the
  world. `Ex4pm.discover/2`, `Ex4pm.conform/3`, `Ex4pm.plan/2`, and `Ex4pm.cmca/2` are
  all documented in the inventory as "receipted" but explicitly non-mutating —
  `Ex4pm.plan/2` and `Ex4pm.cmca/2` are called out as analytical CONSTRUCT with "no
  ambient cloud credentials" / "no DO authority."
- **DO** is the only domain that changes the world outside the receipt ledger:
  invoking an intervention's actuation, firing a POWL task's real callback. It is
  reached only via `Ex4pm.operate/3`, which requires an explicit `authority` map and
  crosses BRCE for every task.

The separation exists so that an agent (human or AI) can run unlimited SELECT/CONSTRUCT
work — discovery, simulation, differential comparison between engines
(`Ex4pm.differential/5`), planning, CMCA allocation — with full evidence receipts but
*zero risk of an unintended side effect*, and only the narrow, explicitly-authorized
`operate/3` path can ever cross into an effect that a receipt alone cannot undo. This
mirrors the classic separation of query from command: unsafe operations get a single,
auditable choke point instead of being reachable from every analytical function.

## Why BRCE is the sole state-change authority

`Ex4pm.Evidence.BRCE.execute/5` is the only function in the entire library (per the
inventory) that is allowed to invoke a state-changing callback. It does three things
atomically around that invocation, every time, with no bypass path:

1. **Admits** the caller's authority (`BRCE.admit/2` — requires `:do` in capabilities or
   the operation present in an explicit `:allow` list) before anything runs.
2. **Writes a `:pending` receipt** before the callback executes, so an in-flight
   invocation is never invisible.
3. **Writes a terminating `:outcome` receipt** after — `:alive` on success, `:blocked`
   on exception or throw — so no attempted invocation can go un-receipted, including
   ones that crash.

Concentrating this in one function is what makes the qualification suite's
`Ex4pm.Qualification.Scanners.BrceEnforcer` meaningful: it AST-scans the whole codebase for
any direct `Ash.create(Receipt, ...)` call that would mint a receipt-shaped record
without actually going through BRCE, i.e. a forged evidence artifact. If DO authority
were scattered across many functions, no static scan could enumerate every bypass.
Concentrating it in BRCE turns "did this state change happen legitimately" into a
single, auditable, AST-greppable question.

## The evidence/standing vocabulary

Every capability's status is expressed with one shared vocabulary, never an ad hoc
string:

| Standing | Meaning |
|---|---|
| `UNKNOWN` | Not yet inspected/measured. |
| `PARTIAL_ALIVE` | Executed, but identity/evidence admission was incomplete (e.g. a WASM or NIF engine ran but could not prove exact source SHA / library digest). |
| `ALIVE` | Executed with full evidence admission — exact identity proven, receipts chained, replay-verified. |
| `BLOCKED` | A BRCE-wrapped invocation raised or threw; the outcome receipt records this rather than losing the failure. |
| `BUILD_BROKEN` | The engine/component itself does not compile or load. |
| `UNSUPPORTED` | The operation is not implemented by this engine at all (`supports?/2` returned false). |
| `REFUSED` | A typed `%Ex4pm.Refusal{}` — a formal domain refusal with a code, message, subject, and details, distinct from a crash. |

`Ex4pm.Standing.rank/1`, `.min/2`, `.to_string/1` (`Ex4pm.Core`) give this vocabulary
total order and composition: combining evidence from multiple sources (e.g. multiple
engine rails) yields the *more pessimistic* of the two standings via `min/2`, so an
aggregate claim can never overstate what its weakest contributing piece of evidence
supports.

This vocabulary exists because "it works" is not a fact until it is backed by an
executed run with a specific standing — the whole `Ex4pm.Qualification` namespace exists to
verify that production code never asserts a standing it did not earn:
`Ex4pm.Qualification.LieFinder` scans for hardcoded metric numbers and bare-string
`standing` assignments that bypass this typed vocabulary, and
`Ex4pm.Qualification.Verifier.verify/1` independently *recomputes* every check in a
release "crown" (identity SHAs, POWL correspondence flags, all 5 engine rails, exit
codes, falsifiers) rather than trusting any stored `standing` field — a receipt's
claimed standing is only as good as its independent re-derivation.

## The flat library module architecture

ex4pm is one Mix app (`:ex4pm`), not a set of separate OTP applications — but the code
under `lib/ex4pm/` is still organized into the same logical layers the former umbrella
apps drew, now as namespaced module directories rather than compile-time app boundaries.
Each namespace exists to keep one concern from silently leaking into another, ordered
bottom-to-top by what each layer is allowed to assume exists below it:

- **`Ex4pm.Contracts`** (`lib/ex4pm/contracts.ex`) — the canonical semantic contract
  surface (ontology TTL, SHACL shapes, WIT world, receipt JSON Schema) as four fixed,
  hashed artifact identities. `Ex4pm.Contracts.verify/0` recomputes a combined
  `contract_hash` and checks each artifact's bytes for required terms, so drift between
  the declared contract and the actual files on disk is a caught event, not a silent
  divergence.
- **`Ex4pm.Core`** (`lib/ex4pm/core/`) — the canonical semantic IR and shared evidence
  primitives: `EventLog`, `ProcessIR`, `POWL`, OCEL2/OLAP views, `Ex4pm.Core.Hash`,
  `Ex4pm.Refusal`, `Ex4pm.Subject`, `Ex4pm.Standing`. This is the bottom of the
  namespace stack and the module group `~/xaas` is meant to depend on by pulling in
  `:ex4pm` as a whole — since the library flattened, there is no longer a separate app
  to depend on independently of Phoenix/Ash/Broadway/Reactor; those remain optional
  runtime dependencies xaas simply doesn't have to start (the demo web app that uses
  Phoenix lives outside the published library, under `test/demo_web/`).
- **`Ex4pm.Evidence`** (`lib/ex4pm/evidence.ex`, plus `lib/ex4pm/evidence/` for
  `DetsStore` and `ReplayChain`) — receipts, the BRCE boundary, replay
  verification, and standards-format evidence generation (EARL, SOSA, PROV-O, DCAT,
  SPDX). Kept as its own namespace, separate from `Ex4pm.Core`, because evidence/receipt
  machinery is a distinct concern from the IR itself — a receipt references a subject
  hash, it does not need to know how to parse XES.
- **`Ex4pm.Engine`** (`lib/ex4pm/engine.ex`, plus `lib/ex4pm/engine/` for the individual
  engine implementations) — the DfCM engine registry and all 25
  candidate engine implementations. Kept as its own namespace, separate from
  `Ex4pm.Core`/`Ex4pm.Evidence`, because engines are swappable execution strategies over
  the same IR — this namespace can grow new engine wrappers without ever touching the
  canonical types they operate on.
- **`Ex4pm.Runtime`** (`lib/ex4pm/runtime/`) — Reactor-based POWL compilation and
  BRCE-gated OTP execution, plus distributed multi-node execution. Separate from
  `Ex4pm.Engine` because runtime execution (DO) is a fundamentally different authority
  domain from engine selection (CONSTRUCT) — see the SELECT/CONSTRUCT/DO section above.
- **`Ex4pm.Domain`** (`lib/ex4pm/domain/`) — the Ash/ETS semantic control-plane
  projection (Agent, Event, Object, ConformanceResult, Receipt, ProcessModel,
  Intervention, EngineCapability). Kept as its own namespace so that persistence is an
  explicit, one-directional projection (`Ex4pm.Domain.Projector`) from core/evidence
  structs — nothing upstream depends on Ash, and persistence can never silently become
  the source of semantic truth.
- **`Ex4pm.Information`** (`lib/ex4pm/information/`) — the Reactor-based information
  plane and closed capability protocol. Separate from `Ex4pm.Domain` and top-level
  `Ex4pm` because it owns the *wire protocol* (request/response envelopes, JSON-safety,
  a static non-dynamic capability registry) rather than the orchestration logic itself.
- **`Ex4pm.Stream`** (`lib/ex4pm/stream/`) — Broadway-based backpressured, acknowledged
  ingestion. Kept as its own namespace because ingestion has its own operational
  concerns (backpressure, idempotency by sequence number, Prometheus telemetry) that are
  orthogonal to analytical operations.
- **`Ex4pm.Qualification`** (`lib/ex4pm/qualification/` for the crown, rails, verifier,
  reference-NIF, and POWL-court pieces; `lib/ex4pm_qualification/` — a separate
  top-level directory, not under `lib/ex4pm/` — for `Ex4pm.Qualification.LieFinder`,
  `Ex4pm.Qualification.ChicagoAuditor`, and `Ex4pm.Qualification.Scanners.BrceEnforcer`)
  — the anti-cheat/qualification suite. Deliberately outside the observation -> ... ->
  standing runtime path — it audits and independently re-verifies the claims that path
  produces, and must not be a dependency of anything it audits, or it could not be
  trusted as an independent check.
- **`Ex4pm`** (`lib/ex4pm.ex`) — the public orchestration API (`Ex4pm.ingest/2`,
  `.discover/2`, `.conform/3`, `.simulate/2`, `.optimize/3`, `.plan/2`, `.cmca/2`,
  `.operate/3`, `.stream/2`, `.capabilities/2`, `.differential/5`, `.replay/2`). This is
  the one module that is allowed to know about every layer below it and compose them
  into a single facade; nothing else in `lib/ex4pm/` is allowed to depend on `Ex4pm`
  itself, which is what keeps the dependency graph acyclic even though there is no
  longer a compile-time app boundary enforcing it.
- **`Ex4pm.Cli`** (`lib/ex4pm/cli.ex`) — the escript/CLI projection of `Ex4pm`'s public
  API (`Ex4pm.CLI.main/1`: `doctor`, `contracts`, `discover`, `discover-xes`), plus a
  separate Ash-resource-blueprint code-generation Mix task (`mix ex4pm.gen.blueprint`).

Outside the published library entirely: **`test/demo_web/`** carries the Phoenix/LiveView
HTTP surface (`POST /api/v1/ocel/events`, health/readiness endpoints, live dashboards,
AshAdmin) that used to be the `ex4pm_web` umbrella app. It is compiled only in the `:test`
environment (`elixirc_paths/1` in the root `mix.exs`) and exists as a demo/integration
harness that exercises the library end to end — it is not something a consumer depending
on `:ex4pm` pulls in, and it defines no orchestration logic of its own; it is a thin
projection over `Ex4pm.Stream`/`Ex4pm.Domain`.

The general rule: a namespace boundary exists wherever one authority domain, one
serialization concern, or one operational concern (persistence, wire protocol,
ingestion backpressure, engine selection, execution, audit) would otherwise leak into
another if left undifferentiated — the same rule the old umbrella app boundaries
enforced at compile time, now enforced by directory/module convention instead.

## The DfCM engine candidate model

`Ex4pm.Engine.Registry.engines/0` (`Ex4pm.Engine`, `lib/ex4pm/engine.ex`) holds a fixed ordered list of 25
candidate engine modules implementing the `Ex4pm.Engine` behaviour
(`id/0`, `supports?/2`, `available?/2`, `execute/3`):

- **`:beam`** — native, deterministic Elixir dispatch (`Ex4pm.Engine.Beam`).
  `available?/2` always returns true; this is the dependable fallback.
- **`:ex4pm_plan`** — a pinned cloud planning worker bridge (`Ex4pm.Engine.Ex4pmPlan`),
  pinned to an exact upstream source SHA and protocol version; only reaches `:alive`
  when the observed capsule identity (source SHA + image digest) is replay-verified,
  otherwise stays `:partial_alive`.
- **`:wasm`** — real Wasmex/Wasmtime execution of an admitted WASM artifact
  (`Ex4pm.Engine.Wasm`), gated by digest-based identity admission.
- **`:nif`** — a configured native NIF module (`Ex4pm.Engine.Nif`), reaching `:alive`
  only with exact `source_sha`/`library_digest`/toolchain identity proven, else
  `:partial_alive`.
- **`:remote`** — an explicit authenticated remote engine callback
  (`Ex4pm.Engine.Remote`), gated by tls/mtls transport plus image digest plus
  receipt-verified transport.

Plus a `:cmca_wasm` bridge and ~18 additional wasm4pm-workspace algorithm wrappers
(discover, conform, simulate, optimize, powl_mine, survival, markov, bayesian,
ocpq_eval, strips_plan, htn_plan, ctl_check, allen_temporal, align, etc_precision,
soundness, playout, oc_discover, prolog_query) — all candidates in the same registry.

`Ex4pm.Engine.candidates/2` *inspects* every registered engine's standing for a given
operation without executing anything, and `Ex4pm.Engine.select/2` picks the
highest-evidence-ranked *available* engine (or resolves an explicit `:engine` option),
refusing only if nothing is available. Wasm-native engines rank above `:beam`, which
ranks above the cloud/remote/nif candidates once they reach `:alive`/`:partial_alive`.

This is deliberately not a single hardcoded engine choice, for three reasons visible
directly in the inventory:

1. **No candidate is silently dropped.** An unavailable engine yields a typed standing
   (`:unsupported`, `:blocked`, `:build_broken`), not disappearance from the list — an
   agent asking "what can discover this log?" always gets the full picture, including
   what *isn't* available and why.
2. **Evidence-ranking, not preference-hardcoding, decides selection**, and the ranking
   itself is graded by how strong the identity admission is (`:alive` requires proven
   exact identity; `:partial_alive` is what you get from a real execution with
   incomplete identity proof) — so a faster or more capable engine is only preferred
   once it has actually earned that standing, not merely because it exists.
3. **Differential testing is a first-class capability**, not an afterthought:
   `Ex4pm.Engine.Differential.compare/5` (and the top-level `Ex4pm.differential/5`)
   runs the *same* operation/subject through two named engines and diffs the results;
   `Ex4pm.Qualification.Rails.verify/1` goes further and requires all 5 canonical rails
   (`:beam`, `:ex4pm_plan`, `:wasm`, `:nif`, `:remote`) to be `:alive` *and* to agree on
   a shared operation's canonical result hash before the release-level crown can be
   finalized. A single hardcoded engine could never be cross-checked this way — the
   candidate model exists specifically so that agreement across independently
   implemented engines is itself a form of evidence.

## See Also

- `/Users/sac/ex4pm/CLAUDE.md` — project overview, commands, flat library architecture
  summary, Chicago-style testing discipline, xaas integration status
- `/Users/sac/ex4pm/docs/CHICAGO.md` — the non-circular-worlds model behind
  `mix chicago` / `ex4pm.audit.chicago`
- `/Users/sac/ex4pm/docs/REACTOR_INFORMATION_PLANE.md` — the `Ex4pm.Information`
  Reactor flow in detail
- `/Users/sac/ex4pm/docs/ROADMAP-xaas-integration.md` — the `Ex4pm.Core`/
  `Ex4pm.Contracts` library-dependency boundary for `~/xaas`
- `AGENTS.md` (repo root) — the full observation -> ... -> bounded standing contract
