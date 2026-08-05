class_name FlightAssistOutput
extends RefCounted

var force_local: Vector3 = Vector3.ZERO
var torque_local: Vector3 = Vector3.ZERO

func is_finite() -> bool:
    return force_local.is_finite() and torque_local.is_finite()
