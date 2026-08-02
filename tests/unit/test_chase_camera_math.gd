extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_equal_approx(ChaseCameraMath.exponential_weight(0.0, 1.0), 0.0),
        "zero sharpness"
    )
    assert_true(
        ChaseCameraMath.exponential_weight(5.0, 0.5) > 0.0,
        "positive interpolation"
    )

    var position := ChaseCameraMath.desired_position(
        Transform3D.IDENTITY,
        Vector3(0.0, 0.0, -100.0),
        Vector3(0.0, 4.0, 16.0),
        0.08,
        0.05,
        14.0
    )
    assert_true(position.y > 0.0, "camera above ship")
    assert_true(position.z > 16.0, "camera pulls backward with speed")

    var look_target := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY,
        Vector3(0.0, 0.0, -100.0),
        0.12,
        10.0
    )
    assert_true(
        look_target.z < -20.0,
        "camera must predict velocity and nose direction"
    )

    var rolled_ship := Transform3D(
        Basis(Vector3.FORWARD, PI * 0.5),
        Vector3.ZERO
    )
    var rolled_camera_basis := ChaseCameraMath.desired_camera_basis(
        Vector3(0.0, 0.0, 10.0),
        Vector3.ZERO,
        rolled_ship
    )
    assert_true(
        rolled_camera_basis.y.normalized().dot(
            rolled_ship.basis.y.normalized()
        ) > 0.999,
        "camera up must follow ship up with no global horizon bias"
    )

    var inverted_ship := Transform3D(
        Basis(Vector3.FORWARD, PI),
        Vector3.ZERO
    )
    var inverted_camera_basis := ChaseCameraMath.desired_camera_basis(
        Vector3(0.0, 0.0, 10.0),
        Vector3.ZERO,
        inverted_ship
    )
    assert_true(
        inverted_camera_basis.y.normalized().dot(
            inverted_ship.basis.y.normalized()
        ) > 0.999,
        "an upside-down ship must produce an upside-down camera perspective"
    )

    assert_true(
        is_equal_approx(
            ChaseCameraMath.desired_fov(
                160.0,
                0.0,
                68.0,
                160.0,
                240.0,
                82.0,
                85.0,
                1.0
            ),
            82.0
        ),
        "normal envelope FOV"
    )
    assert_true(
        is_equal_approx(
            ChaseCameraMath.desired_fov(
                240.0,
                1.0,
                68.0,
                160.0,
                240.0,
                82.0,
                85.0,
                1.0
            ),
            85.0
        ),
        "boost envelope FOV clamp"
    )
