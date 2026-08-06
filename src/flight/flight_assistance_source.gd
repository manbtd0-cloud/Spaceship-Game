class_name FlightAssistanceSource
extends RefCounted

enum Value {
    NONE,
    LEGACY_ASSISTED,
    AI_ASSISTED,
    SMART_STABILIZE,
}

static func visual_cap_for(value: Value) -> float:
    match value:
        Value.LEGACY_ASSISTED:
            return 0.35
        Value.AI_ASSISTED, Value.SMART_STABILIZE:
            return 1.0
        _:
            return 0.0
