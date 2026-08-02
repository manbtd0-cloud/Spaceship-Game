from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import bpy
from mathutils import Matrix, Vector

import export_small_sci_fi_fighter as base
from small_fighter_calibration import (
    COLLIDER_SIZE_GODOT,
    PLUME_GROUPS,
    SOURCE_FRAME_OBJECT,
    SOURCE_SHA256,
    UNIFORM_SCALE,
)
from source_exact_thruster_geometry import (
    EffectGeometryRecord,
    build_source_exact_thruster_effects,
)


def _socket_record_to_manifest(record: base.SocketRecord) -> dict[str, Any]:
    exhaust_godot = Vector(
        base.blender_to_godot_vector(record.exhaust_direction_blender)
    ).normalized()
    reaction_godot = -exhaust_godot
    return {
        "path": record.path,
        "class": record.socket_class,
        "source_object": record.source_object,
        "source_component": record.source_component,
        "position": base.blender_to_godot_vector(record.position_blender),
        "exhaust_direction": [round(float(value), 8) for value in exhaust_godot],
        "reaction_direction": [round(float(value), 8) for value in reaction_godot],
        "basis": base.blender_basis_to_godot_rows(record.basis_blender),
    }


def _effect_record_to_manifest(record: EffectGeometryRecord) -> dict[str, Any]:
    minimum = record.bounds_min_blender
    maximum = record.bounds_max_blender
    bounds_min_godot = [
        round(float(minimum.x), 8),
        round(float(minimum.z), 8),
        round(float(-maximum.y), 8),
    ]
    bounds_max_godot = [
        round(float(maximum.x), 8),
        round(float(maximum.z), 8),
        round(float(-minimum.y), 8),
    ]
    return {
        "path": record.path,
        "class": record.socket_class,
        "source_object": record.source_object,
        "source_component_indices": list(record.source_component_indices),
        "vertex_count": record.vertex_count,
        "face_count": record.face_count,
        "bounds_min": bounds_min_godot,
        "bounds_max": bounds_max_godot,
        "geometry_sha256": record.geometry_sha256,
        "identity_transform": True,
        "source_exact_geometry": True,
    }


def write_schema_three_manifest(
    path: Path,
    output_path: Path,
    source_path: Path,
    socket_records: list[base.SocketRecord],
    effect_records: list[EffectGeometryRecord],
    measured_dimensions_godot: Vector,
) -> None:
    manifest = {
        "schema_version": 3,
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
            round(float(component), 8) for component in measured_dimensions_godot
        ],
        "collider_size_godot_xyz": list(COLLIDER_SIZE_GODOT),
        "uniform_scale": round(UNIFORM_SCALE, 10),
        "removed_from_hull": sorted(PLUME_GROUPS),
        "thruster_visual_strategy": "source_exact_enginefire_geometry",
        "procedural_exhaust_geometry": False,
        "sockets": [
            _socket_record_to_manifest(record)
            for record in socket_records
        ],
        "thruster_effects": [
            _effect_record_to_manifest(record)
            for record in effect_records
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(f"Schema-3 fighter manifest missing or empty: {path}")


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

    collection = base.create_clean_collection()
    retained = base.duplicate_retained_geometry(source_frame_inverse, collection)
    hull = base.convert_and_join(retained)
    hull.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    base.validate_source_hull_bounds(hull)
    hull_bvh = base.build_hull_bvh(hull)
    socket_records = base.extract_all_sockets(source_frame_inverse, hull_bvh)
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
    effect_records = build_source_exact_thruster_effects(
        root,
        collection,
        source_frame_inverse,
    )

    base.export_glb(output_path, root)
    write_schema_three_manifest(
        manifest_path,
        output_path,
        source_path,
        socket_records,
        effect_records,
        measured_dimensions_godot,
    )

    if base.sha256_file(source_path) != actual_sha:
        raise RuntimeError("Source SHA changed during schema-3 canonical export")

    print(f"Source SHA validated: {actual_sha}")
    print("Cube-local hull dimensions validated")
    print(f"{len(socket_records)} physical thruster sockets extracted")
    print(f"{len(effect_records)} source-exact effect meshes exported")
    print("Visual strategy: exact EngineFire vertices and faces; no procedural cones")
    print(f"Canonical GLB: {output_path}")
    print(f"Schema-3 manifest: {manifest_path}")


if __name__ == "__main__":
    main()
