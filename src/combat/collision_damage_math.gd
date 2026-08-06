class_name CollisionDamageMath
extends RefCounted

static func compute_damage(
    relative_speed: float,
    minimum_speed: float,
    damage_per_excess_mps: float,
    maximum_damage: float
) -> float:
    if (
        not is_finite(relative_speed)
        or not is_finite(minimum_speed)
        or not is_finite(damage_per_excess_mps)
        or not is_finite(maximum_damage)
    ):
        return 0.0

    var excess := maxf(relative_speed - maxf(minimum_speed, 0.0), 0.0)
    return clampf(
        excess * maxf(damage_per_excess_mps, 0.0),
        0.0,
        maxf(maximum_damage, 0.0)
    )
