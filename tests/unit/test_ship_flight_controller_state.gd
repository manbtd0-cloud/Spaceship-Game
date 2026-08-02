extends "res://tests/support/test_case.gd"

func run() -> void:
    var controller := ShipFlightController.new()

    assert_vector3_close(
        controller.get_last_force_local(),
        Vector3.ZERO,
        0.000001,
        "flight controller final local force starts at zero"
    )
    assert_vector3_close(
        controller.get_last_torque_local(),
        Vector3.ZERO,
        0.000001,
        "flight controller final local torque starts at zero"
    )

    controller.reset_runtime_state()

    assert_vector3_close(
        controller.get_last_force_local(),
        Vector3.ZERO,
        0.000001,
        "flight controller final local force resets to zero"
    )
    assert_vector3_close(
        controller.get_last_torque_local(),
        Vector3.ZERO,
        0.000001,
        "flight controller final local torque resets to zero"
    )

    controller.free()
