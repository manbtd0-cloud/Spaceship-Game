extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/flight_room/flight_room.tscn") as PackedScene
    assert_true(packed != null, "flight room must load")
    if packed == null:
        return

    var room := packed.instantiate() as Node3D
    assert_true(room != null, "flight room root must be Node3D")
    if room == null:
        return

    assert_true(room.get_node_or_null("PlayerInterceptor") is RigidBody3D, "player required")
    assert_true(room.get_node_or_null("ChaseCameraRig") is ChaseCameraRig, "camera required")
    assert_true(room.get_node_or_null("FlightHud") is FlightHud, "HUD required")
    assert_true(room.get_node_or_null("ResetVolume") is Area3D, "reset volume required")
    assert_true(room.get_node_or_null("FlightRoomController") is FlightRoomController, "room controller required")
    assert_true(room.get_node_or_null("Course/StartGate") is Node3D, "start gate required")
    assert_true(
        room.get_node("Course/NavigationRings").get_child_count() >= 9,
        "nine rings required"
    )
    assert_true(room.get_node("Course/Pylons").get_child_count() >= 6, "six pylons required")
    assert_true(room.get_node("Course/DriftMarkers").get_child_count() >= 10, "ten drift markers required")
    assert_true(
        room.get_node("Course/SpeedMarkers").get_child_count() >= 12,
        "twelve speed markers required"
    )
    assert_true(
        room.get_node("Course/DistantReferenceShapes").get_child_count() >= 8,
        "eight distant references required"
    )
    var last_ring := room.get_node("Course/NavigationRings/Ring09") as Node3D
    assert_true(last_ring.position.z <= -2400.0, "course must support boost-speed testing")
    var room_controller := room.get_node("FlightRoomController") as FlightRoomController
    assert_true(room_controller.boundary_radius >= 6000.0, "expanded boundary required")
    room.free()
