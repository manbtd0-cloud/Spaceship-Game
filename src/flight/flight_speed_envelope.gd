class_name FlightSpeedEnvelope
extends RefCounted

static func authority(
    speed_mps: float,
    soft_start_mps: float,
    soft_limit_mps: float
) -> float:
    var start := maxf(soft_start_mps, 0.0)
    var limit := maxf(soft_limit_mps, start + 0.001)
    var t := clampf(
        (maxf(speed_mps, 0.0) - start) / (limit - start),
        0.0,
        1.0
    )
    var smooth_t := t * t * (3.0 - 2.0 * t)
    return 1.0 - smooth_t

static func apply_to_force(
    force_local: Vector3,
    velocity_local: Vector3,
    soft_start_mps: float,
    soft_limit_mps: float
) -> Vector3:
    var speed := velocity_local.length()
    if speed < 0.001 or force_local.length_squared() < 0.000001:
        return force_local

    var velocity_direction := velocity_local / speed
    var increasing_magnitude := maxf(
        force_local.dot(velocity_direction),
        0.0
    )
    var increasing_force := velocity_direction * increasing_magnitude
    var redirecting_or_braking_force := force_local - increasing_force
    return (
        redirecting_or_braking_force
        + increasing_force * authority(
            speed,
            soft_start_mps,
            soft_limit_mps
        )
    )
