extends "res://tests/support/test_case.gd"

const COORDINATOR_SCRIPT_PATH := (
    "res://src/flight_room/flight_room_settings_coordinator.gd"
)

func run() -> void:
    assert_true(
        ResourceLoader.exists(COORDINATOR_SCRIPT_PATH),
        "flight room settings coordinator script must exist"
    )
    if not ResourceLoader.exists(COORDINATOR_SCRIPT_PATH):
        return

    var coordinator_script := load(COORDINATOR_SCRIPT_PATH) as Script
    assert_true(
        coordinator_script != null,
        "flight room settings coordinator script must load"
    )
    if coordinator_script == null:
        return

    assert_true(
        _script_has_method(coordinator_script, &"initialize"),
        "settings coordinator must expose initialize"
    )

    var coordinator := coordinator_script.new() as Node
    assert_true(
        coordinator != null,
        "settings coordinator script must instantiate as a Node"
    )
    if coordinator == null:
        return

    for property_name: StringName in [
        &"settings_service_path",
        &"camera_rig_path",
        &"flight_controller_path",
    ]:
        assert_true(
            _object_has_property(coordinator, property_name),
            "settings coordinator missing exported path: %s" % property_name
        )

    coordinator.free()

func _script_has_method(script: Script, method_name: StringName) -> bool:
    for method: Dictionary in script.get_script_method_list():
        if StringName(method.get("name", "")) == method_name:
            return true
    return false

func _object_has_property(object: Object, property_name: StringName) -> bool:
    for property: Dictionary in object.get_property_list():
        if StringName(property.get("name", "")) == property_name:
            return true
    return false
