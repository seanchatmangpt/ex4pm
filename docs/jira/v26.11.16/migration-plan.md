# ex4pm migration plan v26.11.16

Standing: UNVERIFIED

## Identity
- Path: /Users/sac/ex4pm
- Remote: https://github.com/seanchatmangpt/ex4pm.git
- Branch: main@9211952 tracking origin/main ; last commit 2026-11-10 ; 1005 commits ; 126 MB
- Languages/build: Elixir umbrella / mix (mix.exs, apps/), package.json + playwright, k8s, fly.toml
- Nested repos: /Users/sac/ex4pm/ex4pm — a full second checkout of the same remote at the same
  sha (main@9211952, ahead 1, dirty 1/untracked 1). Looks like an accidental clone-inside-clone.

## Observed state
- Dirty 1: docs/thesis/chapters/generated_ocel_benchmark_tables.tex
- Untracked 1: docs/jira/v26.11.12/
- Ahead 1 (release v26.11.10 commit not pushed) / behind 0
- Unpushed local branches: 29 (worktree-wf_* snapshots, feat/wasm4pm-phase1/2-bindings,
  feat/aloop-process-intelligence ahead 297, feat/ex4pm-pack-upgrade ahead 5, gall/*, etc.)
- Stash 0; no _build/deps at root; erl_crash.dump, test-results/, tmp/, receipts/ present
- Submodules: none reported

## What it is
BEAM-native, evidence-oriented process-intelligence system (OCEL 2.0, DfCM engine graph,
BRCE broker) derived from wasm4pm semantics; published to Hex at v26.11.10.

## Classification
ACTIVE (census agrees; CLAUDE.md, jira v26.11.10 and v26.11.12 present).

## Migration risk
HIGH. The v26.11.10 release commit is unpushed; feat/aloop-process-intelligence is 297 ahead;
29 local branches unpushed. Thesis .tex edit and v26.11.12 jira notes uncommitted.

## Recommended action
COMMIT-PUSH
1. `cd /Users/sac/ex4pm && git add docs/thesis docs/jira && git commit -m "docs: thesis tables + jira v26.11.12/v26.11.16"`
2. `git push origin main`
3. `git push origin feat/aloop-process-intelligence feat/ex4pm-pack-upgrade-v26.9.30 docs/xaas-integration-roadmap`
4. `git push origin --all` (DECISION: prune `worktree-wf_*` snapshot branches first?)
5. Nested duplicate: `cd /Users/sac/ex4pm/ex4pm && git status && git log origin/main..main`;
   if it holds nothing unique, `rm -rf /Users/sac/ex4pm/ex4pm` (DECISION). Never copy it.
6. `rm -f erl_crash.dump; rm -rf _build deps test-results tmp` before any rsync.

## First commands on the new machine
`mix deps.get && mix compile --warnings-as-errors && mix test`

## See Also
- ../v26.11.12/
- ../v26.11.10/
- /Users/sac/docs/jira/v26.11.16/README.md (master index)
