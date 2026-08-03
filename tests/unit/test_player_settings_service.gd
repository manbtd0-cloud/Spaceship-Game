extends "res://tests/support/test_case.gd"

func run() -> void:
    var path := "user://test_player_settings_%d.cfg" % Time.get_ticks_usec()
    var absolute_path := ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(absolute_path)

    var store := PlayerSettingsStore.new()
    var saved_events: Array[int] = []
    var behavior_events: Array[int] = []
    store.settings_saved.connect(func() -> void: saved_events.append(1))
    store.camera_behavior_changed.connect(
        func(value: CameraBehavior.Value) -> void:
            behavior_events.append(value)
    )

    store.load_from_path(path)
    assert_equal(
        store.get_camera_behavior(),
        CameraBehavior.Value.TACTICAL,
        "missing file must use Tactical"
    )
    assert_equal(
        store.get_camera_distance(),
        CameraDistance.Value.STANDARD,
        "missing file must use Standard"
    )
    assert_equal(
        store.get_default_flight_mode(),
        FlightMode.Value.ASSISTED,
        "missing file must use Assisted"
    )
    assert_true(
        not FileAccess.file_exists(path),
        "loading a missing file must not write defaults immediately"
    )

    assert_true(
        store.set_camera_behavior(CameraBehavior.Value.LOCKED),
        "changed valid value must be accepted"
    )
    assert_equal(saved_events.size(), 1, "one real change saves exactly once")
    assert_equal(
        behavior_events,
        [CameraBehavior.Value.LOCKED],
        "one real change emits one typed behavior event"
    )
    assert_true(
        not store.set_camera_behavior(CameraBehavior.Value.LOCKED),
        "setting an identical value must be a no-op"
    )
    assert_equal(saved_events.size(), 1, "no-op must not save")
    assert_equal(behavior_events.size(), 1, "no-op must not emit")
    assert_true(
        not store.set_camera_behavior(999),
        "invalid camera behavior must be rejected"
    )
    assert_equal(
        store.get_camera_behavior(),
        CameraBehavior.Value.LOCKED,
        "invalid setter input must preserve the current value"
    )

    var reloaded := PlayerSettingsStore.new()
    reloaded.load_from_path(path)
    assert_equal(
        reloaded.get_camera_behavior(),
        CameraBehavior.Value.LOCKED,
        "valid value must round-trip"
    )

    var corrupt := ConfigFile.new()
    corrupt.set_value("camera", "behavior", 999)
    corrupt.set_value(
        "camera",
        "distance",
        CameraDistance.Value.FAR
    )
    corrupt.set_value(
        "flight",
        "default_mode",
        FlightMode.Value.MANUAL
    )
    assert_equal(corrupt.save(path), OK, "corrupt fixture must save")

    var repaired := PlayerSettingsStore.new()
    repaired.load_from_path(path)
    assert_equal(
        repaired.get_camera_behavior(),
        CameraBehavior.Value.TACTICAL,
        "invalid behavior falls back individually"
    )
    assert_equal(
        repaired.get_camera_distance(),
        CameraDistance.Value.FAR,
        "valid distance survives another field's corruption"
    )
    assert_equal(
        repaired.get_default_flight_mode(),
        FlightMode.Value.MANUAL,
        "valid flight mode survives another field's corruption"
    )

    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(absolute_path)
    store.free()
    reloaded.free()
    repaired.free()
