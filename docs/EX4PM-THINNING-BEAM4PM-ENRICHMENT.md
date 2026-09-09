# EX4PM-THINNING-BEAM4PM-ENRICHMENT.md

## Ex4pm Thinning / Beam4pm WASM Enrichment

**Status:** PROPOSAL — not yet started. **Date:** 2026-09-09.

**Summary:** ex4pm embeds a real Wasmex/Wasmtime execution surface (`lib/ex4pm_engine/wasm/`, `Ex4pm.Engine.Wasm`, `Ex4pm.Engine.CmcaWasm`, `{:wasmex, "~> 0.14"}` in `mix.exs:101`) that runs WASM artifacts in-process. This contradicts the role split already stated in `~/ex4pm/CLAUDE.md`: "beam4pm is a separate runtime ... reached only over the network (HTTP/PubSub), never as a compile-time dependency of anything outside its own repo." WASM execution is exactly the kind of heavy runtime concern that doctrine assigns to beam4pm, not to ex4pm. This document proposes moving WASM execution ownership to beam4pm — which already hosts four real Wasmex engines today, though none of them exposed over a network boundary yet — and replacing ex4pm's in-process `:wasm`/`:cmca_wasm` engine candidates with a network-backed candidate that calls beam4pm's existing `Ex4pm.Engine` contract (`supports?/2`, `available?/1`, `execute/3`), following the pattern `Ex4pm.Engine.Remote` already establishes in-repo. The end state is ex4pm as "the thinnest possible" library: `Ex4pm.Core`, `Ex4pm.Contracts`, `Ex4pm.Evidence`, and the engine *contract* stay; Wasmex, `rustler`, `rustler_precompiled`, and 36 files / 1,360 LOC of hand-written WASM adapter code move out.

---

## 1. Motivation

### 1.1 The role split, already stated doctrine

`~/ex4pm/CLAUDE.md`'s "External integration: xaas wants to depend on ex4pm" section is explicit:

> "beam4pm is a separate runtime (the actual execution substrate — Rust rf1-rf4 oracles, whatever receipt/actuation machinery survives its current merge) reached only over the network (HTTP/PubSub), never as a compile-time dependency of anything outside its own repo — xaas has no business knowing beam4pm's internal module names."

That sentence names the intended shape: ex4pm is a thin, publishable library other apps `path:`/hex-depend on; beam4pm is a heavy execution substrate reached only over HTTP/PubSub. WASM execution — spinning up Wasmtime instances, managing linear memory, marshaling ptr/len ABI calls — is exactly the "actual execution substrate" character that sentence assigns to beam4pm. Today it lives in ex4pm instead.

### 1.2 The inconsistency, in real numbers

Per the `ex4pm-wasm-surface` research (grounded inventory, this repo, `pwd` confirmed `/Users/sac/ex4pm`):

- `mix.exs:101` — `{:wasmex, "~> 0.14"}`, ex4pm's only WASM dependency line.
- `lib/ex4pm/engine/adapters.ex:1-113` — `Ex4pm.Engine.Wasm`, raw `Wasmex.start_link/1` (`adapters.ex:45`) + `Wasmex.call_function/4` (`adapters.ex:47`) against a configured `:wasm_path` artifact.
- `lib/ex4pm/engine/cmca_wasm.ex` (237 LOC) — `Ex4pm.Engine.CmcaWasm`, an injected-callback adapter (no direct Wasmex import, but pins wasm4pm/BCINR source SHAs as string constants at `cmca_wasm.ex:19,23`).
- `lib/ex4pm_engine/wasm/` — 36 files, 1,360 LOC total:
  - `real_transport.ex` (485 LOC) — `Ex4pmEngine.Wasm.RealTransport`, the actual Wasmex/Wasmtime driver: `Wasmex.start_link/1` (`real_transport.ex:98`), `Wasmex.Memory.write_binary/read_binary` (`real_transport.ex:214-222,244-249,475`), `Wasmex.call_function/3` for the ptr/len ABI (`real_transport.ex:452,459,466`). This file also documents a real, named upstream gap: 87 `__wbindgen_placeholder__` stub imports (`real_transport.ex:56-73`) — i.e. the in-process WASM execution surface is not even fully functional against its own target artifacts today.
  - `adapter.ex` (297 LOC) — the shared six-state-standing `use`-macro all leaf adapters build on.
  - `algo_registry.ex` (22 LOC) — currently lists only `:mean` as a canonical registered algorithm (`algo_registry.ex:16-18`), despite 33 leaf adapter files existing.
  - 33 leaf adapter files (16-22 LOC each). 17 of 33 carry a moduledoc citation to `~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack` (e.g. `discover.ex:3-4`). **That pack does not exist** — confirmed no such directory under `~/ggen-marketplace/packs/`. The citation is false as written; all 36 files in this directory are hand-written, not machine-generated, despite claiming otherwise.
- Test surface: `test/wasm/` + related reactor/benchmark tests total 1,992 LOC across 10 files (`adapters_smoke_test.exs` 102, `discover_test.exs` 93, `phase123_edge_cases_test.exs` 291, `phase2_adapters_smoke_test.exs` 227, `phase3_adapters_smoke_test.exs` 157, `phase4_edge_cases_test.exs` 295, `real_transport_test.exs` 118, `wasm_capabilities_reactor_test.exs` 84, `wasm_all_capabilities_test.exs` 431, `wasm_engine_benchmark_test.exs` 194), plus `Wasmex` references in `test/engine_test.exs` and `test/property/powl_reactor_correspondence_property_test.exs`.

This is not a small, incidental engine candidate. It is ~1,360 LOC of hand-written, partially-unverified (false pack citation, documented 87-stub-import gap) execution machinery embedded directly in a library whose own `CLAUDE.md` says heavy execution substrate belongs in a separately-reached network service.

### 1.3 Coupling points a thinning pass would need to sever

Per `engine-registry-contract` and `ex4pm-wasm-surface` research, exactly two files outside `lib/ex4pm_engine/wasm/` couple to this surface:

- `lib/ex4pm/engine.ex:41-92` — `Ex4pm.Engine.Registry`'s fixed `@engines` list `alias`es `CmcaWasm`, `Wasm`, and all 20 `Ex4pm.Engine.Wasm.*` leaf modules; this is what `Ex4pm.discover/2`, `Ex4pm.conform/2`, `Ex4pm.simulate/2`, `Ex4pm.optimize/2` route through for candidate selection.
- `lib/mix/tasks/ex4pm.engine.gen.adapter.ex:3,11,62,72` — the Mix task that generated the 33 leaf files, itself calling `Ex4pm.Engine.Wasm.execute/3`.

No core/contracts file (`Ex4pm.Core.*`, `Ex4pm.Contracts`) references Wasmex or the wasm engine modules.

---

## 2. Current State (grounded inventory)

| Concern | Location | LOC | Generated / hand-written |
|---|---|---|---|
| Dependency declaration | `mix.exs:101` (`{:wasmex, "~> 0.14"}`) | 1 line | n/a |
| In-process engine, path-configured artifact | `lib/ex4pm/engine/adapters.ex:1-113` (`Ex4pm.Engine.Wasm`) | ~113 | hand-written, no pack citation |
| Injected-callback CMCA adapter | `lib/ex4pm/engine/cmca_wasm.ex` | 237 | hand-written |
| Wasmtime driver | `lib/ex4pm_engine/wasm/real_transport.ex` | 485 | hand-written; documents 87 unresolved `__wbindgen_placeholder__` stub imports |
| Adapter macro | `lib/ex4pm_engine/wasm/adapter.ex` | 297 | hand-written |
| Algorithm registry | `lib/ex4pm_engine/wasm/algo_registry.ex` | 22 | hand-written; only `:mean` registered |
| 33 leaf adapters | `lib/ex4pm_engine/wasm/*.ex` | ~561 (36-file dir total 1,360 minus above) | hand-written; 17/33 falsely cite a nonexistent ggen pack |
| Reactor wiring | `lib/ex4pm_engine/reactors/wasm_capabilities_reactor.ex` | n/a | aliases `Adapter`/`RealTransport` directly |
| Tests | `test/wasm/*` + reactor/benchmark tests | 1,992 | — |
| Registry coupling | `lib/ex4pm/engine.ex:41-92` | — | `@engines` list includes `Wasm`, `CmcaWasm`, 20 `Ex4pmEngine.Wasm.*` modules |
| Generator tooling | `lib/mix/tasks/ex4pm.engine.gen.adapter.ex` | — | calls `Ex4pm.Engine.Wasm.execute/3` |

Separately, `lib/wasm4pm_compat/ash_types.ex` (209 LOC, `Wasm4pmCompat.AshTypes.*`) has no Wasmex reference and is out of scope for this proposal — it is Ash type-wrapper code, not execution machinery.

**Total in-scope surface: ~2,000 LOC of hand-written engine/adapter code plus ~1,992 LOC of tests, one dependency line pulling `wasmex` (which itself pulls `rustler` and `rustler_precompiled` non-optionally per `mix.lock:81,62,63`), and two coupling points in the public engine registry.**

---

## 3. Target State

`Ex4pm.Engine` (the behaviour at `lib/ex4pm/engine.ex:17-24`: `id/0`, `supports?/2`, `available?/1`, `execute/3`, returning `{:ok, %Ex4pm.Engine.Result{}}` or `{:error, %Ex4pm.Refusal{}}`) is the load-bearing contract and **does not change**. It is already transport-agnostic — `Ex4pm.Engine.Remote` (`lib/ex4pm/engine/adapters.ex:215-307`) already proves a network-shaped candidate fits this contract cleanly: `supports?/2`/`available?/1` reduce to "is a callback configured," `execute/3` dispatches through the injected callback, and `admit_identity/2` (`adapters.ex:275-297`) gates `:alive` vs `:partial_alive` standing on `transport in [:tls, :https, :mtls, ...]`, a binary `source_sha`, a binary `image_digest`, and `receipt_verified == true`.

**Stays in ex4pm:**
- `Ex4pm.Engine` behaviour and `Ex4pm.Engine.Registry`/`candidates/2`/`select/2` (`lib/ex4pm/engine.ex`) — the contract, preference table, and typed-refusal selection logic are pure orchestration, not execution.
- `Ex4pm.Engine.Remote` and `Ex4pm.Engine.Ex4pmPlan` shape — the pattern a new `:wasm` network candidate should imitate.
- `Ex4pm.Core`, `Ex4pm.Contracts`, `Ex4pm.Evidence`, `Ex4pm.Domain`, `Ex4pm.Information`, `Ex4pm.Stream` — untouched; none reference Wasmex per the `consumer-impact` research's grep.

**Moves to beam4pm:**
- The actual WASM hosting: `Ex4pm.Engine.Wasm`'s in-process Wasmex calls, `Ex4pmEngine.Wasm.RealTransport`'s Wasmtime driver, and the 33 leaf adapters' algorithm-specific ABI knowledge — this logic is re-homed as beam4pm-side execution behind an HTTP endpoint, not reimplemented from scratch (beam4pm already has 4 working Wasmex engines with equivalent ptr/len-ABI marshaling patterns per §4).
- `{:wasmex, "~> 0.14"}` and its forced `rustler`/`rustler_precompiled` transitive deps leave ex4pm's `mix.exs` entirely.

**New in ex4pm:**
- A `:wasm` (or renamed, e.g. `:beam4pm_wasm`) engine candidate module implementing `Ex4pm.Engine`, modeled directly on `Ex4pm.Engine.Remote`: an injected transport callback (not a hardcoded HTTP client), `{:ok, value, identity}` tuple carrying `source_sha`/`image_digest`/`transport`/`receipt_verified`, `exact_identity?/1`-style gating, and typed `Refusal`s (`:wasm_unavailable`, `:wasm_identity_mismatch`, etc. — reusing the existing refusal vocabulary from `adapters.ex:31,37,91,72,78` where semantically apt) for every unavailable/mismatched branch.

---

## 4. What beam4pm needs to build first (real prerequisite, not glossed over)

Per `beam4pm-wasm-capability` research (`pwd` confirmed `/Users/sac/beam4pm`), the honest state is mixed — **not** "zero real WASM hosting," but also **not** "ready to serve ex4pm over the network today."

**What beam4pm has (real, working):**
- `{:wasmex, "~> 0.15"}` (`mix.exs:50`).
- Four independently verified, named Wasmex GenServer engines: `BeamPM.Rust4PM.Engine` (`lib/beam4pm_rust4pm.ex`, `Wasmex.start_link/1` line 179, `Wasmex.call_function/4` line 582, `Wasmex.Memory.write_binary/read_binary` lines 591/609 — XES import, variants, DFG); `BeamPM.Ferroplan.Engine` (`lib/beam4pm_ferroplan.ex`, PDDL planning); `BeamPM.Petgraph.Engine` (`lib/beam4pm_petgraph.ex`, graph algorithms); `BeamPM.Tract.Engine` (`lib/beam4pm_tract.ex`).

**What beam4pm does NOT have (the real gap, scoped as prerequisite work):**
1. **No network-exposed WASM execution endpoint.** `lib/beam4pm_application.ex:1-27` starts exactly one child: `{Bandit, plug: BeamPM.OcelIngest.Router, port: port}`. `BeamPM.OcelIngest.Router` (`lib/beam4pm_ocel_ingest.ex`) exposes exactly two routes — `POST /ocel/events` (line 31), `POST /ocel/objects` (line 36) — with an explicit 404 fallback (line 40). There is no WASM-execution route today. A consumer-facing execution endpoint (e.g. `POST /wasm/execute`) does not exist and must be built.
2. **None of the four Wasmex engines are supervision-tree children.** `Application.start/2`'s `children` list does not include any of the four `*.Engine` GenServers — they are started ad hoc by their own callers. A network-facing execution service needs these (or a new dispatch layer routing to them) actually supervised, so a crashed WASM instance doesn't take down the whole node or go unrestarted.
3. **RF4 has no bridge at all.** `native/rf4-oc-discovery-oracle/` exists as a compiled Rust crate, but `grep` for `RF4`/`rf4-oc-discovery-oracle` under `lib/` returns zero matches — no `lib/beam4pm_rf4_*.ex` module invokes it. (Out of scope for this WASM-thinning proposal specifically — RF4 is a native-Port oracle, not WASM — but noted since it is the same "capability inventoried, network path unbuilt" pattern.)
4. **No identity/receipt contract matching `Ex4pm.Engine.Remote`'s admission logic.** ex4pm's `admit_identity/2` (`adapters.ex:275-297`) expects `source_sha`, `image_digest`, `transport`, `receipt_verified` in every response. Nothing in beam4pm's current Bandit router or the four engines' return shapes was found to produce this identity envelope — it must be built as new response-shaping code in beam4pm, not assumed to exist.
5. **No dedicated timeout refusal.** Per `engine-registry-contract` research, `Ex4pm.Engine.Remote` has no `:remote_timeout` atom distinct from "no callback configured" (`:remote_unavailable`); a real network hop to beam4pm can time out distinctly from being unconfigured, and ex4pm's refusal vocabulary needs a new atom (e.g. `:wasm_remote_timeout`) to represent that honestly rather than folding it into `:wasm_execution_failed`.

**Scope statement:** items 1, 2, and 4 above are the real, load-bearing prerequisite work in beam4pm before Phase 0 of the migration (§6) can start. This document does not estimate their effort or commit beam4pm engineering time — see §8.

---

## 5. Consumer impact

Per `consumer-impact` research (`/Users/sac/xaas`, `pwd` confirmed), the xaas → ex4pm dependency is real and active, not aspirational: `xaas/mix.exs:214` — `{:ex4pm, path: "../ex4pm"}`, uncommented, resolved. xaas's own `mix.exs` has no `wasmex` entry directly (confirmed via grep) — the pull is entirely transitive through ex4pm's `mix.exs:101`.

`xaas/mix.lock` confirms the transitive pull is live: `wasmex` 0.15.1 (`mix.lock:183`, pulling `rustler ~> 0.38` and `rustler_precompiled ~> 0.9` non-optionally), plus `explorer` 0.12.0 (`mix.lock:20`, `rustler` optional in `explorer`'s own spec).

**Removable-dependency estimate if `wasmex` leaves ex4pm's `deps()`:** 3 of ex4pm's own 85 locked packages (`wasmex`, `rustler`, `rustler_precompiled` — `mix.lock:81,62,63`), since nothing else in ex4pm's tree forces `rustler`/`rustler_precompiled` non-optionally. If `Explorer` (used only in `lib/ex4pm/engine/differential.ex`, per grep confirming zero hits under `lib/ex4pm/core` or `lib/ex4pm/contracts.ex`) also moved out, add `explorer`, `table`, `table_rex` — roughly 4-6 of 85 total (~5-7%).

This is a modest, honestly-stated number — not a claimed double-digit reduction. The `consumer-impact` research explicitly flags what was **not** verified: how `rustler`/`wasmex` propagate through xaas's own full dependency resolution beyond what's directly visible in its lock file (a `mix deps.tree` pass was not run, to avoid mutating either tree in a read-only research pass). The qualitative benefit — xaas no longer needing to compile/vendor `rustler`'s NIF toolchain transitively through a library dependency it uses only for `Ex4pm.Core`/`Ex4pm.Contracts` — is real regardless of the exact package count, since `rustler` requires a native Rust toolchain at build time that xaas's own `mix.exs` deps() list does not otherwise need.

---

## 6. Migration phases

**Phase 0 — Stand up beam4pm's WASM execution endpoint, prove it standalone.**
Build the missing pieces from §4: a Bandit route (e.g. `POST /wasm/execute`) added to `BeamPM.OcelIngest.Router` or a new sibling `Plug.Router` added to `BeamPM.Application`'s `children`; supervise the four existing Wasmex engines (or a subset scoped to what ex4pm's 33 leaf adapters actually need) as real children rather than ad hoc GenServers; produce responses carrying `source_sha`/`image_digest`/`transport`/`receipt_verified`. Verify with real HTTP calls against real WASM artifacts (Chicago-style — no mocked transport), independent of ex4pm.

**Phase 1 — Add a network-backed `:wasm` candidate to ex4pm alongside the existing in-process one.**
New module implementing `Ex4pm.Engine`, modeled on `Ex4pm.Engine.Remote`, added to `Ex4pm.Engine.Registry`'s `@engines` list (`lib/ex4pm/engine.ex:41-92`) as an additional candidate — not a replacement yet. Differential-verify: for every operation the 33 leaf adapters currently support, run both the in-process `Ex4pm.Engine.Wasm`/`Ex4pmEngine.Wasm.*` path and the new network-backed path against the same subject, assert identical `%Ex4pm.Engine.Result{}` values (or a documented, justified divergence). This produces a real receipt that beam4pm's execution matches ex4pm's existing behavior before anything is removed.

**Phase 2 — Flip the default preference, deprecate the in-process candidate.**
Adjust the fixed preference table (`lib/ex4pm/engine.ex:174-205`) so the network-backed `:wasm` candidate ranks above the in-process one for `select/2`'s implicit (no explicit `:engine` opt) path. Mark `Ex4pm.Engine.Wasm`/`Ex4pmEngine.Wasm.*` deprecated in moduledocs. Keep both live so an explicit `engine: :wasm_inprocess` (or similarly renamed) opt still works during a transition window.

**Phase 3 — Remove the in-process WASM surface entirely.**
Delete `lib/ex4pm_engine/wasm/` (36 files, 1,360 LOC), `lib/ex4pm/engine/adapters.ex`'s `Ex4pm.Engine.Wasm` module (~113 LOC) and `lib/ex4pm/engine/cmca_wasm.ex` (237 LOC), the two coupling points in `lib/ex4pm/engine.ex:41-92` and `lib/mix/tasks/ex4pm.engine.gen.adapter.ex`, and `test/wasm/*` (1,992 LOC across 10 files, replaced by tests against the network-backed candidate — using a real reachable beam4pm instance per Chicago-style discipline, not a mocked HTTP client). Remove `{:wasmex, "~> 0.14"}` from `mix.exs`. Run `mix verify` and confirm `mix.lock`'s package count drops by the 3 (or up to 6, if `explorer` also moves) packages identified in §5.

---

## 7. Risks / open questions

- **Network-hop latency in differential verification (Phase 1).** Comparing in-process and network-backed execution for every operation adds a real HTTP round-trip per comparison; this is expected to be acceptable for a one-time verification pass but was not benchmarked in this document and should be measured before committing to Phase 1's scope.
- **Availability coupling.** Once Phase 2 flips the default, `ex4pm`'s WASM-backed operations become unavailable whenever beam4pm (or the network path to it) is down, where today they only depend on a local file being present. `Ex4pm.Engine.Registry`'s existing `:blocked`/`Refusal` machinery already models this correctly (a candidate can be `supported` but not `available`), but this is a real behavior change for any caller who assumed local-only availability.
- **No consumer currently pins to in-process WASM behavior specifically.** Per the `consumer-impact` research, xaas's dependency is on `Ex4pm.Core`/`Ex4pm.Contracts`, not on the engine layer — no evidence was found of xaas calling `Ex4pm.Engine.Wasm` or any `Ex4pm.Engine.Wasm.*` module directly. This lowers the risk of Phase 3 breaking a real consumer, but was only checked for xaas, not for any other unknown consumer of ex4pm as a library.
- **The false ggen-pack citation (§1.2) — RESOLVED, 2026-09-09.** All 19 leaf adapters that falsely cited `ex4pm-wasm4pm-bindings-pack` (the real count, not the 17 an earlier pass estimated) now cite the real `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/{lib,phase2,phase2_playout,prolog}.rs` source file each algorithm's export actually lives in, verified per-file by grepping the real export name rather than assumed. `mix compile --warnings-as-errors` clean; zero remaining `grep -rl "ex4pm-wasm4pm-bindings-pack" lib/ex4pm_engine/wasm/*.ex` matches. This does not change whether the pack is ever built, or whether this execution surface still moves to beam4pm per this document's own Phase 3 — only the false provenance claim is fixed.
- **Beam4pm's own merge-in-progress blocker.** Per `~/ex4pm/CLAUDE.md`, beam4pm currently has an in-progress, uncommitted git merge and the roadmap's explicit resume trigger says not to touch it until the user confirms that merge is committed. Phase 0 work in beam4pm cannot start until that is resolved — this document does not resolve or bypass that blocker.
- **New refusal atom needed.** As noted in §4 item 5, ex4pm's refusal vocabulary has no `:remote_timeout`/`:wasm_remote_timeout`-equivalent today; Phase 1's new module needs to introduce one rather than overload `:wasm_execution_failed` for a genuinely different failure mode (network timeout vs. execution error).

---

## 8. Explicitly out of scope for this document

- No timeline or effort estimate is committed for beam4pm's Phase 0 prerequisite work (§4).
- No code in beam4pm is modified by this document — it is a proposal only, gated on the beam4pm merge blocker noted in §7.
- The false `ex4pm-wasm4pm-bindings-pack` citation is resolved (§7) — no longer out of scope.
- No decision is made about RF4's missing bridge (§4 item 3) — noted as a parallel gap, not addressed.
- No `mix deps.tree` was run against xaas to fully trace `rustler`'s propagation beyond what's directly visible in `xaas/mix.lock` (§5) — that remains unverified and is not resolved here.
- This document does not modify `Ex4pm.Engine`'s behaviour contract, `Ex4pm.Engine.Registry`'s selection algorithm, or `Ex4pm.Engine.Remote`/`Ex4pm.Engine.Ex4pmPlan` — it proposes a new candidate module following their existing shape, not a change to the shape itself.
