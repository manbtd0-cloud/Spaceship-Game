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

const PRESET_CYCLE: Array[int] = [
    Preset.STANDARD,
    Preset.FAR,
    Preset.CLOSE,
]

@export var target_path: NodePath
@export var controller_path: NodePath
@export var camera_path: NodePath
@export var tuning: FlightTuning
@export var position_sharpness: float = 5.5
@export var rotation_sharpness: float = 7.0
@export var preset_transition_sharpness: float = 9.0
@export var velocity_look_ahead: float = 0.08
@export var max_prediction_distance: float = 8.0
@export var base_fov: float = 68.0

var _target: Node3D
var _controller: ShipFlightController
var _camera: Camera3D
var _presets: Dictionary = {
    Preset.CLOSE: ChaseCameraPreset.new(
        &"close",
        10.5,
        3.2,
        3.5,
        14.0
    ),
    Preset.STANDARD: ChaseCameraPreset.new(
        &"standard",
        14.0,
        4.0,
        5.0,
        19.0
    ),
    Preset.FAR: ChaseCameraPreset.new(
        &"far",
        20.0,
        5.0,
        7.0,
        27.0
    ),
}
var _selected_preset: int = Preset.STANDARD
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

    select_preset(_selected_preset)
    _snap_to_desired_state()
    _initialized = true

func _process(delta: float) -> void:
    if not _initialized:
        return
    if Input.is_action_just_pressed(&"camera_cycle"):
        cycle_preset()
    step_camera(delta)

func cycle_preset() -> void:
    var current_index := PRESET_CYCLE.find(_selected_preset)
    if current_index < 0:
        select_preset(Preset.STANDARD)
        return

    for offset: int in range(1, PRESET_CYCLE.size() + 1):
        var candidate := PRESET_CYCLE[
            (current_index + offset) % PRESET_CYCLE.size()
        ]
        if _preset_for(candidate) != null:
            _selected_preset = candidate
            return
    select_preset(Preset.STANDARD)

func select_preset(value: int) -> void:
    if _preset_for(value) == null:
        _selected_preset = Preset.STANDARD
        return
    _selected_preset = value

func get_selected_preset() -> int:
    if _preset_for(_selected_preset) == null:
        _selected_preset = Preset.STANDARD
    return _selected_preset

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

    var world_velocity := _controller.get_world_velocity()
    var desired_position := ChaseCameraMath.desired_position(
        _target.global_transform,
        world_velocity,
        _current_rear_offset,
        _current_height,
        tuning.camera_speed_pullback,
        _current_max_speed_pullback,
        _current_hard_rear_limit
    )
    if desired_position.is_finite():
        var position_weight := ChaseCameraMath.exponential_weight(
            position_sharpness,
            delta
        )
        var candidate_position := global_position.lerp(
            desired_position,
            position_weight
        )
        global_position = ChaseCameraMath.clamp_rear_position(
            _target.global_transform,
            candidate_position,
            _current_hard_rear_limit
        )

    var desired_target := ChaseCameraMath.desired_look_target(
        _target.global_transform,
        world_velocity,
        velocity_look_ahead,
        tuning.camera_forward_look_ahead,
        max_prediction_distance
    )
    if desired_target.is_finite():
        _smooth_rotation_toward(desired_target, delta)

    _update_fov(delta)

func _snap_to_desired_state() -> void:
    var preset := _selected_valid_preset()
    _current_rear_offset = preset.rear_offset
    _current_height = preset.height
    _current_max_speed_pullback = preset.max_speed_pullback
    _current_hard_rear_limit = preset.hard_rear_limit

    var world_velocity := _controller.get_world_velocity()
    var desired_position := ChaseCameraMath.desired_position(
        _target.global_transform,
        world_velocity,
        _current_rear_offset,
        _current_height,
        tuning.camera_speed_pullback,
        _current_max_speed_pullback,
        _current_hard_rear_limit
    )
    if desired_position.is_finite():
        global_position = desired_position

    var desired_target := ChaseCameraMath.desired_look_target(
        _target.global_transform,
        world_velocity,
        velocity_look_ahead,
        tuning.camera_forward_look_ahead,
        max_prediction_distance
    )
    if desired_target.is_finite():
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

func _update_fov(delta: float) -> void:
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

func _smooth_rotation_toward(look_target: Vector3, delta: float) -> void:
    if global_position.distance_squared_to(look_target) < 0.0001:
        return

    var desired_basis := _desired_basis(look_target)
    var current_rotation := (
        global_transform.basis
        .orthonormalized()
        .get_rotation_quaternion()
    )
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

func _preset_for(value: int) -> ChaseCameraPreset:
    var candidate := _presets.get(value) as ChaseCameraPreset
    if candidate == null or not candidate.is_valid():
        return null
    return candidate

func _selected_valid_preset() -> ChaseCameraPreset:
    var preset := _preset_for(_selected_preset)
    if preset != null:
        return preset
    _selected_preset = Preset.STANDARD
    return _presets[Preset.STANDARD] as ChaseCameraPreset

func _disable_with_error(message: String) -> void:
    push_error(message)
    _initialized = false
    set_process(false)
