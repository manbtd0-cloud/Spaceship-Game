class_name FlightModel
extends RefCounted

static func compute(
    command: FlightCommand,
    tuning: FlightTuning,
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3
) -> FlightOutput:
    var output := FlightOutput.new()
    var longitudinal_force: float = (
        tuning.forward_force
        if command.translation.z < 0.0
        else tuning.reverse_force
    )

    output.force_local = Vector3(
        command.translation.x * tuning.strafe_force,
        command.translation.y * tuning.strafe_force,
        command.translation.z * longitudinal_force
    )

    var boost_factor := lerpf(
        1.0,
        tuning.boost_multiplier,
        clampf(command.boost, 0.0, 1.0)
    )
    output.force_local.z *= boost_factor
    output.torque_local = command.rotation * tuning.rotation_torque

    if command.mode == FlightMode.ASSISTED:
        output.force_local -= Vector3(
            local_linear_velocity.x,
            local_linear_velocity.y,
            0.0
        ) * tuning.assist_linear_damping
        output.torque_local -= local_angular_velocity * tuning.assist_angular_damping

    return output
