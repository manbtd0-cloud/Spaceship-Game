from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from small_fighter_calibration import (
    BOUNDS_TOLERANCE,
    COLLIDER_SIZE_GODOT,
    EXPECTED_DIMENSIONS_GODOT,
    SOCKET_COUNTS,
)

EXPECTED_SOCKET_PATHS = {
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
EXPECTED_EFFECT_PATHS = {
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


def _vector3(value: Any, label: str, errors: list[str]) -> tuple[float, float, float] | None:
    if not isinstance(value, list) or len(value) != 3:
        errors.append(f"{label} must contain three numbers")
        return None
    try:
        result = tuple(float(component) for component in value)
    except (TypeError, ValueError):
        errors.append(f"{label} must contain three numbers")
        return None
    if not all(math.isfinite(component) for component in result):
        errors.append(f"{label} must be finite")
        return None
    return result


def _length(vector: tuple[float, float, float]) -> float:
    return math.sqrt(sum(component * component for component in vector))


def _dot(left: tuple[float, float, float], right: tuple[float, float, float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def _validate_basis(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, list) or len(value) != 3:
        errors.append(f"{label} must contain three rows")
        return
    rows: list[tuple[float, float, float]] = []
    for index, row in enumerate(value):
        vector = _vector3(row, f"{label}[{index}]", errors)
        if vector is None:
            return
        rows.append(vector)
    for row in rows:
        if abs(_length(row) - 1.0) > 1e-4:
            errors.append(f"{label} rows must be unit length")
    for left in range(3):
        for right in range(left + 1, 3):
            if abs(_dot(rows[left], rows[right])) > 1e-4:
                errors.append(f"{label} rows must be orthogonal")


def validate_manifest(path: Path, expected_source_sha: str) -> list[str]:
    errors: list[str] = []
    if not path.is_file():
        return [f"manifest missing: {path}"]
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return [f"manifest unreadable: {error}"]

    if report.get("schema_version") != 3:
        errors.append("manifest schema_version must be 3")
    if str(report.get("source_sha256", "")).lower() != expected_source_sha.lower():
        errors.append("manifest source SHA mismatch")
    if report.get("thruster_visual_strategy") != "source_exact_enginefire_geometry":
        errors.append("thruster_visual_strategy must be source_exact_enginefire_geometry")
    if report.get("procedural_exhaust_geometry") is not False:
        errors.append("procedural_exhaust_geometry must be false")

    frame = report.get("canonical_frame")
    expected_frame = {
        "godot_right": "+X",
        "godot_forward": "-Z",
        "godot_up": "+Y",
        "root_identity": True,
    }
    if not isinstance(frame, dict):
        errors.append("canonical_frame missing")
    else:
        for key, expected in expected_frame.items():
            if frame.get(key) != expected:
                errors.append(f"canonical_frame.{key} must be {expected!r}")

    dimensions = _vector3(report.get("dimensions_godot_xyz"), "dimensions_godot_xyz", errors)
    if dimensions is not None:
        for axis, actual, expected in zip("XYZ", dimensions, EXPECTED_DIMENSIONS_GODOT):
            if abs(actual - expected) > BOUNDS_TOLERANCE:
                errors.append(f"dimension {axis} outside tolerance: {actual} vs {expected}")
    collider = _vector3(report.get("collider_size_godot_xyz"), "collider_size_godot_xyz", errors)
    if collider is not None:
        for axis, actual, expected in zip("XYZ", collider, COLLIDER_SIZE_GODOT):
            if abs(actual - expected) > 1e-4:
                errors.append(f"collider {axis} must be {expected}")

    removed = report.get("removed_from_hull")
    if not isinstance(removed, list) or len(removed) < 11:
        errors.append("removed_from_hull must contain all eleven EngineFire objects")
    elif not all(str(name).startswith("EngineFire") for name in removed):
        errors.append("removed_from_hull may only identify EngineFire objects")

    sockets = report.get("sockets")
    if not isinstance(sockets, list):
        errors.append("sockets must be a list")
        sockets = []
    socket_paths: list[str] = []
    socket_classes: Counter[str] = Counter()
    for index, socket in enumerate(sockets):
        label = f"sockets[{index}]"
        if not isinstance(socket, dict):
            errors.append(f"{label} must be an object")
            continue
        socket_paths.append(str(socket.get("path", "")))
        socket_class = str(socket.get("class", ""))
        socket_classes[socket_class] += 1
        _vector3(socket.get("position"), f"{label}.position", errors)
        exhaust = _vector3(socket.get("exhaust_direction"), f"{label}.exhaust_direction", errors)
        reaction = _vector3(socket.get("reaction_direction"), f"{label}.reaction_direction", errors)
        if exhaust is not None and reaction is not None:
            if abs(_length(exhaust) - 1.0) > 1e-4:
                errors.append(f"{label}.exhaust_direction must be unit length")
            if abs(_length(reaction) - 1.0) > 1e-4:
                errors.append(f"{label}.reaction_direction must be unit length")
            if _dot(exhaust, reaction) > -0.9999:
                errors.append(f"{label} exhaust and reaction directions must be opposite")
        _validate_basis(socket.get("basis"), f"{label}.basis", errors)
    if set(socket_paths) != EXPECTED_SOCKET_PATHS or len(socket_paths) != 12:
        errors.append(
            "socket paths mismatch: "
            f"missing={sorted(EXPECTED_SOCKET_PATHS - set(socket_paths))} "
            f"unexpected={sorted(set(socket_paths) - EXPECTED_SOCKET_PATHS)}"
        )
    if dict(socket_classes) != SOCKET_COUNTS:
        errors.append(f"socket class counts must be {SOCKET_COUNTS}, got {dict(socket_classes)}")

    effects = report.get("thruster_effects")
    if not isinstance(effects, list):
        errors.append("thruster_effects must be a list")
        effects = []
    effect_paths: list[str] = []
    effect_classes: Counter[str] = Counter()
    for index, effect in enumerate(effects):
        label = f"thruster_effects[{index}]"
        if not isinstance(effect, dict):
            errors.append(f"{label} must be an object")
            continue
        effect_paths.append(str(effect.get("path", "")))
        effect_class = str(effect.get("class", ""))
        effect_classes[effect_class] += 1
        components = effect.get("source_component_indices")
        if (
            not isinstance(components, list)
            or not components
            or any(not isinstance(component, int) or component < 0 for component in components)
            or len(set(components)) != len(components)
        ):
            errors.append(f"{label}.source_component_indices must be unique non-negative integers")
        for count_key in ("vertex_count", "face_count"):
            value = effect.get(count_key)
            if not isinstance(value, int) or value <= 0:
                errors.append(f"{label}.{count_key} must be positive")
        minimum = _vector3(effect.get("bounds_min"), f"{label}.bounds_min", errors)
        maximum = _vector3(effect.get("bounds_max"), f"{label}.bounds_max", errors)
        if minimum is not None and maximum is not None:
            if not any(maximum[axis] > minimum[axis] for axis in range(3)):
                errors.append(f"{label} bounds must have positive extent")
        digest = str(effect.get("geometry_sha256", ""))
        if re.fullmatch(r"[0-9a-f]{64}", digest) is None:
            errors.append(f"{label}.geometry_sha256 must be lowercase SHA-256")
        if effect.get("identity_transform") is not True:
            errors.append(f"{label}.identity_transform must be true")
        if effect.get("source_exact_geometry") is not True:
            errors.append(f"{label}.source_exact_geometry must be true")
    if set(effect_paths) != EXPECTED_EFFECT_PATHS or len(effect_paths) != 12:
        errors.append(
            "effect paths mismatch: "
            f"missing={sorted(EXPECTED_EFFECT_PATHS - set(effect_paths))} "
            f"unexpected={sorted(set(effect_paths) - EXPECTED_EFFECT_PATHS)}"
        )
    if dict(effect_classes) != SOCKET_COUNTS:
        errors.append(f"effect class counts must be {SOCKET_COUNTS}, got {dict(effect_classes)}")
    return errors


def validate_output(glb_path: Path, manifest_path: Path, expected_source_sha: str) -> list[str]:
    errors: list[str] = []
    if not glb_path.is_file():
        errors.append(f"GLB missing: {glb_path}")
    elif glb_path.stat().st_size <= 0:
        errors.append(f"GLB empty: {glb_path}")
    errors.extend(validate_manifest(manifest_path, expected_source_sha))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate schema-3 source-exact fighter output.")
    parser.add_argument("--glb", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    errors = validate_output(args.glb, args.manifest, args.source_sha)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Schema-3 source-exact fighter contract validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
