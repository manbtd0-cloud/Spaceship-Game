class_name FlightRoomSettingsCoordinator
extends Node

@export var settings_service_path: NodePath = NodePath("/root/PlayerSettingsService")
@export var camera_rig_path: NodePath
@export var flight_controller_path: NodePath

var _settings: PlayerSettingsStore
var _camera_rig: ChaseCameraRig
var _flight_controller: ShipFlightController
var _initialized := false
var _error_reported := false

var _behavior_changed_callable := Callable()
var _distance_changed_callable := Callable()
var _flight_mode_changed_callable := Callable()

func _ready() -> void:
    initialize()

func initialize() -> bool:
    if _initialized:
        return true

    _disconnect_signals()
    _resolve_dependencies()

    var missing: Array[String] = []
    if _settings == null:
        missing.append("settings service at %s" % settings_service_path)
    if _camera_rig == null:
        missing.append("camera rig at %s" % camera_rig_path)
    if _flight_controller == null:
        missing.append("flight controller at %s" % flight_controller_path)
    if not missing.is_empty():
        _disable_with_error(
            "FlightRoomSettingsCoordinator could not resolve %s"
            % ", ".join(PackedStringArray(missing))
        )
        return false

    _behavior_changed_callable = Callable(
        self,
        &"_on_camera_behavior_changed"
    )
    _distance_changed_callable = Callable(
        self,
        &"_on_camera_distance_changed"
    )
    _flight_mode_changed_callable = Callable(
        self,
        &"_on_default_flight_mode_changed"
    )

    _apply_current_settings()
    _connect_signals()
    _initialized = true
    _error_reported = false
    return true

func is_initialized() -> bool:
    return _initialized

func _exit_tree() -> void:
    _disconnect_signals()
    _initialized = false

func _resolve_dependencies() -> void:
    _settings = get_node_or_null(settings_service_path) as PlayerSettingsStore
    _camera_rig = get_node_or_null(camera_rig_path) as ChaseCameraRig
    _flight_controller = get_node_or_null(
        flight_controller_path
    ) as ShipFlightController

func _apply_current_settings() -> void:
    _camera_rig.select_behavior(_settings.get_camera_behavior())
    _camera_rig.select_distance(_settings.get_camera_distance())
    _flight_controller.set_flight_mode(
        _settings.get_default_flight_mode()
    )

func _connect_signals() -> void:
    if not _settings.camera_behavior_changed.is_connected(
        _behavior_changed_callable
    ):
        _settings.camera_behavior_changed.connect(
            _behavior_changed_callable
        )
    if not _settings.camera_distance_changed.is_connected(
        _distance_changed_callable
    ):
        _settings.camera_distance_changed.connect(
            _distance_changed_callable
        )
    if not _settings.default_flight_mode_changed.is_connected(
        _flight_mode_changed_callable
    ):
        _settings.default_flight_mode_changed.connect(
            _flight_mode_changed_callable
        )

func _disconnect_signals() -> void:
    if not is_instance_valid(_settings):
        return
    if (
        _behavior_changed_callable.is_valid()
        and _settings.camera_behavior_changed.is_connected(
            _behavior_changed_callable
        )
    ):
        _settings.camera_behavior_changed.disconnect(
            _behavior_changed_callable
        )
    if (
        _distance_changed_callable.is_valid()
        and _settings.camera_distance_changed.is_connected(
            _distance_changed_callable
        )
    ):
        _settings.camera_distance_changed.disconnect(
            _distance_changed_callable
        )
    if (
        _flight_mode_changed_callable.is_valid()
        and _settings.default_flight_mode_changed.is_connected(
            _flight_mode_changed_callable
        )
    ):
        _settings.default_flight_mode_changed.disconnect(
            _flight_mode_changed_callable
        )

func _on_camera_behavior_changed(value: CameraBehavior.Value) -> void:
    if is_instance_valid(_camera_rig):
        _camera_rig.select_behavior(value)

func _on_camera_distance_changed(value: CameraDistance.Value) -> void:
    if is_instance_valid(_camera_rig):
        _camera_rig.select_distance(value)

func _on_default_flight_mode_changed(value: FlightMode.Value) -> void:
    if is_instance_valid(_flight_controller):
        _flight_controller.set_flight_mode(value)

func _disable_with_error(message: String) -> void:
    _initialized = false
    set_process(false)
    if _error_reported:
        return
    _error_reported = true
    _report_error(message)

func _report_error(message: String) -> void:
    push_error(message)
