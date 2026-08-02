from __future__ import annotations

import argparse
import json
import math
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


def _vector3(value: Any, label: str, errors: list[str]) -> tuple[float, float, float] | None:
    if not isinstance(value, list) or len(value) != 3:
        errors.append(f"{label} must contain three numbers")
        return None
    try:
        return tuple(float(component) for component in value)
    except (TypeError, ValueError):
        errors.append(f"{label} must contain three numbers")
        return None


def _length(vector: tuple[float, float, float]) -> float:
    return math.sqrt(sum(component * component for component in vector))


def _dot(left: tuple[float, float, float], right: tuple[float, float, float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def _validate_basis(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, list) or len(value) != 3:
        errors.append(f"{label} must contain three basis rows")
        return
    rows: list[tuple[float, float, float]] = []
    for index, row in enumerate(value):
        vector = _vector3(row, f"{label}[{index}]", errors)
        if vector is None:
            return
        rows.append(vector)
    for index, row in enumerate(rows):
        if abs(_length(row) - 1.0) > 1e-4:
            errors.append(f"{label}[{index}] must be unit length")
    for left in range(3):
        for right in range(left + 1, 3):
            if abs(_dot(rows[left], rows[right])) > 1e-4:
                errors.append(f"{label} rows must be orthogonal")
    determinant = (
        rows[0][0] * (rows[1][1] * rows[2][2] - rows[1][2] * rows[2][1])
        - rows[0][1] * (rows[1][0] * rows[2][2] - rows[1][2] * rows[2][0])
        + rows[0][2] * (rows[1][0] * rows[2][1] - rows[1][1] * rows[2][0])
    )
    if abs(determinant - 1.0) > 1e-3:
        errors.append(f"{label} determinant must be +1")


def validate_manifest(path: Path, expected_source_sha: str) -> list[str]:
    errors: list[str] = []
    if not path.is_file():
        return [f"manifest missing: {path}"]
    if path.stat().st_size <= 0:
        return [f"manifest empty: {path}"]
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]

    if report.get("schema_version") != 2:
        errors.append("manifest schema_version must be 2")
    if str(report.get("source_sha256", "")).lower() != expected_source_sha.lower():
        errors.append("manifest source SHA mismatch")

    frame = report.get("canonical_frame")
    if not isinstance(frame, dict):
        errors.append("canonical_frame missing")
    else:
        expected_frame = {
            "godot_right": "+X",
            "godot_forward": "-Z",
            "godot_up": "+Y",
            "root_identity": True,
        }
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

    removed = report.get("removed_objects")
    if not isinstance(removed, list) or not removed:
        errors.append("removed_objects must record EngineFire cleanup")
    elif not all(str(name).startswith("EngineFire") for name in removed):
        errors.append("removed_objects may only contain EngineFire evidence")
    elif "EngineFire" not in removed or len(removed) < 11:
        errors.append("removed_objects must contain all eleven EngineFire objects")

    sockets = report.get("sockets")
    if not isinstance(sockets, list):
        errors.append("sockets must be a list")
        return errors
    if len(sockets) != 12:
        errors.append(f"socket count must be 12, got {len(sockets)}")

    paths: list[str] = []
    classes: Counter[str] = Counter()
    for index, socket in enumerate(sockets):
        label = f"sockets[{index}]"
        if not isinstance(socket, dict):
            errors.append(f"{label} must be an object")
            continue
        path_value = str(socket.get("path", ""))
        if not path_value.startswith("Thrusters/"):
            errors.append(f"{label}.path must start with Thrusters/")
        paths.append(path_value)
        class_value = str(socket.get("class", ""))
        classes[class_value] += 1
        if class_value not in SOCKET_COUNTS:
            errors.append(f"{label}.class is invalid: {class_value}")
        if not str(socket.get("source_object", "")).startswith("EngineFire"):
            errors.append(f"{label}.source_object must identify EngineFire evidence")
        try:
            if int(socket.get("source_component", -1)) < 0:
                raise ValueError
        except (TypeError, ValueError):
            errors.append(f"{label}.source_component must be non-negative")
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

    if len(set(paths)) != len(paths):
        errors.append("socket paths must be unique")
    if report.get("asset") == "Small Sci-Fi Fighter" and set(paths) != EXPECTED_SOCKET_PATHS:
        missing = sorted(EXPECTED_SOCKET_PATHS - set(paths))
        unexpected = sorted(set(paths) - EXPECTED_SOCKET_PATHS)
        errors.append(
            "canonical fighter socket paths mismatch: "
            f"missing={missing}, unexpected={unexpected}"
        )
    if dict(classes) != SOCKET_COUNTS:
        errors.append(f"socket class counts must be {SOCKET_COUNTS}, got {dict(classes)}")
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
    parser = argparse.ArgumentParser(description="Validate canonical fighter export outputs.")
    parser.add_argument("--glb", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    errors = validate_output(args.glb, args.manifest, args.source_sha)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Canonical fighter contract validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
