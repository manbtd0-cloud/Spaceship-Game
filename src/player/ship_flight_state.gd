class_name ShipFlightState
extends RefCounted

static func toggled_mode(mode: FlightMode.Value) -> FlightMode.Value:
    match mode:
        FlightMode.Value.ASSISTED:
            return FlightMode.Value.AI_ASSISTED
        FlightMode.Value.AI_ASSISTED:
            return FlightMode.Value.MANUAL
        FlightMode.Value.MANUAL:
            return FlightMode.Value.ASSISTED
        _:
            return FlightMode.Value.ASSISTED

static func speed_mps(world_velocity: Vector3) -> float:
    return world_velocity.length()
