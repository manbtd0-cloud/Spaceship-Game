# Playable Flight Room Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first playable third-person Shattered Orbit flight room with tested six-axis physics, keyboard/mouse controls, assisted/manual modes, a smooth chase camera, telemetry HUD, and a spatial course.

**Architecture:** Preserve the verified pure `FlightModel` as the only force/torque authority. Add pure input/state/camera helpers around it, then connect focused Godot nodes for input sampling, physics application, camera presentation, HUD display, and room reset/composition. Raw Blender assets remain quarantined; this milestone uses a lightweight procedural interceptor.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, GL Compatibility renderer, dependency-free headless test runner, PowerShell/Bash local verification.

## Global Constraints

- Engine is exactly Godot 4.7.1 Standard.
- Renderer remains `gl_compatibility`; do not introduce Forward+ only features.
- Local `-Z` is ship forward.
- Player body mass is exactly `8500.0`, gravity scale `0.0`, built-in linear damping `0.0`, built-in angular damping `0.0`, and continuous collision detection enabled.
- `FlightModel.compute()` remains the only implementation of flight force and torque equations.
- Assisted/manual mode changes never modify transform, linear velocity, or angular velocity.
- Only an explicit room reset may clear momentum.
- No external Godot add-ons, runtime dependencies, downloaded assets, GitHub Actions workflows, gamepad support, combat, missions, final VFX, or Blender model integration.
- All five new suites plus the two existing suites must finish with `PASS: 7 suites`.
- Every production behavior is introduced with a failing test first.

---

## File Map

### Existing files modified

- `project.godot` — physical keyboard bindings for all flight-room actions.
- `src/core/bootstrap.gd` — deferred transition from bootstrap to the flight room.
- `tests/test_runner.gd` — register exactly five new suites.
- `README.md` — playable controls, verification command, and milestone status.

### New pure logic

- `src/input/player_input_math.gd` — deterministic translation, rotation, and boost shaping.
- `src/player/ship_flight_state.gd` — deterministic mode toggle and speed telemetry.
- `src/camera/chase_camera_math.gd` — deterministic camera position, look target, smoothing, and FOV calculations.

### New runtime nodes

- `src/input/player_input_source.gd` — Godot `Input` sampling and mouse accumulation.
- `src/player/ship_flight_controller.gd` — apply verified flight output to `RigidBody3D`.
- `src/camera/chase_camera_rig.gd` — independent smoothed chase camera.
- `src/ui/flight_hud.gd` — read-only flight telemetry presentation.
- `src/flight_room/flight_room_controller.gd` — spawn/reset/boundary orchestration.

### New scenes/resources

- `scenes/player/player_interceptor.tscn`
- `scenes/camera/chase_camera_rig.tscn`
- `scenes/ui/flight_hud.tscn`
- `scenes/flight_room/flight_room.tscn`
- `resources/flight/player_flight_tuning.tres`

### New tests

- `tests/unit/test_player_input_math.gd`
- `tests/unit/test_ship_flight_state.gd`
- `tests/unit/test_chase_camera_math.gd`
- `tests/integration/test_player_scene.gd`
- `tests/integration/test_flight_room_scene.gd`

---

### Task 1: Pure Input Shaping and Physical Input Bindings

**Files:**
- Create: `src/input/player_input_math.gd`
- Create: `tests/unit/test_player_input_math.gd`
- Modify: `tests/test_runner.gd`
- Modify: `project.godot`

**Interfaces:**
- Consumes: Godot `Vector2`, `Vector3`, `clampf()`.
- Produces:
  - `PlayerInputMath.compose_translation(left, right, down, up, forward, reverse) -> Vector3`
  - `PlayerInputMath.compose_rotation(mouse_delta, roll_left, roll_right, mouse_sensitivity, max_mouse_command) -> Vector3`
  - `PlayerInputMath.clamp_boost(value) -> float`

- [ ] **Step 1: Write the failing input-math suite**

Create `tests/unit/test_player_input_math.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(
        PlayerInputMath.compose_translation(1.0, 1.0, 0.0, 0.0, 0.0, 0.0),
        Vector3.ZERO,
        "opposing horizontal inputs must cancel"
    )

    var diagonal := PlayerInputMath.compose_translation(
        0.0, 1.0, 0.0, 1.0, 1.0, 0.0
    )
    assert_true(
        is_equal_approx(diagonal.length(), 1.0),
        "combined translation must be normalized"
    )
    assert_true(diagonal.z < 0.0, "forward input must use local negative Z")

    var rotation := PlayerInputMath.compose_rotation(
        Vector2(400.0, -300.0),
        0.0,
        0.0,
        0.01,
        1.0
    )
    assert_equal(
        rotation,
        Vector3(1.0, -1.0, 0.0),
        "mouse pitch and yaw must invert screen-space motion and clamp"
    )

    assert_true(
        is_equal_approx(PlayerInputMath.clamp_boost(-2.0), 0.0),
        "boost must clamp below zero"
    )
    assert_true(
        is_equal_approx(PlayerInputMath.clamp_boost(2.0), 1.0),
        "boost must clamp above one"
    )
```

Register it after `test_flight_model.gd` in `tests/test_runner.gd`:

```gdscript
"res://tests/unit/test_player_input_math.gd",
```

- [ ] **Step 2: Run the suite and verify the red failure**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: non-zero exit because `PlayerInputMath` does not exist.

- [ ] **Step 3: Implement the minimal pure input helper**

Create `src/input/player_input_math.gd`:

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
) -> Vector3:
    var value := Vector3(
        clampf(right, 0.0, 1.0) - clampf(left, 0.0, 1.0),
        clampf(up, 0.0, 1.0) - clampf(down, 0.0, 1.0),
        clampf(reverse, 0.0, 1.0) - clampf(forward, 0.0, 1.0)
    )
    return value.normalized() if value.length_squared() > 1.0 else value

static func compose_rotation(
    mouse_delta: Vector2,
    roll_left: float,
    roll_right: float,
    mouse_sensitivity: float,
    max_mouse_command: float
) -> Vector3:
    var limit := maxf(max_mouse_command, 0.0)
    return Vector3(
        clampf(-mouse_delta.y * mouse_sensitivity, -limit, limit),
        clampf(-mouse_delta.x * mouse_sensitivity, -limit, limit),
        clampf(
            clampf(roll_right, 0.0, 1.0) - clampf(roll_left, 0.0, 1.0),
            -1.0,
            1.0
        )
    )

static func clamp_boost(value: float) -> float:
    return clampf(value, 0.0, 1.0)
```

- [ ] **Step 4: Add physical keyboard bindings**

Replace the empty event arrays in `project.godot` with `InputEventKey` entries using these physical keycodes:

```text
W = 87
S = 83
A = 65
D = 68
Space = 32
Ctrl = 4194328
Q = 81
E = 69
Shift = 4194325
F = 70
Escape = 4194305
R = 82
```

Add missing actions:

```text
toggle_mouse_capture
reset_flight_room
```

Keep `fire_primary` and `fire_secondary` configured but unused.

- [ ] **Step 5: Verify green**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected: `PASS: 3 suites`, project import succeeds, bootstrap still boots.

- [ ] **Step 6: Commit**

```bash
git add project.godot src/input/player_input_math.gd tests/unit/test_player_input_math.gd tests/test_runner.gd
git commit -m "feat: add deterministic flight input shaping"
```

---

### Task 2: Pure Flight Mode and Telemetry State

**Files:**
- Create: `src/player/ship_flight_state.gd`
- Create: `tests/unit/test_ship_flight_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `FlightMode.Value`, `Vector3`.
- Produces:
  - `ShipFlightState.toggled_mode(mode) -> FlightMode.Value`
  - `ShipFlightState.speed_mps(world_velocity) -> float`

- [ ] **Step 1: Write the failing state suite**

Create `tests/unit/test_ship_flight_state.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.ASSISTED),
        FlightMode.Value.MANUAL,
        "assisted mode must toggle to manual"
    )
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.MANUAL),
        FlightMode.Value.ASSISTED,
        "manual mode must toggle to assisted"
    )
    assert_true(
        is_equal_approx(
            ShipFlightState.speed_mps(Vector3(3.0, 4.0, 12.0)),
            13.0
        ),
        "speed telemetry must use vector magnitude"
    )
```

Register:

```gdscript
"res://tests/unit/test_ship_flight_state.gd",
```

- [ ] **Step 2: Verify red**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: non-zero exit because `ShipFlightState` does not exist.

- [ ] **Step 3: Implement minimal state helper**

Create `src/player/ship_flight_state.gd`:

```gdscript
class_name ShipFlightState
extends RefCounted

static func toggled_mode(mode: FlightMode.Value) -> FlightMode.Value:
    return (
        FlightMode.Value.MANUAL
        if mode == FlightMode.Value.ASSISTED
        else FlightMode.Value.ASSISTED
    )

static func speed_mps(world_velocity: Vector3) -> float:
    return world_velocity.length()
```

- [ ] **Step 4: Verify green**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected: `PASS: 4 suites`.

- [ ] **Step 5: Commit**

```bash
git add src/player/ship_flight_state.gd tests/unit/test_ship_flight_state.gd tests/test_runner.gd
git commit -m "feat: add pure flight mode state"
```

---

### Task 3: Player Input Source, Physics Controller, and Interceptor Scene

**Files:**
- Create: `src/input/player_input_source.gd`
- Create: `src/player/ship_flight_controller.gd`
- Create: `resources/flight/player_flight_tuning.tres`
- Create: `scenes/player/player_interceptor.tscn`
- Create: `tests/integration/test_player_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes:
  - `PlayerInputMath.compose_translation()`
  - `PlayerInputMath.compose_rotation()`
  - `PlayerInputMath.clamp_boost()`
  - `ShipFlightState.toggled_mode()`
  - `ShipFlightState.speed_mps()`
  - `FlightModel.compute()`
- Produces:
  - `PlayerInputSource.sample_command(current_mode) -> FlightCommand`
  - one-shot input request methods from the approved spec
  - `ShipFlightController` telemetry getters and signals from the approved spec
  - `player_interceptor.tscn` with exact body properties and required child nodes

- [ ] **Step 1: Write the failing player-scene integration suite**

Create `tests/integration/test_player_scene.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/player/player_interceptor.tscn") as PackedScene
    assert_true(packed != null, "player scene must load")
    if packed == null:
        return

    var player := packed.instantiate() as RigidBody3D
    assert_true(player != null, "player root must be RigidBody3D")
    if player == null:
        return

    assert_true(is_equal_approx(player.mass, 8500.0), "player mass must be 8500 kg")
    assert_true(is_equal_approx(player.gravity_scale, 0.0), "player gravity must be disabled")
    assert_true(is_equal_approx(player.linear_damp, 0.0), "built-in linear damping must be zero")
    assert_true(is_equal_approx(player.angular_damp, 0.0), "built-in angular damping must be zero")
    assert_true(player.continuous_cd, "continuous collision detection must be enabled")
    assert_true(player.get_node_or_null("CollisionShape3D") is CollisionShape3D, "player needs collision")
    assert_true(player.get_node_or_null("Visuals") is Node3D, "player needs visuals")
    assert_true(player.get_node_or_null("PlayerInputSource") is PlayerInputSource, "player needs input source")
    assert_true(player.get_node_or_null("ShipFlightController") is ShipFlightController, "player needs controller")

    var visuals := player.get_node("Visuals")
    for child_name: String in [
        "Fuselage", "Nose", "LeftWing", "RightWing",
        "LeftEngine", "RightEngine", "LeftEngineGlow", "RightEngineGlow"
    ]:
        assert_true(
            visuals.get_node_or_null(child_name) is MeshInstance3D,
            "missing visual component: %s" % child_name
        )

    player.free()
```

Register:

```gdscript
"res://tests/integration/test_player_scene.gd",
```

- [ ] **Step 2: Verify red**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: non-zero exit because the player scene and runtime classes do not exist.

- [ ] **Step 3: Implement `PlayerInputSource`**

Create `src/input/player_input_source.gd` with the approved public interface. Use these exact internal rules:

```gdscript
class_name PlayerInputSource
extends Node

@export var mouse_sensitivity: float = 0.0025
@export var max_mouse_command: float = 1.0

const REQUIRED_ACTIONS: Array[StringName] = [
    &"thrust_forward", &"thrust_reverse", &"strafe_left", &"strafe_right",
    &"strafe_up", &"strafe_down", &"roll_left", &"roll_right", &"boost",
    &"toggle_flight_mode", &"toggle_mouse_capture", &"reset_flight_room"
]

var _mouse_delta := Vector2.ZERO
var _available_actions: Dictionary = {}
var _captured := false

func _ready() -> void:
    for action: StringName in REQUIRED_ACTIONS:
        var available := InputMap.has_action(action)
        _available_actions[action] = available
        if not available:
            push_warning("Missing input action: %s" % action)

func _unhandled_input(event: InputEvent) -> void:
    if _captured and event is InputEventMouseMotion:
        _mouse_delta += event.relative

func sample_command(current_mode: FlightMode.Value) -> FlightCommand:
    var command := FlightCommand.new()
    command.mode = current_mode
    command.translation = PlayerInputMath.compose_translation(
        _strength(&"strafe_left"), _strength(&"strafe_right"),
        _strength(&"strafe_down"), _strength(&"strafe_up"),
        _strength(&"thrust_forward"), _strength(&"thrust_reverse")
    )
    command.rotation = PlayerInputMath.compose_rotation(
        _mouse_delta,
        _strength(&"roll_left"),
        _strength(&"roll_right"),
        mouse_sensitivity,
        max_mouse_command
    )
    command.boost = PlayerInputMath.clamp_boost(_strength(&"boost"))
    _mouse_delta = Vector2.ZERO
    return command

func consume_mode_toggle() -> bool:
    return _just_pressed(&"toggle_flight_mode")

func consume_capture_toggle() -> bool:
    return _just_pressed(&"toggle_mouse_capture")

func consume_reset_request() -> bool:
    return _just_pressed(&"reset_flight_room")

func set_mouse_captured(captured: bool) -> void:
    _captured = captured
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
    if not captured:
        _mouse_delta = Vector2.ZERO

func is_mouse_captured() -> bool:
    return _captured

func _strength(action: StringName) -> float:
    return Input.get_action_strength(action) if _available_actions.get(action, false) else 0.0

func _just_pressed(action: StringName) -> bool:
    return Input.is_action_just_pressed(action) if _available_actions.get(action, false) else false
```

- [ ] **Step 4: Implement `ShipFlightController`**

Create `src/player/ship_flight_controller.gd` with the approved exported paths, signals, and getters. The physics update must follow this exact sequence:

```gdscript
func _physics_process(_delta: float) -> void:
    if _body == null or _input_source == null or tuning == null:
        return

    if _input_source.consume_capture_toggle():
        _input_source.set_mouse_captured(not _input_source.is_mouse_captured())

    if _input_source.consume_mode_toggle():
        _flight_mode = ShipFlightState.toggled_mode(_flight_mode)
        flight_mode_changed.emit(_flight_mode)

    if _input_source.consume_reset_request():
        reset_requested.emit()

    var command := _input_source.sample_command(_flight_mode)
    _boost_amount = command.boost

    var basis := _body.global_transform.basis.orthonormalized()
    var local_linear_velocity := basis.inverse() * _body.linear_velocity
    var local_angular_velocity := basis.inverse() * _body.angular_velocity
    var output := FlightModel.compute(
        command,
        tuning,
        local_linear_velocity,
        local_angular_velocity
    )

    _body.apply_central_force(basis * output.force_local)
    _body.apply_torque(basis * output.torque_local)
    _local_velocity = local_linear_velocity
```

In `_ready()`, resolve `body_path` and `input_source_path` once. On invalid paths, emit one `push_error()` and disable physics processing.

- [ ] **Step 5: Create tuning resource**

Create `resources/flight/player_flight_tuning.tres` using the current verified defaults:

```text
forward_force = 120000.0
reverse_force = 50000.0
strafe_force = 65000.0
rotation_torque = 45000.0
boost_multiplier = 1.8
assist_linear_damping = 2.5
assist_angular_damping = 3.5
```

- [ ] **Step 6: Create the procedural interceptor scene**

Create `scenes/player/player_interceptor.tscn` with:

```text
PlayerInterceptor (RigidBody3D)
  mass = 8500.0
  gravity_scale = 0.0
  linear_damp_mode = REPLACE
  linear_damp = 0.0
  angular_damp_mode = REPLACE
  angular_damp = 0.0
  continuous_cd = true
├── CollisionShape3D (BoxShape3D size approximately 8 x 2.5 x 12)
├── Visuals
│   ├── Fuselage (BoxMesh, elongated along Z)
│   ├── Nose (PrismMesh or tapered BoxMesh, extending toward local -Z)
│   ├── LeftWing / RightWing (thin swept BoxMesh instances)
│   ├── LeftEngine / RightEngine (CylinderMesh rotated along Z)
│   └── LeftEngineGlow / RightEngineGlow (emissive rear discs)
├── PlayerInputSource
└── ShipFlightController
```

Use three `StandardMaterial3D` resources: dark hull, lighter panel, cool cyan-blue emission. Configure controller paths as `body_path = NodePath("..")`, `input_source_path = NodePath("../PlayerInputSource")`, and assign `player_flight_tuning.tres`.

- [ ] **Step 7: Verify green**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected: `PASS: 5 suites`; import and bootstrap remain clean.

- [ ] **Step 8: Commit**

```bash
git add src/input/player_input_source.gd src/player/ship_flight_controller.gd resources/flight/player_flight_tuning.tres scenes/player/player_interceptor.tscn tests/integration/test_player_scene.gd tests/test_runner.gd
git commit -m "feat: add playable interceptor physics scene"
```

---

### Task 4: Pure Camera Math and Independent Chase Camera

**Files:**
- Create: `src/camera/chase_camera_math.gd`
- Create: `src/camera/chase_camera_rig.gd`
- Create: `scenes/camera/chase_camera_rig.tscn`
- Create: `tests/unit/test_chase_camera_math.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: player body transform, controller velocity/speed/boost telemetry.
- Produces: approved `ChaseCameraMath` methods and `ChaseCameraRig` exported properties.

- [ ] **Step 1: Write the failing camera-math suite**

Create `tests/unit/test_chase_camera_math.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_equal_approx(ChaseCameraMath.exponential_weight(0.0, 1.0), 0.0),
        "zero sharpness must produce zero interpolation"
    )
    assert_true(
        ChaseCameraMath.exponential_weight(5.0, 0.5) > 0.0,
        "positive sharpness and delta must interpolate"
    )

    var transform := Transform3D.IDENTITY
    var position := ChaseCameraMath.desired_position(
        transform,
        Vector3(0.0, 0.0, -100.0),
        Vector3(0.0, 4.0, 16.0),
        0.08,
        0.025,
        10.0
    )
    assert_true(position.y > 0.0, "camera must remain above the ship")
    assert_true(position.z > 16.0, "speed must pull the camera backward")

    assert_true(
        is_equal_approx(
            ChaseCameraMath.desired_fov(1000.0, 1.0, 68.0, 0.03, 6.0, 82.0),
            82.0
        ),
        "FOV must clamp to max_fov"
    )
```

Register:

```gdscript
"res://tests/unit/test_chase_camera_math.gd",
```

- [ ] **Step 2: Verify red**

Run the headless test runner. Expected: failure because `ChaseCameraMath` does not exist.

- [ ] **Step 3: Implement pure camera math**

Create `src/camera/chase_camera_math.gd`:

```gdscript
class_name ChaseCameraMath
extends RefCounted

static func exponential_weight(sharpness: float, delta: float) -> float:
    return 1.0 - exp(-maxf(sharpness, 0.0) * maxf(delta, 0.0))

static func desired_position(
    target_transform: Transform3D,
    world_velocity: Vector3,
    base_offset: Vector3,
    velocity_look_ahead: float,
    speed_pullback: float,
    max_pullback: float
) -> Vector3:
    var speed := world_velocity.length()
    var pullback := minf(speed * maxf(speed_pullback, 0.0), maxf(max_pullback, 0.0))
    var local_offset := base_offset + Vector3(0.0, 0.0, pullback)
    return (
        target_transform.origin
        + target_transform.basis.orthonormalized() * local_offset
        + world_velocity * maxf(velocity_look_ahead, 0.0)
    )

static func desired_look_target(
    target_transform: Transform3D,
    world_velocity: Vector3,
    look_ahead_distance: float
) -> Vector3:
    return target_transform.origin + world_velocity * maxf(look_ahead_distance, 0.0)

static func desired_fov(
    speed_mps: float,
    boost_amount: float,
    base_fov: float,
    speed_fov_gain: float,
    boost_fov_gain: float,
    max_fov: float
) -> float:
    var upper := maxf(max_fov, base_fov)
    return clampf(
        base_fov
        + maxf(speed_mps, 0.0) * maxf(speed_fov_gain, 0.0)
        + clampf(boost_amount, 0.0, 1.0) * maxf(boost_fov_gain, 0.0),
        base_fov,
        upper
    )
```

- [ ] **Step 4: Implement the chase rig**

Create `src/camera/chase_camera_rig.gd` with the approved properties. `_ready()` resolves target/controller/camera, initializes the rig directly at `desired_position`, sets FOV, and disables processing on invalid paths.

Use this process logic:

```gdscript
func _process(delta: float) -> void:
    var desired_position := ChaseCameraMath.desired_position(
        _target.global_transform,
        _controller.get_world_velocity(),
        base_offset,
        velocity_look_ahead,
        speed_pullback,
        max_pullback
    )
    global_position = global_position.lerp(
        desired_position,
        ChaseCameraMath.exponential_weight(position_sharpness, delta)
    )

    var look_target := ChaseCameraMath.desired_look_target(
        _target.global_transform,
        _controller.get_world_velocity(),
        look_ahead_distance
    )
    var blended_up := Vector3.UP.lerp(
        _target.global_transform.basis.y.normalized(),
        clampf(roll_influence, 0.0, 1.0)
    ).normalized()
    var desired_basis := global_transform.looking_at(look_target, blended_up).basis
    var current_quaternion := global_transform.basis.get_rotation_quaternion()
    var desired_quaternion := desired_basis.get_rotation_quaternion()
    global_basis = Basis(
        current_quaternion.slerp(
            desired_quaternion,
            ChaseCameraMath.exponential_weight(rotation_sharpness, delta)
        )
    )

    var target_fov := ChaseCameraMath.desired_fov(
        _controller.get_speed_mps(),
        _controller.get_boost_amount(),
        base_fov,
        speed_fov_gain,
        boost_fov_gain,
        max_fov
    )
    _camera.fov = lerpf(
        _camera.fov,
        target_fov,
        ChaseCameraMath.exponential_weight(rotation_sharpness, delta)
    )
```

- [ ] **Step 5: Create camera scene**

Create `scenes/camera/chase_camera_rig.tscn`:

```text
ChaseCameraRig (Node3D, script ChaseCameraRig)
└── Camera3D
    current = true
    near = 0.1
    far = 10000.0
    fov = 68.0
```

Set `camera_path = NodePath("Camera3D")`; target and controller paths are assigned by the flight-room scene.

- [ ] **Step 6: Verify green**

Run verifier. Expected: `PASS: 6 suites`.

- [ ] **Step 7: Commit**

```bash
git add src/camera/chase_camera_math.gd src/camera/chase_camera_rig.gd scenes/camera/chase_camera_rig.tscn tests/unit/test_chase_camera_math.gd tests/test_runner.gd
git commit -m "feat: add smooth chase camera"
```

---

### Task 5: Read-Only Flight Telemetry HUD

**Files:**
- Create: `src/ui/flight_hud.gd`
- Create: `scenes/ui/flight_hud.tscn`

**Interfaces:**
- Consumes: `ShipFlightController` getters and `PlayerInputSource.is_mouse_captured()`.
- Produces: visible labels named `SpeedLabel`, `ModeLabel`, `BoostLabel`, `CaptureLabel`, `ControlsLabel`.

- [ ] **Step 1: Extend the existing red player-scene test with HUD-independent telemetry assertions**

Before HUD implementation, add to `tests/integration/test_player_scene.gd`:

```gdscript
var controller := player.get_node("ShipFlightController") as ShipFlightController
assert_equal(
    controller.get_flight_mode(),
    FlightMode.Value.ASSISTED,
    "player must start in assisted mode"
)
assert_true(
    is_equal_approx(controller.get_boost_amount(), 0.0),
    "player must start with zero boost telemetry"
)
```

Run the test runner and confirm these assertions pass against Task 3. This establishes the telemetry contract the HUD will read.

- [ ] **Step 2: Implement HUD script**

Create `src/ui/flight_hud.gd`. Resolve all approved paths in `_ready()` and disable processing with one `push_error()` if any required node is invalid.

Use this display format in `_process()`:

```gdscript
_speed_label.text = "SPEED  %04d m/s" % roundi(_controller.get_speed_mps())
_mode_label.text = (
    "MODE   ASSISTED"
    if _controller.get_flight_mode() == FlightMode.Value.ASSISTED
    else "MODE   MANUAL"
)
var boost_percent := roundi(_controller.get_boost_amount() * 100.0)
_boost_label.text = "BOOST  %03d%%" % boost_percent
_capture_label.text = (
    "MOUSE  CAPTURED — ESC TO RELEASE"
    if _input_source.is_mouse_captured()
    else "MOUSE  RELEASED — ESC TO CAPTURE"
)
_controls_label.text = (
    "W/S THRUST   A/D STRAFE   SPACE/CTRL VERTICAL   "
    + "MOUSE PITCH/YAW   Q/E ROLL   SHIFT BOOST   F MODE   R RESET"
)
```

- [ ] **Step 3: Create HUD scene**

Create `scenes/ui/flight_hud.tscn` with the exact approved hierarchy. Use built-in fonts, a semi-transparent dark `StyleBoxFlat`, 16 px margins, and high-contrast white/cyan text. Configure every exported label path explicitly.

- [ ] **Step 4: Import verification**

Run:

```powershell
godot --headless --path . --editor --quit
```

Expected: zero exit with no HUD parse or scene errors.

- [ ] **Step 5: Commit**

```bash
git add src/ui/flight_hud.gd scenes/ui/flight_hud.tscn tests/integration/test_player_scene.gd
git commit -m "feat: add flight telemetry hud"
```

---

### Task 6: Spatial Flight Room, Reset Orchestration, and Bootstrap Transition

**Files:**
- Create: `src/flight_room/flight_room_controller.gd`
- Create: `scenes/flight_room/flight_room.tscn`
- Create: `tests/integration/test_flight_room_scene.gd`
- Modify: `src/core/bootstrap.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: player, camera, HUD scenes; controller `reset_requested` signal; input-source mouse capture.
- Produces: default playable flight room, explicit reset, boundary reset, bootstrap scene transition.

- [ ] **Step 1: Write the failing room integration suite**

Create `tests/integration/test_flight_room_scene.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/flight_room/flight_room.tscn") as PackedScene
    assert_true(packed != null, "flight room scene must load")
    if packed == null:
        return

    var room := packed.instantiate() as Node3D
    assert_true(room != null, "flight room root must be Node3D")
    if room == null:
        return

    assert_true(room.get_node_or_null("PlayerInterceptor") is RigidBody3D, "room needs player")
    assert_true(room.get_node_or_null("ChaseCameraRig") is ChaseCameraRig, "room needs camera rig")
    assert_true(room.get_node_or_null("FlightHud") is FlightHud, "room needs HUD")
    assert_true(room.get_node_or_null("ResetVolume") is Area3D, "room needs reset volume")
    assert_true(room.get_node_or_null("FlightRoomController") is FlightRoomController, "room needs controller")
    assert_true(room.get_node_or_null("Course/StartGate") is Node3D, "room needs start gate")
    assert_true(room.get_node("Course/NavigationRings").get_child_count() >= 5, "room needs at least five rings")
    assert_true(room.get_node("Course/Pylons").get_child_count() >= 6, "room needs at least six pylons")
    assert_true(room.get_node("Course/DriftMarkers").get_child_count() >= 10, "room needs drift markers")
    assert_true(room.get_node("Course/DistantReferenceShapes").get_child_count() >= 4, "room needs distant references")

    room.free()
```

Register it as the final suite:

```gdscript
"res://tests/integration/test_flight_room_scene.gd",
```

`tests/test_runner.gd` must now contain exactly seven suite paths.

- [ ] **Step 2: Verify red**

Run the test runner. Expected: failure because the room scene/controller do not exist.

- [ ] **Step 3: Implement room controller**

Create `src/flight_room/flight_room_controller.gd` with the approved exported paths. `_ready()` must:

1. resolve all paths;
2. store `spawn_transform = body.global_transform`;
3. connect `controller.reset_requested` to `reset_player`;
4. connect `reset_volume.body_entered` to `_on_reset_volume_body_entered`;
5. call `input_source.set_mouse_captured(true)`;
6. disable physics processing with one error if any path is invalid.

Use:

```gdscript
func _physics_process(_delta: float) -> void:
    if _body.global_position.length() > maxf(boundary_radius, 1.0):
        reset_player()

func _on_reset_volume_body_entered(other: Node) -> void:
    if other == _body:
        reset_player()

func reset_player() -> void:
    _body.freeze = true
    _body.global_transform = _spawn_transform
    _body.linear_velocity = Vector3.ZERO
    _body.angular_velocity = Vector3.ZERO
    _body.freeze = false
    _body.sleeping = false
```

- [ ] **Step 4: Build the flight room scene**

Create `scenes/flight_room/flight_room.tscn` with:

- `WorldEnvironment`: deep blue-black background, low ambient energy, glow disabled unless supported safely by Compatibility.
- `DirectionalLight3D` key: cool white, shadows enabled.
- `DirectionalLight3D` fill: lower energy, no shadows.
- Player at the origin, facing local `-Z`.
- Camera rig sibling with:
  - `target_path = NodePath("../PlayerInterceptor")`
  - `controller_path = NodePath("../PlayerInterceptor/ShipFlightController")`
- HUD with controller/input paths to the player children.
- Start gate centered around `z = -80`.
- At least five torus navigation rings at varied X/Y positions and Z distances between `-180` and `-900`.
- At least six solid pylons with `StaticBody3D`, `CollisionShape3D`, and emissive marker meshes.
- At least ten evenly spaced drift markers extending laterally from the course.
- At least four large dim reference shapes beyond the primary course.
- Reset volume as a wide `Area3D` floor below `y = -300`, not enclosing the spawn.
- `boundary_radius = 2500.0`.

All course geometry uses primitive meshes and `StandardMaterial3D`; keep light/material count modest.

- [ ] **Step 5: Implement exact bootstrap transition**

Replace `src/core/bootstrap.gd` with:

```gdscript
extends Node

func _ready() -> void:
    call_deferred("_enter_flight_room")

func _enter_flight_room() -> void:
    var error := get_tree().change_scene_to_file(
        "res://scenes/flight_room/flight_room.tscn"
    )
    if error != OK:
        push_error("Failed to enter flight room: %s" % error_string(error))
```

- [ ] **Step 6: Verify green**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected:

```text
PASS: 7 suites
```

The bootstrap boot phase must enter the flight room without script or scene errors.

- [ ] **Step 7: Commit**

```bash
git add src/flight_room/flight_room_controller.gd scenes/flight_room/flight_room.tscn tests/integration/test_flight_room_scene.gd src/core/bootstrap.gd tests/test_runner.gd
git commit -m "feat: build playable flight room"
```

---

### Task 7: Full Runtime Verification, Manual Flight Acceptance, and Documentation

**Files:**
- Modify: `README.md`
- Modify only if runtime evidence requires tuning: `resources/flight/player_flight_tuning.tres`
- Modify only if runtime evidence identifies a defect: the smallest responsible source/test pair

**Interfaces:**
- Consumes: complete playable build and Windows Godot CLI setup.
- Produces: verified milestone documentation and evidence-backed tuning only.

- [ ] **Step 1: Run the full automated gate from a clean local checkout**

```powershell
git switch agent/playable-flight-room
git pull
.\tools\verify\verify.ps1
```

Expected:

```text
PASS: 7 suites
```

No parse errors, scene errors, invalid path errors, or unhandled runtime errors may appear.

- [ ] **Step 2: Launch the playable room**

```powershell
godot --path .
```

Verify the bootstrap transitions into the flight room and the pointer captures automatically.

- [ ] **Step 3: Execute the manual acceptance matrix**

Perform each check separately:

```text
1. W/S: forward and reverse thrust are distinct and controllable.
2. A/D and Space/Ctrl: lateral and vertical movement work in local ship space.
3. Mouse: upward movement pitches nose upward; horizontal movement yaws predictably.
4. Q/E: roll works in both directions.
5. Shift: boost is visibly stronger and HUD percentage reaches 100%.
6. F: mode toggles ASSISTED ↔ MANUAL without changing transform or velocity.
7. ASSISTED: release lateral/vertical/rotation input; drift decays gradually.
8. MANUAL: release input; momentum persists.
9. Camera: ordinary turns do not snap; speed pullback/FOV response is restrained.
10. ESC: mouse releases and recaptures; HUD hint updates.
11. R: explicit reset returns to spawn and clears velocities.
12. Boundary/floor: leaving the room or falling below reset volume resets safely.
13. Course: rings, pylons, markers, and distant forms make speed and drift readable.
```

- [ ] **Step 4: Apply evidence-based tuning only if required**

If a criterion fails because of tuning rather than a code defect, modify only `resources/flight/player_flight_tuning.tres`, change one variable at a time, rerun the verifier, and repeat the single affected manual criterion. Do not embed tuned values in controller code.

If a criterion exposes a code defect, invoke `superpowers:systematic-debugging`, add the smallest failing automated reproduction, then fix the root cause.

- [ ] **Step 5: Update README**

Document:

```text
Current milestone: playable flight room
Engine: Godot 4.7.1 Standard
Renderer: GL Compatibility
Verify: .\tools\verify\verify.ps1
Run: godot --path .
Controls: W/S, A/D, Space/Ctrl, Mouse, Q/E, Shift, F, Escape, R
Expected automated result: PASS: 7 suites
Raw Blender assets remain outside runtime scenes.
```

- [ ] **Step 6: Re-run verification after documentation/tuning**

```powershell
.\tools\verify\verify.ps1
```

Expected: `PASS: 7 suites` and clean room boot.

- [ ] **Step 7: Commit**

```bash
git add README.md resources/flight/player_flight_tuning.tres tests src scenes project.godot
git commit -m "docs: verify playable flight milestone"
```

Use path-specific staging instead of the broad command above when no tuning or defect fixes occurred:

```bash
git add README.md
git commit -m "docs: verify playable flight milestone"
```

---

## Final Review Gate

Before opening or updating a pull request:

1. Run `git diff agent/godot-flight-foundation...HEAD --stat` and confirm changes are limited to the approved flight-room scope.
2. Run `git diff --check` and confirm no whitespace errors.
3. Run `.\tools\verify\verify.ps1` and capture the fresh `PASS: 7 suites` output.
4. Launch `godot --path .` and repeat the twelve manual acceptance checks.
5. Confirm no `.blend`, `.fbx`, `.obj`, `.stl`, downloaded package, add-on, or workflow file was introduced.
6. Keep the branch and PR draft until both automated and manual verification evidence are recorded.
