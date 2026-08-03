# Realistic Flight, Camera Modes, and Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve true inertial spacecraft motion, replace speed-bleeding assist forces, add Dynamic/Tactical/Locked chase-camera behaviors, exact rear/side look views, a true velocity-vector HUD marker, and a minimal persistent pause/settings foundation.

**Architecture:** Keep rigid-body force/torque physics authoritative. Add small typed value objects and one typed settings autoload, extend the existing camera rig rather than replacing it, isolate projection and camera-bound calculations into pure helpers, and let a room-owned coordinator apply settings to gameplay systems. The pause menu writes only to the settings service and invokes the existing room reset path.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, GL Compatibility renderer, ConfigFile persistence, the existing custom `TestCase` runner, separate headless SceneTree integration scripts for real physics-frame verification, PowerShell and Bash local verification.

## Global Constraints

- Work only on `manbtd0-cloud/Spaceship-Game`, branch `agent/playable-flight-room`.
- Windows PowerShell with Godot 4.7.1 Standard is authoritative.
- Do not use GitHub Actions.
- Do not modify, delete, or add unrelated local untracked source packs, generated imports, diagnostics, `.uid`, `__pycache__`, or vendor files.
- Preserve the current Dynamic chase camera as an available option.
- Default settings are Tactical camera behavior, Standard distance, and Assisted flight mode.
- Player-facing mode copy is `Assisted` and `Inertial`; the internal `FlightMode.Value.MANUAL` enum may remain.
- Inertial pure rotation must preserve world linear velocity and speed.
- Assisted steering force must be perpendicular to current velocity and must not retain unconditional local X/Y damping.
- `B` is rear view, `PageUp` is right view, `PageDown` is left view, and `Escape` owns pause in the flight room.
- Velocity marker hides below `2.0 m/s` and clamps within a `32 px` safe margin.
- Persist only `camera.behavior`, `camera.distance`, and `flight.default_mode` to `user://settings.cfg`.
- Development-only debug scenes retain their current Escape-to-exit behavior.
- The approved practice-drone milestone remains next and is not implemented in this plan.
- Do not claim completion until fresh Windows output proves import, all suites, dedicated physics integration, main-scene boot, and manual acceptance.

---

## File Map

### Create

- `src/camera/camera_behavior.gd` — typed Dynamic/Tactical/Locked values and validation.
- `src/camera/camera_distance.gd` — typed Close/Standard/Far values and validation.
- `src/settings/player_settings_service.gd` — ConfigFile-backed typed settings store used as the `PlayerSettingsService` autoload.
- `tests/unit/test_player_settings_service.gd` — settings defaults, validation, signals, and persistence.
- `tests/integration/inertial_velocity_scene_test.gd` — real 120-frame rigid-body velocity-preservation test.
- `src/ui/velocity_marker_state.gd` — immutable-style projection result object.
- `src/ui/velocity_marker_math.gd` — pure camera-space projection and screen-edge clamping.
- `tests/unit/test_velocity_marker_math.gd` — trajectory marker math.
- `src/flight_room/flight_room_settings_coordinator.gd` — applies typed settings to camera and flight controller.
- `tests/integration/test_flight_room_settings_coordinator.gd` — coordinator wiring and idempotence.
- `src/ui/pause_menu.gd` — pause ownership and menu actions.
- `scenes/ui/pause_menu.tscn` — basic process-always pause panel.
- `tests/integration/test_pause_menu.gd` — pause state, settings writes, reset, and signal connection behavior.

### Modify

- `src/flight/flight_steering_math.gd` — energy-neutral perpendicular steering force.
- `src/flight/flight_model.gd` — remove unconditional lateral/vertical assist damping.
- `src/flight/flight_tuning.gd` — remove obsolete damping fields.
- `config/flight/player_flight_tuning.tres` — remove obsolete damping values.
- `src/player/ship_flight_controller.gd` — explicit validated mode setter; remove Escape mouse-capture ownership.
- `src/input/player_input_source.gd` — remove `toggle_mouse_capture` requirement and expose no pause handling.
- `src/camera/chase_camera_math.gd` — tactical position/rotation error clamps and exact view transforms.
- `src/camera/chase_camera_rig.gd` — behavior selection, temporary look views, and distance/behavior independence.
- `scenes/camera/chase_camera_rig.tscn` — locked camera defaults and exported parameters.
- `src/ui/flight_hud.gd` — Inertial copy, nose reticle, and velocity marker updates.
- `scenes/ui/flight_hud.tscn` — reticle and marker controls.
- `src/flight_room/flight_room_controller.gd` — pause-safe public reset remains the single restart path.
- `scenes/flight_room/flight_room.tscn` — coordinator and pause-menu instances.
- `project.godot` — settings autoload and new input actions.
- `tests/unit/test_flight_steering_math.gd`
- `tests/unit/test_flight_model.gd`
- `tests/unit/test_ship_flight_controller_state.gd`
- `tests/unit/test_chase_camera_math.gd`
- `tests/integration/test_chase_camera_rig.gd`
- `tests/integration/test_input_map.gd`
- `tests/integration/test_player_scene.gd`
- `tests/integration/test_flight_room_scene.gd`
- `tests/test_runner.gd`
- `tools/verify/verify.ps1`
- `tools/verify/verify.sh`
- `README.md`

---

### Task 1: Typed Camera Values and Persistent Settings Service

**Files:**
- Create: `src/camera/camera_behavior.gd`
- Create: `src/camera/camera_distance.gd`
- Create: `src/settings/player_settings_service.gd`
- Create: `tests/unit/test_player_settings_service.gd`
- Modify: `project.godot`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `CameraBehavior.Value`, `CameraDistance.Value`, and autoload `/root/PlayerSettingsService`.
- Produces: `PlayerSettingsStore.get_camera_behavior() -> CameraBehavior.Value`.
- Produces: `set_camera_behavior(value: CameraBehavior.Value) -> bool`, equivalent distance and flight-mode getters/setters, and typed change signals.
- Consumes: existing `FlightMode.Value.ASSISTED` and `FlightMode.Value.MANUAL`.

- [ ] **Step 1: Add the failing settings test and register it**

Create enum-contract assertions and persistence tests:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var path := "user://test_player_settings_%d.cfg" % Time.get_ticks_usec()
    var store := PlayerSettingsStore.new()
    var saved_events: Array[int] = []
    store.settings_saved.connect(func() -> void: saved_events.append(1))

    store.load_from_path(path)
    assert_equal(store.get_camera_behavior(), CameraBehavior.Value.TACTICAL, "missing file must use Tactical")
    assert_equal(store.get_camera_distance(), CameraDistance.Value.STANDARD, "missing file must use Standard")
    assert_equal(store.get_default_flight_mode(), FlightMode.Value.ASSISTED, "missing file must use Assisted")

    assert_true(store.set_camera_behavior(CameraBehavior.Value.LOCKED), "changed valid value must be accepted")
    assert_equal(saved_events.size(), 1, "one real change saves exactly once")
    assert_true(not store.set_camera_behavior(CameraBehavior.Value.LOCKED), "setting identical value must be a no-op")
    assert_equal(saved_events.size(), 1, "no-op must not save")

    var reloaded := PlayerSettingsStore.new()
    reloaded.load_from_path(path)
    assert_equal(reloaded.get_camera_behavior(), CameraBehavior.Value.LOCKED, "valid value must round-trip")

    var corrupt := ConfigFile.new()
    corrupt.set_value("camera", "behavior", 999)
    corrupt.set_value("camera", "distance", CameraDistance.Value.FAR)
    corrupt.set_value("flight", "default_mode", FlightMode.Value.MANUAL)
    corrupt.save(path)

    var repaired := PlayerSettingsStore.new()
    repaired.load_from_path(path)
    assert_equal(repaired.get_camera_behavior(), CameraBehavior.Value.TACTICAL, "invalid behavior falls back individually")
    assert_equal(repaired.get_camera_distance(), CameraDistance.Value.FAR, "valid distance survives another field's corruption")
    assert_equal(repaired.get_default_flight_mode(), FlightMode.Value.MANUAL, "valid flight mode survives another field's corruption")

    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    store.free()
    reloaded.free()
    repaired.free()
```

Add `res://tests/unit/test_player_settings_service.gd` to `TEST_SCRIPTS`.

- [ ] **Step 2: Run the suite and confirm RED**

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: the new suite fails because `PlayerSettingsStore`, `CameraBehavior`, and `CameraDistance` do not exist.

- [ ] **Step 3: Implement typed enums**

`src/camera/camera_behavior.gd`:

```gdscript
class_name CameraBehavior
extends RefCounted

enum Value { DYNAMIC, TACTICAL, LOCKED }

static func is_valid(value: int) -> bool:
    return value in [Value.DYNAMIC, Value.TACTICAL, Value.LOCKED]

static func semantic_name(value: Value) -> StringName:
    match value:
        Value.DYNAMIC:
            return &"dynamic"
        Value.LOCKED:
            return &"locked"
        _:
            return &"tactical"
```

`src/camera/camera_distance.gd` uses the same pattern with `CLOSE`, `STANDARD`, and `FAR`.

- [ ] **Step 4: Implement `PlayerSettingsStore`**

Use these public signals and defaults:

```gdscript
class_name PlayerSettingsStore
extends Node

signal camera_behavior_changed(value: CameraBehavior.Value)
signal camera_distance_changed(value: CameraDistance.Value)
signal default_flight_mode_changed(value: FlightMode.Value)
signal settings_saved

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULT_CAMERA_BEHAVIOR := CameraBehavior.Value.TACTICAL
const DEFAULT_CAMERA_DISTANCE := CameraDistance.Value.STANDARD
const DEFAULT_FLIGHT_MODE := FlightMode.Value.ASSISTED

var _path := DEFAULT_PATH
var _camera_behavior := DEFAULT_CAMERA_BEHAVIOR
var _camera_distance := DEFAULT_CAMERA_DISTANCE
var _default_flight_mode := DEFAULT_FLIGHT_MODE
var _loaded := false
```

Implement `load_from_path(path: String = DEFAULT_PATH)`, typed getters/setters, per-field validation, and `_save()` using `ConfigFile`. Missing files stay in memory and are not written until a real setter change. Emit `settings_saved` only after `ConfigFile.save()` returns `OK`.

- [ ] **Step 5: Register the autoload**

```ini
[autoload]
PlayerSettingsService="*res://src/settings/player_settings_service.gd"
```

The script class remains `PlayerSettingsStore`; the singleton name is `PlayerSettingsService`, avoiding a global-name collision.

- [ ] **Step 6: Run GREEN verification**

Run the import and full runner again. Expected: settings suite passes, no file leaks, and all earlier suites remain green.

- [ ] **Step 7: Commit**

```powershell
git add project.godot src/camera/camera_behavior.gd src/camera/camera_distance.gd src/settings/player_settings_service.gd tests/unit/test_player_settings_service.gd tests/test_runner.gd
git commit -m "feat: add typed player settings service"
```

---

### Task 2: Energy-Neutral Assisted Steering

**Files:**
- Modify: `src/flight/flight_steering_math.gd`
- Modify: `src/flight/flight_model.gd`
- Modify: `src/flight/flight_tuning.gd`
- Modify: `config/flight/player_flight_tuning.tres`
- Modify: `tests/unit/test_flight_steering_math.gd`
- Modify: `tests/unit/test_flight_model.gd`

**Interfaces:**
- Consumes: `FlightCommand`, `FlightTuning`, local linear velocity, and body mass.
- Produces: `FlightSteeringMath.assisted_force(local_velocity, desired_direction, input_amount, body_mass, steering_strength, minimum_speed, maximum_acceleration) -> Vector3`.
- Guarantees: returned assist force has zero component parallel to nonzero current velocity within tolerance.

- [ ] **Step 1: Write failing perpendicular-force tests**

```gdscript
var velocity := Vector3(22.0, -7.0, -48.0)
var force := FlightSteeringMath.assisted_force(
    velocity,
    Vector3.FORWARD,
    1.0,
    8500.0,
    1.25,
    8.0,
    18.0
)
assert_true(force.length() > 0.0, "misaligned forward travel must steer")
assert_true(absf(force.dot(velocity.normalized())) <= 0.001, "assist force must be perpendicular to velocity")
assert_equal(
    FlightSteeringMath.assisted_force(velocity, Vector3.FORWARD, 0.0, 8500.0, 1.25, 8.0, 18.0),
    Vector3.ZERO,
    "no steering intent means no assist force"
)
```

In `test_flight_model.gd`, assert assisted coasting with zero translation returns zero assist force even with large local X/Y velocity.

- [ ] **Step 2: Run RED verification**

Expected: signature mismatch and the old model still produces local damping while coasting.

- [ ] **Step 3: Implement the pure perpendicular steering calculation**

Replace the hard-coded desired direction with the new argument. Normalize safe inputs, calculate the desired component perpendicular to velocity, cap acceleration, then explicitly remove floating-point parallel residue:

```gdscript
var force := perpendicular.normalized() * acceleration * maxf(body_mass, 0.0)
force -= velocity_direction * force.dot(velocity_direction)
return force
```

Return zero for invalid direction, speed below minimum, zero input, or near-parallel alignment.

- [ ] **Step 4: Remove unconditional assist translation damping**

Delete these additions from `FlightModel.compute()`:

```gdscript
output.assist_force_local.x -= local_linear_velocity.x * tuning.assist_lateral_damping
output.assist_force_local.y -= local_linear_velocity.y * tuning.assist_vertical_damping
```

Call the new steering function with `Vector3.FORWARD` and the clamped forward input. Preserve angular damping and coordinated-bank torque.

- [ ] **Step 5: Remove obsolete tuning fields consistently**

Remove `assist_lateral_damping` and `assist_vertical_damping` from `FlightTuning`, the `.tres`, and tests. Do not leave dead settings that imply active drag.

- [ ] **Step 6: Run GREEN verification**

Expected: all flight math tests pass; speed-envelope acceleration/braking tests remain unchanged.

- [ ] **Step 7: Commit**

```powershell
git add src/flight/flight_steering_math.gd src/flight/flight_model.gd src/flight/flight_tuning.gd config/flight/player_flight_tuning.tres tests/unit/test_flight_steering_math.gd tests/unit/test_flight_model.gd
git commit -m "fix: preserve speed during assisted steering"
```

---

### Task 3: Explicit Inertial Mode and Real Physics Verification

**Files:**
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `src/ui/flight_hud.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`
- Create: `tests/integration/inertial_velocity_scene_test.gd`
- Modify: `tools/verify/verify.ps1`
- Modify: `tools/verify/verify.sh`

**Interfaces:**
- Produces: `ShipFlightController.set_flight_mode(value: FlightMode.Value) -> bool`.
- Produces: real-frame integration script exit code `0` only when two seconds of pure rotation preserve speed and world-velocity direction.
- Preserves: existing `F` toggle via the same setter path.

- [ ] **Step 1: Add failing setter and player-facing copy assertions**

```gdscript
var changed: Array[int] = []
controller.flight_mode_changed.connect(func(value: int) -> void: changed.append(value))
assert_true(controller.set_flight_mode(FlightMode.Value.MANUAL), "valid mode changes")
assert_equal(controller.get_flight_mode(), FlightMode.Value.MANUAL, "mode becomes inertial")
assert_equal(changed.size(), 1, "real change emits once")
assert_true(not controller.set_flight_mode(FlightMode.Value.MANUAL), "same mode is no-op")
assert_true(not controller.set_flight_mode(999), "invalid mode is rejected")
```

Update HUD expectations from `MODE   MANUAL` to `MODE   INERTIAL`.

- [ ] **Step 2: Run RED verification**

Expected: missing setter and old HUD text.

- [ ] **Step 3: Implement validated mode application**

```gdscript
func set_flight_mode(value: FlightMode.Value) -> bool:
    if value not in [FlightMode.Value.ASSISTED, FlightMode.Value.MANUAL]:
        return false
    if _flight_mode == value:
        return false
    _flight_mode = value
    _auto_bank_offset = 0.0
    _auto_bank_rate = 0.0
    flight_mode_changed.emit(_flight_mode)
    return true
```

Change the `F` toggle branch to call `set_flight_mode(ShipFlightState.toggled_mode(_flight_mode))`.

- [ ] **Step 4: Create the real rigid-body integration script**

The SceneTree script must instantiate `player_interceptor.tscn`, add it to the root, await one `physics_frame`, set Inertial mode, assign `Vector3(70.0, 20.0, -110.0)` as initial world velocity, hold `pitch_up`, await exactly 120 physics frames, release the action, and verify:

- orientation changes;
- angular velocity changes;
- speed drift is `<= 0.01 m/s`;
- direction drift is `<= 0.01 degrees`;
- last assist force is effectively zero.

Use:

```gdscript
var direction_error := rad_to_deg(
    initial_velocity.normalized().angle_to(body.linear_velocity.normalized())
)
```

Always release the input action and free the fixture before quitting.

- [ ] **Step 5: Add the dedicated integration command to both verifiers**

After the normal suite runner and before main-scene boot:

```powershell
Invoke-GodotStep `
    -Executable $godotExecutable `
    -Description "Verify inertial rigid-body velocity preservation" `
    -GodotArguments @(
        "--headless",
        "--path",
        ".",
        "--script",
        "res://tests/integration/inertial_velocity_scene_test.gd"
    )
```

Mirror the same command in `verify.sh`.

- [ ] **Step 6: Run GREEN verification**

```powershell
.\tools\verify\verify.ps1
```

Expected: normal suites pass, the dedicated inertial script prints its PASS line, and the main scene boots.

- [ ] **Step 7: Commit**

```powershell
git add src/player/ship_flight_controller.gd src/ui/flight_hud.gd tests/unit/test_ship_flight_controller_state.gd tests/integration/inertial_velocity_scene_test.gd tools/verify/verify.ps1 tools/verify/verify.sh
git commit -m "test: prove inertial velocity preservation"
```

---

### Task 4: Camera Behavior Modes and Tactical Bounds

**Files:**
- Modify: `src/camera/chase_camera_math.gd`
- Modify: `src/camera/chase_camera_rig.gd`
- Modify: `scenes/camera/chase_camera_rig.tscn`
- Modify: `tests/unit/test_chase_camera_math.gd`
- Modify: `tests/integration/test_chase_camera_rig.gd`

**Interfaces:**
- Produces: `select_behavior(value: CameraBehavior.Value) -> bool`.
- Produces: `get_selected_behavior() -> CameraBehavior.Value`.
- Produces: `select_distance(value: CameraDistance.Value) -> bool`, `get_selected_distance()`.
- Keeps compatibility wrappers `select_preset`, `get_selected_preset`, and `cycle_preset`.
- Produces pure `clamp_position_error()` and `clamp_rotation_error()` helpers.

- [ ] **Step 1: Add failing math and rig tests**

```gdscript
var clamped := ChaseCameraMath.clamp_position_error(
    Vector3(10.0, 0.0, 0.0),
    Vector3.ZERO,
    1.5
)
assert_true(is_equal_approx(clamped.length(), 1.5), "tactical position error must clamp to 1.5 m")
```

Create a desired basis rotated more than six degrees and verify `clamp_rotation_error(..., 6.0)` returns a basis whose quaternion angular distance from desired is no more than six degrees.

In rig tests verify the default is Tactical, Dynamic baselines remain `5.5 / 7.0 / 0.08 / 8.0`, Tactical uses `14.0 / 22.0 / 0.015 / 2.0`, behavior and distance are independent, invalid values are rejected, and Locked snaps in one step.

- [ ] **Step 2: Run RED verification**

Expected: behavior APIs and clamp helpers are missing.

- [ ] **Step 3: Add pure tactical clamp helpers**

```gdscript
static func clamp_position_error(candidate: Vector3, desired: Vector3, maximum_error: float) -> Vector3:
    var offset := candidate - desired
    return desired + offset.limit_length(maxf(maximum_error, 0.0))
```

For rotation, orthonormalize, convert to quaternions, measure angular error, and if over the limit return `desired.slerp(candidate, limit / error)`.

- [ ] **Step 4: Refactor the rig around behavior parameters**

```gdscript
const DYNAMIC_POSITION_SHARPNESS := 5.5
const DYNAMIC_ROTATION_SHARPNESS := 7.0
const DYNAMIC_VELOCITY_LOOK_AHEAD := 0.08
const DYNAMIC_MAX_PREDICTION := 8.0

const TACTICAL_POSITION_SHARPNESS := 14.0
const TACTICAL_ROTATION_SHARPNESS := 22.0
const TACTICAL_VELOCITY_LOOK_AHEAD := 0.015
const TACTICAL_MAX_PREDICTION := 2.0
const TACTICAL_MAX_POSITION_ERROR := 1.5
const TACTICAL_MAX_ROTATION_ERROR_DEGREES := 6.0
```

Dynamic follows the current algorithm. Tactical uses faster interpolation, reduced prediction, then clamps positional and rotational error. Locked writes desired position and basis directly each frame. FOV and distance interpolation remain shared.

- [ ] **Step 5: Preserve distance compatibility**

Map `CameraDistance.Value` numerically to the existing Close/Standard/Far preset dictionary. Keep `C` cycling distance only.

- [ ] **Step 6: Run GREEN verification**

Expected: camera math and rig tests pass; existing Dynamic calculations remain unchanged.

- [ ] **Step 7: Commit**

```powershell
git add src/camera/chase_camera_math.gd src/camera/chase_camera_rig.gd scenes/camera/chase_camera_rig.tscn tests/unit/test_chase_camera_math.gd tests/integration/test_chase_camera_rig.gd
git commit -m "feat: add tactical and locked chase cameras"
```

---

### Task 5: Exact Rear and Side Look Controls

**Files:**
- Modify: `project.godot`
- Modify: `src/input/player_input_source.gd`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `src/camera/chase_camera_math.gd`
- Modify: `src/camera/chase_camera_rig.gd`
- Modify: `tests/integration/test_input_map.gd`
- Modify: `tests/integration/test_primary_fire_input.gd`
- Modify: `tests/integration/test_chase_camera_rig.gd`

**Interfaces:**
- Adds actions: `toggle_pause`, `look_rear`, `look_right`, `look_left`.
- Removes Escape from `toggle_mouse_capture`; flight room no longer uses a mouse-capture toggle action.
- Produces exact temporary-view transform helper.
- Priority: rear, then right, then left.

- [ ] **Step 1: Add failing input-map assertions**

```gdscript
assert_true(_action_has_physical_key(&"toggle_pause", KEY_ESCAPE), "Escape pauses")
assert_true(_action_has_physical_key(&"look_rear", KEY_B), "B looks rear")
assert_true(_action_has_physical_key(&"look_right", KEY_PAGEUP), "PageUp looks right")
assert_true(_action_has_physical_key(&"look_left", KEY_PAGEDOWN), "PageDown looks left")
assert_true(not _action_has_physical_key(&"toggle_mouse_capture", KEY_ESCAPE), "Escape must not remain a mouse-capture toggle")
```

Update required-action tests so `PlayerInputSource` no longer requires `toggle_mouse_capture`.

- [ ] **Step 2: Add failing exact-view tests**

For identity target and Standard distance:

- rear origin is `(0, 4, -14)` and look direction is `+Z`;
- right origin is `(-14, 4, 0)` and look direction is `+X`;
- left origin is `(14, 4, 0)` and look direction is `-X`;
- simultaneous keys resolve rear > right > left;
- release restores selected behavior and distance.

- [ ] **Step 3: Run RED verification**

Expected: actions and exact-view logic are absent.

- [ ] **Step 4: Update input ownership**

Add the four actions in `project.godot`. Remove Escape from `toggle_mouse_capture`, remove that action from `PlayerInputSource.REQUIRED_ACTIONS`, remove `consume_capture_toggle()`, and delete the corresponding block from `ShipFlightController._physics_process()`.

- [ ] **Step 5: Implement exact view transform math**

Add a pure helper returning position and look target from target transform, view enum, rear offset, and height. Use the exact positions above; never apply camera lag or velocity prediction.

- [ ] **Step 6: Sample hold actions in the camera rig**

```gdscript
if Input.is_action_pressed(&"look_rear"):
    return TemporaryView.REAR
if Input.is_action_pressed(&"look_right"):
    return TemporaryView.RIGHT
if Input.is_action_pressed(&"look_left"):
    return TemporaryView.LEFT
return TemporaryView.NONE
```

On activation apply the exact transform. On release snap once to the selected chase behavior, then resume normal updates.

- [ ] **Step 7: Run GREEN verification**

Expected: input and camera suites pass, primary-fire mappings remain unchanged.

- [ ] **Step 8: Commit**

```powershell
git add project.godot src/input/player_input_source.gd src/player/ship_flight_controller.gd src/camera/chase_camera_math.gd src/camera/chase_camera_rig.gd tests/integration/test_input_map.gd tests/integration/test_primary_fire_input.gd tests/integration/test_chase_camera_rig.gd
git commit -m "feat: add exact rear and side views"
```

---

### Task 6: Nose Reticle and True Velocity Marker

**Files:**
- Create: `src/ui/velocity_marker_state.gd`
- Create: `src/ui/velocity_marker_math.gd`
- Create: `tests/unit/test_velocity_marker_math.gd`
- Modify: `src/ui/flight_hud.gd`
- Modify: `scenes/ui/flight_hud.tscn`
- Modify: `tests/integration/test_player_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `VelocityMarkerMath.project(camera_transform, vertical_fov_degrees, viewport_size, world_velocity, minimum_speed, safe_margin) -> VelocityMarkerState`.
- `VelocityMarkerState` fields: `visible`, `screen_position`, `clamped`, and `rotation_radians`.
- Flight HUD consumes the active `Camera3D` and controller world velocity.

- [ ] **Step 1: Write failing pure projection tests**

```gdscript
var hidden := VelocityMarkerMath.project(
    Transform3D.IDENTITY, 68.0, Vector2(1280, 720),
    Vector3(0.0, 0.0, -1.9), 2.0, 32.0
)
assert_true(not hidden.visible, "marker hides below 2 m/s")

var forward := VelocityMarkerMath.project(
    Transform3D.IDENTITY, 68.0, Vector2(1280, 720),
    Vector3(0.0, 0.0, -100.0), 2.0, 32.0
)
assert_true(forward.visible and not forward.clamped, "forward marker is visible")
assert_true(forward.screen_position.distance_to(Vector2(640, 360)) <= 1.0, "forward velocity projects at center")

var behind := VelocityMarkerMath.project(
    Transform3D.IDENTITY, 68.0, Vector2(1280, 720),
    Vector3(0.0, 0.0, 100.0), 2.0, 32.0
)
assert_true(behind.clamped, "behind velocity clamps")
assert_true(
    behind.screen_position.x >= 32.0
    and behind.screen_position.x <= 1248.0
    and behind.screen_position.y >= 32.0
    and behind.screen_position.y <= 688.0,
    "clamped marker stays inside safe margin"
)
```

Also test lateral drift and non-finite values.

- [ ] **Step 2: Run RED verification**

Expected: marker classes do not exist.

- [ ] **Step 3: Implement pure camera-space projection**

Transform normalized world velocity into camera-local coordinates. For front-facing vectors (`local.z < 0`), use vertical FOV and viewport aspect to compute NDC then screen coordinates. For behind-camera vectors, derive an edge direction by reversing local XY. Clamp from viewport center to the padded rectangle and return a rotation cue using `atan2`.

Do not call `Camera3D.unproject_position()` inside the pure helper.

- [ ] **Step 4: Add HUD scene nodes**

Add a fixed-center `NoseReticle` Control with four short cyan ColorRects and a `VelocityMarker` Control with a small ring/diamond and chevron. Add exported `camera_path`, `nose_reticle_path`, and `velocity_marker_path`. Keep the telemetry panel intact.

- [ ] **Step 5: Update `FlightHud`**

Resolve camera and marker controls. Each `_process`, retain telemetry, project with `2.0` and `32.0`, hide/show the marker, center it on returned coordinates, rotate only when clamped, and keep the nose reticle fixed. A missing camera hides only the marker and emits one error.

- [ ] **Step 6: Run GREEN verification**

Expected: marker math and player-scene path tests pass, no layout-node leaks.

- [ ] **Step 7: Commit**

```powershell
git add src/ui/velocity_marker_state.gd src/ui/velocity_marker_math.gd src/ui/flight_hud.gd scenes/ui/flight_hud.tscn tests/unit/test_velocity_marker_math.gd tests/integration/test_player_scene.gd tests/test_runner.gd
git commit -m "feat: show nose and velocity vectors"
```

---

### Task 7: Flight-Room Settings Coordinator

**Files:**
- Create: `src/flight_room/flight_room_settings_coordinator.gd`
- Create: `tests/integration/test_flight_room_settings_coordinator.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `PlayerSettingsStore`, `ChaseCameraRig`, `ShipFlightController`.
- Applies settings once at startup and on typed signals.
- Exposes no duplicate state.

- [ ] **Step 1: Write the failing coordinator integration test**

Build a fixture with a local `PlayerSettingsStore`, production player, and production camera rig. Set exported paths, add the coordinator, and assert initial Tactical/Standard/Assisted values apply; changing behavior to Locked updates the rig; changing distance to Far does not change behavior; changing mode to Manual updates the controller; repeated initialization does not duplicate callbacks; and freeing the fixture leaves no orphan nodes.

- [ ] **Step 2: Run RED verification**

Expected: coordinator class missing.

- [ ] **Step 3: Implement coordinator**

```gdscript
@export var settings_service_path: NodePath = NodePath("/root/PlayerSettingsService")
@export var camera_rig_path: NodePath
@export var flight_controller_path: NodePath
```

`initialize()` resolves dependencies, applies three values, connects each typed signal exactly once, and records `_initialized`. `_exit_tree()` disconnects live callables. Invalid dependencies push one error and disable only the coordinator.

- [ ] **Step 4: Run GREEN verification**

Expected: coordinator integration passes with no duplicate emissions or leaks.

- [ ] **Step 5: Commit**

```powershell
git add src/flight_room/flight_room_settings_coordinator.gd tests/integration/test_flight_room_settings_coordinator.gd tests/test_runner.gd
git commit -m "feat: apply flight room settings"
```

---

### Task 8: Basic Pause and Configuration Menu

**Files:**
- Create: `src/ui/pause_menu.gd`
- Create: `scenes/ui/pause_menu.tscn`
- Create: `tests/integration/test_pause_menu.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `/root/PlayerSettingsService`, `PlayerInputSource`, and `FlightRoomController`.
- Writes settings only through `PlayerSettingsStore`.
- Calls only `FlightRoomController.reset_player()` for Restart.
- Owns `toggle_pause` input and cursor release/restore.

- [ ] **Step 1: Add failing pause-menu tests**

Instantiate the scene with a local settings store and room fixture. Verify root process mode is `PROCESS_MODE_ALWAYS`; `open_menu()` pauses, shows, releases cursor, and focuses Resume; opening twice is a no-op; options write and persist settings; `resume_game()` unpauses and restores capture; restart unpauses then calls existing reset; repeated cycles do not duplicate callbacks; and cleanup always restores `tree.paused = false`.

- [ ] **Step 2: Run RED verification**

Expected: scene and class missing.

- [ ] **Step 3: Build the minimal scene**

Create a full-screen translucent backdrop and centered `PanelContainer` with title, Resume, Camera Behavior OptionButton, Camera Distance OptionButton, Flight Mode OptionButton, Restart Flight Room, and Quit. Set `process_mode = 3` on the CanvasLayer root. Use built-in controls only.

- [ ] **Step 4: Implement pause ownership**

```gdscript
func open_menu() -> bool
func resume_game() -> bool
func restart_flight_room() -> bool
func is_open() -> bool
```

Handle `toggle_pause` in `_unhandled_input`, mark viewport input handled, guard idempotently, store previous mouse capture, release on open, and restore on resume. Populate OptionButtons with enum IDs rather than display-index assumptions.

- [ ] **Step 5: Wire settings writes**

```gdscript
_settings.set_camera_behavior(id)
_settings.set_camera_distance(id)
_settings.set_default_flight_mode(id)
```

The coordinator, not the menu, applies values to gameplay.

- [ ] **Step 6: Implement failure safety**

If dependencies are missing, keep the tree unpaused, hide the menu, push one error, and disable input handling. Restart unpauses before invoking `reset_player()`.

- [ ] **Step 7: Run GREEN verification**

Expected: pause integration passes and runner exits with tree unpaused.

- [ ] **Step 8: Commit**

```powershell
git add src/ui/pause_menu.gd scenes/ui/pause_menu.tscn tests/integration/test_pause_menu.gd tests/test_runner.gd
git commit -m "feat: add basic pause settings menu"
```

---

### Task 9: Main Flight-Room Integration

**Files:**
- Modify: `scenes/flight_room/flight_room.tscn`
- Modify: `src/flight_room/flight_room_controller.gd`
- Modify: `tests/integration/test_flight_room_scene.gd`
- Modify: `tests/integration/test_player_scene.gd`
- Modify: `README.md`

**Interfaces:**
- Flight room owns one coordinator and one pause menu.
- Saved settings apply before normal play.
- Existing player, camera, reset volume, HUD, asteroid field, and future drone insertion points remain.

- [ ] **Step 1: Add failing scene-contract assertions**

```gdscript
assert_true(
    room.get_node_or_null("FlightRoomSettingsCoordinator") is FlightRoomSettingsCoordinator,
    "settings coordinator required"
)
assert_true(room.get_node_or_null("PauseMenu") is PauseMenu, "pause menu required")
```

Assert HUD contains NoseReticle and VelocityMarker, camera begins Tactical + Standard after settings apply, and FlightRoomController still owns reset.

- [ ] **Step 2: Run RED verification**

Expected: new nodes absent.

- [ ] **Step 3: Instance coordinator and pause menu**

Add exported paths to existing room nodes. Do not duplicate camera, HUD, player, or reset logic.

- [ ] **Step 4: Make reset pause-safe**

```gdscript
if get_tree() != null and get_tree().paused:
    get_tree().paused = false
```

Retain the existing freeze, transform restore, momentum clear, controller reset, unfreeze sequence.

- [ ] **Step 5: Update help copy and README**

Document Assisted/Inertial naming, Escape pause, B rear, PageUp right, PageDown left, Dynamic/Tactical/Locked, C distance cycling, velocity marker versus nose reticle, `user://settings.cfg`, and the dedicated inertial verifier. Do not advertise the practice drone as implemented.

- [ ] **Step 6: Run full GREEN verification**

```powershell
.\tools\verify\verify.ps1
```

Expected: asset and matrix validation pass; Godot imports; all registered suites pass; dedicated inertial integration passes; main scene boots; no parser, orphan-node, resources-in-use, or retained-resource warnings.

- [ ] **Step 7: Commit**

```powershell
git add scenes/flight_room/flight_room.tscn src/flight_room/flight_room_controller.gd tests/integration/test_flight_room_scene.gd tests/integration/test_player_scene.gd README.md
git commit -m "feat: integrate flight configuration milestone"
```

---

### Task 10: Windows Manual Acceptance and Final Evidence

**Files:**
- Modify only when acceptance exposes a concrete defect, and only the directly responsible tuning, test, or scene file.
- No speculative polish.

**Interfaces:**
- Consumes the complete milestone.
- Produces authoritative user-pasted Windows evidence.

- [ ] **Step 1: Verify branch and intended diff**

```powershell
git status --short
git log --oneline -12
git diff --check
```

Do not stage unrelated local files.

- [ ] **Step 2: Run authoritative verification**

```powershell
.\tools\verify\verify.ps1
```

Record the full output and actual suite count. Do not predict the count.

- [ ] **Step 3: Launch the main game**

```powershell
godot --path .
```

- [ ] **Step 4: Perform inertial acceptance**

Accelerate, switch to Inertial, release translation, rotate hard, confirm speed remains steady, and confirm velocity marker stays on the original trajectory while nose reticle moves.

- [ ] **Step 5: Perform assisted acceptance**

Switch to Assisted, command forward travel through a hard turn, and confirm velocity bends toward the nose without obvious speed collapse.

- [ ] **Step 6: Perform camera acceptance**

Verify Dynamic retains lag, Tactical stays close, Locked has no lag, distances remain independent, C changes distance only, and B/PageUp/PageDown show exact temporary views.

- [ ] **Step 7: Perform pause/settings acceptance**

Verify Escape pause/cursor ownership, no gameplay advancement while paused, keyboard/mouse navigation, persisted settings after restart, restart momentum reset, and debug showcase Escape-to-exit.

- [ ] **Step 8: Correct only evidenced defects**

Use `superpowers:systematic-debugging`, add or tighten a regression test first, implement one root-cause fix, and rerun the full verifier.

- [ ] **Step 9: Commit acceptance corrections when present**

```powershell
git add -p
git diff --cached --check
git commit -m "fix: close flight configuration acceptance gaps"
```

Skip the commit when no correction was needed.

- [ ] **Step 10: Close milestone**

Only after fresh clean output and manual confirmation, record the final commit and return to the already approved practice-drone spec/plan sequence.
