extends "res://tests/support/test_case.gd"

const PLAYER_SCENE_PATH := "res://scenes/player/player_interceptor.tscn"
const TUNING_RESOURCE_PATH := "res://config/flight/player_flight_tuning.tres"

func run() -> void:
    assert_true(
        ResourceLoader.exists(TUNING_RESOURCE_PATH),
        "player tuning resource must use a case-safe non-conflicting path"
    )

    var has_exact_tuning_dependency := false
    for dependency: String in ResourceLoader.get_dependencies(PLAYER_SCENE_PATH):
        if dependency.ends_with(TUNING_RESOURCE_PATH):
            has_exact_tuning_dependency = true
            break
    assert_true(
        has_exact_tuning_dependency,
        "player scene must reference the exact case-safe tuning path"
    )

    var packed := load(PLAYER_SCENE_PATH) as PackedScene
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
    assert_true(is_equal_approx(controller.get_boost_heat(), 0.0), "default boost heat")
    assert_true(not controller.is_boost_locked_out(), "boost starts unlocked")
    assert_true(
        is_equal_approx(controller.get_active_speed_limit(), 160.0),
        "normal envelope is active at spawn"
    )

    var hud_packed := load("res://scenes/ui/flight_hud.tscn") as PackedScene
    assert_true(hud_packed != null, "HUD scene must load")
    if hud_packed != null:
        var hud := hud_packed.instantiate() as FlightHud
        assert_true(hud != null, "HUD root must use FlightHud")
        if hud != null:
            for label_path: String in [
                "SafeArea/Layout/SpeedLabel",
                "SafeArea/Layout/ModeLabel",
                "SafeArea/Layout/BoostLabel",
                "SafeArea/Layout/CaptureLabel",
                "SafeArea/Layout/ControlsLabel"
            ]:
                assert_true(
                    hud.get_node_or_null(label_path) is Label,
                    "missing HUD label: %s" % label_path
                )
            hud.free()

    player.free()
