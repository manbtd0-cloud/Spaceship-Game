class_name PrimaryFireCadence
extends RefCounted

enum MuzzleSide {
    LEFT,
    RIGHT,
}

const SHOTS_PER_SECOND := 7.0
const SHOT_INTERVAL := 1.0 / SHOTS_PER_SECOND

var _was_held := false
var _time_until_next_shot := 0.0
var _next_side: MuzzleSide = MuzzleSide.LEFT

func advance(held: bool, delta: float) -> Array[int]:
    var shots: Array[int] = []
    var safe_delta := maxf(delta, 0.0)

    if not held:
        _was_held = false
        _time_until_next_shot = 0.0
        return shots

    if not _was_held:
        _was_held = true
        shots.append(_consume_side())
        _time_until_next_shot = SHOT_INTERVAL
        return shots

    _time_until_next_shot -= safe_delta
    while _time_until_next_shot <= 0.0:
        shots.append(_consume_side())
        _time_until_next_shot += SHOT_INTERVAL
    return shots

func reset() -> void:
    _was_held = false
    _time_until_next_shot = 0.0
    _next_side = MuzzleSide.LEFT

func _consume_side() -> int:
    var result := int(_next_side)
    _next_side = (
        MuzzleSide.RIGHT
        if _next_side == MuzzleSide.LEFT
        else MuzzleSide.LEFT
    )
    return result
