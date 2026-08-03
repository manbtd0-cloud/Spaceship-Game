class_name PulseProjectilePool
extends Node3D

signal projectile_resolved(
    projectile: PulseProjectile,
    damage_result: DamageResult,
    hit_damageable: bool
)

const PREWARM_COUNT := 32
const DEFAULT_PROJECTILE_SCENE := preload(
    "res://scenes/combat/pulse_projectile.tscn"
)

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE

var _projectiles: Array[PulseProjectile] = []
var _activation_age: Dictionary = {}
var _sequence := 0
var _initialized := false

func _ready() -> void:
    initialize()

func initialize() -> void:
    if _initialized:
        return
    _initialized = true

    if projectile_scene == null:
        push_error("PulseProjectilePool requires a projectile scene")
        return

    for _index: int in range(PREWARM_COUNT):
        var projectile := projectile_scene.instantiate() as PulseProjectile
        if projectile == null:
            push_error("PulseProjectilePool scene root must be PulseProjectile")
            continue
        add_child(projectile)
        projectile.resolved.connect(_on_projectile_resolved)
        projectile.deactivate()
        _projectiles.append(projectile)

func fire(
    world_transform: Transform3D,
    velocity: Vector3,
    source_body: CollisionObject3D
) -> PulseProjectile:
    initialize()
    if _projectiles.is_empty():
        return null

    var projectile := _first_inactive()
    if projectile == null:
        projectile = _oldest_active()
    if projectile == null:
        return null

    if projectile.is_active():
        projectile.deactivate()

    _sequence += 1
    _activation_age[projectile.get_instance_id()] = _sequence
    projectile.activate(
        world_transform,
        velocity,
        source_body,
        PulseProjectile.DEFAULT_DAMAGE,
        PulseProjectile.DEFAULT_LIFETIME
    )
    return projectile

func clear_all() -> void:
    for projectile: PulseProjectile in _projectiles:
        projectile.deactivate()
    _activation_age.clear()
    _sequence = 0

func get_projectile_count() -> int:
    return _projectiles.size()

func get_active_count() -> int:
    var count := 0
    for projectile: PulseProjectile in _projectiles:
        if projectile.is_active():
            count += 1
    return count

func get_active_projectiles() -> Array[PulseProjectile]:
    var result: Array[PulseProjectile] = []
    for projectile: PulseProjectile in _projectiles:
        if projectile.is_active():
            result.append(projectile)
    return result

func _first_inactive() -> PulseProjectile:
    for projectile: PulseProjectile in _projectiles:
        if not projectile.is_active():
            return projectile
    return null

func _oldest_active() -> PulseProjectile:
    var oldest: PulseProjectile
    var oldest_age := 9223372036854775807
    for projectile: PulseProjectile in _projectiles:
        if not projectile.is_active():
            continue
        var age := int(
            _activation_age.get(projectile.get_instance_id(), oldest_age)
        )
        if age < oldest_age:
            oldest = projectile
            oldest_age = age
    return oldest

func _on_projectile_resolved(
    projectile: PulseProjectile,
    damage_result: DamageResult,
    hit_damageable: bool
) -> void:
    projectile_resolved.emit(projectile, damage_result, hit_damageable)
