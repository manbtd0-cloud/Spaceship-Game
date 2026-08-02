class_name ShipVisualController
extends Node

@export var controller_path: NodePath
@export var left_glow_path: NodePath
@export var right_glow_path: NodePath

var _controller: ShipFlightController
var _left_glow: MeshInstance3D
var _right_glow: MeshInstance3D

func _ready() -> void:
    _controller = get_node_or_null(controller_path) as ShipFlightController
    _left_glow = get_node_or_null(left_glow_path) as MeshInstance3D
    _right_glow = get_node_or_null(right_glow_path) as MeshInstance3D

    if _controller == null:
        _disable_with_error(
            "ShipVisualController could not resolve controller at %s"
            % controller_path
        )
        return
    if _left_glow == null:
        _disable_with_error(
            "ShipVisualController could not resolve left glow at %s"
            % left_glow_path
        )
        return
    if _right_glow == null:
        _disable_with_error(
            "ShipVisualController could not resolve right glow at %s"
            % right_glow_path
        )
        return

    _refresh_glows()

func _process(_delta: float) -> void:
    _refresh_glows()

func _refresh_glows() -> void:
    var amount := clampf(_controller.get_boost_amount(), 0.0, 1.0)
    var length_scale := lerpf(1.0, 2.2, amount)
    _left_glow.scale = Vector3(1.0, length_scale, 1.0)
    _right_glow.scale = Vector3(1.0, length_scale, 1.0)

func _disable_with_error(message: String) -> void:
    push_error(message)
    set_process(false)
