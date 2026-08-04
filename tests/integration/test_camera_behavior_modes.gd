extends "res://tests/support/test_case.gd"

func run() -> void:
    _test_tactical_error_clamps()
    _test_runtime_behavior_contract()

func _test_tactical_error_clamps() -> void:
    var clamped_position := ChaseCameraMath.clamp_position_error(
        Vector3(10.0, 0.0, 0.0),
        Vector3.ZERO,
        1.5
    )
    assert_true(
        is_equal_approx(clamped_position.length(), 1.5),
        "tactical position error must clamp to 1.5 m"
    )

    var desired_basis := Basis.IDENTITY
    var candidate_basis := Basis(Vector3.UP, deg_to_rad(30.0))
    var clamped_basis := ChaseCameraMath.clamp_rotation_error(
        candidate_basis,
        desired_basis,
        6.0
    )
    var clamped_error_degrees := rad_to_deg(
        desired_basis.get_rotation_quaternion().angle_to(
            clamped_basis.get_rotation_quaternion()
        )
    )
    assert_true(
        clamped_error_degrees <= 6.0001,
        "tactical rotation error must clamp to six degrees"
    )

    var within_limit := Basis(Vector3.UP, deg_to_rad(3.0))
    var unchanged := ChaseCameraMath.clamp_rotation_error(
        within_limit,
        desired_basis,
        6.0
    )
    assert_true(
        unchanged.is_equal_approx(within_limit),
        "rotation already inside the tactical bound must remain unchanged"
    )

func _test_runtime_behavior_contract() -> void:
    var fixture := Node3D.new()
    fixture.name = "CameraBehaviorFixture"

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
    assert_true(rig.is_initialized(), "camera rig must initialize")
    assert_equal(
        rig.get_selected_behavior(),
        CameraBehavior.Value.TACTICAL,
        "Tactical must be the default camera behavior"
    )
    assert_equal(
        rig.get_selected_distance(),
        CameraDistance.Value.STANDARD,
        "Standard must remain the default distance"
    )

    assert_true(
        is_equal_approx(ChaseCameraRig.DYNAMIC_POSITION_SHARPNESS, 5.5),
        "Dynamic position sharpness must preserve the existing camera"
    )
    assert_true(
        is_equal_approx(ChaseCameraRig.DYNAMIC_ROTATION_SHARPNESS, 7.0),
        "Dynamic rotation sharpness must preserve the existing camera"
    )
    assert_true(
        is_equal_approx(ChaseCameraRig.DYNAMIC_VELOCITY_LOOK_AHEAD, 0.08),
        "Dynamic velocity prediction must preserve the existing camera"
    )
    assert_true(
        is_equal_approx(ChaseCameraRig.DYNAMIC_MAX_PREDICTION, 8.0),
        "Dynamic prediction cap must preserve the existing camera"
    )
    assert_true(
        is_equal_approx(ChaseCameraRig.TACTICAL_POSITION_SHARPNESS, 14.0),
        "Tactical position sharpness contract"
    )
    assert_true(
        is_equal_approx(ChaseCameraRig.TACTICAL_ROTATION_SHARPNESS, 22.0),
        "Tactical rotation sharpness contract"
    )
    assert_true(
        is_equal_approx(ChaseCameraRig.TACTICAL_VELOCITY_LOOK_AHEAD, 0.015),
        "Tactical velocity prediction contract"
    )
    assert_true(
        is_equal_approx(ChaseCameraRig.TACTICAL_MAX_PREDICTION, 2.0),
        "Tactical prediction cap contract"
    )

    var camera := rig.get_node_or_null("Camera3D") as Camera3D
    assert_true(camera != null, "camera rig must retain Camera3D")
    var camera_id := camera.get_instance_id() if camera != null else 0

    assert_true(
        rig.select_behavior(CameraBehavior.Value.DYNAMIC),
        "valid behavior change must be accepted"
    )
    assert_true(
        rig.select_distance(CameraDistance.Value.FAR),
        "valid distance change must be accepted"
    )
    assert_equal(
        rig.get_selected_behavior(),
        CameraBehavior.Value.DYNAMIC,
        "distance selection must not change behavior"
    )
    assert_equal(
        rig.get_selected_distance(),
        CameraDistance.Value.FAR,
        "behavior selection must not change distance"
    )
    assert_true(
        not rig.select_behavior(CameraBehavior.Value.DYNAMIC),
        "same behavior must be a no-op"
    )
    assert_true(
        not rig.select_behavior(999),
        "invalid behavior must be rejected"
    )
    assert_true(
        not rig.select_distance(999),
        "invalid distance must be rejected"
    )

    assert_true(
        rig.select_behavior(CameraBehavior.Value.LOCKED),
        "Locked behavior must be selectable"
    )
    assert_true(
        rig.select_distance(CameraDistance.Value.STANDARD),
        "Locked camera must accept an independent distance"
    )
    rig.global_transform = Transform3D(
        Basis(Vector3.UP, deg_to_rad(40.0)),
        Vector3(25.0, -10.0, 30.0)
    )
    rig.step_camera_for_test(1.0 / 60.0)

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
    var expected_target := ChaseCameraMath.desired_look_target(
        target.global_transform,
        Vector3.ZERO,
        0.0,
        rig.tuning.camera_forward_look_ahead,
        0.0
    )
    var expected_basis := ChaseCameraMath.desired_camera_basis(
        expected_position,
        expected_target,
        target.global_transform
    )
    assert_true(
        rig.global_position.is_equal_approx(expected_position),
        "Locked camera must snap to the exact desired position in one step"
    )
    var locked_rotation_error := rad_to_deg(
        expected_basis.get_rotation_quaternion().angle_to(
            rig.global_transform.basis.get_rotation_quaternion()
        )
    )
    assert_true(
        locked_rotation_error <= 0.001,
        "Locked camera must snap to the exact desired rotation in one step"
    )
    if camera != null:
        assert_equal(
            camera.get_instance_id(),
            camera_id,
            "switching behavior must not recreate Camera3D"
        )

    fixture.get_parent().remove_child(fixture)
    fixture.free()
