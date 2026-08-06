class_name AiFlightIntentSolver
extends RefCounted

const EXPLICIT_INPUT_THRESHOLD := 0.08

static func compute(
    command: FlightCommand,
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    tuning: FlightTuning
) -> FlightAssistCommand:
    var output := FlightAssistCommand.new()
    if (
        command == null
        or tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
    ):
        return output

    var rest_rate := deg_to_rad(
        tuning.ai_angular_rest_threshold_degrees
    )
    var capture_rate := deg_to_rad(
        tuning.ai_angular_capture_rate_degrees
    )
    output.rotation = FlightAuthority.sanitize_rotation(Vector3(
        0.0 if absf(command.rotation.x) > EXPLICIT_INPUT_THRESHOLD else _opposing_axis(local_angular_velocity.x, rest_rate, capture_rate),
        0.0 if absf(command.rotation.y) > EXPLICIT_INPUT_THRESHOLD else _opposing_axis(local_angular_velocity.y, rest_rate, capture_rate),
        0.0 if absf(command.rotation.z) > EXPLICIT_INPUT_THRESHOLD else _opposing_axis(local_angular_velocity.z, rest_rate, capture_rate)
    ))

    var speed := local_linear_velocity.length()
    var reverse_intent := command.translation.z > EXPLICIT_INPUT_THRESHOLD
    if speed < tuning.ai_min_alignment_speed or reverse_intent:
        return output

    var desired_velocity := Vector3.FORWARD * speed
    var velocity_error := desired_velocity - local_linear_velocity
    if absf(command.translation.x) > EXPLICIT_INPUT_THRESHOLD:
        velocity_error.x = 0.0
    if absf(command.translation.y) > EXPLICIT_INPUT_THRESHOLD:
        velocity_error.y = 0.0

    var error_speed := velocity_error.length()
    if error_speed <= tuning.ai_capture_error_speed:
        return output

    var response_range := maxf(
        tuning.ai_full_authority_error_speed
        - tuning.ai_capture_error_speed,
        0.000001
    )
    var weight := clampf(
        (error_speed - tuning.ai_capture_error_speed) / response_range,
        0.0,
        1.0
    )
    output.translation = FlightAuthority.sanitize_translation(
        velocity_error.normalized() * weight
    )
    return output if output.is_finite() else FlightAssistCommand.new()

static func _opposing_axis(
    value: float,
    rest_threshold: float,
    full_authority_threshold: float
) -> float:
    var magnitude := absf(value)
    if not is_finite(magnitude) or magnitude <= rest_threshold:
        return 0.0
    var range_size := maxf(
        full_authority_threshold - rest_threshold,
        0.000001
    )
    return -signf(value) * clampf(
        (magnitude - rest_threshold) / range_size,
        0.0,
        1.0
    )
