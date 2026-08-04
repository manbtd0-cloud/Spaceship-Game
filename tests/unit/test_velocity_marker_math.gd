extends "res://tests/support/test_case.gd"

const STATE_SCRIPT_PATH := "res://src/ui/velocity_marker_state.gd"
const MATH_SCRIPT_PATH := "res://src/ui/velocity_marker_math.gd"

var _math_script: Script

func run() -> void:
    assert_true(
        ResourceLoader.exists(STATE_SCRIPT_PATH),
        "velocity marker state script must exist"
    )
    assert_true(
        ResourceLoader.exists(MATH_SCRIPT_PATH),
        "velocity marker math script must exist"
    )
    if (
        not ResourceLoader.exists(STATE_SCRIPT_PATH)
        or not ResourceLoader.exists(MATH_SCRIPT_PATH)
    ):
        return

    _math_script = load(MATH_SCRIPT_PATH) as Script
    assert_true(_math_script != null, "velocity marker math script must load")
    if _math_script == null:
        return

    assert_true(
        _script_has_method(_math_script, &"project"),
        "velocity marker math must expose project"
    )
    if not _script_has_method(_math_script, &"project"):
        return

    _test_speed_visibility()
    _test_forward_projection()
    _test_lateral_projection()
    _test_behind_and_offscreen_clamping()
    _test_non_finite_inputs()

func _test_speed_visibility() -> void:
    var hidden := _project(Vector3(0.0, 0.0, -1.9))
    assert_true(not bool(hidden.get("visible")), "marker hides below 2 m/s")

    var threshold := _project(Vector3(0.0, 0.0, -2.0))
    assert_true(bool(threshold.get("visible")), "marker appears at 2 m/s")

func _test_forward_projection() -> void:
    var forward := _project(Vector3(0.0, 0.0, -100.0))
    assert_true(bool(forward.get("visible")), "forward marker is visible")
    assert_true(not bool(forward.get("clamped")), "forward marker is not clamped")
    var position := forward.get("screen_position") as Vector2
    assert_true(
        position.distance_to(Vector2(640.0, 360.0)) <= 1.0,
        "forward velocity projects at viewport center"
    )
    assert_true(
        absf(float(forward.get("rotation_radians"))) <= 0.0001,
        "centered marker has neutral rotation"
    )

func _test_lateral_projection() -> void:
    var right_drift := _project(Vector3(40.0, 0.0, -100.0))
    var right_position := right_drift.get("screen_position") as Vector2
    assert_true(bool(right_drift.get("visible")), "lateral velocity remains visible")
    assert_true(
        right_position.x > 640.0,
        "rightward world velocity projects right of center"
    )

    var up_drift := _project(Vector3(0.0, 40.0, -100.0))
    var up_position := up_drift.get("screen_position") as Vector2
    assert_true(
        up_position.y < 360.0,
        "upward world velocity projects above center"
    )

func _test_behind_and_offscreen_clamping() -> void:
    var behind := _project(Vector3(0.0, 0.0, 100.0))
    assert_true(bool(behind.get("visible")), "behind velocity remains visible")
    assert_true(bool(behind.get("clamped")), "behind velocity clamps")
    _assert_inside_safe_margin(
        behind.get("screen_position") as Vector2,
        "behind marker"
    )

    var far_right := _project(Vector3(1000.0, 0.0, -1.0))
    assert_true(bool(far_right.get("clamped")), "offscreen forward velocity clamps")
    var right_position := far_right.get("screen_position") as Vector2
    _assert_inside_safe_margin(right_position, "offscreen marker")
    assert_true(
        is_equal_approx(right_position.x, 1248.0),
        "right edge clamp respects 32 px margin"
    )

func _test_non_finite_inputs() -> void:
    var non_finite_velocity := _project(Vector3(NAN, 0.0, 0.0))
    assert_true(
        not bool(non_finite_velocity.get("visible")),
        "non-finite velocity hides marker"
    )

    var value: Variant = _math_script.call(
        &"project",
        Transform3D.IDENTITY,
        68.0,
        Vector2.ZERO,
        Vector3(0.0, 0.0, -100.0),
        2.0,
        32.0
    )
    var invalid_viewport := _state_as_dictionary(value)
    assert_true(
        not bool(invalid_viewport.get("visible")),
        "invalid viewport hides marker"
    )

func _project(world_velocity: Vector3) -> Dictionary:
    var value: Variant = _math_script.call(
        &"project",
        Transform3D.IDENTITY,
        68.0,
        Vector2(1280.0, 720.0),
        world_velocity,
        2.0,
        32.0
    )
    return _state_as_dictionary(value)

func _state_as_dictionary(value: Variant) -> Dictionary:
    assert_true(value is RefCounted, "project must return a marker state object")
    if not value is RefCounted:
        return {
            "visible": false,
            "screen_position": Vector2.ZERO,
            "clamped": false,
            "rotation_radians": 0.0,
        }
    var state := value as RefCounted
    for property_name: StringName in [
        &"visible",
        &"screen_position",
        &"clamped",
        &"rotation_radians",
    ]:
        assert_true(
            _object_has_property(state, property_name),
            "marker state missing property: %s" % property_name
        )
    return {
        "visible": state.get(&"visible"),
        "screen_position": state.get(&"screen_position"),
        "clamped": state.get(&"clamped"),
        "rotation_radians": state.get(&"rotation_radians"),
    }

func _assert_inside_safe_margin(position: Vector2, label: String) -> void:
    assert_true(
        position.x >= 32.0
        and position.x <= 1248.0
        and position.y >= 32.0
        and position.y <= 688.0,
        "%s stays inside the 32 px safe margin" % label
    )

func _script_has_method(script: Script, method_name: StringName) -> bool:
    for method: Dictionary in script.get_script_method_list():
        if StringName(method.get("name", "")) == method_name:
            return true
    return false

func _object_has_property(object: Object, property_name: StringName) -> bool:
    for property: Dictionary in object.get_property_list():
        if StringName(property.get("name", "")) == property_name:
            return true
    return false
