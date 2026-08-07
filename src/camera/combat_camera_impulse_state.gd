class_name CombatCameraImpulseState
extends RefCounted

const MAX_TRANSLATION_METERS := 0.11
const MAX_ROTATION_DEGREES := 0.8
const EXPLOSION_RANGE_METERS := 700.0

var _peak_strength := 0.0
var _duration := 0.0
var _remaining := 0.0
var _phase := 0.0
var _translation_offset := Vector3.ZERO
var _rotation_offset_degrees := Vector3.ZERO

func request_player_damage(result: DamageResult) -> void:
    if result == null or result.applied_amount <= 0.0:
        return
    if result.kind == DamagePacket.Kind.COLLISION:
        var collision_strength := clampf(
            0.22 + result.applied_amount / 120.0 * 0.60,
            0.22,
            0.82
        )
        _request(collision_strength, 0.38)
        return
    var projectile_strength := clampf(
        0.10 + result.applied_amount / 150.0 * 0.25,
        0.10,
        0.28
    )
    _request(projectile_strength, 0.26)

func request_shield_break() -> void:
    _request(0.58, 0.42)

func request_explosion(distance_meters: float) -> void:
    if not is_finite(distance_meters) or distance_meters < 0.0:
        return
    var range_ratio := clampf(
        1.0 - distance_meters / EXPLOSION_RANGE_METERS,
        0.0,
        1.0
    )
    if range_ratio <= 0.0:
        return
    _request(0.48 * pow(range_ratio, 1.25), 0.52)

func advance(delta: float) -> void:
    if _remaining <= 0.0 or _peak_strength <= 0.0:
        _clear_offsets()
        return
    var safe_delta := maxf(delta, 0.0)
    _phase += safe_delta * 43.0
    _remaining = maxf(_remaining - safe_delta, 0.0)
    if _remaining <= 0.0:
        reset()
        return
    var envelope := sqrt(clampf(_remaining / maxf(_duration, 0.0001), 0.0, 1.0))
    var amplitude := _peak_strength * envelope

    var translation_direction := Vector3(
        sin(_phase),
        cos(_phase * 1.37) * 0.72,
        sin(_phase * 0.73 + 0.8) * 0.46
    )
    if translation_direction.length_squared() > 0.000001:
        translation_direction = translation_direction.normalized()
    _translation_offset = translation_direction * MAX_TRANSLATION_METERS * amplitude

    var rotation_direction := Vector3(
        cos(_phase * 0.91),
        sin(_phase * 1.11 + 0.4),
        cos(_phase * 1.43 + 1.0) * 0.65
    )
    if rotation_direction.length_squared() > 0.000001:
        rotation_direction = rotation_direction.normalized()
    _rotation_offset_degrees = rotation_direction * MAX_ROTATION_DEGREES * amplitude

func reset() -> void:
    _peak_strength = 0.0
    _duration = 0.0
    _remaining = 0.0
    _phase = 0.0
    _clear_offsets()

func get_strength() -> float:
    if _remaining <= 0.0 or _duration <= 0.0:
        return 0.0
    return _peak_strength * clampf(_remaining / _duration, 0.0, 1.0)

func get_translation_offset() -> Vector3:
    return _translation_offset

func get_rotation_offset_degrees() -> Vector3:
    return _rotation_offset_degrees

func _request(strength: float, duration: float) -> void:
    if not is_finite(strength) or not is_finite(duration):
        return
    var safe_strength := clampf(strength, 0.0, 1.0)
    var safe_duration := maxf(duration, 0.0)
    if safe_strength <= 0.0 or safe_duration <= 0.0:
        return
    if safe_strength >= get_strength():
        _peak_strength = safe_strength
        _duration = safe_duration
        _remaining = safe_duration
    else:
        _remaining = maxf(_remaining, minf(safe_duration, _duration))

func _clear_offsets() -> void:
    _translation_offset = Vector3.ZERO
    _rotation_offset_degrees = Vector3.ZERO
