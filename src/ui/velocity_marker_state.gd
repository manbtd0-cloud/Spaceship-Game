class_name VelocityMarkerState
extends RefCounted

var visible: bool
var screen_position: Vector2
var clamped: bool
var rotation_radians: float

func _init(
    is_visible: bool = false,
    position: Vector2 = Vector2.ZERO,
    is_clamped: bool = false,
    rotation: float = 0.0
) -> void:
    visible = is_visible
    screen_position = position
    clamped = is_clamped
    rotation_radians = rotation
