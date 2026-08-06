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

    assert_equal(
        FlightAuthority.translation_force(Vector3.FORWARD, 0.0, tuning),
        Vector3(0.0, 0.0, -100.0),
        "forward command uses exact forward authority"
    )
    assert_equal(
        FlightAuthority.translation_force(Vector3.BACK, 0.0, tuning),
        Vector3(0.0, 0.0, 40.0),
        "reverse command uses exact reverse authority"
    )
    assert_equal(
        FlightAuthority.translation_force(Vector3.RIGHT, 0.0, tuning),
        Vector3(50.0, 0.0, 0.0),
        "lateral command uses exact strafe authority"
    )
    assert_equal(
        FlightAuthority.rotation_torque(Vector3.ONE, tuning),
        Vector3(10.0, 20.0, 30.0),
        "rotation axes retain independent full authority"
    )

    var diagonal := FlightAuthority.combine_translation(
        Vector3.FORWARD,
        Vector3.RIGHT + Vector3.UP
    )
    assert_true(
        is_equal_approx(diagonal.length(), 1.0),
        "combined pilot and automatic translation normalizes to one"
    )
    assert_equal(
        FlightAuthority.combine_rotation(
            Vector3(0.8, 0.8, 0.8),
            Vector3(0.8, -0.8, 0.8)
        ),
        Vector3(1.0, 0.0, 1.0),
        "combined rotation clamps independently per axis"
    )

    var boosted_forward := FlightAuthority.translation_force(
        Vector3.FORWARD,
        1.0,
        tuning
    )
    assert_equal(
        boosted_forward,
        Vector3(0.0, 0.0, -180.0),
        "effective boost scales authority exactly like direct control"
    )

    for command: Vector3 in [
        Vector3.FORWARD,
        Vector3.BACK,
        Vector3.RIGHT,
        Vector3.UP,
        Vector3(0.3, -0.4, -0.5),
    ]:
        var legal := FlightAuthority.sanitize_translation(command)
        var force := FlightAuthority.translation_force(legal, 0.0, tuning)
        assert_true(
            FlightAuthority.translation_command_for_force(
                force,
                0.0,
                tuning
            ).is_equal_approx(legal),
            "legal force must invert to its direction-correct player command"
        )

    var torque_command := Vector3(-0.4, 0.6, -0.8)
    var torque := FlightAuthority.rotation_torque(torque_command, tuning)
    assert_true(
        FlightAuthority.rotation_command_for_torque(
            torque,
            tuning
        ).is_equal_approx(torque_command),
        "legal torque must invert to its player-equivalent command"
    )

    assert_equal(
        FlightAuthority.sanitize_translation(Vector3(NAN, 0.0, 0.0)),
        Vector3.ZERO,
        "non-finite translation fails closed"
    )
    assert_equal(
        FlightAuthority.sanitize_rotation(Vector3(0.0, INF, 0.0)),
        Vector3.ZERO,
        "non-finite rotation fails closed"
    )
    assert_true(
        is_equal_approx(
            FlightAssistanceSource.visual_cap_for(
                FlightAssistanceSource.Value.LEGACY_ASSISTED
            ),
            0.35
        ),
        "legacy Assisted retains its visual cap"
    )
    assert_true(
        is_equal_approx(
            FlightAssistanceSource.visual_cap_for(
                FlightAssistanceSource.Value.SMART_STABILIZE
            ),
            1.0
        ),
        "Smart Stabilize may show full legal output"
    )
