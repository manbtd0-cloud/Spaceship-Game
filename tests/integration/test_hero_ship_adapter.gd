extends "res://tests/support/test_case.gd"

const PLAYER_SCENE_PATH := "res://scenes/player/player_interceptor.tscn"

func run() -> void:
    var packed := load(PLAYER_SCENE_PATH) as PackedScene
    assert_true(packed != null, "player scene must load for adapter test")
    if packed == null:
        return

    var player := packed.instantiate() as RigidBody3D
    assert_true(player != null, "player root must instantiate")
    if player == null:
        return

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner must provide SceneTree")
    if tree == null:
        player.free()
        return

    tree.root.add_child(player)

    var adapter := player.get_node_or_null(
        "HeroShipModelAdapter"
    ) as HeroShipModelAdapter
    var model := player.get_node_or_null(
        "VisualRoot/SmallSciFiFighter"
    ) as Node3D
    assert_true(adapter != null, "hero model adapter required")
    assert_true(model != null, "hero model instance required")

    if adapter != null:
        assert_true(
            adapter.get_applied_scale() > 1.5,
            "runtime adapter must enlarge the undersized pushed GLB"
        )

    if model != null:
        var forward_marker := model.find_child(
            "ForwardMarker",
            true,
            false
        ) as Node3D
        var up_marker := model.find_child(
            "UpMarker",
            true,
            false
        ) as Node3D
        assert_true(forward_marker != null, "runtime forward marker required")
        assert_true(up_marker != null, "runtime up marker required")

        if forward_marker != null:
            var forward_world := (
                forward_marker.global_position - model.global_position
            ).normalized()
            var forward_local := (
                player.global_transform.basis.inverse() * forward_world
            ).normalized()
            assert_true(
                forward_local.dot(Vector3.FORWARD) > 0.99,
                "runtime fighter nose must face player local -Z"
            )

        if up_marker != null:
            var up_world := (
                up_marker.global_position - model.global_position
            ).normalized()
            var up_local := (
                player.global_transform.basis.inverse() * up_world
            ).normalized()
            assert_true(
                up_local.dot(Vector3.UP) > 0.99,
                "runtime fighter top must face player local +Y"
            )

    player.free()
