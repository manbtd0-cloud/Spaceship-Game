from __future__ import annotations

import math
from typing import Sequence

Point3 = tuple[float, float, float]
Basis3 = tuple[Point3, Point3, Point3]

# Blender vectors become canonical/glTF vectors as (x, z, -y).
_BLENDER_TO_CANONICAL: Basis3 = (
    (1.0, 0.0, 0.0),
    (0.0, 0.0, 1.0),
    (0.0, -1.0, 0.0),
)
_CANONICAL_TO_BLENDER: Basis3 = (
    (1.0, 0.0, 0.0),
    (0.0, 0.0, -1.0),
    (0.0, 1.0, 0.0),
)


def _basis(value: Sequence[Sequence[float]]) -> Basis3:
    if len(value) != 3 or any(len(row) != 3 for row in value):
        raise ValueError("basis must contain exactly three rows of three numbers")
    rows = tuple(
        tuple(float(component) for component in row)
        for row in value
    )
    if not all(math.isfinite(component) for row in rows for component in row):
        raise ValueError("basis values must be finite")
    return rows  # type: ignore[return-value]


def _multiply(left: Basis3, right: Basis3) -> Basis3:
    return tuple(
        tuple(
            sum(left[row][axis] * right[axis][column] for axis in range(3))
            for column in range(3)
        )
        for row in range(3)
    )  # type: ignore[return-value]


def canonical_origin_to_blender(origin: Sequence[float]) -> Point3:
    if len(origin) != 3:
        raise ValueError("origin must contain exactly three numbers")
    x, y, z = (float(component) for component in origin)
    if not all(math.isfinite(component) for component in (x, y, z)):
        raise ValueError("origin values must be finite")
    return (x, -z, y)


def canonical_basis_to_blender_rows(
    canonical_basis: Sequence[Sequence[float]],
) -> Basis3:
    """Convert a canonical node transform into Blender object coordinates.

    Blender's glTF exporter changes both the world and local coordinate frames.
    Therefore a node basis must be converted by conjugation rather than by
    transforming only its columns:

        blender = C^-1 * canonical * C
    """

    canonical = _basis(canonical_basis)
    return _multiply(
        _multiply(_CANONICAL_TO_BLENDER, canonical),
        _BLENDER_TO_CANONICAL,
    )


def blender_basis_to_canonical_rows(
    blender_basis: Sequence[Sequence[float]],
) -> Basis3:
    blender = _basis(blender_basis)
    return _multiply(
        _multiply(_BLENDER_TO_CANONICAL, blender),
        _CANONICAL_TO_BLENDER,
    )
