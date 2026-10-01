#!/usr/bin/env python3
"""Inspect unpacked Hex packages as consumer-visible release artifacts."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

VERSION_PATTERNS = [
    re.compile(r'@version\s+"([^"]+)"'),
    re.compile(r'version:\s*"([^"]+)"'),
]
FORBIDDEN_PARTS = {"_build", ".git", ".github", "artifacts", "deps", "priv/plts"}


def project_version(text: str) -> str | None:
    for pattern in VERSION_PATTERNS:
        match = pattern.search(text)
        if match:
            return match.group(1)
    return None


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--version", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    failures: list[str] = []
    mix = root / "mix.exs"
    if not mix.is_file():
        failures.append("package lacks mix.exs")
        version = None
    else:
        version = project_version(mix.read_text())
        if version != args.version:
            failures.append(f"package version {version!r} != {args.version!r}")

    files = sorted(path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file())
    if not any(path.startswith("lib/") for path in files):
        failures.append("package contains no lib/ source")

    for rel in files:
        if any(rel == part or rel.startswith(part + "/") for part in FORBIDDEN_PARTS):
            failures.append(f"forbidden packaged path: {rel}")

    file_hashes = {rel: sha256(root / rel) for rel in files}
    result = {
        "standing": "ALIVE" if not failures else "BUILD_BROKEN",
        "package": args.package,
        "version": version,
        "file_count": len(files),
        "files": file_hashes,
        "failures": failures,
    }
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered)
    print(rendered, end="")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
