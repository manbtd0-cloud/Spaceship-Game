from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from small_fighter_calibration import (  # noqa: E402
    BOUNDS_TOLERANCE,
    COLLIDER_SIZE_GODOT,
    EXPECTED_DIMENSIONS_GODOT,
    HULL_CENTER_LOCAL,
    PLUME_GROUPS,
    SOCKET_COUNTS,
    SOURCE_CENTER_TOLERANCE,
    SOURCE_DIMENSION_TOLERANCE,
    SOURCE_FRAME_OBJECT,
    SOURCE_HULL_DIMENSIONS,
    SOURCE_SHA256,
    UNIFORM_SCALE,
    classify_socket_name,
    connected_components,
    principal_axis,
)


@dataclass(frozen=True)
class SocketRecord:
    path: str
    socket_class: str
    source_object: str
    source_component: int
    position_blender: Vector
    exhaust_direction_blender: Vector
    basis_blender: Matrix


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(
        description="Export the canonical socketed Shattered Orbit hero fighter."
    )
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    return parser.parse_args(argv)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def visible_mesh_objects() -> list[bpy.types.Object]:
    result: list[bpy.types.Object] = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.hide_render or obj.hide_get():
            continue
        try:
            if not obj.visible_get():
                continue
        except RuntimeError:
            pass
        result.append(obj)
    return result


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


def create_clean_collection() -> bpy.types.Collection:
    collection = bpy.data.collections.new("_CanonicalSmallSciFiFighter")
    bpy.context.scene.collection.children.link(collection)
    return collection


def duplicate_materials(obj: bpy.types.Object) -> None:
    for slot in obj.material_slots:
        if slot.material is not None:
            slot.material = slot.material.copy()


def disable_thruster_emission(obj: bpy.types.Object) -> None:
    for slot in obj.material_slots:
        material = slot.material
        if material is None or material.name.split(".")[0] != "Thrusters":
            continue
        if not material.use_nodes or material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type == "EMISSION":
                strength = node.inputs.get("Strength")
                if strength is not None:
                    strength.default_value = 0.0
                color = node.inputs.get("Color")
                if color is not None:
                    color.default_value = (0.0, 0.0, 0.0, 1.0)
            if node.type == "BSDF_PRINCIPLED":
                emission_color = node.inputs.get("Emission Color") or node.inputs.get("Emission")
                if emission_color is not None:
                    emission_color.default_value = (0.0, 0.0, 0.0, 1.0)
                emission_strength = node.inputs.get("Emission Strength")
                if emission_strength is not None:
                    emission_strength.default_value = 0.0


def duplicate_retained_geometry(
    source_frame_inverse: Matrix,
    collection: bpy.types.Collection,
) -> list[bpy.types.Object]:
    retained: list[bpy.types.Object] = []
    sources = sorted(
        visible_mesh_objects(),
        key=lambda source: (source.name != SOURCE_FRAME_OBJECT, source.name.lower()),
    )
    for source in sources:
        if source.name.startswith("EngineFire"):
            continue
        duplicate = source.copy()
        duplicate.data = source.data.copy()
        duplicate.animation_data_clear()
        duplicate.parent = None
        collection.objects.link(duplicate)
        duplicate.matrix_world = source_frame_inverse @ source.matrix_world
        duplicate_materials(duplicate)
        disable_thruster_emission(duplicate)
        retained.append(duplicate)
    if not retained:
        raise RuntimeError("No retained fighter geometry remains after EngineFire cleanup")
    return retained


def convert_and_join(objects: list[bpy.types.Object]) -> bpy.types.Object:
    select_only(objects)
    conversion = bpy.ops.object.convert(target="MESH")
    if "FINISHED" not in conversion:
        raise RuntimeError(f"Failed to evaluate retained fighter meshes: {conversion}")
    converted = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if not converted:
        raise RuntimeError("Retained fighter conversion produced no meshes")
    bpy.context.view_layer.objects.active = converted[0]
    if len(converted) > 1:
        joined = bpy.ops.object.join()
        if "FINISHED" not in joined:
            raise RuntimeError(f"Failed to join retained fighter geometry: {joined}")
    mesh = bpy.context.view_layer.objects.active
    if mesh is None or mesh.type != "MESH":
        raise RuntimeError("Canonical fighter mesh was not created")
    mesh.name = "SmallSciFiFighterMesh"
    mesh.data.name = "SmallSciFiFighterMesh"
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    mesh.data.validate(clean_customdata=False)
    mesh.data.update()
    return mesh


def object_world_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    corners = [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    minimum = Vector(tuple(min(corner[index] for corner in corners) for index in range(3)))
    maximum = Vector(tuple(max(corner[index] for corner in corners) for index in range(3)))
    return minimum, maximum


def validate_source_hull_bounds(mesh: bpy.types.Object) -> None:
    minimum, maximum = object_world_bounds(mesh)
    center = (minimum + maximum) * 0.5
    dimensions = maximum - minimum
    approved_center = Vector(HULL_CENTER_LOCAL)
    approved_dimensions = Vector(SOURCE_HULL_DIMENSIONS)
    if (center - approved_center).length > SOURCE_CENTER_TOLERANCE:
        raise RuntimeError(
            "Cube-local hull center differs from approved calibration: "
            f"actual={tuple(center)}, approved={HULL_CENTER_LOCAL}"
        )
    for axis, actual, approved in zip("XYZ", dimensions, approved_dimensions):
        if abs(actual - approved) > SOURCE_DIMENSION_TOLERANCE:
            raise RuntimeError(
                f"Cube-local hull {axis} dimension differs from approved calibration: "
                f"actual={actual:.6f}, approved={approved:.6f}"
            )


def build_hull_bvh(mesh: bpy.types.Object) -> BVHTree:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(mesh, depsgraph, deform=True, cage=False)
    if bvh is None:
        raise RuntimeError("Could not build hull BVH for nozzle extraction")
    return bvh


def evaluated_component_points(
    source: bpy.types.Object,
    source_frame_inverse: Matrix,
) -> list[list[Vector]]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = source.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        edges = [(edge.vertices[0], edge.vertices[1]) for edge in mesh.edges]
        components = connected_components(len(mesh.vertices), edges)
        transform = source_frame_inverse @ evaluated.matrix_world
        return [
            [transform @ mesh.vertices[index].co for index in component]
            for component in components
        ]
    finally:
        evaluated.to_mesh_clear()


def radial_rms(points: list[Vector], centroid: Vector, axis: Vector) -> float:
    if not points:
        return 0.0
    squared = 0.0
    for point in points:
        offset = point - centroid
        radial = offset - axis * offset.dot(axis)
        squared += radial.length_squared
    return math.sqrt(squared / len(points))


def nearest_hull_distance(bvh: BVHTree, point: Vector) -> float:
    nearest = bvh.find_nearest(point)
    if nearest is None or nearest[0] is None:
        raise RuntimeError(f"Hull distance query failed at {tuple(point)}")
    return float(nearest[3])


def extract_socket_from_component(
    points: list[Vector],
    hull_bvh: BVHTree,
    source_name: str,
    component_index: int,
    socket_class: str,
    group: str,
) -> SocketRecord:
    if len(points) < 4:
        raise RuntimeError(f"{source_name}[{component_index}] has too few vertices")
    axis_values = principal_axis([tuple(point) for point in points])
    axis = Vector(axis_values).normalized()
    ordered_points = sorted(points, key=lambda point: point.dot(axis))
    slice_count = max(2, int(math.ceil(len(points) * 0.2)))
    low_points = ordered_points[:slice_count]
    high_points = ordered_points[-slice_count:]
    low_center = sum(low_points, Vector((0.0, 0.0, 0.0))) / len(low_points)
    high_center = sum(high_points, Vector((0.0, 0.0, 0.0))) / len(high_points)
    low_distance = nearest_hull_distance(hull_bvh, low_center)
    high_distance = nearest_hull_distance(hull_bvh, high_center)
    low_radius = radial_rms(low_points, low_center, axis)
    high_radius = radial_rms(high_points, high_center, axis)

    if low_distance <= high_distance:
        near_center, far_center = low_center, high_center
        near_distance, far_distance = low_distance, high_distance
        near_radius, far_radius = low_radius, high_radius
    else:
        near_center, far_center = high_center, low_center
        near_distance, far_distance = high_distance, low_distance
        near_radius, far_radius = high_radius, low_radius

    if far_distance <= 1e-6 or near_distance > far_distance * 0.85:
        raise RuntimeError(
            f"Ambiguous nozzle end for {source_name}[{component_index}]: "
            f"distances=({low_distance:.6f}, {high_distance:.6f})"
        )
    if near_radius < far_radius * 0.60:
        raise RuntimeError(
            f"Ambiguous plume width for {source_name}[{component_index}]: "
            f"radial_rms=({low_radius:.6f}, {high_radius:.6f})"
        )

    exhaust_direction = (far_center - near_center).normalized()
    canonical_position = (near_center - Vector(HULL_CENTER_LOCAL)) * UNIFORM_SCALE
    path = classify_socket_name(group, tuple(canonical_position))
    up_axis = "X" if abs(exhaust_direction.dot(Vector((0.0, 1.0, 0.0)))) > 0.98 else "Y"
    basis = exhaust_direction.to_track_quat("-Z", up_axis).to_matrix().to_4x4()
    return SocketRecord(
        path=path,
        socket_class=socket_class,
        source_object=source_name,
        source_component=component_index,
        position_blender=canonical_position,
        exhaust_direction_blender=exhaust_direction,
        basis_blender=basis,
    )


def extract_all_sockets(
    source_frame_inverse: Matrix,
    hull_bvh: BVHTree,
) -> list[SocketRecord]:
    records: list[SocketRecord] = []
    for source_name, specification in PLUME_GROUPS.items():
        source = bpy.data.objects.get(source_name)
        if source is None or source.type != "MESH":
            raise RuntimeError(f"Approved plume evidence is missing: {source_name}")
        components = evaluated_component_points(source, source_frame_inverse)
        expected_components = int(specification["components"])
        if len(components) != expected_components:
            raise RuntimeError(
                f"{source_name} component count mismatch: "
                f"expected {expected_components}, got {len(components)}"
            )
        for component_index, points in enumerate(components):
            records.append(
                extract_socket_from_component(
                    points,
                    hull_bvh,
                    source_name,
                    component_index,
                    str(specification["class"]),
                    str(specification["group"]),
                )
            )
    records.sort(key=lambda record: record.path)
    paths = [record.path for record in records]
    if len(records) != 12 or len(set(paths)) != 12:
        raise RuntimeError(f"Expected twelve unique sockets, got {paths}")
    counts = {name: 0 for name in SOCKET_COUNTS}
    for record in records:
        counts[record.socket_class] += 1
    if counts != SOCKET_COUNTS:
        raise RuntimeError(f"Socket class counts mismatch: {counts}")
    return records


def create_empty(
    name: str,
    parent: bpy.types.Object | None,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "ARROWS"
    empty.empty_display_size = 0.15
    empty.parent = parent
    collection.objects.link(empty)
    return empty


def create_socket_hierarchy(
    root: bpy.types.Object,
    collection: bpy.types.Collection,
    records: list[SocketRecord],
) -> dict[str, bpy.types.Object]:
    nodes: dict[str, bpy.types.Object] = {}
    thrusters = create_empty("Thrusters", root, collection)
    nodes["Thrusters"] = thrusters
    for group in ("Main", "Retro", "Maneuver"):
        nodes[f"Thrusters/{group}"] = create_empty(group, thrusters, collection)

    for record in records:
        segments = record.path.split("/")
        parent = nodes["/".join(segments[:-1])]
        socket = create_empty(segments[-1], parent, collection)
        socket.location = record.position_blender
        socket.rotation_mode = "QUATERNION"
        socket.rotation_quaternion = record.basis_blender.to_quaternion()
        socket.scale = Vector((1.0, 1.0, 1.0))
        socket["thruster_class"] = record.socket_class
        socket["source_object"] = record.source_object
        socket["source_component"] = record.source_component
        nodes[record.path] = socket
    return nodes


def center_and_scale_hull(mesh: bpy.types.Object) -> None:
    mesh.location = -Vector(HULL_CENTER_LOCAL)
    mesh.scale = Vector((UNIFORM_SCALE, UNIFORM_SCALE, UNIFORM_SCALE))
    select_only([mesh])
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    minimum, maximum = object_world_bounds(mesh)
    dimensions = maximum - minimum
    expected_blender = Vector(
        (
            EXPECTED_DIMENSIONS_GODOT[0],
            EXPECTED_DIMENSIONS_GODOT[2],
            EXPECTED_DIMENSIONS_GODOT[1],
        )
    )
    for axis, actual, expected in zip("XYZ", dimensions, expected_blender):
        if abs(actual - expected) > BOUNDS_TOLERANCE:
            raise RuntimeError(
                f"Canonical Blender {axis} dimension outside tolerance: "
                f"actual={actual:.6f}, expected={expected:.6f}"
            )


def blender_to_godot_vector(value: Vector) -> list[float]:
    return [
        round(float(value.x), 8),
        round(float(value.z), 8),
        round(float(-value.y), 8),
    ]


def blender_basis_to_godot_rows(basis: Matrix) -> list[list[float]]:
    axes = [Vector(basis.col[index][:3]) for index in range(3)]
    godot_columns = [Vector(blender_to_godot_vector(axis)) for axis in axes]
    return [
        [round(float(godot_columns[column][row]), 8) for column in range(3)]
        for row in range(3)
    ]


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
        raise RuntimeError(f"glTF export failed: {result}")
    if not output_path.is_file() or output_path.stat().st_size <= 0:
        raise RuntimeError(f"GLB output missing or empty: {output_path}")


def write_manifest(
    path: Path,
    output_path: Path,
    source_path: Path,
    records: list[SocketRecord],
    measured_dimensions_godot: Vector,
) -> None:
    removed = sorted(PLUME_GROUPS)
    sockets: list[dict[str, Any]] = []
    for record in records:
        exhaust_godot = Vector(
            blender_to_godot_vector(record.exhaust_direction_blender)
        ).normalized()
        reaction_godot = -exhaust_godot
        sockets.append(
            {
                "path": record.path,
                "class": record.socket_class,
                "source_object": record.source_object,
                "source_component": record.source_component,
                "position": blender_to_godot_vector(record.position_blender),
                "exhaust_direction": [
                    round(float(value), 8) for value in exhaust_godot
                ],
                "reaction_direction": [
                    round(float(value), 8) for value in reaction_godot
                ],
                "basis": blender_basis_to_godot_rows(record.basis_blender),
            }
        )
    manifest = {
        "schema_version": 2,
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
        "removed_objects": removed,
        "sockets": sockets,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(f"Manifest output missing or empty: {path}")


def main() -> None:
    args = parse_args()
    output_path = args.output.resolve()
    manifest_path = args.manifest.resolve()
    source_path = Path(bpy.data.filepath).resolve()
    if not source_path.is_file():
        raise RuntimeError(f"Blender source file unavailable: {source_path}")
    actual_sha = sha256_file(source_path)
    if actual_sha != SOURCE_SHA256:
        raise RuntimeError(f"Unexpected source SHA: {actual_sha}")

    source_frame = bpy.data.objects.get(SOURCE_FRAME_OBJECT)
    if source_frame is None or source_frame.type != "MESH":
        raise RuntimeError("Approved source frame Cube is missing")
    source_frame_inverse = source_frame.matrix_world.inverted_safe()

    collection = create_clean_collection()
    retained = duplicate_retained_geometry(source_frame_inverse, collection)
    hull = convert_and_join(retained)
    hull.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    validate_source_hull_bounds(hull)
    hull_bvh = build_hull_bvh(hull)
    socket_records = extract_all_sockets(source_frame_inverse, hull_bvh)
    center_and_scale_hull(hull)
    final_minimum, final_maximum = object_world_bounds(hull)
    final_dimensions_blender = final_maximum - final_minimum
    measured_dimensions_godot = Vector(
        (
            final_dimensions_blender.x,
            final_dimensions_blender.z,
            final_dimensions_blender.y,
        )
    )

    root = create_empty("SmallSciFiFighter", None, collection)
    root.matrix_world = Matrix.Identity(4)
    hull.parent = root
    hull.matrix_parent_inverse = Matrix.Identity(4)
    create_socket_hierarchy(root, collection, socket_records)

    export_glb(output_path, root)
    write_manifest(
        manifest_path,
        output_path,
        source_path,
        socket_records,
        measured_dimensions_godot,
    )

    if sha256_file(source_path) != actual_sha:
        raise RuntimeError("Source SHA changed during canonical export")

    print(f"Source SHA validated: {actual_sha}")
    print("Cube-local hull dimensions validated")
    print(f"{len(socket_records)} socket components extracted")
    print("2 main / 2 retro / 8 maneuver sockets")
    print(f"Canonical GLB: {output_path}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
