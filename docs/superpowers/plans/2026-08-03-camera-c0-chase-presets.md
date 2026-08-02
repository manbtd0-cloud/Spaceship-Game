# Camera C0 Chase Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unbounded high-speed chase-camera pullback with smooth Close, Standard, and Far presets cycled by `C`, while preserving ship-relative orientation and the existing FOV behavior.

**Architecture:** Add a focused immutable `ChaseCameraPreset` value type, keep all deterministic positioning and prediction rules in `ChaseCameraMath`, and let `ChaseCameraRig` own only preset state, input, interpolation, node resolution, and application. Physical camera position will depend only on the ship-relative preset offset plus bounded forward-speed pullback; velocity prediction will affect only the look target and will be capped to eight metres.

**Tech Stack:** Godot 4.7.1, GDScript, existing custom `TestCase` runner, `project.godot` input map, PowerShell local verifier.

## Global Constraints

- Work on branch `agent/playable-flight-room`.
- Do not use GitHub Actions; verification is local through `tools/verify/verify.ps1`.
- Start in Standard and cycle `Standard -> Far -> Close -> Standard`.
- Bind `camera_cycle` to physical key `C` and read it only in `ChaseCameraRig`.
- Close values: rear `10.5`, height `3.2`, maximum pullback `3.5`, hard rear limit `14.0` metres.
- Standard values: rear `14.0`, height `4.0`, maximum pullback `5.0`, hard rear limit `19.0` metres.
- Far values: rear `20.0`, height `5.0`, maximum pullback `7.0`, hard rear limit `27.0` metres.
- Preserve the existing `camera_speed_pullback = 0.05` rate and FOV tuning.
- Cap velocity prediction in the look target to `8.0` metres.
- Lateral, vertical, reverse, and non-finite velocity must not increase physical camera distance.
- Keep persistent preset state separate from the reserved temporary-view state.
- Do not implement rear/left/right tactical views in Camera C0.
- Do not modify flight physics, ship input commands, thruster visuals, or combat code.
- Do not claim completion until the user reports a green local verifier and confirms the running camera behavior.

---

## File Structure

- Create `src/camera/chase_camera_preset.gd`: immutable validated preset value object.
- Modify `src/camera/chase_camera_math.gd`: pure forward-speed extraction, bounded positioning, capped prediction, and interpolation helpers.
- Modify `src/camera/chase_camera_rig.gd`: preset state, `C` cycling, temporary-view boundary, and smooth application.
- Modify `scenes/camera/chase_camera_rig.tscn`: remove obsolete positional-velocity configuration and expose transition/prediction settings.
- Modify `project.godot`: add the `camera_cycle` action on physical key `C`.
- Modify `tests/unit/test_chase_camera_math.gd`: deterministic position, prediction, transition, roll, inversion, and FOV coverage.
- Modify `tests/integration/test_input_map.gd`: assert the unique `C` binding.
- Create `tests/integration/test_chase_camera_rig.gd`: state-cycle, invalid-state recovery, hold behavior boundary, preset persistence, and scene-resolution coverage.
- Modify `tests/test_runner.gd`: register the new suite.
- Modify `README.md` only if it documents controls or the expected suite count.

---

### Task 1: Add the typed preset contract

**Files:**
- Create: `src/camera/chase_camera_preset.gd`
- Modify: `tests/unit/test_chase_camera_math.gd`

**Interfaces:**
- Produces: `ChaseCameraPreset.new(semantic_name: StringName, rear_offset: float, height: float, max_speed_pullback: float, hard_rear_limit: float)`.
- Produces getter-only properties: `semantic_name`, `rear_offset`, `height`, `max_speed_pullback`, `hard_rear_limit`.
- Produces: `is_valid() -> bool`.

- [ ] **Step 1: Write failing preset validation assertions**

Add to `tests/unit/test_chase_camera_math.gd`:

```gdscript
func _test_preset_contract() -> void:
    var standard := ChaseCameraPreset.new(&"standard", 14.0, 4.0, 5.0, 19.0)
    assert_true(standard.is_valid(), "standard camera preset must be valid")
    assert_true(is_equal_approx(standard.rear_offset, 14.0), "rear offset")
    assert_true(is_equal_approx(standard.height, 4.0), "height")
    assert_true(is_equal_approx(standard.max_speed_pullback, 5.0), "max pullback")
    assert_true(is_equal_approx(standard.hard_rear_limit, 19.0), "hard limit")

    var negative := ChaseCameraPreset.new(&"broken", -1.0, 4.0, 5.0, 19.0)
    assert_true(not negative.is_valid(), "negative rear offset must be invalid")

    var impossible := ChaseCameraPreset.new(&"broken", 20.0, 4.0, 5.0, 19.0)
    assert_true(
        not impossible.is_valid(),
        "hard rear limit must not be smaller than base rear offset"
    )
```

Call `_test_preset_contract()` from `run()`.

- [ ] **Step 2: Run the suite and confirm RED**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: failure because `ChaseCameraPreset` does not exist.

- [ ] **Step 3: Implement the immutable value object**

Create `src/camera/chase_camera_preset.gd`:

```gdscript
class_name ChaseCameraPreset
extends RefCounted

var semantic_name: StringName:
    get:
        return _semantic_name
var rear_offset: float:
    get:
        return _rear_offset
var height: float:
    get:
        return _height
var max_speed_pullback: float:
    get:
        return _max_speed_pullback
var hard_rear_limit: float:
    get:
        return _hard_rear_limit

var _semantic_name: StringName
var _rear_offset: float
var _height: float
var _max_speed_pullback: float
var _hard_rear_limit: float

func _init(
    value_name: StringName,
    value_rear_offset: float,
    value_height: float,
    value_max_speed_pullback: float,
    value_hard_rear_limit: float
) -> void:
    _semantic_name = value_name
    _rear_offset = value_rear_offset
    _height = value_height
    _max_speed_pullback = value_max_speed_pullback
    _hard_rear_limit = value_hard_rear_limit

func is_valid() -> bool:
    return (
        _semantic_name != &""
        and is_finite(_rear_offset)
        and is_finite(_height)
        and is_finite(_max_speed_pullback)
        and is_finite(_hard_rear_limit)
        and _rear_offset > 0.0
        and _height >= 0.0
        and _max_speed_pullback >= 0.0
        and _hard_rear_limit >= _rear_offset
    )
```

- [ ] **Step 4: Run the suite and confirm GREEN**

Run the Godot test runner. Expected: the preset assertions pass and no existing camera regression appears.

- [ ] **Step 5: Commit**

```bash
git add src/camera/chase_camera_preset.gd tests/unit/test_chase_camera_math.gd
git commit -m "feat: add typed chase camera presets"
```

---

### Task 2: Replace unbounded position and look prediction math

**Files:**
- Modify: `src/camera/chase_camera_math.gd`
- Modify: `tests/unit/test_chase_camera_math.gd`

**Interfaces:**
- Produces: `local_forward_speed(target_transform: Transform3D, world_velocity: Vector3) -> float`.
- Replaces `desired_position(...)` with preset-frame arguments.
- Replaces `desired_look_target(...)` with an explicit `max_prediction_distance` argument.
- Produces: `interpolate_scalar(current: float, target: float, sharpness: float, delta: float) -> float`.

- [ ] **Step 1: Replace the old position test with failing bounded-behavior tests**

Use an identity target and these assertions:

```gdscript
func _test_bounded_position_math() -> void:
    var identity := Transform3D.IDENTITY
    var zero := ChaseCameraMath.desired_position(
        identity,
        Vector3.ZERO,
        14.0,
        4.0,
        0.05,
        5.0,
        19.0
    )
    assert_true(zero.is_equal_approx(Vector3(0.0, 4.0, 14.0)), "standard zero-speed offset")

    var boosted := ChaseCameraMath.desired_position(
        identity,
        Vector3(0.0, 0.0, -240.0),
        14.0,
        4.0,
        0.05,
        5.0,
        19.0
    )
    assert_true(is_equal_approx(boosted.z, 19.0), "standard camera must clamp to 19 metres")

    var lateral := ChaseCameraMath.desired_position(
        identity,
        Vector3(200.0, 0.0, 0.0),
        14.0,
        4.0,
        0.05,
        5.0,
        19.0
    )
    assert_true(lateral.is_equal_approx(zero), "lateral velocity must not move the camera")

    var vertical := ChaseCameraMath.desired_position(
        identity,
        Vector3(0.0, 200.0, 0.0),
        14.0,
        4.0,
        0.05,
        5.0,
        19.0
    )
    assert_true(vertical.is_equal_approx(zero), "vertical velocity must not move the camera")

    var reverse := ChaseCameraMath.desired_position(
        identity,
        Vector3(0.0, 0.0, 240.0),
        14.0,
        4.0,
        0.05,
        5.0,
        19.0
    )
    assert_true(reverse.is_equal_approx(zero), "reverse velocity must add no pullback")
```

Add rotated-target coverage proving forward speed is extracted in ship-local space, not world Z.

- [ ] **Step 2: Add failing look-prediction assertions**

```gdscript
func _test_capped_prediction() -> void:
    var target := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY,
        Vector3(300.0, 0.0, -400.0),
        0.12,
        10.0,
        8.0
    )
    var nose_only := Vector3(0.0, 0.0, -10.0)
    assert_true(
        target.distance_to(nose_only) <= 8.0001,
        "velocity prediction must be capped by vector magnitude"
    )
```

Add zero-velocity and non-finite-velocity assertions.

- [ ] **Step 3: Run and confirm RED**

Expected: signature and behavior failures against the old math.

- [ ] **Step 4: Implement bounded pure math**

Implement:

```gdscript
static func local_forward_speed(
    target_transform: Transform3D,
    world_velocity: Vector3
) -> float:
    if not world_velocity.is_finite():
        return 0.0
    var local_velocity := (
        target_transform.basis.orthonormalized().inverse()
        * world_velocity
    )
    return maxf(-local_velocity.z, 0.0)

static func desired_position(
    target_transform: Transform3D,
    world_velocity: Vector3,
    rear_offset: float,
    height: float,
    speed_pullback_rate: float,
    max_speed_pullback: float,
    hard_rear_limit: float
) -> Vector3:
    var safe_rear := maxf(rear_offset, 0.0)
    var safe_height := maxf(height, 0.0)
    var safe_limit := maxf(hard_rear_limit, safe_rear)
    var pullback := minf(
        local_forward_speed(target_transform, world_velocity)
        * maxf(speed_pullback_rate, 0.0),
        maxf(max_speed_pullback, 0.0)
    )
    var final_rear := minf(safe_rear + pullback, safe_limit)
    return (
        target_transform.origin
        + target_transform.basis.orthonormalized()
        * Vector3(0.0, safe_height, final_rear)
    )

static func desired_look_target(
    target_transform: Transform3D,
    world_velocity: Vector3,
    velocity_look_ahead: float,
    forward_look_ahead: float,
    max_prediction_distance: float
) -> Vector3:
    var safe_velocity := world_velocity if world_velocity.is_finite() else Vector3.ZERO
    var prediction := safe_velocity * maxf(velocity_look_ahead, 0.0)
    prediction = prediction.limit_length(maxf(max_prediction_distance, 0.0))
    var forward := target_transform.basis.orthonormalized() * Vector3.FORWARD
    return (
        target_transform.origin
        + prediction
        + forward * maxf(forward_look_ahead, 0.0)
    )

static func interpolate_scalar(
    current: float,
    target: float,
    sharpness: float,
    delta: float
) -> float:
    return lerpf(current, target, exponential_weight(sharpness, delta))
```

- [ ] **Step 5: Run and confirm GREEN**

Expected: bounded position, prediction, roll, inverted, and FOV tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/camera/chase_camera_math.gd tests/unit/test_chase_camera_math.gd
git commit -m "fix: bound chase camera speed response"
```

---

### Task 3: Add `C` input and deterministic preset state

**Files:**
- Modify: `project.godot`
- Modify: `tests/integration/test_input_map.gd`
- Create: `tests/integration/test_chase_camera_rig.gd`
- Modify: `tests/test_runner.gd`
- Modify: `src/camera/chase_camera_rig.gd`

**Interfaces:**
- Adds input action `camera_cycle` bound to physical `KEY_C`.
- Produces `enum Preset { CLOSE, STANDARD, FAR }`.
- Produces `enum TemporaryView { NONE, REAR, LEFT, RIGHT }`.
- Produces `cycle_preset() -> void`, `select_preset(value: int) -> void`, `get_selected_preset() -> int`, `get_selected_preset_name() -> StringName`, and `get_temporary_view() -> int`.

- [ ] **Step 1: Add failing input-map assertions**

Extend `tests/integration/test_input_map.gd`:

```gdscript
assert_equal(
    _physical_key_for_action(&"camera_cycle"),
    KEY_C,
    "C must cycle chase-camera presets"
)

var c_owners := 0
for action: StringName in InputMap.get_actions():
    if _physical_key_for_action(action) == KEY_C:
        c_owners += 1
assert_equal(c_owners, 1, "physical C must belong only to camera_cycle")
```

- [ ] **Step 2: Add a failing rig-state integration suite**

Create `tests/integration/test_chase_camera_rig.gd` that instantiates `scenes/camera/chase_camera_rig.tscn` inside a small fixture containing a player interceptor, then asserts:

```gdscript
assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.STANDARD, "initial preset")
assert_equal(rig.get_selected_preset_name(), &"standard", "initial preset name")
assert_equal(rig.get_temporary_view(), ChaseCameraRig.TemporaryView.NONE, "C0 temporary view")

rig.cycle_preset()
assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.FAR, "standard to far")
rig.cycle_preset()
assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.CLOSE, "far to close")
rig.cycle_preset()
assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.STANDARD, "close to standard")

rig.select_preset(999)
assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.STANDARD, "invalid preset recovery")
```

Register the suite after `test_chase_camera_math.gd` in `tests/test_runner.gd`.

- [ ] **Step 3: Run and confirm RED**

Expected: missing input action and missing rig state API.

- [ ] **Step 4: Add the input action**

Add to `project.godot`:

```ini
camera_cycle={
"deadzone": 0.15,
"events": [Object(InputEventKey,"physical_keycode":67)]
}
```

- [ ] **Step 5: Implement preset and temporary-view state**

In `ChaseCameraRig`:

```gdscript
enum Preset { CLOSE, STANDARD, FAR }
enum TemporaryView { NONE, REAR, LEFT, RIGHT }

const PRESET_CYCLE: Array[int] = [Preset.STANDARD, Preset.FAR, Preset.CLOSE]

var _presets: Dictionary = {}
var _selected_preset: int = Preset.STANDARD
var _temporary_view: int = TemporaryView.NONE
```

Build the three exact preset records during initialization. `select_preset()` must recover invalid values to Standard. `cycle_preset()` must search `PRESET_CYCLE` from the current valid state and skip malformed presets. `_process()` must call `cycle_preset()` only when `Input.is_action_just_pressed(&"camera_cycle")` is true.

- [ ] **Step 6: Run and confirm GREEN**

Expected: input and state tests pass; holding behavior is guaranteed by the `just_pressed` API and no repeated polling method is introduced.

- [ ] **Step 7: Commit**

```bash
git add project.godot src/camera/chase_camera_rig.gd tests/integration/test_input_map.gd tests/integration/test_chase_camera_rig.gd tests/test_runner.gd
git commit -m "feat: cycle bounded chase camera presets"
```

---

### Task 4: Integrate smooth bounded preset framing into the rig

**Files:**
- Modify: `src/camera/chase_camera_rig.gd`
- Modify: `scenes/camera/chase_camera_rig.tscn`
- Modify: `tests/integration/test_chase_camera_rig.gd`
- Modify: `tests/integration/test_flight_room_scene.gd`

**Interfaces:**
- Adds exported `preset_transition_sharpness: float = 9.0`.
- Adds exported `max_prediction_distance: float = 8.0`.
- Produces `get_current_framing() -> Dictionary` for deterministic verification with keys `rear_offset`, `height`, `max_speed_pullback`, and `hard_rear_limit`.

- [ ] **Step 1: Add failing transition and persistence assertions**

After initializing the rig in the integration fixture:

```gdscript
var initial := rig.get_current_framing()
assert_true(is_equal_approx(float(initial["rear_offset"]), 14.0), "standard rear")
assert_true(is_equal_approx(float(initial["height"]), 4.0), "standard height")

rig.cycle_preset()
var before := rig.get_current_framing()
rig.step_camera_for_test(0.05)
var after := rig.get_current_framing()
assert_true(float(after["rear_offset"]) > float(before["rear_offset"]), "far transition increases rear")
assert_true(float(after["rear_offset"]) < 20.0, "far transition does not snap")
assert_true(float(after["height"]) > float(before["height"]), "far transition increases height")
assert_true(float(after["hard_rear_limit"]) <= 27.0, "transition remains bounded")
```

Cycle to Close and assert every sampled rear value decreases monotonically and never exceeds the interpolated hard limit. Call the room reset method used by the flight-room controller and assert the selected preset remains unchanged.

- [ ] **Step 2: Run and confirm RED**

Expected: missing framing and test-step APIs.

- [ ] **Step 3: Replace obsolete rig configuration**

Remove `base_offset` as runtime authority. Keep `velocity_look_ahead` only for look prediction. Add:

```gdscript
@export var preset_transition_sharpness: float = 9.0
@export var max_prediction_distance: float = 8.0
```

Update `scenes/camera/chase_camera_rig.tscn` to remove `base_offset = Vector3(0, 4, 16)` and set the two explicit values.

- [ ] **Step 4: Add smooth framing state**

Store four current scalar values initialized from Standard. Each frame, interpolate each scalar toward the selected valid preset using `ChaseCameraMath.interpolate_scalar`. Use those current values when calling `desired_position`; this guarantees Close/Far changes are smooth while every frame remains hard-limited.

Factor the process body into:

```gdscript
func step_camera(delta: float) -> void:
    # Handle preset interpolation, bounded position, capped look target, rotation, and FOV.

func step_camera_for_test(delta: float) -> void:
    step_camera(delta)
```

`_process(delta)` handles input once and then calls `step_camera(delta)`.

- [ ] **Step 5: Preserve the last finite camera state**

Before assigning a desired position, verify `desired_position.is_finite()`. If invalid, retain the current `global_position`. Apply the same rule to the desired look target. This failure path must never call into flight control or alter player state.

- [ ] **Step 6: Run and confirm GREEN**

Expected: transitions are monotonic, frame-rate-independent within tolerance, bounded, and selected state survives the flight-room reset.

- [ ] **Step 7: Commit**

```bash
git add src/camera/chase_camera_rig.gd scenes/camera/chase_camera_rig.tscn tests/integration/test_chase_camera_rig.gd tests/integration/test_flight_room_scene.gd
git commit -m "feat: smooth bounded chase camera framing"
```

---

### Task 5: Complete regression coverage and documentation

**Files:**
- Modify: `tests/unit/test_chase_camera_math.gd`
- Modify: `tests/integration/test_chase_camera_rig.gd`
- Modify: `README.md` when control or suite-count text exists.

**Interfaces:**
- No new runtime interface; this task closes verification gaps.

- [ ] **Step 1: Add frame-rate-independence coverage**

Compare one `0.4` second transition step with four `0.1` second steps using the same initial/target values and `interpolate_scalar`. Assert the results differ by less than `0.001`.

- [ ] **Step 2: Add all-preset hard-limit coverage**

For Close, Standard, and Far at `240 m/s`, assert rear positions are at most `14.0`, `19.0`, and `27.0` respectively. Assert the ship stays visible behind the target and no case produces a front-side camera position.

- [ ] **Step 3: Add regression checks**

Retain and run the existing rolled-ship, inverted-ship, normal-FOV, and boost-FOV tests. Confirm the flight-room scene still resolves one `ChaseCameraRig` and its `Camera3D`.

- [ ] **Step 4: Update controls documentation**

Where the README lists controls, add:

```text
C — cycle Close / Standard / Far chase camera presets
```

Update an explicit `PASS: 21 suites` reference to `PASS: 22 suites` only when that exact fixed count exists.

- [ ] **Step 5: Run focused test gate**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 22 suites`.

- [ ] **Step 6: Run the project verifier**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected: all asset preflights pass and `PASS: 22 suites`.

- [ ] **Step 7: Manual acceptance**

Launch:

```powershell
godot --path .
```

Verify Standard is initial, `C` cycles Standard/Far/Close, holding `C` does not skip, boost never recreates the former excessive distance, lateral/vertical/reverse motion does not displace framing, transitions are smooth, roll/inversion stay ship-relative, and room reset preserves the selected preset.

- [ ] **Step 8: Commit final documentation/test adjustments**

```bash
git add tests/unit/test_chase_camera_math.gd tests/integration/test_chase_camera_rig.gd README.md
git commit -m "test: close Camera C0 verification"
```

---

## Execution Checkpoints

1. After Task 2: pure camera math is bounded and fully deterministic.
2. After Task 3: `C` input and state cycle work without modifying physical framing yet.
3. After Task 4: the running rig uses smooth bounded presets.
4. After Task 5: user runs the complete verifier and manual acceptance gate.

The next plan after Camera C0 passes is Combat Kernel 1 with rapid pulse cannons, a simple target/enemy, shields, hull, defeat, and reset. Heavy plasma and Camera C1 remain deferred.
