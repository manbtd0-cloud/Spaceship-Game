class_name ShipThrusterVisualController
extends Node

const SOCKET_SPECS := [
    {"path": "Main/MainLeft", "class": &"main"},
    {"path": "Main/MainRight", "class": &"main"},
    {"path": "Retro/RetroLeft", "class": &"retro"},
    {"path": "Retro/RetroRight", "class": &"retro"},
    {"path": "Maneuver/FrontUpperLeft", "class": &"maneuver"},
    {"path": "Maneuver/FrontUpperRight", "class": &"maneuver"},
    {"path": "Maneuver/RearUpperLeft", "class": &"maneuver"},
    {"path": "Maneuver/RearUpperRight", "class": &"maneuver"},
    {"path": "Maneuver/RearLowerLeft", "class": &"maneuver"},
    {"path": "Maneuver/RearLowerRight", "class": &"maneuver"},
    {"path": "Maneuver/FrontLowerLeft", "class": &"maneuver"},
    {"path": "Maneuver/FrontLowerRight", "class": &"maneuver"},
]

@export var controller_path: NodePath
@export var model_path: NodePath

var _controller: ShipFlightController
var _model: Node3D
var _socket_nodes: Array[Node3D] = []
var _socket_effects: Array[ThrusterExhaustEffect] = []
var _socket_data: Array[Dictionary] = []
var _socket_classes: Array[StringName] = []
var _initialized := false
var _contract_valid := false

func _ready() -> void:
    initialize()

func _process(_delta: float) -> void:
    if not _contract_valid or _controller == null:
        return

    var intensities := ShipThrusterAllocator.solve(
        _socket_data,
        _controller.get_last_force_local(),
        _controller.get_last_torque_local(),
        _controller.get_force_reference(),
        _controller.get_torque_reference()
    )
    var boost := _controller.get_boost_amount()
    for index: int in range(_socket_effects.size()):
        var thruster_class: StringName = _socket_classes[index]
        var class_boost := (
            boost
            if thruster_class == &"main" or thruster_class == &"retro"
            else 0.0
        )
        _socket_effects[index].set_output(
            intensities[index],
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

    var body := get_parent() as Node3D
    if body == null:
        _disable_with_error(
            "ShipThrusterVisualController requires a Node3D parent"
        )
        return

    var thruster_candidates := _model.find_children(
        "Thrusters",
        "Node3D",
        true,
        false
    )
    if thruster_candidates.size() != 1:
        _disable_with_error(
            "Canonical fighter must contain exactly one Thrusters hierarchy; found %d"
            % thruster_candidates.size()
        )
        return
    var thruster_root := thruster_candidates[0] as Node3D
    if thruster_root == null:
        _disable_with_error("Canonical fighter Thrusters hierarchy is not Node3D")
        return

    for specification: Dictionary in SOCKET_SPECS:
        var socket_path := String(specification["path"])
        var socket := thruster_root.get_node_or_null(socket_path) as Node3D
        if socket == null:
            _disable_with_error(
                "Canonical fighter thruster socket missing: Thrusters/%s"
                % socket_path
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
        var effect := ThrusterExhaustEffect.new()
        effect.name = "ExhaustEffect"
        effect.visible = false
        effect.set_output(0.0, 0.0, thruster_class)
        socket.add_child(effect)

        _socket_nodes.append(socket)
        _socket_effects.append(effect)
        _socket_classes.append(thruster_class)
        _socket_data.append({
            "position": local_transform.origin,
            "reaction_direction": reaction_direction,
            "capacity": _capacity_for_class(thruster_class),
            "class": thruster_class,
        })

    _contract_valid = (
        _socket_nodes.size() == SOCKET_SPECS.size()
        and _socket_effects.size() == SOCKET_SPECS.size()
        and _socket_data.size() == SOCKET_SPECS.size()
    )
    if not _contract_valid:
        _disable_with_error(
            "Canonical fighter thruster contract did not resolve twelve sockets"
        )

func get_socket_count() -> int:
    return _socket_nodes.size()

func get_effect_count() -> int:
    return _socket_effects.size()

func are_all_effects_hidden() -> bool:
    for effect: ThrusterExhaustEffect in _socket_effects:
        if effect.visible:
            return false
    return true

func is_contract_valid() -> bool:
    return _contract_valid

func _capacity_for_class(thruster_class: StringName) -> float:
    match thruster_class:
        &"main":
            return 0.55
        &"retro":
            return 0.35
        _:
            return 0.22

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
    for effect: ThrusterExhaustEffect in _socket_effects:
        effect.visible = false
        effect.set_output(0.0, 0.0, &"maneuver")
    set_process(false)
