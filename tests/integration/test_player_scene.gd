extends "res://tests/support/test_case.gd"

const PLAYER_SCENE_PATH := "res://scenes/player/player_interceptor.tscn"
const TUNING_RESOURCE_PATH := "res://config/flight/player_flight_tuning.tres"
const HERO_GLB_PATH := "res://assets/runtime/ships/player/small_sci_fi_fighter.glb"

func run() -> void:
    assert_true(
        ResourceLoader.exists(TUNING_RESOURCE_PATH),
        "player tuning resource must use a case-safe non-conflicting path"
    )
    assert_true(
        ResourceLoader.exists(HERO_GLB_PATH),
        "mandatory canonical fighter GLB must exist"
    )

    var has_exact_tuning_dependency := false
    var has_hero_glb_dependency := false
    for dependency: String in ResourceLoader.get_dependencies(PLAYER_SCENE_PATH):
        if dependency.ends_with(TUNING_RESOURCE_PATH):
            has_exact_tuning_dependency = true
        if dependency.ends_with(HERO_GLB_PATH):
            has_hero_glb_dependency = true
    assert_true(
        has_exact_tuning_dependency,
        "player scene must reference the exact case-safe tuning path"
    )
    assert_true(
        has_hero_glb_dependency,
        "player scene must reference the canonical fighter GLB"
    )

    var packed := load(PLAYER_SCENE_PATH) as PackedScene
    assert_true(packed != null, "player scene must load")
    if packed == null:
        return

    var player := packed.instantiate() as RigidBody3D
    assert_true(player != null, "player root must be RigidBody3D")
    if player == null:
        return

    assert_true(is_equal_approx(player.mass, 8500.0), "mass must be 8500 kg")
    assert_true(is_equal_approx(player.gravity_scale, 0.0), "gravity must be disabled")
    assert_true(is_equal_approx(player.linear_damp, 0.0), "linear damping must be zero")
    assert_true(is_equal_approx(player.angular_damp, 0.0), "angular damping must be zero")
    assert_true(player.continuous_cd, "continuous collision detection must be enabled")

    var collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    assert_true(collision != null, "collision required")
    if collision != null:
        var box := collision.shape as BoxShape3D
        assert_true(box != null, "player collision must remain a box")
        if box != null:
            assert_equal(
                box.size,
                Vector3(14.0, 3.8, 12.2),
                "collider must match canonical fighter envelope"
            )

    assert_true(
        player.get_node_or_null("PlayerInputSource") is PlayerInputSource,
        "input source required"
    )
    assert_true(
        player.get_node_or_null("ShipFlightController") is ShipFlightController,
        "flight controller required"
    )
    assert_true(player.get_node_or_null("VisualRoot") is Node3D, "VisualRoot required")

    var fighter := player.get_node_or_null(
        "VisualRoot/SmallSciFiFighter"
    ) as Node3D
    assert_true(fighter != null, "canonical runtime fighter required")
    if fighter != null:
        assert_true(
            fighter.transform.origin.is_equal_approx(Vector3.ZERO),
            "canonical fighter position must remain identity"
        )
        assert_true(
            fighter.transform.basis.x.is_equal_approx(Vector3.RIGHT)
            and fighter.transform.basis.y.is_equal_approx(Vector3.UP)
            and fighter.transform.basis.z.is_equal_approx(Vector3.BACK),
            "canonical fighter rotation and scale must remain identity"
        )

    assert_true(
        player.get_node_or_null("HeroShipModelAdapter") == null,
        "runtime model adapter must be removed"
    )
    assert_true(
        player.get_node_or_null("LeftEngineGlowAnchor") == null,
        "temporary left glow anchor must be removed"
    )
    assert_true(
        player.get_node_or_null("RightEngineGlowAnchor") == null,
        "temporary right glow anchor must be removed"
    )
    assert_true(
        player.get_node_or_null("ShipVisualController") == null,
        "rear-only visual controller must be removed"
    )
    assert_true(
        player.get_node_or_null("ShipThrusterVisualController")
        is ShipThrusterVisualController,
        "twelve-socket visual controller required"
    )
    assert_true(player.get_node_or_null("CameraTarget") is Node3D, "camera target required")
    assert_true(player.get_node_or_null("Visuals") == null, "procedural visual root must stay removed")

    var controller := player.get_node("ShipFlightController") as ShipFlightController
    assert_equal(controller.get_flight_mode(), FlightMode.Value.ASSISTED, "default mode")
    assert_true(is_equal_approx(controller.get_boost_amount(), 0.0), "default boost")
    assert_true(is_equal_approx(controller.get_boost_heat(), 0.0), "default boost heat")
    assert_true(is_equal_approx(controller.get_forward_thrust_amount(), 0.0), "default thrust telemetry")
    assert_true(
        controller.get_last_force_local().is_equal_approx(Vector3.ZERO),
        "final local force starts at zero"
    )
    assert_true(
        controller.get_last_torque_local().is_equal_approx(Vector3.ZERO),
        "final local torque starts at zero"
    )
    assert_true(not controller.is_boost_locked_out(), "boost starts unlocked")
    assert_true(
        is_equal_approx(controller.get_active_speed_limit(), 160.0),
        "normal envelope is active at spawn"
    )
    assert_true(
        is_equal_approx(controller.get_auto_bank_offset_degrees(), 0.0),
        "generated bank starts neutral"
    )

    var camera_packed := load("res://scenes/camera/chase_camera_rig.tscn") as PackedScene
    assert_true(camera_packed != null, "camera scene must load")
    if camera_packed != null:
        var camera_rig := camera_packed.instantiate() as ChaseCameraRig
        assert_true(camera_rig != null, "camera root must use ChaseCameraRig")
        if camera_rig != null:
            assert_equal(
                camera_rig.target_path,
                NodePath("../PlayerInterceptor/CameraTarget"),
                "camera must follow the ship-owned target anchor"
            )
            camera_rig.free()

    var hud_packed := load("res://scenes/ui/flight_hud.tscn") as PackedScene
    assert_true(hud_packed != null, "HUD scene must load")
    if hud_packed != null:
        var hud := hud_packed.instantiate() as FlightHud
        assert_true(hud != null, "HUD root must use FlightHud")
        if hud != null:
            for label_path: String in [
                "SafeArea/Layout/SpeedLabel",
                "SafeArea/Layout/ModeLabel",
                "SafeArea/Layout/BoostLabel",
                "SafeArea/Layout/HeatLabel",
                "SafeArea/Layout/EnvelopeLabel",
                "SafeArea/Layout/CaptureLabel",
                "SafeArea/Layout/ControlsLabel"
            ]:
                assert_true(
                    hud.get_node_or_null(label_path) is Label,
                    "missing HUD label: %s" % label_path
                )
            assert_equal(
                hud.camera_path,
                NodePath("../ChaseCameraRig/Camera3D"),
                "HUD must resolve the existing chase camera"
            )
            assert_equal(
                hud.nose_reticle_path,
                NodePath("NoseReticle"),
                "HUD must expose the fixed nose-reticle path"
            )
            assert_equal(
                hud.velocity_marker_path,
                NodePath("VelocityMarker"),
                "HUD must expose the true-velocity marker path"
            )
            assert_true(
                hud.get_node_or_null("NoseReticle") is Control,
                "fixed nose reticle required"
            )
            assert_true(
                hud.get_node_or_null("VelocityMarker") is Control,
                "true velocity marker required"
            )
            for segment_path: String in [
                "NoseReticle/Top",
                "NoseReticle/Bottom",
                "NoseReticle/Left",
                "NoseReticle/Right"
            ]:
                assert_true(
                    hud.get_node_or_null(segment_path) is ColorRect,
                    "missing nose-reticle segment: %s" % segment_path
                )
            hud.free()

    player.free()
