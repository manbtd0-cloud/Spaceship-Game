extends "res://tests/support/test_case.gd"

const PAUSE_MENU_SCENE_PATH := "res://scenes/ui/pause_menu.tscn"
const FLIGHT_ROOM_SCENE_PATH := "res://scenes/flight_room/flight_room.tscn"
const FLIGHT_ROOM_CONTROLLER_PATH := "res://src/flight_room/flight_room_controller.gd"

class RecordingFlightRoomController:
    extends FlightRoomController

    var reset_calls := 0

    func _ready() -> void:
        pass

    func reset_player() -> void:
        if get_tree() != null and get_tree().paused:
            get_tree().paused = false
        reset_calls += 1

class QuietPauseMenu:
    extends PauseMenu

    var errors: Array[String] = []

    func _report_error(message: String) -> void:
        errors.append(message)

func run() -> void:
    _test_pause_menu_runtime_contract()
    _test_missing_dependency_safety()
    _test_flight_room_scene_contract()

func _test_pause_menu_runtime_contract() -> void:
    var settings_path := "user://test_pause_menu_%d.cfg" % Time.get_ticks_usec()
    _remove_settings_file(settings_path)

    var packed := load(PAUSE_MENU_SCENE_PATH) as PackedScene
    assert_true(packed != null, "pause menu scene must load")
    if packed == null:
        return

    var fixture := Node.new()
    fixture.name = "PauseMenuFixture"

    var settings := PlayerSettingsStore.new()
    settings.name = "Settings"
    settings.load_from_path(settings_path)

    var input_source := PlayerInputSource.new()
    input_source.name = "InputSource"

    var room_controller := RecordingFlightRoomController.new()
    room_controller.name = "RoomController"

    var pause_menu := packed.instantiate() as PauseMenu
    assert_true(pause_menu != null, "pause menu scene must use PauseMenu")
    if pause_menu == null:
        settings.free()
        input_source.free()
        room_controller.free()
        fixture.free()
        return

    pause_menu.settings_service_path = NodePath("../Settings")
    pause_menu.input_source_path = NodePath("../InputSource")
    pause_menu.room_controller_path = NodePath("../RoomController")

    fixture.add_child(settings)
    fixture.add_child(input_source)
    fixture.add_child(room_controller)
    fixture.add_child(pause_menu)

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree == null:
        fixture.free()
        _remove_settings_file(settings_path)
        return
    tree.root.add_child(fixture)
    input_source.set_mouse_captured(true)

    assert_true(pause_menu.is_initialized(), "pause menu must initialize")
    assert_equal(
        pause_menu.process_mode,
        Node.PROCESS_MODE_ALWAYS,
        "pause menu must continue processing while the tree is paused"
    )
    assert_true(not pause_menu.visible, "pause menu starts hidden")
    assert_true(not pause_menu.is_open(), "pause menu starts closed")

    var resume_button := pause_menu.get_node(
        "Backdrop/Center/Panel/Margin/Layout/ResumeButton"
    ) as Button
    var restart_button := pause_menu.get_node(
        "Backdrop/Center/Panel/Margin/Layout/RestartButton"
    ) as Button
    var behavior_option := pause_menu.get_node(
        "Backdrop/Center/Panel/Margin/Layout/CameraBehaviorOption"
    ) as OptionButton
    var distance_option := pause_menu.get_node(
        "Backdrop/Center/Panel/Margin/Layout/CameraDistanceOption"
    ) as OptionButton
    var mode_option := pause_menu.get_node(
        "Backdrop/Center/Panel/Margin/Layout/FlightModeOption"
    ) as OptionButton

    assert_equal(mode_option.item_count, 3, "exactly three modes")
    assert_equal(mode_option.get_item_text(0), "Assisted")
    assert_equal(mode_option.get_item_id(0), FlightMode.Value.ASSISTED)
    assert_equal(mode_option.get_item_text(1), "AI Assisted")
    assert_equal(mode_option.get_item_id(1), FlightMode.Value.AI_ASSISTED)
    assert_equal(mode_option.get_item_text(2), "Inertial")
    assert_equal(mode_option.get_item_id(2), FlightMode.Value.MANUAL)

    assert_equal(
        resume_button.pressed.get_connections().size(),
        1,
        "Resume must have one callback"
    )
    assert_equal(
        restart_button.pressed.get_connections().size(),
        1,
        "Restart must have one callback"
    )
    assert_equal(
        behavior_option.item_selected.get_connections().size(),
        1,
        "camera behavior must have one callback"
    )
    assert_equal(
        distance_option.item_selected.get_connections().size(),
        1,
        "camera distance must have one callback"
    )
    assert_equal(
        mode_option.item_selected.get_connections().size(),
        1,
        "flight mode must have one callback"
    )

    assert_true(pause_menu.open_menu(), "open_menu must open once")
    assert_true(tree.paused, "opening the pause menu must pause gameplay")
    assert_true(pause_menu.visible, "opening the pause menu must show it")
    assert_true(pause_menu.is_open(), "open state must be reported")
    assert_true(
        not input_source.is_mouse_captured(),
        "opening the pause menu must release the mouse"
    )
    assert_true(
        not pause_menu.open_menu(),
        "opening an already-open menu must be a no-op"
    )

    assert_true(
        _emit_option_id(behavior_option, CameraBehavior.Value.LOCKED),
        "Locked behavior option must exist"
    )
    assert_true(
        _emit_option_id(distance_option, CameraDistance.Value.FAR),
        "Far distance option must exist"
    )
    assert_true(
        _emit_option_id(mode_option, FlightMode.Value.AI_ASSISTED),
        "AI Assisted flight option must exist"
    )
    assert_equal(
        settings.get_camera_behavior(),
        CameraBehavior.Value.LOCKED,
        "pause menu must write camera behavior through settings"
    )
    assert_equal(
        settings.get_camera_distance(),
        CameraDistance.Value.FAR,
        "pause menu must write camera distance through settings"
    )
    assert_equal(
        settings.get_default_flight_mode(),
        FlightMode.Value.AI_ASSISTED,
        "pause menu must write AI flight mode through settings"
    )

    var reloaded_settings := PlayerSettingsStore.new()
    reloaded_settings.load_from_path(settings_path)
    assert_equal(
        reloaded_settings.get_default_flight_mode(),
        FlightMode.Value.AI_ASSISTED,
        "AI Assisted pause selection must persist"
    )
    reloaded_settings.free()

    assert_true(pause_menu.resume_game(), "resume must close an open menu")
    assert_true(not tree.paused, "resume must unpause gameplay")
    assert_true(not pause_menu.visible, "resume must hide the menu")
    assert_true(not pause_menu.is_open(), "resume must clear open state")
    assert_true(
        input_source.is_mouse_captured(),
        "resume must restore the previous mouse-capture state"
    )
    assert_true(
        not pause_menu.resume_game(),
        "resuming an already-closed menu must be a no-op"
    )

    assert_true(pause_menu.open_menu(), "menu must reopen cleanly")
    assert_true(
        pause_menu.restart_flight_room(),
        "restart must execute from the pause menu"
    )
    assert_equal(room_controller.reset_calls, 1, "restart calls the room once")
    assert_true(not tree.paused, "restart must leave the tree unpaused")
    assert_true(not pause_menu.is_open(), "restart must close the menu")
    assert_true(
        input_source.is_mouse_captured(),
        "restart must restore mouse capture"
    )

    assert_true(
        pause_menu.initialize(),
        "repeated initialization must be a successful no-op"
    )
    assert_equal(
        resume_button.pressed.get_connections().size(),
        1,
        "repeated initialization must not duplicate callbacks"
    )

    assert_true(pause_menu.open_menu(), "menu must open for cleanup test")
    fixture.remove_child(pause_menu)
    assert_true(not tree.paused, "removing an open menu must unpause the tree")
    assert_equal(
        resume_button.pressed.get_connections().size(),
        0,
        "menu exit must disconnect control callbacks"
    )
    pause_menu.free()

    fixture.get_parent().remove_child(fixture)
    fixture.free()
    _remove_settings_file(settings_path)

func _test_missing_dependency_safety() -> void:
    var fixture := Node.new()
    fixture.name = "MissingPauseDependenciesFixture"

    var pause_menu := QuietPauseMenu.new()
    pause_menu.name = "PauseMenu"
    pause_menu.settings_service_path = NodePath("../MissingSettings")
    pause_menu.input_source_path = NodePath("../MissingInput")
    pause_menu.room_controller_path = NodePath("../MissingController")
    pause_menu.resume_button_path = NodePath("MissingResume")
    pause_menu.camera_behavior_option_path = NodePath("MissingBehavior")
    pause_menu.camera_distance_option_path = NodePath("MissingDistance")
    pause_menu.flight_mode_option_path = NodePath("MissingMode")
    pause_menu.restart_button_path = NodePath("MissingRestart")
    pause_menu.quit_button_path = NodePath("MissingQuit")
    fixture.add_child(pause_menu)

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "failure test SceneTree must exist")
    if tree == null:
        fixture.free()
        return
    tree.paused = false
    tree.root.add_child(fixture)

    assert_true(
        not pause_menu.is_initialized(),
        "missing dependencies must disable the pause menu"
    )
    assert_true(not pause_menu.visible, "failure safety must hide the menu")
    assert_equal(
        pause_menu.errors.size(),
        1,
        "missing dependencies must produce one consolidated error"
    )

    tree.paused = true
    assert_true(
        not pause_menu.initialize(),
        "repeated initialization must remain safely rejected"
    )
    assert_true(not tree.paused, "failure safety must unpause the tree")
    assert_equal(
        pause_menu.errors.size(),
        1,
        "repeated failure must not duplicate error reports"
    )

    fixture.get_parent().remove_child(fixture)
    fixture.free()

func _test_flight_room_scene_contract() -> void:
    var packed := load(FLIGHT_ROOM_SCENE_PATH) as PackedScene
    assert_true(packed != null, "flight room must load for integration")
    if packed == null:
        return

    var room := packed.instantiate() as Node3D
    assert_true(room != null, "flight room must instantiate")
    if room == null:
        return

    var coordinator_count := 0
    var pause_menu_count := 0
    for child: Node in room.get_children():
        if child is FlightRoomSettingsCoordinator:
            coordinator_count += 1
        if child is PauseMenu:
            pause_menu_count += 1
    assert_equal(
        coordinator_count,
        1,
        "flight room must own exactly one settings coordinator"
    )
    assert_equal(
        pause_menu_count,
        1,
        "flight room must own exactly one pause menu"
    )

    var coordinator := room.get_node_or_null(
        "FlightRoomSettingsCoordinator"
    ) as FlightRoomSettingsCoordinator
    var pause_menu := room.get_node_or_null("PauseMenu") as PauseMenu
    assert_true(coordinator != null, "settings coordinator node required")
    assert_true(pause_menu != null, "PauseMenu node required")
    if coordinator != null:
        assert_equal(
            coordinator.settings_service_path,
            NodePath("/root/PlayerSettingsService"),
            "room coordinator must consume the settings autoload"
        )
        assert_equal(
            coordinator.camera_rig_path,
            NodePath("../ChaseCameraRig"),
            "room coordinator must target the existing camera rig"
        )
        assert_equal(
            coordinator.flight_controller_path,
            NodePath("../PlayerInterceptor/ShipFlightController"),
            "room coordinator must target the existing controller"
        )
    if pause_menu != null:
        assert_equal(
            pause_menu.process_mode,
            Node.PROCESS_MODE_ALWAYS,
            "room pause menu must process while paused"
        )
        assert_equal(
            pause_menu.input_source_path,
            NodePath("../PlayerInterceptor/PlayerInputSource"),
            "pause menu must use the existing input source"
        )
        assert_equal(
            pause_menu.room_controller_path,
            NodePath("../FlightRoomController"),
            "pause menu must use the existing reset owner"
        )

    var hud := room.get_node_or_null("FlightHud") as FlightHud
    assert_true(hud != null, "existing HUD must remain")
    if hud != null:
        assert_true(
            hud.get_node_or_null("NoseReticle") is Control,
            "flight room HUD must retain the nose reticle"
        )
        assert_true(
            hud.get_node_or_null("VelocityMarker") is Control,
            "flight room HUD must retain the velocity marker"
        )

    var controller_source := FileAccess.get_file_as_string(
        FLIGHT_ROOM_CONTROLLER_PATH
    )
    assert_true(
        controller_source.contains("get_tree().paused = false"),
        "flight-room reset must explicitly clear pause before resetting"
    )
    room.free()

func _emit_option_id(option: OptionButton, item_id: int) -> bool:
    for index: int in range(option.item_count):
        if option.get_item_id(index) == item_id:
            option.select(index)
            option.item_selected.emit(index)
            return true
    return false

func _remove_settings_file(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
