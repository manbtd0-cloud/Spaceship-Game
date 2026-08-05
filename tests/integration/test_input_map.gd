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
    &"reset_flight_room",
    &"smart_stabilize",
    &"camera_cycle",
    &"toggle_pause",
    &"look_rear",
    &"look_right",
    &"look_left",
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
        "C must cycle chase-camera distances"
    )
    assert_equal(
        _physical_key_for_action(&"fire_primary"),
        KEY_V,
        "physical V must trigger the logical primary fire action"
    )
    assert_true(
        _action_has_physical_key(&"smart_stabilize", KEY_X),
        "physical X must hold Smart Stabilize"
    )
    assert_true(
        _action_has_physical_key(&"toggle_pause", KEY_ESCAPE),
        "Escape must own pause"
    )
    assert_true(
        _action_has_physical_key(&"look_rear", KEY_B),
        "B must hold rear view"
    )
    assert_true(
        _action_has_physical_key(&"look_right", KEY_PAGEUP),
        "PageUp must hold right view"
    )
    assert_true(
        _action_has_physical_key(&"look_left", KEY_PAGEDOWN),
        "PageDown must hold left view"
    )
    assert_true(
        not _action_has_physical_key(&"toggle_mouse_capture", KEY_ESCAPE),
        "Escape must not remain a mouse-capture toggle"
    )

    assert_true(
        &"toggle_mouse_capture" not in PlayerInputSource.REQUIRED_ACTIONS,
        "ship input must stop owning the obsolete mouse-capture action"
    )
    assert_true(
        &"toggle_pause" not in PlayerInputSource.REQUIRED_ACTIONS,
        "pause input must be owned by the pause controller"
    )
    assert_true(
        &"smart_stabilize" in PlayerInputSource.REQUIRED_ACTIONS,
        "PlayerInputSource must own Smart Stabilize"
    )
    assert_true(
        &"look_rear" not in PlayerInputSource.REQUIRED_ACTIONS
        and &"look_right" not in PlayerInputSource.REQUIRED_ACTIONS
        and &"look_left" not in PlayerInputSource.REQUIRED_ACTIONS,
        "temporary camera actions must be owned by the camera rig"
    )

    var c_owners := 0
    var v_owners := 0
    var x_owners := 0
    var escape_owners := 0
    var b_owners := 0
    var page_up_owners := 0
    var page_down_owners := 0
    for action: StringName in InputMap.get_actions():
        if _action_has_physical_key(action, KEY_C):
            c_owners += 1
        if _action_has_physical_key(action, KEY_V):
            v_owners += 1
        if _action_has_physical_key(action, KEY_X):
            x_owners += 1
        if _action_has_physical_key(action, KEY_ESCAPE):
            escape_owners += 1
        if _action_has_physical_key(action, KEY_B):
            b_owners += 1
        if _action_has_physical_key(action, KEY_PAGEUP):
            page_up_owners += 1
        if _action_has_physical_key(action, KEY_PAGEDOWN):
            page_down_owners += 1
    assert_equal(c_owners, 1, "physical C must belong only to camera_cycle")
    assert_equal(v_owners, 1, "physical V must belong only to fire_primary")
    assert_equal(x_owners, 1, "physical X has one owner")
    assert_equal(escape_owners, 1, "Escape must belong only to toggle_pause")
    assert_equal(b_owners, 1, "physical B must belong only to look_rear")
    assert_equal(page_up_owners, 1, "PageUp must belong only to look_right")
    assert_equal(page_down_owners, 1, "PageDown must belong only to look_left")

    var fixture := Node.new()
    var source := PlayerInputSource.new()
    fixture.add_child(source)
    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree != null:
        tree.root.add_child(fixture)
        Input.action_press(&"smart_stabilize")
        assert_true(source.is_smart_stabilize_held(), "held state exposed")
        Input.action_release(&"smart_stabilize")
        assert_true(not source.is_smart_stabilize_held(), "release clears state")
        fixture.get_parent().remove_child(fixture)
    fixture.free()

func _physical_key_for_action(action: StringName) -> int:
    for event: InputEvent in InputMap.action_get_events(action):
        var key_event := event as InputEventKey
        if key_event != null:
            return int(key_event.physical_keycode)
    return int(KEY_NONE)

func _action_has_physical_key(action: StringName, key: Key) -> bool:
    if not InputMap.has_action(action):
        return false
    for event: InputEvent in InputMap.action_get_events(action):
        var key_event := event as InputEventKey
        if key_event != null and key_event.physical_keycode == key:
            return true
    return false
