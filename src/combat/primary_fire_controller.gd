class_name PrimaryFireController
extends Node

signal shot_fired(side: int, world_transform: Transform3D)
signal damage_confirmed(result: DamageResult)

const LEFT_MUZZLE := NodePath("Weapons/Primary/LeftMuzzle")
const RIGHT_MUZZLE := NodePath("Weapons/Primary/RightMuzzle")
const LEFT_MUZZLE_FROM_WEAPONS := NodePath("Primary/LeftMuzzle")
const RIGHT_MUZZLE_FROM_WEAPONS := NodePath("Primary/RightMuzzle")
const PROJECTILE_SPEED := 900.0

@export var body_path: NodePath
@export var input_source_path: NodePath
@export var model_path: NodePath

var _body: RigidBody3D
var _input_source: PlayerInputSource
var _model: Node3D
var _left_muzzle: Node3D
var _right_muzzle: Node3D
var _pool: PulseProjectilePool
var _cadence := PrimaryFireCadence.new()
var _initialized := false
var _muzzles_valid := false
var _firing_enabled := true

func _ready() -> void:
    initialize()

func _physics_process(delta: float) -> void:
    var held := (
        _input_source != null
        and _input_source.is_primary_fire_held()
    )
    _advance_fire(held, delta)

func initialize() -> void:
    if _initialized:
        return
    _initialized = true

    _body = get_node_or_null(body_path) as RigidBody3D
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource
    _model = get_node_or_null(model_path) as Node3D

    if _body == null:
        _disable_primary("PrimaryFireController could not resolve body at %s" % body_path)
        return
    if _input_source == null:
        _disable_primary(
            "PrimaryFireController could not resolve input source at %s"
            % input_source_path
        )
        return
    if _model == null:
        _disable_primary("PrimaryFireController could not resolve model at %s" % model_path)
        return

    var weapons_root := _find_unique_weapons_root()
    if weapons_root == null:
        _disable_primary(
            "Canonical fighter must expose exactly one Weapons hierarchy under model"
        )
        return

    _left_muzzle = weapons_root.get_node_or_null(
        LEFT_MUZZLE_FROM_WEAPONS
    ) as Node3D
    _right_muzzle = weapons_root.get_node_or_null(
        RIGHT_MUZZLE_FROM_WEAPONS
    ) as Node3D
    if _left_muzzle == null or _right_muzzle == null:
        _disable_primary(
            "Canonical fighter primary muzzles missing under model: %s, %s"
            % [LEFT_MUZZLE, RIGHT_MUZZLE]
        )
        return

    _muzzles_valid = true

func set_projectile_pool(pool: PulseProjectilePool) -> void:
    if _pool != null:
        var old_callback := Callable(self, "_on_projectile_resolved")
        if _pool.projectile_resolved.is_connected(old_callback):
            _pool.projectile_resolved.disconnect(old_callback)

    _pool = pool
    if _pool != null:
        _pool.initialize()
        var callback := Callable(self, "_on_projectile_resolved")
        if not _pool.projectile_resolved.is_connected(callback):
            _pool.projectile_resolved.connect(callback)

func set_firing_enabled(enabled: bool) -> void:
    _firing_enabled = enabled
    if not enabled:
        _cadence.advance(false, 0.0)

func is_firing_enabled() -> bool:
    return _firing_enabled

func reset_runtime_state() -> void:
    _cadence.reset()

func step_for_test(held: bool, delta: float) -> void:
    _advance_fire(held, delta)

func _advance_fire(held: bool, delta: float) -> void:
    initialize()
    var can_fire := (
        held
        and _firing_enabled
        and _muzzles_valid
        and _pool != null
    )
    var sides := _cadence.advance(can_fire, delta)
    for side: int in sides:
        _fire_side(side)

func _fire_side(side: int) -> void:
    if _body == null or _pool == null:
        return

    var muzzle := (
        _left_muzzle
        if side == PrimaryFireCadence.MuzzleSide.LEFT
        else _right_muzzle
    )
    if muzzle == null:
        return

    var forward := -_body.global_transform.basis.z.normalized()
    if not forward.is_finite() or forward.length_squared() < 0.99:
        return

    var velocity := _body.linear_velocity + forward * PROJECTILE_SPEED
    var projectile := _pool.fire(muzzle.global_transform, velocity, _body)
    if projectile == null:
        return
    shot_fired.emit(side, muzzle.global_transform)

func _find_unique_weapons_root() -> Node3D:
    if _model == null:
        return null
    var candidates := _model.find_children(
        "Weapons",
        "Node3D",
        true,
        false
    )
    if candidates.size() != 1:
        return null
    return candidates[0] as Node3D

func _on_projectile_resolved(
    _projectile: PulseProjectile,
    result: DamageResult,
    hit_damageable: bool
) -> void:
    if hit_damageable and result != null:
        damage_confirmed.emit(result)

func _disable_primary(message: String) -> void:
    push_error(message)
    _muzzles_valid = false
    _firing_enabled = false
    _cadence.advance(false, 0.0)
    set_physics_process(false)
