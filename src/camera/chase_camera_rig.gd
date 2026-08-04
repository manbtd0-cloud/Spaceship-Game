class_name ChaseCameraRig
extends Node3D

enum Preset {
    CLOSE,
    STANDARD,
    FAR,
}

enum TemporaryView {
    NONE,
    REAR,
    LEFT,
    RIGHT,
}

const DYNAMIC_POSITION_SHARPNESS := 5.5
const DYNAMIC_ROTATION_SHARPNESS := 7.0
const DYNAMIC_VELOCITY_LOOK_AHEAD := 0.08
const DYNAMIC_MAX_PREDICTION := 8.0

const TACTICAL_POSITION_SHARPNESS := 14.0
const TACTICAL_ROTATION_SHARPNESS := 22.0
const TACTICAL_VELOCITY_LOOK_AHEAD := 0.015
const TACTICAL_MAX_PREDICTION := 2.0
const TACTICAL_MAX_POSITION_ERROR := 1.5
const TACTICAL_MAX_ROTATION_ERROR_DEGREES := 6.0

const DISTANCE_CYCLE: Array[int] = [
    CameraDistance.Value.STANDARD,
    CameraDistance.Value.FAR,
    CameraDistance.Value.CLOSE,
]

@export var target_path: NodePath
@export var controller_path: NodePath
@export var camera_path: NodePath
@export var tuning: FlightTuning
@export var preset_transition_sharpness: float = 9.0
@export var base_fov: float = 68.0

var _target: Node3D
var _controller: ShipFlightController
var _camera: Camera3D
var _presets: Dictionary = {
    CameraDistance.Value.CLOSE: ChaseCameraPreset.new(
        &"close",
        10.5,
        3.2,
        3.5,
        14.0
    ),
    CameraDistance.Value.STANDARD: ChaseCameraPreset.new(
        &"standard",
        14.0,
        4.0,
        5.0,
        19.0
    ),
    CameraDistance.Value.FAR: ChaseCameraPreset.new(
        &"far",
        20.0,
        5.0,
        7.0,
        27.0
    ),
}
var _selected_behavior: CameraBehavior.Value = CameraBehavior.Value.TACTICAL
var _selected_distance: CameraDistance.Value = CameraDistance.Value.STANDARD
var _temporary_view: int = TemporaryView.NONE
var _current_rear_offset: float = 14.0
var _current_height: float = 4.0
var _current_max_speed_pullback: float = 5.0
var _current_hard_rear_limit: float = 19.0
var _initialized := false

func _ready() -> void:
    initialize()

func initialize() -> void:
    if _initialized:
        return

    _target = get_node_or_null(target_path) as Node3D
    _controller = get_node_or_null(controller_path) as ShipFlightController
    _camera = get_node_or_null(camera_path) as Camera3D

    if _target == null:
        _disable_with_error(
            "ChaseCameraRig could not resolve target at %s" % target_path
        )
        return
    if _controller == null:
        _disable_with_error(
            "ChaseCameraRig could not resolve controller at %s"
            % controller_path
        )
        return
    if _camera == null:
        _disable_with_error(
            "ChaseCameraRig could not resolve Camera3D at %s" % camera_path
        )
        return
    if tuning == null:
        _disable_with_error("ChaseCameraRig requires a FlightTuning resource")
        return

    if not CameraBehavior.is_valid(_selected_behavior):
        _selected_behavior = CameraBehavior.Value.TACTICAL
    if _preset_for(_selected_distance) == null:
        _selected_distance = CameraDistance.Value.STANDARD
    _snap_to_desired_state()
    _initialized = true

func _process(delta: float) -> void:
    if not _initialized:
        return
    if Input.is_action_just_pressed(&"camera_cycle"):
        cycle_preset()
    step_camera(delta)

func cycle_preset() -> void:
    var current_index := DISTANCE_CYCLE.find(_selected_distance)
    if current_index < 0:
        select_distance(CameraDistance.Value.STANDARD)
        return

    for offset: int in range(1, DISTANCE_CYCLE.size() + 1):
        var candidate := DISTANCE_CYCLE[
            (current_index + offset) % DISTANCE_CYCLE.size()
        ]
        if _preset_for(candidate) != null:
            select_distance(candidate)
            return
    select_distance(CameraDistance.Value.STANDARD)

func select_behavior(value: CameraBehavior.Value) -> bool:
    if not CameraBehavior.is_valid(value):
        return false
    if _selected_behavior == value:
        return false
    _selected_behavior = value
    if (
        _initialized
        and _temporary_view == TemporaryView.NONE
        and value == CameraBehavior.Value.LOCKED
    ):
        _snap_to_desired_state()
    return true

func get_selected_behavior() -> CameraBehavior.Value:
    if not CameraBehavior.is_valid(_selected_behavior):
        _selected_behavior = CameraBehavior.Value.TACTICAL
    return _selected_behavior

func select_distance(value: CameraDistance.Value) -> bool:
    if not CameraDistance.is_valid(value) or _preset_for(value) == null:
        return false
    if _selected_distance == value:
        return false
    _selected_distance = value
    if (
        _initialized
        and _temporary_view == TemporaryView.NONE
        and _selected_behavior == CameraBehavior.Value.LOCKED
    ):
        _snap_to_desired_state()
    return true

func get_selected_distance() -> CameraDistance.Value:
    if _preset_for(_selected_distance) == null:
        _selected_distance = CameraDistance.Value.STANDARD
    return _selected_distance

func select_preset(value: int) -> void:
    if _preset_for(value) == null:
        _selected_distance = CameraDistance.Value.STANDARD
        if (
            _initialized
            and _temporary_view == TemporaryView.NONE
            and _selected_behavior == CameraBehavior.Value.LOCKED
        ):
            _snap_to_desired_state()
        return
    select_distance(value as CameraDistance.Value)

func get_selected_preset() -> int:
    return int(get_selected_distance())

func get_selected_preset_name() -> StringName:
    return _selected_valid_preset().semantic_name

func get_temporary_view() -> int:
    return _temporary_view

func is_initialized() -> bool:
    return _initialized

func get_current_framing() -> Dictionary:
    return {
        "rear_offset": _current_rear_offset,
        "height": _current_height,
        "max_speed_pullback": _current_max_speed_pullback,
        "hard_rear_limit": _current_hard_rear_limit,
    }

func step_camera_for_test(delta: float) -> void:
    step_camera(delta)

func step_camera(delta: float) -> void:
    if not _initialized:
        return

    var requested_temporary_view := _sample_temporary_view()
    if requested_temporary_view != TemporaryView.NONE:
        _temporary_view = requested_temporary_view
        _apply_temporary_view(requested_temporary_view)
        _update_fov(delta)
        return

    if _temporary_view != TemporaryView.NONE:
        _temporary_view = TemporaryView.NONE
        _snap_to_desired_state()
        return

    _advance_distance_framing(delta)

    var world_velocity := _controller.get_world_velocity()
    var desired_position := _desired_position(world_velocity)
    var desired_target := _desired_target(world_velocity)
    if not desired_position.is_finite() or not desired_target.is_finite():
        _update_fov(delta)
        return

    var desired_basis := ChaseCameraMath.desired_camera_basis(
        desired_position,
        desired_target,
        _target.global_transform
    )

    match get_selected_behavior():
        CameraBehavior.Value.DYNAMIC:
            _step_dynamic(desired_position, desired_basis, delta)
        CameraBehavior.Value.LOCKED:
            global_transform = Transform3D(desired_basis, desired_position)
        _:
            _step_tactical(desired_position, desired_basis, delta)

    _update_fov(delta)

func _sample_temporary_view() -> int:
    if _action_pressed(&"look_rear"):
        return TemporaryView.REAR
    if _action_pressed(&"look_right"):
        return TemporaryView.RIGHT
    if _action_pressed(&"look_left"):
        return TemporaryView.LEFT
    return TemporaryView.NONE

func _action_pressed(action: StringName) -> bool:
    return InputMap.has_action(action) and Input.is_action_pressed(action)

func _apply_temporary_view(view: int) -> void:
    var preset := _selected_valid_preset()
    global_transform = ChaseCameraMath.temporary_view_transform(
        _target.global_transform,
        view,
        preset.rear_offset,
        preset.height
    )

func _advance_distance_framing(delta: float) -> void:
    if get_selected_behavior() == CameraBehavior.Value.LOCKED:
        var locked_preset := _selected_valid_preset()
        _current_rear_offset = locked_preset.rear_offset
        _current_height = locked_preset.height
        _current_max_speed_pullback = locked_preset.max_speed_pullback
        _current_hard_rear_limit = locked_preset.hard_rear_limit
        return

    var preset := _selected_valid_preset()
    _current_rear_offset = ChaseCameraMath.interpolate_scalar(
        _current_rear_offset,
        preset.rear_offset,
        preset_transition_sharpness,
        delta
    )
    _current_height = ChaseCameraMath.interpolate_scalar(
        _current_height,
        preset.height,
        preset_transition_sharpness,
        delta
    )
    _current_max_speed_pullback = ChaseCameraMath.interpolate_scalar(
        _current_max_speed_pullback,
        preset.max_speed_pullback,
        preset_transition_sharpness,
        delta
    )
    _current_hard_rear_limit = ChaseCameraMath.interpolate_scalar(
        _current_hard_rear_limit,
        preset.hard_rear_limit,
        preset_transition_sharpness,
        delta
    )

func _step_dynamic(
    desired_position: Vector3,
    desired_basis: Basis,
    delta: float
) -> void:
    var candidate_position := global_position.lerp(
        desired_position,
        ChaseCameraMath.exponential_weight(
            DYNAMIC_POSITION_SHARPNESS,
            delta
        )
    )
    var bounded_position := ChaseCameraMath.clamp_rear_position(
        _target.global_transform,
        candidate_position,
        _current_hard_rear_limit
    )
    var candidate_basis := _interpolated_basis(
        desired_basis,
        DYNAMIC_ROTATION_SHARPNESS,
        delta
    )
    global_transform = Transform3D(candidate_basis, bounded_position)

func _step_tactical(
    desired_position: Vector3,
    desired_basis: Basis,
    delta: float
) -> void:
    var candidate_position := global_position.lerp(
        desired_position,
        ChaseCameraMath.exponential_weight(
            TACTICAL_POSITION_SHARPNESS,
            delta
        )
    )
    candidate_position = ChaseCameraMath.clamp_position_error(
        candidate_position,
        desired_position,
        TACTICAL_MAX_POSITION_ERROR
    )
    candidate_position = ChaseCameraMath.clamp_rear_position(
        _target.global_transform,
        candidate_position,
        _current_hard_rear_limit
    )

    var candidate_basis := _interpolated_basis(
        desired_basis,
        TACTICAL_ROTATION_SHARPNESS,
        delta
    )
    candidate_basis = ChaseCameraMath.clamp_rotation_error(
        candidate_basis,
        desired_basis,
        TACTICAL_MAX_ROTATION_ERROR_DEGREES
    )
    global_transform = Transform3D(candidate_basis, candidate_position)

func _interpolated_basis(
    desired_basis: Basis,
    sharpness: float,
    delta: float
) -> Basis:
    var current_rotation := (
        global_transform.basis
        .orthonormalized()
        .get_rotation_quaternion()
    )
    var desired_rotation := (
        desired_basis
        .orthonormalized()
        .get_rotation_quaternion()
    )
    return Basis(
        current_rotation.slerp(
            desired_rotation,
            ChaseCameraMath.exponential_weight(sharpness, delta)
        )
    ).orthonormalized()

func _desired_position(world_velocity: Vector3) -> Vector3:
    return ChaseCameraMath.desired_position(
        _target.global_transform,
        world_velocity,
        _current_rear_offset,
        _current_height,
        tuning.camera_speed_pullback,
        _current_max_speed_pullback,
        _current_hard_rear_limit
    )

func _desired_target(world_velocity: Vector3) -> Vector3:
    var parameters := _behavior_parameters()
    return ChaseCameraMath.desired_look_target(
        _target.global_transform,
        world_velocity,
        float(parameters["velocity_look_ahead"]),
        tuning.camera_forward_look_ahead,
        float(parameters["max_prediction_distance"])
    )

func _behavior_parameters() -> Dictionary:
    match get_selected_behavior():
        CameraBehavior.Value.DYNAMIC:
            return {
                "rotation_sharpness": DYNAMIC_ROTATION_SHARPNESS,
                "velocity_look_ahead": DYNAMIC_VELOCITY_LOOK_AHEAD,
                "max_prediction_distance": DYNAMIC_MAX_PREDICTION,
            }
        CameraBehavior.Value.LOCKED:
            return {
                "rotation_sharpness": TACTICAL_ROTATION_SHARPNESS,
                "velocity_look_ahead": 0.0,
                "max_prediction_distance": 0.0,
            }
        _:
            return {
                "rotation_sharpness": TACTICAL_ROTATION_SHARPNESS,
                "velocity_look_ahead": TACTICAL_VELOCITY_LOOK_AHEAD,
                "max_prediction_distance": TACTICAL_MAX_PREDICTION,
            }

func _snap_to_desired_state() -> void:
    var preset := _selected_valid_preset()
    _current_rear_offset = preset.rear_offset
    _current_height = preset.height
    _current_max_speed_pullback = preset.max_speed_pullback
    _current_hard_rear_limit = preset.hard_rear_limit

    var world_velocity := _controller.get_world_velocity()
    var desired_position := _desired_position(world_velocity)
    var desired_target := _desired_target(world_velocity)
    if desired_position.is_finite() and desired_target.is_finite():
        var desired_basis := ChaseCameraMath.desired_camera_basis(
            desired_position,
            desired_target,
            _target.global_transform
        )
        global_transform = Transform3D(desired_basis, desired_position)

    _camera.fov = _desired_fov()

func _desired_fov() -> float:
    return ChaseCameraMath.desired_fov(
        _controller.get_speed_mps(),
        _controller.get_boost_amount(),
        base_fov,
        tuning.normal_speed_limit,
        tuning.boost_speed_limit,
        tuning.camera_normal_max_fov,
        tuning.camera_boost_max_fov,
        tuning.camera_boost_fov_bonus
    )

func _update_fov(delta: float) -> void:
    var desired_fov := _desired_fov()
    if get_selected_behavior() == CameraBehavior.Value.LOCKED:
        _camera.fov = desired_fov
        return
    var parameters := _behavior_parameters()
    _camera.fov = lerpf(
        _camera.fov,
        desired_fov,
        ChaseCameraMath.exponential_weight(
            float(parameters["rotation_sharpness"]),
            delta
        )
    )

func _preset_for(value: int) -> ChaseCameraPreset:
    var candidate := _presets.get(value) as ChaseCameraPreset
    if candidate == null or not candidate.is_valid():
        return null
    return candidate

func _selected_valid_preset() -> ChaseCameraPreset:
    var preset := _preset_for(_selected_distance)
    if preset != null:
        return preset
    _selected_distance = CameraDistance.Value.STANDARD
    return _presets[CameraDistance.Value.STANDARD] as ChaseCameraPreset

func _disable_with_error(message: String) -> void:
    push_error(message)
    _initialized = false
    set_process(false)
