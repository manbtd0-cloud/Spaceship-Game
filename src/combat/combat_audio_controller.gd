class_name CombatAudioController
extends Node3D

const CombatAudioSynth = preload("res://src/combat/combat_audio_synth.gd")
const EnemyThrusterVisualController = preload("res://src/combat/enemy_thruster_visual_controller.gd")

@export var player_body_path: NodePath = NodePath("../PlayerInterceptor")
@export var enemy_body_path: NodePath = NodePath("../EnemyFighter")
@export var player_fire_path: NodePath = NodePath("../PlayerInterceptor/PrimaryFireController")
@export var enemy_weapon_path: NodePath = NodePath("../EnemyFighter/EnemyWeaponController")
@export var player_damage_path: NodePath = NodePath("../PlayerInterceptor/DamageState")
@export var enemy_damage_path: NodePath = NodePath("../EnemyFighter/DamageState")
@export var enemy_thrusters_path: NodePath = NodePath("../EnemyFighter/EnemyThrusterVisualController")

var _player_body: RigidBody3D
var _enemy_body: RigidBody3D
var _player_fire: PrimaryFireController
var _enemy_weapon: EnemyWeaponController
var _player_damage: DamageState
var _enemy_damage: DamageState
var _enemy_thrusters: EnemyThrusterVisualController
var _streams: Dictionary = {}
var _emitters: Dictionary = {}
var _event_counts: Dictionary = {}
var _thruster_level := 0.0
var _initialized := false

func _ready() -> void:
    initialize()

func _process(delta: float) -> void:
    step_for_test(delta)

func initialize() -> void:
    if _initialized:
        return
    _player_body = get_node_or_null(player_body_path) as RigidBody3D
    _enemy_body = get_node_or_null(enemy_body_path) as RigidBody3D
    _player_fire = get_node_or_null(player_fire_path) as PrimaryFireController
    _enemy_weapon = get_node_or_null(enemy_weapon_path) as EnemyWeaponController
    _player_damage = get_node_or_null(player_damage_path) as DamageState
    _enemy_damage = get_node_or_null(enemy_damage_path) as DamageState
    _enemy_thrusters = get_node_or_null(enemy_thrusters_path) as EnemyThrusterVisualController
    if (
        _player_body == null
        or _enemy_body == null
        or _player_fire == null
        or _enemy_weapon == null
        or _player_damage == null
        or _enemy_damage == null
        or _enemy_thrusters == null
    ):
        push_error("CombatAudioController dependencies are incomplete")
        set_process(false)
        return

    _streams = CombatAudioSynth.build_streams()
    if _streams.size() != 7:
        push_error("Combat audio synthesis did not produce all required streams")
        set_process(false)
        return

    _emitters[&"player_weapon"] = _create_emitter(&"PlayerWeaponAudio", &"Weapons")
    _emitters[&"enemy_weapon"] = _create_emitter(&"EnemyWeaponAudio", &"Weapons")
    _emitters[&"player_impact"] = _create_emitter(&"PlayerImpactAudio", &"Impacts")
    _emitters[&"enemy_impact"] = _create_emitter(&"EnemyImpactAudio", &"Impacts")
    _emitters[&"enemy_thruster"] = _create_emitter(&"EnemyThrusterAudio", &"Ship")
    _emitters[&"explosion"] = _create_emitter(&"EnemyExplosionAudio", &"Impacts")
    _emitters[&"debris"] = _create_emitter(&"EnemyDebrisAudio", &"Environment")

    var thruster_stream := (_streams[&"thruster"] as AudioStreamWAV).duplicate() as AudioStreamWAV
    if thruster_stream != null:
        thruster_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        thruster_stream.loop_begin = 0
        thruster_stream.loop_end = thruster_stream.data.size() / 2
        (_emitters[&"enemy_thruster"] as AudioStreamPlayer3D).stream = thruster_stream

    _player_fire.shot_fired.connect(_on_player_shot)
    _enemy_weapon.shot_fired.connect(_on_enemy_shot)
    _player_damage.damage_resolved.connect(_on_player_damage)
    _player_damage.shield_broken.connect(_on_player_shield_broken)
    _enemy_damage.damage_resolved.connect(_on_enemy_damage)
    _enemy_damage.shield_broken.connect(_on_enemy_shield_broken)
    _enemy_damage.destroyed.connect(_on_enemy_destroyed)
    _initialized = true
    step_for_test(0.0)

func step_for_test(_delta: float) -> void:
    if not _initialized:
        initialize()
    if not _initialized:
        return
    (_emitters[&"player_weapon"] as AudioStreamPlayer3D).global_position = _player_body.global_position
    (_emitters[&"player_impact"] as AudioStreamPlayer3D).global_position = _player_body.global_position
    (_emitters[&"enemy_weapon"] as AudioStreamPlayer3D).global_position = _enemy_body.global_position
    (_emitters[&"enemy_impact"] as AudioStreamPlayer3D).global_position = _enemy_body.global_position
    (_emitters[&"enemy_thruster"] as AudioStreamPlayer3D).global_position = _enemy_body.global_position
    (_emitters[&"explosion"] as AudioStreamPlayer3D).global_position = _enemy_body.global_position
    (_emitters[&"debris"] as AudioStreamPlayer3D).global_position = _enemy_body.global_position

    _thruster_level = clampf(_enemy_thrusters.get_max_target(), 0.0, 1.0)
    var thruster := _emitters[&"enemy_thruster"] as AudioStreamPlayer3D
    if _thruster_level > 0.005 and not _enemy_damage.is_destroyed():
        thruster.volume_db = lerpf(-30.0, -7.0, sqrt(_thruster_level))
        thruster.pitch_scale = lerpf(0.82, 1.12, _thruster_level)
        if not thruster.playing:
            thruster.play()
    elif thruster.playing:
        thruster.stop()

func get_emitter_count() -> int:
    return _emitters.size()

func get_event_count(event_name: StringName) -> int:
    return int(_event_counts.get(event_name, 0))

func get_thruster_level() -> float:
    return _thruster_level

func _create_emitter(node_name: StringName, bus_name: StringName) -> AudioStreamPlayer3D:
    var emitter := AudioStreamPlayer3D.new()
    emitter.name = node_name
    emitter.bus = bus_name
    emitter.max_distance = 1400.0
    emitter.unit_size = 10.0
    emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    add_child(emitter)
    return emitter

func _play(key: StringName, emitter_key: StringName, event_name: StringName, position: Vector3, pitch: float = 1.0) -> void:
    var emitter := _emitters[emitter_key] as AudioStreamPlayer3D
    emitter.global_position = position
    emitter.stream = _streams[key] as AudioStream
    emitter.pitch_scale = pitch
    emitter.play()
    _event_counts[event_name] = get_event_count(event_name) + 1

func _on_player_shot(_side: int, world_transform: Transform3D) -> void:
    _play(&"pulse", &"player_weapon", &"player_pulse", world_transform.origin, 1.0)

func _on_enemy_shot(_side: int, world_transform: Transform3D) -> void:
    _play(&"pulse", &"enemy_weapon", &"enemy_pulse", world_transform.origin, 0.92)

func _on_player_damage(result: DamageResult) -> void:
    if result == null:
        return
    if result.applied_to_shield > 0.0:
        _play(&"shield_hit", &"player_impact", &"player_shield_hit", result.impact_point, 0.96)
    elif result.applied_to_hull > 0.0:
        _play(&"hull_hit", &"player_impact", &"player_hull_hit", result.impact_point, 0.95)

func _on_enemy_damage(result: DamageResult) -> void:
    if result == null:
        return
    if result.applied_to_shield > 0.0:
        _play(&"shield_hit", &"enemy_impact", &"enemy_shield_hit", result.impact_point, 1.04)
    elif result.applied_to_hull > 0.0:
        _play(&"hull_hit", &"enemy_impact", &"enemy_hull_hit", result.impact_point, 1.03)

func _on_player_shield_broken(result: DamageResult) -> void:
    _play(&"shield_break", &"player_impact", &"player_shield_break", result.impact_point, 0.92)

func _on_enemy_shield_broken(result: DamageResult) -> void:
    _play(&"shield_break", &"enemy_impact", &"enemy_shield_break", result.impact_point, 1.0)

func _on_enemy_destroyed(result: DamageResult) -> void:
    var position := result.impact_point if result != null else _enemy_body.global_position
    _play(&"explosion", &"explosion", &"enemy_explosion", position, 0.94)
    _play(&"debris", &"debris", &"enemy_debris_tail", position, 1.0)
    var thruster := _emitters[&"enemy_thruster"] as AudioStreamPlayer3D
    if thruster.playing:
        thruster.stop()
