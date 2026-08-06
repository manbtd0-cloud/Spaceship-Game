extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_zero_approx(
            CollisionDamageMath.compute_damage(11.99, 12.0, 2.0, 80.0)
        ),
        "sub-threshold collision applies no damage"
    )
    assert_true(
        is_equal_approx(
            CollisionDamageMath.compute_damage(20.0, 12.0, 2.0, 80.0),
            16.0
        ),
        "collision damage uses excess speed"
    )
    assert_true(
        is_equal_approx(
            CollisionDamageMath.compute_damage(100.0, 12.0, 2.0, 80.0),
            80.0
        ),
        "collision damage obeys cap"
    )
    assert_true(
        is_zero_approx(
            CollisionDamageMath.compute_damage(NAN, 12.0, 2.0, 80.0)
        ),
        "non-finite speed fails closed"
    )
    assert_true(
        is_zero_approx(
            CollisionDamageMath.compute_damage(30.0, NAN, 2.0, 80.0)
        ),
        "non-finite tuning fails closed"
    )
