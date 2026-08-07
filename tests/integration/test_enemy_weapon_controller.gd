extends "res://tests/support/test_case.gd"
func run()->void:
 var p:=load("res://scenes/combat/enemy_fighter.tscn") as PackedScene;var e:=p.instantiate() as RigidBody3D;var tree:=Engine.get_main_loop() as SceneTree;e.position=Vector3.ZERO;tree.root.add_child(e)
 var target:=RigidBody3D.new();target.position=Vector3(0,0,-300);var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=3;shape.shape=sphere;target.add_child(shape);tree.root.add_child(target)
 var w:=e.get_node("EnemyWeaponController") as EnemyWeaponController;var pool:=e.get_node("PulseProjectilePool") as PulseProjectilePool;w.set_target(target);w.step_for_test(0);assert_true(w.has_legal_firing_solution(),"aligned solution legal");assert_equal(pool.get_active_count(),1,"fires pooled projectile")
 pool.clear_all();target.global_position=Vector3(300,0,0);w.reset_runtime_state();w.step_for_test(0);assert_true(not w.has_legal_firing_solution(),"outside cone blocked")
 target.global_position=Vector3(0,0,-300);pool.clear_all();w.reset_runtime_state();var blocker:=StaticBody3D.new();blocker.position=Vector3(0,0,-150);blocker.collision_layer=2;var bs:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,20,20);bs.shape=box;blocker.add_child(bs);tree.root.add_child(blocker);w.step_for_test(0);assert_true(not w.has_legal_firing_solution(),"all-layer LOS blocker")
 tree.root.remove_child(blocker);blocker.free();tree.root.remove_child(target);target.free();tree.root.remove_child(e);e.free()
