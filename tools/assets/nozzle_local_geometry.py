from __future__ import annotations

import math
from collections.abc import Iterable, Sequence

Point3 = tuple[float, float, float]
BasisRows = tuple[Point3, Point3, Point3]


def _subtract(left: Point3, right: Point3) -> Point3:
    return tuple(left[index] - right[index] for index in range(3))  # type: ignore[return-value]


def _add(left: Point3, right: Point3) -> Point3:
    return tuple(left[index] + right[index] for index in range(3))  # type: ignore[return-value]


def _dot(left: Point3, right: Point3) -> float:
    return sum(left[index] * right[index] for index in range(3))


def _length(value: Point3) -> float:
    return math.sqrt(_dot(value, value))


def validate_basis_rows(basis_rows: Sequence[Sequence[float]]) -> BasisRows:
    if len(basis_rows) != 3 or any(len(row) != 3 for row in basis_rows):
        raise ValueError("basis must contain three rows of three numbers")
    rows: BasisRows = tuple(  # type: ignore[assignment]
        tuple(float(component) for component in row)
        for row in basis_rows
    )
    if any(not math.isfinite(component) for row in rows for component in row):
        raise ValueError("basis must contain finite numbers")
    for row in rows:
        if abs(_length(row) - 1.0) > 1e-5:
            raise ValueError("basis rows must be unit length")
    for left in range(3):
        for right in range(left + 1, 3):
            if abs(_dot(rows[left], rows[right])) > 1e-5:
                raise ValueError("basis rows must be orthogonal")
    return rows


def canonical_vertices_to_nozzle_local(
    canonical_vertices: Iterable[Sequence[float]],
    origin: Sequence[float],
    basis_rows: Sequence[Sequence[float]],
) -> list[Point3]:
    basis = validate_basis_rows(basis_rows)
    canonical_origin: Point3 = tuple(float(value) for value in origin)  # type: ignore[assignment]
    if len(canonical_origin) != 3 or any(
        not math.isfinite(component) for component in canonical_origin
    ):
        raise ValueError("origin must contain three finite numbers")

    result: list[Point3] = []
    for raw_vertex in canonical_vertices:
        vertex: Point3 = tuple(float(value) for value in raw_vertex)  # type: ignore[assignment]
        if len(vertex) != 3 or any(not math.isfinite(component) for component in vertex):
            raise ValueError("vertices must contain three finite numbers")
        offset = _subtract(vertex, canonical_origin)
        result.append(
            (
                basis[0][0] * offset[0]
                + basis[1][0] * offset[1]
                + basis[2][0] * offset[2],
                basis[0][1] * offset[0]
                + basis[1][1] * offset[1]
                + basis[2][1] * offset[2],
                basis[0][2] * offset[0]
                + basis[1][2] * offset[1]
                + basis[2][2] * offset[2],
            )
        )
    return result


def reconstruct_canonical_vertices(
    local_vertices: Iterable[Sequence[float]],
    origin: Sequence[float],
    basis_rows: Sequence[Sequence[float]],
) -> list[Point3]:
    basis = validate_basis_rows(basis_rows)
    canonical_origin: Point3 = tuple(float(value) for value in origin)  # type: ignore[assignment]
    if len(canonical_origin) != 3 or any(
        not math.isfinite(component) for component in canonical_origin
    ):
        raise ValueError("origin must contain three finite numbers")

    result: list[Point3] = []
    for raw_vertex in local_vertices:
        vertex: Point3 = tuple(float(value) for value in raw_vertex)  # type: ignore[assignment]
        if len(vertex) != 3 or any(not math.isfinite(component) for component in vertex):
            raise ValueError("vertices must contain three finite numbers")
        transformed = (
            basis[0][0] * vertex[0]
            + basis[0][1] * vertex[1]
            + basis[0][2] * vertex[2],
            basis[1][0] * vertex[0]
            + basis[1][1] * vertex[1]
            + basis[1][2] * vertex[2],
            basis[2][0] * vertex[0]
            + basis[2][1] * vertex[1]
            + basis[2][2] * vertex[2],
        )
        result.append(_add(canonical_origin, transformed))
    return result


def max_vertex_error(
    expected_vertices: Sequence[Sequence[float]],
    actual_vertices: Sequence[Sequence[float]],
) -> float:
    if len(expected_vertices) != len(actual_vertices):
        raise ValueError("vertex sequences must have equal length")
    maximum = 0.0
    for expected_raw, actual_raw in zip(expected_vertices, actual_vertices):
        expected: Point3 = tuple(float(value) for value in expected_raw)  # type: ignore[assignment]
        actual: Point3 = tuple(float(value) for value in actual_raw)  # type: ignore[assignment]
        maximum = max(maximum, _length(_subtract(expected, actual)))
    return maximum
