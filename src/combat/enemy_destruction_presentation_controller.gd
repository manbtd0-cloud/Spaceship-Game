class_name EnemyDestructionPresentationController
extends Node3D

const EnemyDestructionTimeline = preload("res://src/combat/enemy_destruction_timeline.gd")
const EnemyThrusterVisualController = preload("res://src/combat/enemy_thruster_visual_controller.gd")
const DEBRIS_COUNT := 5
const INTERNAL_FLASH_COUNT := 3

@export var body_path: NodePath = NodePath("..")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var flight_controller_path: NodePath = NodePath("../EnemyFighterController")
@export var visual_root_path: NodePath = NodePath("../VisualRoot")
@export var core_pulse_path: NodePath = NodePath("../DestructionPulse")
@export var thruster_visual_path: NodePath = NodePath("../EnemyThrusterVisualController")

var _body: RigidBody3D
var _damage: DamageState
var _flight: EnemyFighterController
var _visual_root: Node3D
var _core: MeshInstance3D
var _thrusters: EnemyThrusterVisualController
var _shockwave: MeshInstance3D
var _core_material: StandardMaterial3D
var _shockwave_material: StandardMaterial3D
var _internal_flashes: Array[MeshInstance3D] = []
var _debris: Array[MeshInstance3D] = []
var _debris_velocities: Array[Vector3] = []
var _source_velocity := Vector3.ZERO
var _last_live_velocity := Vector3.ZERO
var _elapsed := 0.0
var _active := false
var _blast_spawned := false
var _initialized := false

func _ready() -> void:
    initialize()

func _process(delta: float) -> void:
    initialize()
    if not _initialized:
        return
    if not _active:
        if _body != null and _damage != null and not _damage.is_destroyed():
            _last_live_velocity = _body.linear_velocity
        return
    step_for_test(delta)

func initialize() -> void:
    if _initialized:
        return
    _body = get_node_or_null(body_path) as RigidBody3D
    _damage = get_node_or_null(damage_state_path) as DamageState
    _flight = get_node_or_null(flight_controller_path) as EnemyFighterController
    _visual_root = get_node_or_null(visual_root_path) as Node3D
    _core = get_node_or_null(core_pulse_path) as MeshInstance3D
    _thrusters = get_node_or_null(thruster_visual_path) as EnemyThrusterVisualController
    if _body == null or _damage == null or _flight == null or _visual_root == null or _core == null:
        push_error("EnemyDestructionPresentationController dependencies are incomplete")
        set_process(false)
        return

    _create_visual_resources()
    if not _damage.damage_resolved.is_connected(_on_damage_resolved):
        _damage.damage_resolved.connect(_on_damage_resolved)
    if not _damage.destroyed.is_connected(_on_destroyed):
        _damage.destroyed.connect(_on_destroyed)
    if not _flight.respawned.is_connected(_on_respawned):
        _flight.respawned.connect(_on_respawned)
    _initialized = true
    reset_visuals()

func capture_live_state_for_test() -> void:
    initialize()
    if _body != null:
        _last_live_velocity = _body.linear_velocity

func step_for_test(delta: float) -> void:
    if not _active:
        return
    var safe_delta := maxf(delta, 0.0)
    _elapsed += safe_delta
    var stage := EnemyDestructionTimeline.stage_at(_elapsed)
    if stage >= EnemyDestructionTimeline.Stage.BLAST and not _blast_spawned:
        _spawn_blast_debris()
        _blast_spawned = true
    if stage >= EnemyDestructionTimeline.Stage.BLAST:
        _visual_root.visible = false

    _apply_buildup()
    _apply_core()
    _apply_shockwave()
    _advance_debris(safe_delta)

    if stage == EnemyDestructionTimeline.Stage.COMPLETE:
        _finish_temporary_effects()

func reset_visuals() -> void:
    _active = false
    _elapsed = 0.0
    _blast_spawned = false
    _source_velocity = Vector3.ZERO
    if _core != null:
        _core.visible = false
        _core.scale = Vector3.ONE
    if _shockwave != null:
        _shockwave.visible = false
        _shockwave.scale = Vector3.ONE
    for flash in _internal_flashes:
        flash.visible = false
    for item in _debris:
        item.visible = false
        item.position = Vector3.ZERO
        item.rotation = Vector3.ZERO
    if _visual_root != null and (_damage == null or not _damage.is_destroyed()):
        _visual_root.visible = true

func is_active() -> bool:
    return _active

func get_stage() -> EnemyDestructionTimeline.Stage:
    return EnemyDestructionTimeline.stage_at(_elapsed)

func get_core_energy() -> float:
    return EnemyDestructionTimeline.core_energy(_elapsed)

func get_visible_debris_count() -> int:
    var count := 0
    for item in _debris:
        if item.visible:
            count += 1
    return count

func get_source_velocity() -> Vector3:
    return _source_velocity

func _on_damage_resolved(result: DamageResult) -> void:
    if result != null and result.destroyed and _body != null:
        _last_live_velocity = _body.linear_velocity

func _on_destroyed(_result: DamageResult) -> void:
    _source_velocity = _last_live_velocity
    _elapsed = 0.0
    _active = true
    _blast_spawned = false
    if _visual_root != null:
        _visual_root.visible = true
    if _thrusters != null:
        _thrusters.reset_visuals()
    _apply_buildup()

func _on_respawned() -> void:
    reset_visuals()
    if _visual_root != null:
        _visual_root.visible = true

func _create_visual_resources() -> void:
    _core_material = _additive_material(Color(1.0, 0.28, 0.05, 1.0))
    _core.material_override = _core_material

    _shockwave = MeshInstance3D.new()
    _shockwave.name = "Shockwave"
    var shock_mesh := SphereMesh.new()
    shock_mesh.radius = 1.0
    shock_mesh.height = 2.0
    shock_mesh.radial_segments = 32
    shock_mesh.rings = 16
    _shockwave.mesh = shock_mesh
    _shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _shockwave_material = _additive_material(Color(1.0, 0.18, 0.04, 1.0))
    _shockwave.material_override = _shockwave_material
    add_child(_shockwave)

    for index in range(INTERNAL_FLASH_COUNT):
        var flash := MeshInstance3D.new()
        flash.name = "InternalFlash%02d" % (index + 1)
        var flash_mesh := SphereMesh.new()
        flash_mesh.radius = 0.35
        flash_mesh.height = 0.70
        flash_mesh.radial_segments = 10
        flash_mesh.rings = 5
        flash.mesh = flash_mesh
        flash.material_override = _additive_material(Color(1.0, 0.42, 0.06, 1.0))
        flash.position = Vector3(-2.4 + index * 2.4, 0.25 * (index - 1), -0.8 + index * 0.7)
        add_child(flash)
        _internal_flashes.append(flash)

    for index in range(DEBRIS_COUNT):
        var fragment := MeshInstance3D.new()
        fragment.name = "Debris%02d" % (index + 1)
        var box := BoxMesh.new()
        box.size = Vector3(0.35 + 0.13 * index, 0.18 + 0.04 * (index % 2), 0.9 + 0.18 * (index % 3))
        fragment.mesh = box
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.13, 0.11, 0.10, 1.0)
        material.metallic = 0.75
        material.roughness = 0.35
        material.emission_enabled = true
        material.emission = Color(0.8, 0.07, 0.015, 1.0)
        material.emission_energy_multiplier = 0.8
        fragment.material_override = material
        add_child(fragment)
        _debris.append(fragment)
        _debris_velocities.append(Vector3.ZERO)

func _spawn_blast_debris() -> void:
    var local_source := _body.global_transform.basis.inverse() * _source_velocity
    var radial := [
        Vector3(1.0, 0.35, 0.1),
        Vector3(-0.8, 0.55, -0.2),
        Vector3(0.35, -0.65, 0.7),
        Vector3(-0.25, -0.35, -1.0),
        Vector3(0.7, 0.8, -0.45),
    ]
    for index in range(_debris.size()):
        _debris[index].visible = true
        _debris[index].position = radial[index].normalized() * (0.7 + 0.2 * index)
        _debris_velocities[index] = local_source + radial[index].normalized() * (7.0 + 2.0 * index)

func _advance_debris(delta: float) -> void:
    if not _blast_spawned:
        return
    var fade := clampf(1.0 - (_elapsed - 0.25) / 1.05, 0.0, 1.0)
    for index in range(_debris.size()):
        var item := _debris[index]
        if not item.visible:
            continue
        item.position += _debris_velocities[index] * delta
        item.rotate_x(delta * (2.1 + index * 0.3))
        item.rotate_y(delta * (1.4 + index * 0.2))
        item.scale = Vector3.ONE * maxf(fade, 0.05)
        if fade <= 0.0:
            item.visible = false

func _apply_buildup() -> void:
    var amount := EnemyDestructionTimeline.buildup_amount(_elapsed)
    for index in range(_internal_flashes.size()):
        var phase := clampf(amount * INTERNAL_FLASH_COUNT - index * 0.55, 0.0, 1.0)
        _internal_flashes[index].visible = phase > 0.02
        _internal_flashes[index].scale = Vector3.ONE * lerpf(0.35, 1.6, phase)

func _apply_core() -> void:
    var energy := EnemyDestructionTimeline.core_energy(_elapsed)
    _core.visible = energy > 0.001
    _core.scale = Vector3.ONE * lerpf(0.4, 3.6, energy)
    _core_material.albedo_color.a = energy
    _core_material.emission_energy_multiplier = 18.0 * energy

func _apply_shockwave() -> void:
    var amount := EnemyDestructionTimeline.shockwave_amount(_elapsed)
    _shockwave.visible = amount > 0.001
    var progress := clampf((_elapsed - EnemyDestructionTimeline.SHOCKWAVE_START) / (EnemyDestructionTimeline.SHOCKWAVE_END - EnemyDestructionTimeline.SHOCKWAVE_START), 0.0, 1.0)
    _shockwave.scale = Vector3.ONE * lerpf(1.2, 10.0, progress)
    _shockwave_material.albedo_color.a = amount * 0.65
    _shockwave_material.emission_energy_multiplier = 10.0 * amount

func _finish_temporary_effects() -> void:
    _active = false
    _core.visible = false
    _shockwave.visible = false
    for flash in _internal_flashes:
        flash.visible = false
    for item in _debris:
        item.visible = false

func _additive_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.albedo_color = Color(color.r, color.g, color.b, 0.0)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.0
    return material
