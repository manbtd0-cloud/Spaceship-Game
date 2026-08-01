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

    assert_equal(
        PlayerInputMath.compose_rotation(
            Vector2(400.0, -300.0), 0.0, 0.0, 0.01, 1.0
        ),
        Vector3(1.0, -1.0, 0.0),
        "mouse command must invert screen motion and clamp"
    )

    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(-2.0), 0.0), "boost lower clamp")
    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(2.0), 1.0), "boost upper clamp")
