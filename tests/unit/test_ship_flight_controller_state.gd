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
    assert_equal(
        controller.get_last_torque_local(),
        controller.get_last_pilot_torque_local()
        + controller.get_last_assist_torque_local(),
        "initial torque telemetry split must sum to final torque"
    )
    assert_true(
        not controller.is_smart_stabilizing(),
        "Smart Stabilize starts inactive"
    )
    assert_equal(
        controller.get_assistance_source(),
        FlightAssistanceSource.Value.NONE,
        "assistance source starts clear"
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

    var changed_modes: Array[int] = []
    controller.flight_mode_changed.connect(
        func(value: FlightMode.Value) -> void:
            changed_modes.append(value)
    )
    assert_true(
        controller.set_flight_mode(FlightMode.Value.AI_ASSISTED),
        "AI Assisted mode change must be accepted"
    )
    assert_equal(
        controller.get_flight_mode(),
        FlightMode.Value.AI_ASSISTED,
        "AI Assisted becomes active"
    )
    assert_equal(changed_modes.size(), 1, "real mode change emits exactly once")
    assert_equal(
        changed_modes[0],
        FlightMode.Value.AI_ASSISTED,
        "mode signal must carry AI Assisted"
    )
    assert_true(
        not controller.set_flight_mode(FlightMode.Value.AI_ASSISTED),
        "setting the active mode must be a no-op"
    )
    assert_equal(changed_modes.size(), 1, "mode no-op must not emit")

    assert_true(
        controller.set_flight_mode(FlightMode.Value.MANUAL),
        "Inertial mode change must be accepted"
    )
    assert_equal(
        controller.get_flight_mode(),
        FlightMode.Value.MANUAL,
        "manual internal mode must become player-facing Inertial mode"
    )
    assert_equal(changed_modes.size(), 2, "second real mode change emits once")
    assert_equal(
        changed_modes[1],
        FlightMode.Value.MANUAL,
        "second signal must carry Inertial internal value"
    )
    assert_true(
        not controller.set_flight_mode(999),
        "invalid mode must be rejected"
    )
    assert_equal(
        controller.get_flight_mode(),
        FlightMode.Value.MANUAL,
        "invalid mode must preserve current state"
    )
    assert_equal(changed_modes.size(), 2, "invalid mode must not emit")

    assert_equal(
        FlightHud.mode_text_for(FlightMode.Value.ASSISTED),
        "MODE   ASSISTED",
        "assisted HUD copy must remain explicit"
    )
    assert_equal(
        FlightHud.mode_text_for(FlightMode.Value.AI_ASSISTED),
        "MODE   AI ASSISTED",
        "AI Assisted HUD copy must remain explicit"
    )
    assert_equal(
        FlightHud.mode_text_for(FlightMode.Value.MANUAL),
        "MODE   INERTIAL",
        "manual internal mode must be labeled Inertial to the player"
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
        controller.get_last_torque_local(),
        controller.get_last_pilot_torque_local()
        + controller.get_last_assist_torque_local(),
        "reset torque telemetry split must sum to final torque"
    )
    assert_true(
        not controller.is_smart_stabilizing(),
        "reset clears Smart Stabilize state"
    )
    assert_equal(
        controller.get_assistance_source(),
        FlightAssistanceSource.Value.NONE,
        "reset clears assistance source"
    )
    assert_equal(
        controller.get_last_command().translation,
        Vector3.ZERO,
        "command snapshot resets to zero input"
    )
    assert_equal(
        controller.get_flight_mode(),
        FlightMode.Value.MANUAL,
        "runtime reset retains selected flight mode"
    )

    controller.free()
