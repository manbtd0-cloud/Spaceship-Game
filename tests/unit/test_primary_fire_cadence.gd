extends "res://tests/support/test_case.gd"

func run() -> void:
    var cadence := PrimaryFireCadence.new()

    var first := cadence.advance(true, 0.0)
    assert_equal(
        first,
        [PrimaryFireCadence.MuzzleSide.LEFT],
        "first held frame must fire immediately from the left muzzle"
    )

    var early := cadence.advance(true, 0.10)
    assert_true(early.is_empty(), "no shot may fire before 1/7 second")

    var next := cadence.advance(true, 0.05)
    assert_equal(
        next,
        [PrimaryFireCadence.MuzzleSide.RIGHT],
        "second shot must alternate to the right muzzle"
    )

    var released := cadence.advance(false, 1.0)
    assert_true(released.is_empty(), "release must stop fire immediately")

    var resumed := cadence.advance(true, 0.0)
    assert_equal(
        resumed,
        [PrimaryFireCadence.MuzzleSide.LEFT],
        "a new trigger press must fire immediately while preserving alternation"
    )

    cadence.reset()
    assert_equal(
        cadence.advance(true, 0.0),
        [PrimaryFireCadence.MuzzleSide.LEFT],
        "reset must restore left-first order"
    )

    var catch_up := cadence.advance(true, 0.50)
    assert_equal(
        catch_up,
        [
            PrimaryFireCadence.MuzzleSide.RIGHT,
            PrimaryFireCadence.MuzzleSide.LEFT,
            PrimaryFireCadence.MuzzleSide.RIGHT,
        ],
        "a large held step must emit every due shot without dropping cadence"
    )

    cadence.reset()
    assert_true(
        cadence.advance(false, 10.0).is_empty(),
        "idle time while released must never accumulate queued shots"
    )
    assert_equal(
        cadence.advance(true, -1.0),
        [PrimaryFireCadence.MuzzleSide.LEFT],
        "negative delta must be clamped while retaining immediate first fire"
    )
