class_name HullImpactVisualizer
extends Node3D

const IMPACT_SLOT_COUNT := 4

@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var burst_color: Color = Color(1.0, 0.32, 0.06, 1.0)
@export var hit_duration: float = 0.32

var _damage_state: DamageState
var _flash_meshes: Array[MeshInstance3D] = []
var _flash_materials: Array[StandardMaterial3D] = []
var _particles: Array[CPUParticles3D] = []
var _energies := PackedFloat32Array()
var _remaining := PackedFloat32Array()
var _next_slot := 0
var _last_energy := 0.0
var _last_local_direction := Vector3.UP

func _ready() -> void:
    _damage_state = get_node_or_null(damage_state_path) as DamageState
    if _damage_state == null:
        push_error("HullImpactVisualizer requires DamageState")
        set_process(false)
        return

    _energies.resize(IMPACT_SLOT_COUNT)
    _remaining.resize(IMPACT_SLOT_COUNT)
    _energies.fill(0.0)
    _remaining.fill(0.0)
    for index in range(IMPACT_SLOT_COUNT):
        _create_slot(index)

    if not _damage_state.damage_resolved.is_connected(_on_damage_resolved):
        _damage_state.damage_resolved.connect(_on_damage_resolved)
    reset_visuals()

func _process(delta: float) -> void:
    var safe_delta := maxf(delta, 0.0)
    for index in range(IMPACT_SLOT_COUNT):
        if _remaining[index] <= 0.0:
            continue
        _remaining[index] = maxf(_remaining[index] - safe_delta, 0.0)
        _energies[index] = clampf(
            _remaining[index] / maxf(hit_duration, 0.001),
            0.0,
            1.0
        )
        _apply_slot(index)

func get_active_burst_count() -> int:
    var count := 0
    for value in _remaining:
        if value > 0.0001:
            count += 1
    return count

func get_last_energy() -> float:
    return _last_energy

func get_last_local_direction() -> Vector3:
    return _last_local_direction

func reset_visuals() -> void:
    _next_slot = 0
    _last_energy = 0.0
    _last_local_direction = Vector3.UP
    for index in range(_flash_meshes.size()):
        _energies[index] = 0.0
        _remaining[index] = 0.0
        _particles[index].emitting = false
        _apply_slot(index)

func _on_damage_resolved(result: DamageResult) -> void:
    if result == null or result.applied_to_hull <= 0.0:
        return
    var maximum_hull := (
        _damage_state.tuning.maximum_hull
        if _damage_state.tuning != null
        else 0.0
    )
    var energy := HullImpactMath.energy(result.applied_to_hull, maximum_hull)
    if energy <= 0.0:
        return

    var slot := _next_slot
    _next_slot = (_next_slot + 1) % IMPACT_SLOT_COUNT
    var local_point := to_local(result.impact_point)
    var local_normal := global_transform.basis.inverse() * result.impact_normal
    _last_local_direction = HullImpactMath.local_direction(local_normal)
    _last_energy = energy
    _energies[slot] = energy
    _remaining[slot] = maxf(hit_duration, 0.001) * energy

    _flash_meshes[slot].position = local_point
    _particles[slot].position = local_point
    _particles[slot].direction = _last_local_direction
    _particles[slot].initial_velocity_min = lerpf(5.0, 8.0, energy)
    _particles[slot].initial_velocity_max = lerpf(9.0, 14.0, energy)
    _particles[slot].emitting = false
    _particles[slot].restart()
    _particles[slot].emitting = true
    _apply_slot(slot)

func _create_slot(_index: int) -> void:
    var flash := MeshInstance3D.new()
    flash.name = "HullFlash%02d" % (_flash_meshes.size() + 1)
    var mesh := SphereMesh.new()
    mesh.radius = 0.22
    mesh.height = 0.44
    mesh.radial_segments = 12
    mesh.rings = 6
    flash.mesh = mesh
    flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(burst_color.r, burst_color.g, burst_color.b, 0.0)
    material.emission_enabled = true
    material.emission = burst_color
    material.emission_energy_multiplier = 0.0
    flash.material_override = material
    add_child(flash)

    var sparks := CPUParticles3D.new()
    sparks.name = "HullSparks%02d" % (_particles.size() + 1)
    sparks.amount = 14
    sparks.lifetime = 0.34
    sparks.one_shot = true
    sparks.explosiveness = 0.95
    sparks.local_coords = true
    sparks.direction = Vector3.UP
    sparks.spread = 28.0
    sparks.gravity = Vector3.ZERO
    sparks.initial_velocity_min = 5.0
    sparks.initial_velocity_max = 10.0
    sparks.scale_amount_min = 0.035
    sparks.scale_amount_max = 0.10
    sparks.color = burst_color
    var spark_mesh := BoxMesh.new()
    spark_mesh.size = Vector3(0.035, 0.035, 0.32)
    sparks.mesh = spark_mesh
    add_child(sparks)

    _flash_meshes.append(flash)
    _flash_materials.append(material)
    _particles.append(sparks)

func _apply_slot(index: int) -> void:
    if index < 0 or index >= _flash_meshes.size():
        return
    var amount := clampf(_energies[index], 0.0, 1.0)
    var flash := _flash_meshes[index]
    var material := _flash_materials[index]
    flash.visible = amount > 0.0001
    flash.scale = Vector3.ONE * lerpf(0.65, 1.7, amount)
    material.albedo_color = Color(
        burst_color.r,
        burst_color.g,
        burst_color.b,
        amount * amount
    )
    material.emission = burst_color
    material.emission_energy_multiplier = 12.0 * amount * amount
