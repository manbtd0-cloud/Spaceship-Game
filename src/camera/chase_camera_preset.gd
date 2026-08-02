class_name ChaseCameraPreset
extends RefCounted

var semantic_name: StringName:
    get:
        return _semantic_name
var rear_offset: float:
    get:
        return _rear_offset
var height: float:
    get:
        return _height
var max_speed_pullback: float:
    get:
        return _max_speed_pullback
var hard_rear_limit: float:
    get:
        return _hard_rear_limit

var _semantic_name: StringName
var _rear_offset: float
var _height: float
var _max_speed_pullback: float
var _hard_rear_limit: float

func _init(
    name_value: StringName,
    rear: float,
    height_value: float,
    pullback: float,
    limit: float
) -> void:
    _semantic_name = name_value
    _rear_offset = rear
    _height = height_value
    _max_speed_pullback = pullback
    _hard_rear_limit = limit

func is_valid() -> bool:
    return (
        _semantic_name != &""
        and is_finite(_rear_offset)
        and is_finite(_height)
        and is_finite(_max_speed_pullback)
        and is_finite(_hard_rear_limit)
        and _rear_offset > 0.0
        and _height >= 0.0
        and _max_speed_pullback >= 0.0
        and _hard_rear_limit >= _rear_offset
    )
