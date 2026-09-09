# PORT-CHEAT-SCANNER-TO-ELIXIR (Create, upstream: ggen_igniter)

## Evidence

- `~/ggen/CONSTITUTION.md:60-64` — Principle IV, "Chicago TDD (Zero Tolerance)," states:
  Test-Driven Development using Chicago School methodology is MANDATORY (state-based
  testing, real collaborators, Red-Green-Refactor, 80%+ coverage on critical paths).
  It is marked `Mechanized: true`, `Enforced by: crates/ggen-cheat-scanner/src/lib.rs
  (CHEAT-T01 vacuous-assert, CHEAT-T02 tautological-result-check, CHEAT-T03
  no-assertion-test, CHEAT-T04 mock-import detectors); wired into just pre-commit via
  guard-cheat-scan at justfile:377-378`. A note on the same lines records that
  `guard-cheat-scan` currently fails on ~464 pre-existing findings across the ggen
  workspace (tracked as TECH-DEBT-001, not blocking new work) — i.e. the detector
  itself is real and live, independent of whether the workspace is clean under it.
  (Cited as reported by the prior research pass; not independently re-verified against
  `crates/ggen-cheat-scanner/src/lib.rs` or `justfile:377-378` in this run, per the
  task's own scope for `~/ggen` citations.)

- `~/ggen_igniter/lib` and `~/ggen_igniter/test` — grepped in this run
  (`grep -rniE "vacuous|tautolog|cheat.?scan" ~/ggen_igniter/lib ~/ggen_igniter/test`)
  and independently re-verified: 17 lines match, but every one is prose inside a
  comment, an assertion failure message, or a fixture script — e.g.
  `test/ggen_igniter_ash_manufacture_pack_test.exs:272` (`assert refusals != [],
  "refusals/0 is empty; every assertion below would be vacuous"`) and
  `test/fixtures/ash_manufacture_pack/bin/drift_check.py:233` (`"PARSE VACUOUS: ..."`
  inside a fixture drift-checker script). None of the 17 matches is a cheat-scan-style
  static detector (no module or task that inspects other test files for
  `assert true`, empty test bodies, or `Mock`/`patch`/`monkeypatch` imports). This
  confirms the prior research pass's "zero matches" finding for actual tooling,
  refined here to "zero tooling matches; 17 unrelated prose matches."

- `~/ex4pm` (this repo) already carries the same Chicago-style testing discipline as a
  standing, enforced-by-convention rule (`/Users/sac/.claude/rules/testing-chicago-style.md`,
  global) and as project doctrine (`/Users/sac/ex4pm/CLAUDE.md`, "Testing discipline
  (Chicago school — enforced, not just preferred)" section: "Real collaborators,
  state-based assertions; `unittest.mock`/mocking-equivalents over collaborators this
  codebase owns are banned by default. `mix chicago` and `ex4pm.audit.chicago` exist
  specifically to keep this honest at the OTP-distribution level"). Verified by reading
  `/Users/sac/ex4pm/CLAUDE.md` in this session: it names `mix ex4pm.lint.truth`
  ("anti-overclaiming static lint") and `mix ex4pm.audit.chicago` as existing
  qualification tasks under `lib/ex4pm/qualification/` (`lib/mix/tasks/`), but neither
  name nor description matches a cheat-scanner (vacuous-assert / tautological-check /
  no-assertion-test / mock-import detector) — those two existing tasks check
  overclaiming vocabulary and OTP-distribution realism respectively, not test-body
  shape. No `ggen.cheat_scan`-equivalent Mix task exists in this repo or in
  `~/ggen_igniter` as of this session.

## Recommendation

Port a minimal Elixir equivalent of `crates/ggen-cheat-scanner`'s four detectors
(CHEAT-T01..T04) as a new Mix task in `~/ggen_igniter`, not in `ex4pm` or `beam4pm`
directly, so any consumer (ex4pm, beam4pm, xaas) can invoke it uniformly:

- Task name: `mix ggen_igniter.cheat_scan` (mirrors `ggen.lint.truth`/
  `ex4pm.lint.truth` naming conventions already in use across this ecosystem).
- Detectors, scoped to `.ex`/`.exs` test files:
  - CHEAT-T01 (vacuous-assert): `assert true`, `assert 1 == 1`, or other
    statically-true assertion expressions.
  - CHEAT-T02 (tautological-result-check): assertions whose both sides are the
    same literal/expression (`assert x == x`).
  - CHEAT-T03 (no-assertion-test): `test "..."` blocks with zero `assert`/`refute`/
    `assert_raise`/`assert_receive` calls in the body.
  - CHEAT-T04 (mock-import): `import Mock`, `use Mox`, `:meck`, or `Mock.expect`/
    `Mock.with_mock` usage — flagging exactly the pattern
    `~/.claude/rules/testing-chicago-style.md` already bans globally
    ("`unittest.mock`, `Mock()`, ... Jest `jest.mock()` ... used to fake a
    collaborator this codebase owns").
- Wire it as an optional step any consumer's own `mix verify`/CI alias can call,
  the way `ex4pm`'s `mix verify` already chains `ex4pm.lint.truth` before `test`
  (`/Users/sac/ex4pm/CLAUDE.md`, "Commands" section).
- Scope this port to `~/ggen_igniter` only — this task does not authorize editing
  `~/ggen_igniter` or `~/ggen` from this session; it is filed as an upstream finding
  for whoever picks up work in that repo.

## Filed

- Date: 2026-09-09
- Filed from: `ex4pm` repo, branch `docs/xaas-integration-roadmap`
- Claude-Session: https://claude.ai/code/session_01XWhXfubgh1b1rFNNStAQot
