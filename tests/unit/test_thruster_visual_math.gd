extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_equal_approx(ThrusterVisualMath.merge_target(0.0, 1.0), 0.35),
        "default assisted output remains capped at 35 percent"
    )
    assert_true(
        is_equal_approx(
            ThrusterVisualMath.merge_target(0.0, 1.0, 0.35),
            0.35
        ),
        "legacy assistance remains capped at 35 percent"
    )
    assert_true(
        is_equal_approx(
            ThrusterVisualMath.merge_target(0.0, 1.0, 1.0),
            1.0
        ),
        "full-authority automatic thrust may reach full output"
    )
    assert_true(
        is_equal_approx(
            ThrusterVisualMath.merge_target(0.8, 0.4, 1.0),
            0.8
        ),
        "direct output retains precedence over weaker automatic output"
    )
    assert_true(
        ThrusterVisualMath.merge_target(0.0, 5.0, 5.0) <= 1.0,
        "automatic visuals never exceed one"
    )
    assert_true(
        is_equal_approx(ThrusterVisualMath.merge_target(0.7, 1.0), 0.7),
        "direct output dominates dim assisted output"
    )
    assert_true(
        is_equal_approx(ThrusterVisualMath.merge_target(0.0, 0.5), 0.175),
        "partial legacy assistance receives one 35 percent scale"
    )
    assert_true(
        is_equal_approx(ThrusterVisualMath.merge_target(0.0, 0.0), 0.0),
        "idle channels remain idle"
    )

    var rising := 0.0
    for _index: int in range(14):
        var next := ThrusterVisualMath.advance(
            rising,
            1.0,
            1.0 / 60.0,
            0.22,
            0.22
        )
        assert_true(next >= rising, "thruster rise must be monotonic")
        rising = next
    assert_true(
        is_equal_approx(rising, 1.0),
        "direct envelope reaches full output after its rise duration"
    )

    var falling := 1.0
    for _index: int in range(14):
        var next := ThrusterVisualMath.advance(
            falling,
            0.0,
            1.0 / 60.0,
            0.22,
            0.22
        )
        assert_true(next <= falling, "thruster fall must be monotonic")
        falling = next
    assert_true(
        is_equal_approx(falling, 0.0),
        "direct envelope reaches zero after its fall duration"
    )

    assert_true(
        is_equal_approx(ThrusterVisualMath.smootherstep(0.0), 0.0),
        "smootherstep lower endpoint"
    )
    assert_true(
        is_equal_approx(ThrusterVisualMath.smootherstep(0.5), 0.5),
        "smootherstep midpoint"
    )
    assert_true(
        is_equal_approx(ThrusterVisualMath.smootherstep(1.0), 1.0),
        "smootherstep upper endpoint"
    )

    assert_equal(
        ThrusterVisualMath.scale_for(0.0, Vector3.BACK),
        Vector3(0.22, 0.22, 0.04),
        "zero envelope retains a tiny nozzle-anchored seed scale"
    )
    assert_equal(
        ThrusterVisualMath.scale_for(1.0, Vector3.BACK),
        Vector3.ONE,
        "full envelope restores authored effect scale"
    )
    assert_true(
        is_equal_approx(ThrusterVisualMath.opacity_for(0.5), 0.25),
        "opacity uses envelope squared"
    )
    assert_true(
        is_equal_approx(ThrusterVisualMath.emission_for(0.5), 0.125),
        "emission uses envelope cubed"
    )
