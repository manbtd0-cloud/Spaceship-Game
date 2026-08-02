from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

CANONICAL_DIAMETER_METERS = 100.0
DIMENSION_TOLERANCE = 0.05


@dataclass(frozen=True)
class AsteroidFamilySpec:
    source_id: str
    canonical_name: str
    source_path: Path
    source_sha256: str
    output_path: Path
    manifest_path: Path
    provenance_status: str
    fixture_bytes: bytes

    @property
    def fixture_sha256(self) -> str:
        return hashlib.sha256(self.fixture_bytes).hexdigest()


FAMILIES: dict[str, AsteroidFamilySpec] = {
    "bennu": AsteroidFamilySpec(
        source_id="bennu",
        canonical_name="Bennu",
        source_path=Path(
            "assets/source/environment/asteroids/bennu/asteroid_bennu_textured.blend"
        ),
        source_sha256="e01e7aa3364d8f7dc91aeaf4149b8aa82111f986467bec00ed7fa9ecd2f0bd5a",
        output_path=Path("assets/runtime/environment/asteroids/bennu.glb"),
        manifest_path=Path("assets/runtime/environment/asteroids/bennu.manifest.json"),
        provenance_status="development_only_pending_source_license",
        fixture_bytes=b"fixture-bennu",
    ),
    "eros": AsteroidFamilySpec(
        source_id="eros",
        canonical_name="Eros",
        source_path=Path(
            "assets/source/environment/asteroids/eros/asteroid_eros_true_color.glb"
        ),
        source_sha256="73994d18c12b696d273abdb2c79d132f755ada014dde972a8ba3b480c7eb95ef",
        output_path=Path("assets/runtime/environment/asteroids/eros.glb"),
        manifest_path=Path("assets/runtime/environment/asteroids/eros.manifest.json"),
        provenance_status="cc_by_4_0_attributed",
        fixture_bytes=b"fixture-eros",
    ),
    "legacy_a": AsteroidFamilySpec(
        source_id="legacy_a",
        canonical_name="LegacyA",
        source_path=Path(
            "assets/source/environment/asteroids/legacy_a/asteroid_legacy_a.blend"
        ),
        source_sha256="8bfa230c83fa9ebeea952b21d2a64d96aa81599413c907fd994372df88185032",
        output_path=Path("assets/runtime/environment/asteroids/legacy_a.glb"),
        manifest_path=Path("assets/runtime/environment/asteroids/legacy_a.manifest.json"),
        provenance_status="development_only_pending_source_license",
        fixture_bytes=b"fixture-legacy-a",
    ),
    "legacy_b": AsteroidFamilySpec(
        source_id="legacy_b",
        canonical_name="LegacyB",
        source_path=Path(
            "assets/source/environment/asteroids/legacy_b/asteroid_legacy_b.blend"
        ),
        source_sha256="5012f846592e69b955bdae10d5e98ac43eb5116541ddbfdb0d3cd489b16035d6",
        output_path=Path("assets/runtime/environment/asteroids/legacy_b.glb"),
        manifest_path=Path("assets/runtime/environment/asteroids/legacy_b.manifest.json"),
        provenance_status="development_only_pending_source_license",
        fixture_bytes=b"fixture-legacy-b",
    ),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_sha(specification: AsteroidFamilySpec, use_fixture_hashes: bool) -> str:
    return (
        specification.fixture_sha256
        if use_fixture_hashes
        else specification.source_sha256
    )


def validate_sources(repo_root: Path, use_fixture_hashes: bool = False) -> list[str]:
    errors: list[str] = []
    for source_id, specification in FAMILIES.items():
        path = repo_root / specification.source_path
        if not path.is_file():
            errors.append(f"{source_id}: source missing: {path}")
            continue
        if path.stat().st_size <= 0:
            errors.append(f"{source_id}: source empty: {path}")
            continue
        actual = sha256_file(path)
        expected = expected_sha(specification, use_fixture_hashes)
        if actual.lower() != expected.lower():
            errors.append(
                f"{source_id}: source SHA mismatch: expected {expected}, got {actual}"
            )
    return errors


def _number(value: Any, label: str, errors: list[str]) -> float | None:
    try:
        result = float(value)
    except (TypeError, ValueError):
        errors.append(f"{label} must be numeric")
        return None
    if not math.isfinite(result):
        errors.append(f"{label} must be finite")
        return None
    return result


def _vector3(value: Any, label: str, errors: list[str]) -> tuple[float, float, float] | None:
    if not isinstance(value, list) or len(value) != 3:
        errors.append(f"{label} must contain three numbers")
        return None
    converted: list[float] = []
    for index, component in enumerate(value):
        number = _number(component, f"{label}[{index}]", errors)
        if number is None:
            return None
        converted.append(number)
    return tuple(converted)


def validate_manifest(
    path: Path,
    specification: AsteroidFamilySpec,
    use_fixture_hashes: bool = False,
) -> list[str]:
    errors: list[str] = []
    prefix = specification.source_id
    if not path.is_file():
        return [f"{prefix}: manifest missing: {path}"]
    if path.stat().st_size <= 0:
        return [f"{prefix}: manifest empty: {path}"]
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return [f"{prefix}: manifest unreadable: {error}"]

    if manifest.get("schema_version") != 1:
        errors.append(f"{prefix}: schema_version must be 1")
    if manifest.get("source_id") != specification.source_id:
        errors.append(f"{prefix}: source_id mismatch")
    if str(manifest.get("source_sha256", "")).lower() != expected_sha(
        specification,
        use_fixture_hashes,
    ).lower():
        errors.append(f"{prefix}: source SHA mismatch")

    frame = manifest.get("canonical_frame")
    if not isinstance(frame, dict):
        errors.append(f"{prefix}: canonical_frame missing")
    else:
        expected_frame = {
            "godot_right": "+X",
            "godot_forward": "-Z",
            "godot_up": "+Y",
            "root_identity": True,
        }
        for key, expected in expected_frame.items():
            if frame.get(key) != expected:
                errors.append(f"{prefix}: canonical_frame.{key} must be {expected!r}")

    diameter = _number(
        manifest.get("canonical_diameter_meters"),
        f"{prefix}: canonical diameter",
        errors,
    )
    if diameter is not None and abs(diameter - CANONICAL_DIAMETER_METERS) > 1e-6:
        errors.append(
            f"{prefix}: canonical diameter must be {CANONICAL_DIAMETER_METERS}"
        )

    dimensions = _vector3(
        manifest.get("dimensions_godot_xyz"),
        f"{prefix}: dimensions_godot_xyz",
        errors,
    )
    if dimensions is not None:
        if min(dimensions) <= 0.0:
            errors.append(f"{prefix}: all dimensions must be positive")
        if abs(max(dimensions) - CANONICAL_DIAMETER_METERS) > DIMENSION_TOLERANCE:
            errors.append(
                f"{prefix}: longest dimension must equal canonical diameter"
            )

    visual_vertices = _number(
        manifest.get("visual_vertices"),
        f"{prefix}: visual_vertices",
        errors,
    )
    visual_faces = _number(
        manifest.get("visual_faces"),
        f"{prefix}: visual_faces",
        errors,
    )
    proxy_vertices = _number(
        manifest.get("proxy_vertices"),
        f"{prefix}: proxy_vertices",
        errors,
    )
    proxy_faces = _number(
        manifest.get("proxy_faces"),
        f"{prefix}: proxy_faces",
        errors,
    )
    for label, value in (
        ("visual_vertices", visual_vertices),
        ("visual_faces", visual_faces),
        ("proxy_vertices", proxy_vertices),
        ("proxy_faces", proxy_faces),
    ):
        if value is not None and value <= 0.0:
            errors.append(f"{prefix}: {label} must be positive")
    if (
        proxy_faces is not None
        and visual_faces is not None
        and proxy_faces >= visual_faces
    ):
        errors.append(f"{prefix}: proxy_faces must be lower than visual_faces")
    if (
        proxy_vertices is not None
        and visual_vertices is not None
        and proxy_vertices >= visual_vertices
    ):
        errors.append(f"{prefix}: proxy_vertices must be lower than visual_vertices")

    material_count = _number(
        manifest.get("material_count"),
        f"{prefix}: material_count",
        errors,
    )
    if material_count is not None and material_count < 0.0:
        errors.append(f"{prefix}: material_count must not be negative")
    if not isinstance(manifest.get("texture_present"), bool):
        errors.append(f"{prefix}: texture_present must be boolean")
    if not isinstance(manifest.get("removed_objects"), list):
        errors.append(f"{prefix}: removed_objects must be a list")
    if manifest.get("provenance_status") != specification.provenance_status:
        errors.append(f"{prefix}: provenance_status mismatch")
    return errors


def validate_outputs(repo_root: Path, use_fixture_hashes: bool = False) -> list[str]:
    errors: list[str] = []
    for source_id, specification in FAMILIES.items():
        glb_path = repo_root / specification.output_path
        if not glb_path.is_file():
            errors.append(f"{source_id}: GLB missing: {glb_path}")
        elif glb_path.stat().st_size <= 0:
            errors.append(f"{source_id}: GLB empty: {glb_path}")
        errors.extend(
            validate_manifest(
                repo_root / specification.manifest_path,
                specification,
                use_fixture_hashes,
            )
        )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the canonical asteroid pack.")
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--sources-only", action="store_true")
    args = parser.parse_args()

    root = args.repo_root.resolve()
    errors = validate_sources(root)
    if not args.sources_only:
        errors.extend(validate_outputs(root))
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        "Asteroid source contract passed."
        if args.sources_only
        else "Canonical four-family asteroid pack contract passed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
