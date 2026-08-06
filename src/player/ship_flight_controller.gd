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
var _boost_heat := 0.0
var _boost_locked_out := false
var _forward_thrust_amount := 0.0
var _local_velocity := Vector3.ZERO
var _auto_bank_offset := 0.0
var _auto_bank_rate := 0.0
var _smart_stabilizing := false
var _assistance_source: FlightAssistanceSource.Value = (
    FlightAssistanceSource.Value.NONE
)
var _last_command := FlightCommand.new()
var _last_pilot_force_local := Vector3.ZERO
var _last_pilot_torque_local := Vector3.ZERO
var _last_assist_force_local := Vector3.ZERO
var _last_assist_torque_local := Vector3.ZERO
var _last_force_local := Vector3.ZERO
var _last_torque_local := Vector3.ZERO

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

func _physics_process(delta: float) -> void:
    if _input_source.consume_mode_toggle():
        set_flight_mode(ShipFlightState.toggled_mode(_flight_mode))

    if _input_source.consume_reset_request():
        reset_requested.emit()

    var pilot_command := _input_source.sample_command(_flight_mode)
    _smart_stabilizing = _input_source.is_smart_stabilize_held()
    _assistance_source = FlightAssistanceSource.Value.NONE

    var basis := _body.global_transform.basis.orthonormalized()
    var local_linear := basis.inverse() * _body.linear_velocity
    var local_angular := basis.inverse() * _body.angular_velocity
    _local_velocity = local_linear

    var automatic_command := FlightAssistCommand.new()
    if _smart_stabilizing:
        automatic_command = SmartStabilizeSolver.compute(
            local_linear,
            local_angular,
            tuning
        )
    elif pilot_command.mode == FlightMode.Value.AI_ASSISTED:
        automatic_command = AiFlightIntentSolver.compute(
            pilot_command,
            local_linear,
            local_angular,
            tuning
        )

    var boost_activity_command := pilot_command.translation
    if _smart_stabilizing:
        boost_activity_command = automatic_command.translation
    elif pilot_command.mode == FlightMode.Value.AI_ASSISTED:
        boost_activity_command = FlightAuthority.combine_translation(
            pilot_command.translation,
            automatic_command.translation
        )

    var thermal_state := BoostThermalState.advance(
        _boost_heat,
        _boost_locked_out,
        pilot_command.boost,
        boost_activity_command.length(),
        delta,
        tuning.boost_heat_per_second,
        tuning.boost_cooling_per_second,
        tuning.boost_recovery_threshold
    )
    _boost_heat = thermal_state.heat
    _boost_locked_out = thermal_state.locked_out
    _boost_amount = thermal_state.effective_boost

    var physics_command := pilot_command.duplicate_command()
    if _smart_stabilizing:
        physics_command.translation = Vector3.ZERO
        physics_command.rotation = Vector3.ZERO
    physics_command.boost = _boost_amount
    _forward_thrust_amount = clampf(
        -physics_command.translation.z,
        0.0,
        1.0
    )

    var assist_rotation_command := Vector3.ZERO
    var pilot_roll := physics_command.rotation.z
    if physics_command.mode == FlightMode.Value.ASSISTED:
        var bank_state := CoordinatedTurnState.advance(
            _auto_bank_offset,
            _auto_bank_rate,
            physics_command.rotation.y,
            pilot_roll,
            delta,
            tuning.auto_bank_max_degrees,
            tuning.auto_bank_response
        )
        _auto_bank_offset = bank_state.bank_offset
        _auto_bank_rate = bank_state.bank_rate
        assist_rotation_command.z = bank_state.roll_command
    else:
        _auto_bank_offset = 0.0
        _auto_bank_rate = 0.0

    _last_command = physics_command.duplicate_command()

    var output := FlightModel.compute(
        physics_command,
        tuning,
        local_linear,
        local_angular,
        _body.mass,
        assist_rotation_command
    )

    var soft_start := (
        tuning.boost_speed_soft_start
        if _boost_amount > 0.0
        else tuning.normal_speed_soft_start
    )
    var soft_limit := (
        tuning.boost_speed_limit
        if _boost_amount > 0.0
        else tuning.normal_speed_limit
    )

    if _smart_stabilizing:
        var raw_stabilize_force := FlightAuthority.translation_force(
            automatic_command.translation,
            _boost_amount,
            tuning
        )
        output.pilot_force_local = Vector3.ZERO
        output.pilot_torque_local = Vector3.ZERO
        output.assist_force_local = FlightSpeedEnvelope.apply_to_force(
            raw_stabilize_force,
            local_linear,
            soft_start,
            soft_limit
        )
        output.assist_torque_local = FlightAuthority.rotation_torque(
            automatic_command.rotation,
            tuning
        )
        _assistance_source = (
            FlightAssistanceSource.Value.SMART_STABILIZE
        )
    elif physics_command.mode == FlightMode.Value.AI_ASSISTED:
        var combined_translation := FlightAuthority.combine_translation(
            physics_command.translation,
            automatic_command.translation
        )
        var combined_rotation := FlightAuthority.combine_rotation(
            physics_command.rotation,
            automatic_command.rotation
        )
        var raw_total_force := FlightAuthority.translation_force(
            combined_translation,
            _boost_amount,
            tuning
        )
        var total_force := FlightSpeedEnvelope.apply_to_force(
            raw_total_force,
            local_linear,
            soft_start,
            soft_limit
        )
        var total_torque := FlightAuthority.rotation_torque(
            combined_rotation,
            tuning
        )
        output.assist_force_local = (
            total_force - output.pilot_force_local
        )
        output.assist_torque_local = (
            total_torque - output.pilot_torque_local
        )
        _assistance_source = FlightAssistanceSource.Value.AI_ASSISTED
    elif physics_command.mode == FlightMode.Value.ASSISTED:
        _assistance_source = (
            FlightAssistanceSource.Value.LEGACY_ASSISTED
        )

    output.finalize_totals()
    _last_pilot_force_local = output.pilot_force_local
    _last_pilot_torque_local = output.pilot_torque_local
    _last_assist_force_local = output.assist_force_local
    _last_assist_torque_local = output.assist_torque_local
    _last_force_local = output.force_local
    _last_torque_local = output.torque_local
    _body.apply_central_force(basis * output.force_local)
    _body.apply_torque(basis * output.torque_local)

func set_flight_mode(value: FlightMode.Value) -> bool:
    if not FlightMode.is_valid(value):
        return false
    if _flight_mode == value:
        return false

    _flight_mode = value
    _auto_bank_offset = 0.0
    _auto_bank_rate = 0.0
    _smart_stabilizing = false
    _assistance_source = FlightAssistanceSource.Value.NONE
    flight_mode_changed.emit(_flight_mode)
    return true

func get_flight_mode() -> FlightMode.Value:
    return _flight_mode

func get_speed_mps() -> float:
    return ShipFlightState.speed_mps(_body.linear_velocity) if _body != null else 0.0

func get_boost_amount() -> float:
    return _boost_amount

func get_boost_heat() -> float:
    return _boost_heat

func is_boost_locked_out() -> bool:
    return _boost_locked_out

func get_boost_recovery_progress() -> float:
    return BoostThermalState.recovery_progress(
        _boost_heat,
        tuning.boost_recovery_threshold
    ) if tuning != null else 0.0

func get_active_speed_limit() -> float:
    if tuning == null:
        return 0.0
    return (
        tuning.boost_speed_limit
        if _boost_amount > 0.0
        else tuning.normal_speed_limit
    )

func get_forward_thrust_amount() -> float:
    return _forward_thrust_amount

func get_auto_bank_offset_degrees() -> float:
    return rad_to_deg(_auto_bank_offset)

func is_smart_stabilizing() -> bool:
    return _smart_stabilizing

func get_assistance_source() -> FlightAssistanceSource.Value:
    return _assistance_source

func get_local_velocity() -> Vector3:
    return _local_velocity

func get_world_velocity() -> Vector3:
    return _body.linear_velocity if _body != null else Vector3.ZERO

func get_body() -> RigidBody3D:
    return _body

func get_last_command() -> FlightCommand:
    return _last_command.duplicate_command()

func get_last_pilot_force_local() -> Vector3:
    return _last_pilot_force_local

func get_last_pilot_torque_local() -> Vector3:
    return _last_pilot_torque_local

func get_last_assist_force_local() -> Vector3:
    return _last_assist_force_local

func get_last_assist_torque_local() -> Vector3:
    return _last_assist_torque_local

func get_last_force_local() -> Vector3:
    return _last_force_local

func get_last_torque_local() -> Vector3:
    return _last_torque_local

func get_force_reference() -> float:
    if tuning == null:
        return 1.0
    return maxf(
        maxf(tuning.forward_force, tuning.strafe_force) * tuning.boost_multiplier,
        tuning.reverse_force
    )

func get_torque_reference() -> float:
    if tuning == null:
        return 1.0
    return maxf(tuning.pitch_torque, maxf(tuning.yaw_torque, tuning.roll_torque))

func reset_runtime_state() -> void:
    _boost_heat = 0.0
    _boost_locked_out = false
    _boost_amount = 0.0
    _forward_thrust_amount = 0.0
    _auto_bank_offset = 0.0
    _auto_bank_rate = 0.0
    _smart_stabilizing = false
    _assistance_source = FlightAssistanceSource.Value.NONE
    _last_command = FlightCommand.new()
    _last_pilot_force_local = Vector3.ZERO
    _last_pilot_torque_local = Vector3.ZERO
    _last_assist_force_local = Vector3.ZERO
    _last_assist_torque_local = Vector3.ZERO
    _last_force_local = Vector3.ZERO
    _last_torque_local = Vector3.ZERO
