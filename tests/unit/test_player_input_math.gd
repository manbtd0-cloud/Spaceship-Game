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
        Vector3(0.75, -1.0, -1.0),
        "mouse, arrows, and A/D roll must compose and clamp"
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

    for action: StringName in [
        &"pitch_up", &"pitch_down", &"yaw_left", &"yaw_right"
    ]:
        assert_true(InputMap.has_action(action), "missing input action: %s" % action)

    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(-2.0), 0.0), "boost lower clamp")
    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(2.0), 1.0), "boost upper clamp")
