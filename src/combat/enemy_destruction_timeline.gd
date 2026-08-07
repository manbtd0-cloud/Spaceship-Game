class_name EnemyDestructionTimeline
extends RefCounted

enum Stage { BUILDUP, BLAST, TAIL, COMPLETE }

const BUILDUP_END := 0.20
const BLAST_END := 0.55
const COMPLETE_TIME := 1.40
const CORE_PEAK := 0.24
const CORE_HALF_WIDTH := 0.22
const SHOCKWAVE_START := 0.22
const SHOCKWAVE_END := 1.15

static func stage_at(elapsed: float) -> Stage:
    var t := maxf(elapsed, 0.0)
    if t < BUILDUP_END:
        return Stage.BUILDUP
    if t < BLAST_END:
        return Stage.BLAST
    if t < COMPLETE_TIME:
        return Stage.TAIL
    return Stage.COMPLETE

static func core_energy(elapsed: float) -> float:
    if not is_finite(elapsed):
        return 0.0
    return clampf(1.0 - absf(elapsed - CORE_PEAK) / CORE_HALF_WIDTH, 0.0, 1.0)

static func shockwave_amount(elapsed: float) -> float:
    if not is_finite(elapsed) or elapsed < SHOCKWAVE_START or elapsed >= SHOCKWAVE_END:
        return 0.0
    var t := clampf((elapsed - SHOCKWAVE_START) / (SHOCKWAVE_END - SHOCKWAVE_START), 0.0, 1.0)
    return sin(t * PI)

static func buildup_amount(elapsed: float) -> float:
    if not is_finite(elapsed) or elapsed < 0.0 or elapsed >= BUILDUP_END:
        return 0.0
    return clampf(elapsed / BUILDUP_END, 0.0, 1.0)
