"""Real predict/execute/observe episode harness -- 4th episode, this session.

Initial condition assigned: "all prerequisites present, control episode".

Domain: /Users/sac/ex4pm-worktrees/qualification-domain/tools/qualification_domain.py
(the EXISTING, already-working Ex4pmQualificationDomain from this session -- reused
as-is, not re-derived, per task instruction). Adapted from this session's own
scratchpad/episode_lib.py harness (used for the prior "deps materialized, wasm
absent, server absent" episode), corrected to:
  - AUTOFDE_LAB_ROOT -> the real, present checkout
    /Users/sac/chatman-ecosystem/platform-console/services/autofde-lab (has a
    working .venv; the sibling worktree path baked into the prior episode_lib.py
    no longer resolved from this subagent's cwd).
  - WASM4PM_ROOT -> left at the domain's own default (~/wasm4pm, the shared
    checkout) rather than a fresh worktree, because THIS episode's assigned
    initial condition requires wasm_built already True (a prerequisite already
    present), not absent.
No materialize_deps / build_wasm actions are used -- both preconditions are
already real-True in the shared EX4PM_ROOT worktree, confirmed by direct
observation before running anything (see initial_state.json).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

EX4PM_ROOT = Path("/Users/sac/ex4pm-worktrees/qualification-domain")
AUTOFDE_LAB_ROOT = Path(
    "/Users/sac/chatman-ecosystem/platform-console/services/autofde-lab"
)

os.environ["EX4PM_ROOT"] = str(EX4PM_ROOT)
os.environ["AUTOFDE_LAB_ROOT"] = str(AUTOFDE_LAB_ROOT)
# WASM4PM_ROOT intentionally left unset -> domain default (~/wasm4pm)

sys.path.insert(0, str(EX4PM_ROOT / "tools"))
import qualification_domain as qd  # noqa: E402


def state_to_dict(s: "qd.QualificationState") -> dict:
    return dict(s._asdict())


class IdealizedD(qd.Ex4pmQualificationDomain):
    """Prediction-only shadow domain: real initial observation, STRIPS-assumed
    (no-side-effect) transition. Never used for execution."""

    def _get_next_state(self, memory, action):  # type: ignore[override]
        d, w, srv, t = (
            memory.deps_materialized,
            memory.wasm_built,
            memory.server_running,
            memory.tests_passing,
        )
        if action is qd.QualificationAction.materialize_deps:
            d = True
        elif action is qd.QualificationAction.build_wasm:
            w = True
        elif action is qd.QualificationAction.start_server:
            srv = True
        elif action is qd.QualificationAction.run_tests:
            t = True
        return qd.QualificationState(d, w, srv, t, d and w and srv and t)


def try_import_astar() -> tuple[bool, str]:
    try:
        from autofde_lab.hub.solver.astar.astar import Astar  # noqa: F401

        return True, "import OK"
    except Exception as exc:  # noqa: BLE001
        return False, repr(exc)


def predict_plan_with_simple_greedy(initial_state) -> dict:
    from autofde_lab.hub.solver.simple_greedy.simple_greedy import SimpleGreedy

    domain = IdealizedD(repo_root=EX4PM_ROOT)
    solver = SimpleGreedy(domain_factory=lambda: domain)
    solver.solve()

    state = initial_state
    plan: list[dict] = []
    states: list[dict] = [state_to_dict(state)]
    max_steps = 10
    for _ in range(max_steps):
        if domain.is_goal(state):
            break
        # domain=None (not the explicit shadow instance) -- passing an explicit
        # domain here re-applies autocast on top of one already applied by
        # solve(), which for a NamedTuple T_state unwraps it to its first field
        # (documented gotcha in simple_greedy.py; hit and fixed in the prior
        # "deps materialized, wasm absent" episode this session).
        action_list = solver._get_next_action(state)
        action = action_list[0] if isinstance(action_list, list) else action_list
        next_state = domain._get_next_state(state, action)
        plan.append({"action": action.name, "cost": 1.0})
        states.append(state_to_dict(next_state))
        state = next_state
    return {
        "solver": "SimpleGreedy (real autofde_lab.hub.solver.simple_greedy.SimpleGreedy, rolled out against an IdealizedD side-effect-free shadow domain for prediction only)",
        "predicted_plan": plan,
        "predicted_states": states,
        "predicted_terminal_qualification_complete": state.qualification_complete,
    }


def real_domain():
    return qd.Ex4pmQualificationDomain(repo_root=EX4PM_ROOT)


def observe_now(tests_passing: bool) -> dict:
    s = qd.observe_state(EX4PM_ROOT, real_domain()._wasm4pm_root, tests_passing=tests_passing)
    return state_to_dict(s)


def run_mix_test_with_exit_code() -> dict:
    t0 = time.time()
    try:
        result = subprocess.run(
            ["mix", "test", "--color=false"],
            cwd=str(EX4PM_ROOT),
            capture_output=True,
            text=True,
            timeout=1800,
        )
        return {
            "returncode": result.returncode,
            "wall_seconds": time.time() - t0,
            "stdout_tail": result.stdout[-4000:],
            "stderr_tail": result.stderr[-4000:],
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "returncode": None,
            "wall_seconds": time.time() - t0,
            "error": repr(exc),
        }


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "initial_state":
        d = real_domain()
        s = d.get_initial_state()
        print(json.dumps(state_to_dict(s), indent=2))
    elif cmd == "predict":
        d = real_domain()
        s = d.get_initial_state()
        astar_ok, astar_err = try_import_astar()
        pred = predict_plan_with_simple_greedy(s)
        pred["astar_import_ok"] = astar_ok
        pred["astar_import_error"] = astar_err
        pred["real_initial_state"] = state_to_dict(s)
        print(json.dumps(pred, indent=2))
    elif cmd == "observe":
        tp = sys.argv[2] == "true" if len(sys.argv) > 2 else False
        print(json.dumps(observe_now(tp), indent=2))
    elif cmd == "step":
        action_name = sys.argv[2]
        action = qd.QualificationAction[action_name]
        d = real_domain()
        cur = json.loads(sys.argv[3])
        memory = qd.QualificationState(**cur)
        t0 = time.time()
        applicable = d._applicable(memory, action)
        next_state = d._get_next_state(memory, action)
        wall = time.time() - t0
        print(
            json.dumps(
                {
                    "action": action_name,
                    "was_applicable_precondition": applicable,
                    "before": state_to_dict(memory),
                    "after": state_to_dict(next_state),
                    "wall_seconds": wall,
                },
                indent=2,
            )
        )
    elif cmd == "mix_test_exit_code":
        print(json.dumps(run_mix_test_with_exit_code(), indent=2))
    elif cmd == "stop_server":
        d = real_domain()
        d.stop_server()
        print("stopped (if it was running)")
    else:
        print("usage: episode_lib_control.py {initial_state|predict|observe|step|mix_test_exit_code|stop_server}")
