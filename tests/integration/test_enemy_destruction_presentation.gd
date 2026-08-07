extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/combat/enemy_fighter.tscn") as PackedScene
    assert_true(packed != null, "enemy fighter scene loads")
    if packed == null:
        return
    var enemy := packed.instantiate() as RigidBody3D
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(enemy)

    var damage := enemy.get_node("DamageState") as DamageState
    var flight := enemy.get_node("EnemyFighterController") as EnemyFighterController
    var presentation := enemy.get_node_or_null("EnemyDestructionPresentationController") as EnemyDestructionPresentationController
    var visual_root := enemy.get_node("VisualRoot") as Node3D
    assert_true(presentation != null, "enemy has staged destruction presentation")
    if presentation == null:
        tree.root.remove_child(enemy)
        enemy.free()
        return

    enemy.linear_velocity = Vector3(20.0, 2.0, -30.0)
    presentation.capture_live_state_for_test()
    damage.apply_damage(DamagePacket.create(1000.0, DamagePacket.Kind.PROJECTILE, enemy.global_position, Vector3.BACK))
    assert_true(presentation.is_active(), "lethal damage starts presentation")
    assert_equal(presentation.get_stage(), EnemyDestructionTimeline.Stage.BUILDUP, "starts in buildup")
    assert_true(visual_root.visible, "fighter remains visible during rupture buildup")

    presentation.step_for_test(0.25)
    assert_equal(presentation.get_stage(), EnemyDestructionTimeline.Stage.BLAST, "core blast stage is reached")
    assert_true(not visual_root.visible, "fighter silhouette yields to the blast")
    assert_true(presentation.get_core_energy() > 0.0, "core detonation is visible")
    assert_true(presentation.get_visible_debris_count() > 0, "bounded debris launches on core blast")
    assert_true(presentation.get_source_velocity().is_equal_approx(Vector3(20.0, 2.0, -30.0)), "debris presentation inherits cached ship momentum")

    presentation.step_for_test(1.3)
    assert_true(not presentation.is_active(), "temporary destruction presentation self-cleans before respawn")
    assert_equal(presentation.get_visible_debris_count(), 0, "debris pool self-cleans")

    flight.step_for_test(flight.tuning.respawn_delay + 0.1)
    assert_true(visual_root.visible, "existing respawn restores fighter visuals")
    assert_true(not presentation.is_active(), "respawn leaves presentation clean")

    tree.root.remove_child(enemy)
    enemy.free()
