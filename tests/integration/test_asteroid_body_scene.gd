extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/environment/asteroid_body.tscn") as PackedScene
    assert_true(packed != null, "asteroid body scene must load")
    if packed == null:
        return

    var body := packed.instantiate() as AsteroidBody
    assert_true(body != null, "asteroid body root must use AsteroidBody")
    if body == null:
        return

    assert_true(body is AnimatableBody3D, "asteroid root must be AnimatableBody3D")
    assert_true(body.get_node_or_null("ModelMount") is Node3D, "model mount required")
    assert_true(
        body.get_node_or_null("Collision") is CollisionShape3D,
        "owned collision shape required"
    )
    assert_true(not body.is_configured(), "asteroid starts unconfigured")

    var model := _make_test_model()
    var configured := body.configure(
        model,
        &"fixture",
        Vector3(2.0, 4.0, -3.0)
    )
    assert_true(configured, "asteroid must configure from valid imported model")
    assert_true(body.is_configured(), "configured state required")
    assert_equal(body.get_family(), &"fixture", "family metadata must be retained")

    var collision := body.get_node("Collision") as CollisionShape3D
    assert_true(collision.shape != null, "imported convex collision must be adopted")
    assert_equal(
        body.get_node("ModelMount").get_child_count(),
        1,
        "configured asteroid must own one imported model"
    )

    var before := body.rotation
    body.advance_rotation(0.5)
    assert_true(
        not body.rotation.is_equal_approx(before),
        "configured asteroid must advance deterministic local rotation"
    )

    body.free()

func _make_test_model() -> PackedScene:
    var root := Node3D.new()
    root.name = "FixtureAsteroid"

    var visual := MeshInstance3D.new()
    visual.name = "VisualModel"
    visual.mesh = SphereMesh.new()
    root.add_child(visual)
    visual.owner = root

    var imported_body := StaticBody3D.new()
    imported_body.name = "CollisionProxy"
    root.add_child(imported_body)
    imported_body.owner = root

    var imported_collision := CollisionShape3D.new()
    imported_collision.name = "CollisionShape3D"
    imported_collision.shape = SphereShape3D.new()
    imported_body.add_child(imported_collision)
    imported_collision.owner = root

    var packed := PackedScene.new()
    var result := packed.pack(root)
    assert_true(result == OK, "fixture asteroid scene must pack")
    root.free()
    return packed
