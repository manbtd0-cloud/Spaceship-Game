from __future__ import annotations

import argparse
import json
import math
import re
import struct
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
EXPECTED_LOCAL_EXHAUST_AXIS = (0.0, 0.0, -1.0)
MAXIMUM_RECONSTRUCTION_ERROR_M = 0.0001
GLB_PIVOT_TOLERANCE_M = 0.001

Matrix4 = tuple[
    tuple[float, float, float, float],
    tuple[float, float, float, float],
    tuple[float, float, float, float],
    tuple[float, float, float, float],
]
NodeEntry = tuple[str, dict[str, Any], Matrix4]


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


def _distance(
    left: tuple[float, float, float],
    right: tuple[float, float, float],
) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


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


def _load_manifest(path: Path) -> tuple[dict[str, Any] | None, list[str]]:
    if not path.is_file():
        return None, [f"manifest missing: {path}"]
    try:
        parsed = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return None, [f"manifest unreadable: {error}"]
    if not isinstance(parsed, dict):
        return None, ["manifest root must be an object"]
    return parsed, []


def validate_manifest(path: Path, expected_source_sha: str) -> list[str]:
    report, errors = _load_manifest(path)
    if report is None:
        return errors

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
        socket_path = str(socket.get("path", ""))
        socket_class = str(socket.get("class", ""))
        socket_paths.append(socket_path)
        socket_classes[socket_class] += 1
        position = _vector3(socket.get("position"), f"{label}.position", errors)
        if position is not None:
            socket_positions[socket_path] = position
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
        try:
            capacity = float(socket.get("capacity"))
        except (TypeError, ValueError):
            capacity = -1.0
        if not math.isfinite(capacity) or capacity <= 0.0:
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
        effect_class = str(effect.get("class", ""))
        effect_paths.append(effect_path)
        effect_socket_paths.append(socket_path)
        effect_classes[effect_class] += 1

        expected_socket = EXPECTED_EFFECT_TO_SOCKET.get(effect_path)
        if not socket_path:
            errors.append(f"{label}.socket_path is required")
        elif socket_path != expected_socket:
            errors.append(
                f"{label}.socket_path must be {expected_socket!r}, got {socket_path!r}"
            )
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
            and _distance(origin, socket_positions[socket_path]) > 1e-4
        ):
            errors.append(f"{label}.node_transform_origin must match socket position")

        local_axis = _vector3(
            effect.get("local_exhaust_axis"),
            f"{label}.local_exhaust_axis",
            errors,
        )
        if (
            local_axis is not None
            and _distance(local_axis, EXPECTED_LOCAL_EXHAUST_AXIS) > 1e-6
        ):
            errors.append(
                f"{label}.local_exhaust_axis must be "
                f"{list(EXPECTED_LOCAL_EXHAUST_AXIS)}"
            )

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

        try:
            reconstruction_error = float(
                effect.get("maximum_reconstruction_error_m")
            )
        except (TypeError, ValueError):
            reconstruction_error = math.inf
        if not math.isfinite(reconstruction_error) or reconstruction_error < 0.0:
            errors.append(
                f"{label}.maximum_reconstruction_error_m must be finite and non-negative"
            )
        elif reconstruction_error > MAXIMUM_RECONSTRUCTION_ERROR_M:
            errors.append(
                f"{label} reconstruction error {reconstruction_error:.9f} exceeds "
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


def _identity_matrix() -> Matrix4:
    return (
        (1.0, 0.0, 0.0, 0.0),
        (0.0, 1.0, 0.0, 0.0),
        (0.0, 0.0, 1.0, 0.0),
        (0.0, 0.0, 0.0, 1.0),
    )


def _multiply(left: Matrix4, right: Matrix4) -> Matrix4:
    return tuple(
        tuple(
            sum(left[row][axis] * right[axis][column] for axis in range(4))
            for column in range(4)
        )
        for row in range(4)
    )  # type: ignore[return-value]


def _node_matrix(node: dict[str, Any]) -> Matrix4:
    raw_matrix = node.get("matrix")
    if isinstance(raw_matrix, list) and len(raw_matrix) == 16:
        values = [float(value) for value in raw_matrix]
        return tuple(
            tuple(values[column * 4 + row] for column in range(4))
            for row in range(4)
        )  # type: ignore[return-value]

    translation = node.get("translation", [0.0, 0.0, 0.0])
    rotation = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    scale = node.get("scale", [1.0, 1.0, 1.0])
    if (
        not isinstance(translation, list)
        or len(translation) != 3
        or not isinstance(rotation, list)
        or len(rotation) != 4
        or not isinstance(scale, list)
        or len(scale) != 3
    ):
        raise ValueError("node TRS fields have invalid dimensions")

    tx, ty, tz = (float(value) for value in translation)
    x, y, z, w = (float(value) for value in rotation)
    sx, sy, sz = (float(value) for value in scale)
    quaternion_length = math.sqrt(x * x + y * y + z * z + w * w)
    if quaternion_length <= 1e-12:
        raise ValueError("node quaternion has zero length")
    x /= quaternion_length
    y /= quaternion_length
    z /= quaternion_length
    w /= quaternion_length
    rotation_rows = (
        (
            1.0 - 2.0 * (y * y + z * z),
            2.0 * (x * y - z * w),
            2.0 * (x * z + y * w),
        ),
        (
            2.0 * (x * y + z * w),
            1.0 - 2.0 * (x * x + z * z),
            2.0 * (y * z - x * w),
        ),
        (
            2.0 * (x * z - y * w),
            2.0 * (y * z + x * w),
            1.0 - 2.0 * (x * x + y * y),
        ),
    )
    scales = (sx, sy, sz)
    return (
        tuple(rotation_rows[0][column] * scales[column] for column in range(3))
        + (tx,),
        tuple(rotation_rows[1][column] * scales[column] for column in range(3))
        + (ty,),
        tuple(rotation_rows[2][column] * scales[column] for column in range(3))
        + (tz,),
        (0.0, 0.0, 0.0, 1.0),
    )


def _origin(matrix: Matrix4) -> tuple[float, float, float]:
    return tuple(matrix[axis][3] for axis in range(3))  # type: ignore[return-value]


def _load_glb_document(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("GLB is too small")
    magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("GLB magic is invalid")
    if version != 2:
        raise ValueError(f"GLB version must be 2, got {version}")
    if total_length != len(data):
        raise ValueError(
            f"GLB header length {total_length} does not match file size {len(data)}"
        )

    offset = 12
    while offset + 8 <= len(data):
        chunk_length, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk_end = offset + chunk_length
        if chunk_end > len(data):
            raise ValueError("GLB chunk exceeds file length")
        if chunk_type == b"JSON":
            try:
                document = json.loads(
                    data[offset:chunk_end]
                    .decode("utf-8")
                    .rstrip(" \t\r\n\0")
                )
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise ValueError(f"GLB JSON is unreadable: {error}") from error
            if not isinstance(document, dict):
                raise ValueError("GLB JSON root must be an object")
            return document
        offset = chunk_end
    raise ValueError("GLB JSON chunk is missing")


def _collect_glb_nodes(document: dict[str, Any]) -> list[NodeEntry]:
    nodes = document.get("nodes")
    scenes = document.get("scenes")
    if not isinstance(nodes, list) or not isinstance(scenes, list) or not scenes:
        raise ValueError("GLB must contain nodes and a scene")
    scene_index = int(document.get("scene", 0))
    if scene_index < 0 or scene_index >= len(scenes):
        raise ValueError("GLB default scene index is invalid")
    scene = scenes[scene_index]
    if not isinstance(scene, dict) or not isinstance(scene.get("nodes"), list):
        raise ValueError("GLB default scene has no root nodes")

    entries: list[NodeEntry] = []

    def visit(
        node_index: int,
        parent_path: str,
        parent_matrix: Matrix4,
        ancestors: set[int],
    ) -> None:
        if node_index in ancestors:
            raise ValueError("GLB node hierarchy contains a cycle")
        if node_index < 0 or node_index >= len(nodes):
            raise ValueError(f"GLB node index is invalid: {node_index}")
        node = nodes[node_index]
        if not isinstance(node, dict):
            raise ValueError(f"GLB node {node_index} must be an object")
        name = str(node.get("name", f"Node{node_index}"))
        path = f"{parent_path}/{name}" if parent_path else name
        world = _multiply(parent_matrix, _node_matrix(node))
        entries.append((path, node, world))
        children = node.get("children", [])
        if not isinstance(children, list):
            raise ValueError(f"GLB node children must be a list: {path}")
        next_ancestors = {*ancestors, node_index}
        for child in children:
            visit(int(child), path, world, next_ancestors)

    for root in scene["nodes"]:
        visit(int(root), "", _identity_matrix(), set())
    return entries


def _find_unique_glb_node(
    entries: list[NodeEntry],
    semantic_path: str,
) -> NodeEntry | None:
    matches = [
        entry
        for entry in entries
        if entry[0] == semantic_path or entry[0].endswith(f"/{semantic_path}")
    ]
    return matches[0] if len(matches) == 1 else None


def validate_glb_thruster_pivots(path: Path) -> list[str]:
    try:
        entries = _collect_glb_nodes(_load_glb_document(path))
    except (OSError, ValueError, TypeError) as error:
        return [f"GLB hierarchy unreadable: {error}"]

    errors: list[str] = []
    for effect_path, socket_path in sorted(EXPECTED_EFFECT_TO_SOCKET.items()):
        socket_entry = _find_unique_glb_node(entries, socket_path)
        pivot_entry = _find_unique_glb_node(entries, effect_path)
        if socket_entry is None:
            errors.append(f"GLB socket path missing or duplicated: {socket_path}")
            continue
        if pivot_entry is None:
            errors.append(f"GLB effect pivot path missing or duplicated: {effect_path}")
            continue
        if "mesh" in pivot_entry[1]:
            errors.append(f"GLB effect pivot must not own mesh geometry: {effect_path}")

        socket_origin = _origin(socket_entry[2])
        pivot_origin = _origin(pivot_entry[2])
        pivot_distance = _distance(socket_origin, pivot_origin)
        if pivot_distance > GLB_PIVOT_TOLERANCE_M:
            errors.append(
                "GLB effect pivot does not match socket: "
                f"{effect_path} distance={pivot_distance:.9f}"
            )

        leaf = effect_path.rsplit("/", 1)[-1]
        mesh_path = f"{effect_path}/{leaf}Mesh"
        mesh_entry = _find_unique_glb_node(entries, mesh_path)
        if mesh_entry is None or "mesh" not in mesh_entry[1]:
            errors.append(f"GLB effect mesh child missing: {mesh_path}")
            continue
        mesh_distance = _distance(pivot_origin, _origin(mesh_entry[2]))
        if mesh_distance > GLB_PIVOT_TOLERANCE_M:
            errors.append(
                "GLB effect mesh child is not at pivot origin: "
                f"{mesh_path} distance={mesh_distance:.9f}"
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
    else:
        errors.extend(validate_glb_thruster_pivots(glb_path))
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
