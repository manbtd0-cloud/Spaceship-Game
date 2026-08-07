class_name EnemyThrusterVisualController
extends Node

const VISIBILITY_THRESHOLD := 0.001
const RISE_SECONDS := 0.10
const FALL_SECONDS := 0.16
const ACTION_MATRIX_PATH := "res://config/ships/small_sci_fi_fighter_thruster_actions.json"
const MANIFEST_PATH := "res://assets/runtime/ships/player/small_sci_fi_fighter.manifest.json"

@export var controller_path: NodePath = NodePath("../EnemyFighterController")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var model_path: NodePath = NodePath("../VisualRoot/SmallSciFiFighter")
@export var tuning: EnemyFighterTuning

var _controller: EnemyFighterController
var _damage_state: DamageState
var _model: Node3D
var _body: Node3D
var _action_matrix: ThrusterActionMatrix
var _socket_paths: Array[StringName] = []
var _effect_paths: Array[StringName] = []
var _effect_pivots: Array[Node3D] = []
var _effect_meshes: Array[MeshInstance3D] = []
var _effect_materials: Array[StandardMaterial3D] = []
var _initial_mesh_transforms: Array[Transform3D] = []
var _initial_pivot_transforms: Array[Transform3D] = []
var _local_axes: Array[Vector3] = []
var _classes: Array[StringName] = []
var _envelopes := PackedFloat32Array()
var _targets: Dictionary = {}
var _contract_valid := false
var _initialized := false
var _test_override := false
var _test_force_world := Vector3.ZERO
var _test_torque_world := Vector3.ZERO

func _ready() -> void:
    initialize()

func _process(delta: float) -> void:
    step_visuals(delta)

func initialize() -> void:
    if _initialized:
        return
    _initialized = true
    _controller = get_node_or_null(controller_path) as EnemyFighterController
    _damage_state = get_node_or_null(damage_state_path) as DamageState
    _model = get_node_or_null(model_path) as Node3D
    _body = get_parent() as Node3D
    if _controller == null or _damage_state == null or _model == null or _body == null or tuning == null:
        _disable_with_error("EnemyThrusterVisualController dependencies are incomplete")
        return

    _action_matrix = ThrusterActionMatrix.load_checked_in(ACTION_MATRIX_PATH)
    if _action_matrix == null or not _action_matrix.is_valid():
        _disable_with_error("Enemy thruster presentation requires the checked-in action matrix")
        return

    var effect_root := ShipThrusterVisualController.find_unique_logical_root(
        _model,
        &"ThrusterEffects"
    )
    if effect_root == null:
        _disable_with_error("Enemy fighter requires exactly one ThrusterEffects hierarchy")
        return
    effect_root.visible = true

    var axes := _load_local_axes()
    if axes.size() != ShipThrusterVisualController.SOCKET_SPECS.size():
        _disable_with_error("Enemy thruster presentation requires schema-5 effect axes")
        return

    for specification: Dictionary in ShipThrusterVisualController.SOCKET_SPECS:
        var socket_path := StringName(String(specification["socket"]))
        var relative_effect_path := String(specification["effect"])
        var effect_path := StringName("ThrusterEffects/%s" % relative_effect_path)
        var pivot := effect_root.get_node_or_null(relative_effect_path) as Node3D
        if pivot == null:
            _disable_with_error("Enemy canonical thruster effect pivot missing: %s" % effect_path)
            return
        var mesh := pivot.get_node_or_null("%sMesh" % pivot.name) as MeshInstance3D
        if mesh == null or mesh.mesh == null:
            _disable_with_error("Enemy canonical thruster effect mesh missing: %s" % effect_path)
            return
        var axis: Vector3 = axes.get(effect_path, Vector3.ZERO)
        if not axis.is_finite() or axis.length_squared() < 0.99:
            _disable_with_error("Enemy canonical thruster axis invalid: %s" % effect_path)
            return

        var thruster_class := StringName(specification["class"])
        var material := _create_material(thruster_class)
        mesh.material_override = material
        mesh.visible = false
        _socket_paths.append(socket_path)
        _effect_paths.append(effect_path)
        _effect_pivots.append(pivot)
        _effect_meshes.append(mesh)
        _effect_materials.append(material)
        _initial_mesh_transforms.append(mesh.transform)
        _initial_pivot_transforms.append(pivot.transform)
        _local_axes.append(axis.normalized())
        _classes.append(thruster_class)

    _envelopes.resize(_effect_meshes.size())
    _envelopes.fill(0.0)
    _contract_valid = _effect_meshes.size() == 12 and are_effect_pivots_unchanged()
    if not _contract_valid:
        _disable_with_error("Enemy thruster presentation did not resolve twelve canonical effects")
        return

    if not _damage_state.destroyed.is_connected(_on_destroyed):
        _damage_state.destroyed.connect(_on_destroyed)
    if not _controller.respawned.is_connected(_on_respawned):
        _controller.respawned.connect(_on_respawned)

func step_visuals(delta: float) -> void:
    initialize()
    if not _contract_valid or _action_matrix == null:
        return

    var force_world := _test_force_world if _test_override else _controller.get_last_force_world()
    var torque_world := _test_torque_world if _test_override else _controller.get_last_torque_world()
    if _damage_state.is_destroyed() and not _test_override:
        force_world = Vector3.ZERO
        torque_world = Vector3.ZERO

    var basis := _body.global_transform.basis.orthonormalized()
    var command := EnemyThrusterPresentationMath.command_for_local_wrench(
        basis.inverse() * force_world,
        basis.inverse() * torque_world,
        tuning
    )
    var intensities := _action_matrix.intensities_for(command)
    _targets.clear()

    for index: int in range(_effect_meshes.size()):
        var path := _socket_paths[index]
        var target := clampf(float(intensities.get(path, 0.0)), 0.0, 1.0)
        _targets[path] = target
        _envelopes[index] = ThrusterVisualMath.advance(
            _envelopes[index],
            target,
            maxf(delta, 0.0),
            RISE_SECONDS,
            FALL_SECONDS
        )
        _apply_output(index, _envelopes[index])

func reset_visuals() -> void:
    _targets.clear()
    for index: int in range(_effect_meshes.size()):
        _envelopes[index] = 0.0
        _apply_output(index, 0.0)

func set_test_wrench_for_test(force_world: Vector3, torque_world: Vector3) -> void:
    _test_override = true
    _test_force_world = force_world
    _test_torque_world = torque_world

func clear_test_wrench_for_test() -> void:
    _test_override = false
    _test_force_world = Vector3.ZERO
    _test_torque_world = Vector3.ZERO

func get_active_effect_paths() -> PackedStringArray:
    var result := PackedStringArray()
    for index: int in range(_effect_meshes.size()):
        if _effect_meshes[index].visible:
            result.append(String(_effect_paths[index]))
    result.sort()
    return result

func get_effect_count() -> int:
    return _effect_meshes.size()

func get_max_target() -> float:
    var maximum := 0.0
    for value: Variant in _targets.values():
        maximum = maxf(maximum, float(value))
    return maximum

func are_all_effects_hidden() -> bool:
    for mesh: MeshInstance3D in _effect_meshes:
        if mesh.visible:
            return false
    return true

func are_effect_pivots_unchanged() -> bool:
    if _effect_pivots.size() != _initial_pivot_transforms.size():
        return false
    for index: int in range(_effect_pivots.size()):
        if not _effect_pivots[index].transform.is_equal_approx(_initial_pivot_transforms[index]):
            return false
    return true

func is_contract_valid() -> bool:
    return _contract_valid

func _apply_output(index: int, amount_value: float) -> void:
    var amount := clampf(amount_value, 0.0, 1.0)
    var mesh := _effect_meshes[index]
    var material := _effect_materials[index]
    var initial := _initial_mesh_transforms[index]
    mesh.visible = amount > VISIBILITY_THRESHOLD
    if not mesh.visible:
        mesh.transform = initial
        material.albedo_color.a = 0.0
        material.emission_energy_multiplier = 0.0
        return

    var scale := ThrusterVisualMath.scale_for(amount, _local_axes[index])
    mesh.transform = Transform3D(initial.basis * Basis.from_scale(scale), initial.origin)
    var color := _class_color(_classes[index])
    material.albedo_color = Color(color.r, color.g, color.b, ThrusterVisualMath.opacity_for(amount))
    material.emission = color
    material.emission_energy_multiplier = 14.0 * ThrusterVisualMath.emission_for(amount)

func _load_local_axes() -> Dictionary:
    var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return {}
    var manifest: Dictionary = parsed
    if String(manifest.get("thruster_visual_strategy", "")) != "source_exact_nozzle_local_enginefire_geometry":
        return {}
    var records_variant: Variant = manifest.get("thruster_effects", [])
    if not records_variant is Array:
        return {}
    var result: Dictionary = {}
    for record_variant: Variant in records_variant:
        if not record_variant is Dictionary:
            return {}
        var record: Dictionary = record_variant
        var raw_axis: Variant = record.get("local_exhaust_axis", [])
        if not raw_axis is Array or raw_axis.size() != 3:
            return {}
        var path := StringName(String(record.get("path", "")))
        result[path] = Vector3(float(raw_axis[0]), float(raw_axis[1]), float(raw_axis[2]))
    return result

func _create_material(thruster_class: StringName) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
    material.emission_enabled = true
    material.emission = _class_color(thruster_class)
    material.emission_energy_multiplier = 0.0
    return material

func _class_color(thruster_class: StringName) -> Color:
    match thruster_class:
        &"retro":
            return Color(1.0, 0.44, 0.12, 1.0)
        &"maneuver":
            return Color(1.0, 0.54, 0.16, 1.0)
        _:
            return Color(1.0, 0.26, 0.07, 1.0)

func _on_destroyed(_result: DamageResult) -> void:
    reset_visuals()

func _on_respawned() -> void:
    reset_visuals()

func _disable_with_error(message: String) -> void:
    push_error(message)
    _contract_valid = false
    reset_visuals()
    set_process(false)
