extends "res://tests/support/test_case.gd"

const REQUIRED_ACTIONS: Array[StringName] = [
    &"thrust_forward",
    &"thrust_reverse",
    &"strafe_left",
    &"strafe_right",
    &"strafe_up",
    &"strafe_down",
    &"pitch_up",
    &"pitch_down",
    &"yaw_left",
    &"yaw_right",
    &"roll_left",
    &"roll_right",
    &"boost",
    &"fire_primary",
    &"toggle_flight_mode",
    &"toggle_mouse_capture",
    &"reset_flight_room",
    &"camera_cycle",
]

func run() -> void:
    for action: StringName in REQUIRED_ACTIONS:
        assert_true(
            InputMap.has_action(action),
            "required input action missing: %s" % action
        )

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
    assert_equal(
        _physical_key_for_action(&"fire_primary"),
        KEY_V,
        "physical V must trigger the logical primary fire action"
    )

    var c_owners := 0
    var v_owners := 0
    for action: StringName in InputMap.get_actions():
        var physical_key := _physical_key_for_action(action)
        if physical_key == KEY_C:
            c_owners += 1
        if physical_key == KEY_V:
            v_owners += 1
    assert_equal(
        c_owners,
        1,
        "physical C must belong only to camera_cycle"
    )
    assert_equal(
        v_owners,
        1,
        "physical V must belong only to fire_primary"
    )

func _physical_key_for_action(action: StringName) -> int:
    for event: InputEvent in InputMap.action_get_events(action):
        var key_event := event as InputEventKey
        if key_event != null:
            return int(key_event.physical_keycode)
    return int(KEY_NONE)
