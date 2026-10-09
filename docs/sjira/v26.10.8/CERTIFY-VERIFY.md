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

## Re-baseline at merged main d9422d3 — REFUSED (falsifier fired, 2026-10-09)

Lane ex4pm-receipt2 re-ran the canonical certify at ex4pm `d9422d3` with fresh
cache in /tmp, per this doc's falsifier. **The ACCEPTED baseline above is
refuted**: certify REFUSES at `d9422d3` on both extractor engines.

- Inputs `ex4pm.inputs.d9422d3.json` (regex engine, canonical-surface:
  595 modules / 2530 claims / 1051 paths / 1139 public items), sha256
  `02385896b320c7e548cb65bba5d9fb86e2133cf66405ca26a47a8c36d6cf3846`:
  **REFUSED:DOC_HDIT_CERTIFY_GATE_FAIL** — Phi_halluc **0.0791 > 0.001**.
  S_coverage **0.9104 >= 0.90 PASS**, Q_density 0.9209 PASS. No receipt minted.
- Inputs at the `auto` engine (tree-sitter path selected): total refusal —
  S_coverage 0.5033 (9302 public items after extractor d10824331's str_key
  expansion) and Phi_halluc 0.0258. Evidence: `ex4pm.certify.d9422d3.log`.
- Old baseline (chain `14c65e67...`, subject cb400347, S 0.9253 / Phi 0.0)
  is **superseded**: its subject no longer exists at HEAD. Chain file
  `ex4pm.chain.jsonl` and inputs `ex4pm.inputs.json` kept unmodified as the
  historical receipt chain.

### Gate table at d9422d3 (regex engine, canonical surface)

| gate | value | threshold | verdict |
|---|---|---|---|
| S_coverage | 0.9104 | >= 0.90 | PASS |
| Phi_halluc | 0.0791 | <= 0.001 | **FAIL** |
| Q_density | 0.9209 | >= 0.65 | PASS |

### Drift cause (extractor-side, not a doc-surface regression)

Extractor commit `d10824331` ("Elixir atom/string-key surface items", ggen-marketplace
hdit-v2-structs) changed claim extraction: 397 `doc_string` claims were replaced by
261 `table_row_scaffold` claims whose `object` is a raw table cell token ("len",
"as_of", "fe99c07") that grounds against no code symbol — 200+ phantom claims,
Phi 0.0 -> 0.0791. Separately, the `auto` engine now selects tree-sitter when
installed, expanding the public surface 1139 -> 9302 items (str_key items,
pub-gate bypassed) and collapsing S_coverage. Neither is a docs regression:
coverage over the canonical surface still clears 0.90, so the fix locus is the
extractor (ggen-marketplace `scripts/gen_doc_surface.py`), not ex4pm docs.

### Replay

Same recipe as above, plus engine pin and the new subject:

```sh
cd /Users/sac/ggen-marketplace
python3 scripts/gen_doc_surface.py code /Users/sac/ex4pm --engine regex \
  > /tmp/hdit-v26108-rerun/ex4pm.code.regex.json
python3 scripts/gen_doc_surface.py doc /Users/sac/ex4pm --engine regex \
  --code-json /tmp/hdit-v26108-rerun/ex4pm.code.regex.json \
  > /tmp/hdit-v26108-rerun/ex4pm.doc.regex.json
# merge as above (claims get id ex4pm-{i}; carry paths/directories/known_external)
# ... -> /tmp/hdit-v26108-rerun/ex4pm.inputs.regex.json
cd packs/rust-doc-hdit-pack
target/release/doc-hdit vectorize /tmp/hdit-v26108-rerun/ex4pm.inputs.regex.json --cache /tmp/hdit-v26108-rerun/cache-regex
target/release/doc-hdit certify   /tmp/hdit-v26108-rerun/ex4pm.inputs.regex.json courts/doc_quality.court \
  --chain /tmp/hdit-v26108-rerun/ex4pm.chain.regex.jsonl --cache /tmp/hdit-v26108-rerun/cache-regex
# expect REFUSED:DOC_HDIT_CERTIFY_GATE_FAIL (Phi_halluc 0.0791) until the extractor
# stops emitting table_row_scaffold junk claims.
```

## Standing

- ex4pm doc-hdit gate standing at HEAD d9422d3: **REFUSED** (Phi_halluc gate) —
  bound to `ex4pm.inputs.d9422d3.json` (sha256 `02385896...`). The ACCEPTED
  standing at cb400347 is historical; the standing at current HEAD cannot be
  repaired docs-side. Unblock locus: ggen-marketplace extractor
  (kill `table_row_scaffold` claims that ground against no symbol), then
  re-certify and re-land.
## Extractor identity pin (ggen-marketplace fleet law [150], 2026-10-09)

The chains in this doc (14c65e67... canonical, f357e486... /tmp replay) are
**grandfathered**: they predate the extractor pin and remain valid as bound.
Certify now embeds an `extractor` field (BLAKE3 over the extractor source
bytes) into every new receipt and refuses typed (`REFUSED:EXTRACTOR_MISMATCH`)
on replay when the current extractor identity differs from the recorded one;
`--force-rebaseline` mints a NEW baseline receipt acknowledging the drift.
Pass `--extractor scripts/gen_doc_surface.py` (ggen-marketplace) when
replaying so new receipts carry the pin.
