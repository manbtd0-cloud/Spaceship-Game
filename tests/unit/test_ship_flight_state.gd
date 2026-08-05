extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(FlightMode.Value.ASSISTED, 0, "Assisted value remains 0")
    assert_equal(FlightMode.Value.MANUAL, 1, "Inertial value remains 1")
    assert_equal(FlightMode.Value.AI_ASSISTED, 2, "AI Assisted appends at 2")
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.ASSISTED),
        FlightMode.Value.AI_ASSISTED,
        "Assisted cycles to AI Assisted"
    )
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.AI_ASSISTED),
        FlightMode.Value.MANUAL,
        "AI Assisted cycles to Inertial"
    )
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.MANUAL),
        FlightMode.Value.ASSISTED,
        "Inertial cycles to Assisted"
    )
    assert_true(
        is_equal_approx(ShipFlightState.speed_mps(Vector3(3.0, 4.0, 12.0)), 13.0),
        "speed must use vector magnitude"
    )
