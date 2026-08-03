extends "res://tests/support/test_case.gd"

const PROJECTILE_SPEED := 900.0
const PROJECTILE_DAMAGE := 15.0
const PHYSICS_STEP := 1.0 / 60.0

func run() -> void:
    _test_high_speed_sweep_hits_damageable_and_excludes_source()
    _test_wall_hit_resolves_without_damage_confirmation()
    _test_pool_recycles_oldest_and_clear_resets_all()
    _test_lifetime_deactivates_projectile()
    _test_primary_fire_controller_uses_muzzle_and_inherited_velocity()

func _test_high_speed_sweep_hits_damageable_and_excludes_source() -> void:
    var fixture := Node3D.new()
    fixture.name = "ProjectileSweepFixture"

    var source := _make_source_body()
    fixture.add_child(source)

    var target := _make_target_body(Vector3(0.0, 0.0, -7.5), true)
    fixture.add_child(target)

    var pool := PulseProjectilePool.new()
    pool.name = "PulseProjectilePool"
    fixture.add_child(pool)
    _attach_fixture(fixture)
    pool.initialize()

    var resolutions: Array[Dictionary] = []
    pool.projectile_resolved.connect(
        func(
            projectile: PulseProjectile,
            result: DamageResult,
            hit_damageable: bool
        ) -> void:
            resolutions.append({
                "projectile": projectile,
                "result": result,
                "hit_damageable": hit_damageable,
            })
    )

    var projectile := pool.fire(
        Transform3D.IDENTITY,
        Vector3.FORWARD * PROJECTILE_SPEED,
        source
    )
    assert_true(projectile != null, "pool must return a projectile")
    if projectile != null:
        projectile.step_for_test(PHYSICS_STEP)

    var damage_state := target.get_node("DamageState") as DamageState
    assert_true(
        is_equal_approx(damage_state.get_shield(), 135.0),
        "900 m/s swept projectile must apply exactly fifteen damage"
    )
    assert_true(
        projectile != null and not projectile.is_active(),
        "projectile must deactivate on its first collision"
    )
    assert_equal(resolutions.size(), 1, "projectile must resolve exactly once")
    if resolutions.size() == 1:
        assert_true(
            bool(resolutions[0]["hit_damageable"]),
            "damageable collision must be marked confirmed"
        )
        var result := resolutions[0]["result"] as DamageResult
        assert_true(result != null, "damageable collision must return DamageResult")
        if result != null:
            assert_true(
                is_equal_approx(result.applied_amount, PROJECTILE_DAMAGE),
                "damage result must record exact projectile damage"
            )

    _detach_fixture(fixture)

func _test_wall_hit_resolves_without_damage_confirmation() -> void:
    var fixture := Node3D.new()
    var source := _make_source_body()
    fixture.add_child(source)
    fixture.add_child(_make_target_body(Vector3(0.0, 0.0, -5.0), false))

    var pool := PulseProjectilePool.new()
    fixture.add_child(pool)
    _attach_fixture(fixture)
    pool.initialize()

    var confirmed := [true]
    var result_seen := [DamageResult.new()]
    pool.projectile_resolved.connect(
        func(
            _projectile: PulseProjectile,
            result: DamageResult,
            hit_damageable: bool
        ) -> void:
            confirmed[0] = hit_damageable
            result_seen[0] = result
    )

    var projectile := pool.fire(
        Transform3D.IDENTITY,
        Vector3.FORWARD * PROJECTILE_SPEED,
        source
    )
    projectile.step_for_test(PHYSICS_STEP)

    assert_true(not projectile.is_active(), "wall hit must clean up projectile")
    assert_true(not confirmed[0], "wall hit must not confirm damage")
    assert_true(result_seen[0] == null, "wall hit must not fabricate DamageResult")

    _detach_fixture(fixture)

func _test_pool_recycles_oldest_and_clear_resets_all() -> void:
    var fixture := Node3D.new()
    var source := _make_source_body()
    fixture.add_child(source)
    var pool := PulseProjectilePool.new()
    fixture.add_child(pool)
    _attach_fixture(fixture)
    pool.initialize()

    assert_equal(pool.get_projectile_count(), 32, "pool must prewarm exactly 32 projectiles")

    var first: PulseProjectile
    for index: int in range(32):
        var projectile := pool.fire(
            Transform3D(Basis.IDENTITY, Vector3(float(index), 50.0, 0.0)),
            Vector3.FORWARD * PROJECTILE_SPEED,
            source
        )
        if index == 0:
            first = projectile

    assert_equal(pool.get_active_count(), 32, "all prewarmed projectiles may be active")
    var recycled := pool.fire(
        Transform3D(Basis.IDENTITY, Vector3(99.0, 50.0, 0.0)),
        Vector3.FORWARD * PROJECTILE_SPEED,
        source
    )
    assert_true(recycled == first, "full pool must recycle oldest active projectile")

    pool.clear_all()
    assert_equal(pool.get_active_count(), 0, "clear_all must deactivate every projectile")

    var after_clear := pool.fire(
        Transform3D(Basis.IDENTITY, Vector3(0.0, 50.0, 0.0)),
        Vector3.FORWARD * PROJECTILE_SPEED,
        source
    )
    assert_true(after_clear == first, "clear_all must reset deterministic allocation order")

    _detach_fixture(fixture)

func _test_lifetime_deactivates_projectile() -> void:
    var fixture := Node3D.new()
    var source := _make_source_body()
    fixture.add_child(source)
    var pool := PulseProjectilePool.new()
    fixture.add_child(pool)
    _attach_fixture(fixture)
    pool.initialize()

    var projectile := pool.fire(
        Transform3D(Basis.IDENTITY, Vector3(0.0, 100.0, 0.0)),
        Vector3.FORWARD * PROJECTILE_SPEED,
        source
    )
    projectile.step_for_test(2.99)
    assert_true(projectile.is_active(), "projectile must remain active before three seconds")
    projectile.step_for_test(0.01)
    assert_true(not projectile.is_active(), "projectile must deactivate at three seconds")

    _detach_fixture(fixture)

func _test_primary_fire_controller_uses_muzzle_and_inherited_velocity() -> void:
    var fixture := Node3D.new()
    var body := RigidBody3D.new()
    body.name = "Ship"
    body.gravity_scale = 0.0
    body.linear_velocity = Vector3(12.0, 3.0, -20.0)
    fixture.add_child(body)

    var input_source := PlayerInputSource.new()
    input_source.name = "Input"
    body.add_child(input_source)

    var model := Node3D.new()
    model.name = "Model"
    body.add_child(model)
    var weapons := Node3D.new()
    weapons.name = "Weapons"
    model.add_child(weapons)
    var primary := Node3D.new()
    primary.name = "Primary"
    weapons.add_child(primary)
    var left := Node3D.new()
    left.name = "LeftMuzzle"
    left.position = Vector3(-1.0, 0.0, -2.0)
    primary.add_child(left)
    var right := Node3D.new()
    right.name = "RightMuzzle"
    right.position = Vector3(1.0, 0.0, -2.0)
    primary.add_child(right)

    var controller := PrimaryFireController.new()
    controller.name = "PrimaryFireController"
    controller.body_path = NodePath("..")
    controller.input_source_path = NodePath("../Input")
    controller.model_path = NodePath("../Model")
    body.add_child(controller)

    var pool := PulseProjectilePool.new()
    fixture.add_child(pool)
    _attach_fixture(fixture)
    pool.initialize()
    controller.initialize()
    controller.set_projectile_pool(pool)

    controller.step_for_test(true, 0.0)
    var active := pool.get_active_projectiles()
    assert_equal(active.size(), 1, "initial held step must fire one projectile")
    if active.size() == 1:
        var projectile := active[0]
        var expected_velocity := body.linear_velocity + Vector3.FORWARD * PROJECTILE_SPEED
        assert_true(
            projectile.get_velocity().is_equal_approx(expected_velocity),
            "projectile velocity must inherit ship velocity plus fighter-forward speed"
        )
        assert_true(
            projectile.global_transform.is_equal_approx(left.global_transform),
            "projectile orientation and origin must come from verified left muzzle"
        )

    controller.set_firing_enabled(false)
    controller.step_for_test(false, 0.0)
    controller.step_for_test(true, 1.0)
    assert_equal(pool.get_active_count(), 1, "disabled controller must not fire")
    controller.reset_runtime_state()
    assert_true(
        not controller.is_firing_enabled(),
        "reset_runtime_state must not silently re-enable firing"
    )

    _detach_fixture(fixture)

func _make_source_body() -> RigidBody3D:
    var source := RigidBody3D.new()
    source.name = "Source"
    source.gravity_scale = 0.0
    source.collision_layer = 1
    source.collision_mask = 1
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.0
    collision.shape = shape
    source.add_child(collision)
    return source

func _make_target_body(position: Vector3, damageable: bool) -> StaticBody3D:
    var target := StaticBody3D.new()
    target.position = position
    target.collision_layer = 1
    target.collision_mask = 1
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(3.0, 3.0, 0.1)
    collision.shape = shape
    target.add_child(collision)

    if damageable:
        var tuning := DamageTuning.new()
        tuning.maximum_shield = 150.0
        tuning.maximum_hull = 200.0
        var state := DamageState.new()
        state.name = "DamageState"
        state.tuning = tuning
        target.add_child(state)
        state.reset_full()

    return target

func _attach_fixture(fixture: Node3D) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    assert_true(tree != null, "test runner SceneTree must exist")
    if tree != null:
        tree.root.add_child(fixture)

func _detach_fixture(fixture: Node3D) -> void:
    if fixture.get_parent() != null:
        fixture.get_parent().remove_child(fixture)
    fixture.free()
