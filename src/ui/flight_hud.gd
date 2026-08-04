class_name FlightHud
extends CanvasLayer

@export var controller_path: NodePath
@export var input_source_path: NodePath
@export var speed_label_path: NodePath
@export var mode_label_path: NodePath
@export var boost_label_path: NodePath
@export var heat_label_path: NodePath
@export var envelope_label_path: NodePath
@export var capture_label_path: NodePath
@export var controls_label_path: NodePath

var _controller: ShipFlightController
var _input_source: PlayerInputSource
var _speed_label: Label
var _mode_label: Label
var _boost_label: Label
var _heat_label: Label
var _envelope_label: Label
var _capture_label: Label
var _controls_label: Label

func _ready() -> void:
    _controller = get_node_or_null(controller_path) as ShipFlightController
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource
    _speed_label = get_node_or_null(speed_label_path) as Label
    _mode_label = get_node_or_null(mode_label_path) as Label
    _boost_label = get_node_or_null(boost_label_path) as Label
    _heat_label = get_node_or_null(heat_label_path) as Label
    _envelope_label = get_node_or_null(envelope_label_path) as Label
    _capture_label = get_node_or_null(capture_label_path) as Label
    _controls_label = get_node_or_null(controls_label_path) as Label

    if _controller == null:
        _disable_with_error("FlightHud could not resolve controller at %s" % controller_path)
        return
    if _input_source == null:
        _disable_with_error("FlightHud could not resolve input source at %s" % input_source_path)
        return
    if (
        _speed_label == null
        or _mode_label == null
        or _boost_label == null
        or _heat_label == null
        or _envelope_label == null
    ):
        _disable_with_error("FlightHud could not resolve telemetry labels")
        return
    if _capture_label == null or _controls_label == null:
        _disable_with_error("FlightHud could not resolve help labels")
        return

    _refresh_labels()

func _process(_delta: float) -> void:
    _refresh_labels()

static func mode_text_for(mode: FlightMode.Value) -> String:
    return (
        "MODE   ASSISTED"
        if mode == FlightMode.Value.ASSISTED
        else "MODE   INERTIAL"
    )

func _refresh_labels() -> void:
    _speed_label.text = "SPEED  %04d m/s" % roundi(_controller.get_speed_mps())
    _mode_label.text = mode_text_for(_controller.get_flight_mode())

    var heat_percent := roundi(_controller.get_boost_heat() * 100.0)
    if _controller.is_boost_locked_out():
        _boost_label.text = "BOOST  OVERHEATED"
        _heat_label.text = "RECOVERY  %03d%%" % roundi(
            _controller.get_boost_recovery_progress() * 100.0
        )
    elif _controller.get_boost_amount() > 0.0:
        _boost_label.text = "BOOST  ACTIVE"
        _heat_label.text = "HEAT  %03d%%" % heat_percent
    else:
        _boost_label.text = "BOOST  READY"
        _heat_label.text = "HEAT  %03d%%" % heat_percent

    _envelope_label.text = "ACTIVE ENVELOPE  %03d m/s" % roundi(
        _controller.get_active_speed_limit()
    )
    _capture_label.text = (
        "MOUSE  CAPTURED   ESC PAUSE"
        if _input_source.is_mouse_captured()
        else "MOUSE  RELEASED"
    )
    _controls_label.text = (
        "W/S THRUST   Q/E STRAFE   SPACE/CTRL VERTICAL   "
        + "MOUSE PITCH/YAW   A/D YAW   UP/DOWN PITCH   "
        + "LEFT/RIGHT ROLL   SHIFT BOOST   F MODE   C CAMERA   "
        + "B REAR   PGUP RIGHT   PGDN LEFT   R RESET"
    )

func _disable_with_error(message: String) -> void:
    push_error(message)
    set_process(false)
