extends "res://tests/support/test_case.gd"

func run() -> void:
    var field := AsteroidField.new()
    var fixture_model := _make_test_model()
    var models := {
        &"bennu": fixture_model,
        &"eros": fixture_model,
        &"legacy_a": fixture_model,
        &"legacy_b": fixture_model,
    }

    var built := field.build(models)
    assert_true(built, "asteroid field must build from four valid model families")
    assert_true(field.is_built(), "asteroid field must report built state")
    assert_equal(
        field.get_asteroid_count(),
        AsteroidFieldLayout.records().size(),
        "field asteroid count must match deterministic layout"
    )
    assert_true(
        field.get_asteroid_count() >= 12,
        "field must contain at least twelve asteroids"
    )
    for family: StringName in AsteroidFieldLayout.FAMILY_IDS:
        assert_true(
            field.get_family_count(family) >= 2,
            "each family must appear at least twice: %s" % family
        )
    assert_true(
        field.are_all_asteroids_collidable(),
        "every configured asteroid must own an enabled collision shape"
    )

    for child: Node in field.get_children():
        assert_true(child is AnimatableBody3D, "every field child must be animatable")
        var asteroid := child as AsteroidBody
        assert_true(asteroid != null, "every field child must use AsteroidBody")
        if asteroid != null:
            assert_true(asteroid.is_configured(), "every asteroid must be configured")
            assert_true(
                asteroid.get_family() in AsteroidFieldLayout.FAMILY_IDS,
                "every asteroid must retain a valid family id"
            )

    field.free()

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
    assert_true(result == OK, "field fixture model must pack")
    root.free()
    return packed
