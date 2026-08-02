extends "res://tests/support/test_case.gd"

func run() -> void:
    var records := AsteroidFieldLayout.records()
    assert_true(records.size() >= 12, "asteroid field requires at least twelve records")

    var family_counts: Dictionary = {}
    var positions: Dictionary = {}
    for record: Dictionary in records:
        var family := StringName(record.get("family", &""))
        assert_true(
            family in AsteroidFieldLayout.FAMILY_IDS,
            "asteroid layout contains unsupported family: %s" % family
        )
        family_counts[family] = int(family_counts.get(family, 0)) + 1

        var position: Vector3 = record.get("position", Vector3.ZERO)
        assert_true(position.is_finite(), "asteroid position must be finite")
        assert_true(
            Vector2(position.x, position.y).length() >= 70.0,
            "asteroid must not block the course centerline: %s" % position
        )
        var position_key := "%0.3f,%0.3f,%0.3f" % [
            position.x,
            position.y,
            position.z,
        ]
        assert_true(
            not positions.has(position_key),
            "asteroid positions must be unique: %s" % position_key
        )
        positions[position_key] = true

        var rotation_degrees: Vector3 = record.get(
            "rotation_degrees",
            Vector3.ZERO
        )
        assert_true(rotation_degrees.is_finite(), "asteroid rotation must be finite")

        var uniform_scale := float(record.get("scale", 0.0))
        assert_true(
            is_finite(uniform_scale) and uniform_scale > 0.0,
            "asteroid scale must be positive and finite"
        )

        var angular_velocity: Vector3 = record.get(
            "angular_velocity_degrees",
            Vector3.ZERO
        )
        assert_true(
            angular_velocity.is_finite()
            and angular_velocity.length_squared() > 0.000001,
            "asteroid angular velocity must be finite and non-zero"
        )

    for family: StringName in AsteroidFieldLayout.FAMILY_IDS:
        assert_true(
            int(family_counts.get(family, 0)) >= 2,
            "each asteroid family must appear at least twice: %s" % family
        )
