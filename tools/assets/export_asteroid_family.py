from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

import bpy
from mathutils import Matrix, Vector

CANONICAL_DIAMETER_METERS = 100.0
TARGET_PROXY_FACES = 384
FLATNESS_RATIO = 0.0005


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Export one canonical asteroid family.")
    parser.add_argument("--source-id", required=True)
    parser.add_argument("--canonical-name", required=True)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--provenance-status", required=True)
    return parser.parse_args(argv)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def ensure_object_mode() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def select_only(objects: list[bpy.types.Object]) -> None:
    ensure_object_mode()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def clear_scene_for_import() -> None:
    ensure_object_mode()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)


def load_input(input_path: Path) -> None:
    suffix = input_path.suffix.lower()
    if suffix in {".glb", ".gltf"}:
        clear_scene_for_import()
        result = bpy.ops.import_scene.gltf(filepath=str(input_path))
        if "FINISHED" not in result:
            raise RuntimeError(f"glTF import failed: {result}")
        return
    if suffix == ".blend":
        opened_path = Path(bpy.data.filepath).resolve()
        if opened_path != input_path.resolve():
            raise RuntimeError(
                f"Blender opened the wrong source: expected {input_path}, got {opened_path}"
            )
        return
    raise RuntimeError(f"Unsupported asteroid source format: {input_path.suffix}")


def evaluated_world_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    corners = [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    if not corners:
        raise RuntimeError(f"Mesh has no bounds: {obj.name}")
    minimum = Vector(tuple(min(point[axis] for point in corners) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in corners) for axis in range(3)))
    return minimum, maximum


def is_flat_mesh(obj: bpy.types.Object) -> bool:
    minimum, maximum = evaluated_world_bounds(obj)
    dimensions = maximum - minimum
    longest = max(dimensions)
    if longest <= 1e-9:
        return True
    return min(dimensions) <= longest * FLATNESS_RATIO


def create_clean_collection(canonical_name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(f"_CanonicalAsteroid{canonical_name}")
    bpy.context.scene.collection.children.link(collection)
    return collection


def duplicate_materials(obj: bpy.types.Object) -> None:
    for slot in obj.material_slots:
        if slot.material is not None:
            slot.material = slot.material.copy()


def duplicate_retained_meshes(
    collection: bpy.types.Collection,
) -> tuple[list[bpy.types.Object], list[str]]:
    retained: list[bpy.types.Object] = []
    removed: list[str] = []
    for source in sorted(bpy.context.scene.objects, key=lambda item: item.name.lower()):
        if source.type != "MESH":
            removed.append(source.name)
            continue
        if source.hide_render or source.hide_get() or is_flat_mesh(source):
            removed.append(source.name)
            continue
        duplicate = source.copy()
        duplicate.data = source.data.copy()
        duplicate.animation_data_clear()
        duplicate.parent = None
        collection.objects.link(duplicate)
        duplicate.matrix_world = source.matrix_world.copy()
        duplicate_materials(duplicate)
        retained.append(duplicate)
    if not retained:
        raise RuntimeError("No non-flat renderable asteroid mesh remains after cleanup")
    return retained, sorted(set(removed))


def convert_and_join(objects: list[bpy.types.Object]) -> bpy.types.Object:
    select_only(objects)
    conversion = bpy.ops.object.convert(target="MESH")
    if "FINISHED" not in conversion:
        raise RuntimeError(f"Failed to evaluate asteroid meshes: {conversion}")
    converted = sorted(
        [obj for obj in bpy.context.selected_objects if obj.type == "MESH"],
        key=lambda item: item.name.lower(),
    )
    if not converted:
        raise RuntimeError("Asteroid conversion produced no mesh")
    bpy.context.view_layer.objects.active = converted[0]
    if len(converted) > 1:
        joined = bpy.ops.object.join()
        if "FINISHED" not in joined:
            raise RuntimeError(f"Failed to join asteroid meshes: {joined}")
    visual = bpy.context.view_layer.objects.active
    if visual is None or visual.type != "MESH":
        raise RuntimeError("Canonical asteroid visual mesh was not created")
    visual.data.transform(visual.matrix_world)
    visual.matrix_world = Matrix.Identity(4)
    visual.name = "VisualModel"
    visual.data.name = "VisualModel"
    visual.data.validate(clean_customdata=False)
    visual.data.update()
    return visual


def local_mesh_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    if not obj.data.vertices:
        raise RuntimeError(f"Mesh has no vertices: {obj.name}")
    points = [vertex.co for vertex in obj.data.vertices]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    return minimum, maximum


def center_and_scale(visual: bpy.types.Object) -> Vector:
    minimum, maximum = local_mesh_bounds(visual)
    center = (minimum + maximum) * 0.5
    dimensions = maximum - minimum
    longest = max(dimensions)
    if longest <= 1e-9:
        raise RuntimeError(f"Asteroid has invalid dimensions: {tuple(dimensions)}")
    scale = CANONICAL_DIAMETER_METERS / longest
    transform = Matrix.Diagonal(Vector((scale, scale, scale, 1.0))) @ Matrix.Translation(-center)
    visual.data.transform(transform)
    visual.data.update()
    minimum, maximum = local_mesh_bounds(visual)
    final_dimensions = maximum - minimum
    if abs(max(final_dimensions) - CANONICAL_DIAMETER_METERS) > 0.01:
        raise RuntimeError(
            f"Canonical asteroid diameter mismatch: {tuple(final_dimensions)}"
        )
    return final_dimensions


def create_collision_proxy(
    visual: bpy.types.Object,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    proxy = visual.copy()
    proxy.data = visual.data.copy()
    proxy.name = "CollisionProxy-convcolonly"
    proxy.data.name = "CollisionProxy-convcolonly"
    proxy.parent = None
    proxy.data.materials.clear()
    collection.objects.link(proxy)

    face_count = len(proxy.data.polygons)
    if face_count <= 0:
        raise RuntimeError("Visual mesh has no faces for collision proxy")
    if face_count > TARGET_PROXY_FACES:
        modifier = proxy.modifiers.new(name="CollisionDecimate", type="DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = max(0.0001, min(1.0, TARGET_PROXY_FACES / face_count))
        modifier.use_collapse_triangulate = True
        select_only([proxy])
        result = bpy.ops.object.modifier_apply(modifier=modifier.name)
        if "FINISHED" not in result:
            raise RuntimeError(f"Collision proxy decimation failed: {result}")

    select_only([proxy])
    bpy.context.view_layer.objects.active = proxy
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    hull_result = bpy.ops.mesh.convex_hull(delete_unused=True, use_existing_faces=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if "FINISHED" not in hull_result:
        raise RuntimeError(f"Collision proxy convex hull failed: {hull_result}")
    proxy.data.validate(clean_customdata=False)
    proxy.data.update()
    if len(proxy.data.vertices) <= 3 or len(proxy.data.polygons) <= 3:
        raise RuntimeError("Collision proxy is degenerate")
    if len(proxy.data.polygons) >= len(visual.data.polygons):
        raise RuntimeError(
            "Collision proxy was not reduced below visual face count: "
            f"proxy={len(proxy.data.polygons)} visual={len(visual.data.polygons)}"
        )
    return proxy


def create_root(canonical_name: str, collection: bpy.types.Collection) -> bpy.types.Object:
    root = bpy.data.objects.new(f"Asteroid_{canonical_name}", None)
    root.empty_display_type = "PLAIN_AXES"
    root.matrix_world = Matrix.Identity(4)
    collection.objects.link(root)
    return root


def texture_present(visual: bpy.types.Object) -> bool:
    for slot in visual.material_slots:
        material = slot.material
        if material is None or material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and getattr(node, "image", None) is not None:
                return True
    return False


def export_glb(output_path: Path, root: bpy.types.Object) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    hierarchy = [root, *list(root.children_recursive)]
    select_only(hierarchy)
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
        export_extras=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"Asteroid glTF export failed: {result}")
    if not output_path.is_file() or output_path.stat().st_size <= 0:
        raise RuntimeError(f"Asteroid GLB missing or empty: {output_path}")


def blender_to_godot_dimensions(dimensions: Vector) -> list[float]:
    return [
        round(float(dimensions.x), 8),
        round(float(dimensions.z), 8),
        round(float(dimensions.y), 8),
    ]


def write_manifest(
    path: Path,
    args: argparse.Namespace,
    dimensions: Vector,
    visual: bpy.types.Object,
    proxy: bpy.types.Object,
    removed_objects: list[str],
) -> None:
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "source_id": args.source_id,
        "canonical_name": args.canonical_name,
        "source_path": args.input.resolve().as_posix(),
        "source_sha256": args.source_sha.lower(),
        "output_path": args.output.resolve().as_posix(),
        "blender_version": bpy.app.version_string,
        "canonical_frame": {
            "godot_right": "+X",
            "godot_forward": "-Z",
            "godot_up": "+Y",
            "root_identity": True,
        },
        "canonical_diameter_meters": CANONICAL_DIAMETER_METERS,
        "dimensions_godot_xyz": blender_to_godot_dimensions(dimensions),
        "visual_vertices": len(visual.data.vertices),
        "visual_faces": len(visual.data.polygons),
        "proxy_vertices": len(proxy.data.vertices),
        "proxy_faces": len(proxy.data.polygons),
        "material_count": len(visual.data.materials),
        "texture_present": texture_present(visual),
        "removed_objects": removed_objects,
        "provenance_status": args.provenance_status,
        "required_nodes": ["VisualModel", "CollisionProxy-convcolonly"],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(f"Asteroid manifest missing or empty: {path}")


def main() -> None:
    args = parse_args()
    input_path = args.input.resolve()
    output_path = args.output.resolve()
    manifest_path = args.manifest.resolve()
    if not input_path.is_file():
        raise RuntimeError(f"Asteroid input missing: {input_path}")
    actual_sha = sha256_file(input_path)
    if actual_sha.lower() != args.source_sha.lower():
        raise RuntimeError(
            f"Asteroid source SHA mismatch: expected {args.source_sha}, got {actual_sha}"
        )

    load_input(input_path)
    collection = create_clean_collection(args.canonical_name)
    retained, removed = duplicate_retained_meshes(collection)
    visual = convert_and_join(retained)
    dimensions = center_and_scale(visual)
    proxy = create_collision_proxy(visual, collection)

    root = create_root(args.canonical_name, collection)
    visual.parent = root
    visual.matrix_parent_inverse = Matrix.Identity(4)
    proxy.parent = root
    proxy.matrix_parent_inverse = Matrix.Identity(4)

    export_glb(output_path, root)
    write_manifest(
        manifest_path,
        args,
        dimensions,
        visual,
        proxy,
        removed,
    )

    if sha256_file(input_path) != actual_sha:
        raise RuntimeError("Asteroid source changed during export")

    print(f"Asteroid family: {args.source_id}")
    print(f"Canonical dimensions (Blender XYZ): {tuple(round(v, 6) for v in dimensions)}")
    print(f"Visual: {len(visual.data.vertices)} vertices / {len(visual.data.polygons)} faces")
    print(f"Proxy: {len(proxy.data.vertices)} vertices / {len(proxy.data.polygons)} faces")
    print(f"GLB: {output_path}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
