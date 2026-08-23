#!/usr/bin/env python3
"""Extract exactly one ex4pm-plan protocol object from a mixed worker stream."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("raw")
    parser.add_argument("output")
    args = parser.parse_args()

    candidates = []
    for number, line in enumerate(Path(args.raw).read_text().splitlines(), start=1):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("protocol") == "ex4pm-plan/v1":
            candidates.append((number, value))

    if len(candidates) != 1:
        raise SystemExit(
            f"REFUSED: expected exactly one ex4pm-plan/v1 object, observed {len(candidates)}"
        )

    line_number, value = candidates[0]
    Path(args.output).write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n")
    print(json.dumps({"standing": "ALIVE", "protocol_line": line_number}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
