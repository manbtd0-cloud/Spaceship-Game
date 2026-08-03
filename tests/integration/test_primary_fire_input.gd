extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        InputMap.has_action(&"fire_primary"),
        "one logical fire_primary action must exist"
    )

    var events := InputMap.action_get_events(&"fire_primary")
    assert_equal(
        events.size(),
        2,
        "fire_primary must have exactly mouse-left and physical-V bindings"
    )

    var mouse_left_count := 0
    var physical_v_count := 0
    for event: InputEvent in events:
        var mouse_event := event as InputEventMouseButton
        if mouse_event != null:
            if mouse_event.button_index == MOUSE_BUTTON_LEFT:
                mouse_left_count += 1
            continue

        var key_event := event as InputEventKey
        if key_event != null and key_event.physical_keycode == KEY_V:
            physical_v_count += 1

    assert_equal(
        mouse_left_count,
        1,
        "fire_primary must contain exactly one left mouse binding"
    )
    assert_equal(
        physical_v_count,
        1,
        "fire_primary must contain exactly one physical V binding"
    )

    var fixture := Node.new()
    var input_source := PlayerInputSource.new()
    fixture.add_child(input_source)
    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree == null:
        fixture.free()
        return
    tree.root.add_child(fixture)

    Input.action_press(&"fire_primary")
    assert_true(
        input_source.is_primary_fire_held(),
        "PlayerInputSource must expose the logical held state"
    )
    Input.action_release(&"fire_primary")
    assert_true(
        not input_source.is_primary_fire_held(),
        "PlayerInputSource must clear held state immediately on release"
    )

    fixture.get_parent().remove_child(fixture)
    fixture.free()
