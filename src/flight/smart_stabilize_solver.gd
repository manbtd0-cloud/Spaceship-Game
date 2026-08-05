class_name SmartStabilizeSolver
extends RefCounted

static func compute(
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    body_mass: float,
    tuning: FlightTuning
) -> FlightAssistOutput:
    var output := FlightAssistOutput.new()
    if (
        tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
        or not is_finite(body_mass)
        or body_mass <= 0.0
    ):
        return output

    var angular_speed_degrees := rad_to_deg(local_angular_velocity.length())
    if (
        angular_speed_degrees
        > tuning.stabilize_angular_rest_threshold_degrees
    ):
        var raw_torque := (
            -local_angular_velocity * tuning.stabilize_angular_damping
        )
        output.torque_local = Vector3(
            clampf(raw_torque.x, -tuning.pitch_torque, tuning.pitch_torque),
            clampf(raw_torque.y, -tuning.yaw_torque, tuning.yaw_torque),
            clampf(raw_torque.z, -tuning.roll_torque, tuning.roll_torque)
        )

    var braking_weight := clampf(
        inverse_lerp(
            tuning.stabilize_no_braking_above_degrees,
            tuning.stabilize_full_braking_below_degrees,
            angular_speed_degrees
        ),
        0.0,
        1.0
    )
    var linear_speed := local_linear_velocity.length()
    if (
        linear_speed > tuning.stabilize_linear_rest_threshold
        and braking_weight > 0.0
    ):
        var deceleration := minf(
            linear_speed,
            tuning.stabilize_max_linear_deceleration
        )
        output.force_local = (
            -local_linear_velocity.normalized()
            * deceleration
            * braking_weight
            * body_mass
        )

    return output if output.is_finite() else FlightAssistOutput.new()
