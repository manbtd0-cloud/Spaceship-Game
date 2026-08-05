# Full-Authority Flight Assistance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AI Assisted and hold-`X` Smart Stabilize use the ship's full legal player-equivalent thrust and torque authority while never exceeding the force, torque, boost, speed-envelope, or combined-input limits available to direct player control.

**Architecture:** Introduce one pure `FlightAuthority` helper as the single source of truth for converting normalized translation/rotation commands into legal force and torque. Change both automatic solvers to return normalized commands instead of independent force stacks; `ShipFlightController` combines pilot and automatic commands first, applies the same normalization/clamping and speed envelope as player input, and derives assist telemetry as `legal_total - pilot_output`. Add a typed assistance source so legacy Assisted visuals retain the `0.35` cap while AI Assisted and Smart Stabilize can visibly reach the same `1.0` output as direct control.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, existing dependency-free test harness, Windows PowerShell verifier.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Baseline verified state: `PASS: 37 suites` and exact inertial drift `0.000000000`.
- Final runner target: `PASS: 38 suites`.
- Smart Stabilize may use full legal direct-control authority but may never exceed it on any axis or combined translation vector.
- AI pilot output plus AI automatic output may never exceed the legal output obtainable from one normalized player command in the same effective-boost state.
- Forward and reverse authority remain asymmetric: `forward_force` for local `-Z`, `reverse_force` for local `+Z`.
- Combined translation is normalized to length `1.0`, exactly matching `PlayerInputMath.compose_translation()`.
- Pitch, yaw, and roll remain independently clamped to `[-1, 1]`, matching current player rotation input.
- Boost authority is used only when boost is held, thermally available, and represented by the controller's current effective boost value.
- Smart Stabilize cancels linear and angular velocity simultaneously; it must not wait for rotation to settle before braking translation.
- AI Assisted continuously drives the velocity vector toward ship-forward after rotational input is released.
- No direct transform assignment, linear/angular velocity assignment, fake damping, second body, second controller, runtime thruster allocator, new sockets, or procedural exhaust.
- Existing Assisted and Inertial behavior remains unchanged while Smart Stabilize is inactive.
- Preserve primary fire, exact muzzle transforms, projectile behavior, camera behavior, pause/settings/reset ownership, boost thermals, speed envelopes, and schema-5 thruster geometry/action matrix.
- No GitHub Actions.
- Run one broad RED per task, one implementation pass, one focused local gate per task, and one final full verifier.

---

## File Map

### Create

- `src/flight/flight_authority.gd` — pure legal command-to-force/torque conversion and command composition.
- `src/flight/flight_assist_command.gd` — typed normalized automatic translation/rotation request.
- `src/flight/flight_assistance_source.gd` — typed source identity and visual cap.
- `tests/unit/test_flight_authority.gd` — exact authority, normalization, asymmetry, boost, and composition contract.

### Modify

- `src/flight/flight_model.gd` — use `FlightAuthority` for pilot force/torque construction.
- `src/flight/ai_flight_intent_solver.gd` — return continuous full-authority commands.
- `src/flight/smart_stabilize_solver.gd` — return simultaneous six-axis cancellation commands.
- `src/flight/flight_tuning.gd` — replace mild acceleration/damping values with capture/rest thresholds.
- `config/flight/player_flight_tuning.tres` — checked-in capture/rest values.
- `src/player/ship_flight_controller.gd` — reorder control flow, combine commands before force generation, expose assistance source.
- `src/player/thruster_visual_math.gd` — accept a caller-supplied assistance cap.
- `src/player/ship_thruster_visual_controller.gd` — choose cap from typed assistance source.
- `tests/test_runner.gd` — register the single new authority suite.
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

### Task 1: Shared player-equivalent authority

**Files:**
- Create: `src/flight/flight_authority.gd`
- Create: `src/flight/flight_assist_command.gd`
- Create: `src/flight/flight_assistance_source.gd`
- Create: `tests/unit/test_flight_authority.gd`
- Modify: `src/flight/flight_model.gd`
- Modify: `tests/unit/test_flight_model.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `FlightAuthority.sanitize_translation(value: Vector3) -> Vector3`.
- Produces: `FlightAuthority.sanitize_rotation(value: Vector3) -> Vector3`.
- Produces: `FlightAuthority.combine_translation(pilot: Vector3, automatic: Vector3) -> Vector3`.
- Produces: `FlightAuthority.combine_rotation(pilot: Vector3, automatic: Vector3) -> Vector3`.
- Produces: `FlightAuthority.translation_force(command: Vector3, effective_boost: float, tuning: FlightTuning) -> Vector3`.
- Produces: `FlightAuthority.rotation_torque(command: Vector3, tuning: FlightTuning) -> Vector3`.
- Produces: `FlightAssistCommand.translation`, `rotation`, and `is_finite()`.
- Produces: `FlightAssistanceSource.Value` and `visual_cap_for(...)`.

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
        "full forward command must use forward authority"
    )
    assert_equal(
        FlightAuthority.translation_force(Vector3.BACK, 0.0, tuning),
        Vector3(0.0, 0.0, 40.0),
        "full reverse command must use reverse authority"
    )
    assert_equal(
        FlightAuthority.translation_force(Vector3.RIGHT, 0.0, tuning),
        Vector3(50.0, 0.0, 0.0),
        "full lateral command must use strafe authority"
    )
    assert_equal(
        FlightAuthority.rotation_torque(Vector3.ONE, tuning),
        Vector3(10.0, 20.0, 30.0),
        "full three-axis rotation must retain independent torque authority"
    )

    var diagonal := FlightAuthority.sanitize_translation(
        Vector3(1.0, 1.0, -1.0)
    )
    assert_true(
        is_equal_approx(diagonal.length(), 1.0),
        "combined translation must normalize to one"
    )
    var diagonal_force := FlightAuthority.translation_force(
        diagonal,
        0.0,
        tuning
    )
    assert_true(
        diagonal_force.is_finite(),
        "combined translation force must remain finite"
    )

    var boosted := FlightAuthority.translation_force(
        Vector3.FORWARD,
        1.0,
        tuning
    )
    assert_equal(
        boosted,
        Vector3(0.0, 0.0, -180.0),
        "effective boost must scale authority exactly like player thrust"
    )

    var combined := FlightAuthority.combine_translation(
        Vector3.FORWARD,
        Vector3.RIGHT
    )
    assert_true(
        combined.length() <= 1.000001,
        "pilot plus automatic translation must remain in one legal envelope"
    )
    var combined_rotation := FlightAuthority.combine_rotation(
        Vector3(0.8, 0.8, 0.8),
        Vector3(0.8, -0.8, 0.8)
    )
    assert_equal(
        combined_rotation,
        Vector3(1.0, 0.0, 1.0),
        "pilot plus automatic rotation must clamp per axis"
    )

    assert_equal(
        FlightAuthority.sanitize_translation(Vector3(NAN, 0.0, 0.0)),
        Vector3.ZERO,
        "non-finite translation must fail closed"
    )
    assert_equal(
        FlightAuthority.sanitize_rotation(Vector3(0.0, INF, 0.0)),
        Vector3.ZERO,
        "non-finite rotation must fail closed"
    )

    assert_true(
        is_equal_approx(
            FlightAssistanceSource.visual_cap_for(
                FlightAssistanceSource.Value.LEGACY_ASSISTED
            ),
            0.35
        ),
        "legacy Assisted keeps the dim visual cap"
    )
    assert_true(
        is_equal_approx(
            FlightAssistanceSource.visual_cap_for(
                FlightAssistanceSource.Value.AI_ASSISTED
            ),
            1.0
        ),
        "AI Assisted may display full legal authority"
    )
    assert_true(
        is_equal_approx(
            FlightAssistanceSource.visual_cap_for(
                FlightAssistanceSource.Value.SMART_STABILIZE
            ),
            1.0
        ),
        "Smart Stabilize may display full legal authority"
    )
```

Extend `test_flight_model.gd` with an exact equivalence assertion:

```gdscript
var authority_command := FlightCommand.new()
authority_command.mode = FlightMode.Value.MANUAL
authority_command.translation = Vector3(0.4, -0.2, -0.7)
authority_command.rotation = Vector3(-0.3, 0.6, -0.9)
authority_command.boost = 0.5
var authority_output := FlightModel.compute(
    authority_command,
    tuning,
    Vector3.ZERO,
    Vector3.ZERO
)
assert_equal(
    authority_output.pilot_force_local,
    FlightAuthority.translation_force(
        authority_command.translation,
        authority_command.boost,
        tuning
    ),
    "FlightModel pilot force must use shared authority"
)
assert_equal(
    authority_output.pilot_torque_local,
    FlightAuthority.rotation_torque(authority_command.rotation, tuning),
    "FlightModel pilot torque must use shared authority"
)
```

- [ ] **Step 2: Run one RED**

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: the new suite fails because the three classes do not exist; existing suites remain parseable.

- [ ] **Step 3: Create the typed automatic command**

`src/flight/flight_assist_command.gd`:

```gdscript
class_name FlightAssistCommand
extends RefCounted

var translation: Vector3 = Vector3.ZERO
var rotation: Vector3 = Vector3.ZERO

func is_finite() -> bool:
    return translation.is_finite() and rotation.is_finite()
```

- [ ] **Step 4: Create the typed assistance source**

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

- [ ] **Step 5: Create `FlightAuthority`**

`src/flight/flight_authority.gd`:

```gdscript
class_name FlightAuthority
extends RefCounted

static func sanitize_translation(value: Vector3) -> Vector3:
    if not value.is_finite():
        return Vector3.ZERO
    return value.limit_length(1.0)

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
    var longitudinal_force := (
        tuning.forward_force
        if legal.z < 0.0
        else tuning.reverse_force
    )
    var force := Vector3(
        legal.x * tuning.strafe_force,
        legal.y * tuning.strafe_force,
        legal.z * longitudinal_force
    )
    return force * lerpf(
        1.0,
        tuning.boost_multiplier,
        clampf(effective_boost, 0.0, 1.0)
    )

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
```

- [ ] **Step 6: Route `FlightModel` through `FlightAuthority`**

Replace manual force/torque construction in `FlightModel.compute()` with:

```gdscript
var pilot_force := FlightAuthority.translation_force(
    command.translation,
    command.boost,
    tuning
)
```

Keep the existing `FlightSpeedEnvelope.apply_to_force(...)` call unchanged.

Replace pilot torque construction with:

```gdscript
output.pilot_torque_local = FlightAuthority.rotation_torque(
    command.rotation,
    tuning
)
```

Do not alter the existing legacy Assisted branch.

- [ ] **Step 7: Run and commit**

Expected: `PASS: 38 suites`.

```powershell
git add src/flight/flight_authority.gd src/flight/flight_assist_command.gd src/flight/flight_assistance_source.gd src/flight/flight_model.gd tests/unit/test_flight_authority.gd tests/unit/test_flight_model.gd tests/test_runner.gd
git commit -m "refactor: centralize legal flight authority"
```

---

### Task 2: Simultaneous full-authority Smart Stabilize

**Files:**
- Modify: `src/flight/smart_stabilize_solver.gd`
- Modify: `src/flight/flight_tuning.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_smart_stabilize_solver.gd`
- Modify: `tests/integration/test_ai_assisted_flight_controller.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`

**Interfaces:**
- Consumes: `FlightAssistCommand` and `FlightAuthority` from Task 1.
- Produces: `SmartStabilizeSolver.compute(local_linear_velocity, local_angular_velocity, tuning) -> FlightAssistCommand`.
- Produces: controller Smart Stabilize composition using effective boost without exceeding legal player authority.

- [ ] **Step 1: Rewrite the Smart Stabilize suite as one RED**

Replace the old damping/deceleration expectations in `test_smart_stabilize_solver.gd` with:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.stabilize_linear_capture_speed = 4.0
    tuning.stabilize_angular_capture_rate_degrees = 8.0
    tuning.stabilize_linear_rest_threshold = 0.10
    tuning.stabilize_angular_rest_threshold_degrees = 0.25

    var combined := SmartStabilizeSolver.compute(
        Vector3(30.0, -20.0, -80.0),
        Vector3(deg_to_rad(20.0), deg_to_rad(-20.0), deg_to_rad(20.0)),
        tuning
    )
    assert_true(combined.is_finite(), "combined stabilization command must be finite")
    assert_true(combined.translation.x < 0.0, "rightward drift must command left thrust")
    assert_true(combined.translation.y > 0.0, "downward drift must command upward thrust")
    assert_true(combined.translation.z > 0.0, "forward drift must command reverse thrust")
    assert_true(
        is_equal_approx(combined.translation.length(), 1.0),
        "combined translation must use one normalized player envelope"
    )
    assert_equal(
        combined.rotation,
        Vector3(-1.0, 1.0, -1.0),
        "all three angular axes must receive full legal counter-command"
    )

    var backward := SmartStabilizeSolver.compute(
        Vector3(0.0, 0.0, 20.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(
        backward.translation,
        Vector3.FORWARD,
        "backward drift must use full forward command"
    )

    var taper := SmartStabilizeSolver.compute(
        Vector3(2.0, 0.0, 0.0),
        Vector3(0.0, deg_to_rad(4.0), 0.0),
        tuning
    )
    assert_true(
        taper.translation.x < 0.0 and absf(taper.translation.x) < 1.0,
        "translation must taper inside the capture band"
    )
    assert_true(
        taper.rotation.y < 0.0 and absf(taper.rotation.y) < 1.0,
        "rotation must taper inside the capture band"
    )

    var rest := SmartStabilizeSolver.compute(
        Vector3(0.05, 0.0, 0.0),
        Vector3(0.0, deg_to_rad(0.1), 0.0),
        tuning
    )
    assert_equal(rest.translation, Vector3.ZERO, "linear rest threshold must stop thrust")
    assert_equal(rest.rotation, Vector3.ZERO, "angular rest threshold must stop torque")

    var simultaneous := SmartStabilizeSolver.compute(
        Vector3(50.0, 0.0, 0.0),
        Vector3(0.0, deg_to_rad(40.0), 0.0),
        tuning
    )
    assert_true(
        simultaneous.translation.length() > 0.99,
        "strong rotation must not delay full linear braking"
    )
    assert_true(
        absf(simultaneous.rotation.y) > 0.99,
        "linear braking must not delay full angular counter-command"
    )
```

Extend `test_ai_assisted_flight_controller.gd` Smart Stabilize loop with:

```gdscript
player.linear_velocity = Vector3(30.0, -20.0, -80.0)
player.angular_velocity = Vector3(0.4, -0.5, 0.3)
Input.action_press(&"smart_stabilize")
controller._physics_process(1.0 / 60.0)
assert_equal(
    controller.get_assistance_source(),
    FlightAssistanceSource.Value.SMART_STABILIZE,
    "Smart Stabilize must expose its typed assistance source"
)
assert_true(
    controller.get_last_assist_force_local().length() > 0.0,
    "Smart Stabilize must brake translation immediately"
)
assert_true(
    controller.get_last_assist_torque_local().length() > 0.0,
    "Smart Stabilize must counter rotation immediately"
)
```

Add a boost-authority integration case:

```gdscript
Input.action_press(&"boost")
Input.action_press(&"smart_stabilize")
player.linear_velocity = Vector3(0.0, 0.0, -80.0)
controller._physics_process(1.0 / 60.0)
assert_true(controller.get_boost_amount() > 0.0, "held boost remains available to stabilization")
assert_true(
    absf(controller.get_last_force_local().z)
    <= controller.tuning.reverse_force * controller.tuning.boost_multiplier + 0.01,
    "boosted stabilization must remain within boosted player reverse authority"
)
Input.action_release(&"boost")
Input.action_release(&"smart_stabilize")
```

- [ ] **Step 2: Run one RED**

Expected: failures because the solver still returns `FlightAssistOutput`, waits before braking, and the controller zeros boost during stabilization.

- [ ] **Step 3: Replace mild tuning with capture thresholds**

In `FlightTuning`, remove:

```gdscript
stabilize_angular_damping
stabilize_max_linear_deceleration
stabilize_full_braking_below_degrees
stabilize_no_braking_above_degrees
```

Set:

```gdscript
@export var stabilize_linear_capture_speed: float = 4.0
@export var stabilize_angular_capture_rate_degrees: float = 8.0
@export var stabilize_linear_rest_threshold: float = 0.10
@export var stabilize_angular_rest_threshold_degrees: float = 0.25
```

Apply the same values in `player_flight_tuning.tres` and remove the obsolete resource properties.

- [ ] **Step 4: Implement command-based Smart Stabilize**

Replace `smart_stabilize_solver.gd` with:

```gdscript
class_name SmartStabilizeSolver
extends RefCounted

static func compute(
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    tuning: FlightTuning
) -> FlightAssistCommand:
    var output := FlightAssistCommand.new()
    if (
        tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
    ):
        return output

    output.translation = FlightAuthority.sanitize_translation(Vector3(
        _opposing_axis(
            local_linear_velocity.x,
            tuning.stabilize_linear_rest_threshold,
            tuning.stabilize_linear_capture_speed
        ),
        _opposing_axis(
            local_linear_velocity.y,
            tuning.stabilize_linear_rest_threshold,
            tuning.stabilize_linear_capture_speed
        ),
        _opposing_axis(
            local_linear_velocity.z,
            tuning.stabilize_linear_rest_threshold,
            tuning.stabilize_linear_capture_speed
        )
    ))

    var rest_rate := deg_to_rad(
        tuning.stabilize_angular_rest_threshold_degrees
    )
    var capture_rate := deg_to_rad(
        tuning.stabilize_angular_capture_rate_degrees
    )
    output.rotation = FlightAuthority.sanitize_rotation(Vector3(
        _opposing_axis(local_angular_velocity.x, rest_rate, capture_rate),
        _opposing_axis(local_angular_velocity.y, rest_rate, capture_rate),
        _opposing_axis(local_angular_velocity.z, rest_rate, capture_rate)
    ))
    return output if output.is_finite() else FlightAssistCommand.new()

static func _opposing_axis(
    value: float,
    rest_threshold: float,
    full_authority_threshold: float
) -> float:
    var magnitude := absf(value)
    if not is_finite(magnitude) or magnitude <= rest_threshold:
        return 0.0
    var range_size := maxf(
        full_authority_threshold - rest_threshold,
        0.000001
    )
    var weight := clampf(
        (magnitude - rest_threshold) / range_size,
        0.0,
        1.0
    )
    return -signf(value) * weight
```

- [ ] **Step 5: Restructure controller ordering for stabilization and boost**

In `_physics_process()`:

1. Sample `pilot_command` without erasing boost.
2. Resolve basis/local velocities before thermal-state advancement.
3. Compute `automatic_command` before thermal-state advancement.
4. Use automatic translation length as boost activity while stabilizing.
5. After effective boost is known, build legal total force and torque.

Required Smart Stabilize branch:

```gdscript
var pilot_command := _input_source.sample_command(_flight_mode)
_smart_stabilizing = _input_source.is_smart_stabilize_held()

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

var boost_activity := (
    automatic_command.translation.length()
    if _smart_stabilizing
    else pilot_command.translation.length()
)
var thermal_state := BoostThermalState.advance(
    _boost_heat,
    _boost_locked_out,
    pilot_command.boost,
    boost_activity,
    delta,
    tuning.boost_heat_per_second,
    tuning.boost_cooling_per_second,
    tuning.boost_recovery_threshold
)
```

For Smart Stabilize, create a zeroed physics command but retain effective boost:

```gdscript
var physics_command := pilot_command.duplicate_command()
if _smart_stabilizing:
    physics_command.translation = Vector3.ZERO
    physics_command.rotation = Vector3.ZERO
physics_command.boost = _boost_amount
```

After `FlightModel.compute(...)`:

```gdscript
if _smart_stabilizing:
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
        tuning.boost_speed_soft_start if _boost_amount > 0.0 else tuning.normal_speed_soft_start,
        tuning.boost_speed_limit if _boost_amount > 0.0 else tuning.normal_speed_limit
    )
    output.assist_torque_local = FlightAuthority.rotation_torque(
        automatic_command.rotation,
        tuning
    )
    _assistance_source = FlightAssistanceSource.Value.SMART_STABILIZE
```

Store `_last_command` from `physics_command` so direct thruster telemetry stays suppressed, while boost telemetry remains accurate.

Add:

```gdscript
var _assistance_source: FlightAssistanceSource.Value = (
    FlightAssistanceSource.Value.NONE
)

func get_assistance_source() -> FlightAssistanceSource.Value:
    return _assistance_source
```

Reset `_assistance_source` to `NONE` on mode change and `reset_runtime_state()`.

- [ ] **Step 6: Run focused gate and commit**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 38 suites`.

```powershell
git add src/flight/smart_stabilize_solver.gd src/flight/flight_tuning.gd config/flight/player_flight_tuning.tres src/player/ship_flight_controller.gd tests/unit/test_smart_stabilize_solver.gd tests/integration/test_ai_assisted_flight_controller.gd tests/unit/test_ship_flight_controller_state.gd
git commit -m "feat: use full legal Smart Stabilize authority"
```

---

### Task 3: Continuous full-authority AI trajectory alignment

**Files:**
- Modify: `src/flight/ai_flight_intent_solver.gd`
- Modify: `src/flight/flight_tuning.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_ai_flight_intent_solver.gd`
- Modify: `tests/integration/test_ai_assisted_flight_controller.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`

**Interfaces:**
- Consumes: `FlightAuthority`, `FlightAssistCommand`, and controller ordering from Tasks 1–2.
- Produces: `AiFlightIntentSolver.compute(command, local_linear_velocity, local_angular_velocity, tuning) -> FlightAssistCommand`.
- Produces: legal AI composition where `pilot + AI` is normalized/clamped before force and torque generation.

- [ ] **Step 1: Rewrite AI solver expectations as one RED**

Replace acceleration/force assertions in `test_ai_flight_intent_solver.gd` with:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var tuning := FlightTuning.new()
    tuning.ai_full_authority_error_speed = 12.0
    tuning.ai_capture_error_speed = 0.75
    tuning.ai_min_alignment_speed = 2.0
    tuning.ai_angular_capture_rate_degrees = 8.0
    tuning.ai_angular_rest_threshold_degrees = 0.25

    var coast := FlightCommand.new()
    coast.mode = FlightMode.Value.AI_ASSISTED
    var alignment := AiFlightIntentSolver.compute(
        coast,
        Vector3(30.0, -20.0, -80.0),
        Vector3(0.4, -0.5, 0.3),
        tuning
    )
    assert_true(alignment.is_finite(), "AI command must remain finite")
    assert_true(alignment.translation.x < 0.0, "AI must cancel rightward trajectory error")
    assert_true(alignment.translation.y > 0.0, "AI must cancel downward trajectory error")
    assert_true(alignment.translation.z < 0.0, "AI must add forward authority to preserve speed while centering")
    assert_true(
        is_equal_approx(alignment.translation.length(), 1.0),
        "large marker displacement must request full legal authority"
    )
    assert_equal(
        alignment.rotation,
        Vector3(-1.0, 1.0, -1.0),
        "uncommanded angular axes must receive full counter-command"
    )

    var aligned := AiFlightIntentSolver.compute(
        coast,
        Vector3(0.0, 0.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(
        aligned.translation,
        Vector3.ZERO,
        "centered velocity marker must not receive translation correction"
    )

    var small_error := AiFlightIntentSolver.compute(
        coast,
        Vector3(1.0, 0.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_true(
        small_error.translation.length() > 0.0
        and small_error.translation.length() < 1.0,
        "small displacement must taper instead of hunting"
    )

    var explicit_axes := FlightCommand.new()
    explicit_axes.mode = FlightMode.Value.AI_ASSISTED
    explicit_axes.translation = Vector3(1.0, 1.0, 0.0).normalized()
    var protected := AiFlightIntentSolver.compute(
        explicit_axes,
        Vector3(30.0, -20.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_true(
        is_zero_approx(protected.translation.x),
        "AI must not oppose explicit lateral intent"
    )
    assert_true(
        is_zero_approx(protected.translation.y),
        "AI must not oppose explicit vertical intent"
    )

    var reverse := FlightCommand.new()
    reverse.mode = FlightMode.Value.AI_ASSISTED
    reverse.translation = Vector3.BACK
    var reverse_output := AiFlightIntentSolver.compute(
        reverse,
        Vector3(30.0, 0.0, -80.0),
        Vector3.ZERO,
        tuning
    )
    assert_equal(
        reverse_output.translation,
        Vector3.ZERO,
        "explicit reverse intent must suspend forward trajectory alignment"
    )

    var commanded_rotation := FlightCommand.new()
    commanded_rotation.mode = FlightMode.Value.AI_ASSISTED
    commanded_rotation.rotation.y = 1.0
    var protected_rotation := AiFlightIntentSolver.compute(
        commanded_rotation,
        Vector3.ZERO,
        Vector3(0.5, -0.5, 0.5),
        tuning
    )
    assert_true(
        is_zero_approx(protected_rotation.rotation.y),
        "AI must not counter-command the explicitly commanded yaw axis"
    )
    assert_true(
        protected_rotation.rotation.x < 0.0
        and protected_rotation.rotation.z < 0.0,
        "uncommanded rotational axes must remain stabilized"
    )
```

Extend `test_ai_assisted_flight_controller.gd`:

```gdscript
controller.set_flight_mode(FlightMode.Value.AI_ASSISTED)
player.linear_velocity = Vector3(30.0, -20.0, -80.0)
player.angular_velocity = Vector3.ZERO
controller._physics_process(1.0 / 60.0)
assert_equal(
    controller.get_assistance_source(),
    FlightAssistanceSource.Value.AI_ASSISTED,
    "AI Assisted must expose its typed source"
)
assert_true(
    controller.get_last_assist_force_local().length() > 0.0,
    "AI correction must remain active without current rotation input"
)

Input.action_press(&"thrust_forward")
Input.action_press(&"strafe_right")
controller._physics_process(1.0 / 60.0)
var legal_combined := FlightAuthority.combine_translation(
    controller.get_last_command().translation,
    AiFlightIntentSolver.compute(
        controller.get_last_command(),
        controller.get_local_velocity(),
        Vector3.ZERO,
        controller.tuning
    ).translation
)
var legal_force := FlightAuthority.translation_force(
    legal_combined,
    controller.get_boost_amount(),
    controller.tuning
)
assert_true(
    controller.get_last_force_local().length()
    <= legal_force.length() + 0.01,
    "pilot plus AI output must remain inside one legal command envelope"
)
Input.action_release(&"thrust_forward")
Input.action_release(&"strafe_right")
```

- [ ] **Step 2: Run one RED**

Expected: failures because AI still returns force/torque, corrects only during intent, and controller stacks assist force independently.

- [ ] **Step 3: Replace old AI tuning with capture thresholds**

Remove:

```gdscript
ai_angular_damping
ai_rotation_command_protection
ai_trajectory_alignment_gain
ai_max_steering_acceleration
ai_translation_command_protection
ai_max_braking_acceleration
```

Set:

```gdscript
@export var ai_full_authority_error_speed: float = 12.0
@export var ai_capture_error_speed: float = 0.75
@export var ai_min_alignment_speed: float = 2.0
@export var ai_angular_capture_rate_degrees: float = 8.0
@export var ai_angular_rest_threshold_degrees: float = 0.25
```

Apply the same values in `player_flight_tuning.tres` and remove the obsolete AI properties.

- [ ] **Step 4: Implement continuous command-based AI solver**

Replace `ai_flight_intent_solver.gd` with:

```gdscript
class_name AiFlightIntentSolver
extends RefCounted

const EXPLICIT_INPUT_THRESHOLD := 0.08

static func compute(
    command: FlightCommand,
    local_linear_velocity: Vector3,
    local_angular_velocity: Vector3,
    tuning: FlightTuning
) -> FlightAssistCommand:
    var output := FlightAssistCommand.new()
    if (
        command == null
        or tuning == null
        or not local_linear_velocity.is_finite()
        or not local_angular_velocity.is_finite()
    ):
        return output

    var rest_rate := deg_to_rad(tuning.ai_angular_rest_threshold_degrees)
    var capture_rate := deg_to_rad(tuning.ai_angular_capture_rate_degrees)
    output.rotation = FlightAuthority.sanitize_rotation(Vector3(
        0.0 if absf(command.rotation.x) > EXPLICIT_INPUT_THRESHOLD else _opposing_axis(local_angular_velocity.x, rest_rate, capture_rate),
        0.0 if absf(command.rotation.y) > EXPLICIT_INPUT_THRESHOLD else _opposing_axis(local_angular_velocity.y, rest_rate, capture_rate),
        0.0 if absf(command.rotation.z) > EXPLICIT_INPUT_THRESHOLD else _opposing_axis(local_angular_velocity.z, rest_rate, capture_rate)
    ))

    var speed := local_linear_velocity.length()
    var reverse_intent := command.translation.z > EXPLICIT_INPUT_THRESHOLD
    if speed < tuning.ai_min_alignment_speed or reverse_intent:
        return output

    var desired_velocity := Vector3.FORWARD * speed
    var velocity_error := desired_velocity - local_linear_velocity
    if absf(command.translation.x) > EXPLICIT_INPUT_THRESHOLD:
        velocity_error.x = 0.0
    if absf(command.translation.y) > EXPLICIT_INPUT_THRESHOLD:
        velocity_error.y = 0.0

    var error_speed := velocity_error.length()
    if error_speed <= tuning.ai_capture_error_speed:
        return output

    var response_range := maxf(
        tuning.ai_full_authority_error_speed
        - tuning.ai_capture_error_speed,
        0.000001
    )
    var weight := clampf(
        (error_speed - tuning.ai_capture_error_speed) / response_range,
        0.0,
        1.0
    )
    output.translation = FlightAuthority.sanitize_translation(
        velocity_error.normalized() * weight
    )
    return output if output.is_finite() else FlightAssistCommand.new()

static func _opposing_axis(
    value: float,
    rest_threshold: float,
    full_authority_threshold: float
) -> float:
    var magnitude := absf(value)
    if not is_finite(magnitude) or magnitude <= rest_threshold:
        return 0.0
    var range_size := maxf(
        full_authority_threshold - rest_threshold,
        0.000001
    )
    return -signf(value) * clampf(
        (magnitude - rest_threshold) / range_size,
        0.0,
        1.0
    )
```

- [ ] **Step 5: Compose pilot and AI commands before force generation**

In the controller, compute AI automatic command before thermal-state advancement:

```gdscript
elif pilot_command.mode == FlightMode.Value.AI_ASSISTED:
    automatic_command = AiFlightIntentSolver.compute(
        pilot_command,
        local_linear,
        local_angular,
        tuning
    )
```

For AI boost activity:

```gdscript
var boost_activity_command := (
    automatic_command.translation
    if _smart_stabilizing
    else FlightAuthority.combine_translation(
        pilot_command.translation,
        automatic_command.translation
    )
)
```

After `FlightModel.compute(...)`, compose legal AI totals:

```gdscript
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
        tuning.boost_speed_soft_start if _boost_amount > 0.0 else tuning.normal_speed_soft_start,
        tuning.boost_speed_limit if _boost_amount > 0.0 else tuning.normal_speed_limit
    )
    var total_torque := FlightAuthority.rotation_torque(
        combined_rotation,
        tuning
    )
    output.assist_force_local = total_force - output.pilot_force_local
    output.assist_torque_local = total_torque - output.pilot_torque_local
    _assistance_source = FlightAssistanceSource.Value.AI_ASSISTED
```

For the unchanged branches:

```gdscript
elif physics_command.mode == FlightMode.Value.ASSISTED:
    _assistance_source = FlightAssistanceSource.Value.LEGACY_ASSISTED
else:
    _assistance_source = FlightAssistanceSource.Value.NONE
```

This subtraction is mandatory: it makes `pilot + assist` equal one legal combined command rather than two stacked full-strength forces.

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

### Task 4: Full-strength automatic thruster feedback and documentation

**Files:**
- Modify: `src/player/thruster_visual_math.gd`
- Modify: `src/player/ship_thruster_visual_controller.gd`
- Modify: `tests/unit/test_thruster_visual_math.gd`
- Modify: `tests/integration/test_ship_thruster_visual_controller.gd`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/deferred-milestones.md`

**Interfaces:**
- Consumes: `FlightAssistanceSource.Value` and `ShipFlightController.get_assistance_source()`.
- Produces: legacy `0.35` visual cap and AI/Smart `1.0` visual cap without changing physical socket allocation.

- [ ] **Step 1: Write one visual RED**

Extend `test_thruster_visual_math.gd`:

```gdscript
assert_true(
    is_equal_approx(ThrusterVisualMath.merge_target(0.0, 1.0, 0.35), 0.35),
    "legacy assistance must remain capped at 35 percent"
)
assert_true(
    is_equal_approx(ThrusterVisualMath.merge_target(0.0, 1.0, 1.0), 1.0),
    "full-authority automatic thrust may reach full visual output"
)
assert_true(
    is_equal_approx(ThrusterVisualMath.merge_target(0.8, 0.4, 1.0), 0.8),
    "direct output must retain precedence over weaker automatic output"
)
assert_true(
    ThrusterVisualMath.merge_target(0.0, 5.0, 5.0) <= 1.0,
    "automatic visuals must never exceed one"
)
```

Extend `test_ship_thruster_visual_controller.gd`:

```gdscript
visual_controller.set_test_command(coast)
visual_controller.set_test_assist_wrench(
    Vector3.FORWARD * flight_controller.get_force_reference(),
    Vector3.ZERO,
    FlightAssistanceSource.Value.LEGACY_ASSISTED
)
visual_controller.step_visuals(0.25)
assert_true(
    visual_controller.get_merged_target(MAIN_LEFT_EFFECT) <= 0.35,
    "legacy Assisted output must remain dim"
)

visual_controller.set_test_assist_wrench(
    Vector3.FORWARD * flight_controller.get_force_reference(),
    Vector3.ZERO,
    FlightAssistanceSource.Value.SMART_STABILIZE
)
visual_controller.step_visuals(0.25)
assert_true(
    visual_controller.get_merged_target(MAIN_LEFT_EFFECT) > 0.99,
    "Smart Stabilize must visibly use full legal authority"
)
```

Add the same full-output assertion for `AI_ASSISTED`.

- [ ] **Step 2: Run one RED**

Expected: parser/signature failures because `merge_target` and `set_test_assist_wrench` do not yet accept a cap/source.

- [ ] **Step 3: Parameterize visual merge cap**

Change `ThrusterVisualMath.merge_target` to:

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

The default keeps all existing callers/tests at `0.35` unless a typed source explicitly requests full output.

- [ ] **Step 4: Route typed source through visual controller**

Add:

```gdscript
var _test_assistance_source: FlightAssistanceSource.Value = (
    FlightAssistanceSource.Value.LEGACY_ASSISTED
)
```

During `step_visuals()`:

```gdscript
var assistance_source := (
    _test_assistance_source
    if _test_override_enabled
    else _controller.get_assistance_source()
)
var assistance_cap := FlightAssistanceSource.visual_cap_for(
    assistance_source
)
```

Pass `assistance_cap` into `ThrusterVisualMath.merge_target(...)`.

Change the test helper to:

```gdscript
func set_test_assist_wrench(
    force: Vector3,
    torque: Vector3,
    source: FlightAssistanceSource.Value = (
        FlightAssistanceSource.Value.LEGACY_ASSISTED
    )
) -> void:
    _test_override_enabled = true
    _test_assist_force = force
    _test_assist_torque = torque
    _test_assistance_source = source
```

Reset the source to `LEGACY_ASSISTED` in `clear_test_overrides()`.

Do not change the action matrix, socket data, effect origins, force/torque allocation, or direct-precedence rule.

- [ ] **Step 5: Update documentation**

README must state:

```text
AI Assisted continuously uses legal full-authority thrust to center the velocity marker on the nose reticle.
Smart Stabilize simultaneously counters all local linear and angular velocity axes while X is held.
Automatic control never exceeds the force, torque, combined-input, or effective-boost authority available to direct player control.
Legacy Assisted corrections remain visually dim; AI Assisted and Smart Stabilize display their actual full-output thruster use.
```

Update `deferred-milestones.md` status to `full-authority correction implemented; verification pending`. Do not mark verified before Task 5.

- [ ] **Step 6: Run focused gate and commit**

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

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: verified full-authority correction evidence.

- [ ] **Step 1: Run the full verifier once**

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify\verify.ps1
```

Required output:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 38 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
==> Boot main scene briefly
```

No parser error, runtime error, orphan node, retained resource, or boot error is acceptable.

- [ ] **Step 2: Debug only from first evidence if needed**

Read the first failing assertion or stack trace completely. Fix the originating contract, run that focused suite once, then rerun the complete verifier. Do not weaken force/torque caps, remove assertions, or alter established Assisted/Inertial behavior to make the gate pass.

- [ ] **Step 3: Run one Windows manual session**

```powershell
godot --path .
```

Verify:

1. Build forward, lateral, vertical, pitch, yaw, and roll velocity simultaneously; hold `X`; relevant opposite thrusters activate together.
2. Smart Stabilize immediately reduces both translation and rotation; neither waits for the other.
3. Strong motion produces full visible legal output; near rest tapers without oscillation.
4. Holding `Shift + X` may use boosted translation authority only while boost is thermally available.
5. Smart Stabilize never accelerates harder than equivalent full direct control in the same direction/runtime boost state.
6. In AI Assisted, create a large velocity-marker/crosshair separation; the marker aggressively moves toward the crosshair.
7. Release pitch/yaw; AI correction continues until the marker is centered.
8. Explicit strafe/up/down input is not countered on its commanded axis.
9. Explicit reverse input suspends forced forward alignment.
10. Pilot plus AI output never feels stronger than one legal full player command.
11. Legacy Assisted still behaves and looks unchanged.
12. Inertial still preserves velocity when Smart Stabilize is not held.
13. LMB/V firing, boost lockout, cameras, pause, settings persistence, reset, collisions, HUD vectors, exact muzzles, and exact thruster sockets remain functional.

- [ ] **Step 4: Close the milestone only after both gates pass**

Set the wait-list entry to:

```text
Full-Authority AI Assisted and Smart Stabilize correction — VERIFIED
Automated gate: PASS: 38 suites
Inertial verifier: zero speed drift, zero direction drift
Windows manual acceptance: passed
Authority rule: automatic control never exceeds legal player-equivalent output
```

Set README runner target to `PASS: 38 suites`.

- [ ] **Step 5: Commit closure and review scope**

```powershell
git add README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "docs: verify full-authority flight assistance"
git status --short
git log --oneline -6
git diff --stat HEAD~5..HEAD
```

Expected changed scope: flight authority/solvers/controller/tuning, thruster visual cap routing, focused tests, and documentation only. No scene hierarchy, assets, workflow files, camera code, combat code, projectile code, or raw Blender files.
