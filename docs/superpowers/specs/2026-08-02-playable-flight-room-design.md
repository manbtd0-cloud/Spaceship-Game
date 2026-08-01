# Playable Flight Room Design

**Project:** Shattered Orbit  
**Engine:** Godot 4.7.1 Standard  
**Renderer:** GL Compatibility  
**Target branch:** `agent/playable-flight-room`  
**Base branch:** `agent/godot-flight-foundation`

## Purpose

This milestone turns the verified pure flight mathematics into the first genuinely playable Shattered Orbit build. The result is a focused third-person space-flight room where the player can fly a readable placeholder interceptor through spatial landmarks, switch between assisted and manual six-axis flight, judge drift and acceleration, and verify the chase camera and telemetry loop.

The milestone proves flight feel, input architecture, physics integration, camera behavior, scene composition, and local Windows verification before any heavy Blender asset conversion, combat, mission scripting, or cinematic systems are introduced.

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
10. Existing foundation tests remain green and the new unit and integration suites pass through `tools/verify/verify.ps1` on Windows.

## Selected Approach

Use a physics-first playable flight room with a procedural placeholder craft.

This approach keeps flight behavior isolated from asset-import uncertainty. The existing Blender candidates remain quarantined under raw source assets until the controller, input, camera, scene composition, and tests are proven. The placeholder is intentionally more readable than a primitive cube but remains cheap, deterministic, and editable directly in Godot.

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
- Unit tests for pure input and camera helpers.
- Scene composition and integration smoke tests.
- Windows and Bash verification compatibility.

### Explicitly Excluded

- Real Blender ship integration.
- Weapons, projectiles, damage, shields, targets, enemies, or combat AI.
- Mission logic, dialogue, cinematics, checkpoints, scoring, menus, save data, or audio production.
- Large asteroid fields, procedural world generation, streaming, or origin rebasing.
- Gamepad support in this milestone.
- Final art direction, final HUD styling, or production VFX.

## Architectural Boundaries

The playable room is divided into focused units. Input sampling, pure command shaping, physics application, camera calculation, HUD presentation, and room composition remain separate.

### Existing Pure Flight Domain

The following verified classes remain authoritative and are not duplicated:

- `FlightMode`
- `FlightCommand`
- `FlightTuning`
- `FlightOutput`
- `FlightModel`

`FlightModel.compute()` continues to produce local force and torque from a command, tuning resource, local linear velocity, and local angular velocity. Godot scene code consumes that output but does not reimplement its formulas.

### New Runtime Components

#### `PlayerInputSource`

Path: `src/input/player_input_source.gd`

Responsibility:

- Sample configured Godot input actions.
- Accumulate relative mouse motion while captured.
- Convert keyboard and mouse state into a normalized `FlightCommand`.
- Emit one-shot requests for flight-mode toggle, mouse capture toggle, and reset.

Public interface:

```gdscript
class_name PlayerInputSource
extends Node

@export var mouse_sensitivity: float = 0.0025
@export var mouse_response: float = 1.0

func sample_command(current_mode: FlightMode.Value) -> FlightCommand
func consume_mode_toggle() -> bool
func consume_capture_toggle() -> bool
func consume_reset_request() -> bool
func set_mouse_captured(captured: bool) -> void
func is_mouse_captured() -> bool
```

Rules:

- Translation and rotation axes are clamped to `[-1.0, 1.0]`.
- Diagonal keyboard input is normalized so combined strafing does not exceed one unit of command magnitude.
- Mouse delta is consumed once per physics frame and then cleared.
- Mouse input controls pitch and yaw only; roll remains on `Q/E`.
- No physics state is read or changed by this class.

#### `ShipFlightController`

Path: `src/player/ship_flight_controller.gd`

Responsibility:

- Own current flight mode.
- Ask `PlayerInputSource` for a `FlightCommand` each physics frame.
- Transform body velocities into local space.
- Call `FlightModel.compute()`.
- Transform local force and torque back into world space.
- Apply central force and torque to the `RigidBody3D`.
- Expose read-only telemetry for camera and HUD.
- Handle mode toggling and reset requests without rewriting momentum during ordinary mode changes.

Public interface:

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
- Flight-mode changes alter only the command mode; they never set transform or velocity.
- Reset is handled by the room controller, not by the flight model.

#### `ChaseCameraMath`

Path: `src/camera/chase_camera_math.gd`

Responsibility:

Provide pure, testable camera calculations:

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
```

The helper contains no nodes, global state, or input access.

#### `ChaseCameraRig`

Path: `src/camera/chase_camera_rig.gd`

Responsibility:

- Follow the player independently from the body hierarchy.
- Smooth position and aim using frame-rate-independent exponential interpolation.
- Add restrained velocity look-ahead and speed pullback.
- Smooth FOV from speed and boost state.
- Respect ship roll partially rather than copying it fully.
- Avoid snapping during ordinary rotation.

Public configuration:

```gdscript
@export var target_path: NodePath
@export var controller_path: NodePath
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

Camera safety rules:

- Invalid target or controller paths produce a clear error and disable processing rather than crashing repeatedly.
- FOV remains within `[base_fov, max_fov]`.
- Smoothing uses `1.0 - exp(-sharpness * delta)` rather than frame-dependent fixed lerp values.
- The camera starts at the calculated desired position to avoid a first-frame sweep from the origin.

#### `FlightHud`

Path: `src/ui/flight_hud.gd`

Responsibility:

- Display rounded speed in metres per second.
- Display `ASSISTED` or `MANUAL` mode.
- Display boost state and amount.
- Display mouse-capture hint and concise control reference.
- Read controller state only; never modify flight behavior.

The HUD remains restrained, high-contrast, and functional. It uses built-in fonts and simple panels so no external UI asset is required.

#### `FlightRoomController`

Path: `src/flight_room/flight_room_controller.gd`

Responsibility:

- Resolve the player body and controller.
- Capture the initial spawn transform.
- Respond to reset requests.
- Reset the player when it enters the reset volume or exceeds the room boundary.
- Restore transform and clear velocities only during an explicit reset.
- Re-capture the mouse when the room starts.

Reset behavior:

```gdscript
body.freeze = true
body.global_transform = spawn_transform
body.linear_velocity = Vector3.ZERO
body.angular_velocity = Vector3.ZERO
body.freeze = false
body.sleeping = false
```

Reset is the only gameplay operation in this milestone permitted to clear momentum directly.

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

- Long nose and swept wings clearly communicate forward direction.
- Twin engine pods and emissive rear surfaces identify the rear.
- Neutral dark hull, lighter edge panels, and cool emissive accents remain readable against space.
- Meshes use built-in `BoxMesh`, `PrismMesh`, `CylinderMesh`, and simple materials.
- The collision shape is a conservative convex-like combination using one primary `BoxShape3D`; decorative wings do not define collision.

### Camera Scene

Path: `scenes/camera/chase_camera_rig.tscn`

```text
ChaseCameraRig (Node3D)
└── Camera3D
```

The rig is instantiated as a sibling of the player under the flight room, not as a child of the physics body.

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

The bootstrap scene will instantiate or switch to `flight_room.tscn`, making the flight room the default playable destination while retaining the bootstrap boundary for future loading and game-state work.

## Input Map

The project input actions use physical keyboard events where practical so layout changes have predictable behavior.

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
| `boost` | `Shift` | Scale forward/reverse thrust using existing boost rules |
| `toggle_flight_mode` | `F` | Toggle assisted/manual |
| `toggle_mouse_capture` | `Escape` | Release or recapture pointer |
| `reset_flight_room` | `R` | Return to spawn and clear velocity |

Mouse motion:

- Horizontal delta controls yaw.
- Vertical delta controls pitch with inverted screen-space sign so moving the mouse upward pitches the nose upward.
- Mouse motion is ignored while the pointer is not captured.

Existing fire actions remain configured but unused.

## Data Flow

Each physics frame follows this sequence:

1. `PlayerInputSource` consumes keyboard state and accumulated mouse delta.
2. It returns a normalized `FlightCommand` carrying current flight mode, translation, rotation, and boost.
3. `ShipFlightController` converts the body’s world velocities into local space.
4. `FlightModel.compute()` returns local force and torque.
5. The controller transforms force and torque into world space and applies them to the body.
6. The controller updates telemetry values.
7. `ChaseCameraRig` reads body transform, world velocity, speed, and boost telemetry during its process update and smooths toward the desired camera state.
8. `FlightHud` reads telemetry and updates visible labels.
9. `FlightRoomController` handles explicit reset requests and boundary/reset-volume events.

No HUD or camera component writes to physics state. No scene component duplicates the force equations.

## Tuning Baseline

The existing `FlightTuning` defaults remain the starting baseline:

- Forward force: `120000.0`
- Reverse force: `50000.0`
- Strafe force: `65000.0`
- Rotation torque: `45000.0`
- Boost multiplier: `1.8`
- Assisted linear damping: `2.5`
- Assisted angular damping: `3.5`

A dedicated `.tres` resource may override these values for the player scene, but the first implementation should use the existing defaults unless runtime verification proves a value unusable. Any tuning adjustment must be made in the resource, not embedded in controller code.

## Flight Room Visual Design

The room is a controlled readability environment rather than an empty void.

- Background: deep blue-black environment with low ambient energy.
- Lighting: one cool key light, one restrained fill light, and emissive course markers.
- Start area: a large rectangular gate frames the initial forward direction.
- Navigation course: multiple rings at varied distance, elevation, and yaw encourage all movement axes.
- Drift zone: evenly spaced luminous markers make lateral momentum visible in manual mode.
- Pylons: solid collision objects provide close-range scale and obstacle feedback.
- Distant references: large dim geometric forms prevent the horizon from feeling featureless.
- Reset boundary: a large invisible box or radius check returns the player when too far from the course.

Compatibility-renderer constraints:

- Use StandardMaterial3D, primitive meshes, baked/simple emission, and modest light counts.
- Do not depend on volumetric fog, screen-space reflections, advanced particle systems, or renderer-specific effects.
- Keep geometry and material count low enough for integrated graphics development hardware.

## Error Handling

- Every exported `NodePath` is validated in `_ready()`.
- Missing required nodes produce one descriptive `push_error()` message and disable the affected component.
- Input sampling returns a neutral command if required actions are unavailable rather than throwing.
- Camera math clamps invalid negative sharpness, pullback, and FOV values to safe ranges.
- Reset logic checks `is_instance_valid()` before touching the body.
- The test runner must treat an unloadable suite as a failure rather than calling `.new()` on an invalid script.
- No continuous per-frame error spam is permitted.

## Testing Strategy

All production behavior follows red-green-refactor ordering.

### Existing Tests

The existing harness and pure `FlightModel` suite must remain unchanged in behavior and continue passing.

### New Unit Tests

#### Input command composition

Path: `tests/unit/test_player_input_math.gd`

Test pure helper behavior for:

- Opposing keys cancel.
- Diagonal translation is normalized.
- Pitch and yaw mouse deltas are clamped.
- Boost remains in `[0.0, 1.0]`.
- Mode value passes through unchanged.

Input tests should target a pure helper rather than mocking the global `Input` singleton.

#### Camera mathematics

Path: `tests/unit/test_chase_camera_math.gd`

Test:

- Exponential weight is zero for zero delta.
- Weight remains in `[0.0, 1.0]`.
- Pullback increases with speed but respects `max_pullback`.
- Desired position uses the target’s basis and local offset.
- Velocity look-ahead moves the look target in the velocity direction.

#### Controller state

Path: `tests/unit/test_ship_flight_state.gd`

Test a pure state helper for:

- Assisted toggles to manual and back.
- Toggle does not alter supplied transform or velocity snapshots.
- Speed telemetry returns vector length.
- Reset is represented as an explicit request rather than an automatic mode side effect.

### Integration Tests

#### Player scene composition

Path: `tests/integration/test_player_interceptor_scene.gd`

Instantiate `player_interceptor.tscn` and assert:

- Root is `RigidBody3D`.
- Mass, gravity, damping, and CCD match the specification.
- Input source and controller exist.
- Controller paths resolve.
- Collision shape and visual hierarchy exist.

#### Flight room composition

Path: `tests/integration/test_flight_room_scene.gd`

Instantiate `flight_room.tscn` and assert:

- Player, camera, HUD, environment, course, reset volume, and room controller exist.
- Camera target and controller paths resolve.
- HUD controller path resolves.
- The course contains at least three navigation rings, two pylons, and four drift markers.

#### Headless smoke test

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

Expected automated result after implementation:

```text
PASS: 7 suites
```

The exact suite count is part of this milestone and includes the existing two suites plus five new unit/integration suites.

## Manual Acceptance Procedure

1. Open the project and run the default scene.
2. Confirm the pointer captures and the craft is visible from the chase camera.
3. Fly through the start gate using `W`, mouse pitch/yaw, and `Q/E` roll.
4. Use `A/D`, `Space`, and `Ctrl` to verify lateral and vertical translation.
5. Hold `Shift` while thrusting and confirm a clear acceleration and camera/FOV response.
6. In assisted mode, create lateral drift and release input; confirm drift decays gradually.
7. Press `F`, create lateral drift in manual mode, and release input; confirm drift persists.
8. Press `F` during motion and confirm position and velocity do not snap or reset.
9. Make ordinary turns and confirm the camera follows smoothly without sudden jumps.
10. Release the mouse with `Escape`, recapture it, and confirm controls resume normally.
11. Press `R` and confirm the ship returns to spawn with zero velocity.
12. Cross the reset boundary and confirm the same safe reset occurs.
13. Observe the HUD and confirm speed, mode, boost, and capture state remain accurate.

## Completion Definition

This design is complete only when automated verification passes on Godot 4.7.1 and the manual acceptance procedure confirms usable flight feel. Passing the milestone permits the next specification: auditing the two Blender player-ship candidates, selecting the hero craft, and producing a Godot-ready runtime GLB without changing the proven controller interfaces.
