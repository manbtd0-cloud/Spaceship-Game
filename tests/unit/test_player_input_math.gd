extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(
        PlayerInputMath.compose_translation(1.0, 1.0, 0.0, 0.0, 0.0, 0.0),
        Vector3.ZERO,
        "opposing horizontal inputs must cancel"
    )

    var diagonal := PlayerInputMath.compose_translation(
        0.0, 1.0, 0.0, 1.0, 1.0, 0.0
    )
    assert_true(is_equal_approx(diagonal.length(), 1.0), "translation must normalize")
    assert_true(diagonal.z < 0.0, "forward must use local negative Z")

    var mouse_and_keys := PlayerInputMath.compose_rotation(
        Vector2(100.0, -50.0),
        0.25,
        0.0,
        0.0,
        0.4,
        1.0,
        0.0,
        0.01,
        1.0
    )
    assert_equal(
        mouse_and_keys,
        Vector3(0.75, -1.0, 1.0),
        "mouse, pitch/yaw keys, and arrow roll must compose with correct roll sign"
    )

    assert_equal(
        PlayerInputMath.compose_rotation(
            Vector2.ZERO,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            0.01,
            1.0
        ),
        Vector3.ZERO,
        "opposed digital attitude inputs must cancel"
    )

    assert_true(_action_has_key(&"strafe_left", KEY_Q), "Q must strafe left")
    assert_true(_action_has_key(&"strafe_right", KEY_E), "E must strafe right")
    assert_true(_action_has_key(&"yaw_left", KEY_A), "A must yaw left")
    assert_true(_action_has_key(&"yaw_right", KEY_D), "D must yaw right")
    assert_true(_action_has_key(&"pitch_up", KEY_DOWN), "Down Arrow must pitch up")
    assert_true(_action_has_key(&"pitch_down", KEY_UP), "Up Arrow must pitch down")
    assert_true(_action_has_key(&"roll_left", KEY_LEFT), "Left Arrow must roll left")
    assert_true(_action_has_key(&"roll_right", KEY_RIGHT), "Right Arrow must roll right")

    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(-2.0), 0.0), "boost lower clamp")
    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(2.0), 1.0), "boost upper clamp")

func _action_has_key(action: StringName, physical_keycode: int) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        var key_event := event as InputEventKey
        if key_event != null and int(key_event.physical_keycode) == physical_keycode:
            return true
    return false
