class_name HeroShipAlignment
extends RefCounted

const AXIS_EPSILON := 0.000001

static func alignment_basis(
    source_forward: Vector3,
    source_up: Vector3
) -> Basis:
    if (
        source_forward.length_squared() <= AXIS_EPSILON
        or source_up.length_squared() <= AXIS_EPSILON
    ):
        return Basis.IDENTITY

    var forward := source_forward.normalized()
    var up := source_up.normalized()
    up = up - forward * up.dot(forward)
    if up.length_squared() <= AXIS_EPSILON:
        return Basis.IDENTITY
    up = up.normalized()

    var right := forward.cross(up)
    if right.length_squared() <= AXIS_EPSILON:
        return Basis.IDENTITY
    right = right.normalized()

    var source_basis := Basis(
        right,
        up,
        -forward
    ).orthonormalized()
    return source_basis.inverse().orthonormalized()

static func uniform_fit_scale(
    source_dimensions: Vector3,
    target_dimensions: Vector3
) -> float:
    if (
        source_dimensions.x <= AXIS_EPSILON
        or source_dimensions.y <= AXIS_EPSILON
        or source_dimensions.z <= AXIS_EPSILON
        or target_dimensions.x <= AXIS_EPSILON
        or target_dimensions.y <= AXIS_EPSILON
        or target_dimensions.z <= AXIS_EPSILON
    ):
        return 1.0

    return minf(
        target_dimensions.x / source_dimensions.x,
        minf(
            target_dimensions.y / source_dimensions.y,
            target_dimensions.z / source_dimensions.z
        )
    )
