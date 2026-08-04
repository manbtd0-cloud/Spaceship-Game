class_name PauseMenu
extends CanvasLayer

@export var settings_service_path: NodePath = NodePath("/root/PlayerSettingsService")
@export var input_source_path: NodePath
@export var room_controller_path: NodePath
@export var resume_button_path: NodePath
@export var camera_behavior_option_path: NodePath
@export var camera_distance_option_path: NodePath
@export var flight_mode_option_path: NodePath
@export var restart_button_path: NodePath
@export var quit_button_path: NodePath

var _settings: PlayerSettingsStore
var _input_source: PlayerInputSource
var _room_controller: FlightRoomController
var _resume_button: Button
var _camera_behavior_option: OptionButton
var _camera_distance_option: OptionButton
var _flight_mode_option: OptionButton
var _restart_button: Button
var _quit_button: Button

var _initialized := false
var _open := false
var _restore_mouse_capture := false
var _error_reported := false

var _resume_callable := Callable()
var _restart_callable := Callable()
var _quit_callable := Callable()
var _behavior_callable := Callable()
var _distance_callable := Callable()
var _flight_mode_callable := Callable()

func _ready() -> void:
    initialize()

func initialize() -> bool:
    if _initialized:
        return true

    _resolve_dependencies()
    var missing := PackedStringArray()
    if _settings == null:
        missing.append("settings service at %s" % settings_service_path)
    if _input_source == null:
        missing.append("input source at %s" % input_source_path)
    if _room_controller == null:
        missing.append("room controller at %s" % room_controller_path)
    if _resume_button == null:
        missing.append("Resume button at %s" % resume_button_path)
    if _camera_behavior_option == null:
        missing.append("camera behavior option at %s" % camera_behavior_option_path)
    if _camera_distance_option == null:
        missing.append("camera distance option at %s" % camera_distance_option_path)
    if _flight_mode_option == null:
        missing.append("flight mode option at %s" % flight_mode_option_path)
    if _restart_button == null:
        missing.append("Restart button at %s" % restart_button_path)
    if _quit_button == null:
        missing.append("Quit button at %s" % quit_button_path)
    if not missing.is_empty():
        _disable_with_error(
            "PauseMenu could not resolve %s" % ", ".join(missing)
        )
        return false

    _populate_options()
    _build_callables()
    _connect_controls()
    _sync_options_from_settings()
    visible = false
    _open = false
    set_process_unhandled_input(true)
    _initialized = true
    _error_reported = false
    return true

func is_initialized() -> bool:
    return _initialized

func open_menu() -> bool:
    if not _initialized and not initialize():
        return false
    if _open:
        return false

    var tree := get_tree()
    if tree == null:
        return false

    _restore_mouse_capture = _input_source.is_mouse_captured()
    _input_source.set_mouse_captured(false)
    _sync_options_from_settings()
    _open = true
    visible = true
    tree.paused = true
    _resume_button.grab_focus()
    return true

func resume_game() -> bool:
    if not _open:
        return false

    var tree := get_tree()
    if tree == null:
        return false

    tree.paused = false
    _open = false
    visible = false
    if is_instance_valid(_input_source):
        _input_source.set_mouse_captured(_restore_mouse_capture)
    return true

func restart_flight_room() -> bool:
    if not _initialized and not initialize():
        return false

    var tree := get_tree()
    if tree == null or not is_instance_valid(_room_controller):
        return false

    tree.paused = false
    _open = false
    visible = false
    if is_instance_valid(_input_source):
        _input_source.set_mouse_captured(_restore_mouse_capture)
    _room_controller.reset_player()
    return true

func is_open() -> bool:
    return _open

func _unhandled_input(event: InputEvent) -> void:
    if not _initialized:
        return
    if not event.is_action_pressed(&"toggle_pause"):
        return

    if _open:
        resume_game()
    else:
        open_menu()
    get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    _disconnect_controls()
    var tree := get_tree()
    if tree != null and tree.paused:
        tree.paused = false
    if _open and is_instance_valid(_input_source):
        _input_source.set_mouse_captured(_restore_mouse_capture)
    _open = false
    _initialized = false

func _resolve_dependencies() -> void:
    _settings = get_node_or_null(settings_service_path) as PlayerSettingsStore
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource
    _room_controller = get_node_or_null(room_controller_path) as FlightRoomController
    _resume_button = get_node_or_null(resume_button_path) as Button
    _camera_behavior_option = get_node_or_null(
        camera_behavior_option_path
    ) as OptionButton
    _camera_distance_option = get_node_or_null(
        camera_distance_option_path
    ) as OptionButton
    _flight_mode_option = get_node_or_null(flight_mode_option_path) as OptionButton
    _restart_button = get_node_or_null(restart_button_path) as Button
    _quit_button = get_node_or_null(quit_button_path) as Button

func _populate_options() -> void:
    _camera_behavior_option.clear()
    _camera_behavior_option.add_item("Dynamic", CameraBehavior.Value.DYNAMIC)
    _camera_behavior_option.add_item("Tactical", CameraBehavior.Value.TACTICAL)
    _camera_behavior_option.add_item("Locked", CameraBehavior.Value.LOCKED)

    _camera_distance_option.clear()
    _camera_distance_option.add_item("Close", CameraDistance.Value.CLOSE)
    _camera_distance_option.add_item("Standard", CameraDistance.Value.STANDARD)
    _camera_distance_option.add_item("Far", CameraDistance.Value.FAR)

    _flight_mode_option.clear()
    _flight_mode_option.add_item("Assisted", FlightMode.Value.ASSISTED)
    _flight_mode_option.add_item("Inertial", FlightMode.Value.MANUAL)

func _build_callables() -> void:
    _resume_callable = Callable(self, &"resume_game")
    _restart_callable = Callable(self, &"restart_flight_room")
    _quit_callable = Callable(self, &"_quit_game")
    _behavior_callable = Callable(self, &"_on_camera_behavior_selected")
    _distance_callable = Callable(self, &"_on_camera_distance_selected")
    _flight_mode_callable = Callable(self, &"_on_flight_mode_selected")

func _connect_controls() -> void:
    if not _resume_button.pressed.is_connected(_resume_callable):
        _resume_button.pressed.connect(_resume_callable)
    if not _restart_button.pressed.is_connected(_restart_callable):
        _restart_button.pressed.connect(_restart_callable)
    if not _quit_button.pressed.is_connected(_quit_callable):
        _quit_button.pressed.connect(_quit_callable)
    if not _camera_behavior_option.item_selected.is_connected(_behavior_callable):
        _camera_behavior_option.item_selected.connect(_behavior_callable)
    if not _camera_distance_option.item_selected.is_connected(_distance_callable):
        _camera_distance_option.item_selected.connect(_distance_callable)
    if not _flight_mode_option.item_selected.is_connected(_flight_mode_callable):
        _flight_mode_option.item_selected.connect(_flight_mode_callable)

func _disconnect_controls() -> void:
    if is_instance_valid(_resume_button) and _resume_callable.is_valid():
        if _resume_button.pressed.is_connected(_resume_callable):
            _resume_button.pressed.disconnect(_resume_callable)
    if is_instance_valid(_restart_button) and _restart_callable.is_valid():
        if _restart_button.pressed.is_connected(_restart_callable):
            _restart_button.pressed.disconnect(_restart_callable)
    if is_instance_valid(_quit_button) and _quit_callable.is_valid():
        if _quit_button.pressed.is_connected(_quit_callable):
            _quit_button.pressed.disconnect(_quit_callable)
    if is_instance_valid(_camera_behavior_option) and _behavior_callable.is_valid():
        if _camera_behavior_option.item_selected.is_connected(_behavior_callable):
            _camera_behavior_option.item_selected.disconnect(_behavior_callable)
    if is_instance_valid(_camera_distance_option) and _distance_callable.is_valid():
        if _camera_distance_option.item_selected.is_connected(_distance_callable):
            _camera_distance_option.item_selected.disconnect(_distance_callable)
    if is_instance_valid(_flight_mode_option) and _flight_mode_callable.is_valid():
        if _flight_mode_option.item_selected.is_connected(_flight_mode_callable):
            _flight_mode_option.item_selected.disconnect(_flight_mode_callable)

func _sync_options_from_settings() -> void:
    _select_item_id(_camera_behavior_option, _settings.get_camera_behavior())
    _select_item_id(_camera_distance_option, _settings.get_camera_distance())
    _select_item_id(_flight_mode_option, _settings.get_default_flight_mode())

func _select_item_id(option: OptionButton, item_id: int) -> void:
    for index: int in range(option.item_count):
        if option.get_item_id(index) == item_id:
            option.select(index)
            return

func _on_camera_behavior_selected(index: int) -> void:
    _settings.set_camera_behavior(
        _camera_behavior_option.get_item_id(index) as CameraBehavior.Value
    )

func _on_camera_distance_selected(index: int) -> void:
    _settings.set_camera_distance(
        _camera_distance_option.get_item_id(index) as CameraDistance.Value
    )

func _on_flight_mode_selected(index: int) -> void:
    _settings.set_default_flight_mode(
        _flight_mode_option.get_item_id(index) as FlightMode.Value
    )

func _quit_game() -> void:
    var tree := get_tree()
    if tree == null:
        return
    tree.paused = false
    tree.quit()

func _disable_with_error(message: String) -> void:
    var tree := get_tree()
    if tree != null and tree.paused:
        tree.paused = false
    visible = false
    _open = false
    _initialized = false
    set_process_unhandled_input(false)
    if _error_reported:
        return
    _error_reported = true
    _report_error(message)

func _report_error(message: String) -> void:
    push_error(message)
