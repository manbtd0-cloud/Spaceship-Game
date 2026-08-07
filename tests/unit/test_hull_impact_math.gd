extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(is_equal_approx(HullImpactMath.energy(15.0, 180.0), 0.5), "normal pulse hull hit stays readable")
    assert_true(is_equal_approx(HullImpactMath.energy(180.0, 180.0), 1.0), "lethal-scale hull hit clamps to full energy")
    assert_true(is_zero_approx(HullImpactMath.energy(-1.0, 180.0)), "invalid negative hit is invisible")
    assert_equal(HullImpactMath.local_direction(Vector3.ZERO), Vector3.UP, "zero normal fallback is deterministic")
    assert_true(HullImpactMath.local_direction(Vector3(3.0, 0.0, 0.0)).is_equal_approx(Vector3.RIGHT), "direction is normalized")
