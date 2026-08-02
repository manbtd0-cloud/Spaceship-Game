class_name CoordinatedTurnState
extends RefCounted

var bank_offset: float = 0.0
var bank_rate: float = 0.0
var roll_command: float = 0.0

static func advance(
    current_offset: float,
    current_rate: float,
    yaw_input: float,
    manual_roll_input: float,
    delta: float,
    max_bank_degrees: float,
    response: float
) -> CoordinatedTurnState:
    var result := CoordinatedTurnState.new()
    if absf(manual_roll_input) > 0.001:
        return result

    var maximum := deg_to_rad(maxf(max_bank_degrees, 0.0))
    var target := -clampf(yaw_input, -1.0, 1.0) * maximum
    var omega := maxf(response, 0.001)
    var acceleration := (
        (target - current_offset) * omega * omega
        - 2.0 * omega * current_rate
    )
    var step := maxf(delta, 0.0)
    result.bank_rate = current_rate + acceleration * step
    result.bank_offset = clampf(
        current_offset + result.bank_rate * step,
        -maximum,
        maximum
    )
    var command_scale := maxf(
        omega * omega * maxf(maximum, 0.001),
        0.001
    )
    result.roll_command = clampf(
        acceleration / command_scale,
        -1.0,
        1.0
    )
    return result
