class_name FlightModel
extends RefCounted

static func compute(
    command: FlightCommand,
    tuning: FlightTuning,
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    body_mass: float = 1.0,
    assist_rotation_command: Vector3 = Vector3.ZERO
) -> FlightOutput:
    var output := FlightOutput.new()
    var pilot_force := FlightAuthority.translation_force(
        command.translation,
        command.boost,
        tuning
    )

    var soft_start := (
        tuning.boost_speed_soft_start
        if command.boost > 0.0
        else tuning.normal_speed_soft_start
    )
    var soft_limit := (
        tuning.boost_speed_limit
        if command.boost > 0.0
        else tuning.normal_speed_limit
    )
    output.pilot_force_local = FlightSpeedEnvelope.apply_to_force(
        pilot_force,
        local_linear_velocity,
        soft_start,
        soft_limit
    )

    output.pilot_torque_local = FlightAuthority.rotation_torque(
        command.rotation,
        tuning
    )

    if command.mode == FlightMode.Value.ASSISTED:
        output.assist_force_local += FlightSteeringMath.assisted_force(
            local_linear_velocity,
            Vector3.FORWARD,
            clampf(-command.translation.z, 0.0, 1.0),
            body_mass,
            tuning.assist_steering_strength,
            tuning.assist_min_steering_speed,
            tuning.assist_max_steering_acceleration
        )
        output.assist_torque_local += Vector3(
            assist_rotation_command.x * tuning.pitch_torque,
            assist_rotation_command.y * tuning.yaw_torque,
            assist_rotation_command.z * tuning.roll_torque
        )
        output.assist_torque_local -= (
            local_angular_velocity * tuning.assist_angular_damping
        )

    output.finalize_totals()
    return output
