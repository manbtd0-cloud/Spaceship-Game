class_name PulseProjectile
extends Node3D

signal resolved(
    projectile: PulseProjectile,
    damage_result: DamageResult,
    hit_damageable: bool
)

const QUERY_RADIUS := 0.15
const DEFAULT_DAMAGE := 15.0
const DEFAULT_LIFETIME := 3.0

@export_flags_3d_physics var collision_mask: int = 1

var _query_shape := SphereShape3D.new()
var _velocity := Vector3.ZERO
var _damage := DEFAULT_DAMAGE
var _remaining_lifetime := 0.0
var _source_body: CollisionObject3D
var _source_rid := RID()
var _source_instance_id := 0
var _active := false
var _resolved_this_activation := false

func _init() -> void:
    _query_shape.radius = QUERY_RADIUS

func _ready() -> void:
    deactivate()

func _physics_process(delta: float) -> void:
    _advance(delta)

func activate(
    world_transform: Transform3D,
    velocity: Vector3,
    source_body: CollisionObject3D,
    damage: float = DEFAULT_DAMAGE,
    lifetime: float = DEFAULT_LIFETIME
) -> void:
    global_transform = world_transform
    _velocity = velocity if velocity.is_finite() else Vector3.ZERO
    _damage = maxf(damage, 0.0)
    _remaining_lifetime = maxf(lifetime, 0.0)
    _source_body = source_body
    _source_rid = source_body.get_rid() if is_instance_valid(source_body) else RID()
    _source_instance_id = (
        source_body.get_instance_id() if is_instance_valid(source_body) else 0
    )
    _resolved_this_activation = false
    _active = _remaining_lifetime > 0.0
    visible = _active
    set_physics_process(_active)

func deactivate() -> void:
    _active = false
    visible = false
    set_physics_process(false)
    _velocity = Vector3.ZERO
    _remaining_lifetime = 0.0
    _source_body = null
    _source_rid = RID()
    _source_instance_id = 0

func step_for_test(delta: float) -> void:
    _advance(delta)

func is_active() -> bool:
    return _active

func get_velocity() -> Vector3:
    return _velocity

func get_remaining_lifetime() -> float:
    return _remaining_lifetime

func _advance(delta: float) -> void:
    if not _active:
        return
    if not is_inside_tree() or get_world_3d() == null:
        return

    var safe_delta := maxf(delta, 0.0)
    if safe_delta <= 0.0:
        return

    var step_delta := minf(safe_delta, _remaining_lifetime)
    var motion := _velocity * step_delta
    var collided := false
    if motion.length_squared() > 0.0:
        collided = _sweep_motion(motion)

    if collided or not _active:
        return

    _remaining_lifetime = maxf(_remaining_lifetime - step_delta, 0.0)
    if _remaining_lifetime <= 0.000001:
        deactivate()

func _sweep_motion(motion: Vector3) -> bool:
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _query_shape
    query.transform = global_transform
    query.motion = motion
    query.collision_mask = collision_mask
    query.collide_with_bodies = true
    query.collide_with_areas = false
    if _source_rid.is_valid():
        query.exclude = [_source_rid]

    var space_state := get_world_3d().direct_space_state
    var fractions := space_state.cast_motion(query)
    if fractions.size() < 2:
        global_position += motion
        return false

    var safe_fraction := clampf(float(fractions[0]), 0.0, 1.0)
    if safe_fraction >= 1.0:
        global_position += motion
        return false

    var unsafe_fraction := clampf(
        float(fractions[1]),
        safe_fraction,
        1.0
    )
    var impact_transform := global_transform
    impact_transform.origin += motion * unsafe_fraction
    query.transform = impact_transform
    query.motion = Vector3.ZERO
    var rest_info := space_state.get_rest_info(query)

    global_position += motion * safe_fraction
    _resolve_first_hit(rest_info, motion)
    return true

func _resolve_first_hit(rest_info: Dictionary, motion: Vector3) -> void:
    if _resolved_this_activation:
        return
    _resolved_this_activation = true

    var collider_id := int(rest_info.get("collider_id", 0))
    var collider: Object = null
    if collider_id != 0 and is_instance_id_valid(collider_id):
        collider = instance_from_id(collider_id)

    var hit_point: Vector3 = rest_info.get("point", global_position)
    var fallback_normal := (
        -motion.normalized() if motion.length_squared() > 0.0 else Vector3.BACK
    )
    var hit_normal: Vector3 = rest_info.get("normal", fallback_normal)
    if hit_normal.is_zero_approx() or not hit_normal.is_finite():
        hit_normal = fallback_normal
    else:
        hit_normal = hit_normal.normalized()

    var damage_state := _find_damage_state(collider)
    var damage_result: DamageResult
    var hit_damageable := damage_state != null
    if damage_state != null:
        var packet := DamagePacket.create(
            _damage,
            DamagePacket.Kind.PROJECTILE,
            hit_point,
            hit_normal,
            _source_instance_id,
            Engine.get_physics_frames()
        )
        damage_result = damage_state.apply_damage(packet)

    deactivate()
    resolved.emit(self, damage_result, hit_damageable)

func _find_damage_state(collider: Object) -> DamageState:
    var collider_node := collider as Node
    if collider_node == null:
        return null
    var direct_state := collider_node as DamageState
    if direct_state != null:
        return direct_state
    for child: Node in collider_node.get_children():
        var child_state := child as DamageState
        if child_state != null:
            return child_state
    return null
