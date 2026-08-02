extends "res://tests/support/test_case.gd"

func run() -> void:
    _test_zero_wrench()
    _test_forward_and_reverse_selection()
    _test_lateral_selection()
    _test_pure_roll_torque_pair()
    _test_combined_request_is_bounded_and_deterministic()

func _test_zero_wrench() -> void:
    var sockets := _basic_sockets()
    var result := ShipThrusterAllocator.solve(
        sockets,
        Vector3.ZERO,
        Vector3.ZERO,
        100.0,
        100.0
    )
    assert_equal(result.size(), sockets.size(), "zero-wrench result size")
    for intensity: float in result:
        assert_true(is_zero_approx(intensity), "zero wrench keeps every thruster idle")

func _test_forward_and_reverse_selection() -> void:
    var sockets := _basic_sockets()
    var forward := ShipThrusterAllocator.solve(
        sockets,
        Vector3(0.0, 0.0, -100.0),
        Vector3.ZERO,
        100.0,
        100.0
    )
    assert_true(forward[0] > 0.25, "forward request activates main left")
    assert_true(forward[1] > 0.25, "forward request activates main right")
    assert_true(forward[2] < 0.01, "forward request leaves retro left idle")
    assert_true(forward[3] < 0.01, "forward request leaves retro right idle")

    var reverse := ShipThrusterAllocator.solve(
        sockets,
        Vector3(0.0, 0.0, 60.0),
        Vector3.ZERO,
        100.0,
        100.0
    )
    assert_true(reverse[2] > 0.15, "reverse request activates retro left")
    assert_true(reverse[3] > 0.15, "reverse request activates retro right")
    assert_true(reverse[0] < 0.01, "reverse request leaves main left idle")
    assert_true(reverse[1] < 0.01, "reverse request leaves main right idle")

func _test_lateral_selection() -> void:
    var sockets := _basic_sockets()
    var right := ShipThrusterAllocator.solve(
        sockets,
        Vector3(40.0, 0.0, 0.0),
        Vector3.ZERO,
        100.0,
        100.0
    )
    assert_true(right[4] > 0.1, "right translation activates right-force maneuver jet")
    assert_true(right[5] < 0.01, "right translation leaves left-force jet idle")

func _test_pure_roll_torque_pair() -> void:
    var sockets: Array[Dictionary] = [
        _socket(Vector3(-2.0, 0.0, 0.0), Vector3.DOWN, 0.25, &"maneuver"),
        _socket(Vector3(2.0, 0.0, 0.0), Vector3.UP, 0.25, &"maneuver"),
        _socket(Vector3(-2.0, 0.0, 0.0), Vector3.UP, 0.25, &"maneuver"),
        _socket(Vector3(2.0, 0.0, 0.0), Vector3.DOWN, 0.25, &"maneuver"),
    ]
    var result := ShipThrusterAllocator.solve(
        sockets,
        Vector3.ZERO,
        Vector3(0.0, 0.0, 100.0),
        100.0,
        100.0
    )
    assert_true(result[0] > 0.1, "positive roll uses left downward jet")
    assert_true(result[1] > 0.1, "positive roll uses right upward jet")
    assert_true(result[2] < 0.01, "opposing roll jet remains idle")
    assert_true(result[3] < 0.01, "opposing roll jet remains idle")

func _test_combined_request_is_bounded_and_deterministic() -> void:
    var sockets := _basic_sockets()
    var first := ShipThrusterAllocator.solve(
        sockets,
        Vector3(30.0, 15.0, -80.0),
        Vector3(20.0, -35.0, 10.0),
        100.0,
        100.0
    )
    var second := ShipThrusterAllocator.solve(
        sockets,
        Vector3(30.0, 15.0, -80.0),
        Vector3(20.0, -35.0, 10.0),
        100.0,
        100.0
    )
    assert_equal(first, second, "thruster allocation must be deterministic")
    for intensity: float in first:
        assert_true(is_finite(intensity), "thruster intensity must be finite")
        assert_true(intensity >= 0.0, "thruster intensity must not be negative")
        assert_true(intensity <= 1.0, "thruster intensity must not exceed one")

func _basic_sockets() -> Array[Dictionary]:
    return [
        _socket(Vector3(-1.0, 0.0, 5.0), Vector3.FORWARD, 0.55, &"main"),
        _socket(Vector3(1.0, 0.0, 5.0), Vector3.FORWARD, 0.55, &"main"),
        _socket(Vector3(-1.0, 0.0, -5.0), Vector3.BACK, 0.35, &"retro"),
        _socket(Vector3(1.0, 0.0, -5.0), Vector3.BACK, 0.35, &"retro"),
        _socket(Vector3(-2.0, 0.0, 0.0), Vector3.RIGHT, 0.22, &"maneuver"),
        _socket(Vector3(2.0, 0.0, 0.0), Vector3.LEFT, 0.22, &"maneuver"),
        _socket(Vector3(0.0, -1.0, 2.0), Vector3.UP, 0.22, &"maneuver"),
        _socket(Vector3(0.0, 1.0, -2.0), Vector3.DOWN, 0.22, &"maneuver"),
    ]

func _socket(
    position: Vector3,
    reaction_direction: Vector3,
    capacity: float,
    thruster_class: StringName
) -> Dictionary:
    return {
        "position": position,
        "reaction_direction": reaction_direction,
        "capacity": capacity,
        "class": thruster_class,
    }
