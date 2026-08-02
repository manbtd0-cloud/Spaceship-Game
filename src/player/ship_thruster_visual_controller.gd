class_name ShipThrusterVisualController
extends Node

const VISIBILITY_THRESHOLD := 0.001
const ASSIST_VISUAL_CAP := 0.35
const ACTION_MATRIX_PATH := "res://config/ships/small_sci_fi_fighter_thruster_actions.json"
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
var _effect_meshes: Array[MeshInstance3D] = []
var _effect_materials: Array[StandardMaterial3D] = []
var _socket_paths: Array[StringName] = []
var _socket_classes: Array[StringName] = []
var _effect_initial_transforms: Array[Transform3D] = []
var _initialized := false
var _contract_valid := false

func _ready() -> void:
    initialize()

func _process(_delta: float) -> void:
    if not _contract_valid or _controller == null or _action_matrix == null:
        return

    var direct := preview_direct_intensities(_controller.get_last_command())
    var assisted := _assisted_intensities()
    var boost := _controller.get_boost_amount()

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
        ) * ASSIST_VISUAL_CAP
        var final_amount := maxf(direct_amount, assist_amount)
        var thruster_class: StringName = _socket_classes[index]
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
            final_amount,
            class_boost,
            thruster_class
        )

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

    var body := get_parent() as Node3D
    if body == null:
        _disable_with_error(
            "ShipThrusterVisualController requires a Node3D parent"
        )
        return

    var thruster_root := find_unique_logical_root(_model, &"Thrusters")
    if thruster_root == null:
        _disable_with_error(
            "Canonical fighter must contain exactly one Thrusters hierarchy"
        )
        return
    var effect_root := find_unique_logical_root(_model, &"ThrusterEffects")
    if effect_root == null:
        _disable_with_error(
            "Canonical fighter must contain exactly one ThrusterEffects hierarchy"
        )
        return

    for specification: Dictionary in SOCKET_SPECS:
        var socket_path := String(specification["socket"])
        var effect_path := String(specification["effect"])
        var socket := thruster_root.get_node_or_null(socket_path) as Node3D
        if socket == null:
            _disable_with_error(
                "Canonical fighter thruster socket missing: Thrusters/%s"
                % socket_path
            )
            return
        var effect := effect_root.get_node_or_null(effect_path) as MeshInstance3D
        if effect == null or effect.mesh == null:
            _disable_with_error(
                "Source-exact thruster effect missing: ThrusterEffects/%s"
                % effect_path
            )
            return
        if not _transform_is_identity(effect.transform):
            _disable_with_error(
                "Source-exact thruster effect transform is not identity: ThrusterEffects/%s"
                % effect_path
            )
            return

        var local_transform := _local_transform_to_ancestor(socket, body)
        var reaction_direction := local_transform.basis.z.normalized()
        if not reaction_direction.is_finite() or reaction_direction.length_squared() < 0.99:
            _disable_with_error(
                "Canonical fighter thruster socket has invalid reaction axis: Thrusters/%s"
                % socket_path
            )
            return

        var thruster_class := StringName(specification["class"])
        var material := _create_effect_material(thruster_class)
        effect.material_override = material
        effect.visible = false

        _socket_nodes.append(socket)
        _effect_meshes.append(effect)
        _effect_materials.append(material)
        _effect_initial_transforms.append(effect.transform)
        _socket_paths.append(StringName(socket_path))
        _socket_classes.append(thruster_class)

    _contract_valid = (
        _socket_nodes.size() == SOCKET_SPECS.size()
        and _effect_meshes.size() == SOCKET_SPECS.size()
        and _effect_materials.size() == SOCKET_SPECS.size()
        and _socket_paths.size() == SOCKET_SPECS.size()
        and are_effect_transforms_unchanged()
    )
    if not _contract_valid:
        _disable_with_error(
            "Source-exact thruster contract did not resolve twelve socket/effect pairs"
        )

func preview_direct_intensities(command: FlightCommand) -> Dictionary:
    if _action_matrix == null or not _action_matrix.is_valid():
        return {}
    return _action_matrix.intensities_for(command)

func direct_intensities_for_command(command: FlightCommand) -> Dictionary:
    return preview_direct_intensities(command)

func get_socket_count() -> int:
    return _socket_nodes.size()

func get_effect_count() -> int:
    return _effect_meshes.size()

func are_all_effects_hidden() -> bool:
    for effect: MeshInstance3D in _effect_meshes:
        if effect.visible:
            return false
    return true

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

func _assisted_intensities() -> Dictionary:
    var command := FlightCommand.new()
    var force_reference := maxf(_controller.get_force_reference(), 0.001)
    var torque_reference := maxf(_controller.get_torque_reference(), 0.001)
    var assist_force := _controller.get_last_assist_force_local()
    var assist_torque := _controller.get_last_assist_torque_local()
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
    intensity: float,
    boost: float,
    thruster_class: StringName
) -> void:
    var amount := clampf(intensity, 0.0, 1.0)
    var effect := _effect_meshes[index]
    var material := _effect_materials[index]
    effect.visible = amount > VISIBILITY_THRESHOLD
    if not effect.visible:
        material.albedo_color.a = 0.0
        material.emission_energy_multiplier = 0.0
        return

    var class_color := _class_color(thruster_class)
    var boost_multiplier := (
        lerpf(1.0, 1.8, clampf(boost, 0.0, 1.0))
        if thruster_class == &"main" or thruster_class == &"retro"
        else 1.0
    )
    material.albedo_color = Color(
        class_color.r,
        class_color.g,
        class_color.b,
        lerpf(0.18, 0.92, sqrt(amount))
    )
    material.emission = class_color
    material.emission_energy_multiplier = lerpf(2.0, 11.0, amount) * boost_multiplier

func _create_effect_material(thruster_class: StringName) -> StandardMaterial3D:
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
            return Color(0.35, 0.78, 1.0, 1.0)
        &"maneuver":
            return Color(0.48, 0.72, 1.0, 1.0)
        _:
            return Color(0.20, 0.88, 1.0, 1.0)

func _transform_is_identity(value: Transform3D) -> bool:
    return (
        value.origin.is_equal_approx(Vector3.ZERO)
        and value.basis.x.is_equal_approx(Vector3.RIGHT)
        and value.basis.y.is_equal_approx(Vector3.UP)
        and value.basis.z.is_equal_approx(Vector3.BACK)
    )

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
