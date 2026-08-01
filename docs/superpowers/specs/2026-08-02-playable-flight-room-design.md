# Playable Flight Room Design

**Project:** Shattered Orbit  
**Engine:** Godot 4.7.1 Standard  
**Renderer:** GL Compatibility  
**Target branch:** `agent/playable-flight-room`  
**Base branch:** `agent/godot-flight-foundation`

## Purpose

This milestone turns the verified pure flight mathematics into the first genuinely playable Shattered Orbit build. The result is a focused third-person space-flight room where the player can fly a readable placeholder interceptor through spatial landmarks, switch between assisted and manual six-axis flight, judge drift and acceleration, and verify the chase camera and telemetry loop.

The milestone proves flight feel, input architecture, physics integration, camera behavior, scene composition, and Windows verification before any heavy Blender asset conversion, combat, mission scripting, or cinematic systems are introduced.

## Success Criteria

The milestone is accepted when all of the following are true:

1. The project imports and boots in Godot 4.7.1 without script or scene errors.
2. The player controls a `RigidBody3D` interceptor using keyboard and mouse.
3. Assisted mode gradually opposes lateral, vertical, and angular drift without teleporting, snapping, or directly rewriting velocity.
4. Manual mode preserves six-axis momentum when no thrust or torque input is applied.
5. Boost is clearly stronger than normal thrust but remains controllable.
6. Switching flight mode preserves transform, linear velocity, and angular velocity.
7. The chase camera follows smoothly without ordinary-turn snapping or excessive roll-induced disorientation.
8. Spatial reference geometry makes speed, scale, drift, and turning radius easy to judge.
9. The HUD reports speed, flight mode, boost state, and mouse-capture state.
10. Existing foundation tests remain green and all new suites pass through `tools/verify/verify.ps1` on Windows.

## Selected Approach

Use a physics-first playable flight room with a procedural placeholder craft.

This isolates flight behavior from asset-import uncertainty. The Blender candidates remain quarantined under raw source assets until the controller, input, camera, scene composition, and tests are proven. The placeholder is intentionally more readable than a primitive cube but remains cheap, deterministic, and editable directly in Godot.

Rejected alternatives:

- **Real-asset-first:** would mix scale, orientation, materials, collision, and import problems with flight-controller debugging.
- **Presentation-first:** would create camera and VFX polish around unproven physics and risk hiding weak control behavior.

## Scope

### Included

- Player `RigidBody3D` scene.
- Procedural interceptor silhouette and collision hull.
- Keyboard and mouse input source.
- Assisted and manual flight modes.
- Application of the existing pure `FlightModel` output to Godot physics.
- Smooth third-person chase camera.
- Lightweight telemetry HUD.
- Spatial flight-test room with gates, rings, pylons, markers, lighting, and reset handling.
- Unit tests for pure input, state, and camera helpers.
- Scene composition and integration smoke tests.
- Windows PowerShell and Bash verification compatibility.

### Explicitly Excluded

- Real Blender ship integration.
- Weapons, projectiles, damage, shields, targets, enemies, or combat AI.
- Mission logic, dialogue, cinematics, checkpoints, scoring, menus, save data, or production audio.
- Large asteroid fields, procedural world generation, streaming, or origin rebasing.
- Gamepad support in this milestone.
- Final art direction, final HUD styling, or production VFX.

## Architectural Boundaries

Input sampling, pure command shaping, mode state, physics application, camera calculation, HUD presentation, and room composition remain separate.

### Existing Pure Flight Domain

The following verified classes remain authoritative and are not duplicated:

- `FlightMode`
- `FlightCommand`
- `FlightTuning`
- `FlightOutput`
- `FlightModel`

`FlightModel.compute()` continues to produce local force and torque from a command, tuning resource, local linear velocity, and local angular velocity. Scene code consumes that output but never reimplements its formulas.

### `PlayerInputMath`

Path: `src/input/player_input_math.gd`

Responsibility: provide pure, deterministic command-shaping functions without reading Godot’s global `Input` singleton.

```gdscript
class_name PlayerInputMath
extends RefCounted

static func compose_translation(
    left: float,
    right: float,
    down: float,
    up: float,
    forward: float,
    reverse: float
) -> Vector3

static func compose_rotation(
    mouse_delta: Vector2,
    roll_left: float,
    roll_right: float,
    mouse_sensitivity: float,
    max_mouse_command: float
) -> Vector3

static func clamp_boost(value: float) -> float
```

Rules:

- Each digital input is normalized to `[0.0, 1.0]` before combination.
- Opposing inputs cancel.
- Translation magnitude is limited to `1.0` so diagonal strafing cannot exceed the intended command magnitude.
- Rotation components are clamped to `[-1.0, 1.0]`.
- Upward mouse movement produces positive pitch command after screen-space inversion.

### `ShipFlightState`

Path: `src/player/ship_flight_state.gd`

Responsibility: contain pure flight-mode and telemetry helpers independently from nodes and physics.

```gdscript
class_name ShipFlightState
extends RefCounted

static func toggled_mode(mode: FlightMode.Value) -> FlightMode.Value
static func speed_mps(world_velocity: Vector3) -> float
```

Rules:

- `ASSISTED` toggles to `MANUAL` and `MANUAL` toggles to `ASSISTED`.
- Mode calculation has no transform or velocity side effects.
- Speed is the Euclidean length of world velocity.

### `PlayerInputSource`

Path: `src/input/player_input_source.gd`

Responsibility:

- Sample configured Godot input actions.
- Accumulate relative mouse motion while captured.
- Use `PlayerInputMath` to build a normalized `FlightCommand`.
- Expose one-shot requests for flight-mode toggle, mouse capture toggle, and reset.

```gdscript
class_name PlayerInputSource
extends Node

@export var mouse_sensitivity: float = 0.0025
@export var max_mouse_command: float = 1.0

func sample_command(current_mode: FlightMode.Value) -> FlightCommand
func consume_mode_toggle() -> bool
func consume_capture_toggle() -> bool
func consume_reset_request() -> bool
func set_mouse_captured(captured: bool) -> void
func is_mouse_captured() -> bool
```

Rules:

- Mouse delta is consumed once per physics frame and then cleared.
- Mouse controls pitch and yaw only; roll remains on `Q/E`.
- Mouse motion is ignored while the pointer is not captured.
- This class never reads or changes physics state.
- If a configured action is missing, its contribution is neutral and one descriptive warning is emitted during initialization.

### `ShipFlightController`

Path: `src/player/ship_flight_controller.gd`

Responsibility:

- Own current flight mode.
- Ask `PlayerInputSource` for a command each physics frame.
- Transform body velocities into local space.
- Call `FlightModel.compute()`.
- Transform local force and torque back into world space.
- Apply central force and torque to the `RigidBody3D`.
- Expose read-only telemetry for camera and HUD.
- Emit reset requests without performing the reset itself.

```gdscript
class_name ShipFlightController
extends Node

signal flight_mode_changed(mode: FlightMode.Value)
signal reset_requested

@export var body_path: NodePath
@export var input_source_path: NodePath
@export var tuning: FlightTuning

func get_flight_mode() -> FlightMode.Value
func get_speed_mps() -> float
func get_boost_amount() -> float
func get_local_velocity() -> Vector3
func get_world_velocity() -> Vector3
func get_body() -> RigidBody3D
```

Physics rules:

- Root body mass: `8500.0` kilograms.
- Gravity scale: `0.0`.
- Linear and angular damping: `0.0`; assistance is provided only by `FlightModel`.
- Continuous collision detection is enabled.
- Local `-Z` is forward.
- Forces are applied through `apply_central_force()` and `apply_torque()`.
- Mode changes use `ShipFlightState.toggled_mode()` and never set transform or velocity.
- Reset is handled only by the room controller.

### `ChaseCameraMath`

Path: `src/camera/chase_camera_math.gd`

Responsibility: provide pure, testable camera calculations.

```gdscript
class_name ChaseCameraMath
extends RefCounted

static func exponential_weight(sharpness: float, delta: float) -> float

static func desired_position(
    target_transform: Transform3D,
    world_velocity: Vector3,
    base_offset: Vector3,
    velocity_look_ahead: float,
    speed_pullback: float,
    max_pullback: float
) -> Vector3

static func desired_look_target(
    target_transform: Transform3D,
    world_velocity: Vector3,
    look_ahead_distance: float
) -> Vector3

static func desired_fov(
    speed_mps: float,
    boost_amount: float,
    base_fov: float,
    speed_fov_gain: float,
    boost_fov_gain: float,
    max_fov: float
) -> float
```

The helper contains no nodes, global state, or input access.

### `ChaseCameraRig`

Path: `src/camera/chase_camera_rig.gd`

Responsibility:

- Follow the player independently from the body hierarchy.
- Smooth position and aim using frame-rate-independent exponential interpolation.
- Add restrained velocity look-ahead and speed pullback.
- Smooth FOV from speed and boost state.
- Respect ship roll partially rather than copying it fully.
- Avoid snapping during ordinary rotation.

```gdscript
class_name ChaseCameraRig
extends Node3D

@export var target_path: NodePath
@export var controller_path: NodePath
@export var camera_path: NodePath
@export var base_offset := Vector3(0.0, 4.0, 16.0)
@export var position_sharpness: float = 5.5
@export var rotation_sharpness: float = 7.0
@export var velocity_look_ahead: float = 0.08
@export var look_ahead_distance: float = 0.12
@export var speed_pullback: float = 0.025
@export var max_pullback: float = 10.0
@export var base_fov: float = 68.0
@export var speed_fov_gain: float = 0.03
@export var boost_fov_gain: float = 6.0
@export var max_fov: float = 82.0
@export_range(0.0, 1.0) var roll_influence: float = 0.35
```

Safety rules:

- Invalid target, controller, or camera paths produce one clear error and disable processing.
- FOV remains within `[base_fov, max_fov]`.
- Smoothing uses `1.0 - exp(-sharpness * delta)` rather than fixed frame-dependent lerp values.
- The rig starts at its calculated desired position to avoid a first-frame sweep from the origin.

### `FlightHud`

Path: `src/ui/flight_hud.gd`

Responsibility:

- Display rounded speed in metres per second.
- Display `ASSISTED` or `MANUAL` mode.
- Display boost state and percentage.
- Display mouse-capture hint and concise controls.
- Read controller and input state only; never modify flight behavior.

```gdscript
class_name FlightHud
extends CanvasLayer

@export var controller_path: NodePath
@export var input_source_path: NodePath
@export var speed_label_path: NodePath
@export var mode_label_path: NodePath
@export var boost_label_path: NodePath
@export var capture_label_path: NodePath
@export var controls_label_path: NodePath
```

The HUD uses built-in fonts and simple high-contrast panels; no external UI asset is required.

### `FlightRoomController`

Path: `src/flight_room/flight_room_controller.gd`

Responsibility:

- Resolve the player body, controller, input source, and reset volume.
- Capture the initial spawn transform.
- Respond to explicit reset requests.
- Reset the player when it enters the reset volume or exceeds the boundary radius.
- Re-capture the mouse when the room starts.

```gdscript
class_name FlightRoomController
extends Node

@export var player_body_path: NodePath
@export var player_controller_path: NodePath
@export var input_source_path: NodePath
@export var reset_volume_path: NodePath
@export var boundary_radius: float = 2500.0

func reset_player() -> void
```

Reset sequence:

```gdscript
body.freeze = true
body.global_transform = spawn_transform
body.linear_velocity = Vector3.ZERO
body.angular_velocity = Vector3.ZERO
body.freeze = false
body.sleeping = false
```

Reset is the only operation in this milestone permitted to clear momentum directly.

## Scene Structure

### Player Scene

Path: `scenes/player/player_interceptor.tscn`

```text
PlayerInterceptor (RigidBody3D)
├── CollisionShape3D
├── Visuals (Node3D)
│   ├── Fuselage
│   ├── Nose
│   ├── LeftWing
│   ├── RightWing
│   ├── LeftEngine
│   ├── RightEngine
│   ├── LeftEngineGlow
│   └── RightEngineGlow
├── PlayerInputSource
└── ShipFlightController
```

Visual requirements:

- A long nose and swept wings communicate forward direction.
- Twin engine pods and emissive rear surfaces identify the rear.
- Neutral dark hull, lighter edge panels, and cool emissive accents remain readable against space.
- Meshes use built-in `BoxMesh`, `PrismMesh`, `CylinderMesh`, and simple materials.
- One conservative `BoxShape3D` covers the fuselage and inner wing area; decorative extremities do not define collision.

### Camera Scene

Path: `scenes/camera/chase_camera_rig.tscn`

```text
ChaseCameraRig (Node3D)
└── Camera3D
```

The rig is a sibling of the player under the flight room, never a child of the physics body.

### HUD Scene

Path: `scenes/ui/flight_hud.tscn`

```text
FlightHud (CanvasLayer)
└── SafeArea (MarginContainer)
    └── Layout (VBoxContainer)
        ├── SpeedLabel
        ├── ModeLabel
        ├── BoostLabel
        ├── CaptureLabel
        └── ControlsLabel
```

### Flight Room Scene

Path: `scenes/flight_room/flight_room.tscn`

```text
FlightRoom (Node3D)
├── WorldEnvironment
├── KeyLight
├── FillLight
├── PlayerInterceptor
├── ChaseCameraRig
├── FlightHud
├── Course (Node3D)
│   ├── StartGate
│   ├── NavigationRings
│   ├── Pylons
│   ├── DriftMarkers
│   └── DistantReferenceShapes
├── ResetVolume (Area3D)
└── FlightRoomController
```

### Bootstrap Behavior

`src/core/bootstrap.gd` performs one deferred transition:

```gdscript
func _ready() -> void:
    call_deferred("_enter_flight_room")

func _enter_flight_room() -> void:
    get_tree().change_scene_to_file("res://scenes/flight_room/flight_room.tscn")
```

The bootstrap remains the configured `run/main_scene`, preserving a stable entry boundary for future loading and game-state work while making the flight room the default playable destination.

## Input Map

Physical keyboard events are used where practical.

| Action | Default input | Purpose |
|---|---|---|
| `thrust_forward` | `W` | Forward thrust along local `-Z` |
| `thrust_reverse` | `S` | Reverse thrust |
| `strafe_left` | `A` | Local left translation |
| `strafe_right` | `D` | Local right translation |
| `strafe_up` | `Space` | Local up translation |
| `strafe_down` | `Ctrl` | Local down translation |
| `roll_left` | `Q` | Roll left |
| `roll_right` | `E` | Roll right |
| `boost` | `Shift` | Scale thrust using existing boost rules |
| `toggle_flight_mode` | `F` | Toggle assisted/manual |
| `toggle_mouse_capture` | `Escape` | Release or recapture pointer |
| `reset_flight_room` | `R` | Return to spawn and clear velocity |

Mouse motion:

- Horizontal delta controls yaw.
- Vertical delta controls pitch with screen-space inversion so moving upward pitches the nose upward.
- Mouse motion is ignored while the pointer is not captured.

Existing fire actions remain configured but unused.

## Data Flow

Each physics frame follows this sequence:

1. `PlayerInputSource` consumes keyboard state and accumulated mouse delta.
2. `PlayerInputMath` converts raw values into normalized translation, rotation, and boost.
3. `PlayerInputSource` returns a `FlightCommand` carrying current mode and shaped input.
4. `ShipFlightController` converts world velocities into local space.
5. `FlightModel.compute()` returns local force and torque.
6. The controller transforms force and torque into world space and applies them to the body.
7. The controller updates telemetry values.
8. `ChaseCameraRig` reads body transform, velocity, speed, and boost, then smooths toward values from `ChaseCameraMath`.
9. `FlightHud` reads telemetry and input capture state.
10. `FlightRoomController` handles explicit reset requests and boundary/reset-volume events.

No HUD or camera component writes to physics state. No scene component duplicates force equations.

## Tuning Baseline

The existing `FlightTuning` defaults remain the starting baseline:

- Forward force: `120000.0`
- Reverse force: `50000.0`
- Strafe force: `65000.0`
- Rotation torque: `45000.0`
- Boost multiplier: `1.8`
- Assisted linear damping: `2.5`
- Assisted angular damping: `3.5`

A player-specific `FlightTuning` resource may override these values only after manual verification proves a default unusable. Any adjustment belongs in the resource, never embedded in controller code.

## Flight Room Visual Design

The room is a controlled readability environment rather than an empty void.

- Deep blue-black environment with low ambient energy.
- One cool key light, one restrained fill light, and emissive course markers.
- A large start gate frames the initial forward direction.
- At least three rings at varied distance, elevation, and yaw encourage all movement axes.
- At least four evenly spaced luminous drift markers make lateral momentum visible.
- At least two solid pylons provide collision, scale, and obstacle feedback.
- Large dim distant forms prevent the horizon from feeling featureless.
- A reset volume and `2500.0` metre boundary radius prevent permanent loss.

Compatibility-renderer constraints:

- Use `StandardMaterial3D`, primitive meshes, simple emission, and modest light counts.
- Do not depend on volumetric fog, screen-space reflections, advanced particles, or renderer-specific effects.
- Keep geometry and material count appropriate for integrated graphics development hardware.

## Error Handling

- Every exported `NodePath` is validated in `_ready()`.
- Missing required nodes produce one descriptive `push_error()` and disable the affected component.
- Missing input actions contribute neutral values and produce one initialization warning.
- Camera math clamps negative sharpness, pullback, look-ahead, and FOV values to safe ranges.
- Reset logic checks `is_instance_valid()` before touching the body.
- The test runner must verify `script.can_instantiate()` before calling `.new()` so parse failures are reported as suite-load failures instead of cascading runtime errors.
- No continuous per-frame error spam is permitted.

## Testing Strategy

All production behavior follows red-green-refactor ordering.

### Existing Tests

The existing harness and `FlightModel` suite must retain behavior and remain green.

### New Unit Tests

#### Input math

Path: `tests/unit/test_player_input_math.gd`

Verify:

- Opposing keys cancel.
- Diagonal translation is normalized.
- Mouse pitch/yaw are clamped.
- Upward mouse movement produces upward pitch.
- Boost remains in `[0.0, 1.0]`.

#### Camera math

Path: `tests/unit/test_chase_camera_math.gd`

Verify:

- Exponential weight is zero for zero delta.
- Weight remains in `[0.0, 1.0]`.
- Pullback increases with speed but respects `max_pullback`.
- Desired position uses target basis and local offset.
- Velocity look-ahead moves the aim target in velocity direction.
- FOV respects configured minimum and maximum.

#### Flight state

Path: `tests/unit/test_ship_flight_state.gd`

Verify:

- Assisted toggles to manual and back.
- Mode calculation leaves supplied transform and velocity snapshots unchanged.
- Speed telemetry equals vector length.

### Integration Tests

#### Player scene composition

Path: `tests/integration/test_player_interceptor_scene.gd`

Instantiate `player_interceptor.tscn` and assert:

- Root is `RigidBody3D`.
- Mass, gravity, damping, and CCD match this specification.
- Input source and controller exist.
- Controller paths resolve.
- Collision shape and visual hierarchy exist.

#### Flight room composition

Path: `tests/integration/test_flight_room_scene.gd`

Instantiate `flight_room.tscn` and assert:

- Player, camera, HUD, environment, course, reset volume, and room controller exist.
- Camera target/controller paths resolve.
- HUD controller/input paths resolve.
- Room-controller paths resolve.
- Course contains at least three navigation rings, two pylons, and four drift markers.

### Headless Smoke Test

The main scene must boot for two seconds through the existing verifier without parse errors, missing-node errors, or crashes.

## Verification Commands

Windows PowerShell:

```powershell
.\tools\verify\verify.ps1
```

Linux or Git Bash:

```bash
./tools/verify/verify.sh
```

Expected automated result:

```text
PASS: 7 suites
```

The count includes the existing two suites plus five new unit/integration suites.

## Manual Acceptance Procedure

1. Run the default scene and confirm the pointer captures and the craft is visible.
2. Fly through the start gate using `W`, mouse pitch/yaw, and `Q/E` roll.
3. Use `A/D`, `Space`, and `Ctrl` to verify lateral and vertical translation.
4. Hold `Shift` while thrusting and confirm clear acceleration and camera/FOV response.
5. In assisted mode, create lateral drift and release input; drift must decay gradually.
6. Press `F`, create lateral drift in manual mode, and release input; drift must persist.
7. Press `F` during motion and confirm position and velocity do not snap or reset.
8. Make ordinary turns and confirm the camera follows without sudden jumps.
9. Release the mouse with `Escape`, recapture it, and confirm controls resume.
10. Press `R` and confirm the ship returns to spawn with zero velocity.
11. Cross the reset volume or boundary and confirm the same safe reset occurs.
12. Confirm HUD speed, mode, boost, and capture state remain accurate.

## Completion Definition

This milestone is complete only when automated verification passes on Godot 4.7.1 and the manual acceptance procedure confirms usable flight feel. Completion permits the next specification: audit the two Blender player-ship candidates, select the hero craft, and produce a Godot-ready runtime GLB without changing the proven controller interfaces.
