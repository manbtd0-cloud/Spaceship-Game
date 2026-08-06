extends "res://tests/support/test_case.gd"

func run() -> void:
    var radii := Vector3(8.0, 3.0, 7.0)
    assert_true(
        ShieldImpactMath.local_direction(
            Vector3(8.0, 0.0, 0.0),
            radii
        ).is_equal_approx(Vector3.RIGHT),
        "right-side impact maps to local right"
    )
    assert_true(
        ShieldImpactMath.local_direction(
            Vector3(0.0, 3.0, 0.0),
            radii
        ).is_equal_approx(Vector3.UP),
        "top impact maps to local up"
    )
    assert_equal(
        ShieldImpactMath.local_direction(Vector3.ZERO, radii),
        Vector3.FORWARD,
        "center fallback is deterministic"
    )
    assert_true(
        is_equal_approx(
            ShieldImpactMath.hit_energy(15.0, 150.0),
            0.55
        ),
        "ordinary projectile hit remains readable"
    )
    assert_true(
        is_equal_approx(
            ShieldImpactMath.hit_energy(150.0, 150.0),
            1.0
        ),
        "full shield damage clamps to full energy"
    )
