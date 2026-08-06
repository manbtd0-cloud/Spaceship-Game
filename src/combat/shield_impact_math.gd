class_name ShieldImpactMath
extends RefCounted

static func local_direction(
    local_point: Vector3,
    ellipsoid_radii: Vector3
) -> Vector3:
    if not local_point.is_finite() or not ellipsoid_radii.is_finite():
        return Vector3.FORWARD

    var safe := Vector3(
        maxf(absf(ellipsoid_radii.x), 0.001),
        maxf(absf(ellipsoid_radii.y), 0.001),
        maxf(absf(ellipsoid_radii.z), 0.001)
    )
    var value := Vector3(
        local_point.x / safe.x,
        local_point.y / safe.y,
        local_point.z / safe.z
    )
    return (
        value.normalized()
        if not value.is_zero_approx()
        else Vector3.FORWARD
    )

static func hit_energy(
    applied_shield_damage: float,
    maximum_shield: float
) -> float:
    if (
        not is_finite(applied_shield_damage)
        or not is_finite(maximum_shield)
    ):
        return 0.0
    if applied_shield_damage <= 0.0 or maximum_shield <= 0.0:
        return 0.0
    return clampf(
        0.35 + (applied_shield_damage / maximum_shield) * 2.0,
        0.35,
        1.0
    )
