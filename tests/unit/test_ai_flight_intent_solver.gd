extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := _tuning()
    var command := FlightCommand.new()
    command.mode = FlightMode.Value.AI_ASSISTED
    command.rotation.y = 0.7

    var turn := AiFlightIntentSolver.compute(
        command,
        Vector3(24.0, -8.0, -80.0),
        Vector3(0.3, -0.5, 0.2),
        8500.0,
        tuning
    )
    assert_true(turn.force_local.x < 0.0, "lateral drift bends toward nose")
    assert_true(turn.force_local.y > 0.0, "vertical drift bends toward nose")
    assert_true(turn.torque_local.x < 0.0, "uncommanded pitch rate damped")
    assert_true(
        absf(turn.torque_local.y) < tuning.yaw_torque,
        "yaw input retains authority"
    )
    assert_true(turn.is_finite(), "AI output finite")
    assert_true(
        Vector2(turn.force_local.x, turn.force_local.y).length()
        <= 8500.0 * tuning.ai_max_steering_acceleration + 0.01,
        "steering force bounded"
    )

    var coast := FlightCommand.new()
    coast.mode = FlightMode.Value.AI_ASSISTED
    var coast_output := AiFlightIntentSolver.compute(
        coast,
        Vector3(24.0, -8.0, -80.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_equal(coast_output.force_local, Vector3.ZERO, "coasting preserves drift")

    command.translation.x = 1.0
    var protected := AiFlightIntentSolver.compute(
        command,
        Vector3(24.0, 0.0, -80.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_true(
        protected.force_local.x
        >= -8500.0 * tuning.ai_max_steering_acceleration * 0.11,
        "explicit strafe protected"
    )

    var backward := FlightCommand.new()
    backward.mode = FlightMode.Value.AI_ASSISTED
    backward.translation = Vector3.FORWARD
    var braking := AiFlightIntentSolver.compute(
        backward,
        Vector3(0.0, 0.0, 70.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_true(braking.force_local.z < 0.0, "backward travel with forward intent brakes")
    assert_true(
        absf(braking.force_local.z)
        <= 8500.0 * tuning.ai_max_braking_acceleration + 0.01,
        "braking bounded"
    )

    var malformed := AiFlightIntentSolver.compute(
        command,
        Vector3(NAN, 0.0, 0.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_equal(malformed.force_local, Vector3.ZERO, "bad input gives zero force")
    assert_equal(malformed.torque_local, Vector3.ZERO, "bad input gives zero torque")

func _tuning() -> FlightTuning:
    var tuning := FlightTuning.new()
    tuning.ai_angular_damping = 42000.0
    tuning.ai_rotation_command_protection = 0.90
    tuning.ai_trajectory_alignment_gain = 1.60
    tuning.ai_min_alignment_speed = 6.0
    tuning.ai_max_steering_acceleration = 20.0
    tuning.ai_translation_command_protection = 0.90
    tuning.ai_max_braking_acceleration = 10.0
    tuning.pitch_torque = 52000.0
    tuning.yaw_torque = 48000.0
    tuning.roll_torque = 60000.0
    tuning.normal_speed_limit = 160.0
    tuning.boost_speed_limit = 240.0
    return tuning
