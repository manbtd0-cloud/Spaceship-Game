class_name HullImpactMath
extends RefCounted

static func energy(amount: float, maximum_hull: float) -> float:
    if (
        not is_finite(amount)
        or not is_finite(maximum_hull)
        or amount <= 0.0
        or maximum_hull <= 0.0
    ):
        return 0.0
    var ratio := clampf(amount / maximum_hull, 0.0, 1.0)
    return clampf(0.45 + ratio * 0.60, 0.0, 1.0)

static func local_direction(value: Vector3) -> Vector3:
    if not value.is_finite() or value.length_squared() <= 0.000001:
        return Vector3.UP
    return value.normalized()
