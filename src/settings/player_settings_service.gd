class_name PlayerSettingsStore
extends Node

signal camera_behavior_changed(value: CameraBehavior.Value)
signal camera_distance_changed(value: CameraDistance.Value)
signal default_flight_mode_changed(value: FlightMode.Value)
signal settings_saved

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULT_CAMERA_BEHAVIOR := CameraBehavior.Value.TACTICAL
const DEFAULT_CAMERA_DISTANCE := CameraDistance.Value.STANDARD
const DEFAULT_FLIGHT_MODE := FlightMode.Value.ASSISTED

var _path: String = DEFAULT_PATH
var _camera_behavior: CameraBehavior.Value = DEFAULT_CAMERA_BEHAVIOR
var _camera_distance: CameraDistance.Value = DEFAULT_CAMERA_DISTANCE
var _default_flight_mode: FlightMode.Value = DEFAULT_FLIGHT_MODE
var _loaded := false

func _ready() -> void:
    if not _loaded:
        load_from_path()

func load_from_path(path: String = DEFAULT_PATH) -> void:
    _path = path if not path.is_empty() else DEFAULT_PATH
    _camera_behavior = DEFAULT_CAMERA_BEHAVIOR
    _camera_distance = DEFAULT_CAMERA_DISTANCE
    _default_flight_mode = DEFAULT_FLIGHT_MODE

    var config := ConfigFile.new()
    var result := config.load(_path)
    if result == ERR_FILE_NOT_FOUND:
        _loaded = true
        return
    if result != OK:
        _report_warning(
            "Player settings could not load from %s; using defaults (error %d)"
            % [_path, result]
        )
        _loaded = true
        return

    _camera_behavior = _read_camera_behavior(config)
    _camera_distance = _read_camera_distance(config)
    _default_flight_mode = _read_flight_mode(config)
    _loaded = true

func is_loaded() -> bool:
    return _loaded

func get_camera_behavior() -> CameraBehavior.Value:
    return _camera_behavior

func get_camera_distance() -> CameraDistance.Value:
    return _camera_distance

func get_default_flight_mode() -> FlightMode.Value:
    return _default_flight_mode

func set_camera_behavior(value: CameraBehavior.Value) -> bool:
    if not CameraBehavior.is_valid(value):
        _report_warning("Rejected invalid camera behavior: %s" % value)
        return false
    if _camera_behavior == value:
        return false

    _camera_behavior = value
    camera_behavior_changed.emit(_camera_behavior)
    _save()
    return true

func set_camera_distance(value: CameraDistance.Value) -> bool:
    if not CameraDistance.is_valid(value):
        _report_warning("Rejected invalid camera distance: %s" % value)
        return false
    if _camera_distance == value:
        return false

    _camera_distance = value
    camera_distance_changed.emit(_camera_distance)
    _save()
    return true

func set_default_flight_mode(value: FlightMode.Value) -> bool:
    if not _is_valid_flight_mode(value):
        _report_warning("Rejected invalid default flight mode: %s" % value)
        return false
    if _default_flight_mode == value:
        return false

    _default_flight_mode = value
    default_flight_mode_changed.emit(_default_flight_mode)
    _save()
    return true

func _read_camera_behavior(config: ConfigFile) -> CameraBehavior.Value:
    var raw: Variant = config.get_value(
        "camera",
        "behavior",
        DEFAULT_CAMERA_BEHAVIOR
    )
    if typeof(raw) == TYPE_INT and CameraBehavior.is_valid(int(raw)):
        return int(raw)

    _report_warning(
        "Invalid camera.behavior in %s; using Tactical" % _path
    )
    return DEFAULT_CAMERA_BEHAVIOR

func _read_camera_distance(config: ConfigFile) -> CameraDistance.Value:
    var raw: Variant = config.get_value(
        "camera",
        "distance",
        DEFAULT_CAMERA_DISTANCE
    )
    if typeof(raw) == TYPE_INT and CameraDistance.is_valid(int(raw)):
        return int(raw)

    _report_warning(
        "Invalid camera.distance in %s; using Standard" % _path
    )
    return DEFAULT_CAMERA_DISTANCE

func _read_flight_mode(config: ConfigFile) -> FlightMode.Value:
    var raw: Variant = config.get_value(
        "flight",
        "default_mode",
        DEFAULT_FLIGHT_MODE
    )
    if typeof(raw) == TYPE_INT and _is_valid_flight_mode(int(raw)):
        return int(raw)

    _report_warning(
        "Invalid flight.default_mode in %s; using Assisted" % _path
    )
    return DEFAULT_FLIGHT_MODE

func _is_valid_flight_mode(value: int) -> bool:
    return (
        value == FlightMode.Value.ASSISTED
        or value == FlightMode.Value.MANUAL
    )

func _save() -> bool:
    var config := ConfigFile.new()
    config.set_value("camera", "behavior", _camera_behavior)
    config.set_value("camera", "distance", _camera_distance)
    config.set_value("flight", "default_mode", _default_flight_mode)

    var result := config.save(_path)
    if result != OK:
        _report_warning(
            "Player settings could not save to %s (error %d)"
            % [_path, result]
        )
        return false

    settings_saved.emit()
    return true

func _report_warning(message: String) -> void:
    push_warning(message)
