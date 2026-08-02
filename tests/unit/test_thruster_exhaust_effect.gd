extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        not ThrusterExhaustEffect.should_be_visible(0.0),
        "zero-output thruster effect must be hidden"
    )
    assert_true(
        ThrusterExhaustEffect.should_be_visible(0.25),
        "non-zero thruster output must be visible"
    )

    var main_length := ThrusterExhaustEffect.output_length(1.0, 0.0, &"main")
    var boosted_main_length := ThrusterExhaustEffect.output_length(1.0, 1.0, &"main")
    var retro_length := ThrusterExhaustEffect.output_length(1.0, 0.0, &"retro")
    var maneuver_length := ThrusterExhaustEffect.output_length(
        1.0,
        0.0,
        &"maneuver"
    )

    assert_true(main_length > retro_length, "main exhaust must exceed retro length")
    assert_true(retro_length > maneuver_length, "retro exhaust must exceed maneuver length")
    assert_true(
        boosted_main_length > main_length,
        "boost must lengthen an active main exhaust"
    )

    var main_radius := ThrusterExhaustEffect.output_radius(1.0, &"main")
    var retro_radius := ThrusterExhaustEffect.output_radius(1.0, &"retro")
    var maneuver_radius := ThrusterExhaustEffect.output_radius(1.0, &"maneuver")
    assert_true(main_radius > retro_radius, "main exhaust must be widest")
    assert_true(retro_radius > maneuver_radius, "maneuver exhaust must be narrowest")

    assert_true(
        is_equal_approx(
            ThrusterExhaustEffect.output_length(-5.0, 0.0, &"main"),
            0.0
        ),
        "negative output must clamp to zero"
    )
