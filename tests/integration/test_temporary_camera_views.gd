extends "res://tests/support/test_case.gd"

func run() -> void:
    _test_exact_view_transforms()
    _test_runtime_priority_and_release()

func _test_exact_view_transforms() -> void:
    var rear := ChaseCameraMath.temporary_view_transform(
        Transform3D.IDENTITY,
        ChaseCameraRig.TemporaryView.REAR,
        14.0,
        4.0
    )
    assert_true(
        rear.origin.is_equal_approx(Vector3(0.0, 4.0, -14.0)),
        "rear view origin must be exact"
    )
    assert_true(
        (-rear.basis.z).normalized().is_equal_approx(Vector3.BACK),
        "rear view must look along ship-local +Z"
    )

    var right := ChaseCameraMath.temporary_view_transform(
        Transform3D.IDENTITY,
        ChaseCameraRig.TemporaryView.RIGHT,
        14.0,
        4.0
    )
    assert_true(
        right.origin.is_equal_approx(Vector3(-14.0, 4.0, 0.0)),
        "right view origin must be exact"
    )
    assert_true(
        (-right.basis.z).normalized().is_equal_approx(Vector3.RIGHT),
        "right view must look along ship-local +X"
    )

    var left := ChaseCameraMath.temporary_view_transform(
        Transform3D.IDENTITY,
        ChaseCameraRig.TemporaryView.LEFT,
        14.0,
        4.0
    )
    assert_true(
        left.origin.is_equal_approx(Vector3(14.0, 4.0, 0.0)),
        "left view origin must be exact"
    )
    assert_true(
        (-left.basis.z).normalized().is_equal_approx(Vector3.LEFT),
        "left view must look along ship-local -X"
    )

func _test_runtime_priority_and_release() -> void:
    var fixture := Node3D.new()
    fixture.name = "TemporaryCameraViewFixture"

    var player_scene := load(
        "res://scenes/player/player_interceptor.tscn"
    ) as PackedScene
    var camera_scene := load(
        "res://scenes/camera/chase_camera_rig.tscn"
    ) as PackedScene
    assert_true(player_scene != null, "player scene must load")
    assert_true(camera_scene != null, "camera scene must load")
    if player_scene == null or camera_scene == null:
        fixture.free()
        return

    var player := player_scene.instantiate() as RigidBody3D
    var rig := camera_scene.instantiate() as ChaseCameraRig
    assert_true(player != null, "player scene must instantiate")
    assert_true(rig != null, "camera scene must instantiate")
    if player == null or rig == null:
        if player != null:
            player.free()
        if rig != null:
            rig.free()
        fixture.free()
        return

    fixture.add_child(player)
    fixture.add_child(rig)
    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree == null:
        fixture.free()
        return
    tree.root.add_child(fixture)

    rig.initialize()
    rig.select_behavior(CameraBehavior.Value.TACTICAL)
    rig.select_distance(CameraDistance.Value.STANDARD)

    Input.action_press(&"look_left")
    Input.action_press(&"look_right")
    Input.action_press(&"look_rear")
    rig.step_camera_for_test(1.0 / 60.0)
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.REAR,
        "rear must have priority over simultaneous side views"
    )

    Input.action_release(&"look_rear")
    rig.step_camera_for_test(1.0 / 60.0)
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.RIGHT,
        "right must have priority over left"
    )

    Input.action_release(&"look_right")
    rig.step_camera_for_test(1.0 / 60.0)
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.LEFT,
        "left must remain active after higher-priority releases"
    )

    Input.action_release(&"look_left")
    rig.step_camera_for_test(1.0 / 60.0)
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.NONE,
        "releasing all view keys must restore chase mode"
    )
    assert_equal(
        rig.get_selected_behavior(),
        CameraBehavior.Value.TACTICAL,
        "temporary views must preserve selected behavior"
    )
    assert_equal(
        rig.get_selected_distance(),
        CameraDistance.Value.STANDARD,
        "temporary views must preserve selected distance"
    )

    var target := player.get_node("CameraTarget") as Node3D
    var expected_position := ChaseCameraMath.desired_position(
        target.global_transform,
        Vector3.ZERO,
        14.0,
        4.0,
        rig.tuning.camera_speed_pullback,
        5.0,
        19.0
    )
    assert_true(
        rig.global_position.is_equal_approx(expected_position),
        "release must snap once to the selected chase framing"
    )

    Input.action_release(&"look_rear")
    Input.action_release(&"look_right")
    Input.action_release(&"look_left")
    fixture.get_parent().remove_child(fixture)
    fixture.free()
