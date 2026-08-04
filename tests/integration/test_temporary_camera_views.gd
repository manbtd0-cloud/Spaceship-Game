extends "res://tests/support/test_case.gd"

const MATH_SCRIPT_PATH := "res://src/camera/chase_camera_math.gd"

var _math_script: Script

func run() -> void:
    _math_script = load(MATH_SCRIPT_PATH) as Script
    assert_true(_math_script != null, "camera math script must load")
    if _math_script == null:
        return

    var has_transform_helper := _script_has_method(
        _math_script,
        &"temporary_view_transform"
    )
    assert_true(
        has_transform_helper,
        "camera math must expose temporary_view_transform"
    )
    if not has_transform_helper:
        return

    _test_exact_view_transforms()
    _test_rotated_ship_relative_transform()
    _test_runtime_priority_and_release()

func _test_exact_view_transforms() -> void:
    var rear := _temporary_view_transform(
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

    var right := _temporary_view_transform(
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

    var left := _temporary_view_transform(
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

func _test_rotated_ship_relative_transform() -> void:
    var target := Transform3D(
        Basis(Vector3.UP, deg_to_rad(90.0)),
        Vector3(10.0, 2.0, -5.0)
    )
    var right := _temporary_view_transform(
        target,
        ChaseCameraRig.TemporaryView.RIGHT,
        14.0,
        4.0
    )
    var expected_origin := (
        target.origin
        + target.basis.orthonormalized() * Vector3(-14.0, 4.0, 0.0)
    )
    var expected_forward := (
        target.basis.orthonormalized() * Vector3.RIGHT
    ).normalized()
    assert_true(
        right.origin.is_equal_approx(expected_origin),
        "temporary view origin must rotate with the ship"
    )
    assert_true(
        (-right.basis.z).normalized().is_equal_approx(expected_forward),
        "temporary view direction must rotate with the ship"
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

    var target := player.get_node("CameraTarget") as Node3D
    assert_true(target != null, "player must expose CameraTarget")
    if target == null:
        _cleanup_fixture(fixture)
        return

    Input.action_press(&"look_left")
    Input.action_press(&"look_right")
    Input.action_press(&"look_rear")
    rig.step_camera_for_test(1.0 / 60.0)
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.REAR,
        "rear must have priority over simultaneous side views"
    )
    assert_true(
        rig.global_transform.is_equal_approx(
            _temporary_view_transform(
                target.global_transform,
                ChaseCameraRig.TemporaryView.REAR,
                14.0,
                4.0
            )
        ),
        "rear priority must apply the exact rear transform"
    )

    Input.action_release(&"look_rear")
    rig.step_camera_for_test(1.0 / 60.0)
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.RIGHT,
        "right must have priority over left"
    )
    assert_true(
        rig.global_transform.is_equal_approx(
            _temporary_view_transform(
                target.global_transform,
                ChaseCameraRig.TemporaryView.RIGHT,
                14.0,
                4.0
            )
        ),
        "right priority must apply the exact right transform"
    )

    Input.action_release(&"look_right")
    rig.step_camera_for_test(1.0 / 60.0)
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.LEFT,
        "left must remain active after higher-priority releases"
    )
    assert_true(
        rig.global_transform.is_equal_approx(
            _temporary_view_transform(
                target.global_transform,
                ChaseCameraRig.TemporaryView.LEFT,
                14.0,
                4.0
            )
        ),
        "left priority must apply the exact left transform"
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
        ChaseCameraRig.TACTICAL_VELOCITY_LOOK_AHEAD,
        rig.tuning.camera_forward_look_ahead,
        ChaseCameraRig.TACTICAL_MAX_PREDICTION
    )
    var expected_basis := ChaseCameraMath.desired_camera_basis(
        expected_position,
        expected_target,
        target.global_transform
    )
    assert_true(
        rig.global_transform.is_equal_approx(
            Transform3D(expected_basis, expected_position)
        ),
        "release must snap once to the exact selected chase transform"
    )

    _cleanup_fixture(fixture)

func _temporary_view_transform(
    target_transform: Transform3D,
    view: int,
    distance: float,
    height: float
) -> Transform3D:
    var value: Variant = _math_script.call(
        &"temporary_view_transform",
        target_transform,
        view,
        distance,
        height
    )
    assert_true(
        typeof(value) == TYPE_TRANSFORM3D,
        "temporary_view_transform must return Transform3D"
    )
    if typeof(value) != TYPE_TRANSFORM3D:
        return Transform3D.IDENTITY
    return value

func _script_has_method(script: Script, method_name: StringName) -> bool:
    for method: Dictionary in script.get_script_method_list():
        if StringName(method.get("name", "")) == method_name:
            return true
    return false

func _cleanup_fixture(fixture: Node3D) -> void:
    Input.action_release(&"look_rear")
    Input.action_release(&"look_right")
    Input.action_release(&"look_left")
    if fixture.get_parent() != null:
        fixture.get_parent().remove_child(fixture)
    fixture.free()
