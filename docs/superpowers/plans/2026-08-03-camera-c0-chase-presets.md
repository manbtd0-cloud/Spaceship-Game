# Camera C0 Chase Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace excessive high-speed chase-camera distance with smooth Close, Standard, and Far presets cycled by `C`.

**Architecture:** `ChaseCameraPreset` stores one validated framing contract. `ChaseCameraMath` remains pure and computes bounded ship-relative position, capped look prediction, interpolation, orientation, and FOV. `ChaseCameraRig` alone owns scene references, selected preset, the reserved temporary-view state, `C` input, and application of the pure outputs.

**Tech Stack:** Godot 4.7.1, GDScript, existing custom `TestCase` runner, `project.godot`, PowerShell verifier.

## Global Constraints

- Branch: `agent/playable-flight-room`.
- No GitHub Actions; use local `tools/verify/verify.ps1`.
- Initial/cycle order: `Standard -> Far -> Close -> Standard`.
- Physical key `C` owns only the `camera_cycle` action.
- Close: rear `10.5`, height `3.2`, max pullback `3.5`, hard rear limit `14.0` metres.
- Standard: rear `14.0`, height `4.0`, max pullback `5.0`, hard rear limit `19.0` metres.
- Far: rear `20.0`, height `5.0`, max pullback `7.0`, hard rear limit `27.0` metres.
- Preserve `camera_speed_pullback = 0.05` and current FOV tuning.
- Cap look-target velocity prediction to `8.0` metres.
- Lateral, vertical, reverse, and non-finite velocity do not alter physical camera framing.
- Keep selected chase preset independent from `TemporaryView.NONE/REAR/LEFT/RIGHT`.
- Camera C0 does not implement tactical rear/side views, collision avoidance, combat target framing, or combat code.
- No completion claim until the user reports a green local verifier and accepts the running camera.

---

### Task 1: Typed preset value and bounded pure math

**Files:**
- Create: `src/camera/chase_camera_preset.gd`
- Modify: `src/camera/chase_camera_math.gd`
- Modify: `tests/unit/test_chase_camera_math.gd`

**Interfaces:**
- `ChaseCameraPreset.new(name, rear, height, max_pullback, hard_limit)`
- Getter-only properties and `is_valid() -> bool`
- `ChaseCameraMath.local_forward_speed(...) -> float`
- New bounded `desired_position(...) -> Vector3`
- New capped `desired_look_target(...) -> Vector3`
- `interpolate_scalar(...) -> float`

- [ ] **Step 1: Write the failing preset tests**

Add to the camera math suite and call it from `run()`:

```gdscript
func _test_preset_contract() -> void:
    var standard := ChaseCameraPreset.new(&"standard", 14.0, 4.0, 5.0, 19.0)
    assert_true(standard.is_valid(), "standard preset must be valid")
    assert_true(is_equal_approx(standard.rear_offset, 14.0), "standard rear")
    assert_true(is_equal_approx(standard.height, 4.0), "standard height")
    assert_true(is_equal_approx(standard.max_speed_pullback, 5.0), "standard pullback")
    assert_true(is_equal_approx(standard.hard_rear_limit, 19.0), "standard limit")
    assert_true(
        not ChaseCameraPreset.new(&"bad", -1.0, 4.0, 5.0, 19.0).is_valid(),
        "negative rear must fail"
    )
    assert_true(
        not ChaseCameraPreset.new(&"bad", 20.0, 4.0, 5.0, 19.0).is_valid(),
        "hard limit below rear offset must fail"
    )
```

- [ ] **Step 2: Write failing bounded-position tests**

```gdscript
func _test_bounded_position() -> void:
    var zero := ChaseCameraMath.desired_position(
        Transform3D.IDENTITY, Vector3.ZERO, 14.0, 4.0, 0.05, 5.0, 19.0
    )
    assert_true(zero.is_equal_approx(Vector3(0.0, 4.0, 14.0)), "zero-speed standard")

    var boost := ChaseCameraMath.desired_position(
        Transform3D.IDENTITY, Vector3(0.0, 0.0, -240.0), 14.0, 4.0, 0.05, 5.0, 19.0
    )
    assert_true(is_equal_approx(boost.z, 19.0), "standard boost hard clamp")

    for irrelevant_velocity: Vector3 in [
        Vector3(200.0, 0.0, 0.0),
        Vector3(0.0, 200.0, 0.0),
        Vector3(0.0, 0.0, 240.0),
        Vector3(INF, 0.0, 0.0),
    ]:
        var result := ChaseCameraMath.desired_position(
            Transform3D.IDENTITY, irrelevant_velocity, 14.0, 4.0, 0.05, 5.0, 19.0
        )
        assert_true(result.is_equal_approx(zero), "irrelevant velocity must not move camera")

    var rotated := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
    var world_forward := rotated.basis * Vector3(0.0, 0.0, -100.0)
    assert_true(
        is_equal_approx(ChaseCameraMath.local_forward_speed(rotated, world_forward), 100.0),
        "forward speed must be extracted in ship-local space"
    )
```

- [ ] **Step 3: Write failing capped-prediction and interpolation tests**

```gdscript
func _test_prediction_and_interpolation() -> void:
    var look := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY,
        Vector3(300.0, 0.0, -400.0),
        0.12,
        10.0,
        8.0
    )
    assert_true(
        look.distance_to(Vector3(0.0, 0.0, -10.0)) <= 8.0001,
        "prediction vector magnitude must be capped"
    )
    var no_velocity := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY, Vector3.ZERO, 0.12, 10.0, 8.0
    )
    assert_true(no_velocity.is_equal_approx(Vector3(0.0, 0.0, -10.0)), "zero prediction")
    var non_finite := ChaseCameraMath.desired_look_target(
        Transform3D.IDENTITY, Vector3(NAN, 0.0, 0.0), 0.12, 10.0, 8.0
    )
    assert_true(non_finite.is_equal_approx(no_velocity), "non-finite prediction must fail safe")

    var one_step := ChaseCameraMath.interpolate_scalar(14.0, 20.0, 9.0, 0.4)
    var four_steps := 14.0
    for _index: int in range(4):
        four_steps = ChaseCameraMath.interpolate_scalar(four_steps, 20.0, 9.0, 0.1)
    assert_true(absf(one_step - four_steps) < 0.001, "interpolation must be frame-rate independent")
```

- [ ] **Step 4: Run RED**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: missing `ChaseCameraPreset` and changed math signatures.

- [ ] **Step 5: Implement `ChaseCameraPreset`**

```gdscript
class_name ChaseCameraPreset
extends RefCounted

var semantic_name: StringName:
    get: return _semantic_name
var rear_offset: float:
    get: return _rear_offset
var height: float:
    get: return _height
var max_speed_pullback: float:
    get: return _max_speed_pullback
var hard_rear_limit: float:
    get: return _hard_rear_limit

var _semantic_name: StringName
var _rear_offset: float
var _height: float
var _max_speed_pullback: float
var _hard_rear_limit: float

func _init(name_value: StringName, rear: float, height_value: float, pullback: float, limit: float) -> void:
    _semantic_name = name_value
    _rear_offset = rear
    _height = height_value
    _max_speed_pullback = pullback
    _hard_rear_limit = limit

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

- [ ] **Step 6: Implement bounded math**

```gdscript
static func local_forward_speed(target_transform: Transform3D, world_velocity: Vector3) -> float:
    if not world_velocity.is_finite():
        return 0.0
    var local_velocity := target_transform.basis.orthonormalized().inverse() * world_velocity
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
        local_forward_speed(target_transform, world_velocity) * maxf(speed_pullback_rate, 0.0),
        maxf(max_speed_pullback, 0.0)
    )
    var final_rear := minf(safe_rear + pullback, safe_limit)
    return target_transform.origin + target_transform.basis.orthonormalized() * Vector3(0.0, safe_height, final_rear)

static func desired_look_target(
    target_transform: Transform3D,
    world_velocity: Vector3,
    velocity_look_ahead: float,
    forward_look_ahead: float,
    max_prediction_distance: float
) -> Vector3:
    var safe_velocity := world_velocity if world_velocity.is_finite() else Vector3.ZERO
    var prediction := (safe_velocity * maxf(velocity_look_ahead, 0.0)).limit_length(
        maxf(max_prediction_distance, 0.0)
    )
    var forward := target_transform.basis.orthonormalized() * Vector3.FORWARD
    return target_transform.origin + prediction + forward * maxf(forward_look_ahead, 0.0)

static func interpolate_scalar(current: float, target: float, sharpness: float, delta: float) -> float:
    return lerpf(current, target, exponential_weight(sharpness, delta))
```

Retain existing basis and FOV functions unchanged.

- [ ] **Step 7: Run GREEN and commit**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

```bash
git add src/camera/chase_camera_preset.gd src/camera/chase_camera_math.gd tests/unit/test_chase_camera_math.gd
git commit -m "fix: bound chase camera speed response"
```

---

### Task 2: Input contract and preset state machine

**Files:**
- Modify: `project.godot`
- Modify: `tests/integration/test_input_map.gd`
- Modify: `src/camera/chase_camera_rig.gd`
- Create: `tests/integration/test_chase_camera_rig.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `enum Preset { CLOSE, STANDARD, FAR }`
- `enum TemporaryView { NONE, REAR, LEFT, RIGHT }`
- `cycle_preset()`, `select_preset(value)`, `get_selected_preset()`, `get_selected_preset_name()`, `get_temporary_view()`

- [ ] **Step 1: Add failing input assertions**

```gdscript
assert_equal(_physical_key_for_action(&"camera_cycle"), KEY_C, "C must cycle camera presets")
var c_owners := 0
for action: StringName in InputMap.get_actions():
    if _physical_key_for_action(action) == KEY_C:
        c_owners += 1
assert_equal(c_owners, 1, "C must belong only to camera_cycle")
```

- [ ] **Step 2: Create the exact rig fixture and failing state tests**

`tests/integration/test_chase_camera_rig.gd` creates a root with the production player and camera scenes, then enters it into the running SceneTree so `_ready()` executes:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var fixture := Node3D.new()
    fixture.name = "CameraFixture"
    var player := (load("res://scenes/player/player_interceptor.tscn") as PackedScene).instantiate()
    var rig := (load("res://scenes/camera/chase_camera_rig.tscn") as PackedScene).instantiate() as ChaseCameraRig
    fixture.add_child(player)
    fixture.add_child(rig)
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(fixture)

    assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.STANDARD, "initial Standard")
    assert_equal(rig.get_selected_preset_name(), &"standard", "initial name")
    assert_equal(rig.get_temporary_view(), ChaseCameraRig.TemporaryView.NONE, "C0 temporary view")
    rig.cycle_preset()
    assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.FAR, "Standard to Far")
    rig.cycle_preset()
    assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.CLOSE, "Far to Close")
    rig.cycle_preset()
    assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.STANDARD, "Close to Standard")
    rig.select_preset(999)
    assert_equal(rig.get_selected_preset(), ChaseCameraRig.Preset.STANDARD, "invalid recovers Standard")

    fixture.get_parent().remove_child(fixture)
    fixture.free()
```

Register this suite immediately after `test_chase_camera_math.gd`.

- [ ] **Step 3: Run RED**

Expected: missing input and rig state methods.

- [ ] **Step 4: Add `camera_cycle`**

```ini
camera_cycle={
"deadzone": 0.15,
"events": [Object(InputEventKey,"physical_keycode":67)]
}
```

- [ ] **Step 5: Implement the state machine**

```gdscript
enum Preset { CLOSE, STANDARD, FAR }
enum TemporaryView { NONE, REAR, LEFT, RIGHT }

const PRESET_CYCLE: Array[int] = [Preset.STANDARD, Preset.FAR, Preset.CLOSE]

var _presets: Dictionary = {
    Preset.CLOSE: ChaseCameraPreset.new(&"close", 10.5, 3.2, 3.5, 14.0),
    Preset.STANDARD: ChaseCameraPreset.new(&"standard", 14.0, 4.0, 5.0, 19.0),
    Preset.FAR: ChaseCameraPreset.new(&"far", 20.0, 5.0, 7.0, 27.0),
}
var _selected_preset: int = Preset.STANDARD
var _temporary_view: int = TemporaryView.NONE
```

`select_preset()` accepts only a valid record and otherwise selects Standard. `cycle_preset()` follows `PRESET_CYCLE`, skips invalid records, and falls back to Standard. `_process()` calls it only under `Input.is_action_just_pressed(&"camera_cycle")`.

- [ ] **Step 6: Run GREEN and commit**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

```bash
git add project.godot src/camera/chase_camera_rig.gd tests/integration/test_input_map.gd tests/integration/test_chase_camera_rig.gd tests/test_runner.gd
git commit -m "feat: add chase camera preset cycling"
```

---

### Task 3: Smooth bounded framing in the production rig

**Files:**
- Modify: `src/camera/chase_camera_rig.gd`
- Modify: `scenes/camera/chase_camera_rig.tscn`
- Modify: `tests/integration/test_chase_camera_rig.gd`
- Modify: `tests/integration/test_flight_room_scene.gd`

**Interfaces:**
- Export `preset_transition_sharpness = 9.0`
- Export `max_prediction_distance = 8.0`
- `step_camera(delta)`, `step_camera_for_test(delta)`, `get_current_framing() -> Dictionary`

- [ ] **Step 1: Add failing transition and reset-boundary tests**

Append before fixture cleanup:

```gdscript
var initial := rig.get_current_framing()
assert_true(is_equal_approx(float(initial["rear_offset"]), 14.0), "standard rear")
assert_true(is_equal_approx(float(initial["height"]), 4.0), "standard height")

rig.select_preset(ChaseCameraRig.Preset.FAR)
var before := rig.get_current_framing()
rig.step_camera_for_test(0.05)
var after := rig.get_current_framing()
assert_true(float(after["rear_offset"]) > float(before["rear_offset"]), "Far transition increases rear")
assert_true(float(after["rear_offset"]) < 20.0, "Far transition is smooth")
assert_true(float(after["height"]) > float(before["height"]), "Far transition increases height")
assert_true(float(after["hard_rear_limit"]) <= 27.0, "Far transition remains bounded")

var selected_before_reset := rig.get_selected_preset()
var controller := player.get_node("ShipFlightController") as ShipFlightController
controller.reset_runtime_state()
assert_equal(rig.get_selected_preset(), selected_before_reset, "controller reset must preserve camera preset")
```

Add repeated Far-to-Close samples and assert each rear value is no greater than the previous value and never greater than its current hard limit.

- [ ] **Step 2: Run RED**

Expected: missing framing and step APIs.

- [ ] **Step 3: Replace obsolete configuration**

Remove `base_offset` from the rig and scene. Keep `velocity_look_ahead` only for look-target prediction. Add:

```gdscript
@export var preset_transition_sharpness: float = 9.0
@export var max_prediction_distance: float = 8.0
```

Set those exact values in `chase_camera_rig.tscn`.

- [ ] **Step 4: Implement current framing state**

Initialize four scalar fields from Standard. Each `step_camera(delta)` interpolates all four toward the selected preset using `interpolate_scalar`, computes bounded position with current values, computes capped look target, and applies existing rotation/FOV smoothing.

```gdscript
func step_camera(delta: float) -> void:
    var preset := _selected_valid_preset()
    _current_rear_offset = ChaseCameraMath.interpolate_scalar(
        _current_rear_offset, preset.rear_offset, preset_transition_sharpness, delta
    )
    _current_height = ChaseCameraMath.interpolate_scalar(
        _current_height, preset.height, preset_transition_sharpness, delta
    )
    _current_max_speed_pullback = ChaseCameraMath.interpolate_scalar(
        _current_max_speed_pullback, preset.max_speed_pullback, preset_transition_sharpness, delta
    )
    _current_hard_rear_limit = ChaseCameraMath.interpolate_scalar(
        _current_hard_rear_limit, preset.hard_rear_limit, preset_transition_sharpness, delta
    )

    var world_velocity := _controller.get_world_velocity()
    var desired_position := ChaseCameraMath.desired_position(
        _target.global_transform,
        world_velocity,
        _current_rear_offset,
        _current_height,
        tuning.camera_speed_pullback,
        _current_max_speed_pullback,
        _current_hard_rear_limit
    )
    if desired_position.is_finite():
        global_position = global_position.lerp(
            desired_position,
            ChaseCameraMath.exponential_weight(position_sharpness, delta)
        )

    var desired_target := ChaseCameraMath.desired_look_target(
        _target.global_transform,
        world_velocity,
        velocity_look_ahead,
        tuning.camera_forward_look_ahead,
        max_prediction_distance
    )
    if desired_target.is_finite():
        _smooth_rotation_toward(desired_target, delta)

    _update_fov(delta)
```

`step_camera_for_test(delta)` calls `step_camera(delta)`. `get_current_framing()` returns copies of the four scalars. `_snap_to_desired_state()` sets all four scalars to Standard and uses the new math immediately. Existing FOV calculations move unchanged into `_update_fov(delta)`.

- [ ] **Step 5: Add flight-room scene assertions**

In `test_flight_room_scene.gd`, assert the resolved camera rig starts Standard and contains a `Camera3D`. Do not alter asteroid setup assertions.

- [ ] **Step 6: Run GREEN and commit**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

```bash
git add src/camera/chase_camera_rig.gd scenes/camera/chase_camera_rig.tscn tests/integration/test_chase_camera_rig.gd tests/integration/test_flight_room_scene.gd
git commit -m "feat: apply smooth bounded chase framing"
```

---

### Task 4: Close regression coverage, docs, and local handoff

**Files:**
- Modify: `tests/unit/test_chase_camera_math.gd`
- Modify: `tests/integration/test_chase_camera_rig.gd`
- Modify: `README.md` when controls or fixed suite count are present.

- [ ] **Step 1: Assert every preset at boost speed**

Use `desired_position` at `240 m/s` and assert Close/Standard/Far rear values are at most `14.0/19.0/27.0`, remain positive, and never cross in front of the target.

- [ ] **Step 2: Retain all orientation/FOV regressions**

The existing rolled-ship, inverted-ship, normal-FOV, and boost-FOV assertions remain unchanged and must pass.

- [ ] **Step 3: Update controls documentation**

Add:

```text
C — cycle Close / Standard / Far chase-camera presets
```

Change an exact `PASS: 21 suites` reference to `PASS: 22 suites` only when that fixed text exists.

- [ ] **Step 4: Run focused gate**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 22 suites`.

- [ ] **Step 5: Commit code-side completion**

```bash
git add tests/unit/test_chase_camera_math.gd tests/integration/test_chase_camera_rig.gd README.md
git commit -m "test: close Camera C0 coverage"
```

- [ ] **Step 6: User local verification**

```powershell
git pull
.\tools\verify\verify.ps1
godot --path .
```

Manual acceptance: Standard initially; `C` cycles Standard/Far/Close; holding does not skip; boost never produces the former huge distance; lateral/vertical/reverse motion does not displace framing; transitions are smooth; roll/inversion remain ship-relative; reset preserves the selected preset.

---

## Execution Checkpoints

1. Task 1: pure math and preset contract.
2. Task 2: input and state machine.
3. Task 3: production framing and integration.
4. Task 4: local verifier and manual acceptance.

After Camera C0 passes, begin Combat Kernel 1 with rapid pulse cannons, one simple target/enemy, shields, hull, defeat, and reset. Heavy plasma and Camera C1 stay deferred.
