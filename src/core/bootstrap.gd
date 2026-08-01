extends Node

func _ready() -> void:
    call_deferred("_enter_flight_room")

func _enter_flight_room() -> void:
    var result := get_tree().change_scene_to_file(
        "res://scenes/flight_room/flight_room.tscn"
    )
    if result != OK:
        push_error("Failed to enter flight room")
