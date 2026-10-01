#!/usr/bin/env python3
"""Verify externally observed Fly machine topology without granting provisioning authority."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def field(machine: dict[str, Any], name: str) -> Any:
    if name in machine:
        return machine[name]
    config = machine.get("config") if isinstance(machine.get("config"), dict) else {}
    metadata = config.get("metadata") if isinstance(config.get("metadata"), dict) else {}
    if name in metadata:
        return metadata[name]
    top_metadata = machine.get("metadata") if isinstance(machine.get("metadata"), dict) else {}
    return top_metadata.get(name)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("machines_json")
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    raw = json.loads(Path(args.machines_json).read_text())
    machines = raw.get("machines", raw) if isinstance(raw, dict) else raw
    if not isinstance(machines, list):
        raise SystemExit("machine evidence is not a list")

    attestations: list[dict[str, Any]] = []
    errors: list[str] = []

    for index, machine in enumerate(machines):
        if not isinstance(machine, dict):
            errors.append(f"machine[{index}] is not an object")
            continue

        host_id = field(machine, "id")
        region = field(machine, "region")
        fault_domain = field(machine, "fault_domain")
        release_digest = field(machine, "ex4pm_release_digest")
        source_sha = field(machine, "ex4pm_source_sha")
        cert_fingerprint = field(machine, "cert_fingerprint")
        state = field(machine, "state")

        required = {
            "host_id": host_id,
            "region": region,
            "fault_domain": fault_domain,
            "release_digest": release_digest,
            "source_sha": source_sha,
            "cert_fingerprint": cert_fingerprint,
        }
        missing = [name for name, value in required.items() if not isinstance(value, str) or not value]
        if missing:
            errors.append(f"machine[{index}] missing independently required metadata: {missing}")
            continue
        if source_sha != args.source_sha:
            errors.append(f"machine[{index}] source mismatch: {source_sha}")
            continue

        observation = {
            "provider": "fly.io",
            "host_id": host_id,
            "region": region,
            "fault_domain": fault_domain,
            "release_digest": release_digest,
            "source_sha": source_sha,
            "cert_fingerprint": cert_fingerprint,
            "state": state,
        }
        observation["observation_digest"] = sha256_bytes(
            json.dumps(observation, sort_keys=True, separators=(",", ":")).encode()
        )
        attestations.append(observation)

    hosts = {att["host_id"] for att in attestations}
    regions = {att["region"] for att in attestations}
    domains = {att["fault_domain"] for att in attestations}
    certs = {att["cert_fingerprint"] for att in attestations}

    if len(hosts) < 5:
        errors.append(f"requires 5 unique hosts, observed {len(hosts)}")
    if len(regions) < 2:
        errors.append(f"requires 2 regions, observed {len(regions)}")
    if len(domains) < 3:
        errors.append(f"requires 3 independently attested failure domains, observed {len(domains)}")
    if len(certs) < 5:
        errors.append(f"requires host-specific certificate identities, observed {len(certs)}")

    output = Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    for att in attestations:
        path = output / f"{att['host_id']}.json"
        path.write_text(json.dumps(att, indent=2, sort_keys=True) + "\n")

    summary = {
        "standing": "ALIVE" if not errors else "PARTIAL_ALIVE",
        "source_sha": args.source_sha,
        "hosts": sorted(hosts),
        "regions": sorted(regions),
        "fault_domains": sorted(domains),
        "certificate_identities": len(certs),
        "errors": errors,
    }
    (output / "topology-summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
