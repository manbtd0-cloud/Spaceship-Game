class_name ChaseCameraRig
extends Node3D

@export var target_path: NodePath
@export var controller_path: NodePath
@export var camera_path: NodePath
@export var tuning: FlightTuning
@export var base_offset := Vector3(0.0, 4.0, 16.0)
@export var position_sharpness: float = 5.5
@export var rotation_sharpness: float = 7.0
@export var velocity_look_ahead: float = 0.08
@export var base_fov: float = 68.0

var _target: Node3D
var _controller: ShipFlightController
var _camera: Camera3D

func _ready() -> void:
    _target = get_node_or_null(target_path) as Node3D
    _controller = get_node_or_null(controller_path) as ShipFlightController
    _camera = get_node_or_null(camera_path) as Camera3D

    if _target == null:
        push_error("ChaseCameraRig could not resolve target at %s" % target_path)
        set_process(false)
        return
    if _controller == null:
        push_error("ChaseCameraRig could not resolve controller at %s" % controller_path)
        set_process(false)
        return
    if _camera == null:
        push_error("ChaseCameraRig could not resolve Camera3D at %s" % camera_path)
        set_process(false)
        return
    if tuning == null:
        push_error("ChaseCameraRig requires a FlightTuning resource")
        set_process(false)
        return

    _snap_to_desired_state()

func _process(delta: float) -> void:
    var world_velocity := _controller.get_world_velocity()
    var desired_position := ChaseCameraMath.desired_position(
        _target.global_transform,
        world_velocity,
        base_offset,
        velocity_look_ahead,
        tuning.camera_speed_pullback,
        tuning.camera_max_pullback
    )
    var position_weight := ChaseCameraMath.exponential_weight(
        position_sharpness,
        delta
    )
    global_position = global_position.lerp(desired_position, position_weight)

    var desired_target := ChaseCameraMath.desired_look_target(
        _target.global_transform,
        world_velocity,
        velocity_look_ahead,
        tuning.camera_forward_look_ahead
    )
    _smooth_rotation_toward(desired_target, delta)

    var desired_fov := ChaseCameraMath.desired_fov(
        _controller.get_speed_mps(),
        _controller.get_boost_amount(),
        base_fov,
        tuning.normal_speed_limit,
        tuning.boost_speed_limit,
        tuning.camera_normal_max_fov,
        tuning.camera_boost_max_fov,
        tuning.camera_boost_fov_bonus
    )
    _camera.fov = lerpf(
        _camera.fov,
        desired_fov,
        ChaseCameraMath.exponential_weight(rotation_sharpness, delta)
    )

func _snap_to_desired_state() -> void:
    var world_velocity := _controller.get_world_velocity()
    global_position = ChaseCameraMath.desired_position(
        _target.global_transform,
        world_velocity,
        base_offset,
        velocity_look_ahead,
        tuning.camera_speed_pullback,
        tuning.camera_max_pullback
    )
    var desired_target := ChaseCameraMath.desired_look_target(
        _target.global_transform,
        world_velocity,
        velocity_look_ahead,
        tuning.camera_forward_look_ahead
    )
    _set_rotation_toward(desired_target)
    _camera.fov = ChaseCameraMath.desired_fov(
        _controller.get_speed_mps(),
        _controller.get_boost_amount(),
        base_fov,
        tuning.normal_speed_limit,
        tuning.boost_speed_limit,
        tuning.camera_normal_max_fov,
        tuning.camera_boost_max_fov,
        tuning.camera_boost_fov_bonus
    )

func _smooth_rotation_toward(look_target: Vector3, delta: float) -> void:
    if global_position.distance_squared_to(look_target) < 0.0001:
        return

    var desired_basis := _desired_basis(look_target)
    var current_rotation := global_transform.basis.orthonormalized().get_rotation_quaternion()
    var desired_rotation := desired_basis.get_rotation_quaternion()
    var rotation_weight := ChaseCameraMath.exponential_weight(
        rotation_sharpness,
        delta
    )
    global_transform = Transform3D(
        Basis(
            current_rotation.slerp(
                desired_rotation,
                rotation_weight
            )
        ).orthonormalized(),
        global_position
    )

func _set_rotation_toward(look_target: Vector3) -> void:
    if global_position.distance_squared_to(look_target) < 0.0001:
        return
    global_transform = Transform3D(_desired_basis(look_target), global_position)

func _desired_basis(look_target: Vector3) -> Basis:
    return ChaseCameraMath.desired_camera_basis(
        global_position,
        look_target,
        _target.global_transform
    )
