#!/usr/bin/env python3
"""Emit one receipted verification observation as admitted OCEL-shaped JSON.

The relay is store-and-forward by construction: it always writes an atomic local
spool artifact first, then optionally POSTs the exact same bytes when an
OCEL_INGEST_URL is configured. External transport never changes the observation
identity or receipt binding.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
from datetime import datetime, timezone
from urllib import request as urllib_request
from urllib.parse import urlparse

STANDINGS = {
    "UNKNOWN",
    "PARTIAL_ALIVE",
    "ALIVE",
    "BLOCKED",
    "BUILD_BROKEN",
    "UNSUPPORTED",
    "REFUSED",
}
AUTHORITY_DOMAINS = {"OBSERVE", "SELECT", "CONSTRUCT", "VERIFY", "DO"}
REPOSITORY_RE = re.compile(r"^[^/\s]+/[^/\s]+$")
SHA_RE = re.compile(r"^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Emit a receipt-bound OCEL verification observation"
    )
    parser.add_argument("--activity", required=True)
    parser.add_argument("--standing", required=True, choices=sorted(STANDINGS))
    parser.add_argument(
        "--authority-domain", required=True, choices=sorted(AUTHORITY_DOMAINS)
    )
    parser.add_argument("--agent-id", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--sequence", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def require_nonempty(name: str, value: str) -> str:
    value = value.strip()
    if not value:
        raise SystemExit(f"{name} must be non-empty")
    return value


def load_and_admit_receipt(path: Path, expected_sha: str, expected_standing: str):
    if not path.is_file():
        raise SystemExit(f"receipt is not a regular file: {path}")

    raw = path.read_bytes()
    try:
        receipt = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SystemExit(f"receipt is not valid JSON: {error}") from error

    if not isinstance(receipt, dict):
        raise SystemExit("receipt root must be a JSON object")
    if receipt.get("subject_sha") != expected_sha:
        raise SystemExit(
            "receipt subject_sha does not correspond to the admitted source SHA"
        )
    if receipt.get("standing") != expected_standing:
        raise SystemExit(
            "receipt standing does not correspond to the emitted observation standing"
        )
    if receipt.get("exit_codes", {}).get("mix_verify") != 0:
        raise SystemExit("receipt does not prove a zero-exit mix verify crown")

    return receipt, raw, hashlib.sha256(raw).hexdigest()


def canonical_digest(value: dict) -> str:
    encoded = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def build_ocel(args: argparse.Namespace, receipt_digest: str) -> dict:
    subject_id = f"github:{args.repo}@{args.sha}"
    run_object_id = f"github-actions:{args.repo}:{args.run_id}:{args.sequence}"
    receipt_object_id = f"receipt:sha256:{receipt_digest}"

    identity = {
        "activity": args.activity,
        "standing": args.standing,
        "authority_domain": args.authority_domain,
        "agent_id": args.agent_id,
        "run_id": args.run_id,
        "sequence": args.sequence,
        "repo": args.repo,
        "sha": args.sha,
        "receipt_sha256": receipt_digest,
    }
    event_id = f"verification:{canonical_digest(identity)}"
    timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    return {
        "objects": {
            subject_id: {
                "type": "SoftwareSourceRevision",
                "repository": args.repo,
                "sha": args.sha,
            },
            run_object_id: {
                "type": "VerificationRun",
                "run_id": args.run_id,
                "sequence": args.sequence,
                "agent_id": args.agent_id,
            },
            receipt_object_id: {
                "type": "EvidenceReceipt",
                "algorithm": "sha256",
                "digest": receipt_digest,
            },
        },
        "events": {
            event_id: {
                "activity": args.activity,
                "timestamp": timestamp,
                "objects": [subject_id, run_object_id, receipt_object_id],
                "standing": args.standing,
                "authority_domain": args.authority_domain,
                "agent_id": args.agent_id,
                "run_id": args.run_id,
                "sequence": args.sequence,
                "repository": args.repo,
                "subject_sha": args.sha,
                "receipt_sha256": receipt_digest,
            }
        },
        "metadata": {
            "schema": "ex4pm.ocel-verification-observation/v1",
            "receipt_sha256": receipt_digest,
            "authority_domain": args.authority_domain,
        },
    }


def encode_document(document: dict) -> bytes:
    return (
        json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    ).encode("utf-8")


def atomic_spool(payload: bytes, output: Path) -> Path:
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile(
        mode="wb", dir=output.parent, prefix=f".{output.name}.", delete=False
    ) as temporary:
        temporary.write(payload)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)

    os.replace(temporary_path, output)
    return output


def post_if_configured(payload: bytes) -> str:
    ingest_url = os.environ.get("OCEL_INGEST_URL", "").strip()
    if not ingest_url:
        return "spool"

    parsed = urlparse(ingest_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise SystemExit("OCEL_INGEST_URL must be an absolute http(s) URL")

    headers = {
        "Content-Type": "application/json",
        "User-Agent": "ex4pm-ocel-relay/1",
    }
    token = os.environ.get("OCEL_INGEST_TOKEN", "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"

    outgoing = urllib_request.Request(
        ingest_url, data=payload, headers=headers, method="POST"
    )
    try:
        with urllib_request.urlopen(outgoing, timeout=15) as response:
            status = getattr(response, "status", response.getcode())
            if status < 200 or status >= 300:
                raise SystemExit(f"OCEL ingest returned HTTP {status}")
    except Exception as error:
        raise SystemExit(f"OCEL ingest failed after local spool: {error}") from error

    return "spool+http"


def main() -> int:
    args = parse_args()
    args.activity = require_nonempty("activity", args.activity)
    args.agent_id = require_nonempty("agent-id", args.agent_id)
    args.run_id = require_nonempty("run-id", args.run_id)
    args.sequence = require_nonempty("sequence", args.sequence)
    args.repo = require_nonempty("repo", args.repo)
    args.sha = require_nonempty("sha", args.sha).lower()

    if not REPOSITORY_RE.fullmatch(args.repo):
        raise SystemExit("repo must be an owner/name identity without whitespace")
    if not SHA_RE.fullmatch(args.sha):
        raise SystemExit("sha must be an exact 40- or 64-hex source identity")

    _, _, receipt_digest = load_and_admit_receipt(
        args.receipt, args.sha, args.standing
    )
    document = build_ocel(args, receipt_digest)
    payload = encode_document(document)

    spool_dir = Path(os.environ.get("OCEL_SPOOL_DIR", "tmp/ocel-spool"))
    output = args.output or (
        spool_dir
        / f"{args.run_id}-{args.sequence}-{receipt_digest[:16]}.ocel.json"
    )
    output = atomic_spool(payload, output)
    transport = post_if_configured(payload)

    print(
        json.dumps(
            {
                "status": "ALIVE",
                "transport": transport,
                "output": str(output),
                "payload_sha256": hashlib.sha256(payload).hexdigest(),
                "receipt_sha256": receipt_digest,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
