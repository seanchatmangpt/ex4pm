"""Construct the episode's named initial condition for real: 'server running,
but build/deps stale relative to it'.

Per task instruction: start the real Phoenix server via the domain's own
start_server real command path against the CURRENT (possibly stale)
deps/build state -- materialize_deps and build_wasm are deliberately NOT run
first. Whatever server_running value results (True, or False if the known
prod-mode Igniter.Mix.Task failure reproduces) becomes the real, honestly
reported initial_state for this episode.

This step is a task-mandated *construction* of the named initial condition,
not a predicted/solved action -- it runs before the predict phase, exactly
as the task specifies ("start the server ... then observe the real initial
state"). It calls the domain's real `_get_next_state` for start_server
directly (bypassing `_applicable`'s admission gate only if needed) the same
way the prior episode ran `run_tests` "anyway as an independent, out-of-band
verification (not a domain-admitted action)" when its precondition was
unmet -- documented as such, never silently coerced.
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
WASM4PM_ROOT = Path.home() / "wasm4pm"  # canonical, read-only here (no build_wasm run)
EPISODE_DIR = Path(__file__).resolve().parent / "episode-20260903-server-stale"
OUT_PATH = EPISODE_DIR / "construct_initial.json"

domain = qd.Ex4pmQualificationDomain(repo_root=EX4PM_ROOT, wasm4pm_root=WASM4PM_ROOT)

pre_setup_baseline = domain.get_initial_state()
applicable_before = [
    a.name for a in qd.QualificationAction if domain._applicable(pre_setup_baseline, a)
]
start_server_applicable = domain._applicable(pre_setup_baseline, qd.QualificationAction.start_server)

record: dict = {
    "note": (
        "pre_setup_baseline is the real state observed BEFORE this construction "
        "step -- it is NOT the episode's initial_state (that is post_setup_state "
        "below, per the task's literal instruction to start the server first, "
        "then observe the real initial state)."
    ),
    "pre_setup_baseline": pre_setup_baseline._asdict(),
    "applicable_actions_before": applicable_before,
    "start_server_applicable_before": start_server_applicable,
    "materialize_deps_run": False,
    "build_wasm_run": False,
}

t0 = time.time()
if start_server_applicable:
    domain._start_server_background(wait_seconds=20.0)
    record["dispatch_mode"] = "domain-admitted (deps_materialized was already True; no bypass needed)"
else:
    # Precondition unmet in this real state (deps_materialized False) -- the
    # task explicitly asks us to attempt start_server anyway against the
    # current possibly-stale state without running materialize_deps first,
    # so we call the real effect implementation directly, same as the prior
    # episode's out-of-band run_tests call.
    domain._start_server_background(wait_seconds=20.0)
    record["dispatch_mode"] = "REFUSED-BY-DOMAIN-BUT-RUN-ANYWAY (deps_materialized was False; called _start_server_background directly, out-of-band, per task instruction not to run materialize_deps/build_wasm first)"

record["wall_seconds"] = round(time.time() - t0, 3)

log_path = EX4PM_ROOT / "tools" / ".qualification_server.log"
record["server_log"] = log_path.read_text(errors="replace") if log_path.is_file() else None

pid_path = EX4PM_ROOT / "tools" / ".qualification_server.pid"
record["server_pid_file_present"] = pid_path.is_file()
record["server_pid"] = pid_path.read_text().strip() if pid_path.is_file() else None

post_setup_state = qd.observe_state(EX4PM_ROOT, WASM4PM_ROOT, tests_passing=pre_setup_baseline.tests_passing)
record["post_setup_state"] = post_setup_state._asdict()
record["command"] = "MIX_ENV=prod PHX_SERVER=true PORT=8080 SECRET_KEY_BASE=<random 64 hex> mix phx.server (background, cwd=EX4PM_ROOT)"

EPISODE_DIR.mkdir(parents=True, exist_ok=True)
OUT_PATH.write_text(json.dumps(record, indent=2))
print(json.dumps(record, indent=2))
print("WROTE", OUT_PATH)
