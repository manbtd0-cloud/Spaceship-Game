# AI-Assisted Flight and Smart Stabilize Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a physically bounded third flight mode, **AI Assisted**, and a universal hold-`X` **Smart Stabilize** function without changing existing Assisted, Inertial, weapon, camera, pause, projectile, or exact-thruster behavior.

**Architecture:** Keep `ShipFlightController` as the sole runtime movement owner. Add two stateless pure solvers that return typed local-space assist force and torque, then compose their output through the existing `FlightOutput` assistance channels. Extend the existing input, settings, HUD, pause-menu, and room-coordinator paths rather than creating parallel state or controllers.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, dependency-free headless test harness, PowerShell verifier on Windows.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Active branch: `agent/playable-flight-room`.
- Engine: Godot `4.7.1.stable` with GL Compatibility.
- Preserve enum compatibility exactly: `ASSISTED = 0`, `MANUAL = 1`, `AI_ASSISTED = 2`.
- Player-facing `MANUAL` copy remains `INERTIAL` everywhere.
- Physical `F` cycles exactly `ASSISTED -> AI ASSISTED -> INERTIAL -> ASSISTED` through explicit logic, never enum ordinal arithmetic.
- Physical `X` uniquely owns `smart_stabilize`; activation is hold-to-use.
- Existing Assisted and Inertial physics must remain unchanged when Smart Stabilize is inactive.
- No direct transform assignment, direct velocity assignment, fake damping, teleporting, second physics body, duplicate controller, or runtime thruster allocator.
- Keep one player body, one input source, one flight controller, one primary-fire controller, and one projectile pool.
- Reuse `FlightOutput.assist_force_local` and `assist_torque_local` so exact checked-in thruster mappings remain authoritative.
- Primary fire remains available while Smart Stabilize is held.
- Do not alter camera behavior, projectile speed/visuals, muzzle transforms, boost thermals, speed envelopes, or existing input ownership.
- No GitHub Actions. Use local Windows verification only.
- Preserve unrelated and untracked local work.
- Workflow: one consolidated RED per task, one complete implementation pass, one focused task commit, and one final authoritative verifier.

---

## File Structure

### New production files

- `src/flight/flight_assist_output.gd` — typed force/torque result shared by both pure solvers.
- `src/flight/ai_flight_intent_solver.gd` — stateless AI trajectory and attitude assistance.
- `src/flight/smart_stabilize_solver.gd` — stateless emergency angular arrest and progressive linear braking.

### New test files

- `tests/unit/test_ai_flight_intent_solver.gd` — all pure AI solver contracts in one suite.
- `tests/unit/test_smart_stabilize_solver.gd` — all pure Smart Stabilize contracts in one suite.
- `tests/integration/test_ai_assisted_flight_controller.gd` — real player/controller/input integration, mode switching, stabilization priority, reset, and non-duplication.

### Existing production files to modify

- `src/flight/flight_mode.gd`
- `src/player/ship_flight_state.gd`
- `src/input/player_input_source.gd`
- `src/flight/flight_tuning.gd`
- `config/flight/player_flight_tuning.tres`
- `src/flight/flight_model.gd`
- `src/player/ship_flight_controller.gd`
- `src/settings/player_settings_service.gd`
- `src/flight_room/flight_room_settings_coordinator.gd` only if test evidence exposes a typed forwarding defect; otherwise leave production code unchanged.
- `src/ui/flight_hud.gd`
- `src/ui/pause_menu.gd`
- `project.godot`
- `README.md`
- `docs/superpowers/plans/deferred-milestones.md`

### Existing tests to modify

- `tests/unit/test_ship_flight_state.gd`
- `tests/unit/test_ship_flight_controller_state.gd`
- `tests/unit/test_flight_model.gd`
- `tests/unit/test_player_settings_service.gd`
- `tests/integration/test_input_map.gd`
- `tests/integration/test_flight_room_settings_coordinator.gd`
- `tests/integration/test_pause_and_flight_room_milestone.gd`
- `tests/integration/test_player_scene.gd`
- `tests/integration/test_ship_thruster_visual_controller.gd`
- `tests/test_runner.gd`

---

### Task 1: Lock compatibility, mode cycle, input ownership, and persisted values

**Files:**
- Modify: `src/flight/flight_mode.gd`
- Modify: `src/player/ship_flight_state.gd`
- Modify: `src/input/player_input_source.gd`
- Modify: `src/settings/player_settings_service.gd`
- Modify: `project.godot`
- Test: `tests/unit/test_ship_flight_state.gd`
- Test: `tests/unit/test_player_settings_service.gd`
- Test: `tests/integration/test_input_map.gd`

**Interfaces:**
- Produces: `FlightMode.Value.AI_ASSISTED = 2`.
- Produces: `ShipFlightState.toggled_mode(mode: FlightMode.Value) -> FlightMode.Value` with explicit three-mode order.
- Produces: `PlayerInputSource.is_smart_stabilize_held() -> bool`.
- Produces: settings acceptance and persistence of all three compatible values.
- Consumes: existing `toggle_flight_mode`, `PlayerSettingsStore`, and input ownership helpers.

- [ ] **Step 1: Write one consolidated compatibility RED**

Update `tests/unit/test_ship_flight_state.gd` with exact numeric and cycle assertions:

```gdscript
assert_equal(FlightMode.Value.ASSISTED, 0, "Assisted persisted value must remain 0")
assert_equal(FlightMode.Value.MANUAL, 1, "Inertial persisted value must remain 1")
assert_equal(FlightMode.Value.AI_ASSISTED, 2, "AI Assisted must append at value 2")
assert_equal(
    ShipFlightState.toggled_mode(FlightMode.Value.ASSISTED),
    FlightMode.Value.AI_ASSISTED,
    "Assisted must cycle to AI Assisted"
)
assert_equal(
    ShipFlightState.toggled_mode(FlightMode.Value.AI_ASSISTED),
    FlightMode.Value.MANUAL,
    "AI Assisted must cycle to Inertial"
)
assert_equal(
    ShipFlightState.toggled_mode(FlightMode.Value.MANUAL),
    FlightMode.Value.ASSISTED,
    "Inertial must cycle to Assisted"
)
```

Update `tests/integration/test_input_map.gd`:

```gdscript
assert_true(InputMap.has_action(&"smart_stabilize"), "smart_stabilize action required")
assert_true(
    _action_has_physical_key(&"smart_stabilize", KEY_X),
    "physical X must hold Smart Stabilize"
)
assert_true(
    &"smart_stabilize" in PlayerInputSource.REQUIRED_ACTIONS,
    "ship input source must own Smart Stabilize"
)
var x_owners := 0
for action: StringName in InputMap.get_actions():
    if _action_has_physical_key(action, KEY_X):
        x_owners += 1
assert_equal(x_owners, 1, "physical X must belong only to smart_stabilize")

var fixture := Node.new()
var source := PlayerInputSource.new()
fixture.add_child(source)
(Engine.get_main_loop() as SceneTree).root.add_child(fixture)
Input.action_press(&"smart_stabilize")
assert_true(source.is_smart_stabilize_held(), "held X state must be exposed")
Input.action_release(&"smart_stabilize")
assert_true(not source.is_smart_stabilize_held(), "release must clear held state")
fixture.get_parent().remove_child(fixture)
fixture.free()
```

Extend `tests/unit/test_player_settings_service.gd` to save/load `AI_ASSISTED`, then separately load raw old values `0` and `1` and confirm their meaning remains unchanged. Also assert `999` is rejected without changing the current value.

- [ ] **Step 2: Run the consolidated RED once**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected failures are limited to missing `AI_ASSISTED`, wrong two-mode cycle, missing `smart_stabilize`, missing held-state method, and settings rejecting value `2`. Parser errors are not acceptable.

- [ ] **Step 3: Implement compatibility without ordinal arithmetic**

Replace `src/flight/flight_mode.gd` with:

```gdscript
class_name FlightMode
extends RefCounted

enum Value {
    ASSISTED = 0,
    MANUAL = 1,
    AI_ASSISTED = 2,
}

static func is_valid(value: int) -> bool:
    return (
        value == Value.ASSISTED
        or value == Value.MANUAL
        or value == Value.AI_ASSISTED
    )
```

Replace the mode cycle in `src/player/ship_flight_state.gd`:

```gdscript
static func toggled_mode(mode: FlightMode.Value) -> FlightMode.Value:
    match mode:
        FlightMode.Value.ASSISTED:
            return FlightMode.Value.AI_ASSISTED
        FlightMode.Value.AI_ASSISTED:
            return FlightMode.Value.MANUAL
        FlightMode.Value.MANUAL:
            return FlightMode.Value.ASSISTED
        _:
            return FlightMode.Value.ASSISTED
```

Add `&"smart_stabilize"` to `PlayerInputSource.REQUIRED_ACTIONS` and add:

```gdscript
func is_smart_stabilize_held() -> bool:
    return _strength(&"smart_stabilize") > 0.0
```

Add this exact action to `project.godot`:

```ini
smart_stabilize={
"deadzone": 0.15,
"events": [Object(InputEventKey,"physical_keycode":88)]
}
```

Replace `PlayerSettingsStore._is_valid_flight_mode()` with:

```gdscript
func _is_valid_flight_mode(value: int) -> bool:
    return FlightMode.is_valid(value)
```

- [ ] **Step 4: Re-run the test runner once**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all existing suites pass. Suite count remains `34` because no new suites are registered yet.

- [ ] **Step 5: Commit the compatibility batch**

```powershell
git add project.godot src/flight/flight_mode.gd src/player/ship_flight_state.gd src/input/player_input_source.gd src/settings/player_settings_service.gd tests/unit/test_ship_flight_state.gd tests/unit/test_player_settings_service.gd tests/integration/test_input_map.gd
git commit -m "feat: add AI flight mode and stabilize input contract"
```

---

### Task 2: Add pure bounded AI and Smart Stabilize solvers

**Files:**
- Create: `src/flight/flight_assist_output.gd`
- Create: `src/flight/ai_flight_intent_solver.gd`
- Create: `src/flight/smart_stabilize_solver.gd`
- Modify: `src/flight/flight_tuning.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Create test: `tests/unit/test_ai_flight_intent_solver.gd`
- Create test: `tests/unit/test_smart_stabilize_solver.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `FlightAssistOutput` with `force_local: Vector3`, `torque_local: Vector3`, and `is_finite() -> bool`.
- Produces: `AiFlightIntentSolver.compute(command: FlightCommand, local_linear_velocity: Vector3, local_angular_velocity: Vector3, body_mass: float, tuning: FlightTuning) -> FlightAssistOutput`.
- Produces: `SmartStabilizeSolver.compute(local_linear_velocity: Vector3, local_angular_velocity: Vector3, body_mass: float, tuning: FlightTuning) -> FlightAssistOutput`.
- Consumes: compatible `FlightMode`, `FlightCommand`, body mass, and new `FlightTuning` fields.

- [ ] **Step 1: Register two suites and write one broad pure-solver RED**

Add to `tests/test_runner.gd` immediately after `test_flight_model.gd`:

```gdscript
"res://tests/unit/test_ai_flight_intent_solver.gd",
"res://tests/unit/test_smart_stabilize_solver.gd",
```

`tests/unit/test_ai_flight_intent_solver.gd` must assert in one suite:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := _tuning()
    var command := FlightCommand.new()
    command.mode = FlightMode.Value.AI_ASSISTED
    command.rotation.y = 0.7

    var turn := AiFlightIntentSolver.compute(
        command,
        Vector3(24.0, -8.0, -80.0),
        Vector3(0.3, -0.5, 0.2),
        8500.0,
        tuning
    )
    assert_true(turn.force_local.x < 0.0, "AI must bend lateral drift toward nose")
    assert_true(turn.force_local.y > 0.0, "AI must bend vertical drift toward nose")
    assert_true(turn.torque_local.x < 0.0, "AI must damp uncommanded pitch rate")
    assert_true(absf(turn.torque_local.y) < tuning.yaw_torque, "explicit yaw must retain authority")
    assert_true(turn.is_finite(), "AI output must remain finite")
    assert_true(
        Vector2(turn.force_local.x, turn.force_local.y).length()
        <= 8500.0 * tuning.ai_max_steering_acceleration + 0.01,
        "AI steering force must remain bounded"
    )

    var coast := FlightCommand.new()
    coast.mode = FlightMode.Value.AI_ASSISTED
    var coast_output := AiFlightIntentSolver.compute(
        coast,
        Vector3(24.0, -8.0, -80.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_equal(coast_output.force_local, Vector3.ZERO, "AI coasting preserves deliberate drift")

    command.translation.x = 1.0
    var protected_strafe := AiFlightIntentSolver.compute(
        command,
        Vector3(24.0, 0.0, -80.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_true(
        protected_strafe.force_local.x >= -8500.0 * tuning.ai_max_steering_acceleration * 0.11,
        "explicit strafe must not be opposed materially"
    )

    var backward := FlightCommand.new()
    backward.mode = FlightMode.Value.AI_ASSISTED
    backward.translation = Vector3.FORWARD
    var braking := AiFlightIntentSolver.compute(
        backward,
        Vector3(0.0, 0.0, 70.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_true(braking.force_local.z < 0.0, "forward intent while moving backward must brake")
    assert_true(
        absf(braking.force_local.z)
        <= 8500.0 * tuning.ai_max_braking_acceleration + 0.01,
        "AI braking must remain capped"
    )

    var malformed := AiFlightIntentSolver.compute(
        command,
        Vector3(NAN, 0.0, 0.0),
        Vector3.ZERO,
        8500.0,
        tuning
    )
    assert_equal(malformed.force_local, Vector3.ZERO, "non-finite AI input returns zero force")
    assert_equal(malformed.torque_local, Vector3.ZERO, "non-finite AI input returns zero torque")

func _tuning() -> FlightTuning:
    var tuning := FlightTuning.new()
    tuning.ai_angular_damping = 42000.0
    tuning.ai_rotation_command_protection = 0.90
    tuning.ai_trajectory_alignment_gain = 1.60
    tuning.ai_min_alignment_speed = 6.0
    tuning.ai_max_steering_acceleration = 20.0
    tuning.ai_translation_command_protection = 0.90
    tuning.ai_max_braking_acceleration = 10.0
    tuning.pitch_torque = 52000.0
    tuning.yaw_torque = 48000.0
    tuning.roll_torque = 60000.0
    tuning.normal_speed_limit = 160.0
    tuning.boost_speed_limit = 240.0
    return tuning
```

`tests/unit/test_smart_stabilize_solver.gd` must cover immediate counter-torque, no linear braking above 15 degrees/second, full braking below 5 degrees/second, near-rest zero output, finite bounds, and no mutation of a mode value passed separately by the test fixture.

- [ ] **Step 2: Run one solver RED**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: exactly the two new suites fail because the solver/output classes and tuning fields do not exist. Existing 34 suites must still load without new failures.

- [ ] **Step 3: Add the typed shared output**

Create `src/flight/flight_assist_output.gd`:

```gdscript
class_name FlightAssistOutput
extends RefCounted

var force_local: Vector3 = Vector3.ZERO
var torque_local: Vector3 = Vector3.ZERO

func is_finite() -> bool:
    return force_local.is_finite() and torque_local.is_finite()
```

- [ ] **Step 4: Add exact tuning fields and checked-in values**

Append to `src/flight/flight_tuning.gd`:

```gdscript
@export var ai_angular_damping: float = 42000.0
@export_range(0.0, 1.0) var ai_rotation_command_protection: float = 0.90
@export var ai_trajectory_alignment_gain: float = 1.60
@export var ai_min_alignment_speed: float = 6.0
@export var ai_max_steering_acceleration: float = 20.0
@export_range(0.0, 1.0) var ai_translation_command_protection: float = 0.90
@export var ai_max_braking_acceleration: float = 10.0

@export var stabilize_angular_damping: float = 70000.0
@export var stabilize_max_linear_deceleration: float = 22.0
@export var stabilize_linear_rest_threshold: float = 0.25
@export var stabilize_full_braking_below_degrees: float = 5.0
@export var stabilize_no_braking_above_degrees: float = 15.0
@export var stabilize_angular_rest_threshold_degrees: float = 0.5
```

Add the same values to `config/flight/player_flight_tuning.tres`.

- [ ] **Step 5: Implement the pure AI solver**

Create `src/flight/ai_flight_intent_solver.gd` with this public method and helpers:

```gdscript
class_name AiFlightIntentSolver
extends RefCounted

const INTENT_THRESHOLD := 0.08
const REVERSE_BRAKE_ANGLE_DEGREES := 100.0

static func compute(
    command: FlightCommand,
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    body_mass: float,
    tuning: FlightTuning
) -> FlightAssistOutput:
    var output := FlightAssistOutput.new()
    if (
        command == null
        or tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
        or not is_finite(body_mass)
        or body_mass <= 0.0
    ):
        return output

    output.torque_local = _attitude_torque(
        command.rotation,
        local_angular_velocity,
        tuning
    )

    var speed := local_linear_velocity.length()
    var turn_intent := maxf(absf(command.rotation.x), absf(command.rotation.y))
    var forward_intent := clampf(-command.translation.z, 0.0, 1.0)
    var alignment_demand := maxf(turn_intent, forward_intent)
    if speed >= tuning.ai_min_alignment_speed and alignment_demand > INTENT_THRESHOLD:
        var acceleration := Vector3(
            -local_linear_velocity.x,
            -local_linear_velocity.y,
            0.0
        ) * tuning.ai_trajectory_alignment_gain * alignment_demand
        acceleration.x *= 1.0 - clampf(
            absf(command.translation.x) * tuning.ai_translation_command_protection,
            0.0,
            1.0
        )
        acceleration.y *= 1.0 - clampf(
            absf(command.translation.y) * tuning.ai_translation_command_protection,
            0.0,
            1.0
        )
        acceleration = acceleration.limit_length(
            maxf(tuning.ai_max_steering_acceleration, 0.0)
        )
        output.force_local += acceleration * body_mass

    var active_limit := (
        tuning.boost_speed_limit
        if command.boost > 0.0
        else tuning.normal_speed_limit
    )
    var moving_direction := (
        local_linear_velocity.normalized()
        if speed > 0.000001
        else Vector3.ZERO
    )
    var opposite_forward := (
        speed > 0.000001
        and moving_direction.dot(Vector3.FORWARD)
        < cos(deg_to_rad(REVERSE_BRAKE_ANGLE_DEGREES))
    )
    if speed > active_limit or (forward_intent > INTENT_THRESHOLD and opposite_forward):
        var longitudinal_acceleration := -signf(local_linear_velocity.z) * minf(
            absf(local_linear_velocity.z),
            maxf(tuning.ai_max_braking_acceleration, 0.0)
        )
        output.force_local.z += longitudinal_acceleration * body_mass

    if not output.is_finite():
        return FlightAssistOutput.new()
    return output

static func _attitude_torque(
    rotation_command: Vector3,
    local_angular_velocity: Vector3,
    tuning: FlightTuning
) -> Vector3:
    var raw := -local_angular_velocity * tuning.ai_angular_damping
    var protection := Vector3(
        1.0 - clampf(absf(rotation_command.x) * tuning.ai_rotation_command_protection, 0.0, 1.0),
        1.0 - clampf(absf(rotation_command.y) * tuning.ai_rotation_command_protection, 0.0, 1.0),
        1.0 - clampf(absf(rotation_command.z) * tuning.ai_rotation_command_protection, 0.0, 1.0)
    )
    return Vector3(
        clampf(raw.x * protection.x, -tuning.pitch_torque, tuning.pitch_torque),
        clampf(raw.y * protection.y, -tuning.yaw_torque, tuning.yaw_torque),
        clampf(raw.z * protection.z, -tuning.roll_torque, tuning.roll_torque)
    )
```

- [ ] **Step 6: Implement the pure Smart Stabilize solver**

Create `src/flight/smart_stabilize_solver.gd`:

```gdscript
class_name SmartStabilizeSolver
extends RefCounted

static func compute(
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    body_mass: float,
    tuning: FlightTuning
) -> FlightAssistOutput:
    var output := FlightAssistOutput.new()
    if (
        tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
        or not is_finite(body_mass)
        or body_mass <= 0.0
    ):
        return output

    var raw_torque := -local_angular_velocity * tuning.stabilize_angular_damping
    output.torque_local = Vector3(
        clampf(raw_torque.x, -tuning.pitch_torque, tuning.pitch_torque),
        clampf(raw_torque.y, -tuning.yaw_torque, tuning.yaw_torque),
        clampf(raw_torque.z, -tuning.roll_torque, tuning.roll_torque)
    )

    var angular_speed_degrees := rad_to_deg(local_angular_velocity.length())
    var braking_weight := clampf(
        inverse_lerp(
            tuning.stabilize_no_braking_above_degrees,
            tuning.stabilize_full_braking_below_degrees,
            angular_speed_degrees
        ),
        0.0,
        1.0
    )
    var linear_speed := local_linear_velocity.length()
    if linear_speed > tuning.stabilize_linear_rest_threshold and braking_weight > 0.0:
        var deceleration := minf(
            linear_speed,
            maxf(tuning.stabilize_max_linear_deceleration, 0.0)
        )
        output.force_local = (
            -local_linear_velocity.normalized()
            * deceleration
            * braking_weight
            * body_mass
        )

    if not output.is_finite():
        return FlightAssistOutput.new()
    return output
```

- [ ] **Step 7: Run the full test runner once**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 36 suites`.

- [ ] **Step 8: Commit the pure-solver batch**

```powershell
git add src/flight/flight_assist_output.gd src/flight/ai_flight_intent_solver.gd src/flight/smart_stabilize_solver.gd src/flight/flight_tuning.gd config/flight/player_flight_tuning.tres tests/unit/test_ai_flight_intent_solver.gd tests/unit/test_smart_stabilize_solver.gd tests/test_runner.gd
git commit -m "feat: add bounded AI and stabilize solvers"
```

---

### Task 3: Integrate AI Assisted and Smart Stabilize into the sole flight controller

**Files:**
- Modify: `src/flight/flight_model.gd`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_flight_model.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`
- Create test: `tests/integration/test_ai_assisted_flight_controller.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `AiFlightIntentSolver.compute(...)` and `SmartStabilizeSolver.compute(...)` from Task 2.
- Produces: `ShipFlightController.is_smart_stabilizing() -> bool`.
- Produces: three-mode `set_flight_mode(value)` validation and deterministic state clearing.
- Preserves: current `FlightModel.compute(...)` behavior for Assisted and Manual/Inertial.

- [ ] **Step 1: Write one controller-integration RED**

Register:

```gdscript
"res://tests/integration/test_ai_assisted_flight_controller.gd",
```

The new suite must instantiate the real `player_interceptor.tscn`, add it to the test tree, and assert:

```gdscript
var controller := player.get_node("ShipFlightController") as ShipFlightController
var source := player.get_node("PlayerInputSource") as PlayerInputSource

assert_true(controller.set_flight_mode(FlightMode.Value.AI_ASSISTED), "AI mode accepted")
assert_equal(controller.get_flight_mode(), FlightMode.Value.AI_ASSISTED, "AI mode selected")

player.linear_velocity = Vector3(20.0, -6.0, -80.0)
player.angular_velocity = Vector3(0.4, -0.5, 0.2)
Input.action_press(&"yaw_right")
controller._physics_process(1.0 / 60.0)
Input.action_release(&"yaw_right")
assert_true(controller.get_last_assist_force_local().length() > 0.0, "AI turn adds assist force")
assert_true(controller.get_last_assist_torque_local().length() > 0.0, "AI adds damping torque")

var selected_mode := controller.get_flight_mode()
Input.action_press(&"smart_stabilize")
controller._physics_process(1.0 / 60.0)
assert_true(controller.is_smart_stabilizing(), "held X activates stabilization")
assert_equal(controller.get_flight_mode(), selected_mode, "stabilization does not change mode")
assert_equal(controller.get_last_pilot_force_local(), Vector3.ZERO, "stabilization suppresses pilot force")
assert_equal(controller.get_last_pilot_torque_local(), Vector3.ZERO, "stabilization suppresses pilot torque")
Input.action_release(&"smart_stabilize")
controller._physics_process(1.0 / 60.0)
assert_true(not controller.is_smart_stabilizing(), "release returns ordinary control")

controller.reset_runtime_state()
assert_true(not controller.is_smart_stabilizing(), "reset clears stabilization state")
```

Extend `test_ship_flight_controller_state.gd` to assert AI is valid, invalid modes remain rejected, mode changes emit once, and switching modes clears stabilization state without changing body velocity. Extend `test_flight_model.gd` with an AI command and assert the base model creates pilot output but no built-in Assisted correction, because the dedicated solver owns AI assistance.

- [ ] **Step 2: Run the integration RED once**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected failures are limited to controller rejection of AI mode, missing stabilization getter/integration, and AI output not yet composed. Existing Assisted/Inertial assertions must remain green.

- [ ] **Step 3: Keep `FlightModel` behavior explicit**

Leave its Assisted branch unchanged. Do not add AI behavior inside that branch. The existing condition remains:

```gdscript
if command.mode == FlightMode.Value.ASSISTED:
    # existing steering, auto-bank, and angular damping unchanged
```

Add a test comment and assertion proving `AI_ASSISTED` receives pilot force/torque only from `FlightModel`; automatic AI output is composed by the controller.

- [ ] **Step 4: Compose exactly one automatic-assist path in `ShipFlightController`**

Add state:

```gdscript
var _smart_stabilizing := false
```

After `FlightModel.compute(...)`, replace the assistance composition with:

```gdscript
_smart_stabilizing = _input_source.is_smart_stabilize_held()
if _smart_stabilizing:
    var stabilize := SmartStabilizeSolver.compute(
        local_linear,
        local_angular,
        _body.mass,
        tuning
    )
    output.pilot_force_local = Vector3.ZERO
    output.pilot_torque_local = Vector3.ZERO
    output.assist_force_local = stabilize.force_local
    output.assist_torque_local = stabilize.torque_local
elif command.mode == FlightMode.Value.AI_ASSISTED:
    var ai_assist := AiFlightIntentSolver.compute(
        command,
        local_linear,
        local_angular,
        _body.mass,
        tuning
    )
    output.assist_force_local = ai_assist.force_local
    output.assist_torque_local = ai_assist.torque_local

output.finalize_totals()
```

Do not call either solver twice in one tick. Do not add direct `linear_velocity`, `angular_velocity`, or transform assignments.

Update mode validation:

```gdscript
if not FlightMode.is_valid(value):
    return false
```

On a real mode change, clear only transient controller state:

```gdscript
_auto_bank_offset = 0.0
_auto_bank_rate = 0.0
_smart_stabilizing = false
```

Add:

```gdscript
func is_smart_stabilizing() -> bool:
    return _smart_stabilizing
```

Add `_smart_stabilizing = false` to `reset_runtime_state()`.

- [ ] **Step 5: Verify force telemetry and exact-thruster compatibility**

Extend `tests/integration/test_ship_thruster_visual_controller.gd` to feed AI/stabilize values through the controller’s existing assist telemetry and assert the existing 35-percent assisted visual cap still applies. Do not add sockets, mappings, or a new visual controller.

- [ ] **Step 6: Run the test runner once**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 37 suites`.

- [ ] **Step 7: Run the dedicated inertial verifier immediately**

Run:

```powershell
godot --headless --path . --script res://tests/verify_inertial_velocity.gd
```

Expected:

```text
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
```

- [ ] **Step 8: Commit the controller batch**

```powershell
git add src/flight/flight_model.gd src/player/ship_flight_controller.gd tests/unit/test_flight_model.gd tests/unit/test_ship_flight_controller_state.gd tests/integration/test_ai_assisted_flight_controller.gd tests/integration/test_ship_thruster_visual_controller.gd tests/test_runner.gd
git commit -m "feat: integrate AI flight and Smart Stabilize"
```

---

### Task 4: Integrate settings, pause menu, HUD, help copy, and live room behavior

**Files:**
- Modify: `src/ui/pause_menu.gd`
- Modify: `src/ui/flight_hud.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`
- Modify: `tests/unit/test_player_settings_service.gd`
- Modify: `tests/integration/test_flight_room_settings_coordinator.gd`
- Modify: `tests/integration/test_pause_and_flight_room_milestone.gd`
- Modify: `tests/integration/test_player_scene.gd`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/deferred-milestones.md`

**Interfaces:**
- Consumes: all three valid flight modes and `ShipFlightController.is_smart_stabilizing()`.
- Produces: exact HUD strings and exact pause-menu item order.
- Preserves: the existing coordinator as the sole settings-to-runtime adapter.

- [ ] **Step 1: Write one UI/settings integration RED**

Extend `test_ship_flight_controller_state.gd`:

```gdscript
assert_equal(
    FlightHud.mode_text_for(FlightMode.Value.AI_ASSISTED),
    "MODE   AI ASSISTED",
    "AI HUD copy must be exact"
)
assert_equal(
    FlightHud.mode_text_for(FlightMode.Value.MANUAL),
    "MODE   INERTIAL",
    "internal Manual remains player-facing Inertial"
)
```

Extend `test_pause_and_flight_room_milestone.gd` to inspect the real option button after initialization:

```gdscript
assert_equal(mode_option.item_count, 3, "pause menu must expose exactly three modes")
assert_equal(mode_option.get_item_text(0), "Assisted", "first mode label")
assert_equal(mode_option.get_item_id(0), FlightMode.Value.ASSISTED, "first mode id")
assert_equal(mode_option.get_item_text(1), "AI Assisted", "second mode label")
assert_equal(mode_option.get_item_id(1), FlightMode.Value.AI_ASSISTED, "second mode id")
assert_equal(mode_option.get_item_text(2), "Inertial", "third mode label")
assert_equal(mode_option.get_item_id(2), FlightMode.Value.MANUAL, "third mode id")
```

Emit selection of `AI_ASSISTED`, assert only the flight setting changes, reload the store from disk, and assert it persists. Extend coordinator integration to set `AI_ASSISTED` and require the existing controller to receive it once without duplicated signal connections.

Extend `test_player_scene.gd` to keep ownership counts exactly one and assert no extra controller/body/input/fire/pool nodes were introduced.

- [ ] **Step 2: Run one UI/settings RED**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected failures are limited to missing AI pause item and HUD text/status. Persistence and coordinator failures must be specific to value `2`, not existing values.

- [ ] **Step 3: Add the exact pause-menu order**

In `PauseMenu._populate_options()` replace the flight-mode population with:

```gdscript
_flight_mode_option.clear()
_flight_mode_option.add_item("Assisted", FlightMode.Value.ASSISTED)
_flight_mode_option.add_item("AI Assisted", FlightMode.Value.AI_ASSISTED)
_flight_mode_option.add_item("Inertial", FlightMode.Value.MANUAL)
```

Keep `_on_flight_mode_selected()` writing only through `PlayerSettingsStore.set_default_flight_mode()`.

- [ ] **Step 4: Add exact HUD text and stabilization status**

Replace `FlightHud.mode_text_for()` with:

```gdscript
static func mode_text_for(mode: FlightMode.Value) -> String:
    match mode:
        FlightMode.Value.ASSISTED:
            return "MODE   ASSISTED"
        FlightMode.Value.AI_ASSISTED:
            return "MODE   AI ASSISTED"
        FlightMode.Value.MANUAL:
            return "MODE   INERTIAL"
        _:
            return "MODE   ASSISTED"
```

In `_refresh_labels()`:

```gdscript
_mode_label.text = mode_text_for(_controller.get_flight_mode())
if _controller.is_smart_stabilizing():
    _mode_label.text += "   |   STABILIZING"
```

Add `X STABILIZE` to the existing controls string without removing any established control copy.

- [ ] **Step 5: Confirm coordinator remains unchanged unless evidence requires a fix**

The coordinator already forwards typed values through `set_flight_mode(value)`. If the extended test passes, do not modify `src/flight_room/flight_room_settings_coordinator.gd`. If it fails, fix only the evidenced forwarding defect and preserve signal idempotence.

- [ ] **Step 6: Update player documentation and wait-list status**

Update `README.md` controls:

```text
F       cycle Assisted / AI Assisted / Inertial
X       hold Smart Stabilize
```

Document that AI Assisted bends actual trajectory through bounded force, Smart Stabilize arrests rotation before braking, and both use real physics. Mark the AI-Assisted/Smart-Stabilize wait-list milestone as `implementation in progress` during execution; change it to `verified` only after Task 5 passes.

- [ ] **Step 7: Run the test runner once**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 37 suites` with no orphan nodes or retained resources.

- [ ] **Step 8: Commit the UI/settings batch**

```powershell
git add src/ui/pause_menu.gd src/ui/flight_hud.gd tests/unit/test_ship_flight_controller_state.gd tests/unit/test_player_settings_service.gd tests/integration/test_flight_room_settings_coordinator.gd tests/integration/test_pause_and_flight_room_milestone.gd tests/integration/test_player_scene.gd README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "feat: expose AI flight controls and settings"
```

---

### Task 5: Full regression gate and one-session Windows acceptance

**Files:**
- Modify only if verification exposes an evidenced defect.
- Finalize: `README.md`
- Finalize: `docs/superpowers/plans/deferred-milestones.md`

**Interfaces:**
- Consumes: complete Tasks 1–4.
- Produces: one fully verified milestone with exact test evidence and manual acceptance.

- [ ] **Step 1: Run the authoritative verifier once**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify\verify.ps1
```

Required output:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 37 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
==> Boot main scene briefly
```

No parser error, runtime error, orphan node, retained resource, or post-boot error is acceptable.

- [ ] **Step 2: If the verifier fails, use evidence-driven debugging only**

Read the first failing stack trace completely. Fix the root cause in the smallest affected boundary. Do not weaken assertions, remove existing tests, alter expected physics, or add duplicate runtime systems. Re-run the full verifier only after the focused failing suite is green.

- [ ] **Step 3: Run one Windows manual acceptance session**

Launch:

```powershell
godot --path .
```

Verify all ten checks in one run:

1. `F` cycles Assisted -> AI Assisted -> Inertial -> Assisted.
2. In AI Assisted, build forward speed and pitch/yaw; the velocity marker bends progressively toward the nose reticle.
3. Release rotational input; unwanted spin settles progressively.
4. Coast without turn or forward input; deliberate drift is preserved.
5. Hold `X` while spinning; rotation is arrested before strong linear braking.
6. Continue holding `X`; speed falls progressively without a snap.
7. Release `X` mid-brake; control immediately returns to the selected mode.
8. Repeat Smart Stabilize in all three modes; selected mode never changes.
9. Persist AI Assisted through the pause menu, quit, relaunch, and confirm it reloads.
10. Confirm LMB/V firing, boost, `C`, `B`, PageUp, PageDown, pause/resume, restart, HUD vectors, collisions, and exact thruster visuals still work.

- [ ] **Step 4: Finalize milestone status only after both gates pass**

Update `docs/superpowers/plans/deferred-milestones.md`:

```text
AI-Assisted Flight Mode and Universal Smart Stabilize — VERIFIED
Automated gate: PASS: 37 suites
Inertial verifier: zero speed drift, zero direction drift
Windows manual acceptance: passed
```

Update the README runner target to `PASS: 37 suites` if not already updated.

- [ ] **Step 5: Commit the verified milestone closure**

```powershell
git add README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "docs: verify AI-assisted flight milestone"
```

- [ ] **Step 6: Review final branch scope**

Run:

```powershell
git status --short
git log --oneline -5
git diff --stat HEAD~5..HEAD
```

Expected: no unintended files, no GitHub workflow files, no raw asset changes, and only the four meaningful implementation commits plus the final documentation closure.
