class_name DamagePacket
extends RefCounted

enum Kind {
    PROJECTILE,
    COLLISION,
}

var amount: float = 0.0
var kind: Kind = Kind.PROJECTILE
var impact_point: Vector3 = Vector3.ZERO
var impact_normal: Vector3 = Vector3.UP
var source_instance_id: int = 0
var physics_tick: int = 0
var contact_key: StringName = &""

static func create(
    requested_amount: float,
    requested_kind: Kind,
    point: Vector3,
    normal: Vector3,
    source_id: int = 0,
    tick: int = 0,
    key: StringName = &""
) -> DamagePacket:
    var packet := DamagePacket.new()
    packet.amount = maxf(requested_amount, 0.0)
    packet.kind = requested_kind
    packet.impact_point = point if point.is_finite() else Vector3.ZERO
    packet.impact_normal = (
        normal.normalized()
        if normal.is_finite() and normal.length_squared() > 0.000001
        else Vector3.UP
    )
    packet.source_instance_id = source_id
    packet.physics_tick = tick
    packet.contact_key = key
    return packet
