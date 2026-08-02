extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_equal_approx(FlightSpeedEnvelope.authority(100.0, 120.0, 160.0), 1.0),
        "authority below onset"
    )
    var middle := FlightSpeedEnvelope.authority(140.0, 120.0, 160.0)
    assert_true(middle > 0.0 and middle < 1.0, "authority inside envelope")
    assert_true(
        is_equal_approx(FlightSpeedEnvelope.authority(160.0, 120.0, 160.0), 0.0),
        "authority at limit"
    )

    var velocity := Vector3(0.0, 0.0, -160.0)
    assert_equal(
        FlightSpeedEnvelope.apply_to_force(
            Vector3(0.0, 0.0, -100.0), velocity, 120.0, 160.0
        ),
        Vector3.ZERO,
        "speed-increasing force must stop at limit"
    )
    assert_equal(
        FlightSpeedEnvelope.apply_to_force(
            Vector3(0.0, 0.0, 100.0), velocity, 120.0, 160.0
        ),
        Vector3(0.0, 0.0, 100.0),
        "braking force must remain available"
    )
    assert_equal(
        FlightSpeedEnvelope.apply_to_force(
            Vector3(100.0, 0.0, 0.0), velocity, 120.0, 160.0
        ),
        Vector3(100.0, 0.0, 0.0),
        "perpendicular redirecting force must remain available"
    )
