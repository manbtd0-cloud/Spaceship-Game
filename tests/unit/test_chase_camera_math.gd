extends "res://tests/support/test_case.gd"

func run() -> void:
    _test_exponential_interpolation()
    _test_preset_contract()
    _test_bounded_position()
    _test_prediction_and_interpolation()
    _test_ship_relative_orientation()
    _test_fov_envelopes()

func _test_exponential_interpolation() -> void:
    assert_true(
        is_equal_approx(ChaseCameraMath.exponential_weight(0.0, 1.0), 0.0),
        "zero sharpness"
    )
    assert_true(
        ChaseCameraMath.exponential_weight(5.0, 0.5) > 0.0,
        "positive interpolation"
    )

func _test_preset_contract() -> void:
    var standard := ChaseCameraPreset.new(&"standard", 14.0, 4.0, 5.0, 19.0)
    assert_true(standard.is_valid(), "standard preset must be valid")
    assert_true(is_equal_approx(standard.rear_offset, 14.0), "standard rear")
    assert_true(is_equal_approx(standard.height, 4.0), "standard height")
    assert_true(
        is_equal_approx(standard.max_speed_pullback, 5.0),
        "standard pullback"
    )
    assert_true(
        is_equal_approx(standard.hard_rear_limit, 19.0),
        "standard limit"
    )
    assert_true(
        not ChaseCameraPreset.new(&"bad", -1.0, 4.0, 5.0, 19.0).is_valid(),
        "negative rear must fail"
    )
    assert_true(
        not ChaseCameraPreset.new(&"bad", 20.0, 4.0, 5.0, 19.0).is_valid(),
        "hard limit below rear offset must fail"
    )

func _test_bounded_position() -> void:
    var zero := ChaseCameraMath.desired_position(
        Transform3D.IDENTITY,
        Vector3.ZERO,
        14.0,
        4.0,
        0.05,
        5.0,
        19.0
    )
    assert_true(
        zero.is_equal_approx(Vector3(0.0, 4.0, 14.0)),
        "zero-speed standard framing"
    )

    var boost := ChaseCameraMath.desired_position(
        Transform3D.IDENTITY,
        Vector3(0.0, 0.0, -240.0),
        14.0,
        4.0,
        0.05,
        5.0,
        19.0
    )
    assert_true(
        is_equal_approx(boost.z, 19.0),
        "standard boost must respect the hard rear clamp"
    )

    var irrelevant_velocities: Array[Vector3] = [
        Vector3(200.0, 0.0, 0.0),
        Vector3(0.0, 200.0, 0.0),
        Vector3(0.0, 0.0, 240.0),
        Vector3(INF, 0.0, 0.0),
    ]
    for irrelevant_velocity: Vector3 in irrelevant_velocities:
        var result := ChaseCameraMath.desired_position(
            Transform3D.IDENTITY,
            irrelevant_velocity,
            14.0,
            4.0,
            0.05,
            5.0,
            19.0
        )
        assert_true(
            result.is_equal_approx(zero),
            "lateral, vertical, reverse, and invalid velocity must not move framing"
        )

    var rotated := Transform3D(
        Basis(Vector3.UP, PI * 0.5),
        Vector3.ZERO
    )
    var world_forward := rotated.basis * Vector3(0.0, 0.0, -100.0)
    assert_true(
        is_equal_approx(
            ChaseCameraMath.local_forward_speed(rotated, world_forward),
            100.0
        ),
        "forward speed must be extracted in ship-local space"
    )

func _test_prediction_and_interpolation() -> void:
    var look := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY,
        Vector3(300.0, 0.0, -400.0),
        0.12,
        10.0,
        8.0
    )
    assert_true(
        look.distance_to(Vector3(0.0, 0.0, -10.0)) <= 8.0001,
        "prediction vector magnitude must be capped"
    )

    var no_velocity := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY,
        Vector3.ZERO,
        0.12,
        10.0,
        8.0
    )
    assert_true(
        no_velocity.is_equal_approx(Vector3(0.0, 0.0, -10.0)),
        "zero velocity must produce no prediction"
    )

    var non_finite := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY,
        Vector3(NAN, 0.0, 0.0),
        0.12,
        10.0,
        8.0
    )
    assert_true(
        non_finite.is_equal_approx(no_velocity),
        "non-finite velocity must fail safe"
    )

    var one_step := ChaseCameraMath.interpolate_scalar(14.0, 20.0, 9.0, 0.4)
    var four_steps := 14.0
    for _index: int in range(4):
        four_steps = ChaseCameraMath.interpolate_scalar(
            four_steps,
            20.0,
            9.0,
            0.1
        )
    assert_true(
        absf(one_step - four_steps) < 0.001,
        "interpolation must be frame-rate independent"
    )

func _test_ship_relative_orientation() -> void:
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

func _test_fov_envelopes() -> void:
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
