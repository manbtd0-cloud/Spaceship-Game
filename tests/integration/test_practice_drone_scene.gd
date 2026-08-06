extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load(
        "res://scenes/combat/practice_drone.tscn"
    ) as PackedScene
    assert_true(packed != null, "practice drone scene must load")
    if packed == null:
        return

    var drone := packed.instantiate() as RigidBody3D
    assert_true(drone != null, "practice drone root must be RigidBody3D")
    if drone == null:
        return

    assert_true(is_equal_approx(drone.mass, 1600.0), "drone mass is exact")
    assert_true(is_zero_approx(drone.gravity_scale), "drone has no gravity")
    assert_true(drone.continuous_cd, "drone uses continuous collision detection")
    assert_true(drone.contact_monitor, "drone reports contacts")
    assert_true(drone.max_contacts_reported >= 8, "drone reports enough contacts")

    var collision := drone.get_node_or_null(
        "CollisionShape3D"
    ) as CollisionShape3D
    assert_true(collision != null, "drone collider required")
    if collision != null:
        var sphere := collision.shape as SphereShape3D
        assert_true(sphere != null, "drone collider must be spherical")
        if sphere != null:
            assert_true(
                is_equal_approx(sphere.radius, 2.4),
                "drone collider radius is exact"
            )

    assert_true(drone.get_node_or_null("VisualRoot") is Node3D, "visual root required")
    assert_true(
        drone.get_node_or_null("CollisionDamageReceiver") is CollisionDamageReceiver,
        "collision damage receiver required"
    )
    var damage := drone.get_node_or_null("DamageState") as DamageState
    assert_true(damage != null, "drone DamageState required")
    if damage != null and damage.tuning != null:
        assert_true(
            is_equal_approx(damage.tuning.maximum_shield, 120.0),
            "drone shield tuning is exact"
        )
        assert_true(
            is_equal_approx(damage.tuning.maximum_hull, 150.0),
            "drone hull tuning is exact"
        )
        assert_true(
            not damage.tuning.hull_repair_enabled,
            "drone hull never repairs"
        )

    var shield := drone.get_node_or_null(
        "ShieldImpactVisualizer"
    ) as ShieldImpactVisualizer
    assert_true(shield != null, "drone shield visual required")
    if shield != null:
        assert_equal(
            shield.ellipsoid_radii,
            Vector3(3.2, 2.4, 3.2),
            "drone shield ellipsoid is exact"
        )

    var controller := drone.get_node_or_null(
        "PracticeDroneController"
    ) as PracticeDroneController
    assert_true(controller != null, "drone controller required")
    if controller != null:
        assert_true(controller.tuning != null, "drone tuning required")
        if controller.tuning != null:
            assert_true(
                is_equal_approx(controller.tuning.respawn_delay, 3.0),
                "drone respawn delay is exact"
            )

    assert_true(
        drone.get_node_or_null("DestructionPulse") is MeshInstance3D,
        "destruction pulse required"
    )
    drone.free()
