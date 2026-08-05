class_name FlightMode
extends RefCounted

enum Value {
    ASSISTED = 0,
    MANUAL = 1,
    AI_ASSISTED = 2,
}

static func is_valid(value: int) -> bool:
    return (
        value == Value.ASSISTED
        or value == Value.MANUAL
        or value == Value.AI_ASSISTED
    )
