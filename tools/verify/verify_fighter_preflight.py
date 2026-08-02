from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from canonical_fighter_contract_v4 import validate_output  # noqa: E402
from fighter_thruster_action_contract import validate_matrix  # noqa: E402
from small_fighter_calibration import SOURCE_SHA256  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--glb", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--matrix", required=True, type=Path)
    args = parser.parse_args()

    fighter_errors = validate_output(
        args.glb,
        args.manifest,
        SOURCE_SHA256,
    )
    if fighter_errors:
        for error in fighter_errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    import json

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    matrix = json.loads(args.matrix.read_text(encoding="utf-8-sig"))
    matrix_errors = validate_matrix(matrix, manifest)
    if matrix_errors:
        for error in matrix_errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Schema-4 nozzle-local fighter preflight passed.")
    print("Deterministic fighter thruster action matrix validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
