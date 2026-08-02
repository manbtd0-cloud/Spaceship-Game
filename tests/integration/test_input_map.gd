extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(
        _physical_key_for_action(&"pitch_up"),
        KEY_DOWN,
        "Down Arrow must pitch the ship upward"
    )
    assert_equal(
        _physical_key_for_action(&"pitch_down"),
        KEY_UP,
        "Up Arrow must pitch the ship downward"
    )
    assert_equal(
        _physical_key_for_action(&"camera_cycle"),
        KEY_C,
        "C must cycle chase-camera presets"
    )

    var c_owners := 0
    for action: StringName in InputMap.get_actions():
        if _physical_key_for_action(action) == KEY_C:
            c_owners += 1
    assert_equal(
        c_owners,
        1,
        "physical C must belong only to camera_cycle"
    )

func _physical_key_for_action(action: StringName) -> int:
    for event: InputEvent in InputMap.action_get_events(action):
        var key_event := event as InputEventKey
        if key_event != null:
            return int(key_event.physical_keycode)
    return int(KEY_NONE)
