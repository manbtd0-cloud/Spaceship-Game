extends "res://tests/support/test_case.gd"

const PLAYER_SCENE := "res://scenes/player/player_interceptor.tscn"

func run() -> void:
    var packed := load(PLAYER_SCENE) as PackedScene
    assert_true(packed != null, "production player scene must load")
    if packed == null:
        return

    var player := packed.instantiate() as RigidBody3D
    assert_true(player != null, "production player root must be RigidBody3D")
    if player == null:
        return

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree == null:
        player.free()
        return
    tree.root.add_child(player)

    var controller := player.get_node_or_null(
        "ShipFlightController"
    ) as ShipFlightController
    assert_true(controller != null, "production flight controller required")
    if controller == null:
        tree.root.remove_child(player)
        player.free()
        return

    assert_true(
        controller.set_flight_mode(FlightMode.Value.AI_ASSISTED),
        "AI mode accepted"
    )
    assert_equal(
        controller.get_flight_mode(),
        FlightMode.Value.AI_ASSISTED,
        "AI mode becomes active"
    )

    player.linear_velocity = Vector3(20.0, -6.0, -80.0)
    player.angular_velocity = Vector3(0.4, -0.5, 0.2)
    Input.action_press(&"yaw_right")
    controller._physics_process(1.0 / 60.0)
    Input.action_release(&"yaw_right")
    assert_true(
        controller.get_last_assist_force_local().length() > 0.0,
        "AI turn adds bounded trajectory force"
    )
    assert_true(
        controller.get_last_assist_torque_local().length() > 0.0,
        "AI turn adds stabilization torque"
    )

    for mode: int in [
        FlightMode.Value.ASSISTED,
        FlightMode.Value.AI_ASSISTED,
        FlightMode.Value.MANUAL,
    ]:
        controller.set_flight_mode(mode)
        var selected := controller.get_flight_mode()
        Input.action_press(&"thrust_forward")
        Input.action_press(&"yaw_right")
        Input.action_press(&"smart_stabilize")
        controller._physics_process(1.0 / 60.0)
        assert_true(
            controller.is_smart_stabilizing(),
            "X activates stabilization in mode %s" % mode
        )
        assert_equal(
            controller.get_flight_mode(),
            selected,
            "stabilization preserves selected mode"
        )
        assert_equal(
            controller.get_last_pilot_force_local(),
            Vector3.ZERO,
            "pilot force suppressed during stabilization"
        )
        assert_equal(
            controller.get_last_pilot_torque_local(),
            Vector3.ZERO,
            "pilot torque suppressed during stabilization"
        )
        assert_equal(
            controller.get_last_command().translation,
            Vector3.ZERO,
            "direct translation telemetry is suppressed while stabilizing"
        )
        assert_equal(
            controller.get_last_command().rotation,
            Vector3.ZERO,
            "direct rotation telemetry is suppressed while stabilizing"
        )
        Input.action_release(&"smart_stabilize")
        Input.action_release(&"thrust_forward")
        Input.action_release(&"yaw_right")
        controller._physics_process(1.0 / 60.0)
        assert_true(
            not controller.is_smart_stabilizing(),
            "release returns ordinary control"
        )
        assert_equal(
            controller.get_flight_mode(),
            selected,
            "release keeps selected mode"
        )

    controller.reset_runtime_state()
    assert_true(
        not controller.is_smart_stabilizing(),
        "reset clears stabilization state"
    )

    Input.action_release(&"yaw_right")
    Input.action_release(&"thrust_forward")
    Input.action_release(&"smart_stabilize")
    tree.root.remove_child(player)
    player.free()
