# Agile Fighter Maneuverability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increase the production fighter's real translational and rotational authority while adding a smooth per-axis angular-rate envelope that prevents uncontrolled infinite spin without weakening braking or stabilization torque.

**Architecture:** Add one pure `FlightAngularEnvelope` helper that attenuates only torque which increases an already-high local angular rate. Update the existing `FlightTuning` resource with the approved agile-fighter force, torque, and angular-rate values, then apply the envelope once to the controller's final composed torque while proportionally preserving pilot/assist telemetry. No mass, collision, input, AI intent, Smart Stabilize command generation, scene hierarchy, camera, weapon, or thruster-matrix architecture changes are allowed.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, existing dependency-free test runner, Windows PowerShell verifier.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Approved design: `docs/superpowers/specs/2026-08-06-agile-fighter-maneuverability-design.md`.
- Verified baseline before this correction: `PASS: 38 suites`; inertial speed and direction drift exactly zero.
- Final runner target: `PASS: 39 suites`.
- Production mass remains exactly `8500 kg`.
- Production collider remains `Vector3(14.0, 3.8, 12.2)`.
- Production authority becomes `forward_force = 150000`, `reverse_force = 110000`, `strafe_force = 150000`, `pitch_torque = 190000`, `yaw_torque = 230000`, and `roll_torque = 210000`.
- Normal and boosted speed limits remain exactly `160 m/s` and `240 m/s`.
- Boost multiplier remains exactly `1.8`; thermal lockout/cooling behavior remains unchanged.
- Pitch/yaw angular soft start and limit are `75 deg/s` and `100 deg/s`.
- Roll angular soft start and limit are `112.5 deg/s` and `150 deg/s`.
- The angular envelope attenuates only torque that increases current angular speed on the same axis.
- Opposing torque remains fully available at every angular speed, including Smart Stabilize and AI counter-torque above the limit.
- Angular velocity is never assigned directly.
- Combined translation remains normalized through `FlightAuthority`.
- Automatic control remains capped to the same legal authority as direct player control.
- Existing AI trajectory logic and Smart Stabilize command generation remain unchanged.
- Existing Assisted and inactive Inertial semantics remain unchanged except for stronger physical authority and the final angular-rate envelope.
- No changes to camera code, combat/projectile code, input bindings, pause/settings ownership, HUD copy, scene hierarchy, raw assets, schema-five sockets, or the checked-in thruster action matrix.
- No GitHub Actions.
- Use one broad RED per task, one implementation pass per task, and one final complete Windows verifier.

---

## File Map

### Create

- `src/flight/flight_angular_envelope.gd` — pure independent per-axis torque attenuation.
- `tests/unit/test_flight_angular_envelope.gd` — exact angular-envelope contract.

### Modify

- `src/flight/flight_tuning.gd` — approved default forces, torques, and six angular-rate fields.
- `config/flight/player_flight_tuning.tres` — checked-in production values.
- `src/player/ship_flight_controller.gd` — apply envelope once to final composed torque and preserve split telemetry.
- `tests/test_runner.gd` — register the single new suite.
- `tests/integration/test_player_scene.gd` — lock mass, collider, authority, speed, boost, and angular-rate values.
- `tests/integration/test_ai_assisted_flight_controller.gd` — production torque-envelope behavior in direct, AI, Smart Stabilize, and no-input states.
- `tests/unit/test_ship_flight_controller_state.gd` — retain telemetry/reset invariants.
- `README.md` — document agile authority, angular caps, and runner target.
- `docs/superpowers/plans/deferred-milestones.md` — record implementation/verification status without rewriting historical requirements.

---

### Task 1: Pure per-axis angular-rate envelope

**Files:**
- Create: `src/flight/flight_angular_envelope.gd`
- Create: `tests/unit/test_flight_angular_envelope.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `FlightAngularEnvelope.apply_to_torque(torque_local: Vector3, angular_velocity_local: Vector3, soft_start_degrees: Vector3, limit_degrees: Vector3) -> Vector3`.
- Produces no nodes, state, input access, body access, transform access, or velocity mutation.
- Later tasks consume the helper only after the controller has composed the final legal torque.

- [ ] **Step 1: Register and write the envelope RED**

Add immediately after `test_flight_speed_envelope.gd` in `tests/test_runner.gd`:

```gdscript
"res://tests/unit/test_flight_angular_envelope.gd",
```

Create `tests/unit/test_flight_angular_envelope.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var soft_start := Vector3(75.0, 75.0, 112.5)
    var limits := Vector3(100.0, 100.0, 150.0)
    var requested := Vector3(10.0, 20.0, 30.0)

    var below_start := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(50.0),
            deg_to_rad(60.0),
            deg_to_rad(90.0)
        ),
        soft_start,
        limits
    )
    assert_equal(
        below_start,
        requested,
        "same-direction torque must remain full below every soft start"
    )

    var midpoint := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(87.5),
            deg_to_rad(87.5),
            deg_to_rad(131.25)
        ),
        soft_start,
        limits
    )
    assert_true(
        midpoint.is_equal_approx(requested * 0.5),
        "midpoint of each envelope must retain half torque"
    )

    var at_limit := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(100.0),
            deg_to_rad(110.0),
            deg_to_rad(150.0)
        ),
        soft_start,
        limits
    )
    assert_equal(
        at_limit,
        Vector3.ZERO,
        "same-direction torque must stop at or above each limit"
    )

    var opposing := FlightAngularEnvelope.apply_to_torque(
        -requested,
        Vector3(
            deg_to_rad(140.0),
            deg_to_rad(140.0),
            deg_to_rad(190.0)
        ),
        soft_start,
        limits
    )
    assert_equal(
        opposing,
        -requested,
        "opposing torque must remain full above every limit"
    )

    var independent := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3(
            deg_to_rad(100.0),
            deg_to_rad(50.0),
            deg_to_rad(131.25)
        ),
        soft_start,
        limits
    )
    assert_true(
        is_zero_approx(independent.x),
        "pitch must stop independently at its limit"
    )
    assert_true(
        is_equal_approx(independent.y, requested.y),
        "yaw below soft start must remain independent and full"
    )
    assert_true(
        is_equal_approx(independent.z, requested.z * 0.5),
        "roll must use its independent higher envelope"
    )

    var zero_rate := FlightAngularEnvelope.apply_to_torque(
        requested,
        Vector3.ZERO,
        soft_start,
        limits
    )
    assert_equal(
        zero_rate,
        requested,
        "zero angular rate must not create artificial damping"
    )

    assert_equal(
        FlightAngularEnvelope.apply_to_torque(
            Vector3(NAN, 0.0, 0.0),
            Vector3.ZERO,
            soft_start,
            limits
        ),
        Vector3.ZERO,
        "non-finite torque must fail closed"
    )
    assert_equal(
        FlightAngularEnvelope.apply_to_torque(
            requested,
            Vector3(0.0, INF, 0.0),
            soft_start,
            limits
        ),
        Vector3.ZERO,
        "non-finite angular velocity must fail closed"
    )
    assert_equal(
        FlightAngularEnvelope.apply_to_torque(
            requested,
            Vector3.ZERO,
            Vector3(NAN, 75.0, 112.5),
            limits
        ),
        Vector3.ZERO,
        "non-finite envelope tuning must fail closed"
    )
```

- [ ] **Step 2: Run one RED**

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: the new suite fails because `FlightAngularEnvelope` does not exist; all existing suites remain parseable.

- [ ] **Step 3: Implement the pure envelope**

Create `src/flight/flight_angular_envelope.gd`:

```gdscript
class_name FlightAngularEnvelope
extends RefCounted

const EPSILON := 0.000001

static func apply_to_torque(
    torque_local: Vector3,
    angular_velocity_local: Vector3,
    soft_start_degrees: Vector3,
    limit_degrees: Vector3
) -> Vector3:
    if (
        not torque_local.is_finite()
        or not angular_velocity_local.is_finite()
        or not soft_start_degrees.is_finite()
        or not limit_degrees.is_finite()
    ):
        return Vector3.ZERO

    return Vector3(
        _apply_axis(
            torque_local.x,
            angular_velocity_local.x,
            soft_start_degrees.x,
            limit_degrees.x
        ),
        _apply_axis(
            torque_local.y,
            angular_velocity_local.y,
            soft_start_degrees.y,
            limit_degrees.y
        ),
        _apply_axis(
            torque_local.z,
            angular_velocity_local.z,
            soft_start_degrees.z,
            limit_degrees.z
        )
    )

static func _apply_axis(
    requested_torque: float,
    angular_rate_radians: float,
    soft_start_degrees: float,
    limit_degrees: float
) -> float:
    if absf(requested_torque) <= EPSILON:
        return 0.0
    if (
        absf(angular_rate_radians) <= EPSILON
        or requested_torque * angular_rate_radians <= 0.0
    ):
        return requested_torque

    var start := maxf(soft_start_degrees, 0.0)
    var limit := maxf(limit_degrees, start + 0.001)
    var rate_degrees := rad_to_deg(absf(angular_rate_radians))
    if rate_degrees <= start:
        return requested_torque
    if rate_degrees >= limit:
        return 0.0

    var t := clampf(
        (rate_degrees - start) / (limit - start),
        0.0,
        1.0
    )
    var smooth_t := t * t * (3.0 - 2.0 * t)
    return requested_torque * (1.0 - smooth_t)
```

- [ ] **Step 4: Run the focused gate**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 39 suites`.

- [ ] **Step 5: Commit the helper contract**

```powershell
git add src/flight/flight_angular_envelope.gd tests/unit/test_flight_angular_envelope.gd tests/test_runner.gd
git commit -m "feat: add per-axis angular rate envelope"
```

---

### Task 2: Agile production authority and locked tuning contract

**Files:**
- Modify: `src/flight/flight_tuning.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Modify: `tests/integration/test_player_scene.gd`

**Interfaces:**
- Produces the approved production force and torque values through the existing `FlightTuning` fields.
- Produces six new scalar fields consumed by Task 3:
  - `pitch_angular_soft_start_degrees`
  - `pitch_angular_limit_degrees`
  - `yaw_angular_soft_start_degrees`
  - `yaw_angular_limit_degrees`
  - `roll_angular_soft_start_degrees`
  - `roll_angular_limit_degrees`
- Preserves the existing mass, collider, speed, boost, AI, stabilization, camera, and thermal fields.

- [ ] **Step 1: Add exact production-value assertions as one RED**

In `tests/integration/test_player_scene.gd`, immediately after resolving `controller`, add:

```gdscript
    var tuning := controller.tuning
    assert_true(tuning != null, "production controller tuning must exist")
    if tuning != null:
        assert_true(
            is_equal_approx(tuning.forward_force, 150000.0),
            "agile fighter forward authority must be exact"
        )
        assert_true(
            is_equal_approx(tuning.reverse_force, 110000.0),
            "agile fighter reverse authority must be exact"
        )
        assert_true(
            is_equal_approx(tuning.strafe_force, 150000.0),
            "agile fighter strafe and vertical authority must be exact"
        )
        assert_true(
            is_equal_approx(tuning.pitch_torque, 190000.0),
            "agile fighter pitch torque must be exact"
        )
        assert_true(
            is_equal_approx(tuning.yaw_torque, 230000.0),
            "agile fighter yaw torque must be exact"
        )
        assert_true(
            is_equal_approx(tuning.roll_torque, 210000.0),
            "agile fighter roll torque must be exact"
        )
        assert_true(
            is_equal_approx(tuning.boost_multiplier, 1.8),
            "boost multiplier must remain unchanged"
        )
        assert_true(
            is_equal_approx(tuning.normal_speed_limit, 160.0),
            "normal speed limit must remain unchanged"
        )
        assert_true(
            is_equal_approx(tuning.boost_speed_limit, 240.0),
            "boost speed limit must remain unchanged"
        )
        assert_equal(
            Vector3(
                tuning.pitch_angular_soft_start_degrees,
                tuning.yaw_angular_soft_start_degrees,
                tuning.roll_angular_soft_start_degrees
            ),
            Vector3(75.0, 75.0, 112.5),
            "production angular soft starts must match the approved profile"
        )
        assert_equal(
            Vector3(
                tuning.pitch_angular_limit_degrees,
                tuning.yaw_angular_limit_degrees,
                tuning.roll_angular_limit_degrees
            ),
            Vector3(100.0, 100.0, 150.0),
            "production angular limits must match the approved profile"
        )
```

Keep the existing assertions that mass is exactly `8500`, damping is zero, continuous collision detection is enabled, and collider size is exact.

- [ ] **Step 2: Run one RED**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: production-value assertions fail and the six new angular fields are missing.

- [ ] **Step 3: Update `FlightTuning` defaults**

Replace the first authority fields in `src/flight/flight_tuning.gd` with:

```gdscript
@export var forward_force: float = 150000.0
@export var reverse_force: float = 110000.0
@export var strafe_force: float = 150000.0
@export var pitch_torque: float = 190000.0
@export var yaw_torque: float = 230000.0
@export var roll_torque: float = 210000.0
@export var boost_multiplier: float = 1.8
```

Add immediately after the torque/boost block:

```gdscript
@export var pitch_angular_soft_start_degrees: float = 75.0
@export var pitch_angular_limit_degrees: float = 100.0
@export var yaw_angular_soft_start_degrees: float = 75.0
@export var yaw_angular_limit_degrees: float = 100.0
@export var roll_angular_soft_start_degrees: float = 112.5
@export var roll_angular_limit_degrees: float = 150.0
```

Do not change the existing speed, boost thermal, steering, AI, Smart Stabilize, auto-bank, or camera fields.

- [ ] **Step 4: Update the checked-in production resource**

Set these exact values in `config/flight/player_flight_tuning.tres`:

```text
forward_force = 150000.0
reverse_force = 110000.0
strafe_force = 150000.0
pitch_torque = 190000.0
yaw_torque = 230000.0
roll_torque = 210000.0
boost_multiplier = 1.8
pitch_angular_soft_start_degrees = 75.0
pitch_angular_limit_degrees = 100.0
yaw_angular_soft_start_degrees = 75.0
yaw_angular_limit_degrees = 100.0
roll_angular_soft_start_degrees = 112.5
roll_angular_limit_degrees = 150.0
```

Leave these exact existing values unchanged:

```text
normal_speed_limit = 160.0
boost_speed_limit = 240.0
ai_full_authority_error_speed = 12.0
ai_capture_error_speed = 0.75
ai_min_alignment_speed = 2.0
stabilize_linear_capture_speed = 4.0
stabilize_angular_capture_rate_degrees = 8.0
```

- [ ] **Step 5: Run and commit**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 39 suites`.

```powershell
git add src/flight/flight_tuning.gd config/flight/player_flight_tuning.tres tests/integration/test_player_scene.gd
git commit -m "feat: tune agile fighter authority"
```

---

### Task 3: Apply the envelope once to final composed torque

**Files:**
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/integration/test_ai_assisted_flight_controller.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`

**Interfaces:**
- Consumes `FlightAngularEnvelope.apply_to_torque(...)` from Task 1.
- Consumes the six production angular-rate fields from Task 2.
- Produces final applied torque which obeys the per-axis rate envelope.
- Preserves `get_last_pilot_torque_local() + get_last_assist_torque_local() == get_last_torque_local()` after attenuation.
- Preserves full opposing torque for Smart Stabilize, AI counter-torque, and direct counter-input above the limit.

- [ ] **Step 1: Add controller-integration RED coverage**

In `tests/integration/test_ai_assisted_flight_controller.gd`, before `controller.reset_runtime_state()`, add:

```gdscript
    controller.set_flight_mode(FlightMode.Value.MANUAL)

    player.angular_velocity = Vector3(0.0, deg_to_rad(87.5), 0.0)
    Input.action_press(&"yaw_left")
    controller._physics_process(1.0 / 60.0)
    Input.action_release(&"yaw_left")
    assert_true(
        controller.get_last_torque_local().y > 0.0
        and controller.get_last_torque_local().y
        < controller.tuning.yaw_torque,
        "same-direction yaw torque must soften inside the angular envelope"
    )

    player.angular_velocity = Vector3(0.0, deg_to_rad(100.0), 0.0)
    Input.action_press(&"yaw_left")
    controller._physics_process(1.0 / 60.0)
    Input.action_release(&"yaw_left")
    assert_true(
        is_zero_approx(controller.get_last_torque_local().y),
        "same-direction yaw torque must stop at the yaw limit"
    )

    player.angular_velocity = Vector3(0.0, deg_to_rad(120.0), 0.0)
    Input.action_press(&"yaw_right")
    controller._physics_process(1.0 / 60.0)
    Input.action_release(&"yaw_right")
    assert_true(
        is_equal_approx(
            controller.get_last_torque_local().y,
            -controller.tuning.yaw_torque
        ),
        "direct counter-yaw must retain full torque above the limit"
    )

    player.angular_velocity = Vector3(0.0, deg_to_rad(120.0), 0.0)
    Input.action_press(&"smart_stabilize")
    controller._physics_process(1.0 / 60.0)
    Input.action_release(&"smart_stabilize")
    assert_true(
        is_equal_approx(
            controller.get_last_torque_local().y,
            -controller.tuning.yaw_torque
        ),
        "Smart Stabilize must retain full counter-yaw above the limit"
    )
    assert_true(
        controller.get_last_torque_local().is_equal_approx(
            controller.get_last_pilot_torque_local()
            + controller.get_last_assist_torque_local()
        ),
        "applied torque telemetry must preserve pilot plus assist split"
    )

    player.angular_velocity = Vector3(0.0, deg_to_rad(120.0), 0.0)
    controller._physics_process(1.0 / 60.0)
    assert_equal(
        controller.get_last_torque_local(),
        Vector3.ZERO,
        "Inertial no-input state must not create artificial torque"
    )

    controller.set_flight_mode(FlightMode.Value.AI_ASSISTED)
    player.angular_velocity = Vector3.ZERO
    Input.action_press(&"yaw_left")
    controller._physics_process(1.0 / 60.0)
    Input.action_release(&"yaw_left")
    assert_true(
        absf(controller.get_last_torque_local().y)
        <= controller.tuning.yaw_torque + 0.01,
        "pilot plus AI yaw must remain inside one legal torque command"
    )
```

Add cleanup at the end if not already present:

```gdscript
    Input.action_release(&"yaw_left")
    Input.action_release(&"yaw_right")
```

In `tests/unit/test_ship_flight_controller_state.gd`, add initial and reset assertions that the split still sums to the final torque:

```gdscript
    assert_equal(
        controller.get_last_torque_local(),
        controller.get_last_pilot_torque_local()
        + controller.get_last_assist_torque_local(),
        "initial torque telemetry split must sum to final torque"
    )
```

Repeat the same assertion after `controller.reset_runtime_state()` with message:

```text
reset torque telemetry split must sum to final torque
```

- [ ] **Step 2: Run one RED**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: same-direction torque remains unattenuated near/at the limit, so the new integration assertions fail.

- [ ] **Step 3: Add final-torque envelope integration**

In `ShipFlightController._physics_process()`, keep all existing force/torque composition unchanged through the first:

```gdscript
output.finalize_totals()
```

Immediately after that call, insert:

```gdscript
    var requested_torque := output.torque_local
    var applied_torque := FlightAngularEnvelope.apply_to_torque(
        requested_torque,
        local_angular,
        Vector3(
            tuning.pitch_angular_soft_start_degrees,
            tuning.yaw_angular_soft_start_degrees,
            tuning.roll_angular_soft_start_degrees
        ),
        Vector3(
            tuning.pitch_angular_limit_degrees,
            tuning.yaw_angular_limit_degrees,
            tuning.roll_angular_limit_degrees
        )
    )
    var torque_ratio := Vector3(
        _applied_axis_ratio(requested_torque.x, applied_torque.x),
        _applied_axis_ratio(requested_torque.y, applied_torque.y),
        _applied_axis_ratio(requested_torque.z, applied_torque.z)
    )
    output.pilot_torque_local = Vector3(
        output.pilot_torque_local.x * torque_ratio.x,
        output.pilot_torque_local.y * torque_ratio.y,
        output.pilot_torque_local.z * torque_ratio.z
    )
    output.assist_torque_local = Vector3(
        output.assist_torque_local.x * torque_ratio.x,
        output.assist_torque_local.y * torque_ratio.y,
        output.assist_torque_local.z * torque_ratio.z
    )
    output.finalize_totals()
```

Add this static helper near the bottom of `ship_flight_controller.gd`, before `reset_runtime_state()`:

```gdscript
static func _applied_axis_ratio(
    requested: float,
    applied: float
) -> float:
    if absf(requested) <= 0.000001:
        return 1.0
    return clampf(applied / requested, 0.0, 1.0)
```

Do not apply the envelope in `FlightModel`, the AI solver, Smart Stabilize solver, or input layer. It must run once on the actual final composed torque.

Do not change force composition, `_body.apply_central_force(...)`, or `_body.apply_torque(...)`; the existing final `output.torque_local` is what `_body.apply_torque(...)` must receive.

- [ ] **Step 4: Run focused tests and inertial verification**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/verify_inertial_velocity.gd
```

Required:

```text
PASS: 39 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
```

- [ ] **Step 5: Commit controller integration**

```powershell
git add src/player/ship_flight_controller.gd tests/integration/test_ai_assisted_flight_controller.gd tests/unit/test_ship_flight_controller_state.gd
git commit -m "feat: cap agile fighter angular rates"
```

---

### Task 4: Documentation, authoritative verification, and manual acceptance

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/deferred-milestones.md`
- Modify implementation files only if fresh verifier evidence identifies a concrete defect.

**Interfaces:**
- Consumes Tasks 1–3.
- Produces documented and verified agile-fighter handling evidence.

- [ ] **Step 1: Update README before verification**

Update the current milestone bullets to state:

```text
agile-fighter authority with 150 kN forward/strafe thrust, 110 kN reverse thrust, and 190/230/210 kNm pitch/yaw/roll torque;
smooth physical angular-rate envelopes at 100 deg/s pitch, 100 deg/s yaw, and 150 deg/s roll;
opposing counter-torque remains fully available above every angular limit.
```

In the flight-mode explanation, state that all modes use the same final per-axis angular-rate envelope and that Smart Stabilize/AI counter-torque is not weakened by the cap.

Change the runner target from:

```text
PASS: 38 suites
```

to:

```text
PASS: 39 suites
```

- [ ] **Step 2: Record verification-pending status**

At the top of `docs/superpowers/plans/deferred-milestones.md`, after the introductory paragraph, insert:

```markdown
## Active correction: Agile Fighter Maneuverability

- Approved design: `docs/superpowers/specs/2026-08-06-agile-fighter-maneuverability-design.md`.
- Implementation plan: `docs/superpowers/plans/2026-08-06-agile-fighter-maneuverability.md`.
- Status: implementation complete; Windows automated and manual verification pending.
- Authority: 150 kN forward/strafe, 110 kN reverse, 190/230/210 kNm pitch/yaw/roll.
- Angular limits: 100 deg/s pitch, 100 deg/s yaw, 150 deg/s roll.
- Automatic counter-torque remains limited to player authority and remains fully available above the angular limits.
```

Do not delete or rewrite the historical deferred AI/Smart Stabilize requirements in that file.

- [ ] **Step 3: Run the complete Windows verifier once**

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify\verify.ps1
```

Required output:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 39 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
==> Boot main scene briefly
```

No parser error, path error, runtime error, orphan node, retained resource, or boot error is acceptable.

- [ ] **Step 4: Debug only from fresh first-failure evidence**

If the verifier fails, read the first complete assertion or stack trace, fix the originating contract, run that focused suite once, and rerun the full verifier. Do not lower approved authority, remove angular-envelope assertions, weaken Smart Stabilize counter-torque, or change mass/collider values merely to make tests pass.

- [ ] **Step 5: Run one Windows manual session**

```powershell
godot --path .
```

Verify:

1. Pitch and yaw respond quickly from rest.
2. Roll responds faster than pitch/yaw but remains controllable.
3. Holding pitch or yaw reaches a stable rate near `100 deg/s` rather than accelerating indefinitely.
4. Holding roll reaches a stable rate near `150 deg/s`.
5. Releasing rotation in Inertial preserves the current angular rate.
6. Applying opposite rotation input above a limit produces strong immediate counter-torque.
7. Holding `X` above a limit strongly arrests rotation instead of being weakened by the cap.
8. Sideways and vertical acceleration feel substantially stronger.
9. Reverse thrust provides meaningful braking.
10. Combined translation does not gain diagonal extra authority.
11. AI Assisted remains aggressive but does not exceed direct player authority.
12. Assisted, Inertial, primary fire, boost heat/lockout, cameras, pause, settings persistence, reset, collisions, HUD vectors, exact muzzles, and exact thrusters remain functional.

- [ ] **Step 6: Close the milestone only after both gates pass**

Replace the active-correction status line with:

```text
- Status: VERIFIED — PASS: 39 suites, zero inertial speed/direction drift, clean main-scene boot, and Windows manual acceptance passed.
```

- [ ] **Step 7: Commit documentation closure and review scope**

```powershell
git add README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "docs: verify agile fighter maneuverability"
git status --short
git log --oneline -6
git diff --stat HEAD~4..HEAD
```

Expected changed scope: one pure angular-envelope helper, flight tuning/resource, existing ship controller, focused tests, and documentation only. No scene hierarchy, assets, input map, camera, combat, projectile, workflow, or raw Blender files.
