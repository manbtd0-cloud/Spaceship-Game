extends "res://tests/support/test_case.gd"

const PROJECTILE_SPEED := 900.0
const PHYSICS_STEP := 1.0 / 60.0

func run() -> void:
    var packed := load(
        "res://scenes/flight_room/flight_room.tscn"
    ) as PackedScene
    assert_true(packed != null, "combat flight room must load")
    if packed == null:
        return

    var room := packed.instantiate() as Node3D
    assert_true(room != null, "combat flight room root required")
    if room == null:
        return

    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test SceneTree required")
    if tree == null:
        room.free()
        return
    tree.root.add_child(room)

    var player := room.get_node_or_null(
        "PlayerInterceptor"
    ) as RigidBody3D
    var player_damage := room.get_node_or_null(
        "PlayerInterceptor/DamageState"
    ) as DamageState
    var player_collision := room.get_node_or_null(
        "PlayerInterceptor/CollisionDamageReceiver"
    ) as CollisionDamageReceiver
    var player_shield := room.get_node_or_null(
        "PlayerInterceptor/ShieldImpactVisualizer"
    ) as ShieldImpactVisualizer
    var pool := room.get_node_or_null(
        "PlayerInterceptor/PulseProjectilePool"
    ) as PulseProjectilePool
    var drone := room.get_node_or_null("PracticeDrone") as RigidBody3D
    var drone_damage := room.get_node_or_null(
        "PracticeDrone/DamageState"
    ) as DamageState
    var drone_shield := room.get_node_or_null(
        "PracticeDrone/ShieldImpactVisualizer"
    ) as ShieldImpactVisualizer
    var drone_controller := room.get_node_or_null(
        "PracticeDrone/PracticeDroneController"
    ) as PracticeDroneController
    var hud := room.get_node_or_null(
        "FlightHud/CombatHud"
    ) as CombatHud
    var room_controller := room.get_node_or_null(
        "FlightRoomController"
    ) as FlightRoomController

    assert_true(player != null, "combat player required")
    assert_true(player_damage != null, "player damage required")
    assert_true(player_collision != null, "player collision damage required")
    assert_true(player_shield != null, "player shield visual required")
    assert_true(pool != null, "production projectile pool required")
    assert_true(drone != null, "practice drone required")
    assert_true(drone_damage != null, "drone damage required")
    assert_true(drone_shield != null, "drone shield visual required")
    assert_true(drone_controller != null, "drone controller required")
    assert_true(hud != null, "combat HUD required")
    assert_true(room_controller != null, "room controller required")

    if (
        player == null
        or player_damage == null
        or player_collision == null
        or pool == null
        or drone == null
        or drone_damage == null
        or drone_shield == null
        or drone_controller == null
        or hud == null
        or room_controller == null
    ):
        tree.root.remove_child(room)
        room.free()
        return

    var projectile := pool.fire(
        Transform3D(
            Basis.IDENTITY,
            Vector3(0.0, 20.0, -170.0)
        ),
        Vector3.FORWARD * PROJECTILE_SPEED,
        player
    )
    assert_true(projectile != null, "pooled projectile must fire")
    if projectile != null:
        projectile.step_for_test(PHYSICS_STEP)

    assert_true(
        is_equal_approx(drone_damage.get_shield(), 105.0),
        "real projectile removes exactly fifteen drone shield"
    )
    assert_true(
        drone_shield.get_active_impact_count() == 1,
        "real shield hit activates one pooled impact"
    )
    assert_true(
        hud.get_hit_marker_alpha() > 0.0,
        "damage-confirmed projectile activates hit marker"
    )

    drone_damage.apply_damage(
        DamagePacket.create(
            300.0,
            DamagePacket.Kind.PROJECTILE,
            drone.global_position,
            Vector3.BACK,
            player.get_instance_id(),
            20
        )
    )
    assert_true(drone_controller.is_respawning(), "lethal hit starts respawn")
    assert_equal(drone.collision_layer, 0, "destroyed drone disables collision")
    drone_controller.step_for_test(3.1)
    assert_true(not drone_controller.is_respawning(), "drone respawns after three seconds")
    assert_true(
        is_equal_approx(drone_damage.get_shield(), 120.0),
        "respawn restores full drone shield"
    )
    assert_true(
        is_equal_approx(drone_damage.get_hull(), 150.0),
        "respawn restores full drone hull"
    )

    var wall := StaticBody3D.new()
    wall.name = "CollisionFixture"
    room.add_child(wall)
    player.linear_velocity = Vector3(30.0, 0.0, 0.0)
    var collision_result := player_collision.resolve_collision_for_test(
        wall,
        player.global_position,
        Vector3.LEFT,
        100
    )
    assert_true(collision_result != null, "high-speed collision applies damage")
    assert_true(
        is_equal_approx(player_damage.get_shield(), 114.0),
        "collision damage depletes player shield before hull"
    )
    assert_true(
        is_equal_approx(player_damage.get_hull(), 200.0),
        "player hull remains protected by shield"
    )

    room_controller.reset_player()
    assert_true(
        is_equal_approx(player_damage.get_shield(), 150.0),
        "room reset restores player shield"
    )
    assert_true(
        is_equal_approx(drone_damage.get_shield(), 120.0),
        "room reset restores drone shield"
    )

    player_damage.apply_damage(
        DamagePacket.create(
            400.0,
            DamagePacket.Kind.PROJECTILE,
            player.global_position,
            Vector3.BACK,
            drone.get_instance_id(),
            200
        )
    )
    assert_true(player.freeze, "player destruction freezes ship")
    assert_true(
        room_controller.get_player_respawn_remaining() > 0.0,
        "player destruction starts recovery countdown"
    )
    room_controller._physics_process(1.3)
    assert_true(not player.freeze, "player recovers after countdown")
    assert_true(
        is_equal_approx(player_damage.get_shield(), 150.0)
        and is_equal_approx(player_damage.get_hull(), 200.0),
        "player recovery restores full combat state"
    )

    tree.root.remove_child(room)
    room.free()
