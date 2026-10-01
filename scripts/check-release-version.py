#!/usr/bin/env python3
"""Fail closed when the dated ex4pm release graph contains mixed versions."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

MIX_PROJECTS = [
    Path("mix.exs"),
    Path("apps/ex4pm/mix.exs"),
    Path("apps/ex4pm_cli/mix.exs"),
    Path("apps/ex4pm_contracts/mix.exs"),
    Path("apps/ex4pm_core/mix.exs"),
    Path("apps/ex4pm_domain/mix.exs"),
    Path("apps/ex4pm_engine/mix.exs"),
    Path("apps/ex4pm_evidence/mix.exs"),
    Path("apps/ex4pm_information/mix.exs"),
    Path("apps/ex4pm_qualification/mix.exs"),
    Path("apps/ex4pm_runtime/mix.exs"),
    Path("apps/ex4pm_stream/mix.exs"),
    Path("apps/ex4pm_web/mix.exs"),
]

CARGO_PROJECTS = [
    Path("qualification/reference-nif/Cargo.toml"),
    Path("qualification/reference-wasm/Cargo.toml"),
]

VERSION_PATTERNS = [
    re.compile(r'@version\s+"([^"]+)"'),
    re.compile(r'version:\s*"([^"]+)"'),
]
INTERNAL_DEP = re.compile(r'\{:ex4pm(?:_[a-z0-9_]+)?,\s*"~>\s*([0-9]+\.[0-9]+\.[0-9]+)"')
CARGO_VERSION = re.compile(r'^version\s*=\s*"([^"]+)"', re.MULTILINE)


def mix_version(text: str) -> str | None:
    for pattern in VERSION_PATTERNS:
        match = pattern.search(text)
        if match:
            return match.group(1)
    return None


def main() -> int:
    expected = sys.argv[1] if len(sys.argv) > 1 else "26.8.23"
    failures: list[str] = []
    observed: dict[str, str] = {}

    for path in MIX_PROJECTS:
        if not path.is_file():
            failures.append(f"missing Mix project: {path}")
            continue
        text = path.read_text()
        version = mix_version(text)
        observed[str(path)] = version or "MISSING"
        if version != expected:
            failures.append(f"{path}: project version {version!r} != {expected!r}")
        for dependency_version in INTERNAL_DEP.findall(text):
            if dependency_version != expected:
                failures.append(
                    f"{path}: internal ex4pm dependency {dependency_version!r} != {expected!r}"
                )

    for path in CARGO_PROJECTS:
        if not path.is_file():
            failures.append(f"missing Cargo project: {path}")
            continue
        match = CARGO_VERSION.search(path.read_text())
        version = match.group(1) if match else None
        observed[str(path)] = version or "MISSING"
        if version != expected:
            failures.append(f"{path}: Cargo version {version!r} != {expected!r}")

    result = {
        "standing": "ALIVE" if not failures else "BUILD_BROKEN",
        "expected": expected,
        "observed": observed,
        "failures": failures,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
