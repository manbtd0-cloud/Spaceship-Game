class_name ThrusterCalibration
extends Node3D

const CASES := PackedStringArray([
    "forward",
    "reverse",
    "strafe_left",
    "strafe_right",
    "strafe_up",
    "strafe_down",
    "pitch_up",
    "pitch_down",
    "yaw_left",
    "yaw_right",
    "roll_left",
    "roll_right",
    "assist_translation",
    "assist_rotation",
])

var _case_index := 0
var _active := true
var _visual_controller: ShipThrusterVisualController
var _flight_controller: ShipFlightController
var _case_label: Label
var _report_label: Label

func _ready() -> void:
    var player := get_node_or_null("PlayerInterceptor") as RigidBody3D
    _visual_controller = get_node_or_null(
        "PlayerInterceptor/ShipThrusterVisualController"
    ) as ShipThrusterVisualController
    _flight_controller = get_node_or_null(
        "PlayerInterceptor/ShipFlightController"
    ) as ShipFlightController
    _case_label = get_node_or_null(
        "UI/Panel/Margin/VBox/CaseLabel"
    ) as Label
    _report_label = get_node_or_null(
        "UI/Panel/Margin/VBox/ReportLabel"
    ) as Label
    var camera := get_node_or_null("Camera3D") as Camera3D

    if player != null:
        player.freeze = true
    if _flight_controller != null:
        _flight_controller.set_physics_process(false)
    if _visual_controller == null or _flight_controller == null:
        push_error("Thruster calibration requires the production player controller")
        set_process(false)
        return

    _visual_controller.initialize()
    _visual_controller.set_process(false)
    if camera != null:
        camera.look_at(Vector3.ZERO, Vector3.UP)
    _apply_case()

func _process(delta: float) -> void:
    if _visual_controller == null:
        return
    _visual_controller.step_visuals(delta)
    _update_report()

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return

    match key_event.keycode:
        KEY_LEFT:
            _case_index = wrapi(_case_index - 1, 0, CASES.size())
            _apply_case()
        KEY_RIGHT:
            _case_index = wrapi(_case_index + 1, 0, CASES.size())
            _apply_case()
        KEY_SPACE:
            _active = not _active
            _apply_case()
        KEY_ESCAPE:
            get_tree().quit()

func get_case_names() -> PackedStringArray:
    return CASES.duplicate()

func get_action_matrix_path() -> String:
    return ShipThrusterVisualController.ACTION_MATRIX_PATH

func _apply_case() -> void:
    if _visual_controller == null or _flight_controller == null:
        return

    var command := FlightCommand.new()
    var assist_force := Vector3.ZERO
    var assist_torque := Vector3.ZERO
    var case_name := StringName(CASES[_case_index])
    if _active:
        if case_name == &"assist_translation":
            assist_force = (
                Vector3.FORWARD
                * _flight_controller.get_force_reference()
            )
        elif case_name == &"assist_rotation":
            assist_torque = (
                Vector3.RIGHT
                * _flight_controller.get_torque_reference()
            )
        else:
            command = _command_for_action(case_name)

    _visual_controller.set_test_command(command)
    _visual_controller.set_test_assist_wrench(
        assist_force,
        assist_torque
    )
    if _case_label != null:
        _case_label.text = "CASE %02d/%02d  %s  [%s]" % [
            _case_index + 1,
            CASES.size(),
            String(case_name).to_upper(),
            "ACTIVE" if _active else "PAUSED",
        ]

func _command_for_action(action_name: StringName) -> FlightCommand:
    var command := FlightCommand.new()
    var action := ThrusterAction.from_name(action_name)
    if action < 0:
        return command
    command.translation = ThrusterAction.target_force(action)
    command.rotation = ThrusterAction.target_torque(action)
    return command

func _update_report() -> void:
    if _report_label == null or _visual_controller == null:
        return

    var lines := PackedStringArray()
    for row: Dictionary in _visual_controller.get_thruster_report():
        var merged := float(row["merged"])
        var envelope := float(row["envelope"])
        if merged <= 0.0001 and envelope <= 0.0001:
            continue
        var force: Vector3 = row["force"]
        var torque: Vector3 = row["torque"]
        lines.append(String(row["path"]))
        lines.append(
            "  force=(%+.3f,%+.3f,%+.3f)  torque=(%+.3f,%+.3f,%+.3f)"
            % [force.x, force.y, force.z, torque.x, torque.y, torque.z]
        )
        lines.append(
            "  direct=%.3f  assist=%.3f  merged=%.3f  envelope=%.3f"
            % [
                float(row["direct"]),
                float(row["assist"]),
                merged,
                envelope,
            ]
        )
    if lines.is_empty():
        lines.append("No active thrusters")
    _report_label.text = "\n".join(lines)
