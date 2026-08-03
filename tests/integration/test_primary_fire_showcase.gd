extends "res://tests/support/test_case.gd"

const SHOWCASE_SCENE_PATH := "res://scenes/debug/primary_fire_showcase.tscn"

func run() -> void:
    var packed := load(SHOWCASE_SCENE_PATH) as PackedScene
    assert_true(packed != null, "primary fire showcase scene must load")
    if packed == null:
        return

    var showcase := packed.instantiate() as PrimaryFireShowcaseController
    assert_true(
        showcase != null,
        "showcase root must use PrimaryFireShowcaseController"
    )
    if showcase == null:
        return

    assert_true(
        showcase.get_node_or_null("PlayerInterceptor") is RigidBody3D,
        "production player required"
    )
    assert_true(
        showcase.get_node_or_null("ChaseCameraRig") is ChaseCameraRig,
        "production chase camera required"
    )
    assert_true(
        showcase.get_node_or_null("PulseProjectilePool") is PulseProjectilePool,
        "production projectile pool required"
    )
    assert_true(
        showcase.get_node_or_null("PlayerInterceptor/PrimaryFireController")
        is PrimaryFireController,
        "production primary fire controller required"
    )
    assert_true(
        showcase.get_node_or_null("FiringLane/ImpactWall") is StaticBody3D,
        "non-damageable impact wall required"
    )
    var rings := showcase.get_node_or_null("FiringLane/DepthRings") as Node3D
    assert_true(rings != null, "firing-lane depth-ring root required")
    if rings != null:
        assert_true(
            rings.get_child_count() >= 4,
            "at least four depth rings required"
        )
    assert_true(
        showcase.get_node_or_null("ShowcaseHud/SafeArea/Instructions") is Label,
        "showcase instructions required"
    )
    assert_true(
        showcase.get_node_or_null("ShowcaseHud/SafeArea/Telemetry") is Label,
        "showcase telemetry required"
    )

    var fire := showcase.get_node(
        "PlayerInterceptor/PrimaryFireController"
    ) as PrimaryFireController
    assert_equal(fire.body_path, NodePath(".."), "fire body path must target player")
    assert_equal(
        fire.input_source_path,
        NodePath("../PlayerInputSource"),
        "fire input path must target production input source"
    )
    assert_equal(
        fire.model_path,
        NodePath("../VisualRoot/SmallSciFiFighter"),
        "fire model path must target canonical fighter"
    )

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree required")
    if tree == null:
        showcase.free()
        return

    tree.root.add_child(showcase)
    showcase.initialize()

    var body := showcase.get_node("PlayerInterceptor") as RigidBody3D
    var input_source := showcase.get_node(
        "PlayerInterceptor/PlayerInputSource"
    ) as PlayerInputSource
    var pool := showcase.get_node("PulseProjectilePool") as PulseProjectilePool

    assert_true(body.freeze, "showcase fighter must remain stationary")
    assert_true(
        not input_source.is_mouse_captured(),
        "showcase must keep mouse visible"
    )
    assert_true(fire.is_firing_enabled(), "showcase firing must be enabled")

    fire.step_for_test(true, 0.0)
    assert_equal(
        pool.get_active_count(),
        1,
        "first held step must visibly spawn one projectile"
    )
    assert_equal(showcase.get_shot_count(), 1, "showcase must count emitted shots")
    assert_equal(
        showcase.get_last_side_name(),
        "LEFT",
        "first visible shot must use left muzzle"
    )

    showcase.reset_showcase()
    assert_equal(pool.get_active_count(), 0, "reset must clear projectiles")
    assert_equal(showcase.get_shot_count(), 0, "reset must clear shot count")
    assert_equal(
        showcase.get_resolved_count(),
        0,
        "reset must clear resolved count"
    )
    assert_equal(
        showcase.get_last_side_name(),
        "NONE",
        "reset must restore neutral side telemetry"
    )

    showcase.free()
