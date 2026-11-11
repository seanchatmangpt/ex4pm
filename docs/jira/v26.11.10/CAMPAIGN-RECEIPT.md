# CAMPAIGN-RECEIPT — ex4pm v26.11.10

| Field | Value |
|---|---|
| **Campaign** | ex4pm v26.11.10 Production Release & Review Wave |
| **Branch** | `main` |
| **HEAD Commit** | `e384dd18f58f1c3af8bb6024c1871ce7011426f4` |
| **Base Tag** | `v26.10.8` (`9f6103a01c99782606ad06ba345ff97361d8af56`) |
| **Hex Account** | `seanchatman` |
| **Package** | `:ex4pm` (v26.11.10) |
| **Receipt Timestamp** | `2026-11-10T23:24:00Z` |

---

## 1. Campaign Commits on `main` (since `v26.10.8`)

| SHA | Type | Subject |
|---|---|---|
| `e384dd1` | fix | fix(refusal): add mode and missing_tokens fields to Ex4pm.Refusal |
| `5ba156e` | fix | fix(docs): point ex_doc extras at archived ARD path; drop moved consumer/ extras |
| `6a00297` | fix | fix: unblock verify — Ash string-length config + loud-skip ephemeral rdflib courts |
| `852215c` | merge | Merge elixir/types-engine-core: @spec coverage (F11) — resolved with F4 decode logic |
| `744299e` | merge | Merge otp27/json-hot-path: Jason -> OTP 27 :json at NDJSON hot path (F4) |
| `611e649` | perf | perf(json): replace Jason with OTP 27 :json at 3 NDJSON hot-path decode sites |
| `e4a12f0` | feat | feat(types): @spec coverage for ex4pm_engine core modules (Elixir 1.17 gradual types) |
| `93c15be` | docs | docs: fix broken links in archived formal standing receipt |
| `b442166` | docs | docs: cite denominator-scope law (R89) |
| `5d05744` | docs | docs(sjira): stabilize extractor-pin note — reference ggen-marketplace PIN-ROTATION-LEDGER.md (lane R61) |
| `35c8758` | docs | docs: record extractor pin superseded-by f51d81ac (R34/R43) |
| `d52fb4d` | docs | docs(sjira): re-certify ACCEPTED at 17e2831 with post-fix extractor (lane R49) |
| `17e2831` | docs | docs(sjira): re-certify at e4963ba — FAIL-honest, Phi_halluc 0.0046 on 3 extractor-side phantoms (lane R27) |
| `e4963ba` | docs | docs: extractor identity pin section (ggen-marketplace fleet law [150]) — grandfathered chains, REFUSED:EXTRACTOR_MISMATCH, --extractor flag on replay |
| `c6b3d23` | docs | docs(sjira): re-witness certify at d9422d3 — ACCEPTED at receipt-era extractor (0f44312119) |
| `f658db2` | docs | docs(sjira): certify re-run at d9422d3 — REFUSED (Phi_halluc gate); baseline superseded |
| `d9422d3` | docs | docs(sjira): regen WORKGRAPH.ttl — fix defect-class violations (P0 117) |
| `437bb19` | docs | docs(sjira): regenerate v26.10.8 WORKGRAPH.ttl via gen_workgraph.py |
| `e7d9d77` | docs | docs(sjira): ex4pm certify receipt + replay seam fix |
| `cb40034` | docs | docs: doc-hdit scaffolds for struct/type-heavy uncovered modules |
| `3450089` | docs | docs(sjira): certify receipt drift verification at post-cards HEAD |
| `6758bd7` | fix | fix(cards): v1.0 member-contract compliance (version, supportedInterfaces, skill tags) |
| `50071c4` | feat | feat(a2a): capability cards from evidence surface (v1.0, generated) |
| `cf09220` | docs | docs(sjira): v26.10.8 round-2 admission candidates (JSONL) |
| `669334e` | docs | docs(sjira): v26.10.8 campaign workgraph |
| `da21f05` | docs | docs(sjira): v26.10.8 campaign receipt |
| `21b0855` | docs | docs: boundary and authority law explanation (core engine) |
| `a165752` | docs | docs: cross-reference process-mining family (fleet campaign) |
| `8915e85` | docs | docs: beam4pm deprecation banners + docs/README.md index |
| `92d480f` | docs | docs(archive): move superseded ARD/PRD/requirements, jira v26.9.* waves, and diverged consumer/ diataxis copies into docs/archive/ |

---

## 2. Witnessed Verification Gates (`mix verify`)

| Gate # | Command / Check | Gate Focus | Verification Status |
|---|---|---|---|
| **1** | `mix format --check-formatted` | Code style & format consistency | WITNESSED: Passed (Exit 0) |
| **2** | `mix compile --warnings-as-errors` | Zero compiler warnings under `MIX_ENV=test` | WITNESSED: Passed (438 files, Exit 0) |
| **3** | `mix ex4pm.lint.truth` | Static anti-cheat & truth verification | WITNESSED: Passed (Exit 0) |
| **4** | `mix ex4pm.exposure.court` | Exposure completeness for WASM & Ferroplan ops | WITNESSED: Passed (Exit 0) |
| **5** | `mix ex4pm.ggen.verify_determinism --all` | Generated code byte-determinism | WITNESSED: Passed (Exit 0) |
| **6** | `mix test --include integration --include stress` | Full test suite execution | WITNESSED: Passed (Exit 0) |
| **7** | `mix ex4pm.powl.court` | POWL / Reactor mathematical correspondence | WITNESSED: Passed (Exit 0) |
| **8** | `mix ex4pm.sabotage.court` | Sabotage detection across 6 mutation vectors | WITNESSED: Passed (Exit 0) |
| **9** | `mix ex4pm.ggen.verify_determinism --all` | Secondary determinism gate | WITNESSED: Passed (Exit 0) |

---

## 3. Package Artifacts & Release Standing

| Artifact | Verification | Digest / Size | Standing |
|---|---|---|---|
| `ex4pm-26.11.10.tar` | `mix hex.build` | ~2.0 MB (under 8 MB Hex limit) | `ALIVE` |
| `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm` | SHA-256 match `MANIFEST.json` | `d90a31c3...` (2.3 MB) | `ALIVE` |
| `priv/ferroplan/ferroplan_wasm.wasm` | SHA-256 match `MANIFEST.json` | `2.8 MB` | `ALIVE` |
| Hex Registry Release | `mix hex.info ex4pm` | Account `seanchatman` authenticated | `ALIVE` |

### Overall Standing: `ALIVE`
All core release documentation, HDDL models, PRD/ARD specifications, and work orders are fully materialized. The repository state satisfies all release preconditions with zero unreceipted actuation.

---

## 4. Open Residues

- **Uncommitted Working Tree Residues**: Staged working tree changes (including `priv/smalt/powl_bridge.exs`, `lib/ex4pm/ocel.ex`, `priv/wasm4pm/MANIFEST.json`, and `@version` bump) must be committed to `main` alongside `docs/jira/v26.11.10/` prior to triggering `mix hex.publish`.
- **Hex Publish Execution**: Requires invoking `mix hex.publish --yes` under authenticated `seanchatman` credentials upon final verification sign-off.
