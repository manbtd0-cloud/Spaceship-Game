class_name CombatCameraFeedbackController
extends Node

@export var camera_path: NodePath = NodePath("../ChaseCameraRig/Camera3D")
@export var player_body_path: NodePath = NodePath("../PlayerInterceptor")
@export var enemy_body_path: NodePath = NodePath("../EnemyFighter")
@export var player_damage_path: NodePath = NodePath("../PlayerInterceptor/DamageState")
@export var enemy_damage_path: NodePath = NodePath("../EnemyFighter/DamageState")

var _camera: Camera3D
var _player_body: RigidBody3D
var _enemy_body: RigidBody3D
var _player_damage: DamageState
var _enemy_damage: DamageState
var _state := CombatCameraImpulseState.new()
var _initialized := false

func _ready() -> void:
    initialize()

func _process(delta: float) -> void:
    step_for_test(delta)

func initialize() -> void:
    if _initialized:
        return
    _camera = get_node_or_null(camera_path) as Camera3D
    _player_body = get_node_or_null(player_body_path) as RigidBody3D
    _enemy_body = get_node_or_null(enemy_body_path) as RigidBody3D
    _player_damage = get_node_or_null(player_damage_path) as DamageState
    _enemy_damage = get_node_or_null(enemy_damage_path) as DamageState
    if (
        _camera == null
        or _player_body == null
        or _enemy_body == null
        or _player_damage == null
        or _enemy_damage == null
    ):
        push_error("CombatCameraFeedbackController dependencies are incomplete")
        set_process(false)
        return

    _player_damage.damage_resolved.connect(_on_player_damage)
    _player_damage.shield_broken.connect(_on_player_shield_broken)
    _enemy_damage.destroyed.connect(_on_enemy_destroyed)
    _initialized = true
    _clear_camera_offset()

func step_for_test(delta: float) -> void:
    if not _initialized:
        initialize()
    if not _initialized:
        return
    _state.advance(delta)
    _apply_camera_offset(
        _state.get_translation_offset(),
        _state.get_rotation_offset_degrees()
    )

func reset_runtime_state() -> void:
    _state.reset()
    _clear_camera_offset()

func get_current_strength() -> float:
    return _state.get_strength()

func _on_player_damage(result: DamageResult) -> void:
    _state.request_player_damage(result)

func _on_player_shield_broken(_result: DamageResult) -> void:
    _state.request_shield_break()

func _on_enemy_destroyed(_result: DamageResult) -> void:
    if _player_body == null or _enemy_body == null:
        return
    _state.request_explosion(
        _player_body.global_position.distance_to(_enemy_body.global_position)
    )

func _apply_camera_offset(translation_local: Vector3, rotation_degrees: Vector3) -> void:
    if _camera == null:
        return
    var safe_translation := (
        translation_local.limit_length(CombatCameraImpulseState.MAX_TRANSLATION_METERS)
        if translation_local.is_finite()
        else Vector3.ZERO
    )
    var safe_rotation := (
        rotation_degrees.limit_length(CombatCameraImpulseState.MAX_ROTATION_DEGREES)
        if rotation_degrees.is_finite()
        else Vector3.ZERO
    )
    _camera.transform = Transform3D(
        Basis.from_euler(Vector3(
            deg_to_rad(safe_rotation.x),
            deg_to_rad(safe_rotation.y),
            deg_to_rad(safe_rotation.z)
        )),
        safe_translation
    )

func _clear_camera_offset() -> void:
    if _camera != null:
        _camera.transform = Transform3D.IDENTITY
