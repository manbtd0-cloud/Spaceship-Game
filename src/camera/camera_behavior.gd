class_name CameraBehavior
extends RefCounted

enum Value {
    DYNAMIC,
    TACTICAL,
    LOCKED,
}

static func is_valid(value: int) -> bool:
    return (
        value == Value.DYNAMIC
        or value == Value.TACTICAL
        or value == Value.LOCKED
    )

static func semantic_name(value: Value) -> StringName:
    match value:
        Value.DYNAMIC:
            return &"dynamic"
        Value.LOCKED:
            return &"locked"
        _:
            return &"tactical"
