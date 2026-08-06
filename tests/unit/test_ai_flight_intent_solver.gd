extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.ai_full_authority_error_speed = 12.0
    tuning.ai_capture_error_speed = 0.75
    tuning.ai_min_alignment_speed = 2.0
    tuning.ai_angular_capture_rate_degrees = 8.0
    tuning.ai_angular_rest_threshold_degrees = 0.25

    var coast := FlightCommand.new()
    coast.mode = FlightMode.Value.AI_ASSISTED
    var alignment := AiFlightIntentSolver.compute(
        coast,
        Vector3(30.0, -20.0, -80.0),
        Vector3(0.4, -0.5, 0.3),
        tuning
    )
    assert_true(alignment.is_finite(), "AI command must remain finite")
    assert_true(
        alignment.translation.x < 0.0,
        "AI must cancel rightward trajectory error"
    )
    assert_true(
        alignment.translation.y > 0.0,
        "AI must cancel downward trajectory error"
    )
    assert_true(
        alignment.translation.z < 0.0,
        "AI must add forward authority while centering"
    )
    assert_true(
        is_equal_approx(alignment.translation.length(), 1.0),
        "large marker displacement must request full legal authority"
    )
    assert_equal(
        alignment.rotation,
        Vector3(-1.0, 1.0, -1.0),
        "uncommanded angular axes must receive full counter-command"
    )

    var aligned := AiFlightIntentSolver.compute(
        coast,
        Vector3(0.0, 0.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(
        aligned.translation,
        Vector3.ZERO,
        "centered velocity marker must not receive translation correction"
    )

    var small_error := AiFlightIntentSolver.compute(
        coast,
        Vector3(1.0, 0.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_true(
        small_error.translation.length() > 0.0
        and small_error.translation.length() < 1.0,
        "small displacement must taper instead of hunting"
    )

    var explicit_axes := FlightCommand.new()
    explicit_axes.mode = FlightMode.Value.AI_ASSISTED
    explicit_axes.translation = Vector3(1.0, 1.0, 0.0).normalized()
    var protected := AiFlightIntentSolver.compute(
        explicit_axes,
        Vector3(30.0, -20.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_true(
        is_zero_approx(protected.translation.x),
        "AI must not oppose explicit lateral intent"
    )
    assert_true(
        is_zero_approx(protected.translation.y),
        "AI must not oppose explicit vertical intent"
    )

    var reverse := FlightCommand.new()
    reverse.mode = FlightMode.Value.AI_ASSISTED
    reverse.translation = Vector3.BACK
    var reverse_output := AiFlightIntentSolver.compute(
        reverse,
        Vector3(30.0, 0.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(
        reverse_output.translation,
        Vector3.ZERO,
        "explicit reverse intent must suspend forward trajectory alignment"
    )

    var commanded_rotation := FlightCommand.new()
    commanded_rotation.mode = FlightMode.Value.AI_ASSISTED
    commanded_rotation.rotation.y = 1.0
    var protected_rotation := AiFlightIntentSolver.compute(
        commanded_rotation,
        Vector3.ZERO,
        Vector3(0.5, -0.5, 0.5),
        tuning
    )
    assert_true(
        is_zero_approx(protected_rotation.rotation.y),
        "AI must not counter-command the explicitly commanded yaw axis"
    )
    assert_true(
        protected_rotation.rotation.x < 0.0
        and protected_rotation.rotation.z < 0.0,
        "uncommanded rotational axes must remain stabilized"
    )

    var malformed := AiFlightIntentSolver.compute(
        coast,
        Vector3(NAN, 0.0, 0.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(
        malformed.translation,
        Vector3.ZERO,
        "bad input gives zero translation command"
    )
    assert_equal(
        malformed.rotation,
        Vector3.ZERO,
        "bad input gives zero rotation command"
    )
