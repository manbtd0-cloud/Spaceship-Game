class_name ShipFlightController
extends Node

signal flight_mode_changed(mode: FlightMode.Value)
signal reset_requested

@export var body_path: NodePath
@export var input_source_path: NodePath
@export var tuning: FlightTuning

var _body: RigidBody3D
var _input_source: PlayerInputSource
var _flight_mode: FlightMode.Value = FlightMode.Value.ASSISTED
var _boost_amount := 0.0
var _local_velocity := Vector3.ZERO

func _ready() -> void:
    _body = get_node_or_null(body_path) as RigidBody3D
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource

    if _body == null:
        push_error("ShipFlightController could not resolve RigidBody3D at %s" % body_path)
        set_physics_process(false)
        return
    if _input_source == null:
        push_error("ShipFlightController could not resolve PlayerInputSource at %s" % input_source_path)
        set_physics_process(false)
        return
    if tuning == null:
        push_error("ShipFlightController requires a FlightTuning resource")
        set_physics_process(false)

func _physics_process(_delta: float) -> void:
    if _input_source.consume_capture_toggle():
        _input_source.set_mouse_captured(not _input_source.is_mouse_captured())

    if _input_source.consume_mode_toggle():
        _flight_mode = ShipFlightState.toggled_mode(_flight_mode)
        flight_mode_changed.emit(_flight_mode)

    if _input_source.consume_reset_request():
        reset_requested.emit()

    var command := _input_source.sample_command(_flight_mode)
    _boost_amount = command.boost

    var basis := _body.global_transform.basis.orthonormalized()
    var local_linear := basis.inverse() * _body.linear_velocity
    var local_angular := basis.inverse() * _body.angular_velocity
    _local_velocity = local_linear

    var output := FlightModel.compute(
        command,
        tuning,
        local_linear,
        local_angular
    )
    _body.apply_central_force(basis * output.force_local)
    _body.apply_torque(basis * output.torque_local)

func get_flight_mode() -> FlightMode.Value:
    return _flight_mode

func get_speed_mps() -> float:
    return ShipFlightState.speed_mps(_body.linear_velocity) if _body != null else 0.0

func get_boost_amount() -> float:
    return _boost_amount

func get_local_velocity() -> Vector3:
    return _local_velocity

func get_world_velocity() -> Vector3:
    return _body.linear_velocity if _body != null else Vector3.ZERO

func get_body() -> RigidBody3D:
    return _body
