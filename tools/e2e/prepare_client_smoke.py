#!/usr/bin/env python3
"""Injects the temporary E2E module into a client package copied by CI.

Credentials come exclusively from the runner environment.  This script never
prints them and the generated file stays inside the disposable CI workspace.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path


def required_secret(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Missing required GitHub Actions secret: {name}")
    return value


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime-root", required=True, type=Path)
    args = parser.parse_args()

    runtime_root = args.runtime_root.resolve()
    if not (runtime_root / "init.lua").is_file():
        raise SystemExit(f"Invalid client runtime root: {runtime_root}")

    module_source = Path(__file__).with_name("client-release-smoke")
    module_destination = runtime_root / "mods" / "zealot_e2e"
    shutil.copytree(module_source, module_destination, dirs_exist_ok=True)

    credentials = {
        "account": required_secret("ZEALOT_E2E_ACCOUNT"),
        "password": required_secret("ZEALOT_E2E_PASSWORD"),
        "character": required_secret("ZEALOT_E2E_CHARACTER"),
    }
    credentials_path = module_destination / "credentials.lua"
    lua_fields = "\n".join(
        f"  {name} = {json.dumps(value, ensure_ascii=True)}," for name, value in credentials.items()
    )
    credentials_path.write_text(f"E2E_CREDENTIALS = {{\n{lua_fields}\n}}\n", encoding="utf-8")
    credentials_path.chmod(0o600)
    print(f"Prepared temporary E2E module in {module_destination}")


if __name__ == "__main__":
    main()
