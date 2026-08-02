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

func _physical_key_for_action(action: StringName) -> Key:
    for event: InputEvent in InputMap.action_get_events(action):
        var key_event := event as InputEventKey
        if key_event != null:
            return key_event.physical_keycode
    return KEY_NONE
