class_name ThrusterExhaustEffect
extends Node3D

const VISIBILITY_THRESHOLD := 0.001
const ATTACK_SPEED := 22.0
const RELEASE_SPEED := 14.0

var _target_intensity := 0.0
var _current_intensity := 0.0
var _boost := 0.0
var _thruster_class: StringName = &"maneuver"
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _core_material: StandardMaterial3D
var _halo_material: StandardMaterial3D

func _ready() -> void:
    _build_visuals()
    visible = false
    set_process(true)

func _process(delta: float) -> void:
    var response_speed := (
        ATTACK_SPEED
        if _target_intensity > _current_intensity
        else RELEASE_SPEED
    )
    var blend := 1.0 - exp(-response_speed * maxf(delta, 0.0))
    _current_intensity = lerpf(
        _current_intensity,
        _target_intensity,
        clampf(blend, 0.0, 1.0)
    )
    if absf(_current_intensity - _target_intensity) < 0.0001:
        _current_intensity = _target_intensity
    _apply_visuals()

func set_output(
    intensity: float,
    boost: float,
    thruster_class: StringName
) -> void:
    _target_intensity = clampf(intensity, 0.0, 1.0)
    _boost = clampf(boost, 0.0, 1.0)
    _thruster_class = thruster_class

static func should_be_visible(intensity: float) -> bool:
    return clampf(intensity, 0.0, 1.0) > VISIBILITY_THRESHOLD

static func output_length(
    intensity: float,
    boost: float,
    thruster_class: StringName
) -> float:
    var amount := clampf(intensity, 0.0, 1.0)
    if amount <= VISIBILITY_THRESHOLD:
        return 0.0
    var length_range := _length_range(thruster_class)
    var result := lerpf(length_range.x, length_range.y, amount)
    if thruster_class == &"main":
        result *= lerpf(1.0, 1.65, clampf(boost, 0.0, 1.0))
    elif thruster_class == &"retro":
        result *= lerpf(1.0, 1.25, clampf(boost, 0.0, 1.0))
    return result

static func output_radius(intensity: float, thruster_class: StringName) -> float:
    var amount := clampf(intensity, 0.0, 1.0)
    if amount <= VISIBILITY_THRESHOLD:
        return 0.0
    var radius_range := _radius_range(thruster_class)
    return lerpf(radius_range.x, radius_range.y, sqrt(amount))

static func _length_range(thruster_class: StringName) -> Vector2:
    match thruster_class:
        &"main":
            return Vector2(0.38, 2.55)
        &"retro":
            return Vector2(0.24, 1.45)
        _:
            return Vector2(0.12, 0.72)

static func _radius_range(thruster_class: StringName) -> Vector2:
    match thruster_class:
        &"main":
            return Vector2(0.10, 0.34)
        &"retro":
            return Vector2(0.07, 0.22)
        _:
            return Vector2(0.035, 0.12)

func _build_visuals() -> void:
    _core_material = _make_material(Color(0.32, 0.86, 1.0, 0.96), 8.0)
    _halo_material = _make_material(Color(0.08, 0.42, 1.0, 0.36), 3.5)

    _core = MeshInstance3D.new()
    _core.name = "Core"
    _core.mesh = _make_plume_mesh(0.36, 0.08)
    _core.rotation.x = PI * 0.5
    add_child(_core)

    _halo = MeshInstance3D.new()
    _halo.name = "Halo"
    _halo.mesh = _make_plume_mesh(0.48, 0.12)
    _halo.rotation.x = PI * 0.5
    add_child(_halo)

    var core_mesh := _core.mesh as CylinderMesh
    var halo_mesh := _halo.mesh as CylinderMesh
    core_mesh.material = _core_material
    halo_mesh.material = _halo_material

func _make_plume_mesh(base_radius: float, tip_radius: float) -> CylinderMesh:
    var mesh := CylinderMesh.new()
    mesh.top_radius = tip_radius
    mesh.bottom_radius = base_radius
    mesh.height = 1.0
    mesh.radial_segments = 16
    mesh.rings = 1
    return mesh

func _make_material(color: Color, emission_energy: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = Color(color.r, color.g, color.b, 1.0)
    material.emission_energy_multiplier = emission_energy
    return material

func _apply_visuals() -> void:
    var exhaust_visible := should_be_visible(_current_intensity)
    visible = exhaust_visible
    if not exhaust_visible or _core == null or _halo == null:
        return

    var length := output_length(_current_intensity, _boost, _thruster_class)
    var radius := output_radius(_current_intensity, _thruster_class)
    var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.024) * 0.035 * _current_intensity

    _core.scale = Vector3(radius * pulse, length, radius * pulse)
    _core.position = Vector3(0.0, 0.0, -length * 0.5)

    _halo.scale = Vector3(radius * 1.55, length * 0.92, radius * 1.55)
    _halo.position = Vector3(0.0, 0.0, -length * 0.46)

    var class_color := _class_color(_thruster_class)
    _core_material.albedo_color = Color(
        class_color.r,
        class_color.g,
        class_color.b,
        0.96
    )
    _core_material.emission = class_color
    _core_material.emission_energy_multiplier = lerpf(
        4.0,
        11.0 + _boost * 5.0,
        _current_intensity
    )
    _halo_material.emission_energy_multiplier = lerpf(
        1.5,
        4.5 + _boost * 2.0,
        _current_intensity
    )

func _class_color(thruster_class: StringName) -> Color:
    match thruster_class:
        &"retro":
            return Color(0.35, 0.78, 1.0, 1.0)
        &"maneuver":
            return Color(0.48, 0.72, 1.0, 1.0)
        _:
            return Color(0.20, 0.88, 1.0, 1.0)
