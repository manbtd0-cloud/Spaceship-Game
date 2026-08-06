class_name SmartStabilizeSolver
extends RefCounted

static func compute(
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    tuning: FlightTuning
) -> FlightAssistCommand:
    var output := FlightAssistCommand.new()
    if (
        tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
    ):
        return output

    output.translation = FlightAuthority.sanitize_translation(Vector3(
        _opposing_axis(
            local_linear_velocity.x,
            tuning.stabilize_linear_rest_threshold,
            tuning.stabilize_linear_capture_speed
        ),
        _opposing_axis(
            local_linear_velocity.y,
            tuning.stabilize_linear_rest_threshold,
            tuning.stabilize_linear_capture_speed
        ),
        _opposing_axis(
            local_linear_velocity.z,
            tuning.stabilize_linear_rest_threshold,
            tuning.stabilize_linear_capture_speed
        )
    ))

    var rest_rate := deg_to_rad(
        tuning.stabilize_angular_rest_threshold_degrees
    )
    var capture_rate := deg_to_rad(
        tuning.stabilize_angular_capture_rate_degrees
    )
    output.rotation = FlightAuthority.sanitize_rotation(Vector3(
        _opposing_axis(local_angular_velocity.x, rest_rate, capture_rate),
        _opposing_axis(local_angular_velocity.y, rest_rate, capture_rate),
        _opposing_axis(local_angular_velocity.z, rest_rate, capture_rate)
    ))
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
    var weight := clampf(
        (magnitude - rest_threshold) / range_size,
        0.0,
        1.0
    )
    return -signf(value) * weight
