class_name ShipThrusterVisualController
extends Node

const VISIBILITY_THRESHOLD := 0.001
const DIRECT_RISE_SECONDS := 0.22
const DIRECT_FALL_SECONDS := 0.22
const ASSIST_RISE_SECONDS := 0.16
const ASSIST_FALL_SECONDS := 0.16
const PIVOT_TOLERANCE_METERS := 0.001
const ACTION_MATRIX_PATH := "res://config/ships/small_sci_fi_fighter_thruster_actions.json"
const MANIFEST_PATH := "res://assets/runtime/ships/player/small_sci_fi_fighter.manifest.json"
const SOCKET_SPECS := [
    {"socket": "Main/MainLeft", "effect": "MainEffects/MainLeftEffect", "class": &"main"},
    {"socket": "Main/MainRight", "effect": "MainEffects/MainRightEffect", "class": &"main"},
    {"socket": "Retro/RetroLeft", "effect": "RetroEffects/RetroLeftEffect", "class": &"retro"},
    {"socket": "Retro/RetroRight", "effect": "RetroEffects/RetroRightEffect", "class": &"retro"},
    {"socket": "Maneuver/FrontUpperLeft", "effect": "ManeuverEffects/FrontUpperLeftEffect", "class": &"maneuver"},
    {"socket": "Maneuver/FrontUpperRight", "effect": "ManeuverEffects/FrontUpperRightEffect", "class": &"maneuver"},
    {"socket": "Maneuver/RearUpperLeft", "effect": "ManeuverEffects/RearUpperLeftEffect", "class": &"maneuver"},
    {"socket": "Maneuver/RearUpperRight", "effect": "ManeuverEffects/RearUpperRightEffect", "class": &"maneuver"},
    {"socket": "Maneuver/RearLowerLeft", "effect": "ManeuverEffects/RearLowerLeftEffect", "class": &"maneuver"},
    {"socket": "Maneuver/RearLowerRight", "effect": "ManeuverEffects/RearLowerRightEffect", "class": &"maneuver"},
    {"socket": "Maneuver/FrontLowerLeft", "effect": "ManeuverEffects/FrontLowerLeftEffect", "class": &"maneuver"},
    {"socket": "Maneuver/FrontLowerRight", "effect": "ManeuverEffects/FrontLowerRightEffect", "class": &"maneuver"},
]

@export var controller_path: NodePath
@export var model_path: NodePath

var _controller: ShipFlightController
var _model: Node3D
var _action_matrix: ThrusterActionMatrix
var _socket_nodes: Array[Node3D] = []
var _effect_pivots: Array[Node3D] = []
var _effect_meshes: Array[MeshInstance3D] = []
var _effect_materials: Array[StandardMaterial3D] = []
var _socket_paths: Array[StringName] = []
var _effect_paths: Array[StringName] = []
var _socket_classes: Array[StringName] = []
var _socket_data: Array[Dictionary] = []
var _effect_initial_transforms: Array[Transform3D] = []
var _effect_pivot_initial_transforms: Array[Transform3D] = []
var _effect_local_exhaust_axes: Array[Vector3] = []
var _envelopes := PackedFloat32Array()
var _envelope_direct_modes: Array[bool] = []
var _direct_targets: Dictionary = {}
var _assist_targets: Dictionary = {}
var _merged_targets: Dictionary = {}
var _test_override_enabled := false
var _test_command := FlightCommand.new()
var _test_assist_force := Vector3.ZERO
var _test_assist_torque := Vector3.ZERO
var _test_boost := 0.0
var _initialized := false
var _contract_valid := false

func _ready() -> void:
    initialize()

func _process(delta: float) -> void:
    step_visuals(delta)

func initialize() -> void:
    if _initialized:
        return
    _initialized = true

    _controller = get_node_or_null(controller_path) as ShipFlightController
    _model = get_node_or_null(model_path) as Node3D
    if _controller == null:
        _disable_with_error(
            "ShipThrusterVisualController could not resolve controller at %s"
            % controller_path
        )
        return
    if _model == null:
        _disable_with_error(
            "ShipThrusterVisualController could not resolve model at %s"
            % model_path
        )
        return

    _action_matrix = ThrusterActionMatrix.load_checked_in(ACTION_MATRIX_PATH)
    if _action_matrix == null or not _action_matrix.is_valid():
        _disable_with_error(
            "Canonical fighter checked-in thruster action matrix is invalid"
        )
        return

    var effect_contracts := _load_effect_contracts()
    if effect_contracts.is_empty():
        _disable_with_error("Canonical fighter schema-4 effect contract is invalid")
        return

    var body := get_parent() as Node3D
    if body == null:
        _disable_with_error(
            "ShipThrusterVisualController requires a Node3D parent"
        )
        return

    var thruster_root := find_unique_logical_root(_model, &"Thrusters")
    var effect_root := find_unique_logical_root(_model, &"ThrusterEffects")
    if thruster_root == null:
        _disable_with_error(
            "Canonical fighter must contain exactly one Thrusters hierarchy"
        )
        return
    if effect_root == null:
        _disable_with_error(
            "Canonical fighter must contain exactly one ThrusterEffects hierarchy"
        )
        return

    for specification: Dictionary in SOCKET_SPECS:
        var relative_socket_path := String(specification["socket"])
        var relative_effect_path := String(specification["effect"])
        var full_socket_path := StringName("Thrusters/%s" % relative_socket_path)
        var full_effect_path := StringName(
            "ThrusterEffects/%s" % relative_effect_path
        )
        var thruster_class := StringName(specification["class"])

        var socket := thruster_root.get_node_or_null(
            relative_socket_path
        ) as Node3D
        var effect_pivot := effect_root.get_node_or_null(
            relative_effect_path
        ) as Node3D
        if socket == null:
            _disable_with_error(
                "Canonical fighter thruster socket missing: %s"
                % full_socket_path
            )
            return
        if effect_pivot == null:
            _disable_with_error(
                "Nozzle-local thruster pivot missing: %s"
                % full_effect_path
            )
            return

        var effect_mesh_name := "%sMesh" % effect_pivot.name
        var effect := effect_pivot.get_node_or_null(
            effect_mesh_name
        ) as MeshInstance3D
        if effect == null or effect.mesh == null:
            _disable_with_error(
                "Source-exact thruster mesh child missing: %s/%s"
                % [full_effect_path, effect_mesh_name]
            )
            return
        if (
            not effect_pivot.transform.origin.is_finite()
            or not effect_pivot.transform.basis.is_finite()
            or absf(effect_pivot.transform.basis.determinant()) <= 0.000001
        ):
            _disable_with_error(
                "Nozzle-local thruster pivot transform is invalid: %s"
                % full_effect_path
            )
            return
        if (
            not effect.transform.origin.is_finite()
            or not effect.transform.basis.is_finite()
            or effect.transform.origin.length() > PIVOT_TOLERANCE_METERS
            or absf(effect.transform.basis.determinant()) <= 0.000001
        ):
            _disable_with_error(
                "Nozzle-local thruster mesh child must begin at pivot identity: %s/%s"
                % [full_effect_path, effect_mesh_name]
            )
            return

        var contract: Dictionary = effect_contracts.get(full_effect_path, {})
        if contract.is_empty():
            _disable_with_error(
                "Schema-4 effect record missing: %s" % full_effect_path
            )
            return
        if StringName(contract.get("socket_path", "")) != full_socket_path:
            _disable_with_error(
                "Schema-4 socket/effect pair mismatch: %s" % full_effect_path
            )
            return
        if StringName(contract.get("class", "")) != thruster_class:
            _disable_with_error(
                "Schema-4 effect class mismatch: %s" % full_effect_path
            )
            return

        var local_axis := _vector3_from_json(
            contract.get("local_exhaust_axis", null)
        )
        if (
            not local_axis.is_finite()
            or local_axis.length_squared() <= 0.99
        ):
            _disable_with_error(
                "Schema-4 local exhaust axis is invalid: %s"
                % full_effect_path
            )
            return
        local_axis = local_axis.normalized()

        var socket_transform := _local_transform_to_ancestor(socket, body)
        var pivot_transform := _local_transform_to_ancestor(effect_pivot, body)
        if (
            socket_transform.origin.distance_to(pivot_transform.origin)
            > PIVOT_TOLERANCE_METERS
        ):
            _disable_with_error(
                "Nozzle-local effect pivot does not match socket: %s"
                % full_effect_path
            )
            return

        var reaction_direction := socket_transform.basis.z.normalized()
        if (
            not reaction_direction.is_finite()
            or reaction_direction.length_squared() < 0.99
        ):
            _disable_with_error(
                "Canonical fighter thruster socket has invalid reaction axis: %s"
                % full_socket_path
            )
            return

        var material := _create_effect_material(thruster_class)
        effect.material_override = material
        effect.visible = false

        _socket_nodes.append(socket)
        _effect_pivots.append(effect_pivot)
        _effect_meshes.append(effect)
        _effect_materials.append(material)
        _effect_initial_transforms.append(effect.transform)
        _effect_pivot_initial_transforms.append(effect_pivot.transform)
        _effect_local_exhaust_axes.append(local_axis)
        _socket_paths.append(StringName(relative_socket_path))
        _effect_paths.append(full_effect_path)
        _socket_classes.append(thruster_class)
        _socket_data.append({
            "position": socket_transform.origin,
            "reaction_direction": reaction_direction,
            "capacity": _capacity_for_class(thruster_class),
        })
        _envelope_direct_modes.append(true)

    _envelopes.resize(SOCKET_SPECS.size())
    _envelopes.fill(0.0)
    _contract_valid = (
        _socket_nodes.size() == SOCKET_SPECS.size()
        and _effect_pivots.size() == SOCKET_SPECS.size()
        and _effect_meshes.size() == SOCKET_SPECS.size()
        and _effect_materials.size() == SOCKET_SPECS.size()
        and _socket_paths.size() == SOCKET_SPECS.size()
        and _effect_paths.size() == SOCKET_SPECS.size()
        and _effect_local_exhaust_axes.size() == SOCKET_SPECS.size()
        and _socket_data.size() == SOCKET_SPECS.size()
        and are_effect_pivots_unchanged()
    )
    if not _contract_valid:
        _disable_with_error(
            "Source-exact thruster contract did not resolve twelve socket/effect pairs"
        )

func step_visuals(delta: float) -> void:
    if not _contract_valid or _action_matrix == null:
        return

    var command := (
        _test_command.duplicate_command()
        if _test_override_enabled
        else _controller.get_last_command()
    )
    var assist_force := (
        _test_assist_force
        if _test_override_enabled
        else _controller.get_last_assist_force_local()
    )
    var assist_torque := (
        _test_assist_torque
        if _test_override_enabled
        else _controller.get_last_assist_torque_local()
    )
    var direct := _action_matrix.intensities_for(command)
    var assisted := _assisted_intensities(assist_force, assist_torque)
    var boost := (
        _test_boost
        if _test_override_enabled
        else _controller.get_boost_amount()
    )

    _direct_targets.clear()
    _assist_targets.clear()
    _merged_targets.clear()

    for index: int in range(_effect_meshes.size()):
        var socket_path := _socket_paths[index]
        var direct_amount := clampf(
            float(direct.get(socket_path, 0.0)),
            0.0,
            1.0
        )
        var assist_amount := clampf(
            float(assisted.get(socket_path, 0.0)),
            0.0,
            1.0
        )
        var merged := ThrusterVisualMath.merge_target(
            direct_amount,
            assist_amount
        )

        _direct_targets[socket_path] = direct_amount
        _assist_targets[socket_path] = assist_amount
        _merged_targets[socket_path] = merged

        if direct_amount > VISIBILITY_THRESHOLD:
            _envelope_direct_modes[index] = true
        elif assist_amount > VISIBILITY_THRESHOLD:
            _envelope_direct_modes[index] = false

        var direct_mode := _envelope_direct_modes[index]
        var rise_seconds := (
            DIRECT_RISE_SECONDS if direct_mode else ASSIST_RISE_SECONDS
        )
        var fall_seconds := (
            DIRECT_FALL_SECONDS if direct_mode else ASSIST_FALL_SECONDS
        )
        _envelopes[index] = ThrusterVisualMath.advance(
            _envelopes[index],
            merged,
            delta,
            rise_seconds,
            fall_seconds
        )

        var thruster_class := _socket_classes[index]
        var class_boost := (
            boost
            if (
                direct_amount > VISIBILITY_THRESHOLD
                and (thruster_class == &"main" or thruster_class == &"retro")
            )
            else 0.0
        )
        _apply_effect_output(
            index,
            _envelopes[index],
            class_boost,
            thruster_class
        )

func set_test_command(command: FlightCommand) -> void:
    _test_override_enabled = true
    _test_command = command.duplicate_command()

func set_test_assist_wrench(force: Vector3, torque: Vector3) -> void:
    _test_override_enabled = true
    _test_assist_force = force
    _test_assist_torque = torque

func set_test_boost(value: float) -> void:
    _test_override_enabled = true
    _test_boost = clampf(value, 0.0, 1.0)

func clear_test_overrides() -> void:
    _test_override_enabled = false
    _test_command = FlightCommand.new()
    _test_assist_force = Vector3.ZERO
    _test_assist_torque = Vector3.ZERO
    _test_boost = 0.0

func clear_test_inputs() -> void:
    clear_test_overrides()

func preview_direct_intensities(command: FlightCommand) -> Dictionary:
    if _action_matrix == null or not _action_matrix.is_valid():
        return {}
    return _action_matrix.intensities_for(command)

func direct_intensities_for_command(command: FlightCommand) -> Dictionary:
    return preview_direct_intensities(command)

func get_active_effect_paths() -> PackedStringArray:
    var result := PackedStringArray()
    for index: int in range(_effect_meshes.size()):
        if _effect_meshes[index].visible:
            result.append(String(_effect_paths[index]))
    result.sort()
    return result

func get_direct_target(path: StringName) -> float:
    var socket_path := _socket_path_for_query(path)
    return float(_direct_targets.get(socket_path, 0.0))

func get_assist_target(path: StringName) -> float:
    var socket_path := _socket_path_for_query(path)
    return float(_assist_targets.get(socket_path, 0.0))

func get_merged_target(path: StringName) -> float:
    var socket_path := _socket_path_for_query(path)
    return float(_merged_targets.get(socket_path, 0.0))

func get_envelope(path: StringName) -> float:
    var socket_path := _socket_path_for_query(path)
    var index := _socket_paths.find(socket_path)
    return _envelopes[index] if index >= 0 else 0.0

func get_thruster_report() -> Array[Dictionary]:
    var report: Array[Dictionary] = []
    for index: int in range(_effect_paths.size()):
        var socket_path := _socket_paths[index]
        var merged := get_merged_target(socket_path)
        var socket: Dictionary = _socket_data[index]
        var force: Vector3 = (
            socket["reaction_direction"]
            * float(socket["capacity"])
            * merged
        )
        var position: Vector3 = socket["position"]
        report.append({
            "path": String(_effect_paths[index]),
            "socket_path": String(socket_path),
            "force": force,
            "torque": position.cross(force),
            "direct": get_direct_target(socket_path),
            "assist": get_assist_target(socket_path),
            "merged": merged,
            "envelope": _envelopes[index],
        })
    report.sort_custom(
        func(left: Dictionary, right: Dictionary) -> bool:
            return String(left["path"]) < String(right["path"])
    )
    return report

func get_socket_count() -> int:
    return _socket_nodes.size()

func get_effect_count() -> int:
    return _effect_meshes.size()

func are_all_effects_hidden() -> bool:
    for effect: MeshInstance3D in _effect_meshes:
        if effect.visible:
            return false
    return true

func are_effect_pivots_unchanged() -> bool:
    if _effect_pivots.size() != _effect_pivot_initial_transforms.size():
        return false
    for index: int in range(_effect_pivots.size()):
        if not _effect_pivots[index].transform.is_equal_approx(
            _effect_pivot_initial_transforms[index]
        ):
            return false
    return true

func are_effect_origins_anchored() -> bool:
    return are_effect_pivots_unchanged()

func are_effect_transforms_unchanged() -> bool:
    if _effect_meshes.size() != _effect_initial_transforms.size():
        return false
    for index: int in range(_effect_meshes.size()):
        if not _effect_meshes[index].transform.is_equal_approx(
            _effect_initial_transforms[index]
        ):
            return false
    return true

func is_contract_valid() -> bool:
    return _contract_valid

static func find_unique_logical_root(
    root: Node,
    logical_name: StringName
) -> Node3D:
    var matches: Array[Node3D] = []
    _collect_named_node3d(root, logical_name, matches)
    return matches[0] if matches.size() == 1 else null

static func _collect_named_node3d(
    node: Node,
    logical_name: StringName,
    matches: Array[Node3D]
) -> void:
    var node_3d := node as Node3D
    if node_3d != null and node_3d.name == logical_name:
        matches.append(node_3d)
    for child: Node in node.get_children():
        _collect_named_node3d(child, logical_name, matches)

func _socket_path_for_query(path: StringName) -> StringName:
    if _socket_paths.has(path):
        return path
    var effect_index := _effect_paths.find(path)
    if effect_index >= 0:
        return _socket_paths[effect_index]
    return &""

func _assisted_intensities(
    assist_force: Vector3,
    assist_torque: Vector3
) -> Dictionary:
    var command := FlightCommand.new()
    var force_reference := maxf(_controller.get_force_reference(), 0.001)
    var torque_reference := maxf(_controller.get_torque_reference(), 0.001)
    command.translation = Vector3(
        clampf(assist_force.x / force_reference, -1.0, 1.0),
        clampf(assist_force.y / force_reference, -1.0, 1.0),
        clampf(assist_force.z / force_reference, -1.0, 1.0)
    )
    command.rotation = Vector3(
        clampf(assist_torque.x / torque_reference, -1.0, 1.0),
        clampf(assist_torque.y / torque_reference, -1.0, 1.0),
        clampf(assist_torque.z / torque_reference, -1.0, 1.0)
    )
    return _action_matrix.intensities_for(command)

func _apply_effect_output(
    index: int,
    envelope: float,
    boost: float,
    thruster_class: StringName
) -> void:
    var amount := clampf(envelope, 0.0, 1.0)
    var effect := _effect_meshes[index]
    var material := _effect_materials[index]
    var initial := _effect_initial_transforms[index]

    effect.visible = amount > VISIBILITY_THRESHOLD
    if not effect.visible:
        effect.transform = initial
        material.albedo_color.a = 0.0
        material.emission_energy_multiplier = 0.0
        return

    var scale := ThrusterVisualMath.scale_for(
        amount,
        _effect_local_exhaust_axes[index]
    )
    effect.transform = Transform3D(
        initial.basis * Basis.from_scale(scale),
        initial.origin
    )

    var class_color := _class_color(thruster_class)
    var opacity := ThrusterVisualMath.opacity_for(amount)
    var emission := ThrusterVisualMath.emission_for(amount)
    var boost_multiplier := (
        lerpf(1.0, 1.8, clampf(boost, 0.0, 1.0))
        if thruster_class == &"main" or thruster_class == &"retro"
        else 1.0
    )
    material.albedo_color = Color(
        class_color.r,
        class_color.g,
        class_color.b,
        opacity
    )
    material.emission = class_color
    material.emission_energy_multiplier = 11.0 * emission * boost_multiplier

func _load_effect_contracts() -> Dictionary:
    var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return {}
    var manifest: Dictionary = parsed
    if int(manifest.get("schema_version", 0)) != 4:
        return {}
    if (
        String(manifest.get("thruster_visual_strategy", ""))
        != "source_exact_nozzle_local_enginefire_geometry"
    ):
        return {}
    var effects_variant: Variant = manifest.get("thruster_effects", [])
    if not effects_variant is Array:
        return {}
    var effects: Array = effects_variant
    if effects.size() != SOCKET_SPECS.size():
        return {}

    var result: Dictionary = {}
    for record_variant: Variant in effects:
        if not record_variant is Dictionary:
            return {}
        var record: Dictionary = record_variant
        var path := StringName(String(record.get("path", "")))
        if path == &"" or result.has(path):
            return {}
        result[path] = record
    return result

func _vector3_from_json(value: Variant) -> Vector3:
    if not value is Array:
        return Vector3.ZERO
    var components: Array = value
    if components.size() != 3:
        return Vector3.ZERO
    return Vector3(
        float(components[0]),
        float(components[1]),
        float(components[2])
    )

func _create_effect_material(
    thruster_class: StringName
) -> StandardMaterial3D:
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

func _capacity_for_class(thruster_class: StringName) -> float:
    match thruster_class:
        &"main":
            return 0.55
        &"retro":
            return 0.35
        _:
            return 0.22

func _class_color(thruster_class: StringName) -> Color:
    match thruster_class:
        &"retro":
            return Color(0.35, 0.78, 1.0, 1.0)
        &"maneuver":
            return Color(0.48, 0.72, 1.0, 1.0)
        _:
            return Color(0.20, 0.88, 1.0, 1.0)

func _local_transform_to_ancestor(
    node: Node3D,
    ancestor: Node3D
) -> Transform3D:
    var chain: Array[Node3D] = []
    var current: Node = node
    while current != ancestor:
        var current_3d := current as Node3D
        if current_3d == null:
            return Transform3D.IDENTITY
        chain.push_front(current_3d)
        current = current.get_parent()
        if current == null:
            return Transform3D.IDENTITY

    var result := Transform3D.IDENTITY
    for item: Node3D in chain:
        result *= item.transform
    return result

func _disable_with_error(message: String) -> void:
    push_error(message)
    _contract_valid = false
    for effect: MeshInstance3D in _effect_meshes:
        effect.visible = false
    set_process(false)
