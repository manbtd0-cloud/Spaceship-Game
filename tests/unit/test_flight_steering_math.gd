extends "res://tests/support/test_case.gd"

func run() -> void:
    var velocity := Vector3(20.0, 0.0, -20.0)
    var force := FlightSteeringMath.assisted_force(
        velocity,
        Vector3.FORWARD,
        1.0,
        8500.0,
        1.25,
        8.0,
        18.0
    )
    assert_true(force.x < 0.0, "steering must bend rightward drift toward the nose")
    assert_true(
        absf(force.dot(velocity.normalized())) <= 0.001,
        "steering force must remain perpendicular to velocity"
    )
    assert_true(
        force.length() <= 8500.0 * 18.0 + 0.01,
        "steering acceleration must be bounded"
    )
    assert_equal(
        FlightSteeringMath.assisted_force(
            velocity,
            Vector3.FORWARD,
            0.0,
            8500.0,
            1.25,
            8.0,
            18.0
        ),
        Vector3.ZERO,
        "no forward thrust means no nose steering"
    )
    assert_equal(
        FlightSteeringMath.assisted_force(
            Vector3(1.0, 0.0, 0.0),
            Vector3.FORWARD,
            1.0,
            8500.0,
            1.25,
            8.0,
            18.0
        ),
        Vector3.ZERO,
        "steering stays inactive below minimum speed"
    )
    assert_equal(
        FlightSteeringMath.assisted_force(
            velocity,
            Vector3.ZERO,
            1.0,
            8500.0,
            1.25,
            8.0,
            18.0
        ),
        Vector3.ZERO,
        "invalid desired direction must not create force"
    )

    var tuning := FlightTuning.new()
    var coasting := FlightCommand.new()
    coasting.mode = FlightMode.Value.ASSISTED
    coasting.translation = Vector3.ZERO
    var coasting_output := FlightModel.compute(
        coasting,
        tuning,
        Vector3(35.0, -12.0, -90.0),
        Vector3.ZERO,
        8500.0
    )
    assert_equal(
        coasting_output.assist_force_local,
        Vector3.ZERO,
        "assisted coasting must not bleed speed through local-axis damping"
    )
