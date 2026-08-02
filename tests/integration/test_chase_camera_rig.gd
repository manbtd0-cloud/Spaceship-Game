extends "res://tests/support/test_case.gd"

func run() -> void:
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

    rig.cycle_preset()
    assert_equal(
        rig.get_selected_preset(),
        ChaseCameraRig.Preset.FAR,
        "Standard must cycle to Far"
    )
    rig.cycle_preset()
    assert_equal(
        rig.get_selected_preset(),
        ChaseCameraRig.Preset.CLOSE,
        "Far must cycle to Close"
    )
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

    fixture.get_parent().remove_child(fixture)
    fixture.free()
