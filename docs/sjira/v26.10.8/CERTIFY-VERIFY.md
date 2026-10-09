# CERTIFY-VERIFY — doc-hdit certify re-run at post-cards HEAD (v26.10.8)

Lane: ex4pm-certify-verify, 2026-10-08. Verifies the BLAKE3 chain hash `f4104bfa`
disclosed in `SEMANTIC-WAVE-RECEIPT.md` / `DOC-HDIT-BUILD-RECEIPT.md` (ggen-marketplace)
by re-running the full doc-hdit certify path against ex4pm at current HEAD.

## Verdict

**The old chain hash no longer reproduces — and not merely by mismatching: certify
REFUSES at HEAD. No new receipt is minted.**

- Old certify receipt: `f4104bfaef0b02b2f6e68180f94527505ba5c5167d78ce301703457a69bdf235`
  (parent `""`, subject `0e0512fb11ec402038b6ddbeb50992534efda96c9f4c51e438f1653703107204`,
  gates S_coverage 0.9693 PASS / Phi_halluc 0.0 / Q_density 1.0, ACCEPTED; chain file
  `/tmp/hdit/repro.chain.jsonl` at certify time, ggen-marketplace @ 20aadd175-era extractor).
- New run: **REFUSED** — `REFUSED:DOC_HDIT_CERTIFY_GATE_FAIL:S_coverage value=0.8736
  threshold=0.9000`, exit 1, no receipt. There is no new hash to compare against f4104bfa;
  the refusal IS the drift signal.

## Gates at HEAD 6758bd7d (extractor @ ggen-marketplace main)

| gate | value | threshold | verdict |
|---|---|---|---|
| S_coverage | 0.8736 | >= 0.90 | **FAIL** |
| Phi_halluc (phantom) | 0.0000 | <= 0.001 | PASS |
| Q_density | 1.0000 | >= 0.65 | PASS |

(`s_coverage_raw` 0.1982 report-only; `s_coverage_vsa` 0.1990 report-only.)

## Drift explanation

The certify-time surface (old inputs: 596 modules, 1032 claims, 1353 public items —
1300 functions + 52 ash_resources + 1 script) and the HEAD surface (595 modules, 1250
claims, 1139 public items — 894 functions + 97 structs + 87 types + 52 ash_resources +
8 routes + 1 script) differ because both the subject repo and the extractor moved:

1. **ex4pm commits landed after the certify**: `50071c4` (capability cards from evidence
   surface) and `6758bd7` (v1.0 member-contract compliance) changed the repo; the docs
   surface the extractor scans changed with them.
2. **ggen-marketplace extractor fixes landed** (table-claims/struct/arity — the v2
   priorities in DOC-HDIT-BUILD-RECEIPT §5): structs and types are now first-class public
   items. The denominator changed shape: 208 of 1139 public items are struct/type items
   that the doc surface was never written against, so set coverage falls 0.9693 -> 0.8736
   and crosses the 0.90 gate.

Both changes are real surface movement, not metric artifacts: phantom and density stay
perfect, coverage drops because the extractor now counts a surface the docs do not
reference. This is the same fail-honest class the pilot documented for ferroplan — a
documentation defect surfaced by a stricter extractor, not a regression in ex4pm docs
quality relative to the code they document.

## Replay

```sh
# ggen-marketplace @ main (extractor scripts/gen_doc_surface.py, pack binary rebuilt:
# cargo build --release in packs/rust-doc-hdit-pack)
cd /Users/sac/ggen-marketplace
python3 scripts/gen_doc_surface.py code /Users/sac/ex4pm > /tmp/hdit/verify/ex4pm.code.json
python3 scripts/gen_doc_surface.py doc  /Users/sac/ex4pm --code-json /tmp/hdit/verify/ex4pm.code.json \
  > /tmp/hdit/verify/ex4pm.doc.json
# merge (claims need `id` assigned — current extractor omits them; binary requires them)
python3 - <<'PY'
import json
c=json.load(open('/tmp/hdit/verify/ex4pm.code.json'))
d=json.load(open('/tmp/hdit/verify/ex4pm.doc.json'))
for i,cl in enumerate(d['claims']): cl.setdefault('id', f'ex4pm-{i}')
json.dump({"modules": c['modules'], "claims": d['claims']},
          open('/tmp/hdit/verify/ex4pm.inputs.json','w'), indent=2, sort_keys=True)
PY
cd packs/rust-doc-hdit-pack
target/release/doc-hdit vectorize /tmp/hdit/verify/ex4pm.inputs.json
target/release/doc-hdit audit     /tmp/hdit/verify/ex4pm.inputs.json courts/doc_quality.court
target/release/doc-hdit certify   /tmp/hdit/verify/ex4pm.inputs.json courts/doc_quality.court \
  --chain /tmp/hdit/verify/ex4pm.chain.jsonl   # expect REFUSED:DOC_HDIT_CERTIFY_GATE_FAIL:S_coverage
```

## Falsifier

Re-run the replay at any HEAD where the certify ACCEPTS with hash == f4104bfa... —
refuted. Re-run where certify ACCEPTS at all — the "refuses at HEAD" finding above is
then stale and this doc must be refreshed.

## Standing

- old receipt f4104bfa: standing unchanged (was PARTIAL_ALIVE at its subject; subject
  no longer exists at HEAD — superseded by this run).
- ex4pm doc-hdit gate standing at HEAD 6758bd7: **BLOCKED** (S_coverage 0.8736 < 0.90,
  typed refusal witnessed). Remediation is documentation: cover the 208 struct/type
  public items the stricter extractor now counts (same remediation class as ferroplan).
