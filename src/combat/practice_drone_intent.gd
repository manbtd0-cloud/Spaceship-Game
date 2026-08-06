class_name PracticeDroneIntent
extends RefCounted

var acceleration_world := Vector3.ZERO
var torque_world := Vector3.ZERO

func clear() -> void:
    acceleration_world = Vector3.ZERO
    torque_world = Vector3.ZERO

func duplicate_intent() -> PracticeDroneIntent:
    var copy := PracticeDroneIntent.new()
    copy.acceleration_world = acceleration_world
    copy.torque_world = torque_world
    return copy
