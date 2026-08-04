extends "res://tests/support/test_case.gd"

class QuietFlightRoomSettingsCoordinator:
    extends FlightRoomSettingsCoordinator

    var errors: Array[String] = []

    func _report_error(message: String) -> void:
        errors.append(message)

func run() -> void:
    _test_initial_application_live_updates_and_cleanup()
    _test_missing_dependency_safety()

func _test_initial_application_live_updates_and_cleanup() -> void:
    var settings_path := (
        "user://test_flight_room_coordinator_%d.cfg"
        % Time.get_ticks_usec()
    )
    _remove_settings_file(settings_path)

    var player_scene := load(
        "res://scenes/player/player_interceptor.tscn"
    ) as PackedScene
    var camera_scene := load(
        "res://scenes/camera/chase_camera_rig.tscn"
    ) as PackedScene
    assert_true(player_scene != null, "player scene must load")
    assert_true(camera_scene != null, "camera scene must load")
    if player_scene == null or camera_scene == null:
        return

    var fixture := Node3D.new()
    fixture.name = "FlightRoomSettingsCoordinatorFixture"

    var settings := PlayerSettingsStore.new()
    settings.name = "Settings"
    settings.load_from_path(settings_path)

    var player := player_scene.instantiate() as RigidBody3D
    var camera_rig := camera_scene.instantiate() as ChaseCameraRig
    assert_true(player != null, "player scene must instantiate")
    assert_true(camera_rig != null, "camera scene must instantiate")
    if player == null or camera_rig == null:
        if player != null:
            player.free()
        if camera_rig != null:
            camera_rig.free()
        settings.free()
        fixture.free()
        return

    var controller := player.get_node_or_null(
        "ShipFlightController"
    ) as ShipFlightController
    assert_true(controller != null, "flight controller must exist")
    if controller == null:
        player.free()
        camera_rig.free()
        settings.free()
        fixture.free()
        return

    assert_true(
        camera_rig.select_behavior(CameraBehavior.Value.DYNAMIC),
        "fixture must begin away from the persisted behavior"
    )
    assert_true(
        camera_rig.select_distance(CameraDistance.Value.FAR),
        "fixture must begin away from the persisted distance"
    )
    assert_true(
        controller.set_flight_mode(FlightMode.Value.MANUAL),
        "fixture must begin away from the persisted flight mode"
    )

    var coordinator := FlightRoomSettingsCoordinator.new()
    coordinator.name = "FlightRoomSettingsCoordinator"
    coordinator.settings_service_path = NodePath("../Settings")
    coordinator.camera_rig_path = NodePath("../ChaseCameraRig")
    coordinator.flight_controller_path = NodePath(
        "../PlayerInterceptor/ShipFlightController"
    )

    fixture.add_child(settings)
    fixture.add_child(player)
    fixture.add_child(camera_rig)
    fixture.add_child(coordinator)

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree == null:
        fixture.free()
        _remove_settings_file(settings_path)
        return
    tree.root.add_child(fixture)

    assert_true(
        coordinator.is_initialized(),
        "coordinator must initialize when dependencies are available"
    )
    assert_equal(
        camera_rig.get_selected_behavior(),
        CameraBehavior.Value.TACTICAL,
        "initial Tactical setting must apply to the camera"
    )
    assert_equal(
        camera_rig.get_selected_distance(),
        CameraDistance.Value.STANDARD,
        "initial Standard setting must apply to the camera"
    )
    assert_equal(
        controller.get_flight_mode(),
        FlightMode.Value.ASSISTED,
        "initial Assisted setting must apply to the controller"
    )

    assert_equal(
        settings.camera_behavior_changed.get_connections().size(),
        1,
        "camera behavior must have one coordinator connection"
    )
    assert_equal(
        settings.camera_distance_changed.get_connections().size(),
        1,
        "camera distance must have one coordinator connection"
    )
    assert_equal(
        settings.default_flight_mode_changed.get_connections().size(),
        1,
        "flight mode must have one coordinator connection"
    )

    assert_true(
        coordinator.initialize(),
        "repeated initialization must be a successful no-op"
    )
    assert_equal(
        settings.camera_behavior_changed.get_connections().size(),
        1,
        "repeated initialization must not duplicate behavior callbacks"
    )
    assert_equal(
        settings.camera_distance_changed.get_connections().size(),
        1,
        "repeated initialization must not duplicate distance callbacks"
    )
    assert_equal(
        settings.default_flight_mode_changed.get_connections().size(),
        1,
        "repeated initialization must not duplicate mode callbacks"
    )

    assert_true(
        settings.set_camera_behavior(CameraBehavior.Value.LOCKED),
        "behavior setting change must be accepted"
    )
    assert_equal(
        camera_rig.get_selected_behavior(),
        CameraBehavior.Value.LOCKED,
        "Locked setting must update the live camera"
    )

    assert_true(
        settings.set_camera_distance(CameraDistance.Value.FAR),
        "distance setting change must be accepted"
    )
    assert_equal(
        camera_rig.get_selected_distance(),
        CameraDistance.Value.FAR,
        "Far setting must update the live camera"
    )
    assert_equal(
        camera_rig.get_selected_behavior(),
        CameraBehavior.Value.LOCKED,
        "distance setting must not alter camera behavior"
    )

    assert_true(
        settings.set_default_flight_mode(FlightMode.Value.MANUAL),
        "flight setting change must be accepted"
    )
    assert_equal(
        controller.get_flight_mode(),
        FlightMode.Value.MANUAL,
        "Inertial setting must update the live controller"
    )

    fixture.remove_child(coordinator)
    coordinator.free()
    assert_equal(
        settings.camera_behavior_changed.get_connections().size(),
        0,
        "coordinator exit must disconnect behavior callbacks"
    )
    assert_equal(
        settings.camera_distance_changed.get_connections().size(),
        0,
        "coordinator exit must disconnect distance callbacks"
    )
    assert_equal(
        settings.default_flight_mode_changed.get_connections().size(),
        0,
        "coordinator exit must disconnect mode callbacks"
    )

    fixture.get_parent().remove_child(fixture)
    fixture.free()
    _remove_settings_file(settings_path)

func _test_missing_dependency_safety() -> void:
    var settings_path := (
        "user://test_flight_room_coordinator_missing_%d.cfg"
        % Time.get_ticks_usec()
    )
    _remove_settings_file(settings_path)

    var player_scene := load(
        "res://scenes/player/player_interceptor.tscn"
    ) as PackedScene
    assert_true(player_scene != null, "player scene must load for failure test")
    if player_scene == null:
        return

    var fixture := Node3D.new()
    fixture.name = "MissingCoordinatorDependencyFixture"

    var settings := PlayerSettingsStore.new()
    settings.name = "Settings"
    settings.load_from_path(settings_path)
    assert_true(
        settings.set_camera_behavior(CameraBehavior.Value.LOCKED),
        "failure fixture behavior must be configurable"
    )
    assert_true(
        settings.set_camera_distance(CameraDistance.Value.FAR),
        "failure fixture distance must be configurable"
    )
    assert_true(
        settings.set_default_flight_mode(FlightMode.Value.MANUAL),
        "failure fixture flight mode must be configurable"
    )

    var player := player_scene.instantiate() as RigidBody3D
    assert_true(player != null, "failure fixture player must instantiate")
    if player == null:
        settings.free()
        fixture.free()
        _remove_settings_file(settings_path)
        return

    var coordinator := QuietFlightRoomSettingsCoordinator.new()
    coordinator.name = "FlightRoomSettingsCoordinator"
    coordinator.settings_service_path = NodePath("../Settings")
    coordinator.camera_rig_path = NodePath("../MissingCameraRig")
    coordinator.flight_controller_path = NodePath(
        "../PlayerInterceptor/ShipFlightController"
    )

    fixture.add_child(settings)
    fixture.add_child(player)
    fixture.add_child(coordinator)

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "failure test SceneTree must exist")
    if tree == null:
        fixture.free()
        _remove_settings_file(settings_path)
        return
    tree.root.add_child(fixture)

    assert_true(
        not coordinator.is_initialized(),
        "missing gameplay dependency must leave coordinator disabled"
    )
    assert_equal(
        coordinator.errors.size(),
        1,
        "missing dependencies must report one consolidated error"
    )
    assert_true(
        not coordinator.initialize(),
        "repeated initialization must remain safely rejected"
    )
    assert_equal(
        coordinator.errors.size(),
        1,
        "repeated failure must not emit duplicate errors"
    )
    assert_equal(
        settings.get_camera_behavior(),
        CameraBehavior.Value.LOCKED,
        "missing camera must not corrupt valid behavior settings"
    )
    assert_equal(
        settings.get_camera_distance(),
        CameraDistance.Value.FAR,
        "missing camera must not corrupt valid distance settings"
    )
    assert_equal(
        settings.get_default_flight_mode(),
        FlightMode.Value.MANUAL,
        "missing camera must not corrupt valid flight settings"
    )
    assert_equal(
        settings.camera_behavior_changed.get_connections().size(),
        0,
        "failed initialization must not leave signal callbacks"
    )

    fixture.get_parent().remove_child(fixture)
    fixture.free()
    _remove_settings_file(settings_path)

func _remove_settings_file(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
