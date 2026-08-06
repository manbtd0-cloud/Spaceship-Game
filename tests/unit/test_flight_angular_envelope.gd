extends "res://tests/support/test_case.gd"

func run() -> void:
    var soft_start := Vector3(75.0, 75.0, 112.5)
    var limits := Vector3(100.0, 100.0, 150.0)
    var requested := Vector3(10.0, 20.0, 30.0)

    var below_start := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(50.0),
            deg_to_rad(60.0),
            deg_to_rad(90.0)
        ),
        soft_start,
        limits
    )
    assert_equal(
        below_start,
        requested,
        "same-direction torque must remain full below every soft start"
    )

    var midpoint := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(87.5),
            deg_to_rad(87.5),
            deg_to_rad(131.25)
        ),
        soft_start,
        limits
    )
    assert_true(
        midpoint.is_equal_approx(requested * 0.5),
        "midpoint of each envelope must retain half torque"
    )

    var at_limit := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(100.0),
            deg_to_rad(110.0),
            deg_to_rad(150.0)
        ),
        soft_start,
        limits
    )
    assert_equal(
        at_limit,
        Vector3.ZERO,
        "same-direction torque must stop at or above each limit"
    )

    var opposing := FlightAngularEnvelope.apply_to_torque(
        -requested,
        Vector3(
            deg_to_rad(140.0),
            deg_to_rad(140.0),
            deg_to_rad(190.0)
        ),
        soft_start,
        limits
    )
    assert_equal(
        opposing,
        -requested,
        "opposing torque must remain full above every limit"
    )

    var independent := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(100.0),
            deg_to_rad(50.0),
            deg_to_rad(131.25)
        ),
        soft_start,
        limits
    )
    assert_true(
        is_zero_approx(independent.x),
        "pitch must stop independently at its limit"
    )
    assert_true(
        is_equal_approx(independent.y, requested.y),
        "yaw below soft start must remain independent and full"
    )
    assert_true(
        is_equal_approx(independent.z, requested.z * 0.5),
        "roll must use its independent higher envelope"
    )

    var zero_rate := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3.ZERO,
        soft_start,
        limits
    )
    assert_equal(
        zero_rate,
        requested,
        "zero angular rate must not create artificial damping"
    )

    assert_equal(
        FlightAngularEnvelope.apply_to_torque(
            Vector3(NAN, 0.0, 0.0),
            Vector3.ZERO,
            soft_start,
            limits
        ),
        Vector3.ZERO,
        "non-finite torque must fail closed"
    )
    assert_equal(
        FlightAngularEnvelope.apply_to_torque(
            requested,
            Vector3(0.0, INF, 0.0),
            soft_start,
            limits
        ),
        Vector3.ZERO,
        "non-finite angular velocity must fail closed"
    )
    assert_equal(
        FlightAngularEnvelope.apply_to_torque(
            requested,
            Vector3.ZERO,
            Vector3(NAN, 75.0, 112.5),
            limits
        ),
        Vector3.ZERO,
        "non-finite envelope tuning must fail closed"
    )
