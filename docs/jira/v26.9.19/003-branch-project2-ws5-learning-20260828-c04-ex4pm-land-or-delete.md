# ex4pm: land or delete remote branch `project2/ws5-learning-20260828-c04-ex4pm`

- Standing: OPEN
- Created: 2026-09-19 (v26.9.19 gh survey wave)
- Source: remote branch `project2/ws5-learning-20260828-c04-ex4pm` — not merged into `main`, no open PR
- Evidence: `git branch -r --no-merged origin/main` lists it; absent from `gh pr list` heads

## Work to complete
- Decide: open a PR (`gh pr create -R seanchatmangpt/ex4pm --head project2/ws5-learning-20260828-c04-ex4pm`) or delete (`git push origin --delete project2/ws5-learning-20260828-c04-ex4pm`).
- If superseded, delete; otherwise land through review.

## Acceptance
- After `git fetch --prune`, `git branch -r --no-merged origin/main` no longer lists `project2/ws5-learning-20260828-c04-ex4pm`.

## History
- 2026-09-19 | OPEN | survey found PR-less unmerged branch | project2/ws5-learning-20260828-c04-ex4pm | decision pending
