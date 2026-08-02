from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass

import bpy
from mathutils import Matrix, Vector

from small_fighter_calibration import (
    HULL_CENTER_LOCAL,
    PLUME_GROUPS,
    UNIFORM_SCALE,
    connected_components,
    group_spatial_component_indices,
)
from thruster_paths import classify_effect_name


@dataclass(frozen=True)
class EffectGeometryRecord:
    path: str
    socket_class: str
    source_object: str
    source_component_indices: tuple[int, ...]
    vertex_count: int
    face_count: int
    bounds_min_blender: Vector
    bounds_max_blender: Vector
    geometry_sha256: str


def _create_empty(
    name: str,
    parent: bpy.types.Object | None,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.parent = parent
    empty.matrix_parent_inverse = Matrix.Identity(4)
    empty.matrix_basis = Matrix.Identity(4)
    collection.objects.link(empty)
    return empty


def _hidden_import_material() -> bpy.types.Material:
    material = bpy.data.materials.new("RuntimeThrusterEffectHidden")
    material.diffuse_color = (0.05, 0.55, 1.0, 0.0)
    material.use_nodes = True
    if hasattr(material, "surface_render_method"):
        material.surface_render_method = "DITHERED"
    elif hasattr(material, "blend_method"):
        material.blend_method = "BLEND"

    node_tree = material.node_tree
    if node_tree is None:
        return material
    principled = next(
        (node for node in node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
        None,
    )
    if principled is not None:
        base_color = principled.inputs.get("Base Color")
        if base_color is not None:
            base_color.default_value = (0.05, 0.55, 1.0, 0.0)
        alpha = principled.inputs.get("Alpha")
        if alpha is not None:
            alpha.default_value = 0.0
        emission_color = principled.inputs.get("Emission Color") or principled.inputs.get("Emission")
        if emission_color is not None:
            emission_color.default_value = (0.0, 0.0, 0.0, 1.0)
        emission_strength = principled.inputs.get("Emission Strength")
        if emission_strength is not None:
            emission_strength.default_value = 0.0
    return material


def _geometry_digest(
    vertices: list[Vector],
    faces: list[tuple[int, ...]],
) -> str:
    digest = hashlib.sha256()
    digest.update(struct.pack("<II", len(vertices), len(faces)))
    for vertex in vertices:
        digest.update(struct.pack("<fff", float(vertex.x), float(vertex.y), float(vertex.z)))
    for face in faces:
        digest.update(struct.pack("<I", len(face)))
        for index in face:
            digest.update(struct.pack("<I", index))
    return digest.hexdigest()


def _bounds(vertices: list[Vector]) -> tuple[Vector, Vector]:
    if not vertices:
        raise RuntimeError("Source-exact thruster effect has no vertices")
    minimum = Vector(
        tuple(min(vertex[axis] for vertex in vertices) for axis in range(3))
    )
    maximum = Vector(
        tuple(max(vertex[axis] for vertex in vertices) for axis in range(3))
    )
    return minimum, maximum


def _evaluated_source_geometry(
    source: bpy.types.Object,
    source_frame_inverse: Matrix,
) -> tuple[list[Vector], list[tuple[int, ...]], list[list[int]]]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = source.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        transform = source_frame_inverse @ evaluated.matrix_world
        source_vertices = [transform @ vertex.co for vertex in mesh.vertices]
        source_faces = [tuple(polygon.vertices) for polygon in mesh.polygons]
        edges = [(edge.vertices[0], edge.vertices[1]) for edge in mesh.edges]
        components = connected_components(len(mesh.vertices), edges)
        return source_vertices, source_faces, components
    finally:
        evaluated.to_mesh_clear()


def _extract_group_mesh(
    source_vertices: list[Vector],
    source_faces: list[tuple[int, ...]],
    raw_components: list[list[int]],
    component_indices: list[int],
) -> tuple[list[Vector], list[tuple[int, ...]]]:
    selected_source_indices = sorted(
        {
            vertex_index
            for component_index in component_indices
            for vertex_index in raw_components[component_index]
        }
    )
    if len(selected_source_indices) < 4:
        raise RuntimeError(
            f"Source-exact plume group has too few vertices: {selected_source_indices}"
        )

    index_map = {
        source_index: local_index
        for local_index, source_index in enumerate(selected_source_indices)
    }
    canonical_vertices = [
        (source_vertices[source_index] - Vector(HULL_CENTER_LOCAL)) * UNIFORM_SCALE
        for source_index in selected_source_indices
    ]
    canonical_faces: list[tuple[int, ...]] = []
    selected_set = set(selected_source_indices)
    for face in source_faces:
        membership = [index in selected_set for index in face]
        if any(membership) and not all(membership):
            raise RuntimeError(
                "A source face crosses physical plume component boundaries: "
                f"{face}"
            )
        if all(membership):
            canonical_faces.append(tuple(index_map[index] for index in face))

    if not canonical_faces:
        raise RuntimeError("Source-exact plume group has no faces")
    return canonical_vertices, canonical_faces


def _create_effect_mesh(
    path: str,
    socket_class: str,
    source_object: str,
    component_indices: list[int],
    vertices: list[Vector],
    faces: list[tuple[int, ...]],
    parent: bpy.types.Object,
    collection: bpy.types.Collection,
    material: bpy.types.Material,
) -> EffectGeometryRecord:
    leaf_name = path.split("/")[-1]
    mesh_data = bpy.data.meshes.new(leaf_name)
    mesh_data.from_pydata([tuple(vertex) for vertex in vertices], [], faces)
    mesh_data.validate(clean_customdata=False)
    mesh_data.update()
    mesh_data.materials.append(material)

    effect = bpy.data.objects.new(leaf_name, mesh_data)
    effect.parent = parent
    effect.matrix_parent_inverse = Matrix.Identity(4)
    effect.matrix_basis = Matrix.Identity(4)
    effect["thruster_class"] = socket_class
    effect["source_object"] = source_object
    effect["source_component_indices"] = list(component_indices)
    effect["source_exact_geometry"] = True
    collection.objects.link(effect)

    minimum, maximum = _bounds(vertices)
    return EffectGeometryRecord(
        path=path,
        socket_class=socket_class,
        source_object=source_object,
        source_component_indices=tuple(component_indices),
        vertex_count=len(vertices),
        face_count=len(faces),
        bounds_min_blender=minimum,
        bounds_max_blender=maximum,
        geometry_sha256=_geometry_digest(vertices, faces),
    )


def build_source_exact_thruster_effects(
    root: bpy.types.Object,
    collection: bpy.types.Collection,
    source_frame_inverse: Matrix,
) -> list[EffectGeometryRecord]:
    effect_root = _create_empty("ThrusterEffects", root, collection)
    group_nodes: dict[str, bpy.types.Object] = {
        "Main": _create_empty("MainEffects", effect_root, collection),
        "Retro": _create_empty("RetroEffects", effect_root, collection),
        "Maneuver": _create_empty("ManeuverEffects", effect_root, collection),
    }
    material = _hidden_import_material()
    records: list[EffectGeometryRecord] = []

    for source_name, specification in PLUME_GROUPS.items():
        source = bpy.data.objects.get(source_name)
        if source is None or source.type != "MESH":
            raise RuntimeError(f"Source-exact exhaust mesh is missing: {source_name}")

        source_vertices, source_faces, raw_components = _evaluated_source_geometry(
            source,
            source_frame_inverse,
        )
        component_points = [
            [tuple(source_vertices[index]) for index in component]
            for component in raw_components
        ]
        component_groups = group_spatial_component_indices(
            component_points,
            int(specification["sockets"]),
        )

        for component_indices in component_groups:
            vertices, faces = _extract_group_mesh(
                source_vertices,
                source_faces,
                raw_components,
                component_indices,
            )
            centroid = sum(vertices, Vector((0.0, 0.0, 0.0))) / len(vertices)
            effect_path = classify_effect_name(
                str(specification["group"]),
                tuple(centroid),
            )
            parent_group = (
                "Maneuver"
                if str(specification["class"]) == "maneuver"
                else str(specification["group"])
            )
            records.append(
                _create_effect_mesh(
                    effect_path,
                    str(specification["class"]),
                    source_name,
                    component_indices,
                    vertices,
                    faces,
                    group_nodes[parent_group],
                    collection,
                    material,
                )
            )

    records.sort(key=lambda record: record.path)
    paths = [record.path for record in records]
    if len(records) != 12 or len(set(paths)) != 12:
        raise RuntimeError(
            f"Expected twelve unique source-exact effect meshes, got {paths}"
        )
    return records
