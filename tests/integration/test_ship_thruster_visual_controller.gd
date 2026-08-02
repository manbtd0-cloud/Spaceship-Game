extends "res://tests/support/test_case.gd"

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
    if visual_controller != null:
        visual_controller.initialize()
        assert_equal(
            visual_controller.get_socket_count(),
            12,
            "visual controller must resolve twelve canonical sockets"
        )
        assert_equal(
            visual_controller.get_effect_count(),
            12,
            "visual controller must resolve twelve imported source-exact effects"
        )
        assert_true(
            visual_controller.are_all_effects_hidden(),
            "all source-exact effects must be hidden at idle"
        )
        assert_true(
            visual_controller.are_effect_transforms_unchanged(),
            "runtime must not move, rotate, or scale source-exact effect meshes"
        )
        assert_true(
            visual_controller.is_contract_valid(),
            "source-exact thruster visual contract must be valid"
        )

        var forward := FlightCommand.new()
        forward.translation = Vector3.FORWARD
        var forward_intensities := visual_controller.direct_intensities_for_command(
            forward
        )
        assert_true(
            is_equal_approx(
                float(forward_intensities.get(&"Main/MainLeft", 0.0)),
                1.0
            ),
            "forward command must activate the left main plume"
        )
        assert_true(
            is_equal_approx(
                float(forward_intensities.get(&"Main/MainRight", 0.0)),
                1.0
            ),
            "forward command must activate the right main plume"
        )
        assert_equal(
            forward_intensities.size(),
            2,
            "forward command must use only the symmetric main pair"
        )

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
