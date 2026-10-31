#!/usr/bin/env python3
"""Waits for the client E2E module result without reading credentials."""

from __future__ import annotations

import argparse
import time
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--timeout", default=130, type=int)
    args = parser.parse_args()

    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        if args.result.is_file():
            lines = args.result.read_text(encoding="utf-8", errors="replace").splitlines()
            status = lines[0] if lines else "FAIL"
            detail = lines[1] if len(lines) > 1 else "missing result detail"
            print(f"Client E2E result: {status} - {detail}")
            if status == "PASS":
                return
            raise SystemExit(1)
        time.sleep(1)

    raise SystemExit("Timed out waiting for the client E2E result file")


if __name__ == "__main__":
    main()
