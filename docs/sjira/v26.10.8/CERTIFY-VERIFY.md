# CERTIFY-VERIFY — doc-hdit certify re-run at post-cards HEAD (v26.10.8)

Lane: ex4pm-certify-verify, 2026-10-08. Verifies the BLAKE3 chain hash `f4104bfa`
disclosed in `SEMANTIC-WAVE-RECEIPT.md` / `DOC-HDIT-BUILD-RECEIPT.md` (ggen-marketplace)
by re-running the full doc-hdit certify path against ex4pm at current HEAD.

## Verdict

**RE-BASELINED 2026-10-08 (this supersedes the REFUSED finding below): the 0.8736
S_coverage refusal was partly a seam artifact.** The replay recipe in this file merged
only `modules` + `claims` into the certify inputs, dropping the code surface's `paths`,
`directories` and `known_external` — real doc paths were scored against a surface that
declared none, depressing coverage. With the merge fixed, certify at ex4pm `cb400347`
is **ACCEPTED**:

- Canonical ACCEPTED chain (`docs/sjira/v26.10.8/ex4pm.chain.jsonl`,
  inputs `ex4pm.inputs.json`, sha256 `170be93f...`): hash `14c65e674b8d8a25c6232e87e1eb85af44bc9656283d2beaa2d7324e4ea3ecd0`,
  parent `""`, subject `1cc9c8642018b1baa4a35f23acba0785ffcce71befee198b0d183747f108ad98`,
  gates S_coverage 0.9253 / Phi_halluc 0.0 / Q_density 1.0, **ACCEPTED**.
- Independent replay in /tmp (fresh extraction, corrected merge) also certifies
  **ACCEPTED**: S_coverage 0.9214, hash `f357e486...`, exit 0. (S differs slightly from
  the canonical run — extraction is not bit-stable run-to-run — but both clear the 0.90 gate.)

- Old certify receipt: `f4104bfaef0b02b2f6e68180f94527505ba5c5167d78ce301703457a69bdf235`
  (parent `""`, subject `0e0512fb11ec402038b6ddbeb50992534efda96c9f4c51e438f1653703107204`,
  gates S_coverage 0.9693 PASS / Phi_halluc 0.0 / Q_density 1.0, ACCEPTED; chain file
  `/tmp/hdit/repro.chain.jsonl` at certify time, ggen-marketplace @ 20aadd175-era extractor).
- Superseded intermediate finding (seam-artifact era, extractor before the merge fix):
  REFUSED at S_coverage 0.8736 < 0.90. **Partly seam artifact, not a pure doc defect** —
  see the replay note above; the struct/type extractor strictness contribution remains real.

## Gates at HEAD cb400347 (extractor @ ggen-marketplace main, corrected merge)

| gate | value | threshold | verdict |
|---|---|---|---|
| S_coverage | 0.9253 (canonical) / 0.9214 (replay) | >= 0.90 | **PASS** |
| Phi_halluc (phantom) | 0.0000 | <= 0.001 | PASS |
| Q_density | 1.0000 | >= 0.65 | PASS |

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
perfect. The original coverage drop was **partly seam artifact** (the inputs merge dropped
`paths`/`directories`/`known_external`), and partly the real stricter-extractor effect —
struct/type items the docs historically did not reference. The remaining doc gap was
closed by `cb40034` ("doc-hdit scaffolds for struct/type-heavy uncovered modules"), which
lifted coverage back above the 0.90 gate.

## Replay

```sh
# ggen-marketplace @ main (extractor scripts/gen_doc_surface.py, pack binary rebuilt:
# cargo build --release in packs/rust-doc-hdit-pack)
cd /Users/sac/ggen-marketplace
python3 scripts/gen_doc_surface.py code /Users/sac/ex4pm > /tmp/hdit/verify/ex4pm.code.json
python3 scripts/gen_doc_surface.py doc  /Users/sac/ex4pm --code-json /tmp/hdit/verify/ex4pm.code.json \
  > /tmp/hdit/verify/ex4pm.doc.json
# merge (claims need `id` assigned — current extractor omits them; binary requires them).
# SEAM BUG FIX (2026-10-08): the merge must carry paths, directories and known_external
# from the code surface too — writing only {modules, claims} forced real paths into a
# phantom-only surface and depressed S_coverage as a seam artifact, not a doc defect.
python3 - <<'PY'
import json
c=json.load(open('/tmp/hdit/verify/ex4pm.code.json'))
d=json.load(open('/tmp/hdit/verify/ex4pm.doc.json'))
for i,cl in enumerate(d['claims']): cl.setdefault('id', f'ex4pm-{i}')
json.dump({
    'claims': d['claims'],
    'directories': c.get('directories', []),
    'known_external': c.get('known_external', []),
    'modules': c['modules'],
    'paths': c.get('paths', []),
}, open('/tmp/hdit/verify/ex4pm.inputs.json','w'), indent=2, sort_keys=True)
PY
cd packs/rust-doc-hdit-pack
target/release/doc-hdit vectorize /tmp/hdit/verify/ex4pm.inputs.json
target/release/doc-hdit audit     /tmp/hdit/verify/ex4pm.inputs.json courts/doc_quality.court
target/release/doc-hdit certify   /tmp/hdit/verify/ex4pm.inputs.json courts/doc_quality.court \
  --chain /tmp/hdit/verify/ex4pm.chain.jsonl   # expect ACCEPTED, S_coverage >= 0.90
```

## Falsifier

Re-run the corrected replay at any HEAD where certify REFUSES (S_coverage < 0.90 with
the paths/directories/known_external merge in place) — the ACCEPTED baseline above is
refuted and this doc must be refreshed.

## Standing

- old receipt f4104bfa: standing unchanged (was PARTIAL_ALIVE at its subject; subject
  no longer exists at HEAD — superseded).
- ex4pm doc-hdit gate standing at HEAD cb400347: **PARTIAL_ALIVE → ACCEPTED** — certify
  hash `14c65e674b...` (canonical, S 0.9253) with an independent /tmp replay also
  ACCEPTED (hash `f357e486...`, S 0.9214). Remaining exposure: extraction is not
  bit-stable run-to-run, so the standing is bound to the committed inputs
  (`ex4pm.inputs.json`, sha256 `170be93f...`), not to HEAD unconditionally.
