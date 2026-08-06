class_name FlightAssistCommand
extends RefCounted

var translation: Vector3 = Vector3.ZERO
var rotation: Vector3 = Vector3.ZERO

func is_finite() -> bool:
    return translation.is_finite() and rotation.is_finite()
