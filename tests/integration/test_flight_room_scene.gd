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

    var fixture_model := _make_test_model()
    var controller := room.get_node("FlightRoomController") as FlightRoomController
    var built := controller.setup_asteroid_field({
        &"bennu": fixture_model,
        &"eros": fixture_model,
        &"legacy_a": fixture_model,
        &"legacy_b": fixture_model,
    })
    assert_true(built, "flight room must build the asteroid field")
    assert_true(
        room.get_node_or_null("Course/DistantReferenceShapes") == null,
        "blue box reference placeholders must be removed"
    )
    var field := room.get_node_or_null("Course/AsteroidField") as AsteroidField
    assert_true(field != null, "flight room must contain AsteroidField")
    if field != null:
        assert_equal(field.get_asteroid_count(), 16, "flight room must contain sixteen asteroids")
        assert_true(
            field.are_all_asteroids_collidable(),
            "every flight-room asteroid must be collidable"
        )

    var last_ring := room.get_node("Course/NavigationRings/Ring09") as Node3D
    assert_true(last_ring.position.z <= -2400.0, "course must support boost-speed testing")
    assert_true(controller.boundary_radius >= 6000.0, "expanded boundary required")
    room.free()

func _make_test_model() -> PackedScene:
    var root := Node3D.new()
    root.name = "FixtureAsteroid"

    var visual := MeshInstance3D.new()
    visual.name = "VisualModel"
    visual.mesh = SphereMesh.new()
    root.add_child(visual)
    visual.owner = root

    var imported_body := StaticBody3D.new()
    imported_body.name = "CollisionProxy"
    root.add_child(imported_body)
    imported_body.owner = root

    var imported_collision := CollisionShape3D.new()
    imported_collision.name = "CollisionShape3D"
    imported_collision.shape = SphereShape3D.new()
    imported_body.add_child(imported_collision)
    imported_collision.owner = root

    var fixture := PackedScene.new()
    var result := fixture.pack(root)
    assert_true(result == OK, "flight-room asteroid fixture must pack")
    root.free()
    return fixture
