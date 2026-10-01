# VISION-2030-LOOP.md

## 1. Thesis

As of 2026-09-09, three repos (`ex4pm`, `xaas`, `ggen_igniter`/`ggen`) implement independently-named instances of the same pattern — admit an ontology fact, generate or execute against it, seal a receipt — but the loop that connects them across repo boundaries is closed in only two places (xaas's actuation-replay idempotency and ex4pm's single-repo ontology-to-engine sync) and open everywhere a fact has to cross a repo boundary: the xaas↔ex4pm OCEL envelope contract is a hand-pinned snapshot of one commit SHA, and no tooling exists anywhere in this ecosystem to generate an `AshJsonApi` route/router block for an already-existing resource. A genuine 2030 loop is the same receipted-generation pattern with those specific cross-boundary manual steps replaced by live ontology pointers and generated (not hand-pinned) contracts — not a new architecture, an extrapolation of exactly what already works in-repo, applied across repos.

---

## 2. The loop today (grounded, cited)

### 2.1 What enters, what processes it, what closes the loop

**Entry event:** an OCEL v2 process event produced by xaas's runtime.

**Layer 1 — xaas (app layer).** `Xaas.Telemetry.OcelForwarder` (hand-written, not ggen-generated — no generation header) builds an OCEL envelope using `lib/xaas/telemetry/ocel_envelope.ex`, which its own moduledoc (lines 1-9) states is a **hand-pinned snapshot of ex4pm's envelope shape at commit `725f495eb90d32a1582e6f44c08151d07743b784`**, read manually from `ex4pm/lib/ex4pm/ocel.ex:366-417` and explicitly disclosed as "vendors (not a live cross-repo pointer)." `POST /api/v1/ocel/events` on ex4pm's `OcelController` is the confirmed real network seam.

**Layer 2 — ex4pm (domain-library layer).** `Ex4pm.OCEL.validate_envelope/1` validates the incoming envelope. `Ex4pm.Evidence.BRCE` (`lib/ex4pm/evidence.ex:222`) is the sole authority permitted to execute a state-changing callback: a pending receipt must exist before invocation, an outcome receipt must terminate every attempted invocation.

**What closes the loop back around, today:**
- **xaas's actuation replay** — `Xaas.Actuation.run/4` mechanically returns the prior sealed `ActuationReceipt` on a repeated idempotency key with `status: :replayed`, no re-mutation (`docs/claude/diataxis/reference/actuation-and-semantics.md:33-80`) — a real closed loop for one specific mechanism (replay-safety), not for cross-repo drift.
- **ex4pm's `mix ex4pm.ggen.sync`** — regenerates ontology-derived modules directly from admitted ontology individuals; adding a capability is declared as ontology-edit-plus-sync rather than hand-written code.

### 2.2 What still requires a human or LLM session to close manually, today

1. **The xaas↔ex4pm OCEL envelope contract is a hand-pinned vendor snapshot, not a live pointer.** Any future drift in `ex4pm/lib/ex4pm/ocel.ex` requires a human/LLM to re-read the source at a new SHA and hand-update xaas's `ocel_envelope.ex` and its backing ontology pack. This is the exact gap the ex4pm↔xaas roadmap named as open, and per this research it remains open.
2. **xaas's own doctrine (`CLAUDE.md:5-24`) explicitly decouples landing code from a clean `mix test` run** — a standing, admitted policy that verification does not gate the next cycle in that repo. The loop from "generated" to "verified-passing" is deliberately left open there, not closed by CI gating, as a matter of policy rather than oversight.
3. **No AST-level or data-driven path exists anywhere in this ecosystem to expose an Ash resource/domain over JSON:API by generation.** Confirmed three ways: `ggen_igniter`'s `injection.ex`/`frontmatter.ex` are line-text splicers with zero DSL awareness (never touch `Ash.Resource` or `json_api do...end`); the one working Ash-generation pack (`ash-lifecycle-pack`) does whole-file EEx regeneration, never surgical injection, and contains no `json_api` vocabulary at all; the two Ash-extension-authoring packs (`ash-extension-core-pack`, `ash-extension-starter-pack`) manufacture brand-new Spark DSL extensions from scratch and have no ontology class or template for an `AshJsonApi` route/router on an *existing* resource — their only `json_api` reference is a test-fixture presence check (`composition_test.exs.tmpl:52`), explicitly disclosed as incomplete in `pack.toml:47-52`. And `AshJsonApi`'s own DSL (verified from real vendored source, `~/xaas/deps/ash_json_api` v1.7.1) is compile-time Spark-macro-based with no runtime/data-driven route list to target — a generator would have to emit literal macro-call source text, the same strategy as the existing (whole-file) Ash templates, since no structured-injection path exists to build on. This means JSON:API exposure of an Ash resource cannot currently be generated; it would have to be hand-written or the injection/template gap closed first.

---

## 3. The loop at 2030 — labeled TARGET / ASPIRATIONAL

Every claim below is traced to the specific real, today capability it extrapolates from. None are invented from nothing; none are asserted as already true.

**[TARGET] Envelope contracts become live cross-repo ontology pointers, not hand-pinned SHAs.**
Extrapolates from: xaas's real, working `ggen_igniter`-generated artifacts (`lib/xaas/telemetry/ocel_envelope.ex`, `lib/mix/tasks/xaas.library.manufacture.ex`, both real generation today from local ontology packs) combined with the pattern of merging a *consumer's* `ontology.ttl` with a *vendored pack's* `ontology.ttl` before querying. By 2030, xaas's OCEL envelope pack merges against ex4pm's *published* contract ontology (`Ex4pm.Contracts`, `priv/ontology/ex4pm.ttl` — already real and hash-manifested today per `Ex4pm.Contracts`'s own moduledoc) instead of a hand-copied snapshot, so a change to `Ex4pm.OCEL` propagates through a re-sync, not a manual re-read of source at a pinned SHA.

**[TARGET] JSON:API exposure for generated Ash resources becomes a fourth real ggen_igniter pack, not a manual write.**
Extrapolates from: the two concrete gaps this research closed with certainty — (a) `ggen_igniter` has zero AST/DSL-aware injection today, only line-text splicing (`injection.ex`, `frontmatter.ex`), and (b) the existing Ash packs (`ash-lifecycle-pack`, `ash-extension-core-pack`, `ash-extension-starter-pack`) never target `AshJsonApi`'s actual DSL, only whole-file resource regeneration or brand-new extension scaffolding. Since `AshJsonApi`'s `routes do get/index/post end` entries are real, confirmed compile-time `Spark.Dsl.Entity` macro calls with no data-driven escape hatch (verified against real vendored source, `~/xaas/deps/ash_json_api` `resource/resource.ex:82-134`), the only generation strategy that can work — templating literal macro-call source text, the same pattern the existing `resource.ex.eex` attribute/relationship template already uses successfully — is a known, buildable extension of a pattern that already works, not new invention. This is the single most concrete, well-specified gap in the entire ecosystem for reaching item 2's live connection.

**[TARGET] A shared, cross-repo receipt format unifies BRCE / receipt_chain / Actuation intent-receipt / ggen's BLAKE3 sync receipt.**
Extrapolates from: all four being real, independently confirmed implementations of the identical admit→act→seal→replay shape today (§3.1 below), with no shared module or schema currently linking them (confirmed: xaas's `path:` dependency on ex4pm pulls in `Ex4pm.OCEL`/`Ex4pm.Contracts`, not `Ex4pm.Evidence.BRCE`). Convergence into one importable receipt contract is a natural but currently unbuilt consolidation of four things that already independently work — this is the most speculative target in this document, since nothing in the research shows a schema-unification effort in progress anywhere.

**[TARGET] xaas's "don't gate on green tests" policy gets a bounded exception for generated-contract drift.**
Extrapolates from: xaas's own admitted, real, current policy (`CLAUDE.md:5-24`) of decoupling landing code from clean-test-run — stated here as a target only in the narrow sense that *if* item 1 (live envelope pointers) lands, drift becomes machine-detectable, at which point the existing policy could reasonably carve out an exception for that one class of failure. This is not a claim that the policy will change generally.

---

## 4. What closes automatically vs. still needs a human/LLM by 2030 — and why

**Closes automatically by 2030 (high confidence — direct extrapolation of working today-capability):**
- xaas's actuation replay idempotency (already automatic today, no change needed).

**Closes automatically only if the JSON:API-generation gap is built first (medium confidence — requires new pack work, but the pattern to extend is known and real):**
- The xaas↔ex4pm envelope contract becoming a live pointer instead of a SHA-pinned snapshot (technically independent of JSON:API generation, but depends on `Ex4pm.Contracts` being treated as the actual sync source rather than read-and-copied by hand).

**Likely never fully closes (name this honestly, not optimistically):**
- **Cross-repo receipt format unification.** The receipt mechanisms (`BRCE`, `receipt_chain`, `Xaas.Actuation`) are scoped to different authority domains by design — one gates in-process state-changing callbacks, one is an ontology-level manufacture-time requirement, one is an Ash-Reactor-backed runtime intent/receipt pair. Unifying their *schema* is plausible; unifying their *authority scope* would mean collapsing app-layer and library-layer authority into one boundary, which the research gives no evidence anyone intends — and collapsing it would arguably violate the SELECT/CONSTRUCT/DO separation that is this ecosystem's real differentiator (§5). The honest read: schema convergence is plausible by 2030; authority convergence is not, and should not be, a goal.
- **xaas's decoupled-verification policy**, because it is a deliberate, stated tradeoff (velocity over gating), not an oversight — there is no evidence in the research that anyone intends to close this, only that it could be narrowed for one failure class.

---

## 5. Nearest prior-art analogs, and where the real differentiator diverges

**Structural match:** The admit→construct→DO→receipt→replay shape most resembles **Temporal/Zeebe-style workflow engines** (durable execution with replay-from-history) crossed with **event-sourced/CQRS systems** (separate read/write authority, append-only fact log as source of truth).

**Where the real, tested differentiator diverges:** the SELECT/CONSTRUCT/DO authority separation, confirmed real in ex4pm today (`Ex4pm.Evidence.BRCE` as the sole DO-authority gate, `lib/ex4pm/evidence.ex:222`, restated in `AGENTS.md`/`docs/ARCHITECTURE.md`), is not merely a workflow-durability mechanism (what Temporal/Zeebe provide) — it is an **evidence-typed authority boundary enforced at the ontology/ RDF level before code generation happens at all**, not just at runtime dispatch. Temporal and Zeebe gate *execution order and retry semantics*; they do not gate *which ontology facts are admitted as true before any code is generated from them*. This ecosystem's actual differentiator, per the research, is that the receipt discipline starts upstream of runtime — at the `CONSTRUCT`/admission step that produces the ontology facts `ggen`/`ggen_igniter` then generate code from. No prior-art system surfaced in this research (Temporal, Zeebe, or otherwise) ties workflow durability to a SHACL-validated, ontology admission step upstream of code generation; that specific combination — not any single piece of it — is what this research finds real, tested, and structurally distinct.