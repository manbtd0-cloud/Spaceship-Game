from __future__ import annotations

from dataclasses import dataclass
import math


Point3 = tuple[float, float, float]


@dataclass(frozen=True)
class MuzzleCandidate:
    source_object: str
    source_vertex_indices: tuple[int, ...]
    centroid: Point3
    normal: Point3
    radius: float
    planarity_error: float
    circularity_ratio: float


@dataclass(frozen=True)
class BarrelComponentEvidence:
    source_object: str
    source_material: str
    source_component: int
    source_vertex_indices: tuple[int, ...]
    centroid: Point3
    bounds_min: Point3
    bounds_max: Point3


@dataclass(frozen=True)
class MuzzleSourceTip:
    source_object: str
    source_material: str
    source_component: int
    source_vertex_indices: tuple[int, ...]
    centroid: Point3
    forward: Point3
    extraction_error_source: float


@dataclass(frozen=True)
class MuzzleRecord:
    path: str
    side: str
    source_object: str
    source_material: str
    source_component: int
    source_vertex_indices: tuple[int, ...]
    canonical_origin: Point3
    canonical_basis_rows: tuple[Point3, Point3, Point3]
    canonical_forward: Point3
    extraction_error_m: float


PRIMARY_BARREL_MIRROR_TOLERANCE_SOURCE = 0.15
PRIMARY_BARREL_EXTENT_TOLERANCE_SOURCE = 0.15
PRIMARY_BARREL_FORWARD_SEPARATION_SOURCE = 0.25


def _distance(left: Point3, right: Point3) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def _dimensions(item: BarrelComponentEvidence) -> Point3:
    return tuple(
        maximum - minimum
        for minimum, maximum in zip(item.bounds_min, item.bounds_max)
    )  # type: ignore[return-value]


def classify_primary_muzzle_path(origin: Point3) -> str:
    if origin[0] < 0.0:
        return "Weapons/Primary/LeftMuzzle"
    if origin[0] > 0.0:
        return "Weapons/Primary/RightMuzzle"
    raise ValueError("primary muzzle cannot lie on the fighter centerline")


def select_primary_muzzle_pair(
    candidates: list[MuzzleCandidate],
) -> tuple[MuzzleCandidate, MuzzleCandidate]:
    valid = [
        item
        for item in candidates
        if len(item.source_vertex_indices) >= 6
        and item.centroid[1] > 0.0
        and abs(item.normal[1]) >= 0.90
        and 0.04 <= item.radius <= 0.60
        and item.planarity_error <= 0.02
        and item.circularity_ratio <= 1.35
        and abs(item.centroid[0]) >= 0.10
    ]
    pairs: list[tuple[MuzzleCandidate, MuzzleCandidate]] = []
    for left in [item for item in valid if item.centroid[0] < 0.0]:
        for right in [item for item in valid if item.centroid[0] > 0.0]:
            mirrored = (
                abs(abs(left.centroid[0]) - abs(right.centroid[0])) <= 0.15
                and abs(left.centroid[1] - right.centroid[1]) <= 0.15
                and abs(left.centroid[2] - right.centroid[2]) <= 0.15
                and abs(left.radius - right.radius)
                <= max(left.radius, right.radius) * 0.10
                and _distance(left.normal, right.normal) <= 0.20
            )
            if mirrored:
                pairs.append((left, right))
    if len(pairs) != 1:
        raise ValueError(
            "expected exactly one primary muzzle pair, "
            f"found {len(pairs)}"
        )
    return pairs[0]


def select_primary_barrel_component_pair(
    components: list[BarrelComponentEvidence],
) -> tuple[BarrelComponentEvidence, BarrelComponentEvidence]:
    valid = [
        item
        for item in components
        if item.source_material == "Barrel"
        and abs(item.centroid[0]) >= 0.10
        and item.bounds_max[1] > 0.0
        and item.source_vertex_indices
    ]
    scored_pairs: list[
        tuple[
            float,
            BarrelComponentEvidence,
            BarrelComponentEvidence,
        ]
    ] = []
    for left in [item for item in valid if item.centroid[0] < 0.0]:
        left_dimensions = _dimensions(left)
        for right in [item for item in valid if item.centroid[0] > 0.0]:
            right_dimensions = _dimensions(right)
            mirrored = (
                abs(abs(left.centroid[0]) - abs(right.centroid[0]))
                <= PRIMARY_BARREL_MIRROR_TOLERANCE_SOURCE
                and abs(left.centroid[1] - right.centroid[1])
                <= PRIMARY_BARREL_MIRROR_TOLERANCE_SOURCE
                and abs(left.centroid[2] - right.centroid[2])
                <= PRIMARY_BARREL_MIRROR_TOLERANCE_SOURCE
                and abs(left.bounds_max[1] - right.bounds_max[1])
                <= PRIMARY_BARREL_EXTENT_TOLERANCE_SOURCE
                and all(
                    abs(left_value - right_value)
                    <= PRIMARY_BARREL_EXTENT_TOLERANCE_SOURCE
                    for left_value, right_value in zip(
                        left_dimensions,
                        right_dimensions,
                    )
                )
            )
            if mirrored:
                scored_pairs.append(
                    (
                        min(left.bounds_max[1], right.bounds_max[1]),
                        left,
                        right,
                    )
                )
    if not scored_pairs:
        raise ValueError("no mirrored Barrel component pair was found")
    scored_pairs.sort(
        key=lambda item: (
            -item[0],
            item[1].source_object,
            item[1].source_component,
            item[2].source_component,
        )
    )
    best_score, best_left, best_right = scored_pairs[0]
    if (
        len(scored_pairs) > 1
        and best_score - scored_pairs[1][0]
        < PRIMARY_BARREL_FORWARD_SEPARATION_SOURCE
    ):
        raise ValueError(
            "front-most Barrel component pair is ambiguous: "
            f"scores={best_score:.6f},{scored_pairs[1][0]:.6f}"
        )
    return best_left, best_right
