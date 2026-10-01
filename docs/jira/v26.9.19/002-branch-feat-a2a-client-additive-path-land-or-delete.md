# ex4pm: land or delete remote branch `feat/a2a-client-additive-path`

- Standing: OPEN
- Created: 2026-09-19 (v26.9.19 gh survey wave)
- Source: remote branch `feat/a2a-client-additive-path` — not merged into `main`, no open PR
- Evidence: `git branch -r --no-merged origin/main` lists it; absent from `gh pr list` heads

## Work to complete
- Decide: open a PR (`gh pr create -R seanchatmangpt/ex4pm --head feat/a2a-client-additive-path`) or delete (`git push origin --delete feat/a2a-client-additive-path`).
- If superseded, delete; otherwise land through review.

## Acceptance
- After `git fetch --prune`, `git branch -r --no-merged origin/main` no longer lists `feat/a2a-client-additive-path`.

## History
- 2026-09-19 | OPEN | survey found PR-less unmerged branch | feat/a2a-client-additive-path | decision pending
