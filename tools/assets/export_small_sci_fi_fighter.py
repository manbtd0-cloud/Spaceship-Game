from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


TARGET_BLENDER_DIMENSIONS = Vector((7.2, 10.8, 4.2))
EXPECTED_GODOT_ENVELOPE = Vector((7.2, 4.2, 10.8))
DIMENSION_TOLERANCE = 0.01
OUTPUT_PATH: Path | None = None


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(
        description="Normalize and export the Shattered Orbit Small Sci-Fi Fighter."
    )
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    return parser.parse_args(argv)


def visible_meshes() -> list[bpy.types.Object]:
    meshes: list[bpy.types.Object] = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.hide_render or obj.hide_get():
            continue
        try:
            visible = obj.visible_get()
        except RuntimeError:
            visible = True
        if visible:
            meshes.append(obj)
    return meshes


def world_bounds(
    objects: list[bpy.types.Object],
) -> tuple[Vector, Vector]:
    if not objects:
        raise RuntimeError("Cannot calculate bounds without mesh objects")

    minimum = Vector((float("inf"), float("inf"), float("inf")))
    maximum = Vector((float("-inf"), float("-inf"), float("-inf")))
    for obj in objects:
        for corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(corner)
            minimum.x = min(minimum.x, world_corner.x)
            minimum.y = min(minimum.y, world_corner.y)
            minimum.z = min(minimum.z, world_corner.z)
            maximum.x = max(maximum.x, world_corner.x)
            maximum.y = max(maximum.y, world_corner.y)
            maximum.z = max(maximum.z, world_corner.z)
    return minimum, maximum


def remove_non_runtime_objects() -> None:
    retained = visible_meshes()
    retained_set = set(retained)
    retained_transforms = {
        obj.name: obj.matrix_world.copy()
        for obj in retained
    }

    for obj in list(bpy.data.objects):
        if obj not in retained_set:
            bpy.data.objects.remove(obj, do_unlink=True)

    for obj in retained:
        if obj.name in bpy.data.objects:
            obj.matrix_world = retained_transforms[obj.name]


def _ensure_object_mode() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def _select_only(objects: list[bpy.types.Object]) -> None:
    _ensure_object_mode()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def join_meshes(objects: list[bpy.types.Object]) -> bpy.types.Object:
    if not objects:
        raise RuntimeError("No visible mesh geometry was found in the source file")

    for obj in objects:
        if obj.data is not None and obj.data.library is not None:
            obj.data = obj.data.copy()

    _select_only(objects)
    conversion = bpy.ops.object.convert(target="MESH")
    if "FINISHED" not in conversion:
        raise RuntimeError(f"Failed to apply mesh modifiers: {conversion}")

    converted = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if not converted:
        raise RuntimeError("Mesh conversion removed all source geometry")

    bpy.context.view_layer.objects.active = converted[0]
    if len(converted) > 1:
        joined = bpy.ops.object.join()
        if "FINISHED" not in joined:
            raise RuntimeError(f"Failed to join source meshes: {joined}")

    mesh = bpy.context.view_layer.objects.active
    if mesh is None or mesh.type != "MESH":
        raise RuntimeError("Joined fighter mesh was not created")

    mesh.name = "SmallSciFiFighterMesh"
    mesh.data.name = "SmallSciFiFighterMesh"
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    mesh.data.validate(clean_customdata=False)
    mesh.data.update()
    return mesh


def normalize_source_axes(mesh: bpy.types.Object) -> None:
    _select_only([mesh])
    mesh.rotation_euler.z += math.pi
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def fit_and_center(mesh: bpy.types.Object) -> Vector:
    minimum, maximum = world_bounds([mesh])
    dimensions = maximum - minimum
    if min(dimensions) <= 0.0 or min(TARGET_BLENDER_DIMENSIONS) <= 0.0:
        raise RuntimeError(
            f"Invalid fighter or target dimensions: source={tuple(dimensions)}, "
            f"target={tuple(TARGET_BLENDER_DIMENSIONS)}"
        )

    uniform_scale = min(
        TARGET_BLENDER_DIMENSIONS.x / dimensions.x,
        TARGET_BLENDER_DIMENSIONS.y / dimensions.y,
        TARGET_BLENDER_DIMENSIONS.z / dimensions.z,
    )
    if uniform_scale <= 0.0:
        raise RuntimeError(f"Invalid calculated scale: {uniform_scale}")

    print(f"Pre-scale dimensions (Blender XYZ): {tuple(round(v, 6) for v in dimensions)}")
    print(f"Uniform scale factor: {uniform_scale:.9f}")

    _select_only([mesh])
    mesh.scale = Vector((uniform_scale, uniform_scale, uniform_scale))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    minimum, maximum = world_bounds([mesh])
    center = (minimum + maximum) * 0.5
    mesh.location -= center
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")

    minimum, maximum = world_bounds([mesh])
    final_dimensions = maximum - minimum
    for axis, final_value, target_value in zip(
        "XYZ", final_dimensions, TARGET_BLENDER_DIMENSIONS
    ):
        if final_value > target_value + DIMENSION_TOLERANCE:
            raise RuntimeError(
                f"Final {axis} dimension {final_value:.6f} exceeds "
                f"target {target_value:.6f}"
            )

    print(
        "Final dimensions (Blender XYZ): "
        f"{tuple(round(v, 6) for v in final_dimensions)}"
    )
    return final_dimensions


def create_axis_markers(root: bpy.types.Object) -> None:
    forward = bpy.data.objects.new("ForwardMarker", None)
    forward.empty_display_type = "ARROWS"
    forward.empty_display_size = 0.35
    forward.location = Vector((0.0, 1.0, 0.0))
    forward.parent = root
    bpy.context.collection.objects.link(forward)

    up = bpy.data.objects.new("UpMarker", None)
    up.empty_display_type = "ARROWS"
    up.empty_display_size = 0.35
    up.location = Vector((0.0, 0.0, 1.0))
    up.parent = root
    bpy.context.collection.objects.link(up)


def export_glb(output_path: Path, root: bpy.types.Object) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    hierarchy = [root, *list(root.children_recursive)]
    _select_only(hierarchy)
    bpy.context.view_layer.objects.active = root

    result = bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_normals=True,
        export_tangents=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"glTF export failed: {result}")
    if not output_path.is_file() or output_path.stat().st_size == 0:
        raise RuntimeError(f"GLB output was not created: {output_path}")


def write_manifest(
    path: Path,
    source_path: Path,
    dimensions: Vector,
) -> None:
    if OUTPUT_PATH is None:
        raise RuntimeError("Runtime output path was not initialized")

    path.parent.mkdir(parents=True, exist_ok=True)
    source_sha = hashlib.sha256(source_path.read_bytes()).hexdigest()
    godot_dimensions = Vector((dimensions.x, dimensions.z, dimensions.y))
    manifest = {
        "asset": "Small Sci-Fi Fighter",
        "development_only": True,
        "license_evidence_reviewed": False,
        "source_path": source_path.as_posix(),
        "source_sha256": source_sha,
        "output_path": OUTPUT_PATH.as_posix(),
        "blender_version": bpy.app.version_string,
        "source_forward": "-Y",
        "source_up": "+Z",
        "normalized_blender_forward": "+Y",
        "normalized_blender_up": "+Z",
        "godot_forward": "-Z",
        "godot_up": "+Y",
        "mesh_dimensions_blender_xyz": [round(value, 6) for value in dimensions],
        "mesh_dimensions_godot_xyz": [round(value, 6) for value in godot_dimensions],
        "target_dimensions_blender_xyz": [
            value for value in TARGET_BLENDER_DIMENSIONS
        ],
        "gameplay_envelope_godot_xyz": [
            value for value in EXPECTED_GODOT_ENVELOPE
        ],
        "required_nodes": [
            "SmallSciFiFighter",
            "SmallSciFiFighterMesh",
            "ForwardMarker",
            "UpMarker",
        ],
    }
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"Manifest output was not created: {path}")


def main() -> None:
    global OUTPUT_PATH

    args = parse_args()
    OUTPUT_PATH = args.output.resolve()
    manifest_path = args.manifest.resolve()
    source_path = Path(bpy.data.filepath).resolve()
    if not source_path.is_file():
        raise RuntimeError(f"Blender source file is unavailable: {source_path}")

    print(f"Source: {source_path}")
    print(f"Source SHA-256: {hashlib.sha256(source_path.read_bytes()).hexdigest()}")

    initial_meshes = visible_meshes()
    if not initial_meshes:
        raise RuntimeError("The source contains no visible renderable mesh objects")

    remove_non_runtime_objects()
    mesh = join_meshes(visible_meshes())
    normalize_source_axes(mesh)
    final_dimensions = fit_and_center(mesh)

    root = bpy.data.objects.new("SmallSciFiFighter", None)
    root.empty_display_type = "PLAIN_AXES"
    root.location = Vector((0.0, 0.0, 0.0))
    bpy.context.collection.objects.link(root)
    mesh.parent = root
    create_axis_markers(root)

    export_glb(OUTPUT_PATH, root)
    write_manifest(manifest_path, source_path, final_dimensions)

    print(f"Runtime GLB: {OUTPUT_PATH}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
