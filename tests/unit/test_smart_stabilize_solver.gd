extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.stabilize_linear_capture_speed = 4.0
    tuning.stabilize_angular_capture_rate_degrees = 8.0
    tuning.stabilize_linear_rest_threshold = 0.10
    tuning.stabilize_angular_rest_threshold_degrees = 0.25

    var combined := SmartStabilizeSolver.compute(
        Vector3(30.0, -20.0, -80.0),
        Vector3(
            deg_to_rad(20.0),
            deg_to_rad(-20.0),
            deg_to_rad(20.0)
        ),
        tuning
    )
    assert_true(
        combined.is_finite(),
        "combined stabilization command must be finite"
    )
    assert_true(
        combined.translation.x < 0.0,
        "rightward drift must command left thrust"
    )
    assert_true(
        combined.translation.y > 0.0,
        "downward drift must command upward thrust"
    )
    assert_true(
        combined.translation.z > 0.0,
        "forward drift must command reverse thrust"
    )
    assert_true(
        is_equal_approx(combined.translation.length(), 1.0),
        "combined translation must use one normalized player envelope"
    )
    assert_equal(
        combined.rotation,
        Vector3(-1.0, 1.0, -1.0),
        "all three angular axes must receive full legal counter-command"
    )

    var backward := SmartStabilizeSolver.compute(
        Vector3(0.0, 0.0, 20.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(
        backward.translation,
        Vector3.FORWARD,
        "backward drift must use full forward command"
    )

    var taper := SmartStabilizeSolver.compute(
        Vector3(2.0, 0.0, 0.0),
        Vector3(0.0, deg_to_rad(4.0), 0.0),
        tuning
    )
    assert_true(
        taper.translation.x < 0.0 and absf(taper.translation.x) < 1.0,
        "translation must taper inside the capture band"
    )
    assert_true(
        taper.rotation.y < 0.0 and absf(taper.rotation.y) < 1.0,
        "rotation must taper inside the capture band"
    )

    var rest := SmartStabilizeSolver.compute(
        Vector3(0.05, 0.0, 0.0),
        Vector3(0.0, deg_to_rad(0.1), 0.0),
        tuning
    )
    assert_equal(
        rest.translation,
        Vector3.ZERO,
        "linear rest threshold must stop thrust"
    )
    assert_equal(
        rest.rotation,
        Vector3.ZERO,
        "angular rest threshold must stop torque"
    )

    var simultaneous := SmartStabilizeSolver.compute(
        Vector3(50.0, 0.0, 0.0),
        Vector3(0.0, deg_to_rad(40.0), 0.0),
        tuning
    )
    assert_true(
        simultaneous.translation.length() > 0.99,
        "strong rotation must not delay full linear braking"
    )
    assert_true(
        absf(simultaneous.rotation.y) > 0.99,
        "linear braking must not delay full angular counter-command"
    )

    var malformed := SmartStabilizeSolver.compute(
        Vector3(INF, 0.0, 0.0),
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
