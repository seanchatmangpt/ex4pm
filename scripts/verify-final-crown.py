#!/usr/bin/env python3
"""Independent v26.8.22 crown verifier.

This program intentionally does not import ex4pm. It recomputes standing from
Git identity and evidence bytes and emits ALIVE only when every required court
is independently evidenced.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import sys
from typing import Any

REQUIRED_RAILS = {"beam", "ex4pm_plan", "wasm", "nif", "remote"}
REQUIRED_SABOTAGE = {
    "source_mutation",
    "tree_mutation",
    "subject_hash_mutation",
    "result_mutation",
    "receipt_mutation",
    "replay_mutation",
    "unreceipted_do",
    "unauthorized_retry",
    "wasm_artifact_mutation",
    "nif_artifact_mutation",
    "oci_image_mutation",
    "certificate_mutation",
    "erts_mutation",
    "powl_extra_trace",
    "powl_missing_trace",
    "powl_wrong_order",
    "powl_duplicate_identity",
    "distributed_identity_mutation",
    "ci_subject_mutation",
}


def fail(message: str) -> None:
    raise ValueError(message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_hash(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256_bytes(payload.encode("utf-8"))


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def within(root: pathlib.Path, raw: str) -> pathlib.Path:
    path = (root / raw).resolve()
    try:
        path.relative_to(root.resolve())
    except ValueError as exc:
        raise ValueError(f"evidence path escapes root: {raw}") from exc
    if not path.is_file():
        fail(f"missing evidence file: {raw}")
    return path


def verify_file(root: pathlib.Path, entry: dict[str, Any], label: str) -> pathlib.Path:
    raw = entry.get("path")
    expected = entry.get("sha256")
    if not isinstance(raw, str) or not isinstance(expected, str) or len(expected) != 64:
        fail(f"{label}: invalid path/sha256 manifest")
    path = within(root, raw)
    observed = sha256_file(path)
    if observed != expected:
        fail(f"{label}: digest mismatch expected={expected} observed={observed}")
    return path


def load_verified_json(root: pathlib.Path, entry: dict[str, Any], label: str) -> dict[str, Any]:
    path = verify_file(root, entry, label)
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        fail(f"{label}: JSON evidence must be an object")
    return value


def verify_identity(crown: dict[str, Any], expected_source: str | None, expected_tree: str | None) -> dict[str, str]:
    source = crown.get("source_sha")
    tree = crown.get("tree_sha")
    if not isinstance(source, str) or len(source) != 40:
        fail("invalid source_sha")
    if not isinstance(tree, str) or len(tree) != 40:
        fail("invalid tree_sha")

    observed_source = git("rev-parse", "HEAD")
    observed_tree = git("rev-parse", "HEAD^{tree}")
    if source != observed_source:
        fail(f"source identity mismatch crown={source} git={observed_source}")
    if tree != observed_tree:
        fail(f"tree identity mismatch crown={tree} git={observed_tree}")
    if expected_source and source != expected_source:
        fail(f"source differs from admitted release subject: {expected_source}")
    if expected_tree and tree != expected_tree:
        fail(f"tree differs from admitted release tree: {expected_tree}")
    return {"source_sha": source, "tree_sha": tree}


def verify_powl(crown: dict[str, Any]) -> dict[str, Any]:
    powl = crown.get("powl")
    if not isinstance(powl, dict):
        fail("missing powl evidence")
    for field in ("soundness", "completeness", "correspondence", "compiler_refinement", "formal_proof"):
        if powl.get(field) is not True:
            fail(f"POWL {field} not proven")
    if int(powl.get("generated_cases", 0)) < 2048:
        fail("POWL generated corpus is below 2048 cases")
    if int(powl.get("reactor_samples", 0)) < 64:
        fail("POWL Reactor refinement sample is below 64 cases")
    return powl


def verify_rails(root: pathlib.Path, crown: dict[str, Any]) -> dict[str, Any]:
    rails = crown.get("rails")
    if not isinstance(rails, dict) or set(rails) != REQUIRED_RAILS:
        fail(f"rail identity set must be exactly {sorted(REQUIRED_RAILS)}")

    result_hashes: dict[str, str] = {}
    for rail in sorted(REQUIRED_RAILS):
        entry = rails[rail]
        if not isinstance(entry, dict) or entry.get("standing") != "ALIVE":
            fail(f"rail {rail} did not earn ALIVE")
        artifact = entry.get("artifact")
        result = entry.get("result")
        if not isinstance(artifact, dict) or not isinstance(result, dict):
            fail(f"rail {rail} lacks artifact/result manifests")
        verify_file(root, artifact, f"rail {rail} artifact")
        result_json = load_verified_json(root, result, f"rail {rail} result")
        observed_hash = canonical_hash(result_json)
        if entry.get("result_hash") != observed_hash:
            fail(f"rail {rail} normalized result hash mismatch")
        if result_json.get("standing") != "ALIVE":
            fail(f"rail {rail} result bytes do not state ALIVE")
        result_hashes[rail] = observed_hash

    # Differential groups are explicit capability-indexed equivalence classes.
    groups = crown.get("rail_differential_groups")
    if not isinstance(groups, list) or not groups:
        fail("missing capability-indexed differential groups")
    for group in groups:
        if not isinstance(group, dict):
            fail("invalid differential group")
        members = group.get("rails")
        if not isinstance(members, list) or not members:
            fail("differential group has no rails")
        hashes = [result_hashes[m] for m in members if m in result_hashes]
        if len(hashes) != len(members):
            fail("differential group contains unknown rail")
        if len(set(hashes)) != 1:
            fail(f"capability differential mismatch for {group.get('operation')}")
    return {"rails": sorted(result_hashes), "result_hashes": result_hashes}


def verify_commands(root: pathlib.Path, crown: dict[str, Any]) -> list[str]:
    commands = crown.get("commands")
    if not isinstance(commands, list) or not commands:
        fail("missing command evidence")
    verified: list[str] = []
    for index, entry in enumerate(commands):
        if not isinstance(entry, dict) or entry.get("exit") != 0:
            fail(f"command {index} has non-zero/missing exit")
        log = entry.get("log")
        if not isinstance(log, dict):
            fail(f"command {index} lacks log manifest")
        verify_file(root, log, f"command {index} log")
        command = entry.get("command")
        if not isinstance(command, str) or not command:
            fail(f"command {index} lacks command identity")
        verified.append(command)
    return verified


def verify_receipts(root: pathlib.Path, crown: dict[str, Any]) -> int:
    receipts = crown.get("receipt_replays")
    if not isinstance(receipts, list) or not receipts:
        fail("missing replay evidence")
    for index, entry in enumerate(receipts):
        if not isinstance(entry, dict):
            fail(f"invalid receipt replay {index}")
        evidence = load_verified_json(root, entry, f"receipt replay {index}")
        if evidence.get("replay") != "chain_match":
            fail(f"receipt replay {index} is not chain_match")
        if evidence.get("retry_authority") not in (None, "none"):
            fail(f"receipt replay {index} grants retry authority")
    return len(receipts)


def verify_global(root: pathlib.Path, crown: dict[str, Any], source_sha: str) -> dict[str, Any]:
    global_evidence = crown.get("global")
    if not isinstance(global_evidence, dict):
        fail("missing global evidence")
    for field in (
        "tls_verified",
        "pre_do_refusal",
        "during_do_ambiguous",
        "no_duplicate_do",
        "mixed_version_refused",
        "clock_skew_safe",
    ):
        if global_evidence.get(field) is not True:
            fail(f"global invariant {field} not proven")

    manifests = global_evidence.get("attestations")
    if not isinstance(manifests, list) or len(manifests) < 5:
        fail("fewer than five topology attestations")

    hosts: set[str] = set()
    regions: set[str] = set()
    domains: set[str] = set()
    fingerprints: set[str] = set()
    providers: set[str] = set()
    for index, manifest in enumerate(manifests):
        if not isinstance(manifest, dict):
            fail(f"invalid topology manifest {index}")
        att = load_verified_json(root, manifest, f"topology attestation {index}")
        for key in ("provider", "host_id", "region", "fault_domain", "release_digest", "cert_fingerprint"):
            if not isinstance(att.get(key), str) or not att[key]:
                fail(f"topology attestation {index} lacks {key}")
        if att.get("source_sha") != source_sha:
            fail(f"topology attestation {index} is for wrong source")
        hosts.add(att["host_id"])
        regions.add(att["region"])
        domains.add(att["fault_domain"])
        fingerprints.add(att["cert_fingerprint"])
        providers.add(att["provider"])

    if len(hosts) < 5:
        fail("global court lacks five unique hosts")
    if len(regions) < 2:
        fail("global court lacks two unique regions")
    if len(domains) < 3:
        fail("global court lacks three unique failure domains")
    if len(fingerprints) < 5:
        fail("TLS identity is not host-specific")
    return {
        "hosts": len(hosts),
        "regions": sorted(regions),
        "fault_domains": sorted(domains),
        "providers": sorted(providers),
    }


def verify_sabotage(crown: dict[str, Any]) -> int:
    sabotage = crown.get("sabotage")
    if not isinstance(sabotage, dict):
        fail("missing sabotage ledger")
    missing = REQUIRED_SABOTAGE - set(sabotage)
    if missing:
        fail(f"missing sabotage cases: {sorted(missing)}")
    survived = sorted(name for name, result in sabotage.items() if result != "DETECTED")
    if survived:
        fail(f"sabotage survived: {survived}")
    return len(sabotage)


def verify(crown_path: pathlib.Path, root: pathlib.Path, expected_source: str | None, expected_tree: str | None) -> dict[str, Any]:
    crown = json.loads(crown_path.read_text())
    if not isinstance(crown, dict):
        fail("crown must be a JSON object")

    identity = verify_identity(crown, expected_source, expected_tree)
    powl = verify_powl(crown)
    rails = verify_rails(root, crown)
    commands = verify_commands(root, crown)
    replays = verify_receipts(root, crown)
    global_result = verify_global(root, crown, identity["source_sha"])
    sabotage_cases = verify_sabotage(crown)

    unsigned = dict(crown)
    unsigned.pop("standing", None)
    supplied_hash = unsigned.pop("evidence_hash", None)
    observed_hash = canonical_hash(unsigned)
    if supplied_hash is not None and supplied_hash != observed_hash:
        fail("crown evidence_hash does not match recomputed canonical evidence")

    return {
        "standing": "ALIVE",
        "source_sha": identity["source_sha"],
        "tree_sha": identity["tree_sha"],
        "evidence_hash": observed_hash,
        "powl_cases": int(powl["generated_cases"]),
        "rail_evidence": rails,
        "commands": commands,
        "receipt_replays": replays,
        "global": global_result,
        "sabotage_cases": sabotage_cases,
        "verifier": "scripts/verify-final-crown.py",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("crown")
    parser.add_argument("--evidence-root", default=".")
    parser.add_argument("--expected-source", default=os.environ.get("EX4PM_SUBJECT_SHA"))
    parser.add_argument("--expected-tree", default=os.environ.get("EX4PM_SUBJECT_TREE"))
    parser.add_argument("--output")
    args = parser.parse_args()

    try:
        result = verify(
            pathlib.Path(args.crown).resolve(),
            pathlib.Path(args.evidence_root).resolve(),
            args.expected_source,
            args.expected_tree,
        )
    except Exception as exc:
        print(json.dumps({"standing": "PARTIAL_ALIVE", "error": str(exc)}, sort_keys=True), file=sys.stderr)
        return 1

    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        pathlib.Path(args.output).write_text(rendered)
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
