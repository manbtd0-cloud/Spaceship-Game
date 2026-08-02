class_name ShipVisualMath
extends RefCounted

static func exhaust_strength(
    forward_thrust: float,
    boost_amount: float
) -> float:
    var thrust := clampf(forward_thrust, 0.0, 1.0)
    if thrust <= 0.001:
        return 0.0

    var boost := clampf(boost_amount, 0.0, 1.0)
    return clampf(
        thrust * lerpf(0.45, 1.0, boost),
        0.0,
        1.0
    )

static func exhaust_length_scale(strength: float) -> float:
    return lerpf(0.45, 2.6, clampf(strength, 0.0, 1.0))

static func exhaust_radius_scale(strength: float) -> float:
    return lerpf(0.65, 1.25, clampf(strength, 0.0, 1.0))
