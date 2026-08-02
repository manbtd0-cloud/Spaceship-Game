from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

EXPECTED_RENDER_NAMES: tuple[str, ...] = (
    "front.png",
    "rear.png",
    "left.png",
    "right.png",
    "top.png",
    "bottom.png",
    "perspective_front.png",
    "perspective_rear.png",
)
EXPECTED_VIEW_NAMES: tuple[str, ...] = tuple(
    Path(filename).stem for filename in EXPECTED_RENDER_NAMES
)
FORBIDDEN_CALIBRATION_KEYS: tuple[str, ...] = (
    "confirmed_nose",
    "confirmed_up",
    "canonical_dimensions",
    "thruster_roles",
)
_SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_finite_vector(value: Any, length: int = 3) -> bool:
    if not isinstance(value, list) or len(value) != length:
        return False
    for component in value:
        if isinstance(component, bool) or not isinstance(component, (int, float)):
            return False
        if not math.isfinite(float(component)):
            return False
    return True


def _load_report(report_path: Path, errors: list[str]) -> dict[str, Any] | None:
    if not report_path.is_file():
        errors.append(f"Missing audit report: {report_path.name}")
        return None
    if report_path.stat().st_size <= 0:
        errors.append(f"Audit report is empty: {report_path.name}")
        return None
    try:
        value = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        errors.append(f"Audit report is invalid JSON: {exc}")
        return None
    if not isinstance(value, dict):
        errors.append("Audit report root must be a JSON object")
        return None
    return value


def validate_audit_directory(
    audit_dir: Path,
    expected_source_sha: str | None = None,
) -> list[str]:
    errors: list[str] = []
    audit_dir = audit_dir.resolve()

    if not audit_dir.is_dir():
        return [f"Audit directory does not exist: {audit_dir}"]

    for filename in EXPECTED_RENDER_NAMES:
        image_path = audit_dir / filename
        if not image_path.is_file():
            errors.append(f"Missing audit render: {filename}")
        elif image_path.stat().st_size <= 0:
            errors.append(f"Audit render is empty: {filename}")

    report = _load_report(audit_dir / "ship_audit.json", errors)
    if report is None:
        return errors

    if report.get("schema_version") != 1:
        errors.append("Audit report schema_version must equal 1")

    for key in FORBIDDEN_CALIBRATION_KEYS:
        if key in report:
            errors.append(f"Audit report must not claim unapproved calibration key: {key}")

    if report.get("calibration_status") != "unconfirmed":
        errors.append("Audit report calibration_status must be 'unconfirmed'")

    source = report.get("source")
    if not isinstance(source, dict):
        errors.append("Audit report source must be an object")
    else:
        source_path = source.get("path")
        if not isinstance(source_path, str) or not source_path.strip():
            errors.append("Audit report source.path must be a non-empty string")
        source_sha = source.get("sha256")
        if not isinstance(source_sha, str) or not _SHA256_PATTERN.fullmatch(source_sha):
            errors.append("Audit report source.sha256 must be 64 lowercase hexadecimal characters")
        elif expected_source_sha is not None and source_sha != expected_source_sha.lower():
            errors.append(
                "Audit report source SHA does not match the preserved source: "
                f"expected {expected_source_sha.lower()}, got {source_sha}"
            )
        blender_version = source.get("blender_version")
        if not isinstance(blender_version, str) or not blender_version.strip():
            errors.append("Audit report source.blender_version must be a non-empty string")

    bounds = report.get("aggregate_bounds")
    if not isinstance(bounds, dict):
        errors.append("Audit report aggregate_bounds must be an object")
    else:
        for key in ("minimum", "maximum", "center", "dimensions"):
            if not _is_finite_vector(bounds.get(key)):
                errors.append(f"Audit report aggregate_bounds.{key} must be a finite 3-vector")
        dimensions = bounds.get("dimensions")
        if _is_finite_vector(dimensions) and any(float(value) <= 0.0 for value in dimensions):
            errors.append("Audit report aggregate dimensions must be positive")

    for key in ("objects", "materials", "empties", "candidate_nozzle_names"):
        if not isinstance(report.get(key), list):
            errors.append(f"Audit report {key} must be a list")

    renders = report.get("renders")
    if not isinstance(renders, dict):
        errors.append("Audit report renders must be an object with eight render records")
        return errors

    actual_view_names = set(renders.keys())
    expected_view_names = set(EXPECTED_VIEW_NAMES)
    if actual_view_names != expected_view_names:
        missing = sorted(expected_view_names - actual_view_names)
        unexpected = sorted(actual_view_names - expected_view_names)
        details: list[str] = []
        if missing:
            details.append(f"missing={missing}")
        if unexpected:
            details.append(f"unexpected={unexpected}")
        errors.append(
            "Audit report must contain exactly eight render records"
            + (f" ({', '.join(details)})" if details else "")
        )

    for filename in EXPECTED_RENDER_NAMES:
        view_name = Path(filename).stem
        record = renders.get(view_name)
        if not isinstance(record, dict):
            continue
        if record.get("file") != filename:
            errors.append(f"Render record {view_name}.file must equal {filename}")
        if not _is_finite_vector(record.get("camera_location")):
            errors.append(f"Render record {view_name}.camera_location must be a finite 3-vector")
        if not _is_finite_vector(record.get("view_direction")):
            errors.append(f"Render record {view_name}.view_direction must be a finite 3-vector")
        projection = record.get("projection")
        expected_projection = "PERSP" if view_name.startswith("perspective_") else "ORTHO"
        if projection != expected_projection:
            errors.append(
                f"Render record {view_name}.projection must equal {expected_projection}"
            )

    return errors


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate canonical hero ship audit evidence.")
    parser.add_argument("--audit-dir", required=True, type=Path)
    parser.add_argument("--source", type=Path)
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    expected_source_sha: str | None = None
    if args.source is not None:
        if not args.source.is_file():
            print(f"Source file does not exist: {args.source}", file=sys.stderr)
            return 1
        expected_source_sha = sha256_file(args.source)

    errors = validate_audit_directory(args.audit_dir, expected_source_sha)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("Hero ship audit contract valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
