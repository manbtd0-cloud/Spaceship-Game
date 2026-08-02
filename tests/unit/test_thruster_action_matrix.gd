extends "res://tests/support/test_case.gd"

const MATRIX_PATH := "res://config/ships/small_sci_fi_fighter_thruster_actions.json"

func run() -> void:
    assert_equal(
        ThrusterAction.action_count(),
        12,
        "thruster matrix must cover twelve pilot actions"
    )
    assert_equal(
        ThrusterAction.target_force(ThrusterAction.Value.FORWARD),
        Vector3.FORWARD,
        "forward action must target local negative Z"
    )
    assert_equal(
        ThrusterAction.target_force(ThrusterAction.Value.REVERSE),
        Vector3.BACK,
        "reverse action must target local positive Z"
    )
    assert_equal(
        ThrusterAction.target_torque(ThrusterAction.Value.PITCH_UP),
        Vector3.RIGHT,
        "pitch up must target positive local X torque"
    )
    assert_equal(
        ThrusterAction.target_torque(ThrusterAction.Value.YAW_LEFT),
        Vector3.UP,
        "yaw left must target positive local Y torque"
    )
    assert_equal(
        ThrusterAction.target_torque(ThrusterAction.Value.ROLL_LEFT),
        Vector3.BACK,
        "roll left must target positive local Z torque"
    )

    var matrix := ThrusterActionMatrix.load_checked_in(MATRIX_PATH)
    assert_true(matrix != null, "checked-in fighter thruster matrix must load")
    if matrix == null:
        return

    var forward := FlightCommand.new()
    forward.translation = Vector3.FORWARD
    var forward_output := matrix.intensities_for(forward)
    assert_true(
        is_equal_approx(float(forward_output.get(&"Main/MainLeft", 0.0)), 1.0),
        "forward thrust must activate the left main plume"
    )
    assert_true(
        is_equal_approx(float(forward_output.get(&"Main/MainRight", 0.0)), 1.0),
        "forward thrust must activate the right main plume"
    )
    assert_equal(
        forward_output.size(),
        2,
        "forward thrust must use exactly the symmetric main pair"
    )

    var reverse := FlightCommand.new()
    reverse.translation = Vector3.BACK
    var reverse_output := matrix.intensities_for(reverse)
    assert_true(
        is_equal_approx(float(reverse_output.get(&"Retro/RetroLeft", 0.0)), 1.0),
        "reverse thrust must activate the left retro plume"
    )
    assert_true(
        is_equal_approx(float(reverse_output.get(&"Retro/RetroRight", 0.0)), 1.0),
        "reverse thrust must activate the right retro plume"
    )

    var idle := FlightCommand.new()
    assert_true(
        matrix.intensities_for(idle).is_empty(),
        "zero pilot command must produce no direct thruster output"
    )

    for action: int in range(ThrusterAction.action_count()):
        assert_true(
            not matrix.weights_for(action as ThrusterAction.Value).is_empty(),
            "every pilot action must have a checked-in thruster mapping"
        )
