extends "res://tests/support/test_case.gd"

func run() -> void:
    var offset := 0.0
    var rate := 0.0
    var state: CoordinatedTurnState
    for _step: int in range(180):
        state = CoordinatedTurnState.advance(
            offset,
            rate,
            1.0,
            0.0,
            1.0 / 60.0,
            22.0,
            5.0
        )
        offset = state.bank_offset
        rate = state.bank_rate
    assert_true(offset < 0.0, "left yaw must generate left bank")
    assert_true(absf(rad_to_deg(offset)) <= 22.01, "bank must stay bounded")

    var overridden := CoordinatedTurnState.advance(
        offset,
        rate,
        1.0,
        -1.0,
        1.0 / 60.0,
        22.0,
        5.0
    )
    assert_true(
        is_equal_approx(overridden.bank_offset, 0.0),
        "manual roll resets generated offset"
    )
    assert_true(
        is_equal_approx(overridden.roll_command, 0.0),
        "manual roll suppresses auto torque"
    )

    var returning := CoordinatedTurnState.advance(
        deg_to_rad(-10.0),
        0.0,
        0.0,
        0.0,
        1.0 / 60.0,
        22.0,
        5.0
    )
    assert_true(
        returning.roll_command > 0.0,
        "released yaw must return generated bank toward zero"
    )
