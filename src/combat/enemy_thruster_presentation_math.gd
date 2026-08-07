class_name EnemyThrusterPresentationMath
extends RefCounted

static func command_for_local_wrench(
    local_force: Vector3,
    local_torque: Vector3,
    tuning: EnemyFighterTuning
) -> FlightCommand:
    var command := FlightCommand.new()
    if (
        tuning == null
        or not local_force.is_finite()
        or not local_torque.is_finite()
    ):
        return command

    command.translation.x = _safe_ratio(local_force.x, tuning.strafe_force)
    command.translation.y = _safe_ratio(local_force.y, tuning.vertical_force)
    command.translation.z = (
        _safe_ratio(local_force.z, tuning.reverse_force)
        if local_force.z >= 0.0
        else _safe_ratio(local_force.z, tuning.forward_force)
    )
    command.rotation = Vector3(
        _safe_ratio(local_torque.x, tuning.pitch_torque),
        _safe_ratio(local_torque.y, tuning.yaw_torque),
        _safe_ratio(local_torque.z, tuning.roll_torque)
    )
    return command

static func _safe_ratio(value: float, authority: float) -> float:
    if not is_finite(value) or not is_finite(authority) or authority <= 0.0:
        return 0.0
    return clampf(value / authority, -1.0, 1.0)
