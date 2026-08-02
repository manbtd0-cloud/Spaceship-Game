class_name BoostThermalState
extends RefCounted

var heat: float = 0.0
var locked_out: bool = false
var effective_boost: float = 0.0

static func advance(
    current_heat: float,
    was_locked_out: bool,
    boost_requested: float,
    translation_magnitude: float,
    delta: float,
    heat_per_second: float,
    cooling_per_second: float,
    recovery_threshold: float
) -> BoostThermalState:
    var result := BoostThermalState.new()
    result.heat = clampf(current_heat, 0.0, 1.0)
    result.locked_out = was_locked_out

    var wants_boost := (
        boost_requested > 0.0
        and translation_magnitude > 0.001
    )

    if result.locked_out:
        result.heat = maxf(
            0.0,
            result.heat
            - maxf(cooling_per_second, 0.0) * maxf(delta, 0.0)
        )
        if result.heat <= clampf(recovery_threshold, 0.0, 1.0):
            result.locked_out = false
        result.effective_boost = 0.0
        return result

    if wants_boost:
        result.heat = minf(
            1.0,
            result.heat
            + maxf(heat_per_second, 0.0) * maxf(delta, 0.0)
        )
        if result.heat >= 1.0:
            result.locked_out = true
            result.effective_boost = 0.0
        else:
            result.effective_boost = clampf(boost_requested, 0.0, 1.0)
        return result

    result.heat = maxf(
        0.0,
        result.heat
        - maxf(cooling_per_second, 0.0) * maxf(delta, 0.0)
    )
    result.effective_boost = 0.0
    return result

static func recovery_progress(
    heat_value: float,
    recovery_threshold: float
) -> float:
    var threshold := clampf(recovery_threshold, 0.0, 0.999)
    return clampf(
        (1.0 - clampf(heat_value, 0.0, 1.0)) / (1.0 - threshold),
        0.0,
        1.0
    )
