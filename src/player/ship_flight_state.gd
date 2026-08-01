class_name ShipFlightState
extends RefCounted

static func toggled_mode(mode: FlightMode.Value) -> FlightMode.Value:
    return (
        FlightMode.Value.MANUAL
        if mode == FlightMode.Value.ASSISTED
        else FlightMode.Value.ASSISTED
    )

static func speed_mps(world_velocity: Vector3) -> float:
    return world_velocity.length()
