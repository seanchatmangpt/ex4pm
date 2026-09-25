"""autofde_lab Domain modelling ex4pm's real CI-qualification state.

LOCATION AND WHY
-----------------
Written inside an ISOLATED git worktree of ex4pm
(``/Users/sac/ex4pm-worktrees/qualification-domain``, branch
``qualification-domain-20260903``, created from the real ex4pm ``origin``
at HEAD ``e1eb78a785568aadc41b2df68c2feeed66f35a4e``) rather than in the
dirty canonical checkout at ``/Users/sac/ex4pm`` (that checkout carried
real uncommitted changes at task start -- ``git status --short`` showed
modified ``mix.exs`` / a generated benchmark table and several untracked
``apps/ex4pm_*`` files -- so it is not a safe place to run mutating
commands like ``mix deps.get`` or a background Phoenix server from).

Placed under ex4pm's own ``tools/`` tree, NOT inside the autofde-lab repo,
because:

1. Every STATE field this domain tracks is an observable fact about
   *this* repository and its host processes (``deps/``, a Cargo-built wasm
   artifact, TCP port 8080, a real ``mix test`` run) -- autofde_lab is the
   *generic* reusable planning library, ex4pm is the *subject* being
   modelled. Every existing autofde_lab domain keeps this same split:
   ``hub/domain/maze/maze.py`` embeds its own maze-string subject data;
   ``hub/domain/rcpsp/`` embeds its own scheduling-problem subject data.
   The subject here (a live sibling git repository) simply lives outside
   autofde-lab entirely, so the domain module follows the subject, not the
   library.
2. The task itself required doing this work "in an ISOLATED worktree of
   ex4pm" -- the natural place to *put* work that must happen inside that
   worktree is inside that worktree.

autofde_lab is not pip-installed anywhere reachable from this worktree (no
``[project.scripts]`` entry point exists in that repo at all -- see its
``src/autofde_lab/CLAUDE.md`` -- and building its wheel would compile the
C++ hub extension, which additionally needs the ``cpp/sdk/*`` nested git
submodules). So it is reached the same way the autofde-lab repo's own
``examples/`` scripts are run standalone: by pointing ``sys.path`` at the
sibling checkout's ``src/`` directory before importing it. See
``AUTOFDE_LAB_ROOT`` below for how that path is resolved.

THE REAL AUTOFDE_LAB DOMAIN/SOLVER CONTRACT THIS FOLLOWS
----------------------------------------------------------
Quoted from the real, already-registered ``D`` class the real A* solver
requires (autofde-lab @ 5600993bdbcd085d1b5decc71fa804168a9ec05f,
``src/autofde_lab/hub/solver/astar/astar.py`` lines 33-44)::

    class D(
        Domain,
        SingleAgent,
        Sequential,
        DeterministicTransitions,
        Actions,
        Goals,
        Markovian,
        FullyObservable,
        PositiveCosts,
    ):
        pass

and the ``DeterministicPlanningDomain`` preset that composes exactly that
set plus ``DeterministicInitialized`` (autofde-lab,
``src/autofde_lab/domains.py`` lines 395-406)::

    class DeterministicPlanningDomain(
        Domain,
        SingleAgent,
        Sequential,
        DeterministicTransitions,
        Actions,
        Goals,
        DeterministicInitialized,
        Markovian,
        FullyObservable,
        PositiveCosts,
    ):
        ...

``DeterministicPlanningDomain`` is a strict superset of Astar's own
required ``D`` (it adds only ``DeterministicInitialized``, needed to give
the domain a real ``get_initial_state()`` for solving, which Astar's
minimal ``D`` does not itself require since it is only a type bound). This
is exactly the base class the repo's own simplest reference domain uses --
``Maze`` (``src/autofde_lab/hub/domain/maze/maze.py`` line 63):
``class D(DeterministicPlanningDomain, UnrestrictedActions, Renderable)``.

This domain uses ``DeterministicPlanningDomain`` plus plain ``Actions``
(NOT ``UnrestrictedActions`` -- unlike Maze, actions here have real,
non-trivial preconditions: you cannot start the server before dependencies
are materialized, so not every action is applicable in every state).
"""

from __future__ import annotations

import os
import re
import socket
import subprocess
import sys
from enum import Enum
from itertools import product
from pathlib import Path
from typing import NamedTuple, Optional

# --------------------------------------------------------------------------
# Make the sibling autofde_lab package importable without installing it.
# Default points at the real, canonical autofde-lab checkout used by the
# rest of the Chatman Ecosystem; override with AUTOFDE_LAB_ROOT to point at
# any other checkout carrying the same source (e.g. an isolated worktree of
# autofde-lab that already has its Python dependencies synced).
# --------------------------------------------------------------------------
AUTOFDE_LAB_ROOT = Path(
    os.environ.get(
        "AUTOFDE_LAB_ROOT",
        "/Users/sac/chatman-ecosystem/platform-console/services/autofde-lab",
    )
)
_autofde_lab_src = AUTOFDE_LAB_ROOT / "src"
if _autofde_lab_src.is_dir() and str(_autofde_lab_src) not in sys.path:
    sys.path.insert(0, str(_autofde_lab_src))

from autofde_lab import DeterministicPlanningDomain, Space, Value  # noqa: E402
from autofde_lab.builders.domain import Actions  # noqa: E402
from autofde_lab.hub.space.gym import EnumSpace, ListSpace  # noqa: E402

__all__ = [
    "QualificationState",
    "QualificationAction",
    "Ex4pmQualificationDomain",
    "D",
]

# --------------------------------------------------------------------------
# Real, observable facts this domain is grounded in (found this session,
# not invented):
#
# - ``deps/`` materialization: ex4pm is a Mix umbrella project; its lock
#   file is ``mix.lock`` (77 top-level hex packages measured this session)
#   and ``mix deps.get`` populates one directory per package under
#   ``deps/``. Verified directly: a fresh `git worktree add` checkout of
#   ex4pm carries no ``deps/`` directory at all (worktrees never copy
#   gitignored build state), while the dirty canonical checkout at
#   ``/Users/sac/ex4pm`` has 76 populated ``deps/*`` directories against 77
#   locked packages.
#
# - the wasm artifact: found for real by grepping the ex4pm test suite,
#   not invented -- five real test files
#   (``apps/ex4pm_engine/test/reactors/wasm_capabilities_reactor_test.exs``,
#   ``wasm_all_capabilities_test.exs``, and three files under
#   ``apps/ex4pm_engine/test/wasm/``) all reference the exact same path:
#   ``~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm``.
#   That file exists on this machine today (8,894,130 bytes, built
#   2026-09-03). Its source is the real Cargo package
#   ``wasm4pm-ex4pm-bindings`` declared in
#   ``~/wasm4pm/crates/wasm4pm-ex4pm-bindings/Cargo.toml`` (workspace
#   member of ``~/wasm4pm/Cargo.toml``), and the real build command for a
#   crate in that workspace, found in ``~/wasm4pm/wasm4pm/package.json``
#   and ``~/wasm4pm/docs/archive/2026-06-09/root-stale/
#   WASM_BUILD_OPTIMIZATION_DEEP_DIVE.md``, is
#   ``cargo build --release --target wasm32-unknown-unknown``, scoped here
#   to the one package with ``-p wasm4pm-ex4pm-bindings``.
#
# - port 8080: found for real in ``config/runtime.exs`` line 16:
#   ``port = String.to_integer(System.get_env("PORT") || "8080")`` --
#   wired only when ``config_env() == :prod`` (or ``PHX_SERVER`` is set).
#   No ``:dev`` http port is configured anywhere in ``config/config.exs``,
#   so the real command that actually binds 8080 is a prod-mode
#   ``mix phx.server`` with ``PORT=8080`` and a real ``SECRET_KEY_BASE``
#   (``config/runtime.exs`` raises without one in ``:prod``).
#
# - tests: the real, only test command for this Mix umbrella is
#   ``mix test`` (also the first step of the repo's own ``verify`` alias
#   in ``mix.exs``). Its process exit code is the qualification signal --
#   never a parsed string match.
# --------------------------------------------------------------------------

WASM_ARTIFACT_RELATIVE = Path(
    "target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
)
_MIX_LOCK_PACKAGE_RE = re.compile(r'^\s*"([A-Za-z0-9_]+)":', re.MULTILINE)


class QualificationState(NamedTuple):
    """One observation of ex4pm's real CI-qualification state.

    Every field is derived from an actual command/filesystem/socket check
    at observation time -- none is assumed, cached-forever, or inferred
    from a different field. ``qualification_complete`` is carried as its
    own field (not merely a derived property) because the task this domain
    was built for treats it as a first-class STATE fact, but it is always
    constructed as the conjunction of the other four (see
    ``observe_state`` below) -- never set independently.
    """

    deps_materialized: bool
    wasm_built: bool
    server_running: bool
    tests_passing: bool
    qualification_complete: bool


class QualificationAction(Enum):
    """The four real actions this domain can take against ex4pm."""

    materialize_deps = 0
    build_wasm = 1
    start_server = 2
    run_tests = 3


# --------------------------------------------------------------------------
# Real state-checking functions. Each one runs an actual command / touches
# the actual filesystem or a real socket -- none returns a synthetic or
# assumed value.
# --------------------------------------------------------------------------


def check_deps_materialized(repo_root: Path) -> bool:
    """True iff every package locked in mix.lock has a populated deps/ dir."""
    mix_lock = repo_root / "mix.lock"
    deps_dir = repo_root / "deps"
    if not mix_lock.is_file() or not deps_dir.is_dir():
        return False
    names = _MIX_LOCK_PACKAGE_RE.findall(mix_lock.read_text())
    if not names:
        return False
    return all((deps_dir / name).is_dir() for name in names)


def check_wasm_built(wasm4pm_root: Path) -> bool:
    """True iff the real wasm4pm_ex4pm_bindings.wasm artifact exists and is non-empty."""
    artifact = wasm4pm_root / WASM_ARTIFACT_RELATIVE
    try:
        return artifact.is_file() and artifact.stat().st_size > 0
    except OSError:
        return False


def check_server_running(host: str = "127.0.0.1", port: int = 8080, timeout: float = 1.0) -> bool:
    """True iff a real TCP connection to host:port succeeds right now."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def run_mix_test(repo_root: Path, timeout: float = 1800.0) -> tuple[bool, str]:
    """Actually run `mix test`; return (exit_code == 0, combined output).

    This is the one and only source of truth for `tests_passing` -- never
    a parsed heuristic string match, per the task's own requirement that
    qualification be "checked via the actual mix test exit code, not a
    synthetic gate".
    """
    try:
        result = subprocess.run(
            ["mix", "test", "--color=false"],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, f"mix test could not be run/completed: {exc!r}"
    return result.returncode == 0, (result.stdout + result.stderr)


def observe_state(
    repo_root: Path,
    wasm4pm_root: Path,
    *,
    tests_passing: bool,
) -> QualificationState:
    """Re-derive the full real state.

    `tests_passing` is threaded through rather than recomputed here because
    it is the one field expensive enough (a full `mix test` run, up to
    minutes) that re-deriving it on every observation would make merely
    *looking at* the state mutate the world. It is only ever updated by
    `run_mix_test` inside the `run_tests` action's real effect function
    below -- every other field here is re-checked fresh, for real, every
    single call.
    """
    deps = check_deps_materialized(repo_root)
    wasm = check_wasm_built(wasm4pm_root)
    server = check_server_running()
    return QualificationState(
        deps_materialized=deps,
        wasm_built=wasm,
        server_running=server,
        tests_passing=tests_passing,
        qualification_complete=deps and wasm and server and tests_passing,
    )


ALL_STATES = [
    QualificationState(d, w, s, t, d and w and s and t)
    for d, w, s, t in product([False, True], repeat=4)
]
GOAL_STATE = QualificationState(True, True, True, True, True)


class D(
    DeterministicPlanningDomain,
    Actions,
):
    """Real T_domain bound: DeterministicPlanningDomain (superset of
    Astar's own required D — Domain, SingleAgent, Sequential,
    DeterministicTransitions, Actions, Goals, Markovian, FullyObservable,
    PositiveCosts, per astar.py lines 33-44 quoted above) plus plain
    Actions with real, non-trivial preconditions (not UnrestrictedActions,
    unlike Maze — see module docstring)."""

    T_state = QualificationState
    T_observation = T_state
    T_event = QualificationAction
    T_value = float
    T_predicate = bool
    T_info = None


class Ex4pmQualificationDomain(D):
    """A genuine autofde_lab Domain over ex4pm's real CI-qualification state.

    Constructing this domain performs no side effects. Every action's
    precondition and effect run a real, named external command (or a real
    socket probe / filesystem check) against `repo_root` / `wasm4pm_root`,
    and every effect RE-CHECKS the resulting state via those same real
    checks rather than assuming the command's own exit code implies the
    state it was meant to produce.
    """

    def __init__(
        self,
        repo_root: Optional[Path] = None,
        wasm4pm_root: Optional[Path] = None,
    ) -> None:
        self._repo_root = Path(
            repo_root
            if repo_root is not None
            else os.environ.get("EX4PM_ROOT", Path(__file__).resolve().parents[1])
        )
        self._wasm4pm_root = Path(
            wasm4pm_root
            if wasm4pm_root is not None
            else os.environ.get("WASM4PM_ROOT", str(Path.home() / "wasm4pm"))
        )

    # -- Initialized ------------------------------------------------------

    def _get_initial_state_(self) -> D.T_state:
        # tests_passing starts False: we have not yet run `mix test` in
        # this domain instance, and per absence-is-not-evidence discipline
        # (autofde-lab's own standing law) absence of a failing run is not
        # evidence of a passing one.
        return observe_state(self._repo_root, self._wasm4pm_root, tests_passing=False)

    # -- Actions / Events ---------------------------------------------------

    def _get_action_space_(self) -> D.T_agent[Space[D.T_event]]:
        return EnumSpace(QualificationAction)

    def _applicable(self, memory: D.T_state, action: QualificationAction) -> bool:
        """Real preconditions, one per action."""
        if action is QualificationAction.materialize_deps:
            return not memory.deps_materialized
        if action is QualificationAction.build_wasm:
            return not memory.wasm_built
        if action is QualificationAction.start_server:
            return memory.deps_materialized and not memory.server_running
        if action is QualificationAction.run_tests:
            return memory.deps_materialized and not memory.tests_passing
        return False  # pragma: no cover - exhaustive over the real Enum

    def _get_applicable_actions_from(
        self, memory: D.T_memory[D.T_state]
    ) -> D.T_agent[Space[D.T_event]]:
        return ListSpace(
            [a for a in QualificationAction if self._applicable(memory, a)]
        )

    # -- DeterministicTransitions ------------------------------------------

    def _get_next_state(
        self,
        memory: D.T_memory[D.T_state],
        action: D.T_agent[D.T_concurrency[D.T_event]],
    ) -> D.T_state:
        """Run the real command for `action`, then re-derive the full
        state via the real checks. Never assumes an effect."""
        tests_passing = memory.tests_passing

        if action is QualificationAction.materialize_deps:
            subprocess.run(
                ["mix", "deps.get"],
                cwd=str(self._repo_root),
                capture_output=True,
                text=True,
            )
            # deps.get does not itself invalidate a prior real test run

        elif action is QualificationAction.build_wasm:
            subprocess.run(
                [
                    "cargo",
                    "build",
                    "--release",
                    "--target",
                    "wasm32-unknown-unknown",
                    "-p",
                    "wasm4pm-ex4pm-bindings",
                ],
                cwd=str(self._wasm4pm_root),
                capture_output=True,
                text=True,
            )

        elif action is QualificationAction.start_server:
            self._start_server_background()

        elif action is QualificationAction.run_tests:
            passed, _output = run_mix_test(self._repo_root)
            tests_passing = passed

        return observe_state(
            self._repo_root, self._wasm4pm_root, tests_passing=tests_passing
        )

    def _start_server_background(self, wait_seconds: float = 15.0) -> None:
        """Real, bounded, backgroundable start of `mix phx.server` on
        port 8080, with `stop_server` below as the real way to stop it.

        Uses the one real, found command path for port 8080
        (config/runtime.exs:16 only wires PORT when config_env() == :prod
        or PHX_SERVER is set) -- MIX_ENV=prod, PHX_SERVER=true, PORT=8080,
        and a real 64-character SECRET_KEY_BASE (config/runtime.exs raises
        without one in :prod). This may legitimately fail to bind (e.g.
        missing compiled prod assets) -- that is a real refusal the
        subsequent `check_server_running()` probe will honestly report as
        `server_running=False`, never coerced to True because the command
        was merely launched.
        """
        import secrets

        env = dict(os.environ)
        env["MIX_ENV"] = "prod"
        env["PHX_SERVER"] = "true"
        env["PORT"] = "8080"
        env.setdefault("SECRET_KEY_BASE", secrets.token_hex(32))  # 64 chars
        log_path = self._repo_root / "tools" / ".qualification_server.log"
        with open(log_path, "wb") as log_file:
            proc = subprocess.Popen(
                ["mix", "phx.server"],
                cwd=str(self._repo_root),
                env=env,
                stdout=log_file,
                stderr=subprocess.STDOUT,
            )
        self._server_pid_file = self._repo_root / "tools" / ".qualification_server.pid"
        self._server_pid_file.write_text(str(proc.pid))

        import time as _time

        end = _time.time() + wait_seconds
        while _time.time() < end:
            if check_server_running():
                return
            _time.sleep(0.5)

    def stop_server(self) -> None:
        """Real way to stop the server started by `_start_server_background`."""
        import signal

        pid_file = self._repo_root / "tools" / ".qualification_server.pid"
        if pid_file.is_file():
            try:
                pid = int(pid_file.read_text().strip())
                os.kill(pid, signal.SIGTERM)
            except (OSError, ValueError):
                pass
            finally:
                pid_file.unlink(missing_ok=True)

    def _get_transition_value(
        self,
        memory: D.T_memory[D.T_state],
        action: D.T_agent[D.T_concurrency[D.T_event]],
        next_state: Optional[D.T_state] = None,
    ) -> D.T_agent[Value[D.T_value]]:
        # Unit cost per real action taken; PositiveCosts only requires a
        # strictly-positive cost, not a wall-clock-weighted one.
        return Value(cost=1.0)

    def _is_terminal(self, state: D.T_state) -> D.T_agent[D.T_predicate]:
        return self._is_goal(state)

    # -- Goals ---------------------------------------------------------------

    def _get_goals_(self) -> D.T_agent[Space[D.T_observation]]:
        return ListSpace([GOAL_STATE])

    # -- FullyObservable -------------------------------------------------

    def _get_observation_space_(self) -> D.T_agent[Space[D.T_observation]]:
        return ListSpace(ALL_STATES)


if __name__ == "__main__":
    domain = Ex4pmQualificationDomain()
    state = domain.get_initial_state()
    print("Real initial ex4pm qualification state:", state)
    # Deterministic planning domains are memoryless (see
    # DeterministicTransitions' own docstring in dynamics.py) -- the
    # public, stateful get_applicable_actions() only works after
    # reset()/step(); for a direct look at one explicit state we call the
    # override point directly, same as a solver would for a given state.
    print(
        "Applicable actions from this state:",
        list(domain._get_applicable_actions_from(state).get_elements()),
    )
    print(
        "Applicable actions from the goal state:",
        list(domain._get_applicable_actions_from(GOAL_STATE).get_elements()),
    )
    print("Is goal state a goal?", domain.is_goal(GOAL_STATE))
    print("Is initial state a goal?", domain.is_goal(state))
