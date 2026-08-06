class_name PracticeDroneSteering
extends RefCounted

static func compute_into(
    result: PracticeDroneIntent,
    relative_position: Vector3,
    relative_velocity: Vector3,
    current_forward: Vector3,
    angular_velocity: Vector3,
    elapsed_seconds: float,
    tuning: PracticeDroneTuning
) -> void:
    if result == null:
        return
    result.clear()

    if (
        tuning == null
        or not relative_position.is_finite()
        or not relative_velocity.is_finite()
        or not current_forward.is_finite()
        or not angular_velocity.is_finite()
        or not is_finite(elapsed_seconds)
    ):
        return

    var distance := relative_position.length()
    if distance <= 0.000001:
        return

    var to_player := relative_position / distance
    var tangent := to_player.cross(Vector3.UP)
    if tangent.length_squared() <= 0.000001:
        tangent = to_player.cross(Vector3.RIGHT)
    tangent = tangent.normalized()

    var orbit_sign := 1.0 if sin(elapsed_seconds * 0.65) >= 0.0 else -1.0
    var desired_velocity := Vector3.ZERO
    var outer_distance := maxf(
        tuning.preferred_distance + tuning.distance_band,
        0.0
    )
    var inner_distance := maxf(
        tuning.preferred_distance - tuning.distance_band,
        0.0
    )

    if distance > outer_distance:
        desired_velocity = (
            to_player * maxf(tuning.radial_speed, 0.0)
            + tangent * maxf(tuning.orbit_speed, 0.0) * 0.25 * orbit_sign
        )
    elif distance < inner_distance:
        desired_velocity = (
            -to_player * maxf(tuning.radial_speed, 0.0)
            + tangent * maxf(tuning.orbit_speed, 0.0) * 0.35 * orbit_sign
        )
    else:
        desired_velocity = (
            tangent * maxf(tuning.orbit_speed, 0.0) * orbit_sign
        )

    desired_velocity += (
        Vector3.UP
        * sin(elapsed_seconds * 0.85)
        * maxf(tuning.vertical_speed, 0.0)
    )
    desired_velocity = desired_velocity.limit_length(
        maxf(tuning.maximum_speed, 0.0)
    )

    result.acceleration_world = (
        (desired_velocity - relative_velocity)
        * maxf(tuning.velocity_response, 0.0)
    ).limit_length(maxf(tuning.maximum_acceleration, 0.0))

    var forward := (
        current_forward.normalized()
        if current_forward.length_squared() > 0.000001
        else Vector3.FORWARD
    )
    var facing_error := forward.cross(to_player)
    result.torque_world = (
        facing_error * maxf(tuning.maximum_turn_torque, 0.0)
        - angular_velocity * maxf(tuning.angular_damping, 0.0)
    ).limit_length(maxf(tuning.maximum_turn_torque, 0.0))
