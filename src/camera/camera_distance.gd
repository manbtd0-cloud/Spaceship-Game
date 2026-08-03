class_name CameraDistance
extends RefCounted

enum Value {
    CLOSE,
    STANDARD,
    FAR,
}

static func is_valid(value: int) -> bool:
    return (
        value == Value.CLOSE
        or value == Value.STANDARD
        or value == Value.FAR
    )

static func semantic_name(value: Value) -> StringName:
    match value:
        Value.CLOSE:
            return &"close"
        Value.FAR:
            return &"far"
        _:
            return &"standard"
