class_name PrimaryFireShowcaseController
extends Node3D

@export var player_body_path: NodePath
@export var input_source_path: NodePath
@export var fire_controller_path: NodePath
@export var projectile_pool_path: NodePath
@export var instructions_label_path: NodePath
@export var telemetry_label_path: NodePath

var _body: RigidBody3D
var _input_source: PlayerInputSource
var _fire_controller: PrimaryFireController
var _pool: PulseProjectilePool
var _instructions_label: Label
var _telemetry_label: Label
var _shot_count := 0
var _resolved_count := 0
var _last_side_name := "NONE"
var _initialized := false

func _ready() -> void:
    initialize()

func _process(_delta: float) -> void:
    if _input_source != null and _input_source.consume_reset_request():
        reset_showcase()
    _update_telemetry()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"ui_cancel"):
        get_viewport().set_input_as_handled()
        get_tree().quit()

func initialize() -> void:
    if _initialized:
        return
    _initialized = true

    _body = get_node_or_null(player_body_path) as RigidBody3D
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource
    _fire_controller = get_node_or_null(
        fire_controller_path
    ) as PrimaryFireController
    _pool = get_node_or_null(projectile_pool_path) as PulseProjectilePool
    _instructions_label = get_node_or_null(
        instructions_label_path
    ) as Label
    _telemetry_label = get_node_or_null(telemetry_label_path) as Label

    if _body == null:
        _disable_with_error("PrimaryFireShowcase could not resolve player body")
        return
    if _input_source == null:
        _disable_with_error("PrimaryFireShowcase could not resolve input source")
        return
    if _fire_controller == null:
        _disable_with_error("PrimaryFireShowcase could not resolve fire controller")
        return
    if _pool == null:
        _disable_with_error("PrimaryFireShowcase could not resolve projectile pool")
        return
    if _instructions_label == null or _telemetry_label == null:
        _disable_with_error("PrimaryFireShowcase could not resolve HUD labels")
        return

    _body.freeze = true
    _body.linear_velocity = Vector3.ZERO
    _body.angular_velocity = Vector3.ZERO
    _input_source.set_mouse_captured(false)
    _fire_controller.set_projectile_pool(_pool)
    _fire_controller.set_firing_enabled(true)

    var shot_callback := Callable(self, "_on_shot_fired")
    if not _fire_controller.shot_fired.is_connected(shot_callback):
        _fire_controller.shot_fired.connect(shot_callback)

    var resolved_callback := Callable(self, "_on_projectile_resolved")
    if not _pool.projectile_resolved.is_connected(resolved_callback):
        _pool.projectile_resolved.connect(resolved_callback)

    _update_telemetry()

func reset_showcase() -> void:
    if _pool != null:
        _pool.clear_all()
    if _fire_controller != null:
        _fire_controller.reset_runtime_state()
    _shot_count = 0
    _resolved_count = 0
    _last_side_name = "NONE"
    _update_telemetry()

func get_shot_count() -> int:
    return _shot_count

func get_resolved_count() -> int:
    return _resolved_count

func get_last_side_name() -> String:
    return _last_side_name

func _on_shot_fired(side: int, _world_transform: Transform3D) -> void:
    _shot_count += 1
    _last_side_name = (
        "LEFT"
        if side == PrimaryFireCadence.MuzzleSide.LEFT
        else "RIGHT"
    )
    _update_telemetry()

func _on_projectile_resolved(
    _projectile: PulseProjectile,
    _damage_result: DamageResult,
    _hit_damageable: bool
) -> void:
    _resolved_count += 1
    _update_telemetry()

func _update_telemetry() -> void:
    if _telemetry_label == null:
        return
    var active_count := _pool.get_active_count() if _pool != null else 0
    _telemetry_label.text = (
        "SHOTS  %04d\nACTIVE  %02d / 32\nIMPACTS  %04d\nLAST MUZZLE  %s"
        % [
            _shot_count,
            active_count,
            _resolved_count,
            _last_side_name,
        ]
    )

func _disable_with_error(message: String) -> void:
    push_error(message)
    set_process(false)
    set_process_unhandled_input(false)
