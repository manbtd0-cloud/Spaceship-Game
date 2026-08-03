from __future__ import annotations

import argparse
import json
import math
import sys
import tempfile
from pathlib import Path
from typing import Any

try:
    from . import canonical_fighter_contract_v4 as base
except ImportError:  # pragma: no cover - script execution path
    import canonical_fighter_contract_v4 as base

EXPECTED_SOCKET_PATHS = base.EXPECTED_SOCKET_PATHS
EXPECTED_EFFECT_TO_SOCKET = base.EXPECTED_EFFECT_TO_SOCKET
EXPECTED_EFFECT_PATHS = base.EXPECTED_EFFECT_PATHS
EXPECTED_PRIMARY_MUZZLES = {
    "Weapons/Primary/LeftMuzzle": "left",
    "Weapons/Primary/RightMuzzle": "right",
}
MAXIMUM_MUZZLE_EXTRACTION_ERROR_M = 0.0001
GLB_MUZZLE_TOLERANCE_M = 0.001
CANONICAL_FORWARD = (0.0, 0.0, -1.0)

Point3 = tuple[float, float, float]


def _load_manifest(path: Path) -> tuple[dict[str, Any] | None, list[str]]:
    if not path.is_file():
        return None, [f"manifest missing: {path}"]
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return None, [f"manifest unreadable: {error}"]
    if not isinstance(value, dict):
        return None, ["manifest root must be an object"]
    return value, []


def _vector3(value: Any, label: str, errors: list[str]) -> Point3 | None:
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
    return result  # type: ignore[return-value]


def _length(value: Point3) -> float:
    return math.sqrt(sum(component * component for component in value))


def _dot(left: Point3, right: Point3) -> float:
    return sum(a * b for a, b in zip(left, right))


def _distance(left: Point3, right: Point3) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def _determinant(rows: tuple[Point3, Point3, Point3]) -> float:
    a, b, c = rows
    return (
        a[0] * (b[1] * c[2] - b[2] * c[1])
        - a[1] * (b[0] * c[2] - b[2] * c[0])
        + a[2] * (b[0] * c[1] - b[1] * c[0])
    )


def _basis(
    value: Any,
    label: str,
    errors: list[str],
) -> tuple[Point3, Point3, Point3] | None:
    if not isinstance(value, list) or len(value) != 3:
        errors.append(f"{label} must contain three rows")
        return None
    parsed: list[Point3] = []
    for index, row in enumerate(value):
        item = _vector3(row, f"{label}[{index}]", errors)
        if item is None:
            return None
        parsed.append(item)
    rows = (parsed[0], parsed[1], parsed[2])
    for row in rows:
        if abs(_length(row) - 1.0) > 0.0001:
            errors.append(f"{label} rows must be unit length")
    for left in range(3):
        for right in range(left + 1, 3):
            if abs(_dot(rows[left], rows[right])) > 0.0001:
                errors.append(f"{label} rows must be orthogonal")
    if _determinant(rows) <= 0.0:
        errors.append(f"{label} determinant must be positive")
    return rows


def _validate_primary_muzzles(report: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    primary_muzzles = report.get("primary_muzzles")
    if not isinstance(primary_muzzles, list):
        return ["primary_muzzles must be a list containing exactly two records"]
    if len(primary_muzzles) != 2:
        errors.append(
            "primary_muzzles must contain exactly two primary muzzle records"
        )

    paths: list[str] = []
    sides: list[str] = []
    origins: dict[str, Point3] = {}
    used_vertices: set[tuple[str, int]] = set()
    for index, muzzle in enumerate(primary_muzzles):
        label = f"primary_muzzles[{index}]"
        if not isinstance(muzzle, dict):
            errors.append(f"{label} must be an object")
            continue
        path_value = str(muzzle.get("path", ""))
        side_value = str(muzzle.get("side", ""))
        paths.append(path_value)
        sides.append(side_value)
        expected_side = EXPECTED_PRIMARY_MUZZLES.get(path_value)
        if expected_side is None:
            errors.append(f"{label}.path is unexpected: {path_value!r}")
        elif side_value != expected_side:
            errors.append(
                f"{label}.side must be {expected_side!r}, got {side_value!r}"
            )

        source_object = str(muzzle.get("source_object", "")).strip()
        if not source_object:
            errors.append(f"{label}.source_object is required")

        indices = muzzle.get("source_vertex_indices")
        if (
            not isinstance(indices, list)
            or not indices
            or any(not isinstance(value, int) or value < 0 for value in indices)
            or len(set(indices)) != len(indices)
        ):
            errors.append(
                f"{label}.source_vertex_indices must be unique non-negative integers"
            )
        else:
            for value in indices:
                key = (source_object, value)
                if key in used_vertices:
                    errors.append(
                        f"{label}.source_vertex_indices overlap another muzzle"
                    )
                used_vertices.add(key)

        origin = _vector3(muzzle.get("origin"), f"{label}.origin", errors)
        if origin is not None:
            origins[path_value] = origin
            if side_value == "left" and origin[0] >= 0.0:
                errors.append(f"{label}.origin must lie left of centerline")
            if side_value == "right" and origin[0] <= 0.0:
                errors.append(f"{label}.origin must lie right of centerline")

        _basis(muzzle.get("basis"), f"{label}.basis", errors)
        forward = _vector3(muzzle.get("forward"), f"{label}.forward", errors)
        if forward is not None:
            if abs(_length(forward) - 1.0) > 0.0001:
                errors.append(f"{label}.forward must be unit length")
            if _dot(forward, CANONICAL_FORWARD) < 0.95:
                errors.append(
                    f"{label}.forward must align with canonical fighter-forward"
                )

        try:
            extraction_error = float(muzzle.get("extraction_error_m"))
        except (TypeError, ValueError):
            extraction_error = math.inf
        if (
            not math.isfinite(extraction_error)
            or extraction_error < 0.0
            or extraction_error > MAXIMUM_MUZZLE_EXTRACTION_ERROR_M
        ):
            errors.append(
                f"{label}.extraction_error_m must be within [0.0, "
                f"{MAXIMUM_MUZZLE_EXTRACTION_ERROR_M}]"
            )

    if set(paths) != set(EXPECTED_PRIMARY_MUZZLES) or len(paths) != 2:
        errors.append(
            "primary muzzle paths must be exactly LeftMuzzle and RightMuzzle"
        )
    if set(sides) != {"left", "right"} or len(sides) != 2:
        errors.append("primary muzzle sides must contain exactly left and right")

    left = origins.get("Weapons/Primary/LeftMuzzle")
    right = origins.get("Weapons/Primary/RightMuzzle")
    if left is not None and right is not None:
        if (
            abs(abs(left[0]) - abs(right[0])) > 0.15
            or abs(left[1] - right[1]) > 0.15
            or abs(left[2] - right[2]) > 0.15
        ):
            errors.append("primary muzzle origins must form one mirrored pair")
    return errors


def validate_manifest(path: Path, expected_source_sha: str) -> list[str]:
    report, errors = _load_manifest(path)
    if report is None:
        return errors
    if report.get("schema_version") != 5:
        errors.append("manifest schema_version must be 5")
    errors.extend(_validate_primary_muzzles(report))

    base_report = dict(report)
    base_report["schema_version"] = 4
    base_report.pop("primary_muzzles", None)
    with tempfile.TemporaryDirectory() as temporary:
        base_path = Path(temporary) / "schema-four-view.json"
        base_path.write_text(json.dumps(base_report), encoding="utf-8")
        errors.extend(base.validate_manifest(base_path, expected_source_sha))
    return errors


def _matrix_origin(matrix: Any) -> Point3:
    return (
        float(matrix[0][3]),
        float(matrix[1][3]),
        float(matrix[2][3]),
    )


def validate_glb_primary_muzzles(
    glb_path: Path,
    manifest_path: Path,
) -> list[str]:
    report, errors = _load_manifest(manifest_path)
    if report is None:
        return errors
    try:
        entries = base._collect_glb_nodes(base._load_glb_document(glb_path))
    except (OSError, ValueError, TypeError, KeyError, IndexError) as error:
        return [f"GLB hierarchy unreadable: {error}"]

    records = report.get("primary_muzzles", [])
    records_by_path = {
        str(record.get("path", "")): record
        for record in records
        if isinstance(record, dict)
    }
    for path in sorted(EXPECTED_PRIMARY_MUZZLES):
        entry = base._find_unique_glb_node(entries, path)
        if entry is None:
            errors.append(f"GLB primary muzzle path missing or duplicated: {path}")
            continue
        if "mesh" in entry[1]:
            errors.append(f"GLB primary muzzle must be an empty Node3D: {path}")
        record = records_by_path.get(path)
        if record is None:
            continue
        origin = _vector3(record.get("origin"), f"{path}.origin", errors)
        if origin is not None:
            distance = _distance(origin, _matrix_origin(entry[2]))
            if distance > GLB_MUZZLE_TOLERANCE_M:
                errors.append(
                    f"GLB primary muzzle origin mismatch: {path} "
                    f"distance={distance:.9f}"
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
        errors.extend(base.validate_glb_thruster_pivots(glb_path))
        errors.extend(validate_glb_primary_muzzles(glb_path, manifest_path))
    errors.extend(validate_manifest(manifest_path, expected_source_sha))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate schema-5 fighter output with source-derived muzzles."
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
    print("Schema-5 fighter contract validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
