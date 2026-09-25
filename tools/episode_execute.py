"""Execute the predicted plan for the ex4pm qualification episode, one real
action at a time, re-observing real state after each step and comparing to
the prediction written by episode_predict.py. Appends results incrementally
to episode-20260903/trajectory.json so partial progress survives a timeout.
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, "/Users/sac/chatman-ecosystem/platform-console/services/autofde-lab/src")
sys.path.insert(0, str(Path(__file__).resolve().parent))

import qualification_domain as qd  # noqa: E402

EX4PM_ROOT = Path("/Users/sac/ex4pm-worktrees/predict-execute-episode-20260903")
WASM4PM_ROOT = Path("/Users/sac/wasm4pm-worktrees/predict-execute-episode-wf10-20260903")
EPISODE_DIR = Path(__file__).resolve().parent / "episode-20260903"
TRAJ_PATH = EPISODE_DIR / "trajectory.json"

ACTION_NAME = sys.argv[1] if len(sys.argv) > 1 else None
if ACTION_NAME is None:
    print("usage: episode_execute.py <materialize_deps|build_wasm|start_server|run_tests>")
    raise SystemExit(2)

action = qd.QualificationAction[ACTION_NAME]
domain = qd.Ex4pmQualificationDomain(repo_root=EX4PM_ROOT, wasm4pm_root=WASM4PM_ROOT)

trajectory = json.loads(TRAJ_PATH.read_text()) if TRAJ_PATH.exists() else {"steps": []}

before = qd.observe_state(
    EX4PM_ROOT,
    WASM4PM_ROOT,
    tests_passing=(trajectory["steps"][-1]["after"]["tests_passing"] if trajectory["steps"] else False),
)

t0 = time.time()
record: dict = {"action": ACTION_NAME, "before": before._asdict()}

if action is qd.QualificationAction.materialize_deps:
    proc = subprocess.run(
        ["mix", "deps.get"], cwd=str(EX4PM_ROOT), capture_output=True, text=True, timeout=580
    )
    record["command"] = "mix deps.get"
    record["returncode"] = proc.returncode
    record["stdout_tail"] = proc.stdout[-4000:]
    record["stderr_tail"] = proc.stderr[-4000:]
    tests_passing = before.tests_passing

elif action is qd.QualificationAction.build_wasm:
    proc = subprocess.run(
        ["cargo", "build", "--release", "--target", "wasm32-unknown-unknown", "-p", "wasm4pm-ex4pm-bindings"],
        cwd=str(WASM4PM_ROOT),
        capture_output=True,
        text=True,
        timeout=580,
    )
    record["command"] = "cargo build --release --target wasm32-unknown-unknown -p wasm4pm-ex4pm-bindings"
    record["returncode"] = proc.returncode
    record["stdout_tail"] = proc.stdout[-4000:]
    record["stderr_tail"] = proc.stderr[-4000:]
    tests_passing = before.tests_passing

elif action is qd.QualificationAction.start_server:
    domain._start_server_background(wait_seconds=25.0)
    log_path = EX4PM_ROOT / "tools" / ".qualification_server.log"
    record["command"] = "MIX_ENV=prod PHX_SERVER=true PORT=8080 mix phx.server (background)"
    record["log_tail"] = log_path.read_text(errors="replace")[-4000:] if log_path.is_file() else None
    record["returncode"] = None
    tests_passing = before.tests_passing

elif action is qd.QualificationAction.run_tests:
    passed, output = qd.run_mix_test(EX4PM_ROOT, timeout=580)
    record["command"] = "mix test --color=false"
    record["returncode"] = 0 if passed else "nonzero_or_error(see_output)"
    record["stdout_tail"] = output[-6000:]
    tests_passing = passed

else:
    raise SystemExit(f"unknown action {ACTION_NAME}")

after = qd.observe_state(EX4PM_ROOT, WASM4PM_ROOT, tests_passing=tests_passing)
record["after"] = after._asdict()
record["wall_seconds"] = round(time.time() - t0, 3)

trajectory["steps"].append(record)
TRAJ_PATH.write_text(json.dumps(trajectory, indent=2))

print(json.dumps(record, indent=2)[:6000])
print("APPENDED", TRAJ_PATH)
