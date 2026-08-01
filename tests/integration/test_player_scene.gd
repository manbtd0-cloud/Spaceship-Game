extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/player/player_interceptor.tscn") as PackedScene
    assert_true(packed != null, "player scene must load")
    if packed == null:
        return

    var player := packed.instantiate() as RigidBody3D
    assert_true(player != null, "player root must be RigidBody3D")
    if player == null:
        return

    assert_true(is_equal_approx(player.mass, 8500.0), "mass must be 8500 kg")
    assert_true(is_equal_approx(player.gravity_scale, 0.0), "gravity must be disabled")
    assert_true(is_equal_approx(player.linear_damp, 0.0), "linear damping must be zero")
    assert_true(is_equal_approx(player.angular_damp, 0.0), "angular damping must be zero")
    assert_true(player.continuous_cd, "continuous collision detection must be enabled")
    assert_true(player.get_node_or_null("CollisionShape3D") is CollisionShape3D, "collision required")
    assert_true(player.get_node_or_null("PlayerInputSource") is PlayerInputSource, "input source required")
    assert_true(player.get_node_or_null("ShipFlightController") is ShipFlightController, "controller required")

    var visuals := player.get_node("Visuals")
    for child_name: String in [
        "Fuselage", "Nose", "LeftWing", "RightWing",
        "LeftEngine", "RightEngine", "LeftEngineGlow", "RightEngineGlow"
    ]:
        assert_true(visuals.get_node_or_null(child_name) is MeshInstance3D, "missing %s" % child_name)

    var controller := player.get_node("ShipFlightController") as ShipFlightController
    assert_equal(controller.get_flight_mode(), FlightMode.Value.ASSISTED, "default mode")
    assert_true(is_equal_approx(controller.get_boost_amount(), 0.0), "default boost")
    player.free()
