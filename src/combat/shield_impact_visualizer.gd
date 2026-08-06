class_name ShieldImpactVisualizer
extends Node3D

const IMPACT_SLOT_COUNT := 4
const SHIELD_SHADER := preload("res://shaders/shield_hex_impact.gdshader")

@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var ellipsoid_radii: Vector3 = Vector3(8.2, 3.0, 7.2)
@export var shield_color: Color = Color(0.12, 0.72, 1.0, 1.0)
@export var hit_duration: float = 0.55
@export var break_duration: float = 0.85

var _damage_state: DamageState
var _impact_meshes: Array[MeshInstance3D] = []
var _impact_materials: Array[ShaderMaterial] = []
var _impact_energies: Array[float] = []
var _impact_durations: Array[float] = []
var _break_mesh: MeshInstance3D
var _break_material: ShaderMaterial
var _break_energy := 0.0
var _break_time_remaining := 0.0
var _next_slot := 0
var _last_local_direction := Vector3.FORWARD
var _shield_ratio := 1.0

func _ready() -> void:
    _damage_state = get_node_or_null(damage_state_path) as DamageState
    if _damage_state == null:
        push_error("ShieldImpactVisualizer requires DamageState")
        set_process(false)
        return

    for index: int in range(IMPACT_SLOT_COUNT):
        var mesh := get_node_or_null("Impact%02d" % (index + 1)) as MeshInstance3D
        if mesh == null:
            push_error("ShieldImpactVisualizer is missing impact slot %d" % index)
            set_process(false)
            return
        mesh.scale = ellipsoid_radii
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var material := ShaderMaterial.new()
        material.shader = SHIELD_SHADER
        material.set_shader_parameter("shield_color", shield_color)
        material.set_shader_parameter("energy", 0.0)
        material.set_shader_parameter("shield_ratio", 1.0)
        material.set_shader_parameter("full_shell", 0.0)
        mesh.material_override = material
        mesh.visible = false
        _impact_meshes.append(mesh)
        _impact_materials.append(material)
        _impact_energies.append(0.0)
        _impact_durations.append(0.0)

    _break_mesh = get_node_or_null("BreakShell") as MeshInstance3D
    if _break_mesh == null:
        push_error("ShieldImpactVisualizer is missing BreakShell")
        set_process(false)
        return
    _break_mesh.scale = ellipsoid_radii
    _break_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _break_material = ShaderMaterial.new()
    _break_material.shader = SHIELD_SHADER
    _break_material.set_shader_parameter("shield_color", shield_color)
    _break_material.set_shader_parameter("energy", 0.0)
    _break_material.set_shader_parameter("shield_ratio", 1.0)
    _break_material.set_shader_parameter("full_shell", 1.0)
    _break_mesh.material_override = _break_material
    _break_mesh.visible = false

    _shield_ratio = _damage_state.get_shield_ratio()
    _damage_state.damage_resolved.connect(_on_damage_resolved)
    _damage_state.shield_broken.connect(_on_shield_broken)
    _damage_state.state_changed.connect(_on_state_changed)
    reset_visuals()

func _process(delta: float) -> void:
    var safe_delta := maxf(delta, 0.0)
    for index: int in range(_impact_energies.size()):
        if _impact_energies[index] <= 0.0:
            continue
        _impact_durations[index] = maxf(
            _impact_durations[index] - safe_delta,
            0.0
        )
        var duration := maxf(hit_duration, 0.001)
        _impact_energies[index] = clampf(
            _impact_durations[index] / duration,
            0.0,
            1.0
        )
        _apply_impact_slot(index)

    if _break_energy > 0.0:
        _break_time_remaining = maxf(
            _break_time_remaining - safe_delta,
            0.0
        )
        _break_energy = clampf(
            _break_time_remaining / maxf(break_duration, 0.001),
            0.0,
            1.0
        )
        _apply_break_shell()

func get_active_impact_count() -> int:
    var count := 0
    for energy: float in _impact_energies:
        if energy > 0.0001:
            count += 1
    return count

func get_last_local_direction() -> Vector3:
    return _last_local_direction

func get_break_energy() -> float:
    return _break_energy

func reset_visuals() -> void:
    _next_slot = 0
    _last_local_direction = Vector3.FORWARD
    for index: int in range(_impact_energies.size()):
        _impact_energies[index] = 0.0
        _impact_durations[index] = 0.0
        _apply_impact_slot(index)
    _break_energy = 0.0
    _break_time_remaining = 0.0
    _apply_break_shell()

func _on_damage_resolved(result: DamageResult) -> void:
    if result == null or result.applied_to_shield <= 0.0:
        return
    var maximum_shield := (
        _damage_state.tuning.maximum_shield
        if _damage_state.tuning != null
        else 0.0
    )
    var energy := ShieldImpactMath.hit_energy(
        result.applied_to_shield,
        maximum_shield
    )
    if energy <= 0.0:
        return

    var slot := _next_slot
    _next_slot = (_next_slot + 1) % IMPACT_SLOT_COUNT
    _last_local_direction = ShieldImpactMath.local_direction(
        to_local(result.impact_point),
        ellipsoid_radii
    )
    _impact_energies[slot] = energy
    _impact_durations[slot] = maxf(hit_duration, 0.001) * energy
    _impact_materials[slot].set_shader_parameter(
        "impact_direction",
        _last_local_direction
    )
    _apply_impact_slot(slot)

func _on_shield_broken(_result: DamageResult) -> void:
    _break_energy = 1.0
    _break_time_remaining = maxf(break_duration, 0.001)
    _apply_break_shell()

func _on_state_changed(_shield: float, _hull: float) -> void:
    if _damage_state == null:
        return
    _shield_ratio = _damage_state.get_shield_ratio()
    for index: int in range(_impact_materials.size()):
        _impact_materials[index].set_shader_parameter(
            "shield_ratio",
            _shield_ratio
        )
    if _break_material != null:
        _break_material.set_shader_parameter(
            "shield_ratio",
            _shield_ratio
        )

func _apply_impact_slot(index: int) -> void:
    if index < 0 or index >= _impact_meshes.size():
        return
    var energy := clampf(_impact_energies[index], 0.0, 1.0)
    _impact_materials[index].set_shader_parameter("energy", energy)
    _impact_materials[index].set_shader_parameter(
        "shield_ratio",
        _shield_ratio
    )
    _impact_meshes[index].visible = energy > 0.0001

func _apply_break_shell() -> void:
    if _break_mesh == null or _break_material == null:
        return
    _break_material.set_shader_parameter(
        "energy",
        clampf(_break_energy, 0.0, 1.0)
    )
    _break_material.set_shader_parameter(
        "shield_ratio",
        _shield_ratio
    )
    _break_mesh.visible = _break_energy > 0.0001
