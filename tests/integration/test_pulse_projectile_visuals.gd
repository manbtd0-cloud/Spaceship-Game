extends "res://tests/support/test_case.gd"

const PROJECTILE_SCENE_PATH := "res://scenes/combat/pulse_projectile.tscn"
const VISUAL_FLOAT_TOLERANCE := 0.0001

func run() -> void:
    var packed := load(PROJECTILE_SCENE_PATH) as PackedScene
    assert_true(packed != null, "pulse projectile scene must load")
    if packed == null:
        return

    var projectile := packed.instantiate() as PulseProjectile
    assert_true(projectile != null, "pulse projectile scene root must use PulseProjectile")
    if projectile == null:
        return

    var bolt := projectile.get_node_or_null("BoltMesh") as MeshInstance3D
    var trail := projectile.get_node_or_null("TrailMesh") as MeshInstance3D
    assert_true(bolt != null, "pulse projectile must contain BoltMesh")
    assert_true(trail != null, "pulse projectile must contain TrailMesh")

    if bolt != null:
        var sphere := bolt.mesh as SphereMesh
        assert_true(sphere != null, "pulse bolt must remain a sphere mesh")
        if sphere != null:
            assert_true(
                sphere.radius + VISUAL_FLOAT_TOLERANCE >= 0.16,
                "pulse bolt radius must remain readable"
            )
            assert_true(
                sphere.height + VISUAL_FLOAT_TOLERANCE >= 0.32,
                "pulse bolt height must remain readable"
            )

            var material := sphere.material as StandardMaterial3D
            assert_true(material != null, "pulse bolt must use StandardMaterial3D")
            if material != null:
                assert_true(
                    is_equal_approx(material.albedo_color.a, 1.0),
                    "pulse bolt must remain fully opaque"
                )
                assert_true(material.emission_enabled, "pulse bolt emission must remain enabled")
                assert_true(
                    material.emission_energy_multiplier + VISUAL_FLOAT_TOLERANCE >= 14.0,
                    "pulse bolt emission must remain bright enough for combat readability"
                )

    if trail != null:
        var box := trail.mesh as BoxMesh
        assert_true(box != null, "pulse trail must remain a box mesh")
        if box != null:
            assert_true(
                box.size.x + VISUAL_FLOAT_TOLERANCE >= 0.09,
                "pulse trail must remain thick enough"
            )
            assert_true(
                box.size.y + VISUAL_FLOAT_TOLERANCE >= 0.09,
                "pulse trail must remain thick enough"
            )
            assert_true(
                box.size.z + VISUAL_FLOAT_TOLERANCE >= 0.95,
                "pulse trail must remain long enough"
            )
        assert_true(
            trail.position.z + VISUAL_FLOAT_TOLERANCE >= 0.48,
            "pulse trail must remain positioned behind the bolt"
        )

    projectile.free()
