# Full-Authority Flight Assistance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AI Assisted and hold-`X` Smart Stabilize use the ship's full legal player-equivalent thrust and torque authority while never exceeding direct-control limits.

**Architecture:** Add a pure `FlightAuthority` helper that converts normalized translation/rotation commands to legal force/torque and converts applied automatic force/torque back to direction-correct player-equivalent commands for thruster visuals. Both automatic solvers return normalized commands. `ShipFlightController` combines pilot and automatic commands before force generation, so pilot plus AI can never stack beyond one legal player command. Smart Stabilize suppresses pilot movement and uses one legal automatic command. Legacy Assisted visuals keep the `0.35` cap; AI Assisted and Smart Stabilize use their actual applied directional authority through the existing checked-in action matrix and may reach `1.0`.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, existing dependency-free test runner, Windows PowerShell verifier.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Verified baseline: `PASS: 37 suites`; inertial speed/direction drift exactly zero.
- Final target: `PASS: 38 suites`.
- Smart Stabilize may use full player-equivalent authority but never exceed it.
- Pilot plus AI output must fit one normalized translation command and one per-axis-clamped rotation command.
- Local `-Z` uses `forward_force`; local `+Z` uses `reverse_force`; X/Y use `strafe_force`.
- Combined translation is normalized to length `1.0`, exactly like `PlayerInputMath.compose_translation()`.
- Pitch, yaw and roll remain independently clamped to `[-1, 1]`.
- Boost is available to automatic control only when held and thermally available through `_boost_amount`.
- Smart Stabilize cancels translation and rotation simultaneously.
- AI Assisted continuously drives actual velocity toward ship-forward after rotation input is released.
- Existing Assisted and inactive Inertial behavior remains unchanged.
- No transform/velocity assignment, fake damping, second controller/body, runtime allocator, new thruster sockets, procedural exhaust, camera changes, combat changes or GitHub Actions.
- Preserve boost thermals, speed envelopes, exact muzzle transforms, projectiles, pause/settings/reset, schema-5 geometry and checked-in action matrix.

---

## File Map

### Create

- `src/flight/flight_authority.gd`
- `src/flight/flight_assist_command.gd`
- `src/flight/flight_assistance_source.gd`
- `tests/unit/test_flight_authority.gd`

### Modify

- `src/flight/flight_model.gd`
- `src/flight/ai_flight_intent_solver.gd`
- `src/flight/smart_stabilize_solver.gd`
- `src/flight/flight_tuning.gd`
- `config/flight/player_flight_tuning.tres`
- `src/player/ship_flight_controller.gd`
- `src/player/thruster_visual_math.gd`
- `src/player/ship_thruster_visual_controller.gd`
- `tests/test_runner.gd`
- `tests/unit/test_flight_model.gd`
- `tests/unit/test_ai_flight_intent_solver.gd`
- `tests/unit/test_smart_stabilize_solver.gd`
- `tests/unit/test_ship_flight_controller_state.gd`
- `tests/unit/test_thruster_visual_math.gd`
- `tests/integration/test_ai_assisted_flight_controller.gd`
- `tests/integration/test_ship_thruster_visual_controller.gd`
- `README.md`
- `docs/superpowers/plans/deferred-milestones.md`

---

### Task 1: One shared legal-authority contract

**Files:**
- Create: `src/flight/flight_authority.gd`
- Create: `src/flight/flight_assist_command.gd`
- Create: `src/flight/flight_assistance_source.gd`
- Create: `tests/unit/test_flight_authority.gd`
- Modify: `src/flight/flight_model.gd`
- Modify: `tests/unit/test_flight_model.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `FlightAuthority.sanitize_translation(value: Vector3) -> Vector3`.
- Produces `FlightAuthority.sanitize_rotation(value: Vector3) -> Vector3`.
- Produces `FlightAuthority.combine_translation(pilot: Vector3, automatic: Vector3) -> Vector3`.
- Produces `FlightAuthority.combine_rotation(pilot: Vector3, automatic: Vector3) -> Vector3`.
- Produces `FlightAuthority.translation_force(command: Vector3, effective_boost: float, tuning: FlightTuning) -> Vector3`.
- Produces `FlightAuthority.rotation_torque(command: Vector3, tuning: FlightTuning) -> Vector3`.
- Produces `FlightAuthority.translation_command_for_force(force: Vector3, effective_boost: float, tuning: FlightTuning) -> Vector3`.
- Produces `FlightAuthority.rotation_command_for_torque(torque: Vector3, tuning: FlightTuning) -> Vector3`.
- Produces `FlightAssistCommand` and `FlightAssistanceSource`.

- [ ] **Step 1: Register and write the authority RED**

Add after `test_flight_model.gd` in `tests/test_runner.gd`:

```gdscript
"res://tests/unit/test_flight_authority.gd",
```

Create `tests/unit/test_flight_authority.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.forward_force = 100.0
    tuning.reverse_force = 40.0
    tuning.strafe_force = 50.0
    tuning.pitch_torque = 10.0
    tuning.yaw_torque = 20.0
    tuning.roll_torque = 30.0
    tuning.boost_multiplier = 1.8

    assert_equal(
        FlightAuthority.translation_force(Vector3.FORWARD, 0.0, tuning),
        Vector3(0.0, 0.0, -100.0),
        "forward command uses exact forward authority"
    )
    assert_equal(
        FlightAuthority.translation_force(Vector3.BACK, 0.0, tuning),
        Vector3(0.0, 0.0, 40.0),
        "reverse command uses exact reverse authority"
    )
    assert_equal(
        FlightAuthority.translation_force(Vector3.RIGHT, 0.0, tuning),
        Vector3(50.0, 0.0, 0.0),
        "lateral command uses exact strafe authority"
    )
    assert_equal(
        FlightAuthority.rotation_torque(Vector3.ONE, tuning),
        Vector3(10.0, 20.0, 30.0),
        "rotation axes retain independent full authority"
    )

    var diagonal := FlightAuthority.combine_translation(
        Vector3.FORWARD,
        Vector3.RIGHT + Vector3.UP
    )
    assert_true(
        is_equal_approx(diagonal.length(), 1.0),
        "combined pilot and automatic translation normalizes to one"
    )
    assert_equal(
        FlightAuthority.combine_rotation(
            Vector3(0.8, 0.8, 0.8),
            Vector3(0.8, -0.8, 0.8)
        ),
        Vector3(1.0, 0.0, 1.0),
        "combined rotation clamps independently per axis"
    )

    var boosted_forward := FlightAuthority.translation_force(
        Vector3.FORWARD,
        1.0,
        tuning
    )
    assert_equal(
        boosted_forward,
        Vector3(0.0, 0.0, -180.0),
        "effective boost scales authority exactly like direct control"
    )

    for command: Vector3 in [
        Vector3.FORWARD,
        Vector3.BACK,
        Vector3.RIGHT,
        Vector3.UP,
        Vector3(0.3, -0.4, -0.5),
    ]:
        var legal := FlightAuthority.sanitize_translation(command)
        var force := FlightAuthority.translation_force(legal, 0.0, tuning)
        assert_true(
            FlightAuthority.translation_command_for_force(
                force,
                0.0,
                tuning
            ).is_equal_approx(legal),
            "legal force must invert to its direction-correct player command"
        )

    var torque_command := Vector3(-0.4, 0.6, -0.8)
    var torque := FlightAuthority.rotation_torque(torque_command, tuning)
    assert_true(
        FlightAuthority.rotation_command_for_torque(
            torque,
            tuning
        ).is_equal_approx(torque_command),
        "legal torque must invert to its player-equivalent command"
    )

    assert_equal(
        FlightAuthority.sanitize_translation(Vector3(NAN, 0.0, 0.0)),
        Vector3.ZERO,
        "non-finite translation fails closed"
    )
    assert_equal(
        FlightAuthority.sanitize_rotation(Vector3(0.0, INF, 0.0)),
        Vector3.ZERO,
        "non-finite rotation fails closed"
    )
    assert_true(
        is_equal_approx(
            FlightAssistanceSource.visual_cap_for(
                FlightAssistanceSource.Value.LEGACY_ASSISTED
            ),
            0.35
        ),
        "legacy Assisted retains its visual cap"
    )
    assert_true(
        is_equal_approx(
            FlightAssistanceSource.visual_cap_for(
                FlightAssistanceSource.Value.SMART_STABILIZE
            ),
            1.0
        ),
        "Smart Stabilize may show full legal output"
    )
```

- [ ] **Step 2: Run one RED**

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: new suite fails because the new classes do not exist; existing suites remain parseable.

- [ ] **Step 3: Create the typed command and source**

`src/flight/flight_assist_command.gd`:

```gdscript
class_name FlightAssistCommand
extends RefCounted

var translation: Vector3 = Vector3.ZERO
var rotation: Vector3 = Vector3.ZERO

func is_finite() -> bool:
    return translation.is_finite() and rotation.is_finite()
```

`src/flight/flight_assistance_source.gd`:

```gdscript
class_name FlightAssistanceSource
extends RefCounted

enum Value {
    NONE,
    LEGACY_ASSISTED,
    AI_ASSISTED,
    SMART_STABILIZE,
}

static func visual_cap_for(value: Value) -> float:
    match value:
        Value.LEGACY_ASSISTED:
            return 0.35
        Value.AI_ASSISTED, Value.SMART_STABILIZE:
            return 1.0
        _:
            return 0.0
```

- [ ] **Step 4: Implement `FlightAuthority`**

```gdscript
class_name FlightAuthority
extends RefCounted

static func sanitize_translation(value: Vector3) -> Vector3:
    return value.limit_length(1.0) if value.is_finite() else Vector3.ZERO

static func sanitize_rotation(value: Vector3) -> Vector3:
    if not value.is_finite():
        return Vector3.ZERO
    return Vector3(
        clampf(value.x, -1.0, 1.0),
        clampf(value.y, -1.0, 1.0),
        clampf(value.z, -1.0, 1.0)
    )

static func combine_translation(
    pilot: Vector3,
    automatic: Vector3
) -> Vector3:
    return sanitize_translation(
        sanitize_translation(pilot) + sanitize_translation(automatic)
    )

static func combine_rotation(
    pilot: Vector3,
    automatic: Vector3
) -> Vector3:
    return sanitize_rotation(
        sanitize_rotation(pilot) + sanitize_rotation(automatic)
    )

static func translation_force(
    command: Vector3,
    effective_boost: float,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null:
        return Vector3.ZERO
    var legal := sanitize_translation(command)
    var z_authority := (
        tuning.forward_force if legal.z < 0.0 else tuning.reverse_force
    )
    var boost_scale := lerpf(
        1.0,
        tuning.boost_multiplier,
        clampf(effective_boost, 0.0, 1.0)
    )
    return Vector3(
        legal.x * tuning.strafe_force,
        legal.y * tuning.strafe_force,
        legal.z * z_authority
    ) * boost_scale

static func rotation_torque(
    command: Vector3,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null:
        return Vector3.ZERO
    var legal := sanitize_rotation(command)
    return Vector3(
        legal.x * tuning.pitch_torque,
        legal.y * tuning.yaw_torque,
        legal.z * tuning.roll_torque
    )

static func translation_command_for_force(
    force: Vector3,
    effective_boost: float,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null or not force.is_finite():
        return Vector3.ZERO
    var boost_scale := lerpf(
        1.0,
        tuning.boost_multiplier,
        clampf(effective_boost, 0.0, 1.0)
    )
    var x_reference := maxf(tuning.strafe_force * boost_scale, 0.000001)
    var y_reference := x_reference
    var z_reference := maxf(
        (tuning.forward_force if force.z < 0.0 else tuning.reverse_force)
        * boost_scale,
        0.000001
    )
    return sanitize_translation(Vector3(
        force.x / x_reference,
        force.y / y_reference,
        force.z / z_reference
    ))

static func rotation_command_for_torque(
    torque: Vector3,
    tuning: FlightTuning
) -> Vector3:
    if tuning == null or not torque.is_finite():
        return Vector3.ZERO
    return sanitize_rotation(Vector3(
        torque.x / maxf(tuning.pitch_torque, 0.000001),
        torque.y / maxf(tuning.yaw_torque, 0.000001),
        torque.z / maxf(tuning.roll_torque, 0.000001)
    ))
```

- [ ] **Step 5: Route direct pilot output through the helper**

In `FlightModel.compute()`, replace manual construction with:

```gdscript
var pilot_force := FlightAuthority.translation_force(
    command.translation,
    command.boost,
    tuning
)
output.pilot_force_local = FlightSpeedEnvelope.apply_to_force(
    pilot_force,
    local_linear_velocity,
    soft_start,
    soft_limit
)
output.pilot_torque_local = FlightAuthority.rotation_torque(
    command.rotation,
    tuning
)
```

Do not alter the existing legacy Assisted branch.

Add to `test_flight_model.gd`:

```gdscript
assert_equal(
    FlightAuthority.translation_force(
        all_axis_boost.translation,
        all_axis_boost.boost,
        tuning
    ),
    all_axis_output.pilot_force_local,
    "FlightModel and automatic authority share one force contract"
)
```

- [ ] **Step 6: Run and commit**

Expected: `PASS: 38 suites`.

```powershell
git add src/flight/flight_authority.gd src/flight/flight_assist_command.gd src/flight/flight_assistance_source.gd src/flight/flight_model.gd tests/unit/test_flight_authority.gd tests/unit/test_flight_model.gd tests/test_runner.gd
git commit -m "refactor: centralize legal flight authority"
```

---

### Task 2: Full-authority simultaneous Smart Stabilize

**Files:**
- Modify: `src/flight/smart_stabilize_solver.gd`
- Modify: `src/flight/flight_tuning.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_smart_stabilize_solver.gd`
- Modify: `tests/integration/test_ai_assisted_flight_controller.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`

**Interfaces:**
- Produces `SmartStabilizeSolver.compute(local_linear_velocity, local_angular_velocity, tuning) -> FlightAssistCommand`.
- Produces `ShipFlightController.get_assistance_source()`.

- [ ] **Step 1: Write the consolidated RED**

Replace `test_smart_stabilize_solver.gd` with tests that require:

```gdscript
var combined := SmartStabilizeSolver.compute(
    Vector3(30.0, -20.0, -80.0),
    Vector3(deg_to_rad(20.0), deg_to_rad(-20.0), deg_to_rad(20.0)),
    tuning
)
assert_true(combined.translation.x < 0.0, "right drift commands left thrust")
assert_true(combined.translation.y > 0.0, "down drift commands upward thrust")
assert_true(combined.translation.z > 0.0, "forward drift commands reverse thrust")
assert_true(
    is_equal_approx(combined.translation.length(), 1.0),
    "combined braking uses one normalized player envelope"
)
assert_equal(
    combined.rotation,
    Vector3(-1.0, 1.0, -1.0),
    "all rotational axes receive full legal counter-command"
)
```

Also require:

```gdscript
var simultaneous := SmartStabilizeSolver.compute(
    Vector3(50.0, 0.0, 0.0),
    Vector3(0.0, deg_to_rad(40.0), 0.0),
    tuning
)
assert_true(
    simultaneous.translation.length() > 0.99,
    "rotation must not delay linear braking"
)
assert_true(
    absf(simultaneous.rotation.y) > 0.99,
    "linear braking must not delay angular arrest"
)
```

Add taper/rest assertions at `2 m/s`, `4 deg/s`, `0.05 m/s`, and `0.1 deg/s`.

Extend the integration suite to assert Smart Stabilize:

```gdscript
assert_equal(
    controller.get_assistance_source(),
    FlightAssistanceSource.Value.SMART_STABILIZE,
    "Smart Stabilize exposes its assistance source"
)
assert_equal(
    controller.get_last_pilot_force_local(),
    Vector3.ZERO,
    "pilot force remains suppressed while stabilizing"
)
assert_equal(
    controller.get_last_pilot_torque_local(),
    Vector3.ZERO,
    "pilot torque remains suppressed while stabilizing"
)
assert_true(
    controller.get_last_assist_force_local().length() > 0.0,
    "linear braking starts immediately"
)
assert_true(
    controller.get_last_assist_torque_local().length() > 0.0,
    "angular counter-torque starts immediately"
)
```

Add `Shift + X` coverage proving output is no greater than the corresponding boosted player authority and that `_boost_amount` is non-zero only while thermally available.

- [ ] **Step 2: Run one RED**

Expected: old solver returns forces, delays braking, and controller erases boost before automatic control.

- [ ] **Step 3: Replace old stabilization tuning**

Remove the old damping/deceleration/braking-angle fields and add:

```gdscript
@export var stabilize_linear_capture_speed: float = 4.0
@export var stabilize_angular_capture_rate_degrees: float = 8.0
@export var stabilize_linear_rest_threshold: float = 0.10
@export var stabilize_angular_rest_threshold_degrees: float = 0.25
```

Apply identical values in `player_flight_tuning.tres`.

- [ ] **Step 4: Return normalized opposing commands**

Implement a pure `_opposing_axis(value, rest_threshold, full_threshold)` that returns zero inside rest, linearly tapers inside capture, and returns `-sign(value)` beyond capture. Build X/Y/Z translation simultaneously, normalize through `FlightAuthority.sanitize_translation`, and build pitch/yaw/roll independently through `sanitize_rotation`.

Required signature:

```gdscript
static func compute(
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    tuning: FlightTuning
) -> FlightAssistCommand
```

- [ ] **Step 5: Reorder controller data flow**

The physics tick must execute in this order:

```text
sample pilot command
resolve local linear/angular velocity
compute Smart/AI automatic command
compute boost activity from the actual combined automatic/pilot translation command
advance boost thermal state
set effective boost
run FlightModel for pilot output
compose legal automatic total
finalize/apply force and torque
store telemetry/source
```

For Smart Stabilize:

```gdscript
var physics_command := pilot_command.duplicate_command()
physics_command.translation = Vector3.ZERO
physics_command.rotation = Vector3.ZERO
physics_command.boost = _boost_amount

var raw_total_force := FlightAuthority.translation_force(
    automatic_command.translation,
    _boost_amount,
    tuning
)
output.pilot_force_local = Vector3.ZERO
output.pilot_torque_local = Vector3.ZERO
output.assist_force_local = FlightSpeedEnvelope.apply_to_force(
    raw_total_force,
    local_linear,
    active_soft_start,
    active_speed_limit
)
output.assist_torque_local = FlightAuthority.rotation_torque(
    automatic_command.rotation,
    tuning
)
_assistance_source = FlightAssistanceSource.Value.SMART_STABILIZE
```

Store `_last_command = physics_command.duplicate_command()` so direct movement/rotation visuals remain suppressed but effective boost telemetry is retained.

Add/reset:

```gdscript
var _assistance_source: FlightAssistanceSource.Value = (
    FlightAssistanceSource.Value.NONE
)

func get_assistance_source() -> FlightAssistanceSource.Value:
    return _assistance_source
```

- [ ] **Step 6: Run and commit**

Expected: `PASS: 38 suites`.

```powershell
git add src/flight/smart_stabilize_solver.gd src/flight/flight_tuning.gd config/flight/player_flight_tuning.tres src/player/ship_flight_controller.gd tests/unit/test_smart_stabilize_solver.gd tests/integration/test_ai_assisted_flight_controller.gd tests/unit/test_ship_flight_controller_state.gd
git commit -m "feat: use full legal Smart Stabilize authority"
```

---

### Task 3: Aggressive continuous AI trajectory alignment

**Files:**
- Modify: `src/flight/ai_flight_intent_solver.gd`
- Modify: `src/flight/flight_tuning.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_ai_flight_intent_solver.gd`
- Modify: `tests/integration/test_ai_assisted_flight_controller.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`

**Interfaces:**
- Produces `AiFlightIntentSolver.compute(command, local_linear_velocity, local_angular_velocity, tuning) -> FlightAssistCommand`.
- Consumes Task 1 authority composition.

- [ ] **Step 1: Write the consolidated RED**

Require the AI solver to:

```gdscript
var alignment := AiFlightIntentSolver.compute(
    coast,
    Vector3(30.0, -20.0, -80.0),
    Vector3(0.4, -0.5, 0.3),
    tuning
)
assert_true(alignment.translation.x < 0.0, "AI cancels rightward trajectory error")
assert_true(alignment.translation.y > 0.0, "AI cancels downward trajectory error")
assert_true(alignment.translation.z < 0.0, "AI adds forward authority to preserve speed")
assert_true(
    is_equal_approx(alignment.translation.length(), 1.0),
    "large marker separation requests full legal authority"
)
assert_equal(
    alignment.rotation,
    Vector3(-1.0, 1.0, -1.0),
    "uncommanded angular axes receive full counter-command"
)
```

Also require:

- aligned velocity `(0, 0, -80)` produces zero translation command;
- a `1 m/s` lateral error produces a tapered command between zero and one;
- explicit X/Y translation zeroes AI correction on those axes;
- explicit reverse suspends forward alignment;
- an explicitly commanded rotation axis receives zero automatic counter-command while other axes stabilize;
- non-finite input returns zero.

Integration tests must prove correction remains active with no current pitch/yaw input and source equals `AI_ASSISTED`.

- [ ] **Step 2: Run one RED**

Expected: current AI returns force/torque, only aligns during intent, and controller stacks independent force.

- [ ] **Step 3: Replace old AI tuning**

Remove the old damping/gain/acceleration/protection/braking fields and add:

```gdscript
@export var ai_full_authority_error_speed: float = 12.0
@export var ai_capture_error_speed: float = 0.75
@export var ai_min_alignment_speed: float = 2.0
@export var ai_angular_capture_rate_degrees: float = 8.0
@export var ai_angular_rest_threshold_degrees: float = 0.25
```

Apply identical values in `player_flight_tuning.tres`.

- [ ] **Step 4: Implement continuous command solver**

Use:

```gdscript
desired_velocity = Vector3.FORWARD * local_linear_velocity.length()
velocity_error = desired_velocity - local_linear_velocity
```

Zero X/Y error components when that pilot translation axis is explicitly commanded. Return no translation correction during explicit reverse. Convert error magnitude to authority weight:

```gdscript
weight = clamp(
    (error_speed - ai_capture_error_speed)
    / (ai_full_authority_error_speed - ai_capture_error_speed),
    0,
    1
)
```

Return `velocity_error.normalized() * weight` through `sanitize_translation`. Use the same per-axis opposing-rate taper as Smart Stabilize for uncommanded rotation axes.

- [ ] **Step 5: Compose pilot and AI before force generation**

```gdscript
var combined_translation := FlightAuthority.combine_translation(
    physics_command.translation,
    automatic_command.translation
)
var combined_rotation := FlightAuthority.combine_rotation(
    physics_command.rotation,
    automatic_command.rotation
)
var legal_total_force := FlightSpeedEnvelope.apply_to_force(
    FlightAuthority.translation_force(
        combined_translation,
        _boost_amount,
        tuning
    ),
    local_linear,
    active_soft_start,
    active_speed_limit
)
var legal_total_torque := FlightAuthority.rotation_torque(
    combined_rotation,
    tuning
)
output.assist_force_local = legal_total_force - output.pilot_force_local
output.assist_torque_local = legal_total_torque - output.pilot_torque_local
_assistance_source = FlightAssistanceSource.Value.AI_ASSISTED
```

This subtraction is mandatory: `pilot + assist` must equal one legal combined command, never two stacked full commands.

Set source to `LEGACY_ASSISTED` for the unchanged Assisted branch and `NONE` for Inertial.

- [ ] **Step 6: Run tests and inertial verifier**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/verify_inertial_velocity.gd
```

Required:

```text
PASS: 38 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
```

- [ ] **Step 7: Commit**

```powershell
git add src/flight/ai_flight_intent_solver.gd src/flight/flight_tuning.gd config/flight/player_flight_tuning.tres src/player/ship_flight_controller.gd tests/unit/test_ai_flight_intent_solver.gd tests/integration/test_ai_assisted_flight_controller.gd tests/unit/test_ship_flight_controller_state.gd
git commit -m "feat: aggressively align AI-assisted trajectory"
```

---

### Task 4: Direction-correct full-strength automatic thruster visuals

**Files:**
- Modify: `src/player/thruster_visual_math.gd`
- Modify: `src/player/ship_thruster_visual_controller.gd`
- Modify: `tests/unit/test_thruster_visual_math.gd`
- Modify: `tests/integration/test_ship_thruster_visual_controller.gd`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/deferred-milestones.md`

**Interfaces:**
- Consumes actual applied assist force/torque, effective boost, controller tuning and typed assistance source.
- Produces legacy global-normalized dim visuals only for `LEGACY_ASSISTED`.
- Produces direction-correct player-equivalent visuals for `AI_ASSISTED` and `SMART_STABILIZE`.

- [ ] **Step 1: Write the visual RED**

Extend `test_thruster_visual_math.gd`:

```gdscript
assert_true(
    is_equal_approx(ThrusterVisualMath.merge_target(0.0, 1.0, 0.35), 0.35),
    "legacy assistance remains capped at 35 percent"
)
assert_true(
    is_equal_approx(ThrusterVisualMath.merge_target(0.0, 1.0, 1.0), 1.0),
    "full-authority automatic output may reach one"
)
assert_true(
    is_equal_approx(ThrusterVisualMath.merge_target(0.8, 0.4, 1.0), 0.8),
    "direct output retains precedence"
)
```

Extend the visual integration suite with full legal directional forces:

```gdscript
visual_controller.set_test_assist_wrench(
    Vector3(0.0, 0.0, flight_controller.tuning.reverse_force),
    Vector3.ZERO,
    FlightAssistanceSource.Value.SMART_STABILIZE
)
visual_controller.step_visuals(0.25)
assert_true(
    visual_controller.get_merged_target(
        &"ThrusterEffects/RetroEffects/RetroLeftEffect"
    ) > 0.99,
    "full legal reverse braking shows full retro output"
)

visual_controller.set_test_assist_wrench(
    Vector3(0.0, 0.0, -flight_controller.tuning.forward_force),
    Vector3.ZERO,
    FlightAssistanceSource.Value.AI_ASSISTED
)
visual_controller.step_visuals(0.25)
assert_true(
    visual_controller.get_merged_target(MAIN_LEFT_EFFECT) > 0.99,
    "full legal forward AI authority shows full main output"
)
```

Retain the existing legacy wrench test and require its merged target to stay `<= 0.35`.

- [ ] **Step 2: Run one RED**

Expected: helper signatures do not accept source/cap, and current global force reference makes legal reverse authority look weak.

- [ ] **Step 3: Parameterize the visual cap**

```gdscript
static func merge_target(
    direct: float,
    assist_raw: float,
    assist_cap: float = ASSIST_VISUAL_CAP
) -> float:
    return maxf(
        clampf(direct, 0.0, 1.0),
        clampf(assist_raw, 0.0, 1.0)
        * clampf(assist_cap, 0.0, 1.0)
    )
```

- [ ] **Step 4: Preserve legacy mapping and add player-equivalent mapping**

In `ShipThrusterVisualController`:

```gdscript
var assistance_source := (
    _test_assistance_source
    if _test_override_enabled
    else _controller.get_assistance_source()
)
var assisted := (
    _assisted_intensities_legacy(assist_force, assist_torque)
    if assistance_source == FlightAssistanceSource.Value.LEGACY_ASSISTED
    else _player_equivalent_assisted_intensities(
        assist_force,
        assist_torque,
        boost
    )
)
var assistance_cap := FlightAssistanceSource.visual_cap_for(
    assistance_source
)
```

Implement:

```gdscript
func _player_equivalent_assisted_intensities(
    assist_force: Vector3,
    assist_torque: Vector3,
    effective_boost: float
) -> Dictionary:
    var command := FlightCommand.new()
    command.translation = FlightAuthority.translation_command_for_force(
        assist_force,
        effective_boost,
        _controller.tuning
    )
    command.rotation = FlightAuthority.rotation_command_for_torque(
        assist_torque,
        _controller.tuning
    )
    return _action_matrix.intensities_for(command)
```

Rename the current global-reference helper to `_assisted_intensities_legacy` without changing its math.

Pass `assistance_cap` to `merge_target`. Extend `set_test_assist_wrench(force, torque, source=LEGACY_ASSISTED)` and reset the test source in `clear_test_overrides()`.

For main/retro boost brightness, allow automatic boosted output only when source is `AI_ASSISTED` or `SMART_STABILIZE` and `assist_amount` is active. Legacy Assisted remains unchanged.

Do not modify the checked-in action matrix, socket data, effect transforms or allocation algorithm.

- [ ] **Step 5: Update docs and run**

README must state:

```text
AI Assisted continuously uses legal full-authority thrust to center the velocity marker on the nose reticle.
Smart Stabilize simultaneously counters all local linear and angular velocity axes while X is held.
Automatic control never exceeds player-equivalent force, torque, combined-input or effective-boost authority.
Legacy Assisted stays visually dim; AI Assisted and Smart Stabilize show the actual directional output through the checked-in thruster matrix.
```

Set deferred milestone status to `full-authority correction implemented; verification pending`.

Expected: `PASS: 38 suites`.

```powershell
git add src/player/thruster_visual_math.gd src/player/ship_thruster_visual_controller.gd tests/unit/test_thruster_visual_math.gd tests/integration/test_ship_thruster_visual_controller.gd README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "feat: show full-authority automatic thrusters"
```

---

### Task 5: Authoritative verification and manual acceptance

**Files:**
- Modify only when the first failing verifier evidence identifies a concrete defect.
- Finalize: `README.md`
- Finalize: `docs/superpowers/plans/deferred-milestones.md`

- [ ] **Step 1: Run the full verifier once**

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify\verify.ps1
```

Required:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 38 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
==> Boot main scene briefly
```

No parser/runtime error, orphan node, retained resource or boot error is acceptable.

- [ ] **Step 2: Debug only from first evidence if required**

Read the first stack trace/assertion completely, fix its originating contract, run that focused suite, then rerun the complete verifier. Do not weaken authority caps or established Assisted/Inertial behavior.

- [ ] **Step 3: Run one Windows manual session**

```powershell
godot --path .
```

Verify:

1. Combined forward/lateral/vertical and pitch/yaw/roll motion activates all relevant opposite thrusters while `X` is held.
2. Translation and rotation begin reducing simultaneously.
3. Strong motion reaches full legal visible output; near rest tapers without oscillation.
4. `Shift + X` uses boosted authority only while boost is thermally available.
5. Stabilization never brakes harder than equivalent direct control in that direction and boost state.
6. AI Assisted aggressively moves a displaced velocity marker toward the crosshair.
7. AI correction continues after pitch/yaw release until centered.
8. Explicit strafe/up/down axes are not countered.
9. Explicit reverse suspends forced forward alignment.
10. Pilot plus AI never exceeds one legal full command.
11. Legacy Assisted remains unchanged and visually dim.
12. Inertial remains exact when `X` is inactive.
13. Fire, boost lockout, cameras, pause, settings, reset, collisions, HUD, exact muzzles and exact thruster sockets remain functional.

- [ ] **Step 4: Close only after both gates pass**

Set documentation to:

```text
Full-Authority AI Assisted and Smart Stabilize correction — VERIFIED
Automated gate: PASS: 38 suites
Inertial verifier: zero speed drift, zero direction drift
Windows manual acceptance: passed
Authority rule: automatic control never exceeds legal player-equivalent output
```

Set README runner target to `PASS: 38 suites`.

- [ ] **Step 5: Commit closure and inspect scope**

```powershell
git add README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "docs: verify full-authority flight assistance"
git status --short
git log --oneline -6
git diff --stat HEAD~5..HEAD
```

Expected scope: flight authority, solvers, controller, tuning, thruster visual mapping/cap, focused tests and documentation only. No scene hierarchy, assets, workflows, camera, combat, projectile or Blender-source changes.
