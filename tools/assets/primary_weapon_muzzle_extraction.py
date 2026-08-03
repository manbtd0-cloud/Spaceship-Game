from __future__ import annotations

from collections import Counter
import math
from typing import Iterable, Sequence

try:
    from .primary_weapon_muzzle_geometry import (
        MuzzleCandidate,
        MuzzleRecord,
        classify_primary_muzzle_path,
        select_primary_muzzle_pair,
    )
except ImportError:  # pragma: no cover - Blender script path
    from primary_weapon_muzzle_geometry import (
        MuzzleCandidate,
        MuzzleRecord,
        classify_primary_muzzle_path,
        select_primary_muzzle_pair,
    )

Point3 = tuple[float, float, float]
Edge = tuple[int, int]

FORWARD_REGION_START: float | None = None
MIN_LOOP_VERTICES = 6
MAX_LOOP_VERTICES = 64
MAX_PLANARITY_ERROR_SOURCE = 0.02
MAX_CIRCULARITY_RATIO = 1.35
MIN_RADIUS_SOURCE = 0.04
MAX_RADIUS_SOURCE = 0.60


def _subtract(left: Point3, right: Point3) -> Point3:
    return tuple(a - b for a, b in zip(left, right))  # type: ignore[return-value]


def _dot(left: Point3, right: Point3) -> float:
    return sum(a * b for a, b in zip(left, right))


def _length(value: Point3) -> float:
    return math.sqrt(_dot(value, value))


def _normalize(value: Point3) -> Point3:
    length = _length(value)
    if length <= 1e-12:
        raise ValueError("boundary loop normal is degenerate")
    return tuple(component / length for component in value)  # type: ignore[return-value]


def choose_track_up_axis(forward: Point3) -> str:
    normalized = _normalize(forward)
    return "X" if abs(normalized[1]) > 0.98 else "Y"


def _canonical_edge(left: int, right: int) -> Edge:
    if left == right:
        raise ValueError("boundary edges must connect distinct vertices")
    return (left, right) if left < right else (right, left)


def trace_boundary_loops(boundary_edges: Iterable[Edge]) -> list[tuple[int, ...]]:
    edges = {
        _canonical_edge(int(left), int(right))
        for left, right in boundary_edges
    }
    adjacency: dict[int, set[int]] = {}
    for left, right in edges:
        adjacency.setdefault(left, set()).add(right)
        adjacency.setdefault(right, set()).add(left)
    if not edges or any(
        len(neighbors) != 2 for neighbors in adjacency.values()
    ):
        raise ValueError("boundary edges must form closed degree-two loops")

    unvisited = set(edges)
    loops: list[tuple[int, ...]] = []
    while unvisited:
        component_vertices = {
            vertex for edge in unvisited for vertex in edge
        }
        start = min(component_vertices)
        previous: int | None = None
        current = start
        loop: list[int] = []
        while True:
            loop.append(current)
            neighbors = sorted(adjacency[current])
            next_candidates = [value for value in neighbors if value != previous]
            if not next_candidates:
                raise ValueError(
                    "boundary edges must form closed degree-two loops"
                )
            next_vertex = next_candidates[0]
            edge = _canonical_edge(current, next_vertex)
            if edge not in unvisited:
                if next_vertex == start and len(loop) >= 3:
                    break
                if len(next_candidates) > 1:
                    next_vertex = next_candidates[1]
                    edge = _canonical_edge(current, next_vertex)
                if edge not in unvisited:
                    raise ValueError(
                        "boundary edges must form closed degree-two loops"
                    )
            unvisited.remove(edge)
            previous, current = current, next_vertex
            if current == start:
                break
        if len(loop) < 3:
            raise ValueError("boundary edges must form closed degree-two loops")
        loops.append(tuple(loop))
    return sorted(loops)


def _newell_normal(points: Sequence[Point3]) -> Point3:
    nx = ny = nz = 0.0
    for index, current in enumerate(points):
        following = points[(index + 1) % len(points)]
        nx += (current[1] - following[1]) * (
            current[2] + following[2]
        )
        ny += (current[2] - following[2]) * (
            current[0] + following[0]
        )
        nz += (current[0] - following[0]) * (
            current[1] + following[1]
        )
    return _normalize((nx, ny, nz))


def build_candidate_from_loop(
    source_object: str,
    source_vertex_indices: tuple[int, ...],
    points: Sequence[Point3],
    *,
    forward_axis: Point3,
) -> MuzzleCandidate:
    if len(points) != len(source_vertex_indices) or len(points) < 3:
        raise ValueError("boundary loop points and indices must match")
    centroid = tuple(
        sum(point[axis] for point in points) / len(points)
        for axis in range(3)
    )
    normal = _newell_normal(points)
    normalized_forward = _normalize(forward_axis)
    if _dot(normal, normalized_forward) < 0.0:
        normal = tuple(-component for component in normal)  # type: ignore[assignment]

    radial_distances: list[float] = []
    planarity_error = 0.0
    for point in points:
        offset = _subtract(point, centroid)
        axial = _dot(offset, normal)
        planarity_error = max(planarity_error, abs(axial))
        radial = _subtract(
            offset,
            tuple(normal[index] * axial for index in range(3)),
        )
        radial_distances.append(_length(radial))
    radius = sum(radial_distances) / len(radial_distances)
    minimum_radius = min(radial_distances)
    circularity_ratio = (
        max(radial_distances) / minimum_radius
        if minimum_radius > 1e-12
        else math.inf
    )
    return MuzzleCandidate(
        source_object=source_object,
        source_vertex_indices=tuple(source_vertex_indices),
        centroid=centroid,  # type: ignore[arg-type]
        normal=normal,
        radius=radius,
        planarity_error=planarity_error,
        circularity_ratio=circularity_ratio,
    )


def _forward_region_start() -> float:
    if FORWARD_REGION_START is not None:
        return FORWARD_REGION_START
    from small_fighter_calibration import (
        HULL_CENTER_LOCAL,
        SOURCE_HULL_DIMENSIONS,
    )

    return HULL_CENTER_LOCAL[1] + SOURCE_HULL_DIMENSIONS[1] * 0.15


def _candidates_from_source(
    source: object,
    source_frame_inverse: object,
) -> list[MuzzleCandidate]:
    import bpy

    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = source.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        edge_use: Counter[Edge] = Counter()
        for polygon in mesh.polygons:
            for left, right in polygon.edge_keys:
                edge_use[
                    _canonical_edge(int(left), int(right))
                ] += 1
        boundary_edges = [
            edge for edge, count in edge_use.items() if count == 1
        ]
        if not boundary_edges:
            return []
        loops = trace_boundary_loops(boundary_edges)
        transform = source_frame_inverse @ evaluated.matrix_world
        candidates: list[MuzzleCandidate] = []
        for loop in loops:
            if not MIN_LOOP_VERTICES <= len(loop) <= MAX_LOOP_VERTICES:
                continue
            points = [
                transform @ mesh.vertices[index].co for index in loop
            ]
            tuples = [
                tuple(float(value) for value in point) for point in points
            ]
            candidate = build_candidate_from_loop(
                str(source.name),
                loop,
                tuples,
                forward_axis=(0.0, 1.0, 0.0),
            )
            if candidate.centroid[1] < _forward_region_start():
                continue
            if candidate.planarity_error > MAX_PLANARITY_ERROR_SOURCE:
                continue
            if candidate.circularity_ratio > MAX_CIRCULARITY_RATIO:
                continue
            if not MIN_RADIUS_SOURCE <= candidate.radius <= MAX_RADIUS_SOURCE:
                continue
            candidates.append(candidate)
        return candidates
    finally:
        evaluated.to_mesh_clear()


def extract_primary_muzzles(
    source_frame_inverse: object,
    hull_center: Sequence[float],
    scale: float,
) -> list[MuzzleRecord]:
    from mathutils import Vector
    import export_small_sci_fi_fighter as base

    candidates: list[MuzzleCandidate] = []
    for source in sorted(
        base.visible_mesh_objects(),
        key=lambda item: item.name.lower(),
    ):
        if source.name.startswith("EngineFire"):
            continue
        candidates.extend(
            _candidates_from_source(source, source_frame_inverse)
        )

    selected = select_primary_muzzle_pair(candidates)
    records: list[MuzzleRecord] = []
    for candidate in selected:
        origin_blender = (
            Vector(candidate.centroid) - Vector(tuple(hull_center))
        ) * scale
        forward_blender = Vector(candidate.normal).normalized()
        up_axis = choose_track_up_axis(
            tuple(float(value) for value in forward_blender)
        )
        basis_blender = (
            forward_blender
            .to_track_quat("-Z", up_axis)
            .to_matrix()
            .to_4x4()
        )
        canonical_origin = tuple(
            base.blender_to_godot_vector(origin_blender)
        )
        basis_rows = tuple(
            tuple(float(value) for value in row)
            for row in base.blender_basis_to_godot_rows(basis_blender)
        )
        canonical_forward_vector = Vector(
            base.blender_to_godot_vector(forward_blender)
        ).normalized()
        canonical_forward = tuple(
            float(value) for value in canonical_forward_vector
        )
        path = classify_primary_muzzle_path(canonical_origin)
        records.append(
            MuzzleRecord(
                path=path,
                side="left" if canonical_origin[0] < 0.0 else "right",
                source_object=candidate.source_object,
                source_vertex_indices=candidate.source_vertex_indices,
                canonical_origin=canonical_origin,  # type: ignore[arg-type]
                canonical_basis_rows=basis_rows,  # type: ignore[arg-type]
                canonical_forward=canonical_forward,  # type: ignore[arg-type]
                extraction_error_m=candidate.planarity_error * scale,
            )
        )
    records.sort(key=lambda record: record.side)
    if [record.side for record in records] != ["left", "right"]:
        raise RuntimeError(
            "primary muzzle extraction did not yield left/right records"
        )
    return records


def record_to_blender_transform(record: MuzzleRecord) -> tuple[object, object]:
    from mathutils import Vector

    origin = Vector(
        (
            record.canonical_origin[0],
            -record.canonical_origin[2],
            record.canonical_origin[1],
        )
    )
    forward = Vector(
        (
            record.canonical_forward[0],
            -record.canonical_forward[2],
            record.canonical_forward[1],
        )
    ).normalized()
    up_axis = choose_track_up_axis(
        tuple(float(value) for value in forward)
    )
    basis = forward.to_track_quat("-Z", up_axis).to_matrix().to_4x4()
    return origin, basis
