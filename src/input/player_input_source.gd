class_name PlayerInputSource
extends Node

@export var mouse_sensitivity: float = 0.0025
@export var max_mouse_command: float = 1.0

const REQUIRED_ACTIONS: Array[StringName] = [
    &"thrust_forward",
    &"thrust_reverse",
    &"strafe_left",
    &"strafe_right",
    &"strafe_up",
    &"strafe_down",
    &"roll_left",
    &"roll_right",
    &"boost",
    &"toggle_flight_mode",
    &"toggle_mouse_capture",
    &"reset_flight_room",
]

var _mouse_delta := Vector2.ZERO
var _available_actions: Dictionary = {}
var _captured := false

func _ready() -> void:
    for action: StringName in REQUIRED_ACTIONS:
        var available := InputMap.has_action(action)
        _available_actions[action] = available
        if not available:
            push_warning("Missing input action: %s" % action)

func _unhandled_input(event: InputEvent) -> void:
    if not _captured:
        return
    var mouse_motion := event as InputEventMouseMotion
    if mouse_motion != null:
        _mouse_delta += mouse_motion.relative

func sample_command(current_mode: FlightMode.Value) -> FlightCommand:
    var command := FlightCommand.new()
    command.mode = current_mode
    command.translation = PlayerInputMath.compose_translation(
        _strength(&"strafe_left"),
        _strength(&"strafe_right"),
        _strength(&"strafe_down"),
        _strength(&"strafe_up"),
        _strength(&"thrust_forward"),
        _strength(&"thrust_reverse")
    )
    command.rotation = PlayerInputMath.compose_rotation(
        _mouse_delta,
        _strength(&"roll_left"),
        _strength(&"roll_right"),
        mouse_sensitivity,
        max_mouse_command
    )
    command.boost = PlayerInputMath.clamp_boost(_strength(&"boost"))
    _mouse_delta = Vector2.ZERO
    return command

func consume_mode_toggle() -> bool:
    return _just_pressed(&"toggle_flight_mode")

func consume_capture_toggle() -> bool:
    return _just_pressed(&"toggle_mouse_capture")

func consume_reset_request() -> bool:
    return _just_pressed(&"reset_flight_room")

func set_mouse_captured(captured: bool) -> void:
    _captured = captured
    Input.mouse_mode = (
        Input.MOUSE_MODE_CAPTURED
        if captured
        else Input.MOUSE_MODE_VISIBLE
    )
    if not captured:
        _mouse_delta = Vector2.ZERO

func is_mouse_captured() -> bool:
    return _captured

func _strength(action: StringName) -> float:
    if not bool(_available_actions.get(action, false)):
        return 0.0
    return Input.get_action_strength(action)

func _just_pressed(action: StringName) -> bool:
    if not bool(_available_actions.get(action, false)):
        return false
    return Input.is_action_just_pressed(action)
