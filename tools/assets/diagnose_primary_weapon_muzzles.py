from __future__ import annotations

from collections import Counter
from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import bpy
from mathutils import Vector

import export_small_sci_fi_fighter as base
from primary_weapon_muzzle_extraction import (
    MAX_CIRCULARITY_RATIO,
    MAX_LOOP_VERTICES,
    MAX_PLANARITY_ERROR_SOURCE,
    MAX_RADIUS_SOURCE,
    MIN_LOOP_VERTICES,
    MIN_RADIUS_SOURCE,
    _canonical_edge,
    _forward_region_start,
    build_candidate_from_loop,
    trace_boundary_loops,
)
from primary_weapon_muzzle_geometry import MuzzleCandidate
from small_fighter_calibration import SOURCE_FRAME_OBJECT


MAX_PRINTED_BOUNDARY_LOOPS = 80
MAX_PRINTED_FORWARD_POLYGONS = 80


def _candidate_reasons(candidate: MuzzleCandidate) -> list[str]:
    reasons: list[str] = []
    if len(candidate.source_vertex_indices) < MIN_LOOP_VERTICES:
        reasons.append("too_few_vertices")
    if len(candidate.source_vertex_indices) > MAX_LOOP_VERTICES:
        reasons.append("too_many_vertices")
    if candidate.centroid[1] < _forward_region_start():
        reasons.append("behind_forward_region")
    if candidate.centroid[1] <= 0.0:
        reasons.append("not_source_forward")
    if abs(candidate.centroid[0]) < 0.10:
        reasons.append("centerline")
    if abs(candidate.normal[1]) < 0.90:
        reasons.append("normal_not_forward")
    if candidate.planarity_error > MAX_PLANARITY_ERROR_SOURCE:
        reasons.append("nonplanar")
    if candidate.circularity_ratio > MAX_CIRCULARITY_RATIO:
        reasons.append("noncircular")
    if not MIN_RADIUS_SOURCE <= candidate.radius <= MAX_RADIUS_SOURCE:
        reasons.append("radius_out_of_range")
    return reasons


def _format_candidate(kind: str, candidate: MuzzleCandidate) -> str:
    reasons = _candidate_reasons(candidate)
    return (
        f"{kind} object={candidate.source_object!r} "
        f"vertices={len(candidate.source_vertex_indices)} "
        f"centroid=({candidate.centroid[0]:.6f},"
        f"{candidate.centroid[1]:.6f},{candidate.centroid[2]:.6f}) "
        f"normal=({candidate.normal[0]:.6f},"
        f"{candidate.normal[1]:.6f},{candidate.normal[2]:.6f}) "
        f"radius={candidate.radius:.6f} "
        f"planarity={candidate.planarity_error:.6f} "
        f"circularity={candidate.circularity_ratio:.6f} "
        f"accepted={'yes' if not reasons else 'no'} "
        f"reasons={','.join(reasons) if reasons else '-'}"
    )


def _diagnose_source(source: bpy.types.Object, source_frame_inverse: object) -> tuple[int, int]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = source.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        transform = source_frame_inverse @ evaluated.matrix_world
        edge_use: Counter[tuple[int, int]] = Counter()
        for polygon in mesh.polygons:
            for left, right in polygon.edge_keys:
                edge_use[_canonical_edge(int(left), int(right))] += 1
        boundary_edges = [edge for edge, count in edge_use.items() if count == 1]
        material_names = [
            slot.material.name if slot.material is not None else "<none>"
            for slot in source.material_slots
        ]
        print(
            "SOURCE_OBJECT "
            f"name={source.name!r} vertices={len(mesh.vertices)} "
            f"polygons={len(mesh.polygons)} boundary_edges={len(boundary_edges)} "
            f"materials={material_names}"
        )

        accepted_boundaries = 0
        boundary_count = 0
        if boundary_edges:
            try:
                loops = trace_boundary_loops(boundary_edges)
            except ValueError as error:
                degrees: Counter[int] = Counter()
                adjacency: dict[int, set[int]] = {}
                for left, right in boundary_edges:
                    adjacency.setdefault(left, set()).add(right)
                    adjacency.setdefault(right, set()).add(left)
                for neighbors in adjacency.values():
                    degrees[len(neighbors)] += 1
                print(
                    f"BOUNDARY_TOPOLOGY_ERROR object={source.name!r} "
                    f"error={str(error)!r} degree_histogram={dict(degrees)}"
                )
                loops = []
            boundary_count = len(loops)
            print(f"BOUNDARY_SUMMARY object={source.name!r} loops={boundary_count}")
            for loop_index, loop in enumerate(loops):
                points = [transform @ mesh.vertices[index].co for index in loop]
                tuples = [tuple(float(value) for value in point) for point in points]
                try:
                    candidate = build_candidate_from_loop(
                        str(source.name),
                        loop,
                        tuples,
                        forward_axis=(0.0, 1.0, 0.0),
                    )
                except ValueError as error:
                    print(
                        f"BOUNDARY_LOOP_ERROR object={source.name!r} "
                        f"index={loop_index} vertices={len(loop)} error={str(error)!r}"
                    )
                    continue
                if not _candidate_reasons(candidate):
                    accepted_boundaries += 1
                if loop_index < MAX_PRINTED_BOUNDARY_LOOPS:
                    print(_format_candidate("BOUNDARY_LOOP", candidate))

        polygon_candidates: list[tuple[float, MuzzleCandidate, int, str]] = []
        for polygon_index, polygon in enumerate(mesh.polygons):
            if not MIN_LOOP_VERTICES <= len(polygon.vertices) <= MAX_LOOP_VERTICES:
                continue
            loop = tuple(int(index) for index in polygon.vertices)
            points = [transform @ mesh.vertices[index].co for index in loop]
            tuples = [tuple(float(value) for value in point) for point in points]
            try:
                candidate = build_candidate_from_loop(
                    str(source.name),
                    loop,
                    tuples,
                    forward_axis=(0.0, 1.0, 0.0),
                )
            except ValueError:
                continue
            if candidate.centroid[1] < _forward_region_start():
                continue
            material_name = "<none>"
            if 0 <= polygon.material_index < len(source.material_slots):
                material = source.material_slots[polygon.material_index].material
                if material is not None:
                    material_name = material.name
            polygon_candidates.append(
                (candidate.centroid[1], candidate, polygon_index, material_name)
            )

        polygon_candidates.sort(key=lambda item: item[0], reverse=True)
        print(
            f"FORWARD_POLYGON_SUMMARY object={source.name!r} "
            f"polygons={len(polygon_candidates)}"
        )
        for _, candidate, polygon_index, material_name in polygon_candidates[
            :MAX_PRINTED_FORWARD_POLYGONS
        ]:
            print(
                _format_candidate("FORWARD_POLYGON", candidate)
                + f" polygon={polygon_index} material={material_name!r}"
            )
        return accepted_boundaries, len(polygon_candidates)
    finally:
        evaluated.to_mesh_clear()


def main() -> None:
    source_frame = bpy.data.objects.get(SOURCE_FRAME_OBJECT)
    if source_frame is None or source_frame.type != "MESH":
        raise RuntimeError("Approved source frame Cube is missing")
    source_frame_inverse = source_frame.matrix_world.inverted_safe()

    print("=== PRIMARY MUZZLE SOURCE DIAGNOSTIC ===")
    print(f"BLEND_FILE {bpy.data.filepath}")
    print(f"SOURCE_FRAME {SOURCE_FRAME_OBJECT}")
    print(f"FORWARD_REGION_START {_forward_region_start():.6f}")
    print(
        "FILTERS "
        f"vertices={MIN_LOOP_VERTICES}..{MAX_LOOP_VERTICES} "
        f"radius={MIN_RADIUS_SOURCE}..{MAX_RADIUS_SOURCE} "
        f"planarity<={MAX_PLANARITY_ERROR_SOURCE} "
        f"circularity<={MAX_CIRCULARITY_RATIO}"
    )

    accepted_total = 0
    forward_polygon_total = 0
    object_count = 0
    for source in sorted(
        base.visible_mesh_objects(),
        key=lambda item: item.name.lower(),
    ):
        if source.name.startswith("EngineFire"):
            continue
        object_count += 1
        accepted, polygons = _diagnose_source(source, source_frame_inverse)
        accepted_total += accepted
        forward_polygon_total += polygons

    print(
        "DIAGNOSTIC_SUMMARY "
        f"objects={object_count} accepted_boundary_candidates={accepted_total} "
        f"forward_polygon_candidates={forward_polygon_total}"
    )
    print("=== END PRIMARY MUZZLE SOURCE DIAGNOSTIC ===")


if __name__ == "__main__":
    main()
