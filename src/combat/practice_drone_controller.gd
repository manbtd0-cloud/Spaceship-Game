class_name PracticeDroneController
extends Node

signal respawn_started(duration: float)
signal respawn_progress(seconds_remaining: float)
signal respawned

@export var body_path: NodePath = NodePath("..")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var collision_receiver_path: NodePath = NodePath("../CollisionDamageReceiver")
@export var shield_visualizer_path: NodePath = NodePath("../ShieldImpactVisualizer")
@export var visual_root_path: NodePath = NodePath("../VisualRoot")
@export var destruction_pulse_path: NodePath = NodePath("../DestructionPulse")
@export var tuning: PracticeDroneTuning

var _body: RigidBody3D
var _damage_state: DamageState
var _collision_receiver: CollisionDamageReceiver
var _shield_visualizer: ShieldImpactVisualizer
var _visual_root: Node3D
var _destruction_pulse: MeshInstance3D
var _target: RigidBody3D
var _intent := PracticeDroneIntent.new()
var _spawn_transform := Transform3D.IDENTITY
var _saved_collision_layer := 1
var _saved_collision_mask := 1
var _elapsed := 0.0
var _respawn_remaining := 0.0
var _destruction_elapsed := 0.0
var _initialized := false

func _ready() -> void:
    initialize()

func initialize() -> void:
    if _initialized:
        return
    _initialized = true

    _body = get_node_or_null(body_path) as RigidBody3D
    _damage_state = get_node_or_null(damage_state_path) as DamageState
    _collision_receiver = get_node_or_null(
        collision_receiver_path
    ) as CollisionDamageReceiver
    _shield_visualizer = get_node_or_null(
        shield_visualizer_path
    ) as ShieldImpactVisualizer
    _visual_root = get_node_or_null(visual_root_path) as Node3D
    _destruction_pulse = get_node_or_null(
        destruction_pulse_path
    ) as MeshInstance3D

    if (
        _body == null
        or _damage_state == null
        or _visual_root == null
        or _destruction_pulse == null
        or tuning == null
    ):
        push_error("PracticeDroneController dependencies are incomplete")
        set_physics_process(false)
        return

    _spawn_transform = _body.global_transform
    _saved_collision_layer = _body.collision_layer
    _saved_collision_mask = _body.collision_mask
    _destruction_pulse.visible = false
    if not _damage_state.destroyed.is_connected(_on_destroyed):
        _damage_state.destroyed.connect(_on_destroyed)

func set_target(body: RigidBody3D) -> void:
    _target = body

func _physics_process(delta: float) -> void:
    step_for_test(delta)

func step_for_test(delta: float) -> void:
    initialize()
    if _body == null or tuning == null:
        return

    var safe_delta := maxf(delta, 0.0)
    if _respawn_remaining > 0.0:
        _advance_respawn(safe_delta)
        return
    if _damage_state == null or _damage_state.is_destroyed():
        return
    if _target == null or not is_instance_valid(_target):
        _intent.clear()
        return

    _elapsed += safe_delta
    var relative_position := (
        _target.global_position - _body.global_position
    )
    var relative_velocity := (
        _body.linear_velocity - _target.linear_velocity
    )
    PracticeDroneSteering.compute_into(
        _intent,
        relative_position,
        relative_velocity,
        -_body.global_transform.basis.z,
        _body.angular_velocity,
        _elapsed,
        tuning
    )
    _body.apply_central_force(
        _intent.acceleration_world * _body.mass
    )
    _body.apply_torque(_intent.torque_world)

func reset_to_spawn() -> void:
    initialize()
    if _body == null:
        return

    _body.freeze = true
    _body.global_transform = _spawn_transform
    _body.linear_velocity = Vector3.ZERO
    _body.angular_velocity = Vector3.ZERO
    _body.collision_layer = _saved_collision_layer
    _body.collision_mask = _saved_collision_mask
    _body.sleeping = false
    if _visual_root != null:
        _visual_root.visible = true
    if _destruction_pulse != null:
        _destruction_pulse.visible = false
        _destruction_pulse.scale = Vector3.ONE
    if _damage_state != null:
        _damage_state.reset_full()
    if _collision_receiver != null:
        _collision_receiver.reset_runtime_state()
    if _shield_visualizer != null:
        _shield_visualizer.reset_visuals()

    _elapsed = 0.0
    _respawn_remaining = 0.0
    _destruction_elapsed = 0.0
    _intent.clear()
    _body.freeze = false
    respawned.emit()

func is_respawning() -> bool:
    return _respawn_remaining > 0.0

func get_respawn_remaining() -> float:
    return _respawn_remaining

func get_last_intent() -> PracticeDroneIntent:
    return _intent.duplicate_intent()

func get_damage_state() -> DamageState:
    return _damage_state

func _on_destroyed(_result: DamageResult) -> void:
    if _body == null or tuning == null or is_respawning():
        return

    _respawn_remaining = maxf(tuning.respawn_delay, 0.0)
    _destruction_elapsed = 0.0
    _intent.clear()
    _body.freeze = true
    _body.linear_velocity = Vector3.ZERO
    _body.angular_velocity = Vector3.ZERO
    _body.collision_layer = 0
    _body.collision_mask = 0
    if _destruction_pulse != null:
        _destruction_pulse.visible = true
        _destruction_pulse.scale = Vector3.ONE * 0.4
    respawn_started.emit(_respawn_remaining)
    respawn_progress.emit(_respawn_remaining)

    if _respawn_remaining <= 0.0:
        reset_to_spawn()

func _advance_respawn(delta: float) -> void:
    _destruction_elapsed += delta
    _respawn_remaining = maxf(_respawn_remaining - delta, 0.0)

    if _visual_root != null and _destruction_elapsed >= 0.12:
        _visual_root.visible = false
    if _destruction_pulse != null:
        if _destruction_elapsed <= 0.45:
            var pulse_t := clampf(_destruction_elapsed / 0.45, 0.0, 1.0)
            _destruction_pulse.visible = true
            _destruction_pulse.scale = Vector3.ONE * lerpf(0.4, 2.8, pulse_t)
        else:
            _destruction_pulse.visible = false

    respawn_progress.emit(_respawn_remaining)
    if _respawn_remaining <= 0.0:
        reset_to_spawn()
