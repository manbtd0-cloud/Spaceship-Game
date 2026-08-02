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
    var strength := ShipVisualMath.exhaust_strength(
        _controller.get_forward_thrust_amount(),
        _controller.get_boost_amount()
    )
    var exhaust_visible := strength > 0.001
    _left_glow.visible = exhaust_visible
    _right_glow.visible = exhaust_visible
    if not exhaust_visible:
        return

    var radius_scale := ShipVisualMath.exhaust_radius_scale(strength)
    var length_scale := ShipVisualMath.exhaust_length_scale(strength)
    var exhaust_scale := Vector3(
        radius_scale,
        length_scale,
        radius_scale
    )
    _left_glow.scale = exhaust_scale
    _right_glow.scale = exhaust_scale

func _disable_with_error(message: String) -> void:
    push_error(message)
    if _left_glow != null:
        _left_glow.visible = false
    if _right_glow != null:
        _right_glow.visible = false
    set_process(false)
