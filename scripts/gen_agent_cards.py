#!/usr/bin/env python3
"""Generate v1.0 A2A-style agent cards from ex4pm's public Elixir surface.

Reads lib/ex4pm/**/*.ex, extracts public functions per module, groups them
into capability clusters, and emits one agent card per cluster under
priv/cards/. GENERATED output — do not hand-edit; regenerate with:

    python3 scripts/gen_agent_cards.py
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib" / "ex4pm"
OUT = ROOT / "priv" / "cards"

PROTOCOL_VERSION = "1.0"
AGENT_NAME = "ex4pm"
LAW = (
    "BRCE.execute/4 is the exclusive receipted-DO boundary; "
    "receipt proves admission, never authority"
)

# cluster -> rel-path prefixes under lib/ex4pm/
CLUSTERS = {
    "evidence": ["evidence.ex", "evidence/"],
    "ocel": ["ocel.ex", "ocel2.ex", "ocel_writer.ex", "xes.ex", "powl.ex", "domain/"],
    "engine": ["engine.ex", "engine/"],
    "information": ["information.ex", "information/"],
    "runtime": ["runtime.ex", "runtime/"],
    "stream": ["stream.ex", "stream/"],
    "qualification": ["qualification.ex", "qualification/"],
    "explore": ["explore.ex", "explore/"],
    "core": ["core.ex", "core/", "contracts.ex", "standing_coded.ex", "economic_isa.ex",
             "gall.ex", "aloop.ex", "reactor.ex", "cli.ex", "application.ex"],
}

MODULE_RE = re.compile(r"^\s*defmodule\s+([A-Za-z0-9_.]+)\s+do\b")
DEF_RE = re.compile(
    r"^\s*def(p)?\s+([a-z_][a-zA-Z0-9_?!]*)(\([^)]*\))?\s*(?:,[^=]*=.*|do|:)?\s*$"
)
SKIP_NAMES = {
    "init", "start_link", "handle_call", "handle_cast", "handle_info",
    "handle_demand", "handle_continue", "child_spec",
}


def rel_key(path: Path) -> str:
    return str(path.relative_to(LIB))


def cluster_for(rel: str):
    for cluster in sorted(CLUSTERS):
        for prefix in CLUSTERS[cluster]:
            if rel == prefix or rel.startswith(prefix):
                return cluster
    return None


def parse_file(path: Path):
    """Return [(module, [function names])] preserving file order."""
    modules = []
    current = None
    depth = 0
    for line in path.read_text(errors="replace").splitlines():
        m = MODULE_RE.match(line)
        d = DEF_RE.match(line)
        if m:
            current = {"module": m.group(1), "functions": []}
            modules.append(current)
            depth += 1
            continue
        if d and current is not None:
            if d.group(1):  # defp
                continue
            fname = d.group(2)
            if fname in SKIP_NAMES:
                continue
            if fname not in current["functions"]:
                current["functions"].append(fname)
        if line.strip().endswith("end") and current is not module_at(modules, -1):
            pass  # depth tracking via 'end' is heuristic; module span not needed
    return modules


def module_at(modules, idx):
    return None


def collect():
    files = sorted(p for p in LIB.rglob("*.ex") if cluster_for(rel_key(p)))
    clusters = {}
    for f in files:
        rel = rel_key(f)
        cluster = cluster_for(rel)
        mods = parse_file(f)
        for mod in mods:
            if not mod["functions"]:
                continue
            clusters.setdefault(cluster, []).append(
                {"module": mod["module"], "functions": mod["functions"], "source": f"lib/ex4pm/{rel}"}
            )
    for cluster in clusters:
        clusters[cluster].sort(key=lambda m: m["module"])
    return clusters


def skill_id(cluster, fname):
    verb = fname.replace("_", "-")
    return f"ex4pm.{cluster}.{verb}"


def make_skills(cluster, modules):
    skills = []
    seen = set()
    for mod in modules:
        for fname in mod["functions"]:
            sid = skill_id(cluster, fname)
            if sid in seen:
                continue
            seen.add(sid)
            desc = f"{mod['module']}.{fname} — {LAW}"
            skills.append({
                "id": sid,
                "name": fname,
                "description": desc,
                "source_module": mod["module"],
                "source_file": mod["source"],
            })
    skills.sort(key=lambda s: s["id"])
    return skills


def make_card(cluster, modules):
    skills = make_skills(cluster, modules)
    return {
        "protocolVersion": PROTOCOL_VERSION,
        "id": f"ex4pm.{cluster}",
        "name": f"ex4pm {cluster} capability card",
        "description": LAW,
        "generatedFrom": "lib/ex4pm",
        "generator": "scripts/gen_agent_cards.py",
        "capabilities": {
            "streaming": False,
            "receiptedExecution": cluster == "evidence",
            "authorityLaw": LAW,
        },
        "skills": skills,
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    clusters = collect()
    for cluster in sorted(clusters):
        card = make_card(cluster, clusters[cluster])
        out = OUT / f"{cluster}.json"
        out.write_text(json.dumps(card, indent=2, sort_keys=True) + "\n")
    # generated README
    total = sum(len(c) for c in clusters.values())
    lines = [
        "# ex4pm Agent Cards (GENERATED)",
        "",
        f"One v1.0 capability card per capability cluster ({len(clusters)} clusters, "
        f"{total} public functions).",
        "",
        "All descriptions carry the authority law verbatim:",
        "",
        "> BRCE.execute/4 is the exclusive receipted-DO boundary; receipt proves admission, never authority",
        "",
        "## Regenerate",
        "",
        "```sh",
        "python3 scripts/gen_agent_cards.py",
        "```",
        "",
        "Do not hand-edit priv/cards/ — edit lib/ex4pm and regenerate.",
        "",
        "| card | file | skills |",
        "|---|---|---|",
    ]
    for cluster in sorted(clusters):
        n = sum(len(m["functions"]) for m in clusters[cluster])
        lines.append(f"| ex4pm.{cluster} | priv/cards/{cluster}.json | {n} |")
    (OUT / "README.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {len(clusters)} cards, {total} skills -> {OUT}")


if __name__ == "__main__":
    main()
