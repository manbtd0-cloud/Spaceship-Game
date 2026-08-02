class_name FlightCommand
extends RefCounted

var mode: FlightMode.Value = FlightMode.Value.ASSISTED
var translation: Vector3 = Vector3.ZERO
var rotation: Vector3 = Vector3.ZERO
var boost: float = 0.0

func duplicate_command() -> FlightCommand:
    var copy := FlightCommand.new()
    copy.mode = mode
    copy.translation = translation
    copy.rotation = rotation
    copy.boost = boost
    return copy
