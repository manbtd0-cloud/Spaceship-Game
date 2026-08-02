class_name FlightOutput
extends RefCounted

var pilot_force_local: Vector3 = Vector3.ZERO
var pilot_torque_local: Vector3 = Vector3.ZERO
var assist_force_local: Vector3 = Vector3.ZERO
var assist_torque_local: Vector3 = Vector3.ZERO
var force_local: Vector3 = Vector3.ZERO
var torque_local: Vector3 = Vector3.ZERO

func finalize_totals() -> void:
    force_local = pilot_force_local + assist_force_local
    torque_local = pilot_torque_local + assist_torque_local
