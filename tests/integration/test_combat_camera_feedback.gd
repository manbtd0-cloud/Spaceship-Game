extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/flight_room/flight_room.tscn") as PackedScene
    assert_true(packed != null, "flight room must load with combat camera feedback")
    if packed == null:
        return
    var room := packed.instantiate() as Node3D
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(room)

    var feedback := room.get_node_or_null("CombatCameraFeedbackController") as CombatCameraFeedbackController
    var camera := room.get_node_or_null("ChaseCameraRig/Camera3D") as Camera3D
    var player := room.get_node_or_null("PlayerInterceptor") as RigidBody3D
    var enemy := room.get_node_or_null("EnemyFighter") as RigidBody3D
    var player_damage := room.get_node_or_null("PlayerInterceptor/DamageState") as DamageState
    var enemy_damage := room.get_node_or_null("EnemyFighter/DamageState") as DamageState

    assert_true(feedback != null and camera != null, "production combat camera feedback is wired")
    if feedback == null or camera == null or player == null or enemy == null or player_damage == null or enemy_damage == null:
        tree.root.remove_child(room)
        room.free()
        return

    feedback.reset_runtime_state()
    enemy_damage.apply_damage(DamagePacket.create(
        15.0,
        DamagePacket.Kind.PROJECTILE,
        enemy.global_position,
        Vector3.BACK,
        player.get_instance_id(),
        1
    ))
    assert_true(is_zero_approx(feedback.get_current_strength()), "ordinary enemy hit does not shake the player camera")

    var player_transform := player.global_transform
    var player_velocity := player.linear_velocity
    var player_angular_velocity := player.angular_velocity
    player_damage.apply_damage(DamagePacket.create(
        15.0,
        DamagePacket.Kind.PROJECTILE,
        player.global_position,
        Vector3.FORWARD,
        enemy.get_instance_id(),
        2
    ))
    assert_true(feedback.get_current_strength() > 0.0, "player damage requests camera feedback")
    feedback.step_for_test(1.0 / 60.0)
    assert_equal(player.global_transform, player_transform, "camera feedback never mutates player transform")
    assert_equal(player.linear_velocity, player_velocity, "camera feedback never mutates player velocity")
    assert_equal(player.angular_velocity, player_angular_velocity, "camera feedback never mutates player angular velocity")
    assert_true(not camera.transform.is_equal_approx(Transform3D.IDENTITY), "camera feedback is applied only to Camera3D local presentation transform")

    feedback.reset_runtime_state()
    var distance := player.global_position.distance_to(enemy.global_position)
    enemy_damage.apply_damage(DamagePacket.create(
        1000.0,
        DamagePacket.Kind.PROJECTILE,
        enemy.global_position,
        Vector3.BACK,
        player.get_instance_id(),
        3
    ))
    assert_true(distance < 700.0, "destruction fixture is within feedback range")
    assert_true(feedback.get_current_strength() > 0.0, "nearby hostile destruction produces restrained camera feedback")

    feedback.reset_runtime_state()
    assert_true(camera.transform.is_equal_approx(Transform3D.IDENTITY), "feedback reset clears all camera-local offset")

    tree.root.remove_child(room)
    room.free()
