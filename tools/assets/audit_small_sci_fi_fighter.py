from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

import bpy
from mathutils import Matrix, Vector


RENDER_FILENAMES = {
    "front": "front.png",
    "rear": "rear.png",
    "left": "left.png",
    "right": "right.png",
    "top": "top.png",
    "bottom": "bottom.png",
    "perspective_front": "perspective_front.png",
    "perspective_rear": "perspective_rear.png",
}
ORTHOGRAPHIC_CAMERA_DIRECTIONS = {
    "front": Vector((0.0, -1.0, 0.0)),
    "rear": Vector((0.0, 1.0, 0.0)),
    "left": Vector((-1.0, 0.0, 0.0)),
    "right": Vector((1.0, 0.0, 0.0)),
    "top": Vector((0.0, 0.0, 1.0)),
    "bottom": Vector((0.0, 0.0, -1.0)),
}
PERSPECTIVE_CAMERA_DIRECTIONS = {
    "perspective_front": Vector((1.0, -1.0, 0.65)).normalized(),
    "perspective_rear": Vector((-1.0, 1.0, 0.45)).normalized(),
}
NOZZLE_NAME_TOKENS = (
    "engine",
    "exhaust",
    "nozzle",
    "thruster",
    "thrust",
    "jet",
    "flame",
    "burner",
    "vent",
    "retro",
    "rcs",
)
OUTPUT_DIR: Path | None = None


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(
        description="Render a non-destructive structural audit of the Small Sci-Fi Fighter."
    )
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--source-sha", required=True)
    return parser.parse_args(argv)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def vector_values(value: Vector) -> list[float]:
    return [round(float(component), 8) for component in value]


def matrix_values(value: Matrix) -> list[list[float]]:
    return [
        [round(float(component), 8) for component in row]
        for row in value
    ]


def serializable_value(value: Any) -> Any:
    if isinstance(value, (int, float, str, bool)) or value is None:
        return value
    try:
        return [round(float(component), 8) for component in value]
    except (TypeError, ValueError):
        return str(value)


def object_is_visible(obj: bpy.types.Object) -> bool:
    if obj.hide_render or obj.hide_get():
        return False
    try:
        return bool(obj.visible_get())
    except RuntimeError:
        return True


def visible_meshes() -> list[bpy.types.Object]:
    return [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and object_is_visible(obj)
    ]


def evaluated_world_corners(obj: bpy.types.Object) -> list[Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    matrix_world = evaluated.matrix_world
    return [matrix_world @ Vector(corner) for corner in evaluated.bound_box]


def aggregate_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    if not objects:
        raise RuntimeError("The source contains no visible renderable mesh objects")
    minimum = Vector((float("inf"), float("inf"), float("inf")))
    maximum = Vector((float("-inf"), float("-inf"), float("-inf")))
    for obj in objects:
        for corner in evaluated_world_corners(obj):
            minimum.x = min(minimum.x, corner.x)
            minimum.y = min(minimum.y, corner.y)
            minimum.z = min(minimum.z, corner.z)
            maximum.x = max(maximum.x, corner.x)
            maximum.y = max(maximum.y, corner.y)
            maximum.z = max(maximum.z, corner.z)
    return minimum, maximum


def material_appears_emissive(material: bpy.types.Material) -> bool:
    if not material.use_nodes or material.node_tree is None:
        return False
    for node in material.node_tree.nodes:
        node_name = f"{node.name} {node.label} {node.bl_idname}".lower()
        if node.type == "EMISSION" or "emission" in node_name:
            return True
        for input_name in ("Emission", "Emission Color", "Emission Strength"):
            socket = node.inputs.get(input_name) if hasattr(node, "inputs") else None
            if socket is None:
                continue
            value = socket.default_value
            if input_name == "Emission Strength" and float(value) > 0.0001:
                return True
            if input_name != "Emission Strength":
                try:
                    if max(float(component) for component in value[:3]) > 0.0001:
                        return True
                except (TypeError, ValueError):
                    pass
    return False


def material_record(material: bpy.types.Material) -> dict[str, Any]:
    nodes: list[dict[str, Any]] = []
    if material.use_nodes and material.node_tree is not None:
        for node in material.node_tree.nodes:
            input_values: dict[str, Any] = {}
            for socket in getattr(node, "inputs", []):
                if hasattr(socket, "default_value"):
                    input_values[socket.name] = serializable_value(socket.default_value)
            nodes.append(
                {
                    "name": node.name,
                    "label": node.label,
                    "type": node.type,
                    "bl_idname": node.bl_idname,
                    "inputs": input_values,
                }
            )
    return {
        "name": material.name,
        "diffuse_color": serializable_value(material.diffuse_color),
        "use_nodes": bool(material.use_nodes),
        "surface_render_method": str(
            getattr(material, "surface_render_method", "")
        ),
        "appears_emissive": material_appears_emissive(material),
        "nodes": nodes,
    }


def object_record(obj: bpy.types.Object) -> dict[str, Any]:
    material_names = [
        slot.material.name
        for slot in getattr(obj, "material_slots", [])
        if slot.material is not None
    ]
    world_corners: list[list[float]] = []
    if obj.type == "MESH":
        world_corners = [vector_values(corner) for corner in evaluated_world_corners(obj)]
    return {
        "name": obj.name,
        "type": obj.type,
        "parent": obj.parent.name if obj.parent else None,
        "visible_render": not obj.hide_render,
        "visible_viewport": not obj.hide_get(),
        "matrix_world": matrix_values(obj.matrix_world),
        "location": vector_values(obj.location),
        "rotation_euler_degrees": [
            round(math.degrees(float(component)), 8)
            for component in obj.rotation_euler
        ],
        "scale": vector_values(obj.scale),
        "dimensions": vector_values(obj.dimensions),
        "bound_box_world": world_corners,
        "materials": material_names,
    }


def collect_source_evidence() -> tuple[
    list[dict[str, Any]],
    list[dict[str, Any]],
    list[dict[str, Any]],
    list[dict[str, str]],
]:
    source_objects = list(bpy.context.scene.objects)
    object_records = [object_record(obj) for obj in source_objects]
    empties = [record for record in object_records if record["type"] == "EMPTY"]

    materials_by_name: dict[str, bpy.types.Material] = {}
    for obj in source_objects:
        for slot in getattr(obj, "material_slots", []):
            if slot.material is not None:
                materials_by_name[slot.material.name] = slot.material
    material_records = [
        material_record(materials_by_name[name])
        for name in sorted(materials_by_name)
    ]

    candidates: list[dict[str, str]] = []
    for obj in source_objects:
        lowered = obj.name.lower()
        if any(token in lowered for token in NOZZLE_NAME_TOKENS):
            candidates.append({"kind": "object", "name": obj.name})
    for name in sorted(materials_by_name):
        lowered = name.lower()
        if any(token in lowered for token in NOZZLE_NAME_TOKENS):
            candidates.append({"kind": "material", "name": name})
    candidates.sort(key=lambda item: (item["kind"], item["name"].lower()))
    return object_records, material_records, empties, candidates


def ensure_output_directory(output_dir: Path) -> None:
    if output_dir.name != "hero_ship_audit":
        raise RuntimeError(
            "Refusing audit output outside a directory named hero_ship_audit: "
            f"{output_dir}"
        )
    output_dir.mkdir(parents=True, exist_ok=True)
    for filename in (*RENDER_FILENAMES.values(), "ship_audit.json"):
        existing = output_dir / filename
        if existing.exists():
            existing.unlink()


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def create_material(
    name: str,
    color: tuple[float, float, float, float],
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name=name)
    material.diffuse_color = color
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        base_color = principled.inputs.get("Base Color")
        if base_color is not None:
            base_color.default_value = color
        emission_color = principled.inputs.get("Emission Color") or principled.inputs.get("Emission")
        if emission_color is not None:
            emission_color.default_value = color
        emission_input = principled.inputs.get("Emission Strength")
        if emission_input is not None:
            emission_input.default_value = emission_strength
        roughness = principled.inputs.get("Roughness")
        if roughness is not None:
            roughness.default_value = 0.35
    return material


def create_uv_sphere(
    name: str,
    location: Vector,
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24,
        ring_count=12,
        radius=radius,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    move_to_collection(obj, collection)
    return obj


def create_cylinder_between(
    name: str,
    start: Vector,
    end: Vector,
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    direction = end - start
    length = direction.length
    if length <= 0.000001:
        raise RuntimeError(f"Cannot create zero-length audit line: {name}")
    midpoint = (start + end) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=radius,
        depth=length,
        location=midpoint,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    move_to_collection(obj, collection)
    return obj


def create_cone(
    name: str,
    base: Vector,
    tip: Vector,
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    direction = tip - base
    length = direction.length
    midpoint = (base + tip) * 0.5
    bpy.ops.mesh.primitive_cone_add(
        vertices=16,
        radius1=radius,
        radius2=0.0,
        depth=length,
        location=midpoint,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    move_to_collection(obj, collection)
    return obj


def create_text(
    name: str,
    body: str,
    location: Vector,
    size: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name=f"{name}Curve", type="FONT")
    curve.body = body
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = size * 0.01
    curve.materials.append(material)
    obj = bpy.data.objects.new(name, curve)
    obj.location = location
    collection.objects.link(obj)
    return obj


def bounds_corners(minimum: Vector, maximum: Vector) -> list[Vector]:
    return [
        Vector((x, y, z))
        for x in (minimum.x, maximum.x)
        for y in (minimum.y, maximum.y)
        for z in (minimum.z, maximum.z)
    ]


def build_overlay(
    minimum: Vector,
    maximum: Vector,
    center: Vector,
    dimensions: Vector,
) -> tuple[bpy.types.Collection, bpy.types.Object]:
    collection = bpy.data.collections.new("_HeroShipAuditOverlay")
    bpy.context.scene.collection.children.link(collection)

    maximum_dimension = max(dimensions)
    line_radius = max(maximum_dimension * 0.0035, 0.002)
    marker_radius = max(maximum_dimension * 0.025, 0.02)
    label_size = max(maximum_dimension * 0.035, 0.03)

    white = create_material("AuditWhite", (0.95, 0.97, 1.0, 1.0), 2.5)
    yellow = create_material("AuditCenter", (1.0, 0.72, 0.05, 1.0), 3.0)
    magenta = create_material("AuditOrigin", (1.0, 0.12, 0.6, 1.0), 3.0)
    red = create_material("AuditX", (1.0, 0.08, 0.08, 1.0), 3.0)
    green = create_material("AuditY", (0.08, 1.0, 0.18, 1.0), 3.0)
    blue = create_material("AuditZ", (0.12, 0.42, 1.0, 1.0), 3.0)

    corners = bounds_corners(minimum, maximum)
    edge_pairs = (
        (0, 1), (0, 2), (0, 4),
        (1, 3), (1, 5),
        (2, 3), (2, 6),
        (3, 7),
        (4, 5), (4, 6),
        (5, 7),
        (6, 7),
    )
    for index, (start_index, end_index) in enumerate(edge_pairs):
        create_cylinder_between(
            f"AuditBounds{index:02d}",
            corners[start_index],
            corners[end_index],
            line_radius,
            white,
            collection,
        )

    create_uv_sphere("AuditWorldOrigin", Vector.ZERO, marker_radius, magenta, collection)
    create_uv_sphere("AuditBoundsCenter", center, marker_radius, yellow, collection)

    axis_length = maximum_dimension * 0.28
    cone_length = axis_length * 0.18
    for axis_name, direction, material in (
        ("X", Vector((1.0, 0.0, 0.0)), red),
        ("Y", Vector((0.0, 1.0, 0.0)), green),
        ("Z", Vector((0.0, 0.0, 1.0)), blue),
    ):
        shaft_end = Vector.ZERO + direction * (axis_length - cone_length)
        tip = Vector.ZERO + direction * axis_length
        create_cylinder_between(
            f"AuditAxis{axis_name}",
            Vector.ZERO,
            shaft_end,
            line_radius * 1.8,
            material,
            collection,
        )
        create_cone(
            f"AuditAxis{axis_name}Tip",
            shaft_end,
            tip,
            line_radius * 5.0,
            material,
            collection,
        )
        label = create_text(
            f"AuditAxis{axis_name}Label",
            axis_name,
            tip + direction * label_size,
            label_size,
            material,
            collection,
        )
        label.rotation_euler = Vector((math.radians(90.0), 0.0, 0.0))

    camera_label = create_text(
        "AuditCameraLabel",
        "",
        Vector.ZERO,
        0.1,
        white,
        collection,
    )
    camera_label.data.align_x = "LEFT"
    camera_label.data.align_y = "TOP"
    return collection, camera_label


def create_area_light(
    name: str,
    location: Vector,
    energy: float,
    size: float,
    target: Vector,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    obj.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()
    collection.objects.link(obj)
    return obj


def create_camera(collection: bpy.types.Collection) -> bpy.types.Object:
    data = bpy.data.cameras.new("HeroShipAuditCamera")
    data.clip_start = 0.01
    data.clip_end = 100000.0
    camera = bpy.data.objects.new("HeroShipAuditCamera", data)
    collection.objects.link(camera)
    bpy.context.scene.camera = camera
    return camera


def point_camera(camera: bpy.types.Object, location: Vector, target: Vector) -> None:
    camera.location = location
    camera.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()


def configure_scene(
    collection: bpy.types.Collection,
    center: Vector,
    dimensions: Vector,
) -> bpy.types.Object:
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        pass
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.use_file_extension = True

    world = scene.world or bpy.data.worlds.new("HeroShipAuditWorld")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (0.025, 0.03, 0.045, 1.0)
        background.inputs["Strength"].default_value = 0.32

    maximum_dimension = max(dimensions)
    light_distance = maximum_dimension * 3.0
    light_size = maximum_dimension * 1.8
    create_area_light(
        "HeroShipAuditKey",
        center + Vector((1.5, -2.0, 1.8)).normalized() * light_distance,
        1350.0,
        light_size,
        center,
        collection,
    )
    create_area_light(
        "HeroShipAuditFill",
        center + Vector((-1.6, -0.4, 0.8)).normalized() * light_distance,
        800.0,
        light_size,
        center,
        collection,
    )
    create_area_light(
        "HeroShipAuditRim",
        center + Vector((0.2, 1.8, 1.3)).normalized() * light_distance,
        1100.0,
        light_size * 0.75,
        center,
        collection,
    )
    return create_camera(collection)


def configure_camera_label(
    label: bpy.types.Object,
    camera: bpy.types.Object,
    view_name: str,
    camera_position_direction: Vector,
    dimensions: Vector,
    source_sha: str,
) -> None:
    label.parent = camera
    label.matrix_parent_inverse = Matrix.Identity(4)
    label.rotation_euler = Vector.ZERO
    label.data.body = (
        f"VIEW: {view_name.upper()}\n"
        f"CAMERA FROM WORLD: ({camera_position_direction.x:+.2f}, "
        f"{camera_position_direction.y:+.2f}, {camera_position_direction.z:+.2f})\n"
        f"DIMS XYZ: ({dimensions.x:.4f}, {dimensions.y:.4f}, {dimensions.z:.4f})\n"
        f"SOURCE SHA: {source_sha[:16]}"
    )
    if camera.data.type == "ORTHO":
        scale = float(camera.data.ortho_scale)
        label.location = Vector((-scale * 0.61, scale * 0.40, -1.0))
        label.data.size = scale * 0.026
        label.data.extrude = scale * 0.00025
    else:
        label.location = Vector((-1.22, 0.82, -2.0))
        label.data.size = 0.085
        label.data.extrude = 0.001


def render_views(
    output_dir: Path,
    camera: bpy.types.Object,
    label: bpy.types.Object,
    center: Vector,
    dimensions: Vector,
    source_sha: str,
) -> dict[str, dict[str, Any]]:
    scene = bpy.context.scene
    maximum_dimension = max(dimensions)
    radius = max(maximum_dimension * 0.65, 0.5)
    distance = max(radius * 3.2, 2.0)
    render_records: dict[str, dict[str, Any]] = {}

    for view_name, camera_position_direction in ORTHOGRAPHIC_CAMERA_DIRECTIONS.items():
        camera.data.type = "ORTHO"
        camera.data.ortho_scale = maximum_dimension * 1.35
        location = center + camera_position_direction.normalized() * distance
        point_camera(camera, location, center)
        configure_camera_label(
            label,
            camera,
            view_name,
            camera_position_direction,
            dimensions,
            source_sha,
        )
        filename = RENDER_FILENAMES[view_name]
        scene.render.filepath = str(output_dir / filename)
        bpy.ops.render.render(write_still=True)
        render_records[view_name] = {
            "file": filename,
            "camera_location": vector_values(location),
            "view_direction": vector_values((center - location).normalized()),
            "camera_position_direction": vector_values(camera_position_direction),
            "projection": "ORTHO",
            "ortho_scale": round(float(camera.data.ortho_scale), 8),
            "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        }

    for view_name, camera_position_direction in PERSPECTIVE_CAMERA_DIRECTIONS.items():
        camera.data.type = "PERSP"
        camera.data.lens = 50.0
        location = center + camera_position_direction * distance
        point_camera(camera, location, center)
        configure_camera_label(
            label,
            camera,
            view_name,
            camera_position_direction,
            dimensions,
            source_sha,
        )
        filename = RENDER_FILENAMES[view_name]
        scene.render.filepath = str(output_dir / filename)
        bpy.ops.render.render(write_still=True)
        render_records[view_name] = {
            "file": filename,
            "camera_location": vector_values(location),
            "view_direction": vector_values((center - location).normalized()),
            "camera_position_direction": vector_values(camera_position_direction),
            "projection": "PERSP",
            "lens_mm": round(float(camera.data.lens), 8),
            "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        }

    return render_records


def assert_render_outputs(output_dir: Path) -> None:
    for filename in RENDER_FILENAMES.values():
        path = output_dir / filename
        if not path.is_file() or path.stat().st_size <= 0:
            raise RuntimeError(f"Audit render missing or empty: {path}")


def main() -> None:
    global OUTPUT_DIR

    args = parse_args()
    OUTPUT_DIR = args.output_dir.resolve()
    source_path = Path(bpy.data.filepath).resolve()
    if not source_path.is_file():
        raise RuntimeError(f"Blender source file is unavailable: {source_path}")

    expected_sha = args.source_sha.lower()
    actual_sha = sha256_file(source_path)
    if actual_sha != expected_sha:
        raise RuntimeError(
            "Source SHA changed before Blender audit started: "
            f"expected {expected_sha}, got {actual_sha}"
        )

    ensure_output_directory(OUTPUT_DIR)
    source_meshes = visible_meshes()
    minimum, maximum = aggregate_bounds(source_meshes)
    center = (minimum + maximum) * 0.5
    dimensions = maximum - minimum
    if min(dimensions) <= 0.0:
        raise RuntimeError(f"Invalid aggregate fighter dimensions: {tuple(dimensions)}")

    object_records, material_records, empty_records, candidates = collect_source_evidence()
    overlay_collection, camera_label = build_overlay(
        minimum,
        maximum,
        center,
        dimensions,
    )
    camera = configure_scene(overlay_collection, center, dimensions)
    render_records = render_views(
        OUTPUT_DIR,
        camera,
        camera_label,
        center,
        dimensions,
        actual_sha,
    )
    assert_render_outputs(OUTPUT_DIR)

    report = {
        "schema_version": 1,
        "source": {
            "path": source_path.as_posix(),
            "sha256": actual_sha,
            "blender_version": bpy.app.version_string,
        },
        "aggregate_bounds": {
            "minimum": vector_values(minimum),
            "maximum": vector_values(maximum),
            "center": vector_values(center),
            "dimensions": vector_values(dimensions),
        },
        "objects": object_records,
        "materials": material_records,
        "empties": empty_records,
        "candidate_nozzle_names": candidates,
        "renders": render_records,
        "calibration_status": "unconfirmed",
        "notes": [
            "This report is structural evidence only.",
            "Nose, top, canonical dimensions, and thruster roles remain unconfirmed.",
        ],
    }
    report_path = OUTPUT_DIR / "ship_audit.json"
    report_path.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
    )
    if not report_path.is_file() or report_path.stat().st_size <= 0:
        raise RuntimeError(f"Audit report was not created: {report_path}")

    if sha256_file(source_path) != actual_sha:
        raise RuntimeError("Source SHA changed during Blender audit")

    print(f"Hero ship audit output: {OUTPUT_DIR}")
    print(f"Source SHA-256: {actual_sha}")
    print(f"Aggregate dimensions: {tuple(round(value, 6) for value in dimensions)}")
    print(f"Aggregate center: {tuple(round(value, 6) for value in center)}")
    print(f"Candidate nozzle names: {len(candidates)}")


if __name__ == "__main__":
    main()
