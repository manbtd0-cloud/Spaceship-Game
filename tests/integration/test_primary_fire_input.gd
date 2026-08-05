extends "res://tests/support/test_case.gd"

const FLIGHT_ROOM_SCENE_PATH := "res://scenes/flight_room/flight_room.tscn"

func run() -> void:
    _test_input_contract()
    _test_live_flight_room_firing()

func _test_input_contract() -> void:
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

func _test_live_flight_room_firing() -> void:
    var packed := load(FLIGHT_ROOM_SCENE_PATH) as PackedScene
    assert_true(packed != null, "production flight room must load")
    if packed == null:
        return

    var room := packed.instantiate() as Node3D
    assert_true(room != null, "production flight room must instantiate")
    if room == null:
        return

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree == null:
        room.free()
        return
    tree.root.add_child(room)

    var fire := room.get_node_or_null(
        "PlayerInterceptor/PrimaryFireController"
    ) as PrimaryFireController
    var pool := room.get_node_or_null(
        "PulseProjectilePool"
    ) as PulseProjectilePool
    var room_controller := room.get_node_or_null(
        "FlightRoomController"
    ) as FlightRoomController

    assert_true(
        fire != null,
        "production flight-room player must own PrimaryFireController"
    )
    assert_true(
        pool != null,
        "production flight room must own PulseProjectilePool"
    )
    assert_true(
        room_controller != null,
        "production flight room must retain FlightRoomController"
    )

    if fire != null and pool != null:
        assert_true(
            fire.is_firing_enabled(),
            "production primary fire must initialize enabled"
        )
        assert_equal(
            pool.get_projectile_count(),
            PulseProjectilePool.PREWARM_COUNT,
            "production pool must prewarm the full projectile budget"
        )

        Input.action_press(&"fire_primary")
        fire._physics_process(0.0)
        Input.action_release(&"fire_primary")

        assert_equal(
            pool.get_active_count(),
            1,
            "holding logical primary fire must spawn a visible projectile"
        )
        var active := pool.get_active_projectiles()
        assert_equal(active.size(), 1, "exactly one first-frame shot expected")
        if active.size() == 1:
            assert_true(
                active[0].global_position.is_finite(),
                "spawned production projectile must have a finite position"
            )

        if room_controller != null:
            room_controller.reset_player()
            assert_equal(
                pool.get_active_count(),
                0,
                "flight-room reset must clear active projectiles"
            )

    Input.action_release(&"fire_primary")
    if tree.paused:
        tree.paused = false
    room.get_parent().remove_child(room)
    room.free()
