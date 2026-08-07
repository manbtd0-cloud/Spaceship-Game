extends "res://tests/support/test_case.gd"
func run()->void:
 var p:=load("res://scenes/flight_room/flight_room.tscn") as PackedScene;assert_true(p!=null,"room loads");if p==null:return
 var room:=p.instantiate() as Node3D;var tree:=Engine.get_main_loop() as SceneTree;tree.root.add_child(room);var player:=room.get_node("PlayerInterceptor") as RigidBody3D;var enemy:=room.get_node_or_null("EnemyFighter") as RigidBody3D;assert_true(enemy!=null,"one enemy fighter");assert_true(room.get_node_or_null("PracticeDrone")==null,"no active practice drone")
 var ec:=room.get_node_or_null("EnemyFighter/EnemyFighterController") as EnemyFighterController;var ed:=room.get_node_or_null("EnemyFighter/DamageState") as DamageState;var ep:=room.get_node_or_null("EnemyFighter/PulseProjectilePool") as PulseProjectilePool;var pp:=room.get_node_or_null("PlayerInterceptor/PulseProjectilePool") as PulseProjectilePool;var pd:=room.get_node_or_null("PlayerInterceptor/DamageState") as DamageState;var rc:=room.get_node("FlightRoomController") as FlightRoomController;assert_true(ec!=null and ed!=null and ep!=null,"enemy runtime")
 ec.step_for_test(1.0/60.0);assert_true(ec.get_last_force_world().length()>0,"enemy acquires and moves")
 var shot:=ep.fire(Transform3D(Basis.IDENTITY,Vector3(0,0,-10)),Vector3.BACK*PulseProjectile.DEFAULT_SPEED,enemy);assert_true(shot!=null,"enemy pool launches")
 ed.apply_damage(DamagePacket.create(1000,DamagePacket.Kind.PROJECTILE,enemy.global_position,Vector3.BACK,player.get_instance_id(),20));assert_true(ec.is_respawning(),"enemy destruction");ec.step_for_test(ec.tuning.respawn_delay+.1);assert_true(not ec.is_respawning(),"enemy respawn")
 rc.reset_player();assert_equal(ep.get_active_count(),0,"enemy pool cleared");assert_equal(pp.get_active_count(),0,"player pool cleared");assert_true(is_equal_approx(pd.get_shield(),pd.tuning.maximum_shield),"player reset")
 tree.root.remove_child(room);room.free()
