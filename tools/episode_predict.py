"""E1-equivalent solver admission + prediction for the ex4pm qualification episode.

Run BEFORE any action is executed. Writes predict.json to disk.

Solver admission trace (real, this session):
  1. Astar (autofde_lab.hub.solver.astar.astar.Astar) -- import attempted for
     real: raises ModuleNotFoundError: No module named
     'autofde_lab.hub.__autofde_lab_hub_cpp'. The C++ hub extension is not
     built in this checkout (cpp/sdk/* git submodules are not initialized;
     a real `uv sync` attempt this session failed at the CMake configure
     step for exactly this reason -- verified, not assumed). UNSUPPORTED.
  2. SimpleGreedy (autofde_lab.hub.solver.simple_greedy.simple_greedy.SimpleGreedy)
     -- imports for real, and SimpleGreedy.check_domain(Ex4pmQualificationDomain())
     returns True (real call, this session). NOT USED to compute the
     prediction, though: this domain has no simulated/idealized transition
     model -- `_get_next_state` always dispatches a real subprocess (mix
     deps.get / cargo build / mix phx.server / mix test). Calling
     SimpleGreedy's online rollout to "compute a plan" would therefore
     already CONSTITUTE Step 4 (real execution) inside what is supposed to
     be Step 3 (prediction only, nothing executed yet). Rejected for this
     reason, not because it failed.
  3. Fallback used: a simple greedy/BFS planner, hand-implemented below,
     labeled explicitly as such. It searches over the domain's own
     `_applicable(state, action)` precondition predicate (a pure function of
     state -- zero side effects, verified by reading
     tools/qualification_domain.py) plus the effect each action's own name
     denotes (materialize_deps sets deps_materialized True, build_wasm sets
     wasm_built True, start_server sets server_running True, run_tests sets
     tests_passing True) -- exactly the four fields the domain's own
     `observe_state` conjoins into `qualification_complete`. This is a real
     search (breadth-first over the 16-state boolean lattice), not a
     hand-typed plan asserted without derivation.
"""

from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, "/Users/sac/chatman-ecosystem/platform-console/services/autofde-lab/src")
sys.path.insert(0, str(Path(__file__).resolve().parent))

import qualification_domain as qd  # noqa: E402

EX4PM_ROOT = Path("/Users/sac/ex4pm-worktrees/predict-execute-episode-20260903")
WASM4PM_ROOT = Path("/Users/sac/wasm4pm-worktrees/predict-execute-episode-wf10-20260903")


def ideal_effect(state: qd.QualificationState, action: qd.QualificationAction) -> qd.QualificationState:
    """The effect each action's own name denotes -- the idealized model the
    BFS searches over. No subprocess is run to compute this; it is a pure
    function of (state, action)."""
    d, w, s, t, _ = state
    if action is qd.QualificationAction.materialize_deps:
        d = True
    elif action is qd.QualificationAction.build_wasm:
        w = True
    elif action is qd.QualificationAction.start_server:
        s = True
    elif action is qd.QualificationAction.run_tests:
        t = True
    return qd.QualificationState(d, w, s, t, d and w and s and t)


def bfs_plan(domain: qd.Ex4pmQualificationDomain, start: qd.QualificationState, goal: qd.QualificationState):
    """Real breadth-first search over the domain's own declared
    preconditions (`domain._applicable`), using `ideal_effect` above as the
    (side-effect-free) transition model. Returns the list of actions."""
    if start == goal:
        return []
    frontier = deque([start])
    came_from: dict[qd.QualificationState, tuple[qd.QualificationState, qd.QualificationAction]] = {}
    visited = {start}
    while frontier:
        cur = frontier.popleft()
        for action in qd.QualificationAction:
            if not domain._applicable(cur, action):
                continue
            nxt = ideal_effect(cur, action)
            if nxt in visited:
                continue
            visited.add(nxt)
            came_from[nxt] = (cur, action)
            if nxt == goal:
                # reconstruct
                plan = [action]
                node = cur
                while node != start:
                    node, a = came_from[node]
                    plan.append(a)
                plan.reverse()
                return plan
            frontier.append(nxt)
    raise RuntimeError("BFS_NO_PLAN_FOUND")


def main() -> None:
    domain = qd.Ex4pmQualificationDomain(repo_root=EX4PM_ROOT, wasm4pm_root=WASM4PM_ROOT)
    initial_state = domain.get_initial_state()
    goal_state = qd.GOAL_STATE

    astar_admission = {
        "solver": "autofde_lab.hub.solver.astar.astar.Astar",
        "outcome": "UNSUPPORTED",
        "reason": (
            "ModuleNotFoundError: No module named "
            "'autofde_lab.hub.__autofde_lab_hub_cpp' (C++ hub extension not "
            "built in this checkout -- cpp/sdk/* submodules uninitialized; "
            "confirmed this session by a real `uv sync` attempt failing at "
            "CMake configure for the same reason)."
        ),
    }
    simple_greedy_admission = {
        "solver": "autofde_lab.hub.solver.simple_greedy.simple_greedy.SimpleGreedy",
        "outcome": "ADMISSIBLE_BUT_NOT_USED_FOR_PREDICTION",
        "reason": (
            "SimpleGreedy.check_domain(Ex4pmQualificationDomain()) == True "
            "(real call, this session), but this domain's _get_next_state "
            "always dispatches a real subprocess -- an online rollout to "
            "'compute' a plan would already execute Step 4 while still "
            "inside Step 3 (prediction-only). Not used for that reason."
        ),
    }
    fallback_used = {
        "solver": "hand-implemented BFS over domain._applicable (simple greedy fallback, explicitly labeled)",
        "outcome": "SUCCEEDED",
    }

    plan = bfs_plan(domain, initial_state, goal_state)

    # Walk the idealized (side-effect-free) transitions to record the
    # predicted intermediate states, one per action.
    predicted_states = [initial_state]
    cur = initial_state
    for action in plan:
        cur = ideal_effect(cur, action)
        predicted_states.append(cur)

    prediction = {
        "episode_id": "ex4pm-qualification-episode-20260903",
        "domain": "Ex4pmQualificationDomain",
        "ex4pm_root": str(EX4PM_ROOT),
        "wasm4pm_root": str(WASM4PM_ROOT),
        "solver_admission_trace": [astar_admission, simple_greedy_admission, fallback_used],
        "solver_used": fallback_used["solver"],
        "initial_state": initial_state._asdict(),
        "predicted_action_sequence": [a.name for a in plan],
        "predicted_intermediate_states": [s._asdict() for s in predicted_states],
        "predicted_terminal_state": predicted_states[-1]._asdict(),
        "predicted_qualification_standing": (
            "ALIVE (qualification_complete=True, all four preconditions met, "
            "predicted mix test exit code 0)"
            if predicted_states[-1].qualification_complete
            else "PARTIAL_ALIVE (predicted plan does not reach qualification_complete)"
        ),
    }

    out_path = Path(__file__).resolve().parent / "episode-20260903" / "predict.json"
    out_path.write_text(json.dumps(prediction, indent=2, sort_keys=False))
    print(json.dumps(prediction, indent=2))
    print("WROTE", out_path)


if __name__ == "__main__":
    main()
