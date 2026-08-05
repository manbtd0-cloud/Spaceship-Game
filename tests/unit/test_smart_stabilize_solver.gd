extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.pitch_torque = 52000.0
    tuning.yaw_torque = 48000.0
    tuning.roll_torque = 60000.0
    tuning.stabilize_angular_damping = 70000.0
    tuning.stabilize_max_linear_deceleration = 22.0
    tuning.stabilize_linear_rest_threshold = 0.25
    tuning.stabilize_full_braking_below_degrees = 5.0
    tuning.stabilize_no_braking_above_degrees = 15.0
    tuning.stabilize_angular_rest_threshold_degrees = 0.5

    var fast_spin := SmartStabilizeSolver.compute(
        Vector3(30.0, 0.0, -80.0),
        Vector3(0.0, deg_to_rad(20.0), 0.0),
        8500.0,
        tuning
    )
    assert_true(fast_spin.torque_local.y < 0.0, "counter-torque begins immediately")
    assert_equal(fast_spin.force_local, Vector3.ZERO, "strong spin delays braking")

    var settled := SmartStabilizeSolver.compute(
        Vector3(30.0, 0.0, -80.0),
        Vector3(0.0, deg_to_rad(3.0), 0.0),
        8500.0,
        tuning
    )
    assert_true(settled.force_local.length() > 0.0, "settled attitude enables braking")
    assert_true(
        settled.force_local.dot(Vector3(30.0, 0.0, -80.0)) < 0.0,
        "braking opposes velocity"
    )
    assert_true(
        settled.force_local.length()
        <= 8500.0 * tuning.stabilize_max_linear_deceleration + 0.01,
        "linear force bounded"
    )
    assert_true(absf(settled.torque_local.x) <= tuning.pitch_torque + 0.01)
    assert_true(absf(settled.torque_local.y) <= tuning.yaw_torque + 0.01)
    assert_true(absf(settled.torque_local.z) <= tuning.roll_torque + 0.01)

    var rest := SmartStabilizeSolver.compute(
        Vector3(0.1, 0.0, 0.0),
        Vector3(0.0, deg_to_rad(0.2), 0.0),
        8500.0,
        tuning
    )
    assert_equal(rest.force_local, Vector3.ZERO, "linear rest threshold stops braking")
    assert_equal(rest.torque_local, Vector3.ZERO, "angular rest threshold stops torque")

    var malformed := SmartStabilizeSolver.compute(
        Vector3(INF, 0.0, 0.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_equal(malformed.force_local, Vector3.ZERO, "bad input gives zero force")
    assert_equal(malformed.torque_local, Vector3.ZERO, "bad input gives zero torque")
