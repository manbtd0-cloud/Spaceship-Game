class_name FlightRoomController
extends Node

const PLAYER_RESPAWN_DELAY := 1.25

@export var player_body_path: NodePath
@export var player_controller_path: NodePath
@export var input_source_path: NodePath
@export var reset_volume_path: NodePath
@export var player_damage_state_path: NodePath
@export var player_collision_receiver_path: NodePath
@export var player_shield_visualizer_path: NodePath
@export var enemy_fighter_controller_path: NodePath
@export var boundary_radius: float = 2500.0

var _body: RigidBody3D
var _controller: ShipFlightController
var _input_source: PlayerInputSource
var _primary_fire_controller: PrimaryFireController
var _projectile_pool: PulseProjectilePool
var _reset_volume: Area3D
var _player_damage_state: DamageState
var _player_collision_receiver: CollisionDamageReceiver
var _player_shield_visualizer: ShieldImpactVisualizer
var _enemy_fighter_controller: EnemyFighterController
var _spawn_transform := Transform3D.IDENTITY
var _player_respawn_remaining := 0.0

func _ready() -> void:
    _body = get_node_or_null(player_body_path) as RigidBody3D
    _controller = get_node_or_null(player_controller_path) as ShipFlightController
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource
    _reset_volume = get_node_or_null(reset_volume_path) as Area3D

    if not player_damage_state_path.is_empty():
        _player_damage_state = get_node_or_null(
            player_damage_state_path
        ) as DamageState
    if not player_collision_receiver_path.is_empty():
        _player_collision_receiver = get_node_or_null(
            player_collision_receiver_path
        ) as CollisionDamageReceiver
    if not player_shield_visualizer_path.is_empty():
        _player_shield_visualizer = get_node_or_null(
            player_shield_visualizer_path
        ) as ShieldImpactVisualizer
    if not enemy_fighter_controller_path.is_empty():
        _enemy_fighter_controller = get_node_or_null(
            enemy_fighter_controller_path
        ) as EnemyFighterController

    if _body != null:
        _primary_fire_controller = _body.get_node_or_null(
            "PrimaryFireController"
        ) as PrimaryFireController
        _projectile_pool = _body.get_node_or_null(
            "PulseProjectilePool"
        ) as PulseProjectilePool

    if _body == null:
        _disable_with_error("FlightRoomController could not resolve player body")
        return
    if _controller == null:
        _disable_with_error("FlightRoomController could not resolve ship controller")
        return
    if _input_source == null:
        _disable_with_error("FlightRoomController could not resolve input source")
        return
    if _primary_fire_controller == null:
        _disable_with_error(
            "FlightRoomController could not resolve production primary fire controller"
        )
        return
    if _projectile_pool == null:
        _disable_with_error(
            "FlightRoomController could not resolve production projectile pool"
        )
        return
    if _reset_volume == null:
        _disable_with_error("FlightRoomController could not resolve reset volume")
        return

    _primary_fire_controller.set_firing_enabled(true)
    _spawn_transform = _body.global_transform

    if not _controller.reset_requested.is_connected(reset_player):
        _controller.reset_requested.connect(reset_player)
    if not _reset_volume.body_entered.is_connected(_on_reset_volume_body_entered):
        _reset_volume.body_entered.connect(_on_reset_volume_body_entered)
    if (
        _player_damage_state != null
        and not _player_damage_state.destroyed.is_connected(_on_player_destroyed)
    ):
        _player_damage_state.destroyed.connect(_on_player_destroyed)
    if _enemy_fighter_controller != null:
        _enemy_fighter_controller.set_target(_body)
        _enemy_fighter_controller.set_hostile_projectile_pool(_projectile_pool)

    _input_source.set_mouse_captured(true)
    if not setup_asteroid_field():
        push_warning(
            "Canonical asteroid pack is unavailable; keeping distant reference placeholders"
        )

func _physics_process(delta: float) -> void:
    if _player_respawn_remaining > 0.0:
        _player_respawn_remaining = maxf(
            _player_respawn_remaining - maxf(delta, 0.0),
            0.0
        )
        if _player_respawn_remaining <= 0.0:
            reset_player()
        return

    if _body.global_position.length() > maxf(boundary_radius, 1.0):
        reset_player()

func setup_asteroid_field(models: Dictionary = {}) -> bool:
    var room := get_parent() as Node3D
    if room == null:
        return false
    var course := room.get_node_or_null("Course") as Node3D
    if course == null:
        return false

    var resolved_models := models
    if resolved_models.is_empty():
        resolved_models = AsteroidField.load_runtime_models()
    if resolved_models.size() != AsteroidFieldLayout.FAMILY_IDS.size():
        return false

    var field := course.get_node_or_null("AsteroidField") as AsteroidField
    var created_field := false
    if field == null:
        field = AsteroidField.new()
        field.name = "AsteroidField"
        course.add_child(field)
        created_field = true

    if not field.build(resolved_models):
        if created_field:
            course.remove_child(field)
            field.free()
        return false

    var references := course.get_node_or_null("DistantReferenceShapes")
    if references != null:
        course.remove_child(references)
        references.free()
    return true

func get_player_respawn_remaining() -> float:
    return _player_respawn_remaining

func _on_reset_volume_body_entered(other: Node) -> void:
    if other == _body:
        reset_player()

func _on_player_destroyed(_result: DamageResult) -> void:
    if _player_respawn_remaining > 0.0:
        return
    _player_respawn_remaining = PLAYER_RESPAWN_DELAY
    _body.freeze = true
    _controller.set_physics_process(false)
    _primary_fire_controller.set_firing_enabled(false)
    _projectile_pool.clear_all()

func reset_player() -> void:
    if get_tree() != null and get_tree().paused:
        get_tree().paused = false

    _player_respawn_remaining = 0.0
    _body.freeze = true
    _body.global_transform = _spawn_transform
    _body.reset_physics_interpolation()
    _body.linear_velocity = Vector3.ZERO
    _body.angular_velocity = Vector3.ZERO
    _controller.reset_runtime_state()
    _controller.set_physics_process(true)
    _primary_fire_controller.reset_runtime_state()
    _primary_fire_controller.set_firing_enabled(true)
    _projectile_pool.clear_all()

    if _player_damage_state != null:
        _player_damage_state.reset_full()
    if _player_collision_receiver != null:
        _player_collision_receiver.reset_runtime_state()
    if _player_shield_visualizer != null:
        _player_shield_visualizer.reset_visuals()
    if _enemy_fighter_controller != null:
        _enemy_fighter_controller.reset_to_spawn()

    _body.freeze = false
    _body.sleeping = false

func _disable_with_error(message: String) -> void:
    push_error(message)
    set_physics_process(false)
