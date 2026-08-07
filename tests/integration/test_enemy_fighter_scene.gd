extends "res://tests/support/test_case.gd"
func run()->void:
 var p:=load("res://scenes/combat/enemy_fighter.tscn") as PackedScene;assert_true(p!=null,"enemy scene loads");if p==null:return
 var e:=p.instantiate() as RigidBody3D;var tree:=Engine.get_main_loop() as SceneTree;tree.root.add_child(e);var c:=e.get_node_or_null("EnemyFighterController") as EnemyFighterController;var d:=e.get_node_or_null("DamageState") as DamageState;assert_true(c!=null and d!=null,"enemy components");assert_true(is_equal_approx(e.mass,6500),"mass")
 var target:=RigidBody3D.new();target.position=Vector3(0,0,-500);tree.root.add_child(target);c.set_target(target);var tr:=e.global_transform;var lv:=e.linear_velocity;c.step_for_test(1.0/60.0);assert_equal(e.global_transform,tr,"no transform warp");assert_equal(e.linear_velocity,lv,"no velocity warp");assert_true(c.get_last_force_world().is_finite() and c.get_last_torque_world().is_finite(),"finite outputs")
 target.global_position=Vector3(0,0,500);e.linear_velocity=Vector3.ZERO;e.angular_velocity=Vector3.ZERO;c.step_for_test(1.0/60.0);assert_true(c.get_last_torque_world().length()>0,"antiparallel turn")
 d.apply_damage(DamagePacket.create(1000,DamagePacket.Kind.PROJECTILE,e.global_position,Vector3.BACK,target.get_instance_id(),50));assert_true(c.is_respawning(),"respawn starts");c.step_for_test(c.tuning.respawn_delay+.1);assert_true(not c.is_respawning(),"respawn ends");assert_equal(c.get_tactical_state(),EnemyDogfightState.Value.ACQUIRE,"state reset")
 tree.root.remove_child(target);target.free();tree.root.remove_child(e);e.free()
