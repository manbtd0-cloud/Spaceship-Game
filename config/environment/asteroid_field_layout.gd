class_name AsteroidFieldLayout
extends RefCounted

const FAMILY_IDS: Array[StringName] = [
    &"bennu",
    &"eros",
    &"legacy_a",
    &"legacy_b",
]

static func records() -> Array[Dictionary]:
    return [
        _record(&"bennu", Vector3(-155, 55, -340), Vector3(18, 42, 11), 0.58, Vector3(0.7, 1.8, -0.4)),
        _record(&"eros", Vector3(165, -70, -470), Vector3(-12, 68, 26), 0.46, Vector3(-0.6, 1.1, 0.8)),
        _record(&"legacy_a", Vector3(-210, -95, -640), Vector3(54, -22, 17), 0.72, Vector3(0.9, -0.5, 1.3)),
        _record(&"legacy_b", Vector3(235, 115, -820), Vector3(27, 103, -31), 0.64, Vector3(-0.8, 0.6, -1.0)),

        _record(&"eros", Vector3(-310, 150, -1080), Vector3(12, -48, 35), 1.05, Vector3(0.4, 0.8, -0.7)),
        _record(&"legacy_b", Vector3(355, -165, -1260), Vector3(-36, 24, 58), 0.88, Vector3(-0.5, 0.9, 0.6)),
        _record(&"bennu", Vector3(-420, -210, -1480), Vector3(66, 11, -19), 1.20, Vector3(0.3, -0.7, 0.5)),
        _record(&"legacy_a", Vector3(455, 230, -1710), Vector3(-22, 77, 43), 1.12, Vector3(-0.4, 0.5, -0.8)),

        _record(&"legacy_a", Vector3(-620, 320, -2140), Vector3(38, 128, -15), 1.75, Vector3(0.25, 0.42, -0.31)),
        _record(&"bennu", Vector3(690, -360, -2480), Vector3(-49, 35, 72), 1.55, Vector3(-0.22, 0.36, 0.28)),
        _record(&"legacy_b", Vector3(-780, -420, -2860), Vector3(81, -65, 29), 2.10, Vector3(0.18, -0.27, 0.33)),
        _record(&"eros", Vector3(850, 460, -3290), Vector3(-31, 96, -44), 1.90, Vector3(-0.20, 0.31, -0.24)),

        _record(&"legacy_b", Vector3(-1120, 590, -3780), Vector3(17, 146, 63), 3.00, Vector3(0.12, 0.20, -0.16)),
        _record(&"legacy_a", Vector3(1240, -680, -4310), Vector3(-73, 53, 18), 2.70, Vector3(-0.14, 0.17, 0.11)),
        _record(&"eros", Vector3(-1390, -760, -4870), Vector3(46, -119, 77), 3.40, Vector3(0.09, -0.15, 0.13)),
        _record(&"bennu", Vector3(1510, 830, -5480), Vector3(-28, 162, -56), 3.15, Vector3(-0.10, 0.13, -0.08)),
    ]

static func _record(
    family: StringName,
    position: Vector3,
    rotation_degrees: Vector3,
    uniform_scale: float,
    angular_velocity_degrees: Vector3
) -> Dictionary:
    return {
        "family": family,
        "position": position,
        "rotation_degrees": rotation_degrees,
        "scale": uniform_scale,
        "angular_velocity_degrees": angular_velocity_degrees,
    }
