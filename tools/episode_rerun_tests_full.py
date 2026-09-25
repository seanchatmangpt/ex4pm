"""Re-run `mix test` once more for this same episode, purely to capture the
FULL output (real returncode + real full log) to disk as evidence, since the
first run's trajectory.json only retained the last 8000 chars of output and
did not show the final summary line. Does not change any domain state
field beyond what step 2 already established (tests_passing was already
observed False from the first run's real exit code)."""

from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

EX4PM_ROOT = Path("/Users/sac/ex4pm-worktrees/qualification-domain")
EPISODE_DIR = Path(__file__).resolve().parent / "episode-20260903-server-stale"
LOG_PATH = EPISODE_DIR / "run_tests_full_output.log"

t0 = time.time()
result = subprocess.run(
    ["mix", "test", "--color=false"],
    cwd=str(EX4PM_ROOT),
    capture_output=True,
    text=True,
    timeout=1800,
)
wall = time.time() - t0
combined = result.stdout + result.stderr
LOG_PATH.write_text(combined)
print("returncode:", result.returncode)
print("wall_seconds:", round(wall, 3))
print("--- last 3000 chars ---")
print(combined[-3000:])
print("WROTE", LOG_PATH)
