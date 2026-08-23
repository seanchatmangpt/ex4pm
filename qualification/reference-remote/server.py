#!/usr/bin/env python3
"""TLS reference remote for the ex4pm capability-indexed rail court."""
from __future__ import annotations

import argparse
import json
import ssl
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(BaseHTTPRequestHandler):
    planner_result: dict = {}

    def log_message(self, fmt: str, *args: object) -> None:
        return

    def do_GET(self) -> None:
        if self.path != "/health":
            self.send_error(404)
            return
        self._json(200, {"standing": "ALIVE"})

    def do_POST(self) -> None:
        if self.path != "/plan":
            self.send_error(404)
            return
        length = int(self.headers.get("content-length", "0"))
        request = json.loads(self.rfile.read(length))
        if request.get("operation") != "plan" or not isinstance(request.get("subject"), dict):
            self._json(400, {"standing": "REFUSED", "reason": "invalid request"})
            return
        self._json(
            200,
            {
                "standing": "ALIVE",
                "receipt_verified": True,
                "result": self.planner_result["result"],
            },
        )

    def _json(self, status: int, value: dict) -> None:
        payload = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--planner-result", required=True)
    parser.add_argument("--port", type=int, default=8443)
    args = parser.parse_args()

    Handler.planner_result = json.loads(Path(args.planner_result).read_text())
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(args.cert, args.key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
