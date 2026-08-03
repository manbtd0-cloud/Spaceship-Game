from __future__ import annotations

from collections import Counter, defaultdict, deque
from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import bpy
from mathutils import Vector

import export_small_sci_fi_fighter as base
from small_fighter_calibration import SOURCE_FRAME_OBJECT

TARGET_MATERIALS = {"Muzzle", "Barrel", "Hull"}
FORWARD_AXIS = Vector((0.0, 1.0, 0.0))
FORWARD_NORMAL_DOT = 0.80
FORWARD_EXTENT_TOLERANCE = 0.20


def _material_name(obj: bpy.types.Object, index: int) -> str:
    if index < 0 or index >= len(obj.material_slots):
        return "<missing>"
    material = obj.material_slots[index].material
    return material.name if material is not None else "<none>"


def _polygon_components(
    mesh: bpy.types.Mesh,
    polygon_indices: list[int],
) -> list[list[int]]:
    vertex_to_polygons: dict[int, list[int]] = defaultdict(list)
    for polygon_index in polygon_indices:
        for vertex_index in mesh.polygons[polygon_index].vertices:
            vertex_to_polygons[int(vertex_index)].append(polygon_index)

    adjacency: dict[int, set[int]] = {
        polygon_index: set() for polygon_index in polygon_indices
    }
    for linked in vertex_to_polygons.values():
        for polygon_index in linked:
            adjacency[polygon_index].update(linked)
            adjacency[polygon_index].discard(polygon_index)

    components: list[list[int]] = []
    remaining = set(polygon_indices)
    while remaining:
        start = min(remaining)
        queue: deque[int] = deque([start])
        remaining.remove(start)
        component: list[int] = []
        while queue:
            current = queue.popleft()
            component.append(current)
            for neighbor in sorted(adjacency[current]):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
        components.append(sorted(component))
    return components


def _source_normal(
    normal_matrix: object,
    polygon: bpy.types.MeshPolygon,
) -> Vector:
    transformed = normal_matrix @ polygon.normal
    if transformed.length <= 1e-12:
        return Vector((0.0, 0.0, 0.0))
    return transformed.normalized()


def _component_report(
    source: bpy.types.Object,
    mesh: bpy.types.Mesh,
    transform: object,
    normal_matrix: object,
    material_name: str,
    component_index: int,
    polygon_indices: list[int],
) -> None:
    vertex_indices = sorted(
        {
            int(vertex_index)
            for polygon_index in polygon_indices
            for vertex_index in mesh.polygons[polygon_index].vertices
        }
    )
    points = [transform @ mesh.vertices[index].co for index in vertex_indices]
    minimum = Vector(
        tuple(min(point[axis] for point in points) for axis in range(3))
    )
    maximum = Vector(
        tuple(max(point[axis] for point in points) for axis in range(3))
    )
    centroid = sum(points, Vector((0.0, 0.0, 0.0))) / len(points)

    weighted_normal = Vector((0.0, 0.0, 0.0))
    forward_faces: list[tuple[int, float, float, tuple[float, float, float]]] = []
    for polygon_index in polygon_indices:
        polygon = mesh.polygons[polygon_index]
        normal = _source_normal(normal_matrix, polygon)
        weighted_normal += normal * max(float(polygon.area), 1e-8)
        polygon_points = [
            transform @ mesh.vertices[int(vertex_index)].co
            for vertex_index in polygon.vertices
        ]
        polygon_centroid = (
            sum(polygon_points, Vector((0.0, 0.0, 0.0)))
            / len(polygon_points)
        )
        dot = float(normal.dot(FORWARD_AXIS))
        if (
            dot >= FORWARD_NORMAL_DOT
            and maximum.y - polygon_centroid.y <= FORWARD_EXTENT_TOLERANCE
        ):
            forward_faces.append(
                (
                    polygon_index,
                    polygon_centroid.y,
                    dot,
                    tuple(round(float(value), 6) for value in polygon_centroid),
                )
            )

    average_normal = (
        weighted_normal.normalized()
        if weighted_normal.length > 1e-12
        else Vector((0.0, 0.0, 0.0))
    )
    print(
        "MATERIAL_COMPONENT "
        f"object={source.name!r} material={material_name!r} "
        f"component={component_index} polygons={len(polygon_indices)} "
        f"vertices={len(vertex_indices)} "
        f"centroid={tuple(round(float(value), 6) for value in centroid)} "
        f"bounds_min={tuple(round(float(value), 6) for value in minimum)} "
        f"bounds_max={tuple(round(float(value), 6) for value in maximum)} "
        f"average_normal={tuple(round(float(value), 6) for value in average_normal)} "
        f"forward_faces={len(forward_faces)}"
    )
    for polygon_index, centroid_y, dot, polygon_centroid in sorted(
        forward_faces,
        key=lambda item: (-item[1], item[0]),
    ):
        polygon = mesh.polygons[polygon_index]
        print(
            "FORWARD_FACE "
            f"object={source.name!r} material={material_name!r} "
            f"component={component_index} polygon={polygon_index} "
            f"vertices={len(polygon.vertices)} centroid={polygon_centroid} "
            f"normal_dot={dot:.6f} area={float(polygon.area):.9f}"
        )


def main() -> None:
    source_path = Path(bpy.data.filepath).resolve()
    source_frame = bpy.data.objects.get(SOURCE_FRAME_OBJECT)
    if source_frame is None or source_frame.type != "MESH":
        raise RuntimeError("Approved source frame Cube is missing")
    source_frame_inverse = source_frame.matrix_world.inverted_safe()

    print("=== PRIMARY MUZZLE MATERIAL COMPONENT DIAGNOSTIC ===")
    print(f"BLEND_FILE {source_path}")
    print(f"SOURCE_FRAME {SOURCE_FRAME_OBJECT}")

    for source in sorted(
        base.visible_mesh_objects(), key=lambda item: item.name.lower()
    ):
        if source.name.startswith("EngineFire"):
            continue
        depsgraph = bpy.context.evaluated_depsgraph_get()
        evaluated = source.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        try:
            transform = source_frame_inverse @ evaluated.matrix_world
            normal_matrix = transform.to_3x3().inverted_safe().transposed()
            material_counts: Counter[str] = Counter(
                _material_name(source, int(polygon.material_index))
                for polygon in mesh.polygons
            )
            print(
                "OBJECT_MATERIAL_COUNTS "
                f"object={source.name!r} counts={dict(sorted(material_counts.items()))}"
            )
            for material_name in sorted(TARGET_MATERIALS):
                polygon_indices = [
                    int(polygon.index)
                    for polygon in mesh.polygons
                    if _material_name(source, int(polygon.material_index))
                    == material_name
                ]
                if not polygon_indices:
                    print(
                        "MATERIAL_COMPONENT_SUMMARY "
                        f"object={source.name!r} material={material_name!r} "
                        "polygons=0 components=0"
                    )
                    continue
                components = _polygon_components(mesh, polygon_indices)
                print(
                    "MATERIAL_COMPONENT_SUMMARY "
                    f"object={source.name!r} material={material_name!r} "
                    f"polygons={len(polygon_indices)} components={len(components)}"
                )
                for component_index, component in enumerate(components):
                    _component_report(
                        source,
                        mesh,
                        transform,
                        normal_matrix,
                        material_name,
                        component_index,
                        component,
                    )
        finally:
            evaluated.to_mesh_clear()

    print("=== END PRIMARY MUZZLE MATERIAL COMPONENT DIAGNOSTIC ===")


if __name__ == "__main__":
    main()
