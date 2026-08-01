extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.forward_force = 100.0
    tuning.reverse_force = 40.0
    tuning.strafe_force = 50.0
    tuning.rotation_torque = 25.0
    tuning.boost_multiplier = 1.8
    tuning.assist_linear_damping = 4.0
    tuning.assist_angular_damping = 3.0

    var assisted := FlightCommand.new()
    assisted.mode = FlightMode.Value.ASSISTED
    assisted.translation = Vector3(0.0, 0.0, -1.0)

    var assisted_output := FlightModel.compute(
        assisted,
        tuning,
        Vector3(10.0, -2.0, 30.0),
        Vector3(0.0, 2.0, 0.0)
    )
    assert_true(assisted_output.force_local.z < 0.0, "forward input must produce forward force")
    assert_true(assisted_output.force_local.x < 0.0, "assisted mode must oppose lateral drift")
    assert_true(assisted_output.force_local.y > 0.0, "assisted mode must oppose vertical drift")
    assert_true(assisted_output.torque_local.y < 0.0, "assisted mode must oppose angular drift")

    var manual := FlightCommand.new()
    manual.mode = FlightMode.Value.MANUAL
    manual.translation = Vector3.ZERO

    var manual_output := FlightModel.compute(
        manual,
        tuning,
        Vector3(10.0, -2.0, 30.0),
        Vector3(0.0, 2.0, 0.0)
    )
    assert_equal(manual_output.force_local, Vector3.ZERO, "manual mode must preserve linear momentum")
    assert_equal(manual_output.torque_local, Vector3.ZERO, "manual mode must preserve angular momentum")

    var reverse := FlightCommand.new()
    reverse.mode = FlightMode.Value.MANUAL
    reverse.translation = Vector3(0.0, 0.0, 1.0)
    var reverse_output := FlightModel.compute(reverse, tuning, Vector3.ZERO, Vector3.ZERO)
    assert_true(is_equal_approx(reverse_output.force_local.z, 40.0), "reverse input must use reverse thrust")

    var boosted := FlightCommand.new()
    boosted.mode = FlightMode.Value.MANUAL
    boosted.translation = Vector3(0.0, 0.0, -1.0)
    boosted.boost = 1.0
    var boosted_output := FlightModel.compute(boosted, tuning, Vector3.ZERO, Vector3.ZERO)
    assert_true(is_equal_approx(boosted_output.force_local.z, -180.0), "full boost must scale forward thrust")
