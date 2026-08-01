extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.ASSISTED),
        FlightMode.Value.MANUAL,
        "assisted must toggle to manual"
    )
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.MANUAL),
        FlightMode.Value.ASSISTED,
        "manual must toggle to assisted"
    )
    assert_true(
        is_equal_approx(ShipFlightState.speed_mps(Vector3(3.0, 4.0, 12.0)), 13.0),
        "speed must use vector magnitude"
    )
