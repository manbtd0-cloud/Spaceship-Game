extends "res://tests/support/test_case.gd"

func run() -> void:
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
            "visual controller must create twelve exhaust effects"
        )
        assert_true(
            visual_controller.are_all_effects_hidden(),
            "all canonical exhaust effects must be hidden at idle"
        )
        assert_true(
            visual_controller.is_contract_valid(),
            "canonical thruster visual contract must be valid"
        )

    player.free()
