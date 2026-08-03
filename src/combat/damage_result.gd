class_name DamageResult
extends RefCounted

var requested_amount: float = 0.0
var applied_amount: float = 0.0
var applied_to_shield: float = 0.0
var applied_to_hull: float = 0.0
var remaining_shield: float = 0.0
var remaining_hull: float = 0.0
var shield_broken: bool = false
var hull_damaged: bool = false
var destroyed: bool = false
var ignored: bool = false
var impact_point: Vector3 = Vector3.ZERO
var impact_normal: Vector3 = Vector3.UP
var kind: DamagePacket.Kind = DamagePacket.Kind.PROJECTILE
var source_instance_id: int = 0
var physics_tick: int = 0
var contact_key: StringName = &""
