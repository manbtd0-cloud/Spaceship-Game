class_name FlightAuthority
extends RefCounted

static func sanitize_translation(value: Vector3) -> Vector3:
    return value.limit_length(1.0) if value.is_finite() else Vector3.ZERO

static func sanitize_rotation(value: Vector3) -> Vector3:
    if not value.is_finite():
        return Vector3.ZERO
    return Vector3(
        clampf(value.x, -1.0, 1.0),
        clampf(value.y, -1.0, 1.0),
        clampf(value.z, -1.0, 1.0)
    )

static func combine_translation(
    pilot: Vector3,
    automatic: Vector3
) -> Vector3:
    return sanitize_translation(
        sanitize_translation(pilot) + sanitize_translation(automatic)
    )

static func combine_rotation(
    pilot: Vector3,
    automatic: Vector3
) -> Vector3:
    return sanitize_rotation(
        sanitize_rotation(pilot) + sanitize_rotation(automatic)
    )

static func translation_force(
    command: Vector3,
    effective_boost: float,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null:
        return Vector3.ZERO
    var legal := sanitize_translation(command)
    var z_authority := (
        tuning.forward_force if legal.z < 0.0 else tuning.reverse_force
    )
    var boost_scale := lerpf(
        1.0,
        tuning.boost_multiplier,
        clampf(effective_boost, 0.0, 1.0)
    )
    return Vector3(
        legal.x * tuning.strafe_force,
        legal.y * tuning.strafe_force,
        legal.z * z_authority
    ) * boost_scale

static func rotation_torque(
    command: Vector3,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null:
        return Vector3.ZERO
    var legal := sanitize_rotation(command)
    return Vector3(
        legal.x * tuning.pitch_torque,
        legal.y * tuning.yaw_torque,
        legal.z * tuning.roll_torque
    )

static func translation_command_for_force(
    force: Vector3,
    effective_boost: float,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null or not force.is_finite():
        return Vector3.ZERO
    var boost_scale := lerpf(
        1.0,
        tuning.boost_multiplier,
        clampf(effective_boost, 0.0, 1.0)
    )
    var x_reference := maxf(
        tuning.strafe_force * boost_scale,
        0.000001
    )
    var z_reference := maxf(
        (
            tuning.forward_force
            if force.z < 0.0
            else tuning.reverse_force
        ) * boost_scale,
        0.000001
    )
    return sanitize_translation(Vector3(
        force.x / x_reference,
        force.y / x_reference,
        force.z / z_reference
    ))

static func rotation_command_for_torque(
    torque: Vector3,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null or not torque.is_finite():
        return Vector3.ZERO
    return sanitize_rotation(Vector3(
        torque.x / maxf(tuning.pitch_torque, 0.000001),
        torque.y / maxf(tuning.yaw_torque, 0.000001),
        torque.z / maxf(tuning.roll_torque, 0.000001)
    ))
