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
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
if manifest.get("schema_version") != 3:
    raise SystemExit("Hero fighter manifest schema_version must be 3")
if manifest.get("thruster_visual_strategy") != "source_exact_enginefire_geometry":
    raise SystemExit("Hero fighter must use source_exact_enginefire_geometry")
if manifest.get("procedural_exhaust_geometry") is not False:
    raise SystemExit("Hero fighter procedural_exhaust_geometry must be false")
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
expected_socket_paths = {
    "Thrusters/Main/MainLeft",
    "Thrusters/Main/MainRight",
    "Thrusters/Retro/RetroLeft",
    "Thrusters/Retro/RetroRight",
    "Thrusters/Maneuver/FrontUpperLeft",
    "Thrusters/Maneuver/FrontUpperRight",
    "Thrusters/Maneuver/RearUpperLeft",
    "Thrusters/Maneuver/RearUpperRight",
    "Thrusters/Maneuver/RearLowerLeft",
    "Thrusters/Maneuver/RearLowerRight",
    "Thrusters/Maneuver/FrontLowerLeft",
    "Thrusters/Maneuver/FrontLowerRight",
}
actual_socket_paths = {str(socket.get("path", "")) for socket in manifest.get("sockets", [])}
if actual_socket_paths != expected_socket_paths:
    raise SystemExit(
        f"Hero fighter socket paths mismatch. Missing: {sorted(expected_socket_paths - actual_socket_paths)} "
        f"Unexpected: {sorted(actual_socket_paths - expected_socket_paths)}"
    )
expected_effect_paths = {
    "ThrusterEffects/Main/MainLeftEffect",
    "ThrusterEffects/Main/MainRightEffect",
    "ThrusterEffects/Retro/RetroLeftEffect",
    "ThrusterEffects/Retro/RetroRightEffect",
    "ThrusterEffects/Maneuver/FrontUpperLeftEffect",
    "ThrusterEffects/Maneuver/FrontUpperRightEffect",
    "ThrusterEffects/Maneuver/RearUpperLeftEffect",
    "ThrusterEffects/Maneuver/RearUpperRightEffect",
    "ThrusterEffects/Maneuver/RearLowerLeftEffect",
    "ThrusterEffects/Maneuver/RearLowerRightEffect",
    "ThrusterEffects/Maneuver/FrontLowerLeftEffect",
    "ThrusterEffects/Maneuver/FrontLowerRightEffect",
}
effects = manifest.get("thruster_effects", [])
actual_effect_paths = {str(effect.get("path", "")) for effect in effects}
if actual_effect_paths != expected_effect_paths:
    raise SystemExit(
        f"Hero fighter effect paths mismatch. Missing: {sorted(expected_effect_paths - actual_effect_paths)} "
        f"Unexpected: {sorted(actual_effect_paths - expected_effect_paths)}"
    )
for effect in effects:
    if effect.get("identity_transform") is not True or effect.get("source_exact_geometry") is not True:
        raise SystemExit("Every fighter effect must be identity-transform source-exact geometry")
    if re.fullmatch(r"[0-9a-f]{64}", str(effect.get("geometry_sha256", ""))) is None:
        raise SystemExit("Every fighter effect must include a valid geometry SHA-256")
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
