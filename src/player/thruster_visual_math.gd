class_name ThrusterVisualMath
extends RefCounted

const ASSIST_VISUAL_CAP := 0.35
const MINIMUM_LENGTH_SCALE := 0.04
const MINIMUM_RADIUS_SCALE := 0.22
const EPSILON := 0.000001

static func merge_target(direct: float, assist_raw: float) -> float:
    return maxf(
        clampf(direct, 0.0, 1.0),
        clampf(assist_raw, 0.0, 1.0) * ASSIST_VISUAL_CAP
    )

static func advance(
    current: float,
    target: float,
    delta: float,
    rise_seconds: float,
    fall_seconds: float
) -> float:
    var safe_current := clampf(current, 0.0, 1.0)
    var safe_target := clampf(target, 0.0, 1.0)
    var step_seconds := maxf(delta, 0.0)
    if step_seconds <= 0.0 or is_equal_approx(safe_current, safe_target):
        return safe_target if is_equal_approx(safe_current, safe_target) else safe_current

    var duration := (
        maxf(rise_seconds, EPSILON)
        if safe_target > safe_current
        else maxf(fall_seconds, EPSILON)
    )
    return move_toward(safe_current, safe_target, step_seconds / duration)

static func smootherstep(value: float) -> float:
    var x := clampf(value, 0.0, 1.0)
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

static func scale_for(envelope: float, exhaust_axis: Vector3) -> Vector3:
    var axis := Vector3(
        absf(exhaust_axis.x),
        absf(exhaust_axis.y),
        absf(exhaust_axis.z)
    )
    if axis.length_squared() <= EPSILON:
        axis = Vector3.BACK
    else:
        axis = axis.normalized()

    var shaped := smootherstep(envelope)
    var length_scale := lerpf(MINIMUM_LENGTH_SCALE, 1.0, shaped)
    var radius_scale := lerpf(MINIMUM_RADIUS_SCALE, 1.0, shaped)
    return Vector3(
        lerpf(radius_scale, length_scale, axis.x),
        lerpf(radius_scale, length_scale, axis.y),
        lerpf(radius_scale, length_scale, axis.z)
    )

static func opacity_for(envelope: float) -> float:
    var value := clampf(envelope, 0.0, 1.0)
    return value * value

static func emission_for(envelope: float) -> float:
    var value := clampf(envelope, 0.0, 1.0)
    return value * value * value
