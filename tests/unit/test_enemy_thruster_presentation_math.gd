extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := EnemyFighterTuning.new()

    var forward := EnemyThrusterPresentationMath.command_for_local_wrench(
        Vector3(0.0, 0.0, -tuning.forward_force),
        Vector3.ZERO,
        tuning
    )
    assert_true(
        forward.translation.is_equal_approx(Vector3(0.0, 0.0, -1.0)),
        "full forward force maps to one legal forward command"
    )

    var combined := EnemyThrusterPresentationMath.command_for_local_wrench(
        Vector3(
            -tuning.strafe_force * 0.5,
            tuning.vertical_force * 0.25,
            tuning.reverse_force * 0.75
        ),
        Vector3(
            tuning.pitch_torque * 0.4,
            -tuning.yaw_torque * 0.6,
            tuning.roll_torque * 2.0
        ),
        tuning
    )
    assert_true(is_equal_approx(combined.translation.x, -0.5), "strafe normalizes")
    assert_true(is_equal_approx(combined.translation.y, 0.25), "vertical normalizes")
    assert_true(is_equal_approx(combined.translation.z, 0.75), "reverse normalizes")
    assert_true(is_equal_approx(combined.rotation.x, 0.4), "pitch normalizes")
    assert_true(is_equal_approx(combined.rotation.y, -0.6), "yaw normalizes")
    assert_true(is_equal_approx(combined.rotation.z, 1.0), "roll clamps to legal authority")

    var invalid := EnemyThrusterPresentationMath.command_for_local_wrench(
        Vector3(INF, 0.0, 0.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(invalid.translation, Vector3.ZERO, "non-finite force fails closed")
    assert_equal(invalid.rotation, Vector3.ZERO, "non-finite force cannot leak rotation")

    var matrix := ThrusterActionMatrix.load_checked_in(
        "res://config/ships/small_sci_fi_fighter_thruster_actions.json"
    )
    assert_true(matrix != null and matrix.is_valid(), "checked-in matrix is valid")
    if matrix != null:
        var intensities := matrix.intensities_for(forward)
        assert_true(is_equal_approx(float(intensities.get(&"Main/MainLeft", 0.0)), 1.0), "left main follows real full forward force")
        assert_true(is_equal_approx(float(intensities.get(&"Main/MainRight", 0.0)), 1.0), "right main follows real full forward force")
        assert_equal(intensities.size(), 2, "pure forward force does not illuminate unrelated nozzles")
