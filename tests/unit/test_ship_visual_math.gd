extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_equal_approx(ShipVisualMath.exhaust_strength(0.0, 0.0), 0.0),
        "idle ship must have no exhaust"
    )

    var normal_thrust := ShipVisualMath.exhaust_strength(1.0, 0.0)
    var boosted_thrust := ShipVisualMath.exhaust_strength(1.0, 1.0)
    assert_true(normal_thrust > 0.0, "forward thrust must create exhaust")
    assert_true(boosted_thrust > normal_thrust, "boost must intensify exhaust")
    assert_true(boosted_thrust <= 1.0, "exhaust strength must stay normalized")

    assert_true(
        is_equal_approx(ShipVisualMath.exhaust_strength(0.0, 1.0), 0.0),
        "boost without forward thrust must not show rear exhaust"
    )

    assert_true(
        ShipVisualMath.exhaust_length_scale(boosted_thrust)
        > ShipVisualMath.exhaust_length_scale(normal_thrust),
        "boost must lengthen the exhaust"
    )
