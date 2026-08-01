# Playable Flight Room Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first playable third-person Shattered Orbit flight room with tested six-axis physics, keyboard/mouse controls, assisted/manual modes, a smooth chase camera, telemetry HUD, and a readable spatial course.

**Architecture:** Keep the verified `FlightModel` as the only source of force and torque equations. Add pure input, mode-state, and camera helpers around it; connect them through focused runtime nodes for input sampling, physics application, camera presentation, HUD display, and room reset/composition. Raw Blender assets remain quarantined and the player uses a lightweight procedural interceptor.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, GL Compatibility renderer, dependency-free headless tests, PowerShell/Bash verification.

## Global Constraints

- Engine is exactly Godot 4.7.1 Standard.
- Renderer remains `gl_compatibility`.
- Local `-Z` is ship forward.
- Player mass is `8500.0`; gravity scale, built-in linear damping, and built-in angular damping are `0.0`; continuous collision detection is enabled.
- `FlightModel.compute()` remains the only flight-force and torque implementation.
- Flight-mode changes never modify transform or velocities.
- Only an explicit room reset may clear momentum.
- No external add-ons, downloads, workflows, gamepad support, combat, missions, Blender integration, or final VFX.
- Five new suites plus the two existing suites must finish with `PASS: 7 suites`.
- Every production behavior requires a failing test first.

## File Map

**Modify:**
- `project.godot`
- `src/core/bootstrap.gd`
- `tests/test_runner.gd`
- `README.md`

**Create pure logic:**
- `src/input/player_input_math.gd`
- `src/player/ship_flight_state.gd`
- `src/camera/chase_camera_math.gd`

**Create runtime nodes:**
- `src/input/player_input_source.gd`
- `src/player/ship_flight_controller.gd`
- `src/camera/chase_camera_rig.gd`
- `src/ui/flight_hud.gd`
- `src/flight_room/flight_room_controller.gd`

**Create scenes/resources:**
- `scenes/player/player_interceptor.tscn`
- `scenes/camera/chase_camera_rig.tscn`
- `scenes/ui/flight_hud.tscn`
- `scenes/flight_room/flight_room.tscn`
- `resources/flight/player_flight_tuning.tres`

**Create tests:**
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
- Produces `PlayerInputMath.compose_translation(...) -> Vector3`
- Produces `PlayerInputMath.compose_rotation(...) -> Vector3`
- Produces `PlayerInputMath.clamp_boost(value) -> float`

- [ ] **Step 1: Write and register the failing suite**

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
    assert_true(is_equal_approx(diagonal.length(), 1.0), "translation must normalize")
    assert_true(diagonal.z < 0.0, "forward must use local negative Z")

    assert_equal(
        PlayerInputMath.compose_rotation(
            Vector2(400.0, -300.0), 0.0, 0.0, 0.01, 1.0
        ),
        Vector3(1.0, -1.0, 0.0),
        "mouse command must invert screen motion and clamp"
    )

    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(-2.0), 0.0), "boost lower clamp")
    assert_true(is_equal_approx(PlayerInputMath.clamp_boost(2.0), 1.0), "boost upper clamp")
```

Register `res://tests/unit/test_player_input_math.gd` after the existing flight-model suite.

- [ ] **Step 2: Verify RED**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: non-zero exit because `PlayerInputMath` is missing.

- [ ] **Step 3: Implement the minimal helper**

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

- [ ] **Step 4: Add physical keyboard events in `project.godot`**

Bind actions to these physical keycodes:

```text
thrust_forward: W = 87
thrust_reverse: S = 83
strafe_left: A = 65
strafe_right: D = 68
strafe_up: Space = 32
strafe_down: Ctrl = 4194326
roll_left: Q = 81
roll_right: E = 69
boost: Shift = 4194325
toggle_flight_mode: F = 70
toggle_mouse_capture: Escape = 4194305
reset_flight_room: R = 82
```

Keep `fire_primary` and `fire_secondary` configured but unused.

- [ ] **Step 5: Verify GREEN**

```powershell
.\tools\verify\verify.ps1
```

Expected: `PASS: 3 suites`.

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
- Produces `ShipFlightState.toggled_mode(mode) -> FlightMode.Value`
- Produces `ShipFlightState.speed_mps(world_velocity) -> float`

- [ ] **Step 1: Write and register the failing suite**

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.ASSISTED),
        FlightMode.Value.MANUAL,
        "assisted must toggle to manual"
    )
    assert_equal(
        ShipFlightState.toggled_mode(FlightMode.Value.MANUAL),
        FlightMode.Value.ASSISTED,
        "manual must toggle to assisted"
    )
    assert_true(
        is_equal_approx(ShipFlightState.speed_mps(Vector3(3.0, 4.0, 12.0)), 13.0),
        "speed must use vector magnitude"
    )
```

- [ ] **Step 2: Verify RED**

Run the headless test runner. Expected: `ShipFlightState` missing.

- [ ] **Step 3: Implement**

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

- [ ] **Step 4: Verify GREEN**

Expected: `PASS: 4 suites`.

- [ ] **Step 5: Commit**

```bash
git add src/player/ship_flight_state.gd tests/unit/test_ship_flight_state.gd tests/test_runner.gd
git commit -m "feat: add pure flight mode state"
```

---

### Task 3: Input Source, Physics Controller, and Interceptor Scene

**Files:**
- Create: `src/input/player_input_source.gd`
- Create: `src/player/ship_flight_controller.gd`
- Create: `resources/flight/player_flight_tuning.tres`
- Create: `scenes/player/player_interceptor.tscn`
- Create: `tests/integration/test_player_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes `PlayerInputMath`, `ShipFlightState`, and `FlightModel.compute()`.
- Produces the approved `PlayerInputSource` and `ShipFlightController` APIs.

- [ ] **Step 1: Write and register the failing player-scene suite**

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

    assert_true(is_equal_approx(player.mass, 8500.0), "mass must be 8500 kg")
    assert_true(is_equal_approx(player.gravity_scale, 0.0), "gravity must be disabled")
    assert_true(is_equal_approx(player.linear_damp, 0.0), "linear damping must be zero")
    assert_true(is_equal_approx(player.angular_damp, 0.0), "angular damping must be zero")
    assert_true(player.continuous_cd, "continuous collision detection must be enabled")
    assert_true(player.get_node_or_null("CollisionShape3D") is CollisionShape3D, "collision required")
    assert_true(player.get_node_or_null("PlayerInputSource") is PlayerInputSource, "input source required")
    assert_true(player.get_node_or_null("ShipFlightController") is ShipFlightController, "controller required")

    var visuals := player.get_node("Visuals")
    for child_name: String in [
        "Fuselage", "Nose", "LeftWing", "RightWing",
        "LeftEngine", "RightEngine", "LeftEngineGlow", "RightEngineGlow"
    ]:
        assert_true(visuals.get_node_or_null(child_name) is MeshInstance3D, "missing %s" % child_name)

    var controller := player.get_node("ShipFlightController") as ShipFlightController
    assert_equal(controller.get_flight_mode(), FlightMode.Value.ASSISTED, "default mode")
    assert_true(is_equal_approx(controller.get_boost_amount(), 0.0), "default boost")
    player.free()
```

- [ ] **Step 2: Verify RED**

Expected: player scene/classes missing.

- [ ] **Step 3: Implement `PlayerInputSource`**

Use this exact behavior:

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

Use exported `body_path`, `input_source_path`, and `tuning`. Resolve once in `_ready()`; one invalid path emits one `push_error()` and disables physics processing.

```gdscript
func _physics_process(_delta: float) -> void:
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
    var local_linear := basis.inverse() * _body.linear_velocity
    var local_angular := basis.inverse() * _body.angular_velocity
    var output := FlightModel.compute(command, tuning, local_linear, local_angular)
    _body.apply_central_force(basis * output.force_local)
    _body.apply_torque(basis * output.torque_local)
    _local_velocity = local_linear
```

Implement getters exactly:

```gdscript
func get_flight_mode() -> FlightMode.Value:
    return _flight_mode

func get_speed_mps() -> float:
    return ShipFlightState.speed_mps(_body.linear_velocity) if _body != null else 0.0

func get_boost_amount() -> float:
    return _boost_amount

func get_local_velocity() -> Vector3:
    return _local_velocity

func get_world_velocity() -> Vector3:
    return _body.linear_velocity if _body != null else Vector3.ZERO

func get_body() -> RigidBody3D:
    return _body
```

- [ ] **Step 5: Create tuning resource and player scene**

`player_flight_tuning.tres` uses the verified defaults: `120000`, `50000`, `65000`, `45000`, `1.8`, `2.5`, `3.5`.

`player_interceptor.tscn`:

```text
PlayerInterceptor (RigidBody3D)
├── CollisionShape3D (BoxShape3D about 8 x 2.5 x 12)
├── Visuals
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

Use primitive meshes, dark hull/light panel/cyan emission materials, `body_path = ".."`, `input_source_path = "../PlayerInputSource"`, and the tuning resource.

- [ ] **Step 6: Verify GREEN**

Expected: `PASS: 5 suites`.

- [ ] **Step 7: Commit**

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

- [ ] **Step 1: Write and register the failing camera suite**

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(is_equal_approx(ChaseCameraMath.exponential_weight(0.0, 1.0), 0.0), "zero sharpness")
    assert_true(ChaseCameraMath.exponential_weight(5.0, 0.5) > 0.0, "positive interpolation")

    var position := ChaseCameraMath.desired_position(
        Transform3D.IDENTITY,
        Vector3(0.0, 0.0, -100.0),
        Vector3(0.0, 4.0, 16.0),
        0.08,
        0.025,
        10.0
    )
    assert_true(position.y > 0.0, "camera above ship")
    assert_true(position.z > 16.0, "camera pulls backward with speed")
    assert_true(
        is_equal_approx(ChaseCameraMath.desired_fov(1000.0, 1.0, 68.0, 0.03, 6.0, 82.0), 82.0),
        "FOV max clamp"
    )
```

- [ ] **Step 2: Verify RED**

Expected: `ChaseCameraMath` missing.

- [ ] **Step 3: Implement camera math**

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
    var pullback := minf(
        world_velocity.length() * maxf(speed_pullback, 0.0),
        maxf(max_pullback, 0.0)
    )
    return (
        target_transform.origin
        + target_transform.basis.orthonormalized() * (base_offset + Vector3(0.0, 0.0, pullback))
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
    return clampf(
        base_fov
        + maxf(speed_mps, 0.0) * maxf(speed_fov_gain, 0.0)
        + clampf(boost_amount, 0.0, 1.0) * maxf(boost_fov_gain, 0.0),
        base_fov,
        maxf(max_fov, base_fov)
    )
```

- [ ] **Step 4: Implement rig and scene**

Resolve `target_path`, `controller_path`, and `camera_path` once. Initialize directly at desired position. Process with exponential interpolation, velocity look-ahead, partial roll up-vector blending, quaternion slerp, and smoothed clamped FOV. Invalid paths emit one error and disable processing.

Scene:

```text
ChaseCameraRig (Node3D)
└── Camera3D (current, near 0.1, far 10000, FOV 68)
```

- [ ] **Step 5: Verify GREEN**

Expected: `PASS: 6 suites`.

- [ ] **Step 6: Commit**

```bash
git add src/camera/chase_camera_math.gd src/camera/chase_camera_rig.gd scenes/camera/chase_camera_rig.tscn tests/unit/test_chase_camera_math.gd tests/test_runner.gd
git commit -m "feat: add smooth chase camera"
```

---

### Task 5: Read-Only Flight Telemetry HUD

**Files:**
- Create: `src/ui/flight_hud.gd`
- Create: `scenes/ui/flight_hud.tscn`
- Modify: `tests/integration/test_player_scene.gd`

- [ ] **Step 1: Add a failing HUD scene contract to the existing player suite**

Append before `player.free()`:

```gdscript
var hud_packed := load("res://scenes/ui/flight_hud.tscn") as PackedScene
assert_true(hud_packed != null, "HUD scene must load")
if hud_packed != null:
    var hud := hud_packed.instantiate() as FlightHud
    assert_true(hud != null, "HUD root must use FlightHud")
    if hud != null:
        for label_path: String in [
            "SafeArea/Layout/SpeedLabel",
            "SafeArea/Layout/ModeLabel",
            "SafeArea/Layout/BoostLabel",
            "SafeArea/Layout/CaptureLabel",
            "SafeArea/Layout/ControlsLabel"
        ]:
            assert_true(hud.get_node_or_null(label_path) is Label, "missing HUD label: %s" % label_path)
        hud.free()
```

- [ ] **Step 2: Verify RED**

Expected: HUD scene/class missing while the other five suites remain green.

- [ ] **Step 3: Implement HUD script**

Resolve the controller, input source, and five labels once. Invalid paths emit one error and disable processing. `_process()` uses:

```gdscript
_speed_label.text = "SPEED  %04d m/s" % roundi(_controller.get_speed_mps())
_mode_label.text = (
    "MODE   ASSISTED"
    if _controller.get_flight_mode() == FlightMode.Value.ASSISTED
    else "MODE   MANUAL"
)
_boost_label.text = "BOOST  %03d%%" % roundi(_controller.get_boost_amount() * 100.0)
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

- [ ] **Step 4: Create HUD scene**

Use the exact approved hierarchy, built-in fonts, a semi-transparent dark panel, 16 px margins, and white/cyan high-contrast text. Configure all exported label paths.

- [ ] **Step 5: Verify GREEN**

Run the full verifier. Expected: `PASS: 6 suites`; the player suite now also validates HUD composition.

- [ ] **Step 6: Commit**

```bash
git add src/ui/flight_hud.gd scenes/ui/flight_hud.tscn tests/integration/test_player_scene.gd
git commit -m "feat: add flight telemetry hud"
```

---

### Task 6: Spatial Flight Room, Reset Orchestration, and Bootstrap

**Files:**
- Create: `src/flight_room/flight_room_controller.gd`
- Create: `scenes/flight_room/flight_room.tscn`
- Create: `tests/integration/test_flight_room_scene.gd`
- Modify: `src/core/bootstrap.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write and register the failing room suite**

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var packed := load("res://scenes/flight_room/flight_room.tscn") as PackedScene
    assert_true(packed != null, "flight room must load")
    if packed == null:
        return

    var room := packed.instantiate() as Node3D
    assert_true(room != null, "flight room root must be Node3D")
    if room == null:
        return

    assert_true(room.get_node_or_null("PlayerInterceptor") is RigidBody3D, "player required")
    assert_true(room.get_node_or_null("ChaseCameraRig") is ChaseCameraRig, "camera required")
    assert_true(room.get_node_or_null("FlightHud") is FlightHud, "HUD required")
    assert_true(room.get_node_or_null("ResetVolume") is Area3D, "reset volume required")
    assert_true(room.get_node_or_null("FlightRoomController") is FlightRoomController, "room controller required")
    assert_true(room.get_node_or_null("Course/StartGate") is Node3D, "start gate required")
    assert_true(room.get_node("Course/NavigationRings").get_child_count() >= 5, "five rings required")
    assert_true(room.get_node("Course/Pylons").get_child_count() >= 6, "six pylons required")
    assert_true(room.get_node("Course/DriftMarkers").get_child_count() >= 10, "ten markers required")
    assert_true(room.get_node("Course/DistantReferenceShapes").get_child_count() >= 4, "four references required")
    room.free()
```

Register it as the seventh and final suite.

- [ ] **Step 2: Verify RED**

Expected: room scene/controller missing.

- [ ] **Step 3: Implement room controller**

Resolve body/controller/input/reset volume, store spawn transform, connect `reset_requested` and `body_entered`, capture mouse, and disable on invalid paths.

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

- [ ] **Step 4: Build the room scene**

Include:

```text
FlightRoom
├── WorldEnvironment
├── KeyLight
├── FillLight
├── PlayerInterceptor
├── ChaseCameraRig
├── FlightHud
├── Course
│   ├── StartGate at z ≈ -80
│   ├── NavigationRings: at least 5, z -180 to -900, varied x/y
│   ├── Pylons: at least 6 StaticBody3D obstacles
│   ├── DriftMarkers: at least 10 evenly spaced emissive markers
│   └── DistantReferenceShapes: at least 4 large dim forms
├── ResetVolume: wide floor below y = -300
└── FlightRoomController: boundary_radius = 2500
```

Use primitive meshes, `StandardMaterial3D`, a deep blue-black environment, one cool key light, one restrained fill light, and modest material/light counts.

- [ ] **Step 5: Implement bootstrap transition**

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

- [ ] **Step 6: Verify GREEN**

```powershell
.\tools\verify\verify.ps1
```

Expected: `PASS: 7 suites` and clean flight-room boot.

- [ ] **Step 7: Commit**

```bash
git add src/flight_room/flight_room_controller.gd scenes/flight_room/flight_room.tscn tests/integration/test_flight_room_scene.gd src/core/bootstrap.gd tests/test_runner.gd
git commit -m "feat: build playable flight room"
```

---

### Task 7: Runtime Acceptance and Documentation

**Files:**
- Modify: `README.md`
- Modify only with evidence: `resources/flight/player_flight_tuning.tres` and the smallest failing source/test pair.

- [ ] **Step 1: Run the automated gate**

```powershell
git switch agent/playable-flight-room
git pull
.\tools\verify\verify.ps1
```

Expected: `PASS: 7 suites`, no parse/scene/path/runtime errors.

- [ ] **Step 2: Launch**

```powershell
godot --path .
```

- [ ] **Step 3: Execute manual acceptance**

```text
1. W/S forward and reverse are distinct.
2. A/D and Space/Ctrl move in local ship space.
3. Mouse up pitches nose up; horizontal motion yaws predictably.
4. Q/E roll both directions.
5. Shift boost is obvious and HUD reaches 100%.
6. F toggles mode without changing transform or velocities.
7. Assisted mode gradually decays lateral, vertical, and angular drift.
8. Manual mode preserves momentum.
9. Camera turns smoothly with restrained pullback/FOV response.
10. Escape releases/recaptures mouse and updates HUD.
11. R resets to spawn and clears velocities.
12. Boundary/reset floor safely return the ship.
13. Course geometry makes speed, scale, and drift readable.
```

- [ ] **Step 4: Apply evidence-based corrections only**

For tuning, change one `.tres` value at a time, rerun automated verification, then repeat the affected manual check. For a code defect, invoke `superpowers:systematic-debugging`, add a failing automated reproduction, fix the root cause, and rerun all seven suites.

- [ ] **Step 5: Update README**

Document the milestone, exact engine/renderer, `godot --path .`, `.\tools\verify\verify.ps1`, all controls, expected `PASS: 7 suites`, and the raw/runtime asset boundary.

- [ ] **Step 6: Fresh final verification**

Run the verifier and manual checks again after all edits.

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs: verify playable flight milestone"
```

Add tuning or defect files explicitly only when they changed.

---

## Final Review Gate

1. `git diff agent/godot-flight-foundation...HEAD --stat` contains only approved flight-room scope.
2. `git diff --check` reports no whitespace errors.
3. Fresh `.\tools\verify\verify.ps1` prints `PASS: 7 suites`.
4. Fresh `godot --path .` passes all thirteen manual checks.
5. No raw model, downloaded package, add-on, or workflow file was added.
6. Keep the branch and PR draft until automated and manual evidence are recorded.
