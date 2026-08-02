class_name ThrusterAction
extends RefCounted

enum Value {
    FORWARD,
    REVERSE,
    STRAFE_LEFT,
    STRAFE_RIGHT,
    STRAFE_UP,
    STRAFE_DOWN,
    PITCH_UP,
    PITCH_DOWN,
    YAW_LEFT,
    YAW_RIGHT,
    ROLL_LEFT,
    ROLL_RIGHT,
}

static func action_count() -> int:
    return Value.size()

static func name_of(action: int) -> StringName:
    match action:
        Value.FORWARD:
            return &"forward"
        Value.REVERSE:
            return &"reverse"
        Value.STRAFE_LEFT:
            return &"strafe_left"
        Value.STRAFE_RIGHT:
            return &"strafe_right"
        Value.STRAFE_UP:
            return &"strafe_up"
        Value.STRAFE_DOWN:
            return &"strafe_down"
        Value.PITCH_UP:
            return &"pitch_up"
        Value.PITCH_DOWN:
            return &"pitch_down"
        Value.YAW_LEFT:
            return &"yaw_left"
        Value.YAW_RIGHT:
            return &"yaw_right"
        Value.ROLL_LEFT:
            return &"roll_left"
        Value.ROLL_RIGHT:
            return &"roll_right"
        _:
            return &""

static func from_name(action_name: StringName) -> int:
    for action: int in range(action_count()):
        if name_of(action) == action_name:
            return action
    return -1

static func target_force(action: int) -> Vector3:
    match action:
        Value.FORWARD:
            return Vector3.FORWARD
        Value.REVERSE:
            return Vector3.BACK
        Value.STRAFE_LEFT:
            return Vector3.LEFT
        Value.STRAFE_RIGHT:
            return Vector3.RIGHT
        Value.STRAFE_UP:
            return Vector3.UP
        Value.STRAFE_DOWN:
            return Vector3.DOWN
        _:
            return Vector3.ZERO

static func target_torque(action: int) -> Vector3:
    match action:
        Value.PITCH_UP:
            return Vector3.RIGHT
        Value.PITCH_DOWN:
            return Vector3.LEFT
        Value.YAW_LEFT:
            return Vector3.UP
        Value.YAW_RIGHT:
            return Vector3.DOWN
        Value.ROLL_LEFT:
            return Vector3.BACK
        Value.ROLL_RIGHT:
            return Vector3.FORWARD
        _:
            return Vector3.ZERO
