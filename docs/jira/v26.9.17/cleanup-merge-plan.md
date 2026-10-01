# Cleanup and Merge Plan: ex4pm / ash_ex4pm worktree family

## Current State (as observed 2026-09-17)

Two independent git repos are in scope, each with its own worktree/scratch sprawl.
`git worktree list` was run against both canonical repos; every other path below was
checked with `git -C <path> status --short`, `git -C <path> log -1`, and `du -sh`.

### Family A — `/Users/sac/ex4pm` (canonical repo, remote: `seanchatmangpt/ex4pm`)

| Path | Type | Branch | Git status | Last commit | Size |
|---|---|---|---|---|---|
| `/Users/sac/ex4pm` | canonical repo | `feat/a2a-client-additive-path` (1 commit ahead of local `main`, 0 behind) | 3 untracked items: `.claude/` (workflow admin dir, expected), `docs/jira/v26.9.11/a2a-client-additive-path.md` (untracked doc), `ex4pm` (a **self-referential symlink**, `ex4pm -> /Users/sac/ex4pm`, stray junk) | 2026-09-11, `9c6d950` | 5.3G (includes all nested worktrees below, which live under `.claude/worktrees/`) |
| `/Users/sac/ex4pm-igniter-fix` | worktree of ex4pm | `fix/igniter-dev-scope-leak-prod-compile` (1 ahead / 50 behind `main`) | dirty: 1 file, `generated_ocel_benchmark_tables.tex` (auto-generated benchmark table, numbers only, confirmed non-substantive by diff) | 2026-09-03, `55c6e4f` | 29M |
| `/Users/sac/ex4pm-worktrees/predict-execute-episode-20260903` | worktree of ex4pm | `predict-execute-episode-20260903` (0 ahead / 50 behind `main` — fully merged) | dirty: same trivial `.tex` file; untracked `tools/` dir containing real, never-committed Python (`episode_execute.py`, `episode_predict.py`, `qualification_domain.py`) | 2026-08-31, `e1eb78a` | 29M |
| `/Users/sac/ex4pm-worktrees/qualification-domain` | worktree of ex4pm | `qualification-domain-20260903` (0 ahead / 50 behind `main` — fully merged, **same base commit `e1eb78a` as the row above**) | dirty: same trivial `.tex` file, `mix.lock`; untracked `tools/` (same kind of uncommitted Python scripts) | 2026-08-31, `e1eb78a` | 46M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_0fa532e2-ea8-1` | worktree of ex4pm | `worktree-wf_0fa532e2-ea8-1` (0 ahead / 7 behind) | clean | 2026-09-09, `1bcc81f` | 452M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_0fa532e2-ea8-2` | worktree of ex4pm | `worktree-wf_0fa532e2-ea8-2` (0 ahead / 7 behind) | clean | 2026-09-09, `4893278` | 452M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_4bda08d9-e8e-1` | worktree of ex4pm | `worktree-wf_4bda08d9-e8e-1` (0 ahead / 23 behind) | **dirty: 20 modified files** under `lib/ex4pm_engine/wasm/*.ex`, real code (101 insertions / 57 deletions per `git diff --stat`), not committed | 2026-09-09, `2f2f016` | 78M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_4bda08d9-e8e-2` | worktree of ex4pm | `worktree-wf_4bda08d9-e8e-2` (0 ahead / 23 behind) | **dirty: 2 modified + 1 untracked** (`lib/ex4pm/engine.ex`, `lib/ex4pm/engine/adapters.ex`, `test/engine_wasm_remote_test.exs`), 138 lines of real, different uncommitted work than the row above (not a duplicate) | 2026-09-09, `2f2f016` | 29M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_54a9e1aa-5d9-2` | worktree of ex4pm | `worktree-wf_54a9e1aa-5d9-2` (0 ahead / 3 behind) | clean | 2026-09-09, `e5d22a0` | 452M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_76b4895f-667-7` | worktree of ex4pm | `worktree-wf_76b4895f-667-7` (**1 ahead**, unique commit `d8e13b4` "feat: add mix ex4pm.ggen.sync generic manifest-driven ggen task" / 40 behind) | clean | 2026-09-09, `d8e13b4` | 72M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_76b4895f-667-8` | worktree of ex4pm | `worktree-wf_76b4895f-667-8` (**1 ahead**, unique commit `7ccbdb1` "feat(ggen): automated determinism gate for generated files" / 40 behind) | clean | 2026-09-09, `7ccbdb1` | 72M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_7916b9c5-ab5-20` | worktree of ex4pm | `worktree-wf_7916b9c5-ab5-20` (**1 ahead**, unique commit `ea4d4e6` "fix(stream): real idempotency dedup in Ingest.ingest_envelope/2" / 1 behind) | clean | 2026-09-09, `ea4d4e6` | 452M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_7916b9c5-ab5-28` | worktree of ex4pm | `worktree-wf_7916b9c5-ab5-28` (**1 ahead**, unique commit `9d76818` "fix: OCEL 2.0 object attributes as a real value-time log, not a snapshot" / 1 behind) | clean | 2026-09-09, `9d76818` | 452M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_94919046-fe4-1` | worktree of ex4pm | `worktree-wf_94919046-fe4-1` (0 ahead / 19 behind) | clean | 2026-09-09, `5b6e7d1` | 450M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_94919046-fe4-2` | worktree of ex4pm | `worktree-wf_94919046-fe4-2` (0 ahead / 19 behind) | clean | 2026-09-09, `54fb3bc` | 450M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_a11cea38-da9-1` | worktree of ex4pm | `worktree-wf_a11cea38-da9-1` (0 ahead / 14 behind) | clean | 2026-09-09, `f7122df` | 450M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_a11cea38-da9-2` | worktree of ex4pm | `worktree-wf_a11cea38-da9-2` (0 ahead / 14 behind) | clean | 2026-09-09, `8dad2d6` | 450M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_a11cea38-da9-3` | worktree of ex4pm | `worktree-wf_a11cea38-da9-3` (0 ahead / 14 behind) | clean | 2026-09-09, `99b5e11` | 450M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_ae9bd890-20d-1` | worktree of ex4pm | `worktree-wf_ae9bd890-20d-1` (0 ahead / 21 behind) | **dirty: 1 file**, `priv/ggen/templates/beam4pm.ex.eex`, a real new 121-line template addition, not committed | 2026-09-09, `60b78b3` | 79M |
| `/Users/sac/ex4pm/.claude/worktrees/wf_ae9bd890-20d-2` | worktree of ex4pm | `worktree-wf_ae9bd890-20d-2` (**1 ahead**, unique commit `57a1b1e` "docs: note Ex4pm.Engine.Beam4pm's new contract-drift verification" / 21 behind) | clean | 2026-09-09, `57a1b1e` | 29M |

Note on the canonical repo itself: local `main` is diverged from `origin/main` (11 commits ahead, 1 behind) — this is a pre-existing state of `ex4pm`'s own `main` branch, unrelated to the worktree/scratch sprawl, and out of scope for this cleanup pass (see Open Questions).

### Family B — `/Users/sac/ash_ex4pm` (independent repo, remote: `seanchatmangpt/ash_ex4pm`, NOT a worktree of ex4pm — separate git history, separate remote, consumed by ex4pm as a hex dependency)

| Path | Type | Branch | Git status | Last commit | Size |
|---|---|---|---|---|---|
| `/Users/sac/ash_ex4pm` | canonical repo | `rename/automated-planning` (2 ahead of local `main`, 0 behind) | clean | 2026-09-10, `7c24a09` | 740M |
| 19 registered worktrees (`git worktree list` shows them under `/private/tmp/ash_ex4pm_*` and `/private/tmp/claude-501/ash_ex4pm_*`) | **all 19 are `prunable`**: `git worktree list -v` reports "gitdir file points to non-existent location" for every one. The directories still physically exist (leftover, non-git plain directories — `.git` file inside each is gone) but are no longer valid worktrees from git's point of view. | 19 branches, listed individually below | n/a (not real worktrees any more) | see below | ~0B reported by `du` (APFS-cloned/hardlinked leftovers, no unique blocks) |

Per-branch status of the 19 `ash_ex4pm` branches (checked via `git rev-list --count main..<branch>` and `git branch --merged main`):

| Branch | Unique commit vs `main` | Merged into `main`? |
|---|---|---|
| `fix/activity-enforce-keys-on` | none | yes |
| `fix/activity-typed-attributes` | none | yes |
| `fix/brce-gate-capabilities-validation` | none | yes |
| `fix/brce-gate-ordering` | none | yes |
| `fix/brce-gate-subject-hash` | none | yes |
| `fix/domain-verifier-resource-check` | none | yes |
| `fix/dsl-activity-describe` | none | yes |
| `fix/dsl-qualifier-field` | none | yes |
| `fix/notifier-data-relationships` | `43f8c75` "fix: recover manage_relationship-touched record identities from notification.data" | **no** |
| `fix/notifier-ocel-attributes` | `da3b61b` "fix: emit real changeset attribute values in OCEL event envelopes" | **no** |
| `fix/notifier-qualifier-dsl` | `77c3010` "fix: add real qualifier: DSL option, remove hardcoded \"primary\" E2O qualifier" | **no** |
| `fix/notifier-record-id` | none | yes |
| `fix/notifier-relationship-objects` | none | yes |
| `fix/notifier-scope-docs` | none | yes |
| `fix/notifier-simple-notifiers` | none | yes |
| `fix/o2o-emission` | none | yes |
| `fix/ocel-attribute-history` | `4d74dc7` "fix(notifier): populate real changed attribute values on :update actions" | **no** |
| `fix/ocel-object-type-schema` | none | yes |
| `fix/persist-after-ordering` | none | yes |

Also present in `ash_ex4pm`: `upstream-main` (0 ahead of `main`, 39 behind — a stale pre-rename tracking branch, fully subsumed).

No merge-base comparison between `ex4pm` and `ash_ex4pm` histories was attempted: they are unrelated git histories (different remotes, `ash_ex4pm` is consumed by `ex4pm` as a hex package per `ex4pm`'s own commit `68cc0a9 "fix: switch ex4pm from path dependency to real hex dependency"` in `ash_ex4pm`'s log) — comparing their commit graphs directly would be meaningless and is not claimed here.

No `gemma`-named directory was found anywhere under `~` (checked with `find ~ -maxdepth 2 -iname '*gemma*'`) — consistent with the user's note that it was already deleted manually; nothing further to do for it in this plan.

## What "merged" should look like

**Canonical going forward, Family A:** `/Users/sac/ex4pm` on branch `feat/a2a-client-additive-path`. It is the only path with the `origin` remote wired to the real GitHub repo, it has the deepest and most complete history (every other worktree is 0–50 commits *behind* it), and it is the one path actively being worked in (2026-09-11/17, the most recent activity of the family). All `.claude/worktrees/wf_*` and the two `ex4pm-worktrees/*` and `ex4pm-igniter-fix` paths are strictly derivative — either fully merged already, or short-lived branches spun off `main` at some earlier point that never rejoined it.

**Canonical going forward, Family B:** `/Users/sac/ash_ex4pm` (the only real, non-prunable location for that repo) on branch `rename/automated-planning`, which sits 2 commits ahead of `main`, clean. All 19 registered worktrees are already `prunable` — git itself has already lost the worktree link for them — so there is no live parallel checkout of `ash_ex4pm` competing for canonical status.

### Per-path disposition

**Family A:**

- `ex4pm/ex4pm` (self-symlink) — junk, safe to delete directly, no git object involved.
- `docs/jira/v26.9.11/a2a-client-additive-path.md` (untracked in canonical repo) — MANUAL REVIEW REQUIRED: decide whether to `git add` + commit it or discard it; content not evaluated here since that is an editorial, not a git-state, decision.
- `ex4pm-igniter-fix` — this is a stale git worktree of the canonical repo. Its only unique commit (`55c6e4f`, 1 ahead) is a real fix (`fix/igniter-dev-scope-leak-prod-compile`) not yet in `main`/HEAD. Its uncommitted dirty file is the auto-generated benchmark `.tex` (safe to discard, it's regenerated by `mix ex4pm.ocel_to_latex`). **Action: cherry-pick `55c6e4f` into the canonical repo, discard the dirty `.tex`, then `git worktree remove`.**
- `ex4pm-worktrees/predict-execute-episode-20260903` — fully merged (0 ahead of `main`). Its uncommitted `tools/` directory (real Python scripts, never committed anywhere) is the only asset at risk. **MANUAL REVIEW REQUIRED for `tools/`** (either copy it into the canonical repo and commit it, or confirm it's disposable); once resolved, `git worktree remove` is safe (no unique commits).
- `ex4pm-worktrees/qualification-domain` — same situation as the row above (same base commit `e1eb78a`, same class of untracked `tools/` scripts, plus a dirty `mix.lock`). **MANUAL REVIEW REQUIRED for `tools/`**, then safe to remove.
- `wf_0fa532e2-ea8-1`, `wf_0fa532e2-ea8-2`, `wf_54a9e1aa-5d9-2`, `wf_94919046-fe4-1`, `wf_94919046-fe4-2`, `wf_a11cea38-da9-1`, `wf_a11cea38-da9-2`, `wf_a11cea38-da9-3` (8 worktrees) — clean, 0 commits ahead of `main`, fully subsumed. **Safe to `git worktree remove` directly, no merge needed.**
- `wf_76b4895f-667-7`, `wf_76b4895f-667-8`, `wf_7916b9c5-ab5-20`, `wf_7916b9c5-ab5-28`, `wf_ae9bd890-20d-2` (5 worktrees) — clean working tree, each carries exactly one unique commit not on `main`. **Action: cherry-pick that one commit into the canonical repo, then `git worktree remove`.**
- `wf_4bda08d9-e8e-1` — clean of unique commits (0 ahead) but has 20 files of real, uncommitted work (101 insertions/57 deletions across `lib/ex4pm_engine/wasm/*.ex`). **This cannot be automated: MANUAL REVIEW REQUIRED** — the user must either commit this WIP to a branch and merge it, or confirm it's abandoned/superseded before the worktree is removed.
- `wf_4bda08d9-e8e-2` — same base commit as the row above but a **different** uncommitted diff (`lib/ex4pm/engine.ex`, `lib/ex4pm/engine/adapters.ex`, an untracked test file). **MANUAL REVIEW REQUIRED**, not a duplicate of `wf_4bda08d9-e8e-1`.
- `wf_ae9bd890-20d-1` — clean of unique commits but has one real uncommitted file (a new 121-line ggen template). **MANUAL REVIEW REQUIRED.**

**Family B:**

- 15 of the 19 `ash_ex4pm` prunable worktree branches (everything in the "merged into `main`? = yes" table above) — already fully merged, and the worktree link is already broken (git-reported `prunable`). **Safe to `git worktree prune` (clears the stale admin metadata) and delete the branch and the leftover directory directly — no merge step needed.**
- 4 branches with a real unique commit not yet in `main` (`fix/notifier-data-relationships`, `fix/notifier-ocel-attributes`, `fix/notifier-qualifier-dsl`, `fix/ocel-attribute-history`) — the branch refs are intact even though the worktree checkouts are gone. **Action: cherry-pick each branch's one commit into the canonical repo (`rename/automated-planning` or `main`, per the open question below), then delete the branch.**
- `upstream-main` — 0 unique commits, 39 behind `main`. **Safe to delete directly, no merge needed.**

## Commands to run (in order), once approved

```bash
# ============================================================
# FAMILY A — /Users/sac/ex4pm
# ============================================================

# 1. Junk cleanup in the canonical repo (no git object involved)
rm /Users/sac/ex4pm/ex4pm   # self-referential symlink, verified with `file`/`ls -la`

# 2. MANUAL REVIEW REQUIRED: docs/jira/v26.9.11/a2a-client-additive-path.md
#    (untracked in canonical repo) -- commit it or delete it, your call; no command given.

# 3. ex4pm-igniter-fix: cherry-pick its one unique commit, discard the
#    regenerated benchmark table, then remove the worktree
cd /Users/sac/ex4pm
git cherry-pick 55c6e4f
git -C /Users/sac/ex4pm-igniter-fix checkout -- apps/ex4pm/docs/thesis/chapters/generated_ocel_benchmark_tables.tex
git worktree remove /Users/sac/ex4pm-igniter-fix

# 4. MANUAL REVIEW REQUIRED: ex4pm-worktrees/predict-execute-episode-20260903/tools/
#    and ex4pm-worktrees/qualification-domain/tools/ (real, uncommitted Python scripts).
#    After you've decided to keep or discard them:
git -C /Users/sac/ex4pm-worktrees/predict-execute-episode-20260903 checkout -- apps/ex4pm/docs/thesis/chapters/generated_ocel_benchmark_tables.tex
git worktree remove /Users/sac/ex4pm-worktrees/predict-execute-episode-20260903
git -C /Users/sac/ex4pm-worktrees/qualification-domain checkout -- apps/ex4pm/docs/thesis/chapters/generated_ocel_benchmark_tables.tex mix.lock
git worktree remove /Users/sac/ex4pm-worktrees/qualification-domain

# 5. 8 clean, fully-merged .claude/worktrees -- remove directly, no merge needed
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_0fa532e2-ea8-1
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_0fa532e2-ea8-2
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_54a9e1aa-5d9-2
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_94919046-fe4-1
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_94919046-fe4-2
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_a11cea38-da9-1
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_a11cea38-da9-2
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_a11cea38-da9-3

# 6. 5 worktrees with exactly one unique commit each -- cherry-pick, then remove
git cherry-pick d8e13b4   # feat: add mix ex4pm.ggen.sync generic manifest-driven ggen task
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_76b4895f-667-7
git cherry-pick 7ccbdb1   # feat(ggen): automated determinism gate for generated files
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_76b4895f-667-8
git cherry-pick ea4d4e6   # fix(stream): real idempotency dedup in Ingest.ingest_envelope/2
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_7916b9c5-ab5-20
git cherry-pick 9d76818   # fix: OCEL 2.0 object attributes as a real value-time log, not a snapshot
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_7916b9c5-ab5-28
git cherry-pick 57a1b1e   # docs: note Ex4pm.Engine.Beam4pm's new contract-drift verification
git worktree remove /Users/sac/ex4pm/.claude/worktrees/wf_ae9bd890-20d-2

# 7. MANUAL REVIEW REQUIRED -- 3 worktrees with real uncommitted work, cannot be automated:
#      /Users/sac/ex4pm/.claude/worktrees/wf_4bda08d9-e8e-1  (20 files, lib/ex4pm_engine/wasm/*.ex)
#      /Users/sac/ex4pm/.claude/worktrees/wf_4bda08d9-e8e-2  (lib/ex4pm/engine.ex, engine/adapters.ex, new test)
#      /Users/sac/ex4pm/.claude/worktrees/wf_ae9bd890-20d-1  (new priv/ggen/templates/beam4pm.ex.eex)
#    For each: either commit the WIP to a branch and merge/cherry-pick it, or explicitly
#    discard it (`git -C <path> checkout -- .` / `git -C <path> clean -fd`) before removal.
#    No blanket command is given here on purpose.

# 8. Prune the worktree admin list once every path above is actually gone
git -C /Users/sac/ex4pm worktree prune -v

# ============================================================
# FAMILY B — /Users/sac/ash_ex4pm
# ============================================================

# 9. Cherry-pick the 4 real unmerged commits (branch refs are intact even though
#    the worktree checkouts are gone) -- confirm target branch first, see Open Questions
cd /Users/sac/ash_ex4pm
git cherry-pick 43f8c75   # fix: recover manage_relationship-touched record identities from notification.data
git cherry-pick da3b61b   # fix: emit real changeset attribute values in OCEL event envelopes
git cherry-pick 77c3010   # fix: add real qualifier: DSL option, remove hardcoded "primary" E2O qualifier
git cherry-pick 4d74dc7   # fix(notifier): populate real changed attribute values on :update actions

# 10. Delete the 4 now-merged branches
git branch -d fix/notifier-data-relationships
git branch -d fix/notifier-ocel-attributes
git branch -d fix/notifier-qualifier-dsl
git branch -d fix/ocel-attribute-history

# 11. Delete the 15 already-merged branches (safe, no unique commits, per the table above)
git branch -d fix/activity-enforce-keys-on
git branch -d fix/activity-typed-attributes
git branch -d fix/brce-gate-capabilities-validation
git branch -d fix/brce-gate-ordering
git branch -d fix/brce-gate-subject-hash
git branch -d fix/domain-verifier-resource-check
git branch -d fix/dsl-activity-describe
git branch -d fix/dsl-qualifier-field
git branch -d fix/notifier-record-id
git branch -d fix/notifier-relationship-objects
git branch -d fix/notifier-scope-docs
git branch -d fix/notifier-simple-notifiers
git branch -d fix/o2o-emission
git branch -d fix/ocel-object-type-schema
git branch -d fix/persist-after-ordering
git branch -d upstream-main

# 12. Prune the stale worktree admin metadata, then remove the leftover
#     non-git directories left behind in /tmp and /tmp/claude-501
git -C /Users/sac/ash_ex4pm worktree prune -v
rm -rf /private/tmp/ash_ex4pm_attr_history /private/tmp/ash_ex4pm_wt_brce_gate \
       /private/tmp/ash_ex4pm_wt_describe /private/tmp/ash_ex4pm_wt_notif_data \
       /private/tmp/ash_ex4pm_wt_notifier_relmgmt /private/tmp/ash_ex4pm_wt_notifier_scope \
       /private/tmp/ash_ex4pm_wt_o2o /private/tmp/ash_ex4pm_wt_ocel_attrs \
       /private/tmp/claude-501/ash_ex4pm_dsl_fix /private/tmp/claude-501/ash_ex4pm_event_attrs_schema \
       /private/tmp/claude-501/ash_ex4pm_notifier_simple /private/tmp/claude-501/ash_ex4pm_objtype \
       /private/tmp/claude-501/ash_ex4pm_persist_fix /private/tmp/claude-501/ash_ex4pm_qualifier_fix \
       /private/tmp/claude-501/ash_ex4pm_qualifier_impl /private/tmp/claude-501/ash_ex4pm_wt \
       /private/tmp/claude-501/ash_ex4pm_wt2 /private/tmp/claude-501/ash_ex4pm_wt_brce \
       /private/tmp/claude-501/ash_ex4pm_wt_brcegate
```

## Open questions

- **Which branch is the real cherry-pick target in `ash_ex4pm`?** `rename/automated-planning` (checked out, 2 ahead of `main`) or `main` itself. Both are plausible "canonical" targets; git alone can't tell which one the user intends as the trunk going forward — ask before running step 9.
- **`ex4pm`'s local `main` is diverged from `origin/main`** (11 ahead, 1 behind). This is a pre-existing condition of the canonical repo's own branch, not created by the worktree sprawl, and reconciling it (merge/rebase/force-push decision) is a separate task from this cleanup — flagging it here since it affects what "the canonical repo, in sync" actually means going forward.
- **`docs/jira/v26.9.11/a2a-client-additive-path.md`** sitting untracked in the canonical repo for 6 days (since 2026-09-11) — intentional WIP or an accidental stray file? Git cannot distinguish the two; needs a human look at the content.
- **The `tools/` directories** in `ex4pm-worktrees/predict-execute-episode-20260903` and `ex4pm-worktrees/qualification-domain` (real Python scripts, never committed to any branch) — are these still-needed tooling that should be committed into the canonical repo, or abandoned scratch work? Cannot be inferred from git history since they were never tracked.
- **The three dirty `.claude/worktrees` (`wf_4bda08d9-e8e-1`, `wf_4bda08d9-e8e-2`, `wf_ae9bd890-20d-1`)** carry real uncommitted code. Whether this WIP is still wanted, superseded by later merged work, or safe to discard cannot be determined from git state alone — each needs a human diff review (commands above point at the exact files) before any deletion.
- **Why are all 19 `ash_ex4pm` worktree admin entries `prunable`** (gitdir pointing to a non-existent location) while their directories still physically exist as plain, non-git leftovers? This looks like the worktrees were torn down by deleting the inner `.git` file directly (e.g. a manual `rm` or a cleanup script) rather than via `git worktree remove`, leaving both stale admin metadata in `/Users/sac/ash_ex4pm/.git/worktrees/` and orphaned directories in `/private/tmp`. Confirms this cleanup should finish the job git worktree admin already half-registered, but the original cause (was this the "deleted gemma manually" cleanup mentioned, or something else?) was not something git records and could not be verified here.

## Merge Execution Log (2026-09-17)

Content-level evaluation and merging only, per explicit user instruction: **no file,
directory, worktree, or branch was deleted, discarded, or discarded via `checkout --`/
`clean`/`reset --hard`.** Deletion is a separate, later pass. Every git state below was
re-verified live immediately before acting (`git status --short`, `git log -1`,
`git merge-base --is-ancestor`) rather than trusted from the table above.

### Family A — `/Users/sac/ex4pm` (canonical, branch `feat/a2a-client-additive-path`)

Re-verification confirmed the doc's state exactly (same 3 untracked junk items, same
`main`/`origin/main` 11-ahead/1-behind divergence, same worktree list). Working tree had
zero tracked modifications before starting, so every cherry-pick below applied cleanly or
was cleanly abortable.

**Committed and pushed to `origin/feat/a2a-client-additive-path`** (5 new commits, all
verified present with `git log --oneline 9c6d950..HEAD` and confirmed on `origin` via
`git ls-remote`):

| Commit (canonical) | Source | Description |
|---|---|---|
| `0834d78` | cherry-pick of `ex4pm-igniter-fix`'s `55c6e4f` | fix: guard `Igniter.Mix.Task` usage so prod compile doesn't require igniter |
| `8f5d524` | cherry-pick of `wf_7916b9c5-ab5-20`'s `ea4d4e6` | fix(stream): real idempotency dedup in `Ingest.ingest_envelope/2` |
| `59501af` | cherry-pick of `wf_7916b9c5-ab5-28`'s `9d76818` | fix: OCEL 2.0 object attributes as a real value-time log, not a snapshot |
| `acfe1e5` | cherry-pick of `wf_ae9bd890-20d-2`'s `57a1b1e` | docs: note `Ex4pm.Engine.Beam4pm`'s new contract-drift verification |
| `5548f26` | new commit (previously untracked file) | docs: capture `a2a-client-additive-path.md` writeup — content confirmed it documents already-merged `9c6d950`, not stray WIP, so it was safe to commit as-is |

Push: `git push origin feat/a2a-client-additive-path` → `[new branch]` on
`seanchatmangpt/ex4pm` (same remote/branch this repo already had configured; no force,
no new remote).

**Cherry-picks attempted and cleanly aborted (NOT resolved — genuine content-level merge
decision required, not a mechanical operation):**

- `wf_76b4895f-667-7`'s `d8e13b4` ("feat: add mix ex4pm.ggen.sync generic manifest-driven
  ggen task") — add/add conflict on `lib/mix/tasks/ex4pm.ggen.sync.ex` and
  `priv/ggen/manifest.json`. Diffed both sides: canonical HEAD already has an
  independently-written `mix ex4pm.ggen.sync` task with a **different manifest schema**
  (different unit names, different query-binding keys, different usage docs) than this
  branch's version. These are two competing implementations of the same feature, not a
  textual conflict — picking one over the other is an editorial/design decision I am not
  confident is "purely additive," so `git cherry-pick --abort` was run and the working
  tree verified clean (`git status --short` showed no tracked changes) before moving on.
- `wf_76b4895f-667-8`'s `7ccbdb1` ("feat(ggen): automated determinism gate for generated
  files") — same conflict cluster, add/add conflicts on 4 files
  (`lib/mix/tasks/ex4pm.ggen.verify_determinism.ex`, `priv/ggen/manifest.json`,
  `priv/ggen/templates/standing_coded.ex.eex`,
  `test/ex4pm_ggen_verify_determinism_test.exs`) plus a clean auto-merge on `mix.exs`.
  Same reasoning: aborted cleanly, working tree re-verified clean.

**Preserved by committing WIP in place (on the worktree's own existing branch, NOT
merged into canonical) and pushing that branch to `origin` as a new branch** — this
captures the content durably on the remote without making the "is this WIP still
wanted / superseded?" judgment call the plan doc flagged as needing a human:

| Worktree | Branch | New commit | Pushed to origin |
|---|---|---|---|
| `wf_4bda08d9-e8e-1` | `worktree-wf_4bda08d9-e8e-1` | `93fad16` "wip: preserve uncommitted wasm engine changes" (20 files, 101+/57-, `lib/ex4pm_engine/wasm/*.ex`) | yes, `[new branch]` |
| `wf_4bda08d9-e8e-2` | `worktree-wf_4bda08d9-e8e-2` | `b35ac6c` "wip: preserve uncommitted engine/adapters changes" (`lib/ex4pm/engine.ex`, `lib/ex4pm/engine/adapters.ex`, new `test/engine_wasm_remote_test.exs`) | yes, `[new branch]` |
| `wf_ae9bd890-20d-1` | `worktree-wf_ae9bd890-20d-1` | `924db0a` "wip: preserve uncommitted beam4pm.ex.eex template addition" (121-line addition to `priv/ggen/templates/beam4pm.ex.eex`) | yes, `[new branch]` |

Each worktree's `git status --short` was confirmed empty (fully committed) after its
commit, before pushing.

**Also pushed as-is (already-committed content, just not yet on `origin`), to preserve
it ahead of the still-unresolved merge-conflict decision above:**

- `worktree-wf_76b4895f-667-7` (carries `d8e13b4`) → pushed, `[new branch]`
- `worktree-wf_76b4895f-667-8` (carries `7ccbdb1`) → pushed, `[new branch]`

**Left untouched, not acted on (documented reasons, no git command run against them):**

- `ex4pm/ex4pm` self-referential symlink — junk, deletion out of scope for this pass.
- `.claude/` untracked dir — expected workflow admin dir; committing it would embed the
  nested worktree checkouts into the repo as tracked files, not "additive," left alone.
- `docs/jira/v26.9.17/` (this plan doc's own directory) — left untracked; committing the
  plan doc itself was not asked for in this pass.
- `ex4pm-igniter-fix`'s dirty `generated_ocel_benchmark_tables.tex` and the 2
  `ex4pm-worktrees/*` dirty `.tex`/`mix.lock` files — regenerated-artifact diffs per the
  doc's own assessment; left exactly as found rather than discarded, since discarding
  (`checkout --`) is a hard-banned operation in this pass.
- `ex4pm-worktrees/predict-execute-episode-20260903/tools/` and
  `ex4pm-worktrees/qualification-domain/tools/` — inspected directly (not just trusted
  from the doc): both contain real Python source **and** `__pycache__/`, a stray
  `.qualification_server.log`, and nested `episode-*`/`episode-control-*` run-artifact
  directories, not just clean utility scripts as the doc's one-line summary suggested.
  Copying this wholesale into the canonical repo would mix genuine tooling with
  disposable run logs/bytecode — a real editorial judgment call, not a mechanical
  git operation, so nothing was copied or committed. Left exactly as found.
- The 8 clean, fully-merged `.claude/worktrees/*` (`wf_0fa532e2-ea8-{1,2}`,
  `wf_54a9e1aa-5d9-2`, `wf_94919046-fe4-{1,2}`, `wf_a11cea38-da9-{1,2,3}`) — re-verified
  0 ahead of `main`, clean; nothing to merge, nothing done.

### Family B — `/Users/sac/ash_ex4pm` (canonical, branch `rename/automated-planning`)

Re-verification confirmed the doc's state exactly: clean, 2 ahead / 0 behind `main`,
same remote. The 4 branches with a real unique commit each (`fix/notifier-data-relationships`,
`fix/notifier-ocel-attributes`, `fix/notifier-qualifier-dsl`, `fix/ocel-attribute-history`)
were re-checked and still each carry exactly 1 unique commit vs. both `main` and
`rename/automated-planning`.

**Not cherry-picked** — the plan doc's own Open Questions section correctly flags that
the cherry-pick *target* (`main` vs. `rename/automated-planning`) is genuinely ambiguous
and needs the user's call; guessing would violate this pass's "don't guess, describe
instead" constraint.

**Instead, preserved without deciding the target:** confirmed via `git ls-remote
--heads origin` that none of the 4 branches existed on `origin` yet, then pushed all 4
as-is (no cherry-pick, no rebase, no merge — just the existing branch tip, same remote
the repo already has configured):

- `git push origin fix/notifier-data-relationships` → `[new branch]`
- `git push origin fix/notifier-ocel-attributes` → `[new branch]`
- `git push origin fix/notifier-qualifier-dsl` → `[new branch]`
- `git push origin fix/ocel-attribute-history` → `[new branch]`

This makes all 4 real, unmerged fixes durable on GitHub (visible for a PR once the
target branch is confirmed) without pre-judging which branch they land on.

**Left untouched, not acted on:**

- The 15 already-merged branches and `upstream-main` — 0 unique commits vs. `main`,
  nothing to capture; not pushed (would add no content, only later deletion-pass noise).
- All 19 `prunable` worktree directories under `/private/tmp` and
  `/private/tmp/claude-501` — no `git worktree prune`, no `rm`, per the hard
  no-deletion constraint. Left exactly as found.

### Still open (for the separate deletion pass and/or user decisions)

1. **`ex4pm/ex4pm`** self-symlink — confirmed junk (`ex4pm -> /Users/sac/ex4pm`), safe to
   delete whenever the deletion pass runs.
2. **`ex4pm-igniter-fix`, `ex4pm-worktrees/predict-execute-episode-20260903`,
   `ex4pm-worktrees/qualification-domain`** — each worktree's one real unique commit (if
   any) is now captured in canonical (`ex4pm-igniter-fix`'s `55c6e4f` is; the other two
   had 0 unique commits already). Once their `tools/`-directory content decision
   (below) and their trivial regenerated-file dirty state are resolved, these 3 worktrees
   are safe to `git worktree remove`.
3. **`tools/` content in the 2 `ex4pm-worktrees/*` dirs** — needs a human pass to split
   real tooling worth committing from `__pycache__`/log/episode-run artifacts worth
   discarding; not resolved here (see "Left untouched" above for what was actually found).
4. **`d8e13b4` and `7ccbdb1`** (the two ggen-sync/determinism-gate commits) — real,
   valuable content, now durably pushed to `origin` as
   `worktree-wf_76b4895f-667-7`/`-8`, but **not** merged into canonical: they conflict
   with an independently-written, already-present `mix ex4pm.ggen.sync` +
   `ex4pm.ggen.verify_determinism` implementation on `feat/a2a-client-additive-path`.
   Needs a human decision on which manifest-schema design wins (or whether to hand-merge
   both feature sets) before either branch can be merged. Once resolved, the losing
   worktree/branch becomes safe to remove in the deletion pass.
5. **3 dirty `.claude/worktrees`** (`wf_4bda08d9-e8e-1`, `wf_4bda08d9-e8e-2`,
   `wf_ae9bd890-20d-1`) — WIP is now committed and pushed to `origin` (branches
   `worktree-wf_4bda08d9-e8e-1`/`-2`, `worktree-wf_ae9bd890-20d-1`), so nothing is at
   risk of loss, but **not merged into canonical**: whether this WIP is still wanted,
   stale (23/23/21 commits behind `main` respectively), or superseded needs a human
   diff review before it's merged or the worktree is removed.
6. **The 8 clean, fully-merged `.claude/worktrees`** — confirmed 0 ahead of `main`,
   nothing to merge; safe to `git worktree remove` directly whenever the deletion pass
   runs.
7. **`ex4pm`'s local `main` vs. `origin/main` divergence** (11 ahead / 1 behind) —
   unchanged by this pass, pre-existing, explicitly out of scope per the doc.
8. **`docs/jira/v26.9.11/a2a-client-additive-path.md`** — resolved: committed as `5548f26`
   (content confirmed it documents already-merged work).
9. **Family B cherry-pick target** (`main` vs. `rename/automated-planning`) — still an
   open question for the user; the 4 candidate commits are now safely pushed to `origin`
   pending that decision (see above).
10. **Family B's 19 `prunable` worktree admin entries + `/private/tmp` leftover
    directories** — confirmed still present, untouched; safe to `git worktree prune` and
    delete the leftover directories once the deletion pass runs (no unique content in
    any of them per the original audit).
