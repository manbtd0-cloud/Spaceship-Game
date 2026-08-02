extends "res://tests/support/test_case.gd"

func run() -> void:
    var back_facing := HeroShipAlignment.alignment_basis(
        Vector3.BACK,
        Vector3.UP
    )
    assert_true(
        (back_facing * Vector3.BACK).normalized().dot(Vector3.FORWARD) > 0.999,
        "source forward must map to Godot local -Z"
    )
    assert_true(
        (back_facing * Vector3.UP).normalized().dot(Vector3.UP) > 0.999,
        "source up must map to Godot local +Y"
    )

    var right_facing := HeroShipAlignment.alignment_basis(
        Vector3.RIGHT,
        Vector3.UP
    )
    assert_true(
        (right_facing * Vector3.RIGHT).normalized().dot(Vector3.FORWARD) > 0.999,
        "alignment must work for arbitrary imported forward axes"
    )

    var scale := HeroShipAlignment.uniform_fit_scale(
        Vector3(3.129579, 2.35, 6.008671),
        Vector3(7.2, 4.2, 10.8)
    )
    assert_true(scale > 1.7 and scale < 1.9, "fighter must scale up uniformly")

    assert_true(
        is_equal_approx(
            HeroShipAlignment.uniform_fit_scale(Vector3.ZERO, Vector3.ONE),
            1.0
        ),
        "invalid dimensions must return a safe neutral scale"
    )
