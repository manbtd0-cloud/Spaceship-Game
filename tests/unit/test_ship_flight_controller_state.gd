extends "res://tests/support/test_case.gd"

func run() -> void:
    var controller := ShipFlightController.new()

    assert_true(
        controller.get_last_force_local().is_equal_approx(Vector3.ZERO),
        "flight controller final local force starts at zero"
    )
    assert_true(
        controller.get_last_torque_local().is_equal_approx(Vector3.ZERO),
        "flight controller final local torque starts at zero"
    )

    controller.reset_runtime_state()

    assert_true(
        controller.get_last_force_local().is_equal_approx(Vector3.ZERO),
        "flight controller final local force resets to zero"
    )
    assert_true(
        controller.get_last_torque_local().is_equal_approx(Vector3.ZERO),
        "flight controller final local torque resets to zero"
    )

    controller.free()
