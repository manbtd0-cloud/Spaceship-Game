class_name CollisionDamageReceiver
extends Node

signal collision_damage_resolved(result: DamageResult)

@export var body_path: NodePath = NodePath("..")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var minimum_impact_speed: float = 12.0
@export var damage_per_excess_mps: float = 2.0
@export var maximum_damage: float = 80.0
@export var repeat_guard_frames: int = 12

var _body: RigidBody3D
var _damage_state: DamageState
var _last_contact_tick: Dictionary = {}

func _ready() -> void:
    _body = get_node_or_null(body_path) as RigidBody3D
    _damage_state = get_node_or_null(damage_state_path) as DamageState
    if _body == null or _damage_state == null:
        push_error("CollisionDamageReceiver requires body and DamageState")
        set_process(false)
        return

    _body.contact_monitor = true
    _body.max_contacts_reported = maxi(_body.max_contacts_reported, 8)
    if not _body.body_entered.is_connected(_on_body_entered):
        _body.body_entered.connect(_on_body_entered)

func _on_body_entered(other: Node) -> void:
    var other_body := other as PhysicsBody3D
    if other_body == null or _body == null:
        return

    var separation := _body.global_position - other_body.global_position
    var impact_normal := (
        separation.normalized()
        if not separation.is_zero_approx()
        else Vector3.UP
    )
    var impact_point := (
        _body.global_position + other_body.global_position
    ) * 0.5
    _resolve(
        other_body,
        impact_point,
        impact_normal,
        Engine.get_physics_frames()
    )

func resolve_collision_for_test(
    other_body: PhysicsBody3D,
    impact_point: Vector3,
    impact_normal: Vector3,
    physics_tick: int
) -> DamageResult:
    return _resolve(
        other_body,
        impact_point,
        impact_normal,
        physics_tick
    )

func reset_runtime_state() -> void:
    _last_contact_tick.clear()

func _resolve(
    other_body: PhysicsBody3D,
    impact_point: Vector3,
    impact_normal: Vector3,
    physics_tick: int
) -> DamageResult:
    if _body == null or _damage_state == null or other_body == null:
        return null
    if other_body == _body:
        return null

    var key := _contact_key(_body.get_instance_id(), other_body.get_instance_id())
    var previous_tick := int(_last_contact_tick.get(key, -1000000000))
    if physics_tick - previous_tick < maxi(repeat_guard_frames, 0):
        return null
    _last_contact_tick[key] = physics_tick

    var other_rigid := other_body as RigidBody3D
    var other_velocity := (
        other_rigid.linear_velocity
        if other_rigid != null
        else Vector3.ZERO
    )
    var relative_speed := (
        _body.linear_velocity - other_velocity
    ).length()
    var amount := CollisionDamageMath.compute_damage(
        relative_speed,
        minimum_impact_speed,
        damage_per_excess_mps,
        maximum_damage
    )
    if amount <= 0.0:
        return null

    var result := _damage_state.apply_damage(
        DamagePacket.create(
            amount,
            DamagePacket.Kind.COLLISION,
            impact_point,
            impact_normal,
            other_body.get_instance_id(),
            physics_tick,
            key
        )
    )
    if result != null and result.applied_amount > 0.0:
        collision_damage_resolved.emit(result)
    return result

static func _contact_key(first_id: int, second_id: int) -> StringName:
    var lower := mini(first_id, second_id)
    var upper := maxi(first_id, second_id)
    return StringName("%d:%d" % [lower, upper])
