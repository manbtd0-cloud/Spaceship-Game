class_name PlayerInputMath
extends RefCounted

static func compose_translation(
    left: float,
    right: float,
    down: float,
    up: float,
    forward: float,
    reverse: float
) -> Vector3:
    var value := Vector3(
        clampf(right, 0.0, 1.0) - clampf(left, 0.0, 1.0),
        clampf(up, 0.0, 1.0) - clampf(down, 0.0, 1.0),
        clampf(reverse, 0.0, 1.0) - clampf(forward, 0.0, 1.0)
    )
    return value.normalized() if value.length_squared() > 1.0 else value

static func compose_rotation(
    mouse_delta: Vector2,
    pitch_up: float,
    pitch_down: float,
    yaw_left: float,
    yaw_right: float,
    roll_left: float,
    roll_right: float,
    mouse_sensitivity: float,
    max_mouse_command: float
) -> Vector3:
    var limit := maxf(max_mouse_command, 0.0)
    var mouse_pitch := -mouse_delta.y * mouse_sensitivity
    var mouse_yaw := -mouse_delta.x * mouse_sensitivity
    return Vector3(
        clampf(
            mouse_pitch
            + clampf(pitch_up, 0.0, 1.0)
            - clampf(pitch_down, 0.0, 1.0),
            -limit,
            limit
        ),
        clampf(
            mouse_yaw
            + clampf(yaw_left, 0.0, 1.0)
            - clampf(yaw_right, 0.0, 1.0),
            -limit,
            limit
        ),
        clampf(
            clampf(roll_left, 0.0, 1.0)
            - clampf(roll_right, 0.0, 1.0),
            -1.0,
            1.0
        )
    )

static func clamp_boost(value: float) -> float:
    return clampf(value, 0.0, 1.0)
