extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/combat/enemy_fighter.tscn") as PackedScene
    assert_true(packed != null, "enemy fighter scene loads")
    if packed == null:
        return

    var enemy := packed.instantiate() as RigidBody3D
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(enemy)

    var flight := enemy.get_node_or_null("EnemyFighterController") as EnemyFighterController
    var visuals := enemy.get_node_or_null("EnemyThrusterVisualController") as EnemyThrusterVisualController
    assert_true(flight != null, "enemy flight controller required")
    assert_true(visuals != null, "enemy thruster presentation controller required")
    if flight == null or visuals == null:
        tree.root.remove_child(enemy)
        enemy.free()
        return

    assert_true(visuals.is_contract_valid(), "enemy resolves all canonical source-exact thruster effects")
    assert_equal(visuals.get_effect_count(), 12, "enemy presentation owns exactly twelve verified effects")
    assert_true(visuals.are_all_effects_hidden(), "enemy thrusters start invisible at zero physical output")

    visuals.set_test_wrench_for_test(
        -enemy.global_transform.basis.z * flight.tuning.forward_force,
        Vector3.ZERO
    )
    visuals.step_visuals(1.0)
    var active := visuals.get_active_effect_paths()
    assert_true(active.has("ThrusterEffects/MainEffects/MainLeftEffect"), "left main lights for real forward authority")
    assert_true(active.has("ThrusterEffects/MainEffects/MainRightEffect"), "right main lights for real forward authority")
    assert_equal(active.size(), 2, "pure forward authority lights no unrelated effects")
    assert_true(visuals.get_max_target() <= 1.000001, "visual target never exceeds physical authority")
    assert_true(visuals.are_effect_pivots_unchanged(), "source-exact nozzle pivots remain untouched")

    visuals.clear_test_wrench_for_test()
    visuals.step_visuals(1.0)
    assert_true(visuals.are_all_effects_hidden(), "zero physical output fades all enemy thrusters out")

    tree.root.remove_child(enemy)
    enemy.free()
