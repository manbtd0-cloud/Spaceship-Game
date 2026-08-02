extends "res://tests/support/test_case.gd"

func run() -> void:
    var heat := 0.0
    var locked := false
    var elapsed := 0.0
    while not locked and elapsed < 13.0:
        var state := BoostThermalState.advance(
            heat,
            locked,
            1.0,
            1.0,
            1.0 / 60.0,
            1.0 / 12.0,
            1.0 / 15.0,
            0.60
        )
        heat = state.heat
        locked = state.locked_out
        elapsed += 1.0 / 60.0
    assert_true(elapsed >= 11.9 and elapsed <= 12.1, "twelve-second endurance")
    assert_true(locked, "maximum heat must lock boost")

    var recovery_elapsed := 0.0
    while locked and recovery_elapsed < 7.0:
        var state := BoostThermalState.advance(
            heat,
            locked,
            0.0,
            0.0,
            1.0 / 60.0,
            1.0 / 12.0,
            1.0 / 15.0,
            0.60
        )
        heat = state.heat
        locked = state.locked_out
        recovery_elapsed += 1.0 / 60.0
    assert_true(
        recovery_elapsed >= 5.9 and recovery_elapsed <= 6.1,
        "six-second lockout recovery"
    )

    var full_cooling_elapsed := recovery_elapsed
    while heat > 0.0 and full_cooling_elapsed < 16.0:
        var state := BoostThermalState.advance(
            heat,
            locked,
            0.0,
            0.0,
            1.0 / 60.0,
            1.0 / 12.0,
            1.0 / 15.0,
            0.60
        )
        heat = state.heat
        locked = state.locked_out
        full_cooling_elapsed += 1.0 / 60.0
    assert_true(
        full_cooling_elapsed >= 14.9 and full_cooling_elapsed <= 15.1,
        "fifteen-second full cooling"
    )
    assert_true(is_equal_approx(heat, 0.0), "heat must fully cool")

    var idle := BoostThermalState.advance(
        0.5,
        false,
        1.0,
        0.0,
        1.0,
        1.0 / 12.0,
        1.0 / 15.0,
        0.60
    )
    assert_true(idle.heat < 0.5, "boost without translation must cool")

    var x_state := BoostThermalState.advance(
        0.0,
        false,
        1.0,
        1.0,
        1.0,
        1.0 / 12.0,
        1.0 / 15.0,
        0.60
    )
    var diagonal_state := BoostThermalState.advance(
        0.0,
        false,
        1.0,
        0.25,
        1.0,
        1.0 / 12.0,
        1.0 / 15.0,
        0.60
    )
    assert_true(
        is_equal_approx(x_state.heat, diagonal_state.heat),
        "translation magnitude must not weight heat rate"
    )
