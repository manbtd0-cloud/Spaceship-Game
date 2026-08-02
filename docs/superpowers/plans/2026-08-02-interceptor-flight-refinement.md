# Interceptor Flight Refinement and Hero Ship Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the verified six-axis prototype into an agile simcade interceptor with nose-led assisted turns, total-speed soft envelopes, thermal boost lockout, high-speed camera and room support, and the normalized Small Sci-Fi Fighter as the only player visual.

**Architecture:** Keep the current `RigidBody3D`, collider, `FlightCommand`, pure force/torque model, input source, controller, sibling camera rig, HUD, and flight-room boundaries. Add small pure helpers for speed attenuation, boost thermal state, velocity-vector steering, and coordinated bank state; let `ShipFlightController` own runtime state and apply only forces/torques. Generate one audited runtime GLB through a repeatable Blender script, then replace only the player visual subtree.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, GL Compatibility renderer, Blender Python API, PowerShell, Git.

## Global Constraints

- Work on `agent/playable-flight-room`; do not implement on `main`.
- Godot version is exactly 4.7.1 Standard and renderer remains GL Compatibility.
- Local `-Z` is forward and local `+Y` is up.
- Player mass remains `8500.0`, gravity remains `0.0`, built-in linear/angular damping remain `0.0`, and continuous collision detection remains enabled.
- Gameplay collision remains the existing simple `8 x 2.5 x 12 m` box; imported visual geometry never defines physics collision.
- Normal total-speed attenuation starts at `120 m/s` and reaches zero increasing-speed authority at `160 m/s`.
- Boosted attenuation starts at `180 m/s` and reaches zero increasing-speed authority at `240 m/s`.
- Never assign, rotate, normalize, or hard-clamp `RigidBody3D.linear_velocity` during ordinary flight.
- Ending boost above `160 m/s` preserves excess momentum.
- Boost heat rises at `1.0 / 12.0` per second, cools at `1.0 / 15.0` per second, locks at `1.0`, and recovers at or below `0.60`.
- Boost amplifies all translational axes but never rotational torque.
- Assisted mode may add drift damping, perpendicular nose-steering force, and coordinated roll torque; manual mode adds none of these.
- Mode switches preserve transform, linear velocity, angular velocity, heat, and lockout state.
- Controls are W/S thrust, Q/E lateral strafe, Space/Ctrl vertical strafe, mouse or arrows pitch/yaw, A/D roll, Shift boost, F mode, R reset, Escape capture.
- Raw `.blend`, `.fbx`, `.obj`, and `.stl` files remain source-only. Gameplay scenes reference only `assets/runtime/` GLB files.
- `assets/runtime/ships/player/small_sci_fi_fighter.glb` is mandatory; there is no procedural visual fallback.
- Do not add combat, weapons, damage, atmospheric lift/drag, gamepad support, alternate ships, missions, enemy AI, world streaming, detailed mesh collision, final audio, or final VFX.
- Run only local verification; do not add or trigger GitHub Actions.

## File Map

### Create

- `src/flight/flight_speed_envelope.gd` — attenuate only force that increases total speed.
- `src/flight/boost_thermal_state.gd` — immutable-style thermal step result and recovery math.
- `src/flight/flight_steering_math.gd` — bounded perpendicular assisted steering force.
- `src/flight/coordinated_turn_state.gd` — bounded generated bank offset/rate and roll command.
- `src/player/ship_visual_controller.gd` — read-only engine-glow response to effective boost.
- `tools/assets/export_small_sci_fi_fighter.py` — deterministic Blender cleanup, scale, axis markers, GLB export, and manifest.
- `tools/assets/export-small-fighter.ps1` — Blender executable resolution and export wrapper.
- `assets/licenses/small_sci_fi_fighter/PROVENANCE.md` — exact source and redistribution status.
- `tests/unit/test_flight_speed_envelope.gd`
- `tests/unit/test_boost_thermal_state.gd`
- `tests/unit/test_flight_steering_math.gd`
- `tests/unit/test_coordinated_turn_state.gd`
- `tests/integration/test_hero_ship_asset.gd`
- Generated locally: `assets/runtime/ships/player/small_sci_fi_fighter.glb`
- Generated locally: `assets/runtime/ships/player/small_sci_fi_fighter.manifest.json`

### Modify

- `project.godot` — revised physical key bindings and digital attitude actions.
- `src/input/player_input_math.gd` — mouse plus arrow pitch/yaw and A/D roll composition.
- `src/input/player_input_source.gd` — sample revised actions.
- `src/flight/flight_tuning.gd` — all data-driven flight, thermal, bank, and camera values.
- `src/flight/flight_model.gd` — all-axis boost, separate torques, soft envelope, damping, and steering force.
- `config/flight/player_flight_tuning.tres` — approved initial values.
- `src/player/ship_flight_controller.gd` — thermal/bank state, body mass input, telemetry, and reset API.
- `src/flight_room/flight_room_controller.gd` — reset controller runtime state.
- `src/camera/chase_camera_math.gd`
- `src/camera/chase_camera_rig.gd`
- `scenes/camera/chase_camera_rig.tscn`
- `src/ui/flight_hud.gd`
- `scenes/ui/flight_hud.tscn`
- `scenes/player/player_interceptor.tscn`
- `scenes/flight_room/flight_room.tscn`
- `tests/unit/test_player_input_math.gd`
- `tests/unit/test_flight_model.gd`
- `tests/unit/test_chase_camera_math.gd`
- `tests/integration/test_player_scene.gd`
- `tests/integration/test_flight_room_scene.gd`
- `tests/test_runner.gd`
- `tools/verify/verify.ps1`
- `assets/inventory/ASSET_INVENTORY.md`
- `README.md`

---

### Task 1: Revised Pilot Input Contract

**Files:**
- Modify: `project.godot`
- Modify: `src/input/player_input_math.gd`
- Modify: `src/input/player_input_source.gd`
- Modify: `tests/unit/test_player_input_math.gd`

**Interfaces:**
- Produces `PlayerInputMath.compose_rotation(mouse_delta, pitch_up, pitch_down, yaw_left, yaw_right, roll_left, roll_right, mouse_sensitivity, max_mouse_command) -> Vector3`.
- Produces input actions `pitch_up`, `pitch_down`, `yaw_left`, and `yaw_right`.
- Preserves `FlightCommand.translation`, `FlightCommand.rotation`, and `FlightCommand.boost`.

- [ ] **Step 1: Replace the rotation assertions with the failing revised contract**

Use this test body in `tests/unit/test_player_input_math.gd` after the existing translation checks:

```gdscript
var mouse_and_keys := PlayerInputMath.compose_rotation(
    Vector2(100.0, -50.0),
    0.25,
    0.0,
    0.0,
    0.4,
    1.0,
    0.0,
    0.01,
    1.0
)
assert_equal(
    mouse_and_keys,
    Vector3(0.75, -1.0, -1.0),
    "mouse, arrows, and A/D roll must compose and clamp"
)

assert_equal(
    PlayerInputMath.compose_rotation(
        Vector2.ZERO,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        0.01,
        1.0
    ),
    Vector3.ZERO,
    "opposed digital attitude inputs must cancel"
)

for action: StringName in [
    &"pitch_up", &"pitch_down", &"yaw_left", &"yaw_right"
]:
    assert_true(InputMap.has_action(action), "missing input action: %s" % action)
```

- [ ] **Step 2: Run the verifier and observe RED**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected: the input suite fails because `compose_rotation()` still has the old signature and the four arrow actions do not exist.

- [ ] **Step 3: Implement the new pure rotation composition**

Replace `compose_rotation()` with:

```gdscript
static func compose_rotation(
    mouse_delta: Vector2,
    pitch_up: float,
    pitch_down: float,
    yaw_left: float,
    yaw_right: float,
    roll_left: float,
    roll_right: float,
    mouse_sensitivity: float,
    max_mouse_command: float
) -> Vector3:
    var limit := maxf(max_mouse_command, 0.0)
    var mouse_pitch := -mouse_delta.y * mouse_sensitivity
    var mouse_yaw := -mouse_delta.x * mouse_sensitivity
    return Vector3(
        clampf(
            mouse_pitch
            + clampf(pitch_up, 0.0, 1.0)
            - clampf(pitch_down, 0.0, 1.0),
            -limit,
            limit
        ),
        clampf(
            mouse_yaw
            + clampf(yaw_left, 0.0, 1.0)
            - clampf(yaw_right, 0.0, 1.0),
            -limit,
            limit
        ),
        clampf(
            clampf(roll_right, 0.0, 1.0)
            - clampf(roll_left, 0.0, 1.0),
            -1.0,
            1.0
        )
    )
```

- [ ] **Step 4: Remap the physical controls in `project.godot`**

Use these exact physical keycodes:

```text
strafe_left  = Q = 81
strafe_right = E = 69
roll_left    = A = 65
roll_right   = D = 68
pitch_up     = Up Arrow = 4194320
pitch_down   = Down Arrow = 4194322
yaw_left     = Left Arrow = 4194319
yaw_right    = Right Arrow = 4194321
```

Keep W/S, Space/Ctrl, Shift, F, R, Escape, and unused fire actions unchanged.

- [ ] **Step 5: Update `PlayerInputSource`**

Add the four digital actions to `REQUIRED_ACTIONS`. Call `compose_rotation()` as:

```gdscript
command.rotation = PlayerInputMath.compose_rotation(
    _mouse_delta,
    _strength(&"pitch_up"),
    _strength(&"pitch_down"),
    _strength(&"yaw_left"),
    _strength(&"yaw_right"),
    _strength(&"roll_left"),
    _strength(&"roll_right"),
    mouse_sensitivity,
    max_mouse_command
)
```

Keep translation sampling on `strafe_left/right`, which now resolve to Q/E.

- [ ] **Step 6: Verify GREEN**

Run the full verifier. Expected: the existing seven suites pass with the revised input contract and no warnings.

- [ ] **Step 7: Commit**

```bash
git add project.godot src/input/player_input_math.gd src/input/player_input_source.gd tests/unit/test_player_input_math.gd
git commit -m "feat: revise interceptor pilot controls"
```

---

### Task 2: Data-Driven Soft Speed Envelope and Axis-Specific Torque

**Files:**
- Create: `src/flight/flight_speed_envelope.gd`
- Create: `tests/unit/test_flight_speed_envelope.gd`
- Modify: `src/flight/flight_tuning.gd`
- Modify: `src/flight/flight_model.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Modify: `tests/unit/test_flight_model.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `FlightSpeedEnvelope.authority(speed_mps, soft_start_mps, soft_limit_mps) -> float`.
- Produces `FlightSpeedEnvelope.apply_to_force(force_local, velocity_local, soft_start_mps, soft_limit_mps) -> Vector3`.
- `FlightModel.compute()` keeps its current four-argument signature in this task.

- [ ] **Step 1: Add and register the failing envelope suite**

Create `tests/unit/test_flight_speed_envelope.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_equal_approx(FlightSpeedEnvelope.authority(100.0, 120.0, 160.0), 1.0),
        "authority below onset"
    )
    var middle := FlightSpeedEnvelope.authority(140.0, 120.0, 160.0)
    assert_true(middle > 0.0 and middle < 1.0, "authority inside envelope")
    assert_true(
        is_equal_approx(FlightSpeedEnvelope.authority(160.0, 120.0, 160.0), 0.0),
        "authority at limit"
    )

    var velocity := Vector3(0.0, 0.0, -160.0)
    assert_equal(
        FlightSpeedEnvelope.apply_to_force(
            Vector3(0.0, 0.0, -100.0), velocity, 120.0, 160.0
        ),
        Vector3.ZERO,
        "speed-increasing force must stop at limit"
    )
    assert_equal(
        FlightSpeedEnvelope.apply_to_force(
            Vector3(0.0, 0.0, 100.0), velocity, 120.0, 160.0
        ),
        Vector3(0.0, 0.0, 100.0),
        "braking force must remain available"
    )
    assert_equal(
        FlightSpeedEnvelope.apply_to_force(
            Vector3(100.0, 0.0, 0.0), velocity, 120.0, 160.0
        ),
        Vector3(100.0, 0.0, 0.0),
        "perpendicular redirecting force must remain available"
    )
```

Register it after `test_flight_model.gd`. Expected suite count after implementation: `PASS: 8 suites`.

- [ ] **Step 2: Verify RED**

Run the verifier. Expected: `FlightSpeedEnvelope` is missing.

- [ ] **Step 3: Implement the pure envelope helper**

Create:

```gdscript
class_name FlightSpeedEnvelope
extends RefCounted

static func authority(
    speed_mps: float,
    soft_start_mps: float,
    soft_limit_mps: float
) -> float:
    var start := maxf(soft_start_mps, 0.0)
    var limit := maxf(soft_limit_mps, start + 0.001)
    var t := clampf((maxf(speed_mps, 0.0) - start) / (limit - start), 0.0, 1.0)
    var smooth_t := t * t * (3.0 - 2.0 * t)
    return 1.0 - smooth_t

static func apply_to_force(
    force_local: Vector3,
    velocity_local: Vector3,
    soft_start_mps: float,
    soft_limit_mps: float
) -> Vector3:
    var speed := velocity_local.length()
    if speed < 0.001 or force_local.length_squared() < 0.000001:
        return force_local

    var velocity_direction := velocity_local / speed
    var increasing_magnitude := maxf(force_local.dot(velocity_direction), 0.0)
    var increasing_force := velocity_direction * increasing_magnitude
    var redirecting_or_braking_force := force_local - increasing_force
    return (
        redirecting_or_braking_force
        + increasing_force * authority(speed, soft_start_mps, soft_limit_mps)
    )
```

- [ ] **Step 4: Expand `FlightTuning` with exact initial values**

Replace the old shared rotation/damping fields with:

```gdscript
@export var forward_force: float = 120000.0
@export var reverse_force: float = 50000.0
@export var strafe_force: float = 65000.0
@export var pitch_torque: float = 52000.0
@export var yaw_torque: float = 48000.0
@export var roll_torque: float = 60000.0
@export var boost_multiplier: float = 1.8

@export var normal_speed_soft_start: float = 120.0
@export var normal_speed_limit: float = 160.0
@export var boost_speed_soft_start: float = 180.0
@export var boost_speed_limit: float = 240.0

@export var assist_lateral_damping: float = 12000.0
@export var assist_vertical_damping: float = 12000.0
@export var assist_angular_damping: float = 35000.0

@export var boost_heat_per_second: float = 1.0 / 12.0
@export var boost_cooling_per_second: float = 1.0 / 15.0
@export_range(0.0, 1.0) var boost_recovery_threshold: float = 0.60

@export var assist_steering_strength: float = 1.25
@export var assist_min_steering_speed: float = 8.0
@export var assist_max_steering_acceleration: float = 18.0

@export var auto_bank_max_degrees: float = 22.0
@export var auto_bank_response: float = 5.0

@export var camera_speed_pullback: float = 0.05
@export var camera_max_pullback: float = 14.0
@export var camera_forward_look_ahead: float = 10.0
@export var camera_normal_max_fov: float = 82.0
@export var camera_boost_max_fov: float = 85.0
@export var camera_boost_fov_bonus: float = 1.0
```

Mirror every value in `config/flight/player_flight_tuning.tres`; remove serialized `rotation_torque`, `assist_linear_damping`, and the old angular field value.

- [ ] **Step 5: Update `FlightModel.compute()`**

Build translation, multiply all axes by boost, apply the active envelope, then add assisted damping:

```gdscript
var force_local := Vector3(
    command.translation.x * tuning.strafe_force,
    command.translation.y * tuning.strafe_force,
    command.translation.z * longitudinal_force
)
var boost_factor := lerpf(
    1.0,
    tuning.boost_multiplier,
    clampf(command.boost, 0.0, 1.0)
)
force_local *= boost_factor

var soft_start := (
    tuning.boost_speed_soft_start
    if command.boost > 0.0
    else tuning.normal_speed_soft_start
)
var soft_limit := (
    tuning.boost_speed_limit
    if command.boost > 0.0
    else tuning.normal_speed_limit
)
output.force_local = FlightSpeedEnvelope.apply_to_force(
    force_local,
    local_linear_velocity,
    soft_start,
    soft_limit
)

output.torque_local = Vector3(
    command.rotation.x * tuning.pitch_torque,
    command.rotation.y * tuning.yaw_torque,
    command.rotation.z * tuning.roll_torque
)

if command.mode == FlightMode.Value.ASSISTED:
    output.force_local.x -= (
        local_linear_velocity.x * tuning.assist_lateral_damping
    )
    output.force_local.y -= (
        local_linear_velocity.y * tuning.assist_vertical_damping
    )
    output.torque_local -= (
        local_angular_velocity * tuning.assist_angular_damping
    )
```

Do not damp local Z velocity.

- [ ] **Step 6: Update flight-model tests**

Keep manual momentum assertions. Add assertions that full boost scales X/Y/Z, separate torques use their own values, normal forward force is zero at `160 m/s`, boosted forward force remains non-zero at `160 m/s`, and reverse braking force remains available above `160 m/s`.

- [ ] **Step 7: Verify GREEN and commit**

Run the verifier; expected `PASS: 8 suites`.

```bash
git add src/flight/flight_speed_envelope.gd src/flight/flight_tuning.gd src/flight/flight_model.gd config/flight/player_flight_tuning.tres tests/unit/test_flight_speed_envelope.gd tests/unit/test_flight_model.gd tests/test_runner.gd
git commit -m "feat: add interceptor speed envelopes"
```

---

### Task 3: Sustained Boost Thermal Lockout

**Files:**
- Create: `src/flight/boost_thermal_state.gd`
- Create: `tests/unit/test_boost_thermal_state.gd`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `src/flight_room/flight_room_controller.gd`
- Modify: `tests/integration/test_player_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `BoostThermalState.advance(...) -> BoostThermalState`.
- Adds controller getters `get_boost_heat()`, `is_boost_locked_out()`, `get_boost_recovery_progress()`, and `get_active_speed_limit()`.
- Adds `ShipFlightController.reset_runtime_state()`.

- [ ] **Step 1: Add the failing thermal suite**

Create:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var heat := 0.0
    var locked := false
    var elapsed := 0.0
    while not locked and elapsed < 13.0:
        var state := BoostThermalState.advance(
            heat, locked, 1.0, 1.0, 1.0 / 60.0,
            1.0 / 12.0, 1.0 / 15.0, 0.60
        )
        heat = state.heat
        locked = state.locked_out
        elapsed += 1.0 / 60.0
    assert_true(elapsed >= 11.9 and elapsed <= 12.1, "twelve-second endurance")
    assert_true(locked, "maximum heat must lock boost")

    var recovery_elapsed := 0.0
    while locked and recovery_elapsed < 7.0:
        var state := BoostThermalState.advance(
            heat, locked, 0.0, 0.0, 1.0 / 60.0,
            1.0 / 12.0, 1.0 / 15.0, 0.60
        )
        heat = state.heat
        locked = state.locked_out
        recovery_elapsed += 1.0 / 60.0
    assert_true(
        recovery_elapsed >= 5.9 and recovery_elapsed <= 6.1,
        "six-second lockout recovery"
    )

    var idle := BoostThermalState.advance(
        0.5, false, 1.0, 0.0, 1.0,
        1.0 / 12.0, 1.0 / 15.0, 0.60
    )
    assert_true(idle.heat < 0.5, "boost without translation must cool")

    var x_state := BoostThermalState.advance(
        0.0, false, 1.0, 1.0, 1.0,
        1.0 / 12.0, 1.0 / 15.0, 0.60
    )
    var diagonal_state := BoostThermalState.advance(
        0.0, false, 1.0, 0.25, 1.0,
        1.0 / 12.0, 1.0 / 15.0, 0.60
    )
    assert_true(
        is_equal_approx(x_state.heat, diagonal_state.heat),
        "translation magnitude must not weight heat rate"
    )
```

Register after the speed-envelope suite. Expected final for this task: `PASS: 9 suites`.

- [ ] **Step 2: Verify RED**

Expected: `BoostThermalState` missing.

- [ ] **Step 3: Implement the thermal result/state class**

Create:

```gdscript
class_name BoostThermalState
extends RefCounted

var heat: float = 0.0
var locked_out: bool = false
var effective_boost: float = 0.0

static func advance(
    current_heat: float,
    was_locked_out: bool,
    boost_requested: float,
    translation_magnitude: float,
    delta: float,
    heat_per_second: float,
    cooling_per_second: float,
    recovery_threshold: float
) -> BoostThermalState:
    var result := BoostThermalState.new()
    result.heat = clampf(current_heat, 0.0, 1.0)
    result.locked_out = was_locked_out

    var wants_boost := (
        boost_requested > 0.0
        and translation_magnitude > 0.001
    )

    if result.locked_out:
        result.heat = maxf(
            0.0,
            result.heat - maxf(cooling_per_second, 0.0) * maxf(delta, 0.0)
        )
        if result.heat <= clampf(recovery_threshold, 0.0, 1.0):
            result.locked_out = false
        result.effective_boost = 0.0
        return result

    if wants_boost:
        result.heat = minf(
            1.0,
            result.heat + maxf(heat_per_second, 0.0) * maxf(delta, 0.0)
        )
        if result.heat >= 1.0:
            result.locked_out = true
            result.effective_boost = 0.0
        else:
            result.effective_boost = clampf(boost_requested, 0.0, 1.0)
        return result

    result.heat = maxf(
        0.0,
        result.heat - maxf(cooling_per_second, 0.0) * maxf(delta, 0.0)
    )
    result.effective_boost = 0.0
    return result

static func recovery_progress(heat_value: float, recovery_threshold: float) -> float:
    var threshold := clampf(recovery_threshold, 0.0, 0.999)
    return clampf((1.0 - clampf(heat_value, 0.0, 1.0)) / (1.0 - threshold), 0.0, 1.0)
```

- [ ] **Step 4: Integrate thermal state into `ShipFlightController`**

Add `_boost_heat` and `_boost_locked_out`. In `_physics_process(delta)`, sample the command, advance state with the requested boost and `command.translation.length()`, store the result, then replace `command.boost` with `effective_boost` before calling `FlightModel.compute()`.

Add exact getters:

```gdscript
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

func reset_runtime_state() -> void:
    _boost_heat = 0.0
    _boost_locked_out = false
    _boost_amount = 0.0
```

- [ ] **Step 5: Reset thermal state only during room reset**

Call `_controller.reset_runtime_state()` inside `FlightRoomController.reset_player()` before unfreezing the body. Mode changes must not call it.

- [ ] **Step 6: Strengthen the player-scene contract**

Assert initial heat is zero, lockout is false, and active speed limit is `160.0`.

- [ ] **Step 7: Verify GREEN and commit**

Expected: `PASS: 9 suites`.

```bash
git add src/flight/boost_thermal_state.gd src/player/ship_flight_controller.gd src/flight_room/flight_room_controller.gd tests/unit/test_boost_thermal_state.gd tests/integration/test_player_scene.gd tests/test_runner.gd
git commit -m "feat: add thermal boost lockout"
```

---

### Task 4: Force-Based Nose-Led Assisted Steering

**Files:**
- Create: `src/flight/flight_steering_math.gd`
- Create: `tests/unit/test_flight_steering_math.gd`
- Modify: `src/flight/flight_model.gd`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_flight_model.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `FlightSteeringMath.assisted_force(local_velocity, forward_input, body_mass, steering_strength, minimum_speed, maximum_acceleration) -> Vector3`.
- Extends `FlightModel.compute(..., body_mass: float = 1.0) -> FlightOutput`.

- [ ] **Step 1: Add the failing steering suite**

Create:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var velocity := Vector3(20.0, 0.0, -20.0)
    var force := FlightSteeringMath.assisted_force(
        velocity, 1.0, 8500.0, 1.25, 8.0, 18.0
    )
    assert_true(force.x < 0.0, "steering must bend rightward drift toward the nose")
    assert_true(
        absf(force.dot(velocity.normalized())) < 0.01,
        "steering force must remain perpendicular to velocity"
    )
    assert_true(
        force.length() <= 8500.0 * 18.0 + 0.01,
        "steering acceleration must be bounded"
    )
    assert_equal(
        FlightSteeringMath.assisted_force(
            velocity, 0.0, 8500.0, 1.25, 8.0, 18.0
        ),
        Vector3.ZERO,
        "no forward thrust means no nose steering"
    )
    assert_equal(
        FlightSteeringMath.assisted_force(
            Vector3(1.0, 0.0, 0.0), 1.0, 8500.0, 1.25, 8.0, 18.0
        ),
        Vector3.ZERO,
        "steering stays inactive below minimum speed"
    )
```

Register it. Expected after completion: `PASS: 10 suites`.

- [ ] **Step 2: Verify RED**

Expected: `FlightSteeringMath` missing.

- [ ] **Step 3: Implement the pure steering force**

```gdscript
class_name FlightSteeringMath
extends RefCounted

static func assisted_force(
    local_velocity: Vector3,
    forward_input: float,
    body_mass: float,
    steering_strength: float,
    minimum_speed: float,
    maximum_acceleration: float
) -> Vector3:
    var speed := local_velocity.length()
    var input_amount := clampf(forward_input, 0.0, 1.0)
    if input_amount <= 0.0 or speed < maxf(minimum_speed, 0.0):
        return Vector3.ZERO

    var velocity_direction := local_velocity / speed
    var desired_direction := Vector3.FORWARD
    var alignment := clampf(
        velocity_direction.dot(desired_direction),
        -1.0,
        1.0
    )
    var perpendicular_target := (
        desired_direction - velocity_direction * alignment
    )
    if perpendicular_target.length_squared() < 0.000001:
        return Vector3.ZERO

    var angle_factor := clampf(acos(alignment) / PI, 0.0, 1.0)
    var acceleration := minf(
        speed * maxf(steering_strength, 0.0) * angle_factor,
        maxf(maximum_acceleration, 0.0)
    ) * input_amount
    return (
        perpendicular_target.normalized()
        * acceleration
        * maxf(body_mass, 0.0)
    )
```

- [ ] **Step 4: Extend `FlightModel.compute()` and add steering only in assisted mode**

Add `body_mass: float = 1.0` as the fifth argument. Inside the assisted branch add:

```gdscript
output.force_local += FlightSteeringMath.assisted_force(
    local_linear_velocity,
    clampf(-command.translation.z, 0.0, 1.0),
    body_mass,
    tuning.assist_steering_strength,
    tuning.assist_min_steering_speed,
    tuning.assist_max_steering_acceleration
)
```

Manual mode must not call or reproduce this force.

- [ ] **Step 5: Pass `_body.mass` from the controller**

Use:

```gdscript
var output := FlightModel.compute(
    command,
    tuning,
    local_linear,
    local_angular,
    _body.mass
)
```

- [ ] **Step 6: Add model-level assisted/manual assertions**

In `test_flight_model.gd`, use a diagonal local velocity and forward input. Assert assisted output has steering force toward local `-Z`; assert the equivalent manual output does not receive the perpendicular steering term.

- [ ] **Step 7: Verify GREEN and commit**

Expected: `PASS: 10 suites`.

```bash
git add src/flight/flight_steering_math.gd src/flight/flight_model.gd src/player/ship_flight_controller.gd tests/unit/test_flight_steering_math.gd tests/unit/test_flight_model.gd tests/test_runner.gd
git commit -m "feat: add nose-led assisted steering"
```

---

### Task 5: Coordinated Assisted Banking

**Files:**
- Create: `src/flight/coordinated_turn_state.gd`
- Create: `tests/unit/test_coordinated_turn_state.gd`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/integration/test_player_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `CoordinatedTurnState.advance(current_offset, current_rate, yaw_input, manual_roll_input, delta, max_bank_degrees, response) -> CoordinatedTurnState`.
- Result fields are `bank_offset`, `bank_rate`, and `roll_command`.
- Adds `ShipFlightController.get_auto_bank_offset_degrees() -> float`.

- [ ] **Step 1: Add the failing bank-state suite**

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var offset := 0.0
    var rate := 0.0
    var state: CoordinatedTurnState
    for _step: int in range(180):
        state = CoordinatedTurnState.advance(
            offset, rate, 1.0, 0.0, 1.0 / 60.0, 22.0, 5.0
        )
        offset = state.bank_offset
        rate = state.bank_rate
    assert_true(offset < 0.0, "left yaw must generate left bank")
    assert_true(absf(rad_to_deg(offset)) <= 22.01, "bank must stay bounded")

    var overridden := CoordinatedTurnState.advance(
        offset, rate, 1.0, -1.0, 1.0 / 60.0, 22.0, 5.0
    )
    assert_true(is_equal_approx(overridden.bank_offset, 0.0), "manual roll resets generated offset")
    assert_true(is_equal_approx(overridden.roll_command, 0.0), "manual roll suppresses auto torque")

    var returning := CoordinatedTurnState.advance(
        deg_to_rad(-10.0), 0.0, 0.0, 0.0, 1.0 / 60.0, 22.0, 5.0
    )
    assert_true(returning.roll_command > 0.0, "released yaw must return generated bank toward zero")
```

Register it. Expected: `PASS: 11 suites` after implementation.

- [ ] **Step 2: Verify RED**

Expected: `CoordinatedTurnState` missing.

- [ ] **Step 3: Implement the generated-bank spring**

```gdscript
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
    var command_scale := maxf(omega * omega * maxf(maximum, 0.001), 0.001)
    result.roll_command = clampf(acceleration / command_scale, -1.0, 1.0)
    return result
```

- [ ] **Step 4: Integrate generated bank into the controller**

Store `_auto_bank_offset` and `_auto_bank_rate`. Before `FlightModel.compute()`:

```gdscript
var pilot_roll := command.rotation.z
if command.mode == FlightMode.Value.ASSISTED:
    var bank_state := CoordinatedTurnState.advance(
        _auto_bank_offset,
        _auto_bank_rate,
        command.rotation.y,
        pilot_roll,
        delta,
        tuning.auto_bank_max_degrees,
        tuning.auto_bank_response
    )
    _auto_bank_offset = bank_state.bank_offset
    _auto_bank_rate = bank_state.bank_rate
    command.rotation.z = clampf(
        pilot_roll + bank_state.roll_command,
        -1.0,
        1.0
    )
else:
    _auto_bank_offset = 0.0
    _auto_bank_rate = 0.0
```

`reset_runtime_state()` also zeroes both bank fields. Add:

```gdscript
func get_auto_bank_offset_degrees() -> float:
    return rad_to_deg(_auto_bank_offset)
```

Do not alter body orientation or angular velocity directly.

- [ ] **Step 5: Verify GREEN and commit**

Expected: `PASS: 11 suites`.

```bash
git add src/flight/coordinated_turn_state.gd src/player/ship_flight_controller.gd tests/unit/test_coordinated_turn_state.gd tests/integration/test_player_scene.gd tests/test_runner.gd
git commit -m "feat: add coordinated turn banking"
```

---

### Task 6: Thermal and Envelope HUD

**Files:**
- Modify: `src/ui/flight_hud.gd`
- Modify: `scenes/ui/flight_hud.tscn`
- Modify: `tests/integration/test_player_scene.gd`

**Interfaces:**
- Consumes controller thermal and active-limit getters from Tasks 3 and 5.
- Adds label paths `heat_label_path` and `envelope_label_path`.

- [ ] **Step 1: Extend the failing HUD scene contract**

Require:

```text
SafeArea/Layout/HeatLabel
SafeArea/Layout/EnvelopeLabel
```

Both must be `Label` nodes. Keep all existing labels.

- [ ] **Step 2: Verify RED**

Expected: the player integration suite reports both labels missing.

- [ ] **Step 3: Add HUD nodes and exported paths**

Increase the backdrop bottom to `232.0` and SafeArea bottom to `222.0`. Add `HeatLabel` after `BoostLabel` and `EnvelopeLabel` after it. Use the existing cyan/white palette and 14–16 px text.

- [ ] **Step 4: Render exact thermal/envelope states**

Use:

```gdscript
var heat_percent := roundi(_controller.get_boost_heat() * 100.0)
if _controller.is_boost_locked_out():
    _boost_label.text = "BOOST  OVERHEATED"
    _heat_label.text = "RECOVERY  %03d%%" % roundi(
        _controller.get_boost_recovery_progress() * 100.0
    )
elif _controller.get_boost_amount() > 0.0:
    _boost_label.text = "BOOST  ACTIVE"
    _heat_label.text = "HEAT  %03d%%" % heat_percent
else:
    _boost_label.text = "BOOST  READY"
    _heat_label.text = "HEAT  %03d%%" % heat_percent

_envelope_label.text = "ACTIVE ENVELOPE  %03d m/s" % roundi(
    _controller.get_active_speed_limit()
)
_controls_label.text = (
    "W/S THRUST   Q/E STRAFE   SPACE/CTRL VERTICAL   "
    + "MOUSE/ARROWS PITCH-YAW   A/D ROLL   SHIFT BOOST   F MODE   R RESET"
)
```

- [ ] **Step 5: Verify GREEN and commit**

Expected suite count remains `11`.

```bash
git add src/ui/flight_hud.gd scenes/ui/flight_hud.tscn tests/integration/test_player_scene.gd
git commit -m "feat: show boost heat and speed envelope"
```

---

### Task 7: High-Speed Chase Camera Refinement

**Files:**
- Modify: `src/camera/chase_camera_math.gd`
- Modify: `src/camera/chase_camera_rig.gd`
- Modify: `scenes/camera/chase_camera_rig.tscn`
- Modify: `tests/unit/test_chase_camera_math.gd`

**Interfaces:**
- `ChaseCameraRig` gains `@export var tuning: FlightTuning`.
- `desired_look_target()` gains `forward_look_ahead`.
- `desired_fov()` becomes piecewise across normal and boost limits.

- [ ] **Step 1: Replace camera tests with the failing high-speed contract**

Add assertions that:

```gdscript
var look_target := ChaseCameraMath.desired_look_target(
    Transform3D.IDENTITY,
    Vector3(0.0, 0.0, -100.0),
    0.12,
    10.0
)
assert_true(look_target.z < -20.0, "camera must predict velocity and nose direction")

assert_true(is_equal_approx(
    ChaseCameraMath.desired_fov(
        160.0, 0.0, 68.0, 160.0, 240.0, 82.0, 85.0, 1.0
    ),
    82.0
), "normal envelope FOV")
assert_true(is_equal_approx(
    ChaseCameraMath.desired_fov(
        240.0, 1.0, 68.0, 160.0, 240.0, 82.0, 85.0, 1.0
    ),
    85.0
), "boost envelope FOV clamp")
```

- [ ] **Step 2: Verify RED**

Expected: signature mismatch.

- [ ] **Step 3: Implement nose-aware look targeting and piecewise FOV**

```gdscript
static func desired_look_target(
    target_transform: Transform3D,
    world_velocity: Vector3,
    velocity_look_ahead: float,
    forward_look_ahead: float
) -> Vector3:
    var forward := target_transform.basis.orthonormalized() * Vector3.FORWARD
    return (
        target_transform.origin
        + world_velocity * maxf(velocity_look_ahead, 0.0)
        + forward * maxf(forward_look_ahead, 0.0)
    )

static func desired_fov(
    speed_mps: float,
    boost_amount: float,
    base_fov: float,
    normal_limit: float,
    boost_limit: float,
    normal_max_fov: float,
    boost_max_fov: float,
    boost_bonus: float
) -> float:
    var speed := maxf(speed_mps, 0.0)
    var normal_end := maxf(normal_limit, 0.001)
    var boost_end := maxf(boost_limit, normal_end + 0.001)
    var value: float
    if speed <= normal_end:
        var t := clampf(speed / normal_end, 0.0, 1.0)
        value = lerpf(base_fov, normal_max_fov, t * t * (3.0 - 2.0 * t))
    else:
        var t := clampf((speed - normal_end) / (boost_end - normal_end), 0.0, 1.0)
        value = lerpf(normal_max_fov, boost_max_fov, t * t * (3.0 - 2.0 * t))
    value += clampf(boost_amount, 0.0, 1.0) * maxf(boost_bonus, 0.0)
    return clampf(value, base_fov, maxf(boost_max_fov, base_fov))
```

- [ ] **Step 4: Make the rig consume `FlightTuning`**

Remove duplicated speed/FOV exports except base offset, smoothing, velocity look-ahead, and roll influence. Require `tuning`; disable processing with one clear error when absent. Use `tuning.camera_speed_pullback`, `camera_max_pullback`, `camera_forward_look_ahead`, the normal/boost limits, and camera FOV fields.

Set the tuning resource on `scenes/camera/chase_camera_rig.tscn` using `res://config/flight/player_flight_tuning.tres`. Set `max_fov` behavior to `85.0` through tuning and keep base FOV `68.0`.

- [ ] **Step 5: Verify GREEN and commit**

```bash
git add src/camera/chase_camera_math.gd src/camera/chase_camera_rig.gd scenes/camera/chase_camera_rig.tscn tests/unit/test_chase_camera_math.gd
git commit -m "feat: refine high-speed chase camera"
```

---

### Task 8: Extend the Single Flight Room

**Files:**
- Modify: `scenes/flight_room/flight_room.tscn`
- Modify: `tests/integration/test_flight_room_scene.gd`

**Interfaces:**
- Keeps the current root/node names.
- Extends `Course/NavigationRings`, adds `Course/SpeedMarkers`, expands distant references, reset floor, and boundary.

- [ ] **Step 1: Add the failing extended-room assertions**

Require:

```gdscript
assert_true(
    room.get_node("Course/NavigationRings").get_child_count() >= 9,
    "nine rings required"
)
assert_true(
    room.get_node("Course/SpeedMarkers").get_child_count() >= 12,
    "twelve speed markers required"
)
assert_true(
    room.get_node("Course/DistantReferenceShapes").get_child_count() >= 8,
    "eight distant references required"
)
var last_ring := room.get_node("Course/NavigationRings/Ring09") as Node3D
assert_true(last_ring.position.z <= -2400.0, "course must support boost-speed testing")
var room_controller := room.get_node("FlightRoomController") as FlightRoomController
assert_true(room_controller.boundary_radius >= 6000.0, "expanded boundary required")
```

- [ ] **Step 2: Verify RED**

Expected: missing `SpeedMarkers`, ring count, reference count, and boundary assertions fail.

- [ ] **Step 3: Extend the route with exact ring centers**

Keep Rings 01–05 unchanged. Add:

```text
Ring06: (70, -35, -1200), rotation (-6, -15, 10)
Ring07: (-110, 55, -1550), rotation (10, 20, -14)
Ring08: (90, 20, -1950), rotation (-8, -18, 12)
Ring09: (0, 0, -2400), rotation (0, 0, 0)
```

Use the same four-piece ring mesh structure.

- [ ] **Step 4: Add twelve speed markers**

Create `Course/SpeedMarkers` with emissive markers at Z values `-1000`, `-1125`, `-1250`, `-1375`, `-1500`, `-1650`, `-1800`, `-1950`, `-2100`, `-2250`, `-2400`, and `-2600`. Alternate X between `-28` and `28`; alternate Y between `-12` and `12`.

- [ ] **Step 5: Expand references and safety volumes**

Add four large dim references beyond `-1800`. Change reset shape to `Vector3(12000, 60, 12000)`, center ResetVolume at `(0, -350, -1200)`, and set `boundary_radius = 6000.0`. Keep the near-spawn handling section unchanged.

- [ ] **Step 6: Verify GREEN and commit**

```bash
git add scenes/flight_room/flight_room.tscn tests/integration/test_flight_room_scene.gd
git commit -m "feat: extend interceptor flight course"
```

---

### Task 9: Repeatable Blender Export and Provenance Gate

**Files:**
- Create: `tools/assets/export_small_sci_fi_fighter.py`
- Create: `tools/assets/export-small-fighter.ps1`
- Create: `assets/licenses/small_sci_fi_fighter/PROVENANCE.md`
- Modify: `assets/inventory/ASSET_INVENTORY.md`
- Generated: `assets/runtime/ships/player/small_sci_fi_fighter.glb`
- Generated: `assets/runtime/ships/player/small_sci_fighter.manifest.json`

**Interfaces:**
- Blender source: `assets/source/ships/player_candidates/small_sci_fi_fighter/Small Sci-Fi Fighter.blend`.
- Runtime output: `assets/runtime/ships/player/small_sci_fi_fighter.glb`.
- Exported GLB contains `SmallSciFiFighterMesh`, `ForwardMarker`, and `UpMarker` under `SmallSciFiFighter`.

- [ ] **Step 1: Record honest provenance before creating a derivative**

Create `PROVENANCE.md` with:

```markdown
# Small Sci-Fi Fighter Provenance

- Preserved source: `assets/source/ships/player_candidates/small_sci_fi_fighter/Small Sci-Fi Fighter.blend`
- First repository commit containing the source: `ceabb61d90bf2b0b79ac00c1f4cc5abf2d5df2f4`
- Selected role: Shattered Orbit player interceptor
- License evidence currently present in repository: none identified
- Redistribution status: development-only until original license evidence is added and reviewed
- Runtime derivative: `assets/runtime/ships/player/small_sci_fi_fighter.glb`

The source file must not be deleted or overwritten by the export pipeline.
```

Update the inventory status to the same explicit development-only wording.

- [ ] **Step 2: Write the Blender exporter**

The script must:

1. parse `--output` and `--manifest` after Blender’s `--` separator;
2. use the currently opened source `.blend` and calculate its SHA-256;
3. remove cameras, lights, armatures, hidden render objects, and non-mesh helpers;
4. join remaining visible meshes as `SmallSciFiFighterMesh` while preserving material slots;
5. assume Blender-space `-Y` forward and `+Z` up for this candidate;
6. uniformly fit the joined mesh inside Blender-space `(7.6, 11.4, 2.35)` so Godot receives a margin inside `(8, 12, 2.5)`;
7. center the world-space bounding box at the origin and apply transforms;
8. create root empty `SmallSciFiFighter`;
9. create child empties `ForwardMarker` at `(0, -1, 0)` and `UpMarker` at `(0, 0, 1)`;
10. export selected root hierarchy as GLB with Y-up conversion, normals, tangents, materials, no cameras/lights/animations;
11. write JSON containing source SHA, mesh dimensions, output path, `source_forward: "-Y"`, `source_up: "+Z"`, `godot_forward: "-Z"`, and `godot_up: "+Y"`.

Use this export call:

```python
bpy.ops.export_scene.gltf(
    filepath=str(output_path),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=True,
    export_materials="EXPORT",
    export_normals=True,
    export_tangents=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
)
```

Exit with a non-zero exception when no visible mesh exists, a target dimension is non-positive, final dimensions exceed the target by more than `0.01`, or output files are absent.

- [ ] **Step 3: Write the PowerShell wrapper**

Accept `-BlenderBin`, default to `$env:BLENDER_BIN`, then try `blender` on PATH and common Windows install paths. Invoke:

```powershell
& $blenderExecutable `
  --background $sourcePath `
  --python $scriptPath `
  -- `
  --output $outputPath `
  --manifest $manifestPath
```

Throw when Blender exits non-zero or either output is missing.

- [ ] **Step 4: Run the export locally**

```powershell
.\tools\assets\export-small-fighter.ps1 -BlenderBin "C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"
```

Use the user’s actual installed Blender executable if the path differs. Expected output includes source SHA, pre-scale dimensions, scale factor, final dimensions, GLB path, and manifest path.

- [ ] **Step 5: Inspect the generated GLB in Godot before wiring gameplay**

Open the imported GLB scene. Confirm the mesh nose points toward the `ForwardMarker`, the top points toward `UpMarker`, materials are present, no camera/light/armature remains, and dimensions fit the approved envelope. If the source is not actually `-Y` forward, stop and use systematic debugging to change the exporter’s source-axis normalization before proceeding.

- [ ] **Step 6: Commit tooling, evidence, manifest, and binary together**

```bash
git add tools/assets/export_small_sci_fi_fighter.py tools/assets/export-small-fighter.ps1 assets/licenses/small_sci_fi_fighter/PROVENANCE.md assets/inventory/ASSET_INVENTORY.md assets/runtime/ships/player/small_sci_fi_fighter.glb assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
git commit -m "feat: export normalized hero interceptor"
```

---

### Task 10: Mandatory Hero Ship Scene and Visual Response

**Files:**
- Create: `src/player/ship_visual_controller.gd`
- Modify: `scenes/player/player_interceptor.tscn`
- Modify: `scenes/camera/chase_camera_rig.tscn`
- Modify: `tests/integration/test_player_scene.gd`

**Interfaces:**
- Player adds `VisualRoot`, `CameraTarget`, `LeftEngineGlowAnchor`, `RightEngineGlowAnchor`, and `ShipVisualController`.
- Removes `Visuals/Fuselage`, `Nose`, wings, engines, and procedural glow meshes.
- Camera target path becomes `../PlayerInterceptor/CameraTarget`.

- [ ] **Step 1: Make the player contract fail on the procedural scene**

Replace old procedural-node assertions with:

```gdscript
assert_true(player.get_node_or_null("VisualRoot") is Node3D, "VisualRoot required")
assert_true(player.get_node_or_null("VisualRoot/SmallSciFiFighter") is Node3D, "runtime fighter required")
assert_true(player.get_node_or_null("CameraTarget") is Node3D, "camera target required")
assert_true(player.get_node_or_null("LeftEngineGlowAnchor") is Node3D, "left glow anchor required")
assert_true(player.get_node_or_null("RightEngineGlowAnchor") is Node3D, "right glow anchor required")
assert_true(player.get_node_or_null("ShipVisualController") is ShipVisualController, "visual controller required")
assert_true(player.get_node_or_null("Visuals") == null, "procedural visual root must be removed")
```

- [ ] **Step 2: Verify RED**

Expected: all new hierarchy assertions fail.

- [ ] **Step 3: Replace only the visual subtree**

Add an ext_resource for the GLB and instance it under `VisualRoot` as `SmallSciFiFighter`. Keep root rigid-body properties, collision, input source, controller, and tuning unchanged.

Use these Godot-owned nodes:

```text
CameraTarget position: (0, 0.8, -1.5)
LeftEngineGlowAnchor position: (-2.2, -0.1, 4.8)
RightEngineGlowAnchor position: (2.2, -0.1, 4.8)
```

Under each glow anchor, add a small cyan emissive `CylinderMesh` pointing backward. These are effects, not fallback ship geometry.

- [ ] **Step 4: Implement read-only glow response**

`ShipVisualController` resolves the controller and two glow meshes. On each frame:

```gdscript
var amount := _controller.get_boost_amount()
var glow_scale := lerpf(1.0, 2.2, amount)
_left_glow.scale.z = glow_scale
_right_glow.scale.z = glow_scale
```

Invalid paths emit one clear error and disable processing. The script never changes physics or the imported mesh.

- [ ] **Step 5: Retarget the chase camera**

Set `target_path = NodePath("../PlayerInterceptor/CameraTarget")` in the camera scene.

- [ ] **Step 6: Verify GREEN and commit**

Run the verifier. Existing suite count remains `11` until Task 11.

```bash
git add src/player/ship_visual_controller.gd scenes/player/player_interceptor.tscn scenes/camera/chase_camera_rig.tscn tests/integration/test_player_scene.gd
git commit -m "feat: integrate hero interceptor visual"
```

---

### Task 11: Runtime Asset Contract and Verification Preflight

**Files:**
- Create: `tests/integration/test_hero_ship_asset.gd`
- Modify: `tests/test_runner.gd`
- Modify: `tools/verify/verify.ps1`

**Interfaces:**
- Final registered suite count becomes `12`.
- Verifier fails before Godot import when GLB or manifest is absent.

- [ ] **Step 1: Add the failing hero-asset suite**

Create a suite that:

1. asserts `ResourceLoader.exists("res://assets/runtime/ships/player/small_sci_fi_fighter.glb")`;
2. loads it as `PackedScene`;
3. instantiates it;
4. finds `ForwardMarker` and `UpMarker` recursively;
5. asserts normalized marker positions point to `Vector3.FORWARD` and `Vector3.UP` with dot product above `0.99`;
6. recursively merges transformed `MeshInstance3D.get_aabb()` bounds;
7. asserts final bounds do not exceed X `8.0`, Y `2.5`, or Z `12.0` plus `0.05` tolerance;
8. asserts at least one mesh exists;
9. frees the instance.

Register it last. Expected final output: `PASS: 12 suites`.

- [ ] **Step 2: Demonstrate the regression test**

Temporarily rename the GLB locally, run the test runner, and confirm the hero suite fails. Restore the GLB and rerun. Do not commit the temporary rename.

- [ ] **Step 3: Add PowerShell preflight**

Before `Push-Location`, resolve repo root and require these files:

```powershell
$requiredRuntimeFiles = @(
    "assets\runtime\ships\player\small_sci_fi_fighter.glb",
    "assets\runtime\ships\player\small_sci_fi_fighter.manifest.json"
)
foreach ($relativePath in $requiredRuntimeFiles) {
    $absolutePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Required runtime asset missing: $relativePath"
    }
}
```

- [ ] **Step 4: Verify GREEN and commit**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected: import succeeds, `PASS: 12 suites`, and boot exits without warnings/errors.

```bash
git add tests/integration/test_hero_ship_asset.gd tests/test_runner.gd tools/verify/verify.ps1
git commit -m "test: enforce hero ship runtime contract"
```

---

### Task 12: Manual Acceptance, Evidence-Based Tuning, and Documentation

**Files:**
- Modify: `README.md`
- Modify only with runtime evidence: `config/flight/player_flight_tuning.tres` and the smallest related source/test pair.

**Interfaces:**
- No new runtime architecture.
- Final acceptance uses the verifier plus direct play in Godot 4.7.1.

- [ ] **Step 1: Run the complete automated gate from a fresh pull**

```powershell
git switch agent/playable-flight-room
git pull
.\tools\verify\verify.ps1
```

Required evidence: no path-case warning, no missing GLB/manifest, no parser/scene error, `PASS: 12 suites`, and clean brief boot.

- [ ] **Step 2: Launch the game**

```powershell
godot --path .
```

- [ ] **Step 3: Execute the twenty acceptance checks from the approved design**

Additionally record measured values for:

```text
cold-to-lockout boost time
maximum normal speed reached under continuous thrust
maximum boosted speed reached under continuous thrust
lockout-to-recovery time
full cooling time
peak camera FOV
```

- [ ] **Step 4: Tune one value at a time only when evidence fails a target**

Allowed first-pass tuning fields are:

```text
pitch_torque
yaw_torque
roll_torque
assist_lateral_damping
assist_vertical_damping
assist_angular_damping
assist_steering_strength
assist_max_steering_acceleration
auto_bank_response
camera_speed_pullback
camera_max_pullback
camera_forward_look_ahead
```

Do not change the approved `160/240 m/s`, `12 s`, `6 s`, `15 s`, `0.60`, `22°`, mass, or collider targets without returning to design review. After each tuning change, rerun all twelve suites and the affected manual check.

- [ ] **Step 5: Update README**

Document:

- agile simcade interceptor milestone;
- exact revised controls;
- assisted versus manual behavior;
- 160/240 m/s soft envelopes;
- twelve-second thermal boost and lockout recovery;
- hero GLB export command;
- development-only license status until evidence is added;
- exact verifier command and `PASS: 12 suites` target;
- no raw source asset is loaded by gameplay.

- [ ] **Step 6: Fresh final verification and diff audit**

```powershell
.\tools\verify\verify.ps1
```

```bash
git diff --check
git diff agent/playable-flight-room~1...HEAD --stat
git status --short
```

Also compare the milestone branch against the last verified playable-flight commit and confirm no workflow, add-on, raw-source mutation, combat, or unrelated files were added.

- [ ] **Step 7: Commit documentation and evidence-based tuning**

```bash
git add README.md
git commit -m "docs: verify refined interceptor milestone"
```

If tuning changed, add only the exact tuning/source/test files changed by evidence to the same commit or a preceding focused `fix:` commit.

---

## Final Review Gate

1. Input tests prove mouse/arrows pitch-yaw, A/D roll, and Q/E strafe.
2. Speed tests prove smooth 120–160 and 180–240 attenuation without velocity assignment or braking.
3. Thermal tests measure approximately 12-second endurance, 6-second recovery, and 15-second full cooling.
4. Steering force is perpendicular, bounded, forward-thrust-dependent, and assisted-only.
5. Generated bank is bounded at 22 degrees, returns smoothly, and manual roll overrides it.
6. HUD reports heat, lockout, recovery, active envelope, and revised controls.
7. Camera remains smooth and reaches the approved high-speed composition without snapping.
8. Flight room includes the preserved handling section and extended speed section through at least Z `-2400`.
9. Blender exporter leaves source untouched, produces GLB plus manifest, and verifies bounds/markers.
10. Player scene has no procedural ship geometry or fallback and preserves its physics/controller hierarchy.
11. `verify.ps1` prints `PASS: 12 suites` and boots without warnings/errors.
12. All twenty manual acceptance checks pass before branch completion.
