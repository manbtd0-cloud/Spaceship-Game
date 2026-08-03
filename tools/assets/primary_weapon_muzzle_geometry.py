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
class MuzzleRecord:
    path: str
    side: str
    source_object: str
    source_vertex_indices: tuple[int, ...]
    canonical_origin: Point3
    canonical_basis_rows: tuple[Point3, Point3, Point3]
    canonical_forward: Point3
    extraction_error_m: float


def _distance(left: Point3, right: Point3) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


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
