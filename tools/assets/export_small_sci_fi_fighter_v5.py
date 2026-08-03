from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import bpy
from mathutils import Matrix, Vector

import export_small_sci_fi_fighter as base
import export_small_sci_fi_fighter_v4 as schema4
from primary_weapon_muzzle_extraction import extract_primary_muzzles
from primary_weapon_muzzle_geometry import MuzzleRecord
from primary_weapon_muzzle_transform import (
    canonical_basis_to_blender_rows,
    canonical_origin_to_blender,
)
from small_fighter_calibration import (
    COLLIDER_SIZE_GODOT,
    HULL_CENTER_LOCAL,
    PLUME_GROUPS,
    SOURCE_FRAME_OBJECT,
    SOURCE_SHA256,
    UNIFORM_SCALE,
)
from source_exact_thruster_geometry import (
    NozzleLocalEffectGeometryRecord,
    build_nozzle_local_thruster_effects,
)


def _record_to_blender_transform(record: MuzzleRecord) -> tuple[Vector, Matrix]:
    origin = Vector(canonical_origin_to_blender(record.canonical_origin))
    basis = Matrix(
        canonical_basis_to_blender_rows(record.canonical_basis_rows)
    ).to_4x4()
    return origin, basis


def _muzzle_record_to_manifest(record: MuzzleRecord) -> dict[str, Any]:
    return {
        "path": record.path,
        "side": record.side,
        "source_object": record.source_object,
        "source_material": record.source_material,
        "source_component": record.source_component,
        "source_vertex_indices": list(record.source_vertex_indices),
        "origin": list(record.canonical_origin),
        "basis": [list(row) for row in record.canonical_basis_rows],
        "forward": list(record.canonical_forward),
        "extraction_error_m": round(record.extraction_error_m, 12),
    }


def create_primary_muzzle_hierarchy(
    root: bpy.types.Object,
    collection: bpy.types.Collection,
    records: list[MuzzleRecord],
) -> dict[str, bpy.types.Object]:
    if len(records) != 2:
        raise RuntimeError(
            f"Expected exactly two primary muzzle records, got {len(records)}"
        )
    nodes: dict[str, bpy.types.Object] = {}
    weapons = base.create_empty("Weapons", root, collection)
    primary = base.create_empty("Primary", weapons, collection)
    nodes["Weapons"] = weapons
    nodes["Weapons/Primary"] = primary

    for record in records:
        leaf = record.path.rsplit("/", 1)[-1]
        origin, basis = _record_to_blender_transform(record)
        node = base.create_empty(leaf, primary, collection)
        node.location = origin
        node.rotation_mode = "QUATERNION"
        node.rotation_quaternion = basis.to_quaternion()
        node.scale = Vector((1.0, 1.0, 1.0))
        node["weapon_socket"] = "primary"
        node["side"] = record.side
        node["source_object"] = record.source_object
        node["source_material"] = record.source_material
        node["source_component"] = record.source_component
        node["source_vertex_indices"] = list(record.source_vertex_indices)
        nodes[record.path] = node

    expected = {
        "Weapons/Primary/LeftMuzzle",
        "Weapons/Primary/RightMuzzle",
    }
    if set(nodes) & expected != expected:
        raise RuntimeError("Primary muzzle hierarchy is incomplete")
    return nodes


def write_schema_five_manifest(
    path: Path,
    output_path: Path,
    source_path: Path,
    socket_records: list[base.SocketRecord],
    effect_records: list[NozzleLocalEffectGeometryRecord],
    muzzle_records: list[MuzzleRecord],
    measured_dimensions_godot: Vector,
) -> None:
    manifest = {
        "schema_version": 5,
        "asset": "Small Sci-Fi Fighter",
        "development_only": True,
        "license_evidence_reviewed": False,
        "source_path": source_path.as_posix(),
        "source_sha256": SOURCE_SHA256,
        "output_path": output_path.as_posix(),
        "blender_version": bpy.app.version_string,
        "source_frame_object": SOURCE_FRAME_OBJECT,
        "canonical_frame": {
            "godot_right": "+X",
            "godot_forward": "-Z",
            "godot_up": "+Y",
            "root_identity": True,
        },
        "dimensions_godot_xyz": [
            round(float(component), 8)
            for component in measured_dimensions_godot
        ],
        "collider_size_godot_xyz": list(COLLIDER_SIZE_GODOT),
        "uniform_scale": round(UNIFORM_SCALE, 10),
        "removed_from_hull": sorted(PLUME_GROUPS),
        "thruster_visual_strategy": (
            "source_exact_nozzle_local_enginefire_geometry"
        ),
        "procedural_exhaust_geometry": False,
        "sockets": [
            schema4._socket_record_to_manifest(record)
            for record in socket_records
        ],
        "thruster_effects": [
            schema4._effect_record_to_manifest(record)
            for record in effect_records
        ],
        "primary_muzzles": [
            _muzzle_record_to_manifest(record)
            for record in muzzle_records
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )
    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(f"Schema-5 fighter manifest missing or empty: {path}")


def main() -> None:
    args = base.parse_args()
    output_path = args.output.resolve()
    manifest_path = args.manifest.resolve()
    source_path = Path(bpy.data.filepath).resolve()
    if not source_path.is_file():
        raise RuntimeError(f"Blender source file unavailable: {source_path}")
    actual_sha = base.sha256_file(source_path)
    if actual_sha != SOURCE_SHA256:
        raise RuntimeError(f"Unexpected source SHA: {actual_sha}")

    source_frame = bpy.data.objects.get(SOURCE_FRAME_OBJECT)
    if source_frame is None or source_frame.type != "MESH":
        raise RuntimeError("Approved source frame Cube is missing")
    source_frame_inverse = source_frame.matrix_world.inverted_safe()

    muzzle_records = extract_primary_muzzles(
        source_frame_inverse,
        HULL_CENTER_LOCAL,
        UNIFORM_SCALE,
    )
    if len(muzzle_records) != 2:
        raise RuntimeError("Source extraction did not produce exactly two muzzles")
    maximum_muzzle_error = max(
        record.extraction_error_m for record in muzzle_records
    )
    if maximum_muzzle_error > 0.0001:
        raise RuntimeError(
            "Primary muzzle extraction error exceeds 0.0001 m: "
            f"{maximum_muzzle_error:.12f}"
        )

    collection = base.create_clean_collection()
    retained = base.duplicate_retained_geometry(
        source_frame_inverse,
        collection,
    )
    hull = base.convert_and_join(retained)
    hull.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    base.validate_source_hull_bounds(hull)
    hull_bvh = base.build_hull_bvh(hull)
    socket_records = base.extract_all_sockets(
        source_frame_inverse,
        hull_bvh,
    )
    base.center_and_scale_hull(hull)

    final_minimum, final_maximum = base.object_world_bounds(hull)
    final_dimensions_blender = final_maximum - final_minimum
    measured_dimensions_godot = Vector(
        (
            final_dimensions_blender.x,
            final_dimensions_blender.z,
            final_dimensions_blender.y,
        )
    )

    root = base.create_empty("SmallSciFiFighter", None, collection)
    root.matrix_world = Matrix.Identity(4)
    hull.parent = root
    hull.matrix_parent_inverse = Matrix.Identity(4)
    base.create_socket_hierarchy(root, collection, socket_records)
    effect_records = build_nozzle_local_thruster_effects(
        root,
        collection,
        source_frame_inverse,
        socket_records,
    )
    create_primary_muzzle_hierarchy(root, collection, muzzle_records)

    base.export_glb(output_path, root)
    write_schema_five_manifest(
        manifest_path,
        output_path,
        source_path,
        socket_records,
        effect_records,
        muzzle_records,
        measured_dimensions_godot,
    )

    if base.sha256_file(source_path) != actual_sha:
        raise RuntimeError("Source SHA changed during schema-5 canonical export")

    maximum_thruster_error = max(
        record.maximum_reconstruction_error_m
        for record in effect_records
    )
    print(f"Source SHA validated: {actual_sha}")
    print("Cube-local hull dimensions validated")
    print(f"{len(socket_records)} physical thruster sockets extracted")
    print(f"{len(effect_records)} nozzle-local effect meshes exported")
    print(f"{len(muzzle_records)} source-derived primary muzzle nodes exported")
    for record in muzzle_records:
        print(
            f"Primary muzzle: {record.path} source={record.source_object} "
            f"material={record.source_material} "
            f"component={record.source_component} "
            f"vertices={len(record.source_vertex_indices)}"
        )
    print(
        "Visual strategy: exact EngineFire geometry in verified nozzle-local "
        "coordinates"
    )
    print(
        f"Maximum thruster reconstruction error: "
        f"{maximum_thruster_error:.12f} m"
    )
    print(
        f"Maximum muzzle extraction error: "
        f"{maximum_muzzle_error:.12f} m"
    )
    print(f"Canonical GLB: {output_path}")
    print(f"Schema-5 manifest: {manifest_path}")


if __name__ == "__main__":
    main()
