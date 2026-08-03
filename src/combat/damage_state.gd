class_name DamageState
extends Node

signal damage_resolved(result: DamageResult)
signal shield_broken(result: DamageResult)
signal destroyed(result: DamageResult)
signal state_changed(shield: float, hull: float)

@export var tuning: DamageTuning

var _shield: float = 0.0
var _hull: float = 0.0
var _shield_delay_remaining: float = 0.0
var _shield_reboot_remaining: float = 0.0
var _hull_repair_delay_remaining: float = 0.0
var _destroyed: bool = false
var _damage_enabled: bool = true
var _initialized: bool = false

func _ready() -> void:
    _ensure_initialized()

func apply_damage(packet: DamagePacket) -> DamageResult:
    _ensure_initialized()
    var safe_packet := (
        packet
        if packet != null
        else DamagePacket.create(
            0.0,
            DamagePacket.Kind.PROJECTILE,
            Vector3.ZERO,
            Vector3.UP
        )
    )
    var result := _result_for_packet(safe_packet)

    if safe_packet.amount <= 0.0 or not _damage_enabled or _destroyed:
        result.ignored = not _damage_enabled or _destroyed
        return result

    var shield_before := _shield
    var hull_before := _hull
    var remaining := safe_packet.amount

    result.applied_to_shield = minf(_shield, remaining)
    _shield -= result.applied_to_shield
    remaining -= result.applied_to_shield

    result.applied_to_hull = minf(_hull, remaining)
    _hull -= result.applied_to_hull
    result.applied_amount = (
        result.applied_to_shield + result.applied_to_hull
    )

    _shield = clampf(_shield, 0.0, _maximum_shield())
    _hull = clampf(_hull, 0.0, _maximum_hull())

    result.shield_broken = shield_before > 0.0 and _shield <= 0.0
    result.hull_damaged = result.applied_to_hull > 0.0
    result.destroyed = hull_before > 0.0 and _hull <= 0.0
    result.remaining_shield = _shield
    result.remaining_hull = _hull

    if _shield <= 0.0:
        _shield_reboot_remaining = maxf(
            _effective_tuning().shield_reboot_delay,
            0.0
        )
        _shield_delay_remaining = 0.0
    else:
        _shield_delay_remaining = maxf(
            _effective_tuning().shield_regeneration_delay,
            0.0
        )
        _shield_reboot_remaining = 0.0

    _hull_repair_delay_remaining = maxf(
        _effective_tuning().hull_repair_delay_after_full_shield,
        0.0
    )

    if result.destroyed:
        _destroyed = true
        _shield_delay_remaining = 0.0
        _shield_reboot_remaining = 0.0
        _hull_repair_delay_remaining = 0.0

    if result.applied_amount <= 0.0:
        result.ignored = true
        return result

    state_changed.emit(_shield, _hull)
    damage_resolved.emit(result)
    if result.shield_broken:
        shield_broken.emit(result)
    if result.destroyed:
        destroyed.emit(result)
    return result

func advance(delta: float) -> void:
    _ensure_initialized()
    var remaining := maxf(delta, 0.0)
    if remaining <= 0.0 or _destroyed:
        return

    var previous_shield := _shield
    var previous_hull := _hull
    var maximum_shield := _maximum_shield()
    var maximum_hull := _maximum_hull()
    var configuration := _effective_tuning()

    if _shield < maximum_shield:
        _hull_repair_delay_remaining = maxf(
            configuration.hull_repair_delay_after_full_shield,
            0.0
        )

        if _shield <= 0.0 and _shield_reboot_remaining > 0.0:
            var reboot_consumed := minf(
                remaining,
                _shield_reboot_remaining
            )
            _shield_reboot_remaining -= reboot_consumed
            remaining -= reboot_consumed
        elif _shield > 0.0 and _shield_delay_remaining > 0.0:
            var delay_consumed := minf(
                remaining,
                _shield_delay_remaining
            )
            _shield_delay_remaining -= delay_consumed
            remaining -= delay_consumed

        if (
            remaining > 0.0
            and _shield < maximum_shield
            and configuration.shield_regeneration_rate > 0.0
        ):
            var missing_shield := maximum_shield - _shield
            var time_to_full_shield := (
                missing_shield / configuration.shield_regeneration_rate
            )
            var recharge_time := minf(remaining, time_to_full_shield)
            _shield += (
                configuration.shield_regeneration_rate * recharge_time
            )
            remaining -= recharge_time
            _shield = minf(_shield, maximum_shield)

    if _shield >= maximum_shield:
        _shield = maximum_shield
        if (
            configuration.hull_repair_enabled
            and _hull < maximum_hull
        ):
            if _hull_repair_delay_remaining > 0.0:
                var repair_delay_consumed := minf(
                    remaining,
                    _hull_repair_delay_remaining
                )
                _hull_repair_delay_remaining -= repair_delay_consumed
                remaining -= repair_delay_consumed

            if (
                remaining > 0.0
                and _hull_repair_delay_remaining <= 0.0
                and configuration.hull_repair_rate > 0.0
            ):
                var missing_hull := maximum_hull - _hull
                var time_to_full_hull := (
                    missing_hull / configuration.hull_repair_rate
                )
                var repair_time := minf(remaining, time_to_full_hull)
                _hull += configuration.hull_repair_rate * repair_time
                _hull = minf(_hull, maximum_hull)

    if (
        not is_equal_approx(previous_shield, _shield)
        or not is_equal_approx(previous_hull, _hull)
    ):
        state_changed.emit(_shield, _hull)

func reset_full() -> void:
    var configuration := _effective_tuning()
    _shield = maxf(configuration.maximum_shield, 0.0)
    _hull = maxf(configuration.maximum_hull, 0.0)
    _shield_delay_remaining = 0.0
    _shield_reboot_remaining = 0.0
    _hull_repair_delay_remaining = 0.0
    _destroyed = false
    _damage_enabled = true
    _initialized = true
    state_changed.emit(_shield, _hull)

func set_damage_enabled(enabled: bool) -> void:
    _ensure_initialized()
    _damage_enabled = enabled

func is_damage_enabled() -> bool:
    _ensure_initialized()
    return _damage_enabled

func get_shield() -> float:
    _ensure_initialized()
    return _shield

func get_hull() -> float:
    _ensure_initialized()
    return _hull

func get_shield_ratio() -> float:
    _ensure_initialized()
    var maximum := _maximum_shield()
    return clampf(_shield / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0

func get_hull_ratio() -> float:
    _ensure_initialized()
    var maximum := _maximum_hull()
    return clampf(_hull / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0

func is_destroyed() -> bool:
    _ensure_initialized()
    return _destroyed

func is_rebooting() -> bool:
    _ensure_initialized()
    return (
        not _destroyed
        and _shield <= 0.0
        and _shield_reboot_remaining > 0.0
    )

func is_recharging() -> bool:
    _ensure_initialized()
    if _destroyed or _shield >= _maximum_shield():
        return false
    if _effective_tuning().shield_regeneration_rate <= 0.0:
        return false
    if _shield <= 0.0:
        return _shield_reboot_remaining <= 0.0
    return _shield_delay_remaining <= 0.0

func is_repairing_hull() -> bool:
    _ensure_initialized()
    var configuration := _effective_tuning()
    return (
        not _destroyed
        and configuration.hull_repair_enabled
        and configuration.hull_repair_rate > 0.0
        and _shield >= _maximum_shield()
        and _hull < _maximum_hull()
        and _hull_repair_delay_remaining <= 0.0
    )

func _ensure_initialized() -> void:
    if not _initialized:
        reset_full()

func _effective_tuning() -> DamageTuning:
    if tuning == null:
        tuning = DamageTuning.new()
    return tuning

func _maximum_shield() -> float:
    return maxf(_effective_tuning().maximum_shield, 0.0)

func _maximum_hull() -> float:
    return maxf(_effective_tuning().maximum_hull, 0.0)

func _result_for_packet(packet: DamagePacket) -> DamageResult:
    var result := DamageResult.new()
    result.requested_amount = packet.amount
    result.remaining_shield = _shield
    result.remaining_hull = _hull
    result.impact_point = packet.impact_point
    result.impact_normal = packet.impact_normal
    result.kind = packet.kind
    result.source_instance_id = packet.source_instance_id
    result.physics_tick = packet.physics_tick
    result.contact_key = packet.contact_key
    return result
