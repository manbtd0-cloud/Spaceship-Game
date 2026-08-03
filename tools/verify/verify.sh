#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXPECTED_SOURCE_SHA="1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478"

required_files=(
    "assets/runtime/ships/player/small_sci_fi_fighter.glb"
    "assets/runtime/ships/player/small_sci_fi_fighter.manifest.json"
    "config/ships/small_sci_fi_fighter_thruster_actions.json"
    "tools/assets/canonical_fighter_contract_v5.py"
    "tools/assets/fighter_thruster_action_contract.py"
)

for relative_path in "${required_files[@]}"; do
    absolute_path="$REPO_ROOT/$relative_path"
    if [[ ! -f "$absolute_path" ]]; then
        printf 'ERROR: Required verification file missing: %s\n' "$relative_path" >&2
        exit 1
    fi
    if [[ ! -s "$absolute_path" ]]; then
        printf 'ERROR: Required verification file is empty: %s\n' "$relative_path" >&2
        exit 1
    fi
done

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    printf 'ERROR: Python executable not found: %s\n' "$PYTHON_BIN" >&2
    exit 127
fi

manifest_path="$REPO_ROOT/assets/runtime/ships/player/small_sci_fi_fighter.manifest.json"
glb_path="$REPO_ROOT/assets/runtime/ships/player/small_sci_fi_fighter.glb"
matrix_path="$REPO_ROOT/config/ships/small_sci_fi_fighter_thruster_actions.json"
fighter_validator_path="$REPO_ROOT/tools/assets/canonical_fighter_contract_v5.py"
matrix_validator_path="$REPO_ROOT/tools/assets/fighter_thruster_action_contract.py"

"$PYTHON_BIN" - "$manifest_path" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8-sig"))
if manifest.get("schema_version") != 5:
    raise SystemExit("Hero fighter manifest schema_version must be 5")
if (
    manifest.get("thruster_visual_strategy")
    != "source_exact_nozzle_local_enginefire_geometry"
):
    raise SystemExit(
        "Hero fighter must use source_exact_nozzle_local_enginefire_geometry"
    )
if manifest.get("procedural_exhaust_geometry") is not False:
    raise SystemExit("Hero fighter procedural_exhaust_geometry must be false")
frame = manifest.get("canonical_frame")
expected_frame = {
    "godot_right": "+X",
    "godot_forward": "-Z",
    "godot_up": "+Y",
    "root_identity": True,
}
if not isinstance(frame, dict) or any(
    frame.get(key) != value for key, value in expected_frame.items()
):
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
actual_socket_paths = {
    str(socket.get("path", "")) for socket in manifest.get("sockets", [])
}
if actual_socket_paths != expected_socket_paths:
    raise SystemExit("Hero fighter socket paths mismatch")

expected_effect_paths = {
    "ThrusterEffects/MainEffects/MainLeftEffect",
    "ThrusterEffects/MainEffects/MainRightEffect",
    "ThrusterEffects/RetroEffects/RetroLeftEffect",
    "ThrusterEffects/RetroEffects/RetroRightEffect",
    "ThrusterEffects/ManeuverEffects/FrontUpperLeftEffect",
    "ThrusterEffects/ManeuverEffects/FrontUpperRightEffect",
    "ThrusterEffects/ManeuverEffects/RearUpperLeftEffect",
    "ThrusterEffects/ManeuverEffects/RearUpperRightEffect",
    "ThrusterEffects/ManeuverEffects/RearLowerLeftEffect",
    "ThrusterEffects/ManeuverEffects/RearLowerRightEffect",
    "ThrusterEffects/ManeuverEffects/FrontLowerLeftEffect",
    "ThrusterEffects/ManeuverEffects/FrontLowerRightEffect",
}
effects = manifest.get("thruster_effects", [])
actual_effect_paths = {str(effect.get("path", "")) for effect in effects}
if actual_effect_paths != expected_effect_paths:
    raise SystemExit("Hero fighter effect paths mismatch")
effect_socket_paths = {str(effect.get("socket_path", "")) for effect in effects}
if effect_socket_paths != expected_socket_paths or len(effects) != 12:
    raise SystemExit("Hero fighter effect socket mapping must be one-to-one")
for effect in effects:
    if effect.get("source_exact_geometry") is not True:
        raise SystemExit("Every fighter effect must use source-exact geometry")
    if re.fullmatch(r"[0-9a-f]{64}", str(effect.get("geometry_sha256", ""))) is None:
        raise SystemExit("Every fighter effect must include a valid geometry SHA-256")
    if effect.get("node_transform_basis") is None:
        raise SystemExit("Every fighter effect must include node_transform_basis")
    if effect.get("node_transform_origin") is None:
        raise SystemExit("Every fighter effect must include node_transform_origin")
    if effect.get("local_exhaust_axis") is None:
        raise SystemExit("Every fighter effect must include local_exhaust_axis")
    reconstruction = float(effect.get("maximum_reconstruction_error_m", -1.0))
    if not 0.0 <= reconstruction <= 0.0001:
        raise SystemExit(
            "Every fighter effect maximum_reconstruction_error_m must be within [0, 0.0001]"
        )

expected_muzzle_paths = {
    "Weapons/Primary/LeftMuzzle",
    "Weapons/Primary/RightMuzzle",
}
muzzles = manifest.get("primary_muzzles", [])
actual_muzzle_paths = {str(muzzle.get("path", "")) for muzzle in muzzles}
if actual_muzzle_paths != expected_muzzle_paths or len(muzzles) != 2:
    raise SystemExit("Hero fighter primary muzzle paths mismatch")
for muzzle in muzzles:
    if muzzle.get("origin") is None or muzzle.get("basis") is None:
        raise SystemExit("Every primary muzzle must include origin and basis")
    if muzzle.get("forward") is None:
        raise SystemExit("Every primary muzzle must include forward")
    extraction = float(muzzle.get("extraction_error_m", -1.0))
    if not 0.0 <= extraction <= 0.0001:
        raise SystemExit(
            "Every primary muzzle extraction_error_m must be within [0, 0.0001]"
        )
PY

"$PYTHON_BIN" "$fighter_validator_path" \
    --glb "$glb_path" \
    --manifest "$manifest_path" \
    --source-sha "$EXPECTED_SOURCE_SHA"

"$PYTHON_BIN" "$matrix_validator_path" \
    --manifest "$manifest_path" \
    --matrix "$matrix_path"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    printf 'ERROR: Godot executable not found: %s\n' "$GODOT_BIN" >&2
    printf 'Set GODOT_BIN to the Godot 4.7.1 executable path.\n' >&2
    exit 127
fi

cd "$REPO_ROOT"
"$GODOT_BIN" --headless --path . --editor --quit
"$GODOT_BIN" --headless --path . --script res://tests/test_runner.gd
"$GODOT_BIN" --headless --path . --quit-after 2
