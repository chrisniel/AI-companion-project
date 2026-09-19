#!/usr/bin/env python3
"""
OpenAPI Contract Verification & Drift Detection Script.

Verifies that contracts/openapi/openapi.json matches app.openapi()
deterministically without running the server or modifying local state.

Usage:
    python scripts/check_openapi_contract.py          # check mode (exit 0 on match, exit 1 on drift)
    python scripts/check_openapi_contract.py --check  # explicit check mode
    python scripts/check_openapi_contract.py --write  # regenerate contracts/openapi/openapi.json
"""

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path

# Ensure isolated runtime environment before importing app
if "COMPANION_API_KEY" not in os.environ:
    os.environ["COMPANION_API_KEY"] = "ci-ephemeral-test-key"
if "COMPANION_DATA_ROOT" not in os.environ:
    os.environ["COMPANION_DATA_ROOT"] = os.path.join(tempfile.gettempdir(), "ai-companion-ci")

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
CONTRACT_PATH = REPO_ROOT / "contracts" / "openapi" / "openapi.json"

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

REQUIRED_MODEL_ROUTES = [
    ("/api/v1/models", "get"),
    ("/api/v1/models/registry", "get"),
    ("/api/v1/models/load", "post"),
    ("/api/v1/models/unload", "post"),
    ("/api/v1/models/profile", "patch"),
    ("/api/v1/chat/completions", "post"),
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Check or regenerate OpenAPI contract from FastAPI app.")
    parser.add_argument("--check", action="store_true", default=True, help="Verify contract without modifying files (default)")
    parser.add_argument("--write", action="store_true", help="Regenerate contracts/openapi/openapi.json")
    args = parser.parse_args()

    # Import FastAPI application
    try:
        from app.main import app
    except ImportError as e:
        print(f"Failed to import app.main: {e}", file=sys.stderr)
        return 2

    # Generate OpenAPI schema
    schema = app.openapi()
    paths = schema.get("paths", {})

    # Verify required routes exist
    missing_routes: list[str] = []
    for route, method in REQUIRED_MODEL_ROUTES:
        if route not in paths:
            missing_routes.append(f"{method.upper()} {route} (path missing)")
        elif method.lower() not in paths[route]:
            missing_routes.append(f"{method.upper()} {route} (method missing)")

    if missing_routes:
        print("Error: Missing required routes in generated OpenAPI schema:", file=sys.stderr)
        for missing in missing_routes:
            print(f"  - {missing}", file=sys.stderr)
        return 1

    # Deterministic serialization: indent=2, ensure_ascii=False, final newline
    generated_json = json.dumps(schema, indent=2, ensure_ascii=False) + "\n"

    if args.write:
        CONTRACT_PATH.parent.mkdir(parents=True, exist_ok=True)
        CONTRACT_PATH.write_text(generated_json, encoding="utf-8")
        print(f"Successfully regenerated {CONTRACT_PATH.relative_to(REPO_ROOT)}")
        return 0

    if not CONTRACT_PATH.exists():
        print(f"Error: Contract file does not exist: {CONTRACT_PATH}", file=sys.stderr)
        return 1

    committed_json = CONTRACT_PATH.read_text(encoding="utf-8")

    if generated_json == committed_json:
        print(f"OpenAPI contract is up-to-date ({len(paths)} routes, all required model routes present).")
        return 0
    else:
        print(
            f"Error: OpenAPI contract drift detected!\n"
            f"{CONTRACT_PATH.relative_to(REPO_ROOT)} does not match app.openapi().\n"
            f"Run 'python scripts/check_openapi_contract.py --write' to regenerate.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
