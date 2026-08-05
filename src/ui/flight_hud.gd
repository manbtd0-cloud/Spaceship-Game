class_name FlightHud
extends CanvasLayer

const VELOCITY_MARKER_MINIMUM_SPEED := 2.0
const VELOCITY_MARKER_SAFE_MARGIN := 32.0

@export var controller_path: NodePath
@export var input_source_path: NodePath
@export var camera_path: NodePath
@export var nose_reticle_path: NodePath
@export var velocity_marker_path: NodePath
@export var speed_label_path: NodePath
@export var mode_label_path: NodePath
@export var boost_label_path: NodePath
@export var heat_label_path: NodePath
@export var envelope_label_path: NodePath
@export var capture_label_path: NodePath
@export var controls_label_path: NodePath

var _controller: ShipFlightController
var _input_source: PlayerInputSource
var _camera: Camera3D
var _nose_reticle: Control
var _velocity_marker: Control
var _speed_label: Label
var _mode_label: Label
var _boost_label: Label
var _heat_label: Label
var _envelope_label: Label
var _capture_label: Label
var _controls_label: Label
var _camera_error_reported := false

func _ready() -> void:
    _controller = get_node_or_null(controller_path) as ShipFlightController
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource
    _nose_reticle = get_node_or_null(nose_reticle_path) as Control
    _velocity_marker = get_node_or_null(velocity_marker_path) as Control
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

    if _nose_reticle == null:
        push_error("FlightHud could not resolve nose reticle at %s" % nose_reticle_path)
    if _velocity_marker == null:
        push_error("FlightHud could not resolve velocity marker at %s" % velocity_marker_path)
    else:
        _velocity_marker.visible = false

    _refresh_labels()
    _refresh_velocity_marker()

func _process(_delta: float) -> void:
    _refresh_labels()
    _refresh_velocity_marker()

static func mode_text_for(mode: FlightMode.Value) -> String:
    match mode:
        FlightMode.Value.ASSISTED:
            return "MODE   ASSISTED"
        FlightMode.Value.AI_ASSISTED:
            return "MODE   AI ASSISTED"
        FlightMode.Value.MANUAL:
            return "MODE   INERTIAL"
        _:
            return "MODE   ASSISTED"

func _refresh_labels() -> void:
    _speed_label.text = "SPEED  %04d m/s" % roundi(_controller.get_speed_mps())
    _mode_label.text = mode_text_for(_controller.get_flight_mode())
    if _controller.is_smart_stabilizing():
        _mode_label.text += "   |   STABILIZING"

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
        + "LEFT/RIGHT ROLL   SHIFT BOOST   F MODE   X STABILIZE   "
        + "C CAMERA   B REAR   PGUP RIGHT   PGDN LEFT   R RESET"
    )

func _refresh_velocity_marker() -> void:
    if _velocity_marker == null:
        return

    if _camera == null or not is_instance_valid(_camera):
        _camera = get_node_or_null(camera_path) as Camera3D
    if _camera == null:
        _velocity_marker.visible = false
        if not _camera_error_reported:
            _camera_error_reported = true
            push_error("FlightHud could not resolve camera at %s" % camera_path)
        return

    var viewport_size := get_viewport().get_visible_rect().size
    var state := VelocityMarkerMath.project(
        _camera.global_transform,
        _camera.fov,
        viewport_size,
        _controller.get_world_velocity(),
        VELOCITY_MARKER_MINIMUM_SPEED,
        VELOCITY_MARKER_SAFE_MARGIN
    )
    _velocity_marker.visible = state.visible
    if not state.visible:
        return

    _velocity_marker.position = state.screen_position - _velocity_marker.size * 0.5
    _velocity_marker.rotation = state.rotation_radians if state.clamped else 0.0

func _disable_with_error(message: String) -> void:
    push_error(message)
    set_process(false)
