# ex4pm: land or delete remote branch `worktree-wf_ae9bd890-20d-1`

- Standing: OPEN
- Created: 2026-09-19 (v26.9.19 gh survey wave)
- Source: remote branch `worktree-wf_ae9bd890-20d-1` — not merged into `main`, no open PR
- Evidence: `git branch -r --no-merged origin/main` lists it; absent from `gh pr list` heads

## Work to complete
- Decide: open a PR (`gh pr create -R seanchatmangpt/ex4pm --head worktree-wf_ae9bd890-20d-1`) or delete (`git push origin --delete worktree-wf_ae9bd890-20d-1`).
- If superseded, delete; otherwise land through review.

## Acceptance
- After `git fetch --prune`, `git branch -r --no-merged origin/main` no longer lists `worktree-wf_ae9bd890-20d-1`.

## History
- 2026-09-19 | OPEN | survey found PR-less unmerged branch | worktree-wf_ae9bd890-20d-1 | decision pending
