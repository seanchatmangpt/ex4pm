# ex4pm: triage 12 local-only branches

- Standing: OPEN
- Created: 2026-09-19 (v26.9.19 gh survey wave)
- Source: local branches with commits not on `origin/main` and no upstream
- Evidence: `git rev-list --count origin/main..<branch>` > 0 for each: feat/a2a-client-additive-path:7 feat/wasm4pm-phase2-bindings:2 integrate/distributed-runtime:49 release/v26.9.10:3 worktree-wf_4bda08d9-e8e-1:1 worktree-wf_4bda08d9-e8e-2:1 worktree-wf_76b4895f-667-7:1 worktree-wf_76b4895f-667-8:1 worktree-wf_7916b9c5-ab5-20:1 worktree-wf_7916b9c5-ab5-28:1 worktree-wf_ae9bd890-20d-1:1 worktree-wf_ae9bd890-20d-2:1

## Work to complete
- Triage each branch: push (`git push -u origin <branch>`) or delete after confirming the commits are obsolete/recoverable. Batch the work; record decisions in History.

## Acceptance
- Every listed branch is pushed or deleted; no local-only branch with unique commits remains.

## History
- 2026-09-19 | OPEN | survey found 12 local-only branches | full list above | triage pending
