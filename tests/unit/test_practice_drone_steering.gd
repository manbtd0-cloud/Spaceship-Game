extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := PracticeDroneTuning.new()
    var intent := PracticeDroneIntent.new()

    PracticeDroneSteering.compute_into(
        intent,
        Vector3(0.0, 0.0, 260.0),
        Vector3.ZERO,
        Vector3.FORWARD,
        Vector3.ZERO,
        0.0,
        tuning
    )
    assert_true(intent.acceleration_world.z > 0.0, "far drone approaches")
    assert_true(
        intent.acceleration_world.length()
        <= tuning.maximum_acceleration + 0.001,
        "approach acceleration remains bounded"
    )

    PracticeDroneSteering.compute_into(
        intent,
        Vector3(0.0, 0.0, 50.0),
        Vector3.ZERO,
        Vector3.FORWARD,
        Vector3.ZERO,
        1.0,
        tuning
    )
    assert_true(intent.acceleration_world.z < 0.0, "close drone retreats")

    PracticeDroneSteering.compute_into(
        intent,
        Vector3(140.0, 0.0, 0.0),
        Vector3.ZERO,
        Vector3.FORWARD,
        Vector3.ZERO,
        2.0,
        tuning
    )
    assert_true(
        absf(intent.acceleration_world.z) > 0.0,
        "drone orbits inside distance band"
    )
    assert_true(
        intent.torque_world.length()
        <= tuning.maximum_turn_torque + 0.001,
        "turn torque remains bounded"
    )

    PracticeDroneSteering.compute_into(
        intent,
        Vector3(NAN, 0.0, 0.0),
        Vector3.ZERO,
        Vector3.FORWARD,
        Vector3.ZERO,
        0.0,
        tuning
    )
    assert_equal(
        intent.acceleration_world,
        Vector3.ZERO,
        "non-finite input clears acceleration"
    )
    assert_equal(
        intent.torque_world,
        Vector3.ZERO,
        "non-finite input clears torque"
    )
