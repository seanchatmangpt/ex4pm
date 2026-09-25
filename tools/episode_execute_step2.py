"""Execute step 2 (run_tests) of the server-stale episode for real, and
assemble trajectory.json (step 1 = the start_server construction step already
recorded in construct_initial.json; step 2 = this run_tests execution).
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, "/Users/sac/chatman-ecosystem/platform-console/services/autofde-lab/src")
sys.path.insert(0, str(Path(__file__).resolve().parent))

import qualification_domain as qd  # noqa: E402

EX4PM_ROOT = Path("/Users/sac/ex4pm-worktrees/qualification-domain")
WASM4PM_ROOT = Path.home() / "wasm4pm"
EPISODE_DIR = Path(__file__).resolve().parent / "episode-20260903-server-stale"
CONSTRUCT_PATH = EPISODE_DIR / "construct_initial.json"
TRAJ_PATH = EPISODE_DIR / "trajectory.json"

construct = json.loads(CONSTRUCT_PATH.read_text())

step1 = {
    "step": 1,
    "action": "start_server",
    "kind": "episode-defining construction action (task-mandated: run first, against current un-refreshed deps/build state, before observing/deriving this episode's initial_state)",
    "command": construct["command"],
    "returncode": None,
    "outcome": "ATTEMPTED_BUT_FAILED (real subprocess launched; not a domain-precondition refusal -- deps_materialized was True so the action was domain-admitted -- but the real `mix phx.server` process itself crashed on a real compile error before binding port 8080)",
    "failure_detail": construct["process_outcome"],
    "server_log_full": construct["server_log_full"],
    "wall_seconds": construct["wall_seconds_first_probe"],
    "observed_after": construct["final_settled_state"],
}

before2 = qd.observe_state(EX4PM_ROOT, WASM4PM_ROOT, tests_passing=step1["observed_after"]["tests_passing"])
assert before2._asdict() == step1["observed_after"], (before2._asdict(), step1["observed_after"])

t0 = time.time()
passed, output = qd.run_mix_test(EX4PM_ROOT, timeout=1800.0)
wall = round(time.time() - t0, 3)

after2 = qd.observe_state(EX4PM_ROOT, WASM4PM_ROOT, tests_passing=passed)

step2 = {
    "step": 2,
    "action": "run_tests",
    "kind": "predicted plan action, executed for real",
    "command": "mix test --color=false",
    "returncode": 0 if passed else "nonzero_or_error(see stdout_tail)",
    "stdout_tail": output[-8000:],
    "wall_seconds": wall,
    "before": before2._asdict(),
    "observed_after": after2._asdict(),
}

trajectory = {"steps": [step1, step2]}
TRAJ_PATH.write_text(json.dumps(trajectory, indent=2))
print(json.dumps(step2, indent=2)[:4000])
print("WROTE", TRAJ_PATH)
