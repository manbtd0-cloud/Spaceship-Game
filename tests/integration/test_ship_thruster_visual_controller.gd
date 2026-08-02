extends "res://tests/support/test_case.gd"

const MAIN_LEFT_EFFECT := &"ThrusterEffects/MainEffects/MainLeftEffect"
const MAIN_RIGHT_EFFECT := &"ThrusterEffects/MainEffects/MainRightEffect"
const MAIN_EFFECTS := PackedStringArray([
    "ThrusterEffects/MainEffects/MainLeftEffect",
    "ThrusterEffects/MainEffects/MainRightEffect",
])

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
    var flight_controller := player.get_node_or_null(
        "ShipFlightController"
    ) as ShipFlightController
    assert_true(
        visual_controller != null,
        "player scene must contain ShipThrusterVisualController"
    )
    assert_true(
        flight_controller != null,
        "player scene must contain ShipFlightController"
    )
    if visual_controller == null or flight_controller == null:
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
        "all effects must be hidden at idle"
    )
    assert_true(
        visual_controller.are_effect_origins_anchored(),
        "every nozzle-local effect origin must begin anchored"
    )
    assert_true(
        visual_controller.is_contract_valid(),
        "schema-four thruster visual contract must be valid"
    )

    var coast := FlightCommand.new()
    visual_controller.set_test_command(coast)
    visual_controller.set_test_assist_wrench(Vector3.ZERO, Vector3.ZERO)
    visual_controller.step_visuals(0.25)
    assert_true(
        visual_controller.are_all_effects_hidden(),
        "coasting without pilot or assist acceleration must remain dark"
    )

    var forward := FlightCommand.new()
    forward.translation = Vector3.FORWARD
    var direct_preview := visual_controller.direct_intensities_for_command(
        forward
    )
    assert_true(
        is_equal_approx(
            float(direct_preview.get(&"Main/MainLeft", 0.0)),
            1.0
        ),
        "forward command must map to the left main thruster"
    )
    assert_true(
        is_equal_approx(
            float(direct_preview.get(&"Main/MainRight", 0.0)),
            1.0
        ),
        "forward command must map to the right main thruster"
    )

    visual_controller.set_test_command(forward)
    visual_controller.step_visuals(0.25)
    assert_equal(
        visual_controller.get_active_effect_paths(),
        MAIN_EFFECTS,
        "forward must activate only the symmetric main pair"
    )
    assert_true(
        is_equal_approx(
            visual_controller.get_direct_target(MAIN_LEFT_EFFECT),
            1.0
        ),
        "left main direct target must reach one"
    )
    assert_true(
        is_equal_approx(
            visual_controller.get_direct_target(MAIN_RIGHT_EFFECT),
            1.0
        ),
        "right main direct target must reach one"
    )
    assert_true(
        is_equal_approx(
            visual_controller.get_envelope(MAIN_LEFT_EFFECT),
            1.0
        ),
        "left main envelope must reach full output"
    )
    assert_true(
        is_equal_approx(
            visual_controller.get_envelope(MAIN_RIGHT_EFFECT),
            1.0
        ),
        "right main envelope must reach full output"
    )
    assert_true(
        visual_controller.are_effect_origins_anchored(),
        "plume growth must not move any nozzle origin"
    )

    visual_controller.set_test_command(coast)
    visual_controller.set_test_assist_wrench(
        Vector3.FORWARD * flight_controller.get_force_reference(),
        Vector3.ZERO
    )
    visual_controller.step_visuals(0.25)
    for path: String in MAIN_EFFECTS:
        var effect_path := StringName(path)
        assert_true(
            visual_controller.get_assist_target(effect_path) > 0.99,
            "full assisted forward correction must reach raw target one"
        )
        assert_true(
            visual_controller.get_merged_target(effect_path) <= 0.35,
            "assisted output must be capped exactly once at 35 percent"
        )
        assert_true(
            visual_controller.get_envelope(effect_path) <= 0.35,
            "assisted plume envelope must remain dimmer than direct output"
        )

    visual_controller.set_test_assist_wrench(Vector3.ZERO, Vector3.ZERO)
    visual_controller.step_visuals(0.25)
    assert_true(
        visual_controller.are_all_effects_hidden(),
        "released direct and assisted thrust must decay to invisible"
    )
    assert_true(
        visual_controller.are_effect_origins_anchored(),
        "plume decay must preserve every nozzle origin"
    )

    visual_controller.clear_test_inputs()
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
