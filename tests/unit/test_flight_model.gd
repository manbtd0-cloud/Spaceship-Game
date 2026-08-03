extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.forward_force = 100.0
    tuning.reverse_force = 40.0
    tuning.strafe_force = 50.0
    tuning.pitch_torque = 10.0
    tuning.yaw_torque = 20.0
    tuning.roll_torque = 30.0
    tuning.boost_multiplier = 1.8
    tuning.normal_speed_soft_start = 120.0
    tuning.normal_speed_limit = 160.0
    tuning.boost_speed_soft_start = 180.0
    tuning.boost_speed_limit = 240.0
    tuning.assist_angular_damping = 3.0
    tuning.assist_steering_strength = 1.25
    tuning.assist_min_steering_speed = 8.0
    tuning.assist_max_steering_acceleration = 18.0

    var assisted := FlightCommand.new()
    assisted.mode = FlightMode.Value.ASSISTED
    assisted.translation = Vector3.FORWARD

    var assisted_output := FlightModel.compute(
        assisted,
        tuning,
        Vector3(10.0, -2.0, -30.0),
        Vector3(0.0, 2.0, 0.0)
    )
    assert_true(assisted_output.force_local.z < 0.0, "forward input must produce forward force")
    assert_true(assisted_output.force_local.x < 0.0, "assisted mode must steer lateral drift toward nose")
    assert_true(assisted_output.force_local.y > 0.0, "assisted mode must steer vertical drift toward nose")
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
    reverse.translation = Vector3.BACK
    var reverse_output := FlightModel.compute(reverse, tuning, Vector3.ZERO, Vector3.ZERO)
    assert_true(is_equal_approx(reverse_output.force_local.z, 40.0), "reverse input must use reverse thrust")

    var boosted := FlightCommand.new()
    boosted.mode = FlightMode.Value.MANUAL
    boosted.translation = Vector3.FORWARD
    boosted.boost = 1.0
    var boosted_output := FlightModel.compute(boosted, tuning, Vector3.ZERO, Vector3.ZERO)
    assert_true(is_equal_approx(boosted_output.force_local.z, -180.0), "full boost must scale forward thrust")

    var all_axis_boost := FlightCommand.new()
    all_axis_boost.mode = FlightMode.Value.MANUAL
    all_axis_boost.translation = Vector3(1.0, 1.0, -1.0).normalized()
    all_axis_boost.rotation = Vector3.ONE
    all_axis_boost.boost = 1.0
    var all_axis_output := FlightModel.compute(
        all_axis_boost, tuning, Vector3.ZERO, Vector3.ZERO
    )
    assert_true(all_axis_output.force_local.x > tuning.strafe_force, "boost scales lateral thrust")
    assert_true(all_axis_output.force_local.y > tuning.strafe_force, "boost scales vertical thrust")
    assert_equal(all_axis_output.torque_local, Vector3(10.0, 20.0, 30.0), "axis torques")

    var normal_limit_output := FlightModel.compute(
        assisted,
        tuning,
        Vector3(0.0, 0.0, -160.0),
        Vector3.ZERO
    )
    assert_true(
        is_equal_approx(normal_limit_output.force_local.z, 0.0),
        "normal increasing thrust stops at 160 m/s"
    )

    var boosted_at_normal_limit := FlightCommand.new()
    boosted_at_normal_limit.mode = FlightMode.Value.MANUAL
    boosted_at_normal_limit.translation = Vector3.FORWARD
    boosted_at_normal_limit.boost = 1.0
    var boosted_at_normal_output := FlightModel.compute(
        boosted_at_normal_limit,
        tuning,
        Vector3(0.0, 0.0, -160.0),
        Vector3.ZERO
    )
    assert_true(boosted_at_normal_output.force_local.z < 0.0, "boost remains available at 160 m/s")

    var braking_above_limit := FlightCommand.new()
    braking_above_limit.mode = FlightMode.Value.MANUAL
    braking_above_limit.translation = Vector3.BACK
    var braking_output := FlightModel.compute(
        braking_above_limit,
        tuning,
        Vector3(0.0, 0.0, -180.0),
        Vector3.ZERO
    )
    assert_true(braking_output.force_local.z > 0.0, "braking remains available above limit")

    var steering_command := FlightCommand.new()
    steering_command.mode = FlightMode.Value.ASSISTED
    steering_command.translation = Vector3.FORWARD
    var steering_output := FlightModel.compute(
        steering_command,
        tuning,
        Vector3(20.0, 0.0, -20.0),
        Vector3.ZERO,
        8500.0
    )
    assert_true(steering_output.force_local.x < 0.0, "assisted model bends drift toward nose")
    assert_true(
        absf(
            steering_output.assist_force_local.dot(
                Vector3(20.0, 0.0, -20.0).normalized()
            )
        ) <= 0.001,
        "assisted steering must not add or remove speed along velocity"
    )

    steering_command.mode = FlightMode.Value.MANUAL
    var inertial_output := FlightModel.compute(
        steering_command,
        tuning,
        Vector3(20.0, 0.0, -20.0),
        Vector3.ZERO,
        8500.0
    )
    assert_true(
        inertial_output.force_local.x >= -0.001,
        "manual model receives no nose-steering force"
    )

    var coasting_assisted := FlightCommand.new()
    coasting_assisted.mode = FlightMode.Value.ASSISTED
    var split := FlightModel.compute(
        coasting_assisted,
        tuning,
        Vector3(12.0, -3.0, -80.0),
        Vector3(0.2, -0.4, 0.1),
        8500.0
    )
    assert_equal(
        split.pilot_force_local,
        Vector3.ZERO,
        "coasting must produce zero pilot force"
    )
    assert_equal(
        split.pilot_torque_local,
        Vector3.ZERO,
        "coasting must produce zero pilot torque"
    )
    assert_equal(
        split.assist_force_local,
        Vector3.ZERO,
        "assisted coasting must produce zero translational assist force"
    )
    assert_true(
        split.assist_torque_local.length() > 0.0,
        "assisted angular damping must remain isolated"
    )
    assert_equal(
        split.force_local,
        split.pilot_force_local + split.assist_force_local,
        "total force must equal split contributions"
    )
    assert_equal(
        split.torque_local,
        split.pilot_torque_local + split.assist_torque_local,
        "total torque must preserve split contributions"
    )

    var yaw_only := FlightCommand.new()
    yaw_only.mode = FlightMode.Value.ASSISTED
    yaw_only.rotation.y = 0.5
    var with_auto_bank := FlightModel.compute(
        yaw_only,
        tuning,
        Vector3.ZERO,
        Vector3.ZERO,
        8500.0,
        Vector3(0.0, 0.0, -0.25)
    )
    assert_equal(
        with_auto_bank.pilot_torque_local,
        Vector3(0.0, 10.0, 0.0),
        "pilot yaw torque must remain isolated from auto-bank"
    )
    assert_equal(
        with_auto_bank.assist_torque_local,
        Vector3(0.0, 0.0, -7.5),
        "auto-bank must enter the assisted torque channel"
    )
    assert_equal(
        with_auto_bank.torque_local,
        Vector3(0.0, 10.0, -7.5),
        "total torque must preserve pilot plus auto-bank physics"
    )
