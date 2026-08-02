extends "res://tests/support/test_case.gd"

const MAIN_LEFT_SOCKET := &"Main/MainLeft"
const MAIN_RIGHT_SOCKET := &"Main/MainRight"
const MAIN_LEFT_EFFECT := "ThrusterEffects/MainEffects/MainLeftEffect"
const MAIN_RIGHT_EFFECT := "ThrusterEffects/MainEffects/MainRightEffect"

func run() -> void:
    _test_unique_logical_root_lookup()

    var packed := load("res://scenes/player/player_interceptor.tscn") as PackedScene
    assert_true(packed != null, "player interceptor scene must load")
    if packed == null:
        return

    var player := packed.instantiate() as RigidBody3D
    assert_true(player != null, "player interceptor root must be RigidBody3D")
    if player == null:
        return

    var visual_controller := player.get_node_or_null(
        "ShipThrusterVisualController"
    ) as ShipThrusterVisualController
    assert_true(
        visual_controller != null,
        "player scene must contain ShipThrusterVisualController"
    )
    if visual_controller == null:
        player.free()
        return

    visual_controller.initialize()
    assert_equal(
        visual_controller.get_socket_count(),
        12,
        "visual controller must resolve twelve canonical sockets"
    )
    assert_equal(
        visual_controller.get_effect_count(),
        12,
        "visual controller must resolve twelve nozzle-local effects"
    )
    assert_true(
        visual_controller.are_all_effects_hidden(),
        "all source-exact effects must be hidden at idle"
    )
    assert_true(
        visual_controller.are_effect_pivots_unchanged(),
        "runtime initialization must preserve every nozzle pivot"
    )
    assert_true(
        visual_controller.is_contract_valid(),
        "schema-four thruster visual contract must be valid"
    )

    var forward := FlightCommand.new()
    forward.translation = Vector3.FORWARD
    var forward_intensities := visual_controller.direct_intensities_for_command(
        forward
    )
    assert_true(
        is_equal_approx(
            float(forward_intensities.get(MAIN_LEFT_SOCKET, 0.0)),
            1.0
        ),
        "forward command must activate the left main plume"
    )
    assert_true(
        is_equal_approx(
            float(forward_intensities.get(MAIN_RIGHT_SOCKET, 0.0)),
            1.0
        ),
        "forward command must activate the right main plume"
    )
    assert_equal(
        forward_intensities.size(),
        2,
        "forward command must use only the symmetric main pair"
    )

    visual_controller.set_test_command(FlightCommand.new())
    visual_controller.set_test_assist_wrench(Vector3.ZERO, Vector3.ZERO)
    visual_controller.set_test_boost(1.0)
    visual_controller.step_visuals(0.30)
    assert_true(
        visual_controller.are_all_effects_hidden(),
        "coasting with no force request must remain dark even during boost state"
    )

    visual_controller.set_test_command(forward)
    visual_controller.set_test_assist_wrench(Vector3.ZERO, Vector3.ZERO)
    visual_controller.set_test_boost(0.0)
    visual_controller.step_visuals(0.25)
    assert_equal(
        visual_controller.get_active_effect_paths(),
        PackedStringArray([MAIN_LEFT_EFFECT, MAIN_RIGHT_EFFECT]),
        "forward must activate exactly both main effects"
    )
    assert_true(
        is_equal_approx(visual_controller.get_direct_target(MAIN_LEFT_SOCKET), 1.0),
        "left main direct target must be full"
    )
    assert_true(
        is_equal_approx(visual_controller.get_direct_target(MAIN_RIGHT_SOCKET), 1.0),
        "right main direct target must be full"
    )
    assert_true(
        is_equal_approx(visual_controller.get_envelope(MAIN_LEFT_SOCKET), 1.0),
        "left main envelope must reach full after rise duration"
    )
    assert_true(
        is_equal_approx(visual_controller.get_envelope(MAIN_RIGHT_SOCKET), 1.0),
        "right main envelope must reach full after rise duration"
    )
    assert_true(
        visual_controller.are_effect_pivots_unchanged(),
        "growing source-exact effects must not move nozzle pivots"
    )

    visual_controller.set_test_command(FlightCommand.new())
    visual_controller.set_test_assist_wrench(Vector3.FORWARD, Vector3.ZERO)
    visual_controller.step_visuals(0.25)
    assert_true(
        visual_controller.get_direct_target(MAIN_LEFT_SOCKET) <= 0.0,
        "assisted-only output must not create direct thrust"
    )
    assert_true(
        visual_controller.get_assist_target(MAIN_LEFT_SOCKET) > 0.0,
        "assisted correction must request the approved main pair"
    )
    assert_true(
        visual_controller.get_merged_target(MAIN_LEFT_SOCKET) <= 0.35,
        "assisted output must be capped at 35 percent exactly once"
    )
    assert_true(
        visual_controller.get_merged_target(MAIN_RIGHT_SOCKET) <= 0.35,
        "both assisted main outputs must remain dim"
    )

    visual_controller.set_test_assist_wrench(Vector3.ZERO, Vector3.ZERO)
    visual_controller.step_visuals(0.30)
    assert_true(
        visual_controller.are_all_effects_hidden(),
        "released direct and assisted requests must decay to hidden"
    )

    visual_controller.clear_test_overrides()
    player.free()

func _test_unique_logical_root_lookup() -> void:
    var imported_wrapper := Node3D.new()
    var generated_root := Node3D.new()
    var logical_root := Node3D.new()
    logical_root.name = "ThrusterEffects"
    imported_wrapper.add_child(generated_root)
    generated_root.add_child(logical_root)

    assert_equal(
        ShipThrusterVisualController.find_unique_logical_root(
            imported_wrapper,
            &"ThrusterEffects"
        ),
        logical_root,
        "logical hierarchy lookup must ignore imported wrapper depth"
    )

    var duplicate := Node3D.new()
    duplicate.name = "ThrusterEffects"
    imported_wrapper.add_child(duplicate)
    assert_equal(
        ShipThrusterVisualController.find_unique_logical_root(
            imported_wrapper,
            &"ThrusterEffects"
        ),
        null,
        "duplicate logical roots must be rejected"
    )

    imported_wrapper.free()
