# RE-WITNESS — certify re-witness at d9422d3 (ex4pm-witness lane, 2026-10-09)

Re-witness of the doc-hdit certify at merged main `d9422d3` (original ACCEPTED
receipt `14c65e67...` was minted at `cb400347`-era, landed by `e7d9d77`).
Full 4-array inputs (modules/claims/paths/directories/known_external),
canonical pipeline in /tmp, per the `CERTIFY-VERIFY.md` replay recipe.

## Result: extractor-identity-split

Two certify runs, one subject (`ex4pm @ d9422d3`), differing only in
extractor generation (all post-receipt extractor commits are
`scripts/gen_doc_surface.py`-only; the certifier binary is byte-identical
across both runs):

| run | extractor | inputs sha256 | S_coverage | Phi_halluc | Q_density | verdict |
|---|---|---|---|---|---|---|
| A | ggen-marketplace main `115f96bdc` (incl. `d10824331` atom/string-key) | `d825f1e0`-prefix family, full 4-array, 594 mods / 2964 claims / 9302 items | 0.5033 | 0.0258 | 0.9741 | **REFUSED** (S < 0.90, Phi > 0.001) |
| B | receipt-era `5eb8076ab` (last extractor before the receipt) | `d825f1e00915f800...` | 0.9214 | 0.0000 | 1.0000 | **ACCEPTED** |

Run B canonical receipt (landed here as `ex4pm.chain.jsonl` +
`ex4pm.inputs.json`): hash `0f44312119cf7dab...`, parent `""`,
subject `9de84ed316f0f47b...`, exit 0 — S_coverage 0.9214 clears the 0.90
gate, matching the e7d9d77 replay value (0.9214) almost exactly.

## Residual classification

**Extractor-side drift, not a docs regression.** The four extractor commits
after the e7d9d77 receipt (`66eaea182` generated-surface policy,
`b04003b07` env-var/string-key items, `2de3d52fe` multi-ident spans,
`d10824331` atom/string-key items) grow the code surface 1139 → 9302 public
items and introduce phantom grounding pressure (Phi 0.0258 unpinned). At
the receipt-era extractor identity the d9422d3 docs remain gate-clean
(ACCEPTED, S 0.9214). This agrees with `f658db2`'s independent
classification (extractor-side drift, `--engine regex` pinned S 0.9104 /
Phi 0.0791 REFUSED); run A here additionally shows the unpinned new
extractor also breaks S_coverage and the docs alone cannot clear it until
the extractor's claim classes stabilize.

## Replay (run B)

```sh
cd /Users/sac/ggen-marketplace
git show 5eb8076ab:scripts/gen_doc_surface.py > /tmp/hdit/witness-e7/gen_doc_surface.py
python3 /tmp/hdit/witness-e7/gen_doc_surface.py code /Users/sac/ex4pm > /tmp/hdit/witness-e7/ex4pm.code.json
python3 /tmp/hdit/witness-e7/gen_doc_surface.py doc /Users/sac/ex4pm \
  --code-json /tmp/hdit/witness-e7/ex4pm.code.json > /tmp/hdit/witness-e7/ex4pm.doc.json
# merge claims+modules+paths+directories+known_external (4-array seam fix, e7d9d77)
cd packs/rust-doc-hdit-pack
target/release/doc-hdit vectorize /tmp/hdit/witness-e7/ex4pm.inputs.json --cache /tmp/hdit/witness-e7-cache
target/release/doc-hdit audit     /tmp/hdit/witness-e7/ex4pm.inputs.json courts/doc_quality.court --cache /tmp/hdit/witness-e7-cache
target/release/doc-hdit certify   /tmp/hdit/witness-e7/ex4pm.inputs.json courts/doc_quality.court \
  --chain /tmp/hdit/witness-e7/ex4pm.chain.jsonl --cache /tmp/hdit/witness-e7-cache
# expect ACCEPTED, hash 0f44312119cf..., exit 0
```

## Standing

- Standing at d9422d3 under the receipt-era extractor identity: **ACCEPTED**
  (hash `0f44312119cf...`, inputs `ex4pm.inputs.json` sha256 `d825f1e0...`).
- Under the current main extractor generation: **REFUSED** — blocked on
  ggen-marketplace extractor, not on ex4pm docs. Re-certify with the
  `--extractor` pin once the new claim classes stabilize (see the extractor
  identity pin note in `CERTIFY-VERIFY.md`).
