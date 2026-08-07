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
    var shield := enemy.get_node("ShieldImpactVisualizer") as ShieldImpactVisualizer
    var hull := enemy.get_node_or_null("HullImpactVisualizer") as HullImpactVisualizer
    assert_true(hull != null, "production enemy has hull impact presentation")
    if hull == null:
        tree.root.remove_child(enemy)
        enemy.free()
        return

    damage.apply_damage(DamagePacket.create(15.0, DamagePacket.Kind.PROJECTILE, enemy.global_position + Vector3.RIGHT * 4.0, Vector3.LEFT))
    assert_equal(shield.get_active_impact_count(), 1, "shield hit activates localized hex presentation")
    assert_equal(hull.get_active_burst_count(), 0, "shield-only damage does not emit hull sparks")

    damage.apply_damage(DamagePacket.create(135.0, DamagePacket.Kind.PROJECTILE, enemy.global_position, Vector3.BACK))
    hull.reset_visuals()
    damage.apply_damage(DamagePacket.create(15.0, DamagePacket.Kind.PROJECTILE, enemy.global_position + Vector3.UP, Vector3.DOWN))
    assert_equal(hull.get_active_burst_count(), 1, "hull damage emits one bounded directional burst")
    assert_true(hull.get_last_energy() >= 0.49, "ordinary hull pulse remains visually readable")

    for index in range(8):
        damage.apply_damage(DamagePacket.create(1.0, DamagePacket.Kind.PROJECTILE, enemy.global_position, Vector3.FORWARD))
    assert_true(hull.get_active_burst_count() <= HullImpactVisualizer.IMPACT_SLOT_COUNT, "rapid hits remain inside fixed presentation pool")

    hull.reset_visuals()
    damage.set_damage_enabled(false)
    damage.apply_damage(DamagePacket.create(10.0, DamagePacket.Kind.PROJECTILE, enemy.global_position, Vector3.FORWARD))
    assert_equal(hull.get_active_burst_count(), 0, "ignored damage creates no false hull presentation")

    tree.root.remove_child(enemy)
    enemy.free()
