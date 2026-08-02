class_name ThrusterActionMatrix
extends RefCounted

const KNOWN_SOCKET_PATHS := [
    &"Main/MainLeft",
    &"Main/MainRight",
    &"Retro/RetroLeft",
    &"Retro/RetroRight",
    &"Maneuver/FrontUpperLeft",
    &"Maneuver/FrontUpperRight",
    &"Maneuver/RearUpperLeft",
    &"Maneuver/RearUpperRight",
    &"Maneuver/RearLowerLeft",
    &"Maneuver/RearLowerRight",
    &"Maneuver/FrontLowerLeft",
    &"Maneuver/FrontLowerRight",
]

var _weights_by_action: Array[Dictionary] = []
var _valid := false

static func load_checked_in(path: String) -> ThrusterActionMatrix:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return null

    var matrix := ThrusterActionMatrix.new()
    if not matrix._load_data(parsed as Dictionary):
        return null
    return matrix

func is_valid() -> bool:
    return _valid

func weights_for(action: int) -> Dictionary:
    if not _valid or action < 0 or action >= _weights_by_action.size():
        return {}
    return _weights_by_action[action].duplicate(true)

func intensities_for(command: FlightCommand) -> Dictionary:
    var output: Dictionary = {}
    if not _valid or command == null:
        return output

    _apply_action(
        output,
        ThrusterAction.Value.FORWARD,
        maxf(-command.translation.z, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.REVERSE,
        maxf(command.translation.z, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.STRAFE_LEFT,
        maxf(-command.translation.x, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.STRAFE_RIGHT,
        maxf(command.translation.x, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.STRAFE_UP,
        maxf(command.translation.y, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.STRAFE_DOWN,
        maxf(-command.translation.y, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.PITCH_UP,
        maxf(command.rotation.x, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.PITCH_DOWN,
        maxf(-command.rotation.x, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.YAW_LEFT,
        maxf(command.rotation.y, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.YAW_RIGHT,
        maxf(-command.rotation.y, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.ROLL_LEFT,
        maxf(command.rotation.z, 0.0)
    )
    _apply_action(
        output,
        ThrusterAction.Value.ROLL_RIGHT,
        maxf(-command.rotation.z, 0.0)
    )
    return output

func _load_data(data: Dictionary) -> bool:
    if int(data.get("schema_version", 0)) != 1:
        return false
    if bool(data.get("runtime_generated", true)):
        return false

    var action_records: Variant = data.get("actions", [])
    if not action_records is Array:
        return false

    _weights_by_action.resize(ThrusterAction.action_count())
    for action: int in range(_weights_by_action.size()):
        _weights_by_action[action] = {}

    var seen: Dictionary = {}
    for record_variant: Variant in action_records:
        if not record_variant is Dictionary:
            return false
        var record := record_variant as Dictionary
        var action_name := StringName(String(record.get("action", "")))
        var action := ThrusterAction.from_name(action_name)
        if action < 0 or seen.has(action):
            return false

        var raw_weights: Variant = record.get("weights", {})
        if not raw_weights is Dictionary or raw_weights.is_empty():
            return false

        var normalized: Dictionary = {}
        for path_variant: Variant in raw_weights.keys():
            var path := StringName(String(path_variant))
            if not KNOWN_SOCKET_PATHS.has(path):
                return false
            var weight := float(raw_weights[path_variant])
            if not is_finite(weight) or weight <= 0.0 or weight > 1.0:
                return false
            normalized[path] = weight

        _weights_by_action[action] = normalized
        seen[action] = true

    if seen.size() != ThrusterAction.action_count():
        return false
    for action: int in range(_weights_by_action.size()):
        if _weights_by_action[action].is_empty():
            return false

    var forward := _weights_by_action[ThrusterAction.Value.FORWARD]
    var left_main := float(forward.get(&"Main/MainLeft", 0.0))
    var right_main := float(forward.get(&"Main/MainRight", 0.0))
    if left_main <= 0.0 or not is_equal_approx(left_main, right_main):
        return false
    if forward.size() != 2:
        return false

    _valid = true
    return true

func _apply_action(output: Dictionary, action: int, amount: float) -> void:
    var strength := clampf(amount, 0.0, 1.0)
    if strength <= 0.0:
        return

    var weights := _weights_by_action[action]
    for path_variant: Variant in weights.keys():
        var path := StringName(String(path_variant))
        var candidate := float(weights[path_variant]) * strength
        output[path] = maxf(float(output.get(path, 0.0)), candidate)
