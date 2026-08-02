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
EXPECTED_EFFECT_TO_SOCKET = {
    "ThrusterEffects/MainEffects/MainLeftEffect": "Thrusters/Main/MainLeft",
    "ThrusterEffects/MainEffects/MainRightEffect": "Thrusters/Main/MainRight",
    "ThrusterEffects/RetroEffects/RetroLeftEffect": "Thrusters/Retro/RetroLeft",
    "ThrusterEffects/RetroEffects/RetroRightEffect": "Thrusters/Retro/RetroRight",
    "ThrusterEffects/ManeuverEffects/FrontUpperLeftEffect": "Thrusters/Maneuver/FrontUpperLeft",
    "ThrusterEffects/ManeuverEffects/FrontUpperRightEffect": "Thrusters/Maneuver/FrontUpperRight",
    "ThrusterEffects/ManeuverEffects/RearUpperLeftEffect": "Thrusters/Maneuver/RearUpperLeft",
    "ThrusterEffects/ManeuverEffects/RearUpperRightEffect": "Thrusters/Maneuver/RearUpperRight",
    "ThrusterEffects/ManeuverEffects/RearLowerLeftEffect": "Thrusters/Maneuver/RearLowerLeft",
    "ThrusterEffects/ManeuverEffects/RearLowerRightEffect": "Thrusters/Maneuver/RearLowerRight",
    "ThrusterEffects/ManeuverEffects/FrontLowerLeftEffect": "Thrusters/Maneuver/FrontLowerLeft",
    "ThrusterEffects/ManeuverEffects/FrontLowerRightEffect": "Thrusters/Maneuver/FrontLowerRight",
}
EXPECTED_EFFECT_PATHS = set(EXPECTED_EFFECT_TO_SOCKET)
MAXIMUM_RECONSTRUCTION_ERROR_M = 0.0001


def _vector3(
    value: Any,
    label: str,
    errors: list[str],
) -> tuple[float, float, float] | None:
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


def _length(value: tuple[float, float, float]) -> float:
    return math.sqrt(sum(component * component for component in value))


def _dot(
    left: tuple[float, float, float],
    right: tuple[float, float, float],
) -> float:
    return sum(a * b for a, b in zip(left, right))


def _validate_basis(
    value: Any,
    label: str,
    errors: list[str],
) -> list[tuple[float, float, float]] | None:
    if not isinstance(value, list) or len(value) != 3:
        errors.append(f"{label} must contain three rows")
        return None
    rows: list[tuple[float, float, float]] = []
    for index, row in enumerate(value):
        parsed = _vector3(row, f"{label}[{index}]", errors)
        if parsed is None:
            return None
        rows.append(parsed)
    for row in rows:
        if abs(_length(row) - 1.0) > 1e-4:
            errors.append(f"{label} rows must be unit length")
    for left in range(3):
        for right in range(left + 1, 3):
            if abs(_dot(rows[left], rows[right])) > 1e-4:
                errors.append(f"{label} rows must be orthogonal")
    return rows


def _class_for_socket_path(path: str) -> str:
    if path.startswith("Thrusters/Main/"):
        return "main"
    if path.startswith("Thrusters/Retro/"):
        return "retro"
    if path.startswith("Thrusters/Maneuver/"):
        return "maneuver"
    return ""


def validate_manifest(path: Path, expected_source_sha: str) -> list[str]:
    errors: list[str] = []
    if not path.is_file():
        return [f"manifest missing: {path}"]
    try:
        report = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return [f"manifest unreadable: {error}"]

    if report.get("schema_version") != 4:
        errors.append("manifest schema_version must be 4")
    if str(report.get("source_sha256", "")).lower() != expected_source_sha.lower():
        errors.append("manifest source SHA mismatch")
    if (
        report.get("thruster_visual_strategy")
        != "source_exact_nozzle_local_enginefire_geometry"
    ):
        errors.append(
            "thruster_visual_strategy must be "
            "source_exact_nozzle_local_enginefire_geometry"
        )
    if report.get("procedural_exhaust_geometry") is not False:
        errors.append("procedural_exhaust_geometry must be false")

    expected_frame = {
        "godot_right": "+X",
        "godot_forward": "-Z",
        "godot_up": "+Y",
        "root_identity": True,
    }
    frame = report.get("canonical_frame")
    if not isinstance(frame, dict):
        errors.append("canonical_frame missing")
    else:
        for key, expected in expected_frame.items():
            if frame.get(key) != expected:
                errors.append(f"canonical_frame.{key} must be {expected!r}")

    dimensions = _vector3(
        report.get("dimensions_godot_xyz"),
        "dimensions_godot_xyz",
        errors,
    )
    if dimensions is not None:
        for axis, actual, expected in zip(
            "XYZ",
            dimensions,
            EXPECTED_DIMENSIONS_GODOT,
        ):
            if abs(actual - expected) > BOUNDS_TOLERANCE:
                errors.append(
                    f"dimension {axis} outside tolerance: {actual} vs {expected}"
                )

    collider = _vector3(
        report.get("collider_size_godot_xyz"),
        "collider_size_godot_xyz",
        errors,
    )
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
    socket_positions: dict[str, tuple[float, float, float]] = {}
    for index, socket in enumerate(sockets):
        label = f"sockets[{index}]"
        if not isinstance(socket, dict):
            errors.append(f"{label} must be an object")
            continue
        path_value = str(socket.get("path", ""))
        socket_paths.append(path_value)
        socket_class = str(socket.get("class", ""))
        socket_classes[socket_class] += 1
        position = _vector3(socket.get("position"), f"{label}.position", errors)
        if position is not None:
            socket_positions[path_value] = position
        exhaust = _vector3(
            socket.get("exhaust_direction"),
            f"{label}.exhaust_direction",
            errors,
        )
        reaction = _vector3(
            socket.get("reaction_direction"),
            f"{label}.reaction_direction",
            errors,
        )
        if exhaust is not None and reaction is not None:
            if abs(_length(exhaust) - 1.0) > 1e-4:
                errors.append(f"{label}.exhaust_direction must be unit length")
            if abs(_length(reaction) - 1.0) > 1e-4:
                errors.append(f"{label}.reaction_direction must be unit length")
            if _dot(exhaust, reaction) > -0.9999:
                errors.append(
                    f"{label} exhaust and reaction directions must be opposite"
                )
        _validate_basis(socket.get("basis"), f"{label}.basis", errors)
        capacity = socket.get("capacity")
        try:
            parsed_capacity = float(capacity)
        except (TypeError, ValueError):
            parsed_capacity = -1.0
        if not math.isfinite(parsed_capacity) or parsed_capacity <= 0.0:
            errors.append(f"{label}.capacity must be positive and finite")

    if set(socket_paths) != EXPECTED_SOCKET_PATHS or len(socket_paths) != 12:
        errors.append(
            "socket paths mismatch: "
            f"missing={sorted(EXPECTED_SOCKET_PATHS - set(socket_paths))} "
            f"unexpected={sorted(set(socket_paths) - EXPECTED_SOCKET_PATHS)}"
        )
    if dict(socket_classes) != SOCKET_COUNTS:
        errors.append(
            f"socket class counts must be {SOCKET_COUNTS}, "
            f"got {dict(socket_classes)}"
        )

    effects = report.get("thruster_effects")
    if not isinstance(effects, list):
        errors.append("thruster_effects must be a list")
        effects = []
    effect_paths: list[str] = []
    effect_socket_paths: list[str] = []
    effect_classes: Counter[str] = Counter()
    for index, effect in enumerate(effects):
        label = f"thruster_effects[{index}]"
        if not isinstance(effect, dict):
            errors.append(f"{label} must be an object")
            continue

        effect_path = str(effect.get("path", ""))
        socket_path = str(effect.get("socket_path", ""))
        effect_paths.append(effect_path)
        effect_socket_paths.append(socket_path)
        expected_socket = EXPECTED_EFFECT_TO_SOCKET.get(effect_path)
        if not socket_path:
            errors.append(f"{label}.socket_path is required")
        elif socket_path != expected_socket:
            errors.append(
                f"{label}.socket_path must be {expected_socket!r}, got {socket_path!r}"
            )

        effect_class = str(effect.get("class", ""))
        effect_classes[effect_class] += 1
        expected_class = _class_for_socket_path(socket_path)
        if expected_class and effect_class != expected_class:
            errors.append(
                f"{label}.class must match socket class {expected_class!r}"
            )

        components = effect.get("source_component_indices")
        if (
            not isinstance(components, list)
            or not components
            or any(
                not isinstance(component, int) or component < 0
                for component in components
            )
            or len(set(components)) != len(components)
        ):
            errors.append(
                f"{label}.source_component_indices must be unique "
                "non-negative integers"
            )

        for count_key in ("vertex_count", "face_count"):
            count = effect.get(count_key)
            if not isinstance(count, int) or count <= 0:
                errors.append(f"{label}.{count_key} must be positive")

        digest = str(effect.get("geometry_sha256", ""))
        if re.fullmatch(r"[0-9a-f]{64}", digest) is None:
            errors.append(f"{label}.geometry_sha256 must be lowercase SHA-256")

        _validate_basis(
            effect.get("node_transform_basis"),
            f"{label}.node_transform_basis",
            errors,
        )
        origin = _vector3(
            effect.get("node_transform_origin"),
            f"{label}.node_transform_origin",
            errors,
        )
        if (
            origin is not None
            and socket_path in socket_positions
            and any(
                abs(origin[axis] - socket_positions[socket_path][axis]) > 1e-4
                for axis in range(3)
            )
        ):
            errors.append(f"{label}.node_transform_origin must match socket position")

        local_axis = _vector3(
            effect.get("local_exhaust_axis"),
            f"{label}.local_exhaust_axis",
            errors,
        )
        if local_axis is not None and abs(_length(local_axis) - 1.0) > 1e-4:
            errors.append(f"{label}.local_exhaust_axis must be unit length")

        minimum = _vector3(
            effect.get("local_bounds_min"),
            f"{label}.local_bounds_min",
            errors,
        )
        maximum = _vector3(
            effect.get("local_bounds_max"),
            f"{label}.local_bounds_max",
            errors,
        )
        if minimum is not None and maximum is not None:
            if not any(maximum[axis] > minimum[axis] for axis in range(3)):
                errors.append(f"{label} local bounds must have positive extent")

        reconstruction_error = effect.get("maximum_reconstruction_error_m")
        try:
            parsed_error = float(reconstruction_error)
        except (TypeError, ValueError):
            parsed_error = math.inf
        if not math.isfinite(parsed_error) or parsed_error < 0.0:
            errors.append(
                f"{label}.maximum_reconstruction_error_m must be finite and non-negative"
            )
        elif parsed_error > MAXIMUM_RECONSTRUCTION_ERROR_M:
            errors.append(
                f"{label} reconstruction error {parsed_error:.9f} exceeds "
                f"{MAXIMUM_RECONSTRUCTION_ERROR_M:.9f}"
            )

        if effect.get("source_exact_geometry") is not True:
            errors.append(f"{label}.source_exact_geometry must be true")

    if set(effect_paths) != EXPECTED_EFFECT_PATHS or len(effect_paths) != 12:
        errors.append(
            "effect paths mismatch: "
            f"missing={sorted(EXPECTED_EFFECT_PATHS - set(effect_paths))} "
            f"unexpected={sorted(set(effect_paths) - EXPECTED_EFFECT_PATHS)}"
        )
    if (
        set(effect_socket_paths) != EXPECTED_SOCKET_PATHS
        or len(effect_socket_paths) != 12
        or len(set(effect_socket_paths)) != 12
    ):
        errors.append("effect socket mapping must be one-to-one across twelve sockets")
    if dict(effect_classes) != SOCKET_COUNTS:
        errors.append(
            f"effect class counts must be {SOCKET_COUNTS}, "
            f"got {dict(effect_classes)}"
        )
    return errors


def validate_output(
    glb_path: Path,
    manifest_path: Path,
    expected_source_sha: str,
) -> list[str]:
    errors: list[str] = []
    if not glb_path.is_file():
        errors.append(f"GLB missing: {glb_path}")
    elif glb_path.stat().st_size <= 0:
        errors.append(f"GLB empty: {glb_path}")
    errors.extend(validate_manifest(manifest_path, expected_source_sha))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate schema-4 nozzle-local source-exact fighter output."
    )
    parser.add_argument("--glb", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    errors = validate_output(args.glb, args.manifest, args.source_sha)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Schema-4 nozzle-local fighter contract validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
