extends "res://tests/support/test_case.gd"

func run() -> void:
    var velocity := Vector3(20.0, 0.0, -20.0)
    var force := FlightSteeringMath.assisted_force(
        velocity,
        1.0,
        8500.0,
        1.25,
        8.0,
        18.0
    )
    assert_true(force.x < 0.0, "steering must bend rightward drift toward the nose")
    assert_true(
        absf(force.dot(velocity.normalized())) < 0.01,
        "steering force must remain perpendicular to velocity"
    )
    assert_true(
        force.length() <= 8500.0 * 18.0 + 0.01,
        "steering acceleration must be bounded"
    )
    assert_equal(
        FlightSteeringMath.assisted_force(
            velocity,
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
            1.0,
            8500.0,
            1.25,
            8.0,
            18.0
        ),
        Vector3.ZERO,
        "steering stays inactive below minimum speed"
    )
