extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        bool(ProjectSettings.get_setting(
            "physics/common/physics_interpolation",
            false
        )),
        "project must enable physics interpolation so rendered ship motion is decoupled from 60 Hz physics steps"
    )

    var player_scene := load(
        "res://scenes/player/player_interceptor.tscn"
    ) as PackedScene
    var camera_scene := load(
        "res://scenes/camera/chase_camera_rig.tscn"
    ) as PackedScene
    assert_true(player_scene != null, "player scene must load")
    assert_true(camera_scene != null, "camera scene must load")
    if player_scene == null or camera_scene == null:
        return

    var fixture := Node3D.new()
    var player := player_scene.instantiate() as RigidBody3D
    var rig := camera_scene.instantiate() as ChaseCameraRig
    fixture.add_child(player)
    fixture.add_child(rig)
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(fixture)
    rig.initialize()

    assert_equal(
        rig.physics_interpolation_mode,
        Node.PHYSICS_INTERPOLATION_MODE_OFF,
        "chase camera rig must opt out of automatic interpolation because it performs manual render-frame interpolation"
    )
    assert_true(
        rig.has_method("get_render_target_transform_for_test"),
        "camera rig must expose the transform it samples for rendered target following"
    )
    if rig.has_method("get_render_target_transform_for_test"):
        var target := player.get_node("CameraTarget") as Node3D
        var sampled: Transform3D = rig.call(
            "get_render_target_transform_for_test"
        )
        var expected := target.get_global_transform_interpolated()
        assert_true(
            sampled.is_equal_approx(expected),
            "render-frame camera target must come from get_global_transform_interpolated()"
        )

    tree.root.remove_child(fixture)
    fixture.free()
