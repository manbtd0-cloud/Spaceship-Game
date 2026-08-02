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
    assert_true(
        controller.get_last_pilot_force_local().is_equal_approx(Vector3.ZERO),
        "pilot force starts at zero"
    )
    assert_true(
        controller.get_last_pilot_torque_local().is_equal_approx(Vector3.ZERO),
        "pilot torque starts at zero"
    )
    assert_true(
        controller.get_last_assist_force_local().is_equal_approx(Vector3.ZERO),
        "assist force starts at zero"
    )
    assert_true(
        controller.get_last_assist_torque_local().is_equal_approx(Vector3.ZERO),
        "assist torque starts at zero"
    )

    var first_snapshot := controller.get_last_command()
    assert_true(first_snapshot != null, "controller must expose a command snapshot")
    first_snapshot.translation = Vector3.ONE
    var second_snapshot := controller.get_last_command()
    assert_equal(
        second_snapshot.translation,
        Vector3.ZERO,
        "returned command snapshots must not mutate controller state"
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
    assert_true(
        controller.get_last_pilot_force_local().is_equal_approx(Vector3.ZERO),
        "pilot force resets to zero"
    )
    assert_true(
        controller.get_last_pilot_torque_local().is_equal_approx(Vector3.ZERO),
        "pilot torque resets to zero"
    )
    assert_true(
        controller.get_last_assist_force_local().is_equal_approx(Vector3.ZERO),
        "assist force resets to zero"
    )
    assert_true(
        controller.get_last_assist_torque_local().is_equal_approx(Vector3.ZERO),
        "assist torque resets to zero"
    )
    assert_equal(
        controller.get_last_command().translation,
        Vector3.ZERO,
        "command snapshot resets to zero input"
    )

    controller.free()
