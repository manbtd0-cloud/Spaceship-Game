class_name AiFlightIntentSolver
extends RefCounted

const INTENT_THRESHOLD := 0.08
const REVERSE_BRAKE_ANGLE_DEGREES := 100.0

static func compute(
    command: FlightCommand,
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    body_mass: float,
    tuning: FlightTuning
) -> FlightAssistOutput:
    var output := FlightAssistOutput.new()
    if (
        command == null
        or tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
        or not is_finite(body_mass)
        or body_mass <= 0.0
    ):
        return output

    var raw_torque := -local_angular_velocity * tuning.ai_angular_damping
    var protection := Vector3(
        1.0 - clampf(
            absf(command.rotation.x) * tuning.ai_rotation_command_protection,
            0.0,
            1.0
        ),
        1.0 - clampf(
            absf(command.rotation.y) * tuning.ai_rotation_command_protection,
            0.0,
            1.0
        ),
        1.0 - clampf(
            absf(command.rotation.z) * tuning.ai_rotation_command_protection,
            0.0,
            1.0
        )
    )
    output.torque_local = Vector3(
        clampf(
            raw_torque.x * protection.x,
            -tuning.pitch_torque,
            tuning.pitch_torque
        ),
        clampf(
            raw_torque.y * protection.y,
            -tuning.yaw_torque,
            tuning.yaw_torque
        ),
        clampf(
            raw_torque.z * protection.z,
            -tuning.roll_torque,
            tuning.roll_torque
        )
    )

    var speed := local_linear_velocity.length()
    var turn_intent := maxf(
        absf(command.rotation.x),
        absf(command.rotation.y)
    )
    var forward_intent := clampf(-command.translation.z, 0.0, 1.0)
    var demand := maxf(turn_intent, forward_intent)
    if speed >= tuning.ai_min_alignment_speed and demand > INTENT_THRESHOLD:
        var acceleration := Vector3(
            -local_linear_velocity.x,
            -local_linear_velocity.y,
            0.0
        ) * tuning.ai_trajectory_alignment_gain * demand
        acceleration = acceleration.limit_length(
            tuning.ai_max_steering_acceleration
        )
        acceleration.x *= 1.0 - clampf(
            absf(command.translation.x) * tuning.ai_translation_command_protection,
            0.0,
            1.0
        )
        acceleration.y *= 1.0 - clampf(
            absf(command.translation.y) * tuning.ai_translation_command_protection,
            0.0,
            1.0
        )
        output.force_local += acceleration * body_mass

    var active_limit := (
        tuning.boost_speed_limit
        if command.boost > 0.0
        else tuning.normal_speed_limit
    )
    var direction := (
        local_linear_velocity.normalized()
        if speed > 0.000001
        else Vector3.ZERO
    )
    var opposite_forward := (
        speed > 0.000001
        and direction.dot(Vector3.FORWARD)
        < cos(deg_to_rad(REVERSE_BRAKE_ANGLE_DEGREES))
    )
    if (
        speed > active_limit
        or (forward_intent > INTENT_THRESHOLD and opposite_forward)
    ):
        output.force_local.z += (
            -signf(local_linear_velocity.z)
            * minf(
                absf(local_linear_velocity.z),
                tuning.ai_max_braking_acceleration
            )
            * body_mass
        )

    return output if output.is_finite() else FlightAssistOutput.new()
