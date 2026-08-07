class_name CombatHud
extends Control

@export var player_damage_state_path: NodePath
@export var target_damage_state_path: NodePath
@export var target_controller_path: NodePath
@export var projectile_pool_path: NodePath

var _player_damage: DamageState
var _target_damage: DamageState
var _target_controller: EnemyFighterController
var _projectile_pool: PulseProjectilePool

var _player_shield_bar: ProgressBar
var _player_hull_bar: ProgressBar
var _player_shield_label: Label
var _player_hull_label: Label
var _target_shield_bar: ProgressBar
var _target_hull_bar: ProgressBar
var _target_shield_label: Label
var _target_hull_label: Label
var _target_status_label: Label
var _hit_marker: Control

var _hit_flash_remaining := 0.0
var _target_respawn_remaining := 0.0

func _ready() -> void:
    _player_damage = get_node_or_null(player_damage_state_path) as DamageState
    _target_damage = get_node_or_null(target_damage_state_path) as DamageState
    _target_controller = get_node_or_null(
        target_controller_path
    ) as EnemyFighterController
    _projectile_pool = get_node_or_null(
        projectile_pool_path
    ) as PulseProjectilePool

    _player_shield_bar = get_node_or_null(
        "PlayerPanel/VBox/ShieldBar"
    ) as ProgressBar
    _player_hull_bar = get_node_or_null(
        "PlayerPanel/VBox/HullBar"
    ) as ProgressBar
    _player_shield_label = get_node_or_null(
        "PlayerPanel/VBox/ShieldLabel"
    ) as Label
    _player_hull_label = get_node_or_null(
        "PlayerPanel/VBox/HullLabel"
    ) as Label
    _target_shield_bar = get_node_or_null(
        "TargetPanel/VBox/ShieldBar"
    ) as ProgressBar
    _target_hull_bar = get_node_or_null(
        "TargetPanel/VBox/HullBar"
    ) as ProgressBar
    _target_shield_label = get_node_or_null(
        "TargetPanel/VBox/ShieldLabel"
    ) as Label
    _target_hull_label = get_node_or_null(
        "TargetPanel/VBox/HullLabel"
    ) as Label
    _target_status_label = get_node_or_null(
        "TargetPanel/VBox/StatusLabel"
    ) as Label
    _hit_marker = get_node_or_null("HitMarker") as Control

    if (
        _player_damage == null
        or _target_damage == null
        or _target_controller == null
        or _projectile_pool == null
        or _player_shield_bar == null
        or _player_hull_bar == null
        or _target_shield_bar == null
        or _target_hull_bar == null
        or _target_status_label == null
        or _hit_marker == null
    ):
        push_error("CombatHud dependencies are incomplete")
        set_process(false)
        return

    _player_damage.state_changed.connect(_on_player_state_changed)
    _target_damage.state_changed.connect(_on_target_state_changed)
    _target_controller.respawn_started.connect(_on_respawn_started)
    _target_controller.respawn_progress.connect(_on_respawn_progress)
    _target_controller.respawned.connect(_on_respawned)
    _projectile_pool.projectile_resolved.connect(
        _on_projectile_resolved
    )

    _hit_marker.visible = false
    _refresh_player()
    _refresh_target()
    _refresh_target_status()

func _process(delta: float) -> void:
    if _hit_flash_remaining > 0.0:
        _hit_flash_remaining = maxf(
            _hit_flash_remaining - maxf(delta, 0.0),
            0.0
        )
    if _hit_marker != null:
        var alpha := clampf(_hit_flash_remaining / 0.12, 0.0, 1.0)
        _hit_marker.modulate.a = alpha
        _hit_marker.visible = alpha > 0.0001
    _refresh_target_status()

func get_hit_marker_alpha() -> float:
    return clampf(_hit_flash_remaining / 0.12, 0.0, 1.0)

func get_player_shield_percent() -> float:
    return _player_damage.get_shield_ratio() * 100.0 if _player_damage != null else 0.0

func get_player_hull_percent() -> float:
    return _player_damage.get_hull_ratio() * 100.0 if _player_damage != null else 0.0

func get_target_shield_percent() -> float:
    return _target_damage.get_shield_ratio() * 100.0 if _target_damage != null else 0.0

func get_target_hull_percent() -> float:
    return _target_damage.get_hull_ratio() * 100.0 if _target_damage != null else 0.0

func get_target_status_text() -> String:
    return _target_status_label.text if _target_status_label != null else ""

func _on_player_state_changed(_shield: float, _hull: float) -> void:
    _refresh_player()

func _on_target_state_changed(_shield: float, _hull: float) -> void:
    _refresh_target()

func _on_respawn_started(duration: float) -> void:
    _target_respawn_remaining = maxf(duration, 0.0)
    _refresh_target_status()

func _on_respawn_progress(seconds_remaining: float) -> void:
    _target_respawn_remaining = maxf(seconds_remaining, 0.0)
    _refresh_target_status()

func _on_respawned() -> void:
    _target_respawn_remaining = 0.0
    _refresh_target()
    _refresh_target_status()

func _on_projectile_resolved(
    _projectile: PulseProjectile,
    result: DamageResult,
    hit_damageable: bool
) -> void:
    if (
        hit_damageable
        and result != null
        and result.applied_amount > 0.0
    ):
        _hit_flash_remaining = 0.12

func _refresh_player() -> void:
    if _player_damage == null:
        return
    var shield_percent := get_player_shield_percent()
    var hull_percent := get_player_hull_percent()
    _player_shield_bar.value = shield_percent
    _player_hull_bar.value = hull_percent
    if _player_shield_label != null:
        _player_shield_label.text = "SHIELD  %03d%%" % roundi(shield_percent)
    if _player_hull_label != null:
        _player_hull_label.text = "HULL    %03d%%" % roundi(hull_percent)

func _refresh_target() -> void:
    if _target_damage == null:
        return
    var shield_percent := get_target_shield_percent()
    var hull_percent := get_target_hull_percent()
    _target_shield_bar.value = shield_percent
    _target_hull_bar.value = hull_percent
    if _target_shield_label != null:
        _target_shield_label.text = "SHIELD  %03d%%" % roundi(shield_percent)
    if _target_hull_label != null:
        _target_hull_label.text = "HULL    %03d%%" % roundi(hull_percent)

func _refresh_target_status() -> void:
    if _target_status_label == null or _target_controller == null:
        return
    if _target_controller.is_respawning():
        _target_status_label.text = "RESPAWN  %.1f s" % _target_respawn_remaining
    else:
        _target_status_label.text = "ACTIVE"
