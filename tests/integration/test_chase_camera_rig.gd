extends "res://tests/support/test_case.gd"

func run() -> void:
    _test_all_preset_hard_limits()

    var fixture := Node3D.new()
    fixture.name = "CameraFixture"

    var player_scene := load(
        "res://scenes/player/player_interceptor.tscn"
    ) as PackedScene
    var camera_scene := load(
        "res://scenes/camera/chase_camera_rig.tscn"
    ) as PackedScene
    assert_true(player_scene != null, "player scene must load")
    assert_true(camera_scene != null, "camera scene must load")
    if player_scene == null or camera_scene == null:
        fixture.free()
        return

    var player := player_scene.instantiate() as RigidBody3D
    var rig := camera_scene.instantiate() as ChaseCameraRig
    assert_true(player != null, "player scene must instantiate")
    assert_true(rig != null, "camera scene must instantiate")
    if player == null or rig == null:
        if player != null:
            player.free()
        if rig != null:
            rig.free()
        fixture.free()
        return

    fixture.add_child(player)
    fixture.add_child(rig)
    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree == null:
        fixture.free()
        return
    tree.root.add_child(fixture)

    assert_equal(
        rig.get_selected_preset(),
        ChaseCameraRig.Preset.STANDARD,
        "camera must start in Standard"
    )
    assert_equal(
        rig.get_selected_preset_name(),
        &"standard",
        "initial preset name must be standard"
    )
    assert_equal(
        rig.get_temporary_view(),
        ChaseCameraRig.TemporaryView.NONE,
        "Camera C0 temporary view must begin at NONE"
    )

    var initial := rig.get_current_framing()
    assert_true(
        is_equal_approx(float(initial["rear_offset"]), 14.0),
        "Standard rear offset must initialize exactly"
    )
    assert_true(
        is_equal_approx(float(initial["height"]), 4.0),
        "Standard height must initialize exactly"
    )

    rig.cycle_preset()
    assert_equal(
        rig.get_selected_preset(),
        ChaseCameraRig.Preset.FAR,
        "Standard must cycle to Far"
    )
    var far_before := rig.get_current_framing()
    rig.step_camera_for_test(0.05)
    var far_after := rig.get_current_framing()
    assert_true(
        float(far_after["rear_offset"]) > float(far_before["rear_offset"]),
        "Far transition must increase rear offset"
    )
    assert_true(
        float(far_after["rear_offset"]) < 20.0,
        "Far transition must not snap"
    )
    assert_true(
        float(far_after["height"]) > float(far_before["height"]),
        "Far transition must increase height"
    )
    assert_true(
        float(far_after["hard_rear_limit"]) <= 27.0,
        "Far transition must remain bounded"
    )

    rig.cycle_preset()
    assert_equal(
        rig.get_selected_preset(),
        ChaseCameraRig.Preset.CLOSE,
        "Far must cycle to Close"
    )
    var previous_rear := float(rig.get_current_framing()["rear_offset"])
    for _index: int in range(8):
        rig.step_camera_for_test(0.05)
        var close_frame := rig.get_current_framing()
        var current_rear := float(close_frame["rear_offset"])
        assert_true(
            current_rear <= previous_rear + 0.0001,
            "Close transition must decrease monotonically"
        )
        assert_true(
            current_rear <= float(close_frame["hard_rear_limit"]) + 0.0001,
            "rear offset must never exceed current hard limit"
        )
        previous_rear = current_rear

    rig.cycle_preset()
    assert_equal(
        rig.get_selected_preset(),
        ChaseCameraRig.Preset.STANDARD,
        "Close must cycle to Standard"
    )

    rig.select_preset(999)
    assert_equal(
        rig.get_selected_preset(),
        ChaseCameraRig.Preset.STANDARD,
        "invalid preset state must recover to Standard"
    )

    rig.select_preset(ChaseCameraRig.Preset.FAR)
    var selected_before_reset := rig.get_selected_preset()
    var flight_controller := player.get_node(
        "ShipFlightController"
    ) as ShipFlightController
    assert_true(
        flight_controller != null,
        "player must expose ShipFlightController"
    )
    if flight_controller != null:
        flight_controller.reset_runtime_state()
        assert_equal(
            rig.get_selected_preset(),
            selected_before_reset,
            "flight reset must preserve selected camera preset"
        )

    fixture.get_parent().remove_child(fixture)
    fixture.free()

func _test_all_preset_hard_limits() -> void:
    var presets: Array[Dictionary] = [
        {
            "name": "Close",
            "rear": 10.5,
            "height": 3.2,
            "pullback": 3.5,
            "limit": 14.0,
        },
        {
            "name": "Standard",
            "rear": 14.0,
            "height": 4.0,
            "pullback": 5.0,
            "limit": 19.0,
        },
        {
            "name": "Far",
            "rear": 20.0,
            "height": 5.0,
            "pullback": 7.0,
            "limit": 27.0,
        },
    ]

    for preset: Dictionary in presets:
        var result := ChaseCameraMath.desired_position(
            Transform3D.IDENTITY,
            Vector3(0.0, 0.0, -240.0),
            float(preset["rear"]),
            float(preset["height"]),
            0.05,
            float(preset["pullback"]),
            float(preset["limit"])
        )
        assert_true(
            result.z > 0.0,
            "%s camera must remain behind the ship" % String(preset["name"])
        )
        assert_true(
            result.z <= float(preset["limit"]) + 0.0001,
            "%s camera must respect its hard rear limit" % String(preset["name"])
        )
