# v26.9.1 Jira-Style Plan

## Charter / Define

This repo (ex4pm) is mid-cycle on a DMEDI-shaped process-intelligence and
distributed-runtime rearchitecture. Branch names and recent commit history show three
concurrent workstreams: (1) a "select portfolio" evaluation pipeline that scores
competing implementations (distributed-runtime, evidence, planner, search, semantic)
against each other and picks a winner (`develop/select-*` branches), (2) an "explore
courts" pattern that runs adversarial/differential tests per subsystem
(`explore/26.8.23-*-courts`), and (3) a maximalist DMEDI exploration branch
(`scheduled/dmedi-explore-maximalist-20260824`, `dmedi/explore-25-process-intelligence-
20260823`). Main itself has moved on independently since 2026-08-23 — direct pushes for
release bumps, wasm4pm bindings, k8s secret hygiene, and OCEL benchmark regeneration,
with zero merges of the `develop/select-*` or `explore/*` branches back into it.

The v26.9.1 workstream's goal: decide, for each stale portfolio-selection and
exploration branch, whether its content is still relevant against current main, and
either rebase/re-verify it to mergeable state or formally park/close it — closing the
gap between "explored/selected in a branch" and "actually landed in main."

## Measure — Current State (real `git log`/`git branch -a`, not guesses)

Repo: `https://github.com/seanchatmangpt/ex4pm.git`, default branch `main`.
All SHAs and dates below are from real `git log` output against `origin/*` after
`git fetch --all --prune` on a fresh clone; ahead/behind counts are
`git rev-list --left-right --count origin/main...origin/<branch>`.

### main (recent activity — confirms direct pushes, no merge commits since 08-23)

| SHA | Date (local) | Message |
|-----|---------------|---------|
| `f50f0af` | 2026-08-31 16:27:05 -0700 | fix: stop 2 real test failures -- closed-loop process leak, brittle live-data assertion |
| `bb8da84` | 2026-08-31 15:40:52 -0700 | chore(fmt): finish mix format cleanup across ws5_contracts tests |
| `0381a87` | 2026-08-31 15:39:43 -0700 | fix(test): correct ExUnit skip tuples, calver contract, and formatting |
| `2c2bf9b` | 2026-08-31 15:20:45 -0700 | chore(thesis): regenerate OCEL benchmark tables (665404 events) |
| `78648bc` | prior | security: stop tracking k8s/secret.yaml, add gitignore + example template |

Verified: each of the four 08-31 commits on main has exactly one parent
(`git log --format="%H %P"`), confirming they are direct single-commit pushes to
main, not merge-commit landings of any feature branch.

### All active remote branches (latest commit each)

| Branch | Latest SHA | Date | Ahead/Behind main | Message |
|--------|-----------|------|--------------------|---------|
| `main` | `f50f0af` | 2026-08-31 16:27:05 | 0 / 0 | fix: stop 2 real test failures |
| `automation/claude-daily-drain` | `b10993b` | 2026-08-27 20:54:48 | not measured | ci(factory): add daily Claude backlog drain |
| `develop/select-distributed-runtime-20260823-2031` | `8a29cc5` | 2026-08-24 13:54:18 | 190 / 47 | fix(distributed): hash canonical replay bytes in correct argument order |
| `develop/select-evidence-portfolio-20260823-1930` | `8d8b810` | 2026-08-23 19:37:51 | 193 / 24 | ci(develop): verify selected evidence portfolio exact head |
| `develop/select-planner-portfolio-20260823-1930` | `a450742` | 2026-08-23 19:37:38 | 193 / 22 | ci(develop): verify selected planner portfolio exact head |
| `develop/select-search-portfolio-20260823-2031` | `e7e7b50` | 2026-08-23 20:35:52 | 190 / 46 | evidence(select): record search portfolio selection |
| `develop/select-semantic-convergence-20260823-2031` | `6dc957e` | 2026-08-23 20:35:57 | 190 / 46 | evidence(select): record semantic convergence selection |
| `develop/select-semantic-portfolio-20260823-1930` | `8ba8430` | 2026-08-23 19:37:45 | 193 / 20 | ci(develop): verify selected semantic portfolio exact head |
| `dmedi/explore-25-process-intelligence-20260823` | `a7ee25b` | 2026-08-23 14:30:15 | not measured | explore: add cross-methodology differential closure tests |
| `docs/refresh-agents-20260823` | `fe0c812` | 2026-08-23 10:37:18 | not measured | docs: rebuild agent operating contract |
| `explore/26.8.23-evidence-courts` | `fe99c07` | 2026-08-23 19:25:20 | not measured | explore(evidence): add hybrid logical clock court |
| `explore/26.8.23-planner-courts` | `6dcbbdf` | 2026-08-23 19:25:37 | not measured | fix(explore): repair A* court syntax |
| `explore/26.8.23-semantic-courts` | `e8681f0` | 2026-08-23 19:25:08 | not measured | explore(semantics): add closure-operator law court |
| `project2/ws5-learning-20260827-21c` | `0133449` | 2026-08-27 21:46:27 | not measured | fix: make core test-support guard delimiter-safe |
| `project2/ws5-learning-20260828-c04-ex4pm` | `f613e6c` | 2026-08-27 21:04:12 | not measured | test(ws5): guard deterministic chicago seed |
| `release/v26.8.23` | `b78fd0d` | 2026-08-23 10:56:12 | not measured | fix(package): isolate Hex builder stdin across package graph |
| `scheduled/dmedi-explore-maximalist-20260824` | `2c56fa4` | 2026-08-23 20:24:23 | not measured | test(explore): distinguish strong and weak temporal standing |

Only 4 commits landed anywhere since 2026-08-31 00:00, and all 4 are on `main` — no
branch other than `main` has moved in the last 24h window ending 2026-09-01. Every
`develop/select-*` and `explore/*` branch is 20-47 commits behind current main and
190+ commits ahead on its own diverged content, meaning a naive merge is not safe:
each needs a real rebase and re-verification, not a merge commit.

## Explore — Options Implied by Branch Names

1. **Portfolio-selection pattern (`develop/select-*`)** — five parallel branches, one
   per subsystem (distributed-runtime, evidence, planner, search, semantic-portfolio,
   semantic-convergence), each apparently the *chosen* implementation out of a larger
   competing set (implied by "select" + "portfolio" naming and "ci(develop): verify
   selected ... exact head" messages, which read as an automated selection-pinning
   step, not human-authored work). Option: treat these as the DMEDI Explore-phase
   output that was never carried into Develop/Implement on main.
2. **Adversarial "courts" pattern (`explore/*-courts`)** — per-subsystem
   differential/adversarial test suites (evidence hybrid logical clock, planner A*,
   semantic closure-operator laws). Option: these are qualification harnesses meant to
   falsify the `select-*` portfolio branches before merge; they may need to run
   *against* the select branches rather than against main directly.
3. **Maximalist DMEDI branch** (`scheduled/dmedi-explore-maximalist-20260824`) —
   temporal-standing test work, likely a superset/parent exploration branch that the
   `select-*` and `explore/*-courts` branches were split out from. Option: check
   ancestry (merge-base) against the other branches before assuming independence.
4. **ws5-learning branches** (`project2/ws5-learning-*`) — two branches one day apart
   (08-27, 08-28) touching test-support guards and Chicago-style seeding; likely
   superseded by each other or by main's own `ws5_contracts` formatting work
   (`bb8da84` on main, 08-31). Option: diff each against main's current
   `ws5_contracts` state before deciding either is still needed.
5. **Do nothing / archive** — given the 190+ commit divergence and zero activity in
   the last 24h+ window, an option is to formally close all `develop/select-*` and
   `explore/*` branches as superseded-by-main-diverging, extracting only specific
   diffs (if any) that never landed, rather than attempting a full rebase.

## Develop — Concrete Next Engineering Steps Per Workstream

For every branch below: work happens in an isolated worktree per
`~/.claude/rules/local-dfcm-manufacturing-engine.md` law 3, one branch per worktree.

1. **`develop/select-distributed-runtime-20260823-2031`**
   - `git merge-base origin/main origin/develop/select-distributed-runtime-20260823-2031`
     to find the true fork point, then `git log <merge-base>..origin/develop/...`
     to isolate the 190 unique commits from noise.
   - Run the existing test suite on the branch as-is (no changes) to get a real
     baseline pass/fail count before touching anything.
   - Rebase onto current `origin/main` in the worktree; resolve conflicts by reading
     both sides in full (no `-X theirs`/`-X ours`).
   - Re-run tests post-rebase; diff pass/fail against the pre-rebase baseline.

2. **`develop/select-evidence-portfolio-20260823-1930`**,
   **`develop/select-planner-portfolio-20260823-1930`**,
   **`develop/select-search-portfolio-20260823-2031`**,
   **`develop/select-semantic-convergence-20260823-2031`**,
   **`develop/select-semantic-portfolio-20260823-1930`**
   - Same merge-base + baseline-test + rebase + re-test procedure as above, run
     concurrently across five worktrees (independent, no shared state).
   - Because these are "select" branches (implying a completed comparison already
     happened), inspect commit bodies for the losing alternatives they compared
     against — confirm nothing valuable from a rejected alternative is being dropped
     silently.

3. **`explore/26.8.23-evidence-courts`**, **`explore/26.8.23-planner-courts`**,
   **`explore/26.8.23-semantic-courts`**
   - Determine intended target: do these courts test the corresponding `select-*`
     branch, or main directly? Check commit diffs for which module paths they touch.
   - If they target the `select-*` branches, they must be rebased together with their
     matching `select-*` branch as one unit, not independently.
   - Run each court suite against current main head as a control to see how many
     failures are pre-existing vs. introduced by stale branch content.

4. **`scheduled/dmedi-explore-maximalist-20260824`**
   - Run `git merge-base` against each of the above branches to determine if it is
     an ancestor (parent exploration) or a sibling. This changes rebase order:
     ancestors get rebased first.

5. **`project2/ws5-learning-20260827-21c`** and
   **`project2/ws5-learning-20260828-c04-ex4pm`**
   - Diff each branch's `ws5_contracts`-related changes against main's `bb8da84`
     (chore(fmt): finish mix format cleanup across ws5_contracts tests) to check for
     overlap/redundancy before rebasing either.
   - If both branches make the same fix independently, keep the later one
     (08-28-c04-ex4pm) and close the earlier as superseded.

6. **`docs/refresh-agents-20260823`**, **`release/v26.8.23`**,
   **`automation/claude-daily-drain`**
   - Lower priority / non-competing: docs and release/automation branches don't
     compete with the select/explore workstreams. Verify each still applies cleanly
     against main; if release/v26.8.23 is superseded by main's own
     `chore(release): bump version to 26.8.28` commit, close it.

## Implement — Merge Order, Verification Gates, Rollout/Monitoring

### Merge order (sequential integration point only — worktree work stays parallel)

1. `scheduled/dmedi-explore-maximalist-20260824` first, if ancestry check (Develop
   step 4) shows it is a true ancestor of the select/courts branches — landing it
   first avoids re-doing the same rebase work per downstream branch.
2. `develop/select-evidence-portfolio-20260823-1930` +
   `explore/26.8.23-evidence-courts` together (courts branch validates the select
   branch before its merge).
3. `develop/select-planner-portfolio-20260823-1930` +
   `explore/26.8.23-planner-courts` together, same pattern.
4. `develop/select-semantic-portfolio-20260823-1930` +
   `develop/select-semantic-convergence-20260823-2031` +
   `explore/26.8.23-semantic-courts` together — these three all touch "semantic" and
   likely share code paths; land as one reviewed unit to avoid re-conflicting.
5. `develop/select-search-portfolio-20260823-2031` and
   `develop/select-distributed-runtime-20260823-2031` — largest divergence (190
   commits, 46-47 behind), land last after the smaller portfolios establish the
   rebase pattern and any shared conflict-resolution decisions.
6. `project2/ws5-learning-*` (whichever survives the Develop-step-5 dedup check).
7. `docs/refresh-agents-20260823`, `release/v26.8.23`,
   `automation/claude-daily-drain` — land opportunistically, no dependency on 1-6.

Each numbered step is one consequential merge boundary per
`local-dfcm-manufacturing-engine.md`'s "fan out maximally, integrate conservatively" —
rebase work for steps 2-5 can run in parallel worktrees, but the actual merge to main
happens one step at a time, re-verifying main after each before starting the next
merge.

### Verification gates (must pass before each merge in the order above)

- Real test suite run on the rebased branch in its worktree (`mix test` or repo's
  actual test command — confirm via `mix.exs`/CI config, not assumed) with zero new
  failures versus the pre-rebase baseline captured in Develop step 1/2.
- Chicago-style test audit: `grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch"`
  equivalent for Elixir (`Mox`, `:meck`) over any new/changed test files — zero
  matches, or each match justified per `~/.claude/rules/testing-chicago-style.md`'s
  one-legitimate-use criteria.
- OCEL/benchmark regression check: since main's `2c2bf9b` regenerated OCEL benchmark
  tables (665404 events), any merged branch touching that pipeline must regenerate
  and diff those tables again post-merge, not assume the old numbers still hold.
- No merge commit lands without the target branch's HEAD SHA and the pre-merge main
  SHA recorded in the commit message, so `git log --format="%H %P"` on main stays
  auditable the same way the 08-31 commits were verified above.

### Rollout / monitoring plan

- After each Implement-phase merge, tag the resulting main commit
  (`v26.9.1-step-N`) so a regression can be bisected to a specific workstream
  landing rather than the whole v26.9.1 batch.
- Re-run the full test suite and the OCEL benchmark regeneration once after all
  seven steps land, as a final integration check distinct from the per-step gates.
- Standing check: add the branch-divergence measurement in this document's Measure
  section as a recurring check (e.g. a weekly `git rev-list --left-right --count`
  sweep across all remote branches) so a branch never again drifts 190+ commits
  behind main before someone notices, per DMEDI's Implement-phase "plan for control/
  monitoring after shipping, not just ship and walk away."

## See Also

- `~/.claude/rules/dmedi-methodology.md` — the Define/Measure/Explore/Develop/
  Implement structure this document follows
- `~/.claude/rules/local-dfcm-manufacturing-engine.md` — worktree isolation and
  "fan out maximally, integrate conservatively" principles applied to the merge order
  above
- `~/.claude/rules/testing-chicago-style.md` — the mock-audit gate cited in Implement

Last Updated: 2026-09-01
