#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_runtime_files=(
    "assets/runtime/ships/player/small_sci_fi_fighter.glb"
    "assets/runtime/ships/player/small_sci_fi_fighter.manifest.json"
)

for relative_path in "${required_runtime_files[@]}"; do
    absolute_path="$REPO_ROOT/$relative_path"
    if [[ ! -f "$absolute_path" ]]; then
        printf 'ERROR: Required runtime asset missing: %s\n' "$relative_path" >&2
        exit 1
    fi
    if [[ ! -s "$absolute_path" ]]; then
        printf 'ERROR: Required runtime asset is empty: %s\n' "$relative_path" >&2
        exit 1
    fi
done

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    printf 'ERROR: Python executable not found: %s\n' "$PYTHON_BIN" >&2
    exit 127
fi

manifest_path="$REPO_ROOT/assets/runtime/ships/player/small_sci_fi_fighter.manifest.json"
"$PYTHON_BIN" - "$manifest_path" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
if manifest.get("schema_version") != 2:
    raise SystemExit("Hero fighter manifest schema_version must be 2")
frame = manifest.get("canonical_frame")
expected = {
    "godot_right": "+X",
    "godot_forward": "-Z",
    "godot_up": "+Y",
    "root_identity": True,
}
if not isinstance(frame, dict) or any(frame.get(key) != value for key, value in expected.items()):
    raise SystemExit(
        "Hero fighter canonical frame must be +X right, -Z forward, +Y up, identity root"
    )
if len(manifest.get("sockets", [])) != 12:
    raise SystemExit("Hero fighter manifest must contain exactly twelve thruster sockets")
PY

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    printf 'ERROR: Godot executable not found: %s\n' "$GODOT_BIN" >&2
    printf 'Set GODOT_BIN to the Godot 4.7.1 executable path.\n' >&2
    exit 127
fi

cd "$REPO_ROOT"
"$GODOT_BIN" --headless --path . --editor --quit
"$GODOT_BIN" --headless --path . --script res://tests/test_runner.gd
"$GODOT_BIN" --headless --path . --quit-after 2
