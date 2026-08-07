extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/flight_room/flight_room.tscn") as PackedScene
    assert_true(packed != null, "flight room loads")
    if packed == null:
        return
    var room := packed.instantiate() as Node3D
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(room)

    var audio := room.get_node_or_null("CombatAudioController") as CombatAudioController
    assert_true(audio != null, "production room has combat audio controller")
    if audio == null:
        tree.root.remove_child(room)
        room.free()
        return
    assert_equal(audio.get_emitter_count(), 7, "combat audio uses a fixed emitter pool")

    var player_fire := room.get_node("PlayerInterceptor/PrimaryFireController") as PrimaryFireController
    player_fire.shot_fired.emit(PrimaryFireCadence.MuzzleSide.LEFT, Transform3D.IDENTITY)
    assert_equal(audio.get_event_count(&"player_pulse"), 1, "player shot routes to weapon audio")
    assert_equal(audio.get_emitter_count(), 7, "shot does not allocate another emitter")

    var enemy_damage := room.get_node("EnemyFighter/DamageState") as DamageState
    var enemy := room.get_node("EnemyFighter") as RigidBody3D
    enemy_damage.apply_damage(DamagePacket.create(15.0, DamagePacket.Kind.PROJECTILE, enemy.global_position, Vector3.BACK))
    assert_equal(audio.get_event_count(&"enemy_shield_hit"), 1, "shield hit routes to shield audio")

    var enemy_thrusters := room.get_node("EnemyFighter/EnemyThrusterVisualController") as EnemyThrusterVisualController
    var enemy_flight := room.get_node("EnemyFighter/EnemyFighterController") as EnemyFighterController
    enemy_thrusters.set_test_wrench_for_test(-enemy.global_transform.basis.z * enemy_flight.tuning.forward_force, Vector3.ZERO)
    enemy_thrusters.step_visuals(1.0)
    audio.step_for_test(0.1)
    assert_true(audio.get_thruster_level() > 0.9, "enemy thruster loop follows real presentation authority")

    enemy_damage.apply_damage(DamagePacket.create(1000.0, DamagePacket.Kind.PROJECTILE, enemy.global_position, Vector3.BACK))
    assert_equal(audio.get_event_count(&"enemy_explosion"), 1, "enemy destruction routes to layered explosion audio")
    assert_equal(audio.get_emitter_count(), 7, "destruction still uses fixed emitters")

    tree.root.remove_child(room)
    room.free()
