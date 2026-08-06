class_name FlightAngularEnvelope
extends RefCounted

const EPSILON := 0.000001

static func apply_to_torque(
    torque_local: Vector3,
    angular_velocity_local: Vector3,
    soft_start_degrees: Vector3,
    limit_degrees: Vector3
) -> Vector3:
    if (
        not torque_local.is_finite()
        or not angular_velocity_local.is_finite()
        or not soft_start_degrees.is_finite()
        or not limit_degrees.is_finite()
    ):
        return Vector3.ZERO

    return Vector3(
        _apply_axis(
            torque_local.x,
            angular_velocity_local.x,
            soft_start_degrees.x,
            limit_degrees.x
        ),
        _apply_axis(
            torque_local.y,
            angular_velocity_local.y,
            soft_start_degrees.y,
            limit_degrees.y
        ),
        _apply_axis(
            torque_local.z,
            angular_velocity_local.z,
            soft_start_degrees.z,
            limit_degrees.z
        )
    )

static func _apply_axis(
    requested_torque: float,
    angular_rate_radians: float,
    soft_start_degrees: float,
    limit_degrees: float
) -> float:
    if absf(requested_torque) <= EPSILON:
        return 0.0
    if (
        absf(angular_rate_radians) <= EPSILON
        or requested_torque * angular_rate_radians <= 0.0
    ):
        return requested_torque

    var start := maxf(soft_start_degrees, 0.0)
    var limit := maxf(limit_degrees, start + 0.001)
    var rate_degrees := rad_to_deg(absf(angular_rate_radians))
    if rate_degrees <= start:
        return requested_torque
    if rate_degrees >= limit:
        return 0.0

    var t := clampf(
        (rate_degrees - start) / (limit - start),
        0.0,
        1.0
    )
    var smooth_t := t * t * (3.0 - 2.0 * t)
    return requested_torque * (1.0 - smooth_t)
