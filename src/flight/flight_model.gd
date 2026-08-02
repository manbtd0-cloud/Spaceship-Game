class_name FlightModel
extends RefCounted

static func compute(
    command: FlightCommand,
    tuning: FlightTuning,
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    body_mass: float = 1.0
) -> FlightOutput:
    var output := FlightOutput.new()
    var longitudinal_force: float = (
        tuning.forward_force
        if command.translation.z < 0.0
        else tuning.reverse_force
    )

    var force_local := Vector3(
        command.translation.x * tuning.strafe_force,
        command.translation.y * tuning.strafe_force,
        command.translation.z * longitudinal_force
    )
    var boost_factor := lerpf(
        1.0,
        tuning.boost_multiplier,
        clampf(command.boost, 0.0, 1.0)
    )
    force_local *= boost_factor

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
    output.force_local = FlightSpeedEnvelope.apply_to_force(
        force_local,
        local_linear_velocity,
        soft_start,
        soft_limit
    )

    output.torque_local = Vector3(
        command.rotation.x * tuning.pitch_torque,
        command.rotation.y * tuning.yaw_torque,
        command.rotation.z * tuning.roll_torque
    )

    if command.mode == FlightMode.Value.ASSISTED:
        output.force_local.x -= (
            local_linear_velocity.x * tuning.assist_lateral_damping
        )
        output.force_local.y -= (
            local_linear_velocity.y * tuning.assist_vertical_damping
        )
        output.torque_local -= (
            local_angular_velocity * tuning.assist_angular_damping
        )

    return output
