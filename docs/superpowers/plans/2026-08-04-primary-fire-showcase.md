# Primary Fire Showcase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a directly launchable Godot debug scene that visibly demonstrates the production primary-fire cadence, verified fighter muzzles, projectile pool, swept collision, and cleanup behavior.

**Architecture:** An isolated `PrimaryFireShowcaseController` wires the existing production player, fire controller, projectile pool, chase camera, firing lane, and telemetry overlay. Production combat classes remain unchanged; the showcase adds only composition, reset/exit handling, and observation counters.

**Tech Stack:** Godot 4.7.1 Standard, GL Compatibility, typed GDScript, `.tscn` scenes, existing custom synchronous test runner.

## Global Constraints

- Branch: `agent/playable-flight-room`.
- No GitHub Actions.
- Windows PowerShell with Godot 4.7.1 is authoritative.
- Do not modify projectile damage, speed, lifetime, pool size, cadence, muzzle paths, or source exclusion.
- Do not modify the main flight-room scene.
- Use the production player, chase camera, fire controller, projectile pool, and projectile scene.
- The scene is development-only and launches explicitly from `res://scenes/debug/primary_fire_showcase.tscn`.
- Tests must leave no orphan Nodes or retained resources.

---

### Task 1: Lock the showcase scene contract

**Files:**
- Create: `tests/integration/test_primary_fire_showcase.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `PrimaryFireController.step_for_test(held: bool, delta: float)`, `PulseProjectilePool.get_active_count()`, and the canonical player scene hierarchy.
- Produces: an integration contract for `PrimaryFireShowcaseController.initialize()`, `reset_showcase()`, `get_shot_count()`, `get_resolved_count()`, and `get_last_side_name()`.

- [ ] **Step 1: Write the failing integration test**

The test must load `res://scenes/debug/primary_fire_showcase.tscn`, instantiate it, attach it to the active `SceneTree`, and assert:

```gdscript
var showcase := packed.instantiate() as PrimaryFireShowcaseController
assert_true(showcase != null, "showcase root must use PrimaryFireShowcaseController")
assert_true(showcase.get_node_or_null("PlayerInterceptor") is RigidBody3D, "production player required")
assert_true(showcase.get_node_or_null("ChaseCameraRig") is ChaseCameraRig, "production chase camera required")
assert_true(showcase.get_node_or_null("PulseProjectilePool") is PulseProjectilePool, "production pool required")
assert_true(showcase.get_node_or_null("PlayerInterceptor/PrimaryFireController") is PrimaryFireController, "production fire controller required")
assert_true(showcase.get_node_or_null("FiringLane/ImpactWall") is StaticBody3D, "impact wall required")
assert_true(showcase.get_node("FiringLane/DepthRings").get_child_count() >= 4, "depth markers required")
assert_true(showcase.get_node_or_null("ShowcaseHud/SafeArea/Instructions") is Label, "instructions required")
assert_true(showcase.get_node_or_null("ShowcaseHud/SafeArea/Telemetry") is Label, "telemetry required")
```

After `showcase.initialize()`:

```gdscript
var fire := showcase.get_node("PlayerInterceptor/PrimaryFireController") as PrimaryFireController
var pool := showcase.get_node("PulseProjectilePool") as PulseProjectilePool
fire.step_for_test(true, 0.0)
assert_equal(pool.get_active_count(), 1, "first held step must visibly spawn one projectile")
assert_equal(showcase.get_shot_count(), 1, "showcase must count emitted shots")
assert_equal(showcase.get_last_side_name(), "LEFT", "first visible shot must use left muzzle")
showcase.reset_showcase()
assert_equal(pool.get_active_count(), 0, "reset must clear projectiles")
assert_equal(showcase.get_shot_count(), 0, "reset must clear shot counter")
```

Free the scene before returning.

- [ ] **Step 2: Register the suite**

Add:

```gdscript
"res://tests/integration/test_primary_fire_showcase.gd",
```

to `TEST_SCRIPTS` in `tests/test_runner.gd` immediately after `test_pulse_projectile.gd`.

- [ ] **Step 3: Run and verify the red state**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: the new suite fails because the showcase class and scene do not yet exist.

- [ ] **Step 4: Commit the red contract**

```powershell
git add tests/integration/test_primary_fire_showcase.gd tests/test_runner.gd
git commit -m "test: require visible primary fire showcase"
```

---

### Task 2: Implement showcase wiring and telemetry

**Files:**
- Create: `src/debug/primary_fire_showcase_controller.gd`

**Interfaces:**
- Consumes: `PrimaryFireController.set_projectile_pool(pool)`, `PrimaryFireController.reset_runtime_state()`, `PulseProjectilePool.clear_all()`, `PlayerInputSource.consume_reset_request()`.
- Produces:

```gdscript
class_name PrimaryFireShowcaseController
extends Node3D

func initialize() -> void
func reset_showcase() -> void
func get_shot_count() -> int
func get_resolved_count() -> int
func get_last_side_name() -> String
```

- [ ] **Step 1: Implement idempotent initialization**

Resolve exported NodePaths for the player body, input source, fire controller, pool, instructions label, and telemetry label. On success:

```gdscript
_body.freeze = true
_body.linear_velocity = Vector3.ZERO
_body.angular_velocity = Vector3.ZERO
_input_source.set_mouse_captured(false)
_fire_controller.set_projectile_pool(_pool)
_fire_controller.set_firing_enabled(true)
```

Connect `shot_fired` and `projectile_resolved` exactly once.

- [ ] **Step 2: Implement telemetry**

Track:

```gdscript
var _shot_count := 0
var _resolved_count := 0
var _last_side_name := "NONE"
```

On `shot_fired`, increment shots and map `PrimaryFireCadence.MuzzleSide.LEFT` to `LEFT`, otherwise `RIGHT`. On `projectile_resolved`, increment resolved count. Update the telemetry label with total shots, active pool count, resolved impacts, and last side.

- [ ] **Step 3: Implement reset and exit behavior**

`reset_showcase()` must:

```gdscript
_pool.clear_all()
_fire_controller.reset_runtime_state()
_shot_count = 0
_resolved_count = 0
_last_side_name = "NONE"
```

In `_process`, consume `R` through `PlayerInputSource.consume_reset_request()`. In `_unhandled_input`, exit on `ui_cancel`.

- [ ] **Step 4: Commit the controller**

```powershell
git add src/debug/primary_fire_showcase_controller.gd
git commit -m "feat: add primary fire showcase controller"
```

---

### Task 3: Build the launchable showcase scene

**Files:**
- Create: `scenes/debug/primary_fire_showcase.tscn`

**Interfaces:**
- Consumes: the production scenes and the controller from Task 2.
- Produces: `res://scenes/debug/primary_fire_showcase.tscn`.

- [ ] **Step 1: Compose production combat nodes**

The root is `PrimaryFireShowcaseController`. Instance:

```text
PlayerInterceptor                       res://scenes/player/player_interceptor.tscn
ChaseCameraRig                          res://scenes/camera/chase_camera_rig.tscn
PulseProjectilePool                    PulseProjectilePool
PlayerInterceptor/PrimaryFireController PrimaryFireController
```

Set exact fire-controller paths:

```gdscript
body_path = NodePath("..")
input_source_path = NodePath("../PlayerInputSource")
model_path = NodePath("../VisualRoot/SmallSciFiFighter")
```

- [ ] **Step 2: Build the visible firing lane**

Create a dark `WorldEnvironment`, two restrained directional lights, at least four emissive torus depth rings between `z = -45` and `z = -180`, and a large `StaticBody3D` impact wall centered near `z = -240`. The wall must have both a visible mesh and `CollisionShape3D`, remain non-damageable, and use collision layer 1.

- [ ] **Step 3: Add the showcase overlay**

Create `ShowcaseHud` as `CanvasLayer`, with `SafeArea` and two labels:

```text
PRIMARY FIRE SHOWCASE
Hold LMB or physical V to fire
R clears the firing lane   Esc exits
```

The telemetry label is populated by the controller. Set all UI mouse filters to ignore so LMB always reaches `fire_primary`.

- [ ] **Step 4: Wire exported paths**

Set root paths to:

```gdscript
player_body_path = NodePath("PlayerInterceptor")
input_source_path = NodePath("PlayerInterceptor/PlayerInputSource")
fire_controller_path = NodePath("PlayerInterceptor/PrimaryFireController")
projectile_pool_path = NodePath("PulseProjectilePool")
instructions_label_path = NodePath("ShowcaseHud/SafeArea/Instructions")
telemetry_label_path = NodePath("ShowcaseHud/SafeArea/Telemetry")
```

- [ ] **Step 5: Commit the scene**

```powershell
git add scenes/debug/primary_fire_showcase.tscn
git commit -m "feat: add launchable primary fire showcase"
```

---

### Task 4: Document and verify the showcase

**Files:**
- Modify: `README.md`

**Interfaces:**
- Produces: a copy-paste launch command and expected controls.

- [ ] **Step 1: Add the launch section**

Document:

```powershell
godot --path . res://scenes/debug/primary_fire_showcase.tscn
```

Controls:

```text
LMB / physical V  hold primary fire
R                 clear projectiles and reset cadence/counters
Escape            exit showcase
```

- [ ] **Step 2: Import and run the complete suite**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected:

```text
PASS: 27 suites
```

with no parser errors, assertion failures, ObjectDB leaks, or retained-resource warnings.

- [ ] **Step 3: Manually launch the showcase**

Run:

```powershell
godot --path . res://scenes/debug/primary_fire_showcase.tscn
```

Confirm the fighter is stationary, holding LMB or physical `V` produces alternating left/right pulse streams, projectiles disappear at the wall, telemetry updates, `R` clears the lane and restores left-first cadence, and `Escape` exits.

- [ ] **Step 4: Commit documentation**

```powershell
git add README.md
git commit -m "docs: add primary fire showcase launch"
```
