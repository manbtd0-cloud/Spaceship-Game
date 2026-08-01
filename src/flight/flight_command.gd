class_name FlightCommand
extends RefCounted

var mode: FlightMode.Value = FlightMode.ASSISTED
var translation: Vector3 = Vector3.ZERO
var rotation: Vector3 = Vector3.ZERO
var boost: float = 0.0
