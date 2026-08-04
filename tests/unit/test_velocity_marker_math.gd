extends "res://tests/support/test_case.gd"

func run() -> void:
    _test_speed_visibility()
    _test_forward_projection()
    _test_lateral_projection()
    _test_behind_and_offscreen_clamping()
    _test_non_finite_inputs()

func _test_speed_visibility() -> void:
    var hidden := _project(Vector3(0.0, 0.0, -1.9))
    assert_true(not hidden.visible, "marker hides below 2 m/s")

    var threshold := _project(Vector3(0.0, 0.0, -2.0))
    assert_true(threshold.visible, "marker appears at 2 m/s")

func _test_forward_projection() -> void:
    var forward := _project(Vector3(0.0, 0.0, -100.0))
    assert_true(forward.visible, "forward marker is visible")
    assert_true(not forward.clamped, "forward marker is not clamped")
    assert_true(
        forward.screen_position.distance_to(Vector2(640.0, 360.0)) <= 1.0,
        "forward velocity projects at viewport center"
    )
    assert_true(
        absf(forward.rotation_radians) <= 0.0001,
        "centered marker has neutral rotation"
    )

func _test_lateral_projection() -> void:
    var right_drift := _project(Vector3(40.0, 0.0, -100.0))
    assert_true(right_drift.visible, "lateral velocity remains visible")
    assert_true(
        right_drift.screen_position.x > 640.0,
        "rightward world velocity projects right of center"
    )

    var up_drift := _project(Vector3(0.0, 40.0, -100.0))
    assert_true(
        up_drift.screen_position.y < 360.0,
        "upward world velocity projects above center"
    )

func _test_behind_and_offscreen_clamping() -> void:
    var behind := _project(Vector3(0.0, 0.0, 100.0))
    assert_true(behind.visible, "behind velocity remains visible")
    assert_true(behind.clamped, "behind velocity clamps")
    _assert_inside_safe_margin(behind.screen_position, "behind marker")

    var far_right := _project(Vector3(1000.0, 0.0, -1.0))
    assert_true(far_right.clamped, "offscreen forward velocity clamps")
    _assert_inside_safe_margin(far_right.screen_position, "offscreen marker")
    assert_true(
        is_equal_approx(far_right.screen_position.x, 1248.0),
        "right edge clamp respects 32 px margin"
    )

func _test_non_finite_inputs() -> void:
    var non_finite_velocity := _project(Vector3(NAN, 0.0, 0.0))
    assert_true(
        not non_finite_velocity.visible,
        "non-finite velocity hides marker"
    )

    var invalid_viewport := VelocityMarkerMath.project(
        Transform3D.IDENTITY,
        68.0,
        Vector2.ZERO,
        Vector3(0.0, 0.0, -100.0),
        2.0,
        32.0
    )
    assert_true(
        not invalid_viewport.visible,
        "invalid viewport hides marker"
    )

func _project(world_velocity: Vector3) -> VelocityMarkerState:
    return VelocityMarkerMath.project(
        Transform3D.IDENTITY,
        68.0,
        Vector2(1280.0, 720.0),
        world_velocity,
        2.0,
        32.0
    )

func _assert_inside_safe_margin(position: Vector2, label: String) -> void:
    assert_true(
        position.x >= 32.0
        and position.x <= 1248.0
        and position.y >= 32.0
        and position.y <= 688.0,
        "%s stays inside the 32 px safe margin" % label
    )
