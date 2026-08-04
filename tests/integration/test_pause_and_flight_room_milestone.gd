extends "res://tests/support/test_case.gd"

const PAUSE_MENU_SCRIPT_PATH := "res://src/ui/pause_menu.gd"
const PAUSE_MENU_SCENE_PATH := "res://scenes/ui/pause_menu.tscn"
const FLIGHT_ROOM_SCENE_PATH := "res://scenes/flight_room/flight_room.tscn"
const FLIGHT_ROOM_CONTROLLER_PATH := "res://src/flight_room/flight_room_controller.gd"

func run() -> void:
    var pause_script_exists := ResourceLoader.exists(PAUSE_MENU_SCRIPT_PATH)
    var pause_scene_exists := ResourceLoader.exists(PAUSE_MENU_SCENE_PATH)
    assert_true(pause_script_exists, "pause menu production script must exist")
    assert_true(pause_scene_exists, "pause menu production scene must exist")

    if pause_script_exists:
        var pause_script := load(PAUSE_MENU_SCRIPT_PATH) as Script
        assert_true(pause_script != null, "pause menu script must load")
        if pause_script != null:
            for method_name: StringName in [
                &"open_menu",
                &"resume_game",
                &"restart_flight_room",
                &"is_open",
            ]:
                assert_true(
                    _script_has_method(pause_script, method_name),
                    "pause menu missing method: %s" % method_name
                )

    var packed := load(FLIGHT_ROOM_SCENE_PATH) as PackedScene
    assert_true(packed != null, "flight room must load for milestone integration")
    if packed != null:
        var room := packed.instantiate() as Node3D
        assert_true(room != null, "flight room must instantiate")
        if room != null:
            assert_true(
                room.get_node_or_null("FlightRoomSettingsCoordinator")
                is FlightRoomSettingsCoordinator,
                "flight room must own exactly one settings coordinator"
            )
            assert_true(
                room.get_node_or_null("PauseMenu") != null,
                "flight room must own exactly one pause menu"
            )
            room.free()

    var controller_source := FileAccess.get_file_as_string(
        FLIGHT_ROOM_CONTROLLER_PATH
    )
    assert_true(
        controller_source.contains("get_tree().paused = false"),
        "flight-room reset must explicitly clear pause before resetting"
    )

func _script_has_method(script: Script, method_name: StringName) -> bool:
    for method: Dictionary in script.get_script_method_list():
        if StringName(method.get("name", "")) == method_name:
            return true
    return false
