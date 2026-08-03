# Combat Kernel 1 Phase 3 — Practice Drone and Collision Damage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This project is inline-execution only; stop at every local Blender/Godot checkpoint and use the user's pasted output as the source of truth.

**Goal:** Add the stationary armored drone and route qualified physical impacts through the same damage state without altering rigid-body response.

**Architecture:** The drone owns only stationary lifecycle behavior. Collision qualification is split into a pure formula and a direct-body contact tracker with deterministic first-impact, separation, renewed-impact, and symmetric ramming rules.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, GL Compatibility, Blender 5.2 LTS, Python 3, PowerShell, custom `TestCase` harness.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Base: design/spec commit `1d63819e02c194d762ee08f45c038ac10389fdb0` or a descendant.
- Godot 4.7.1 Standard with GL Compatibility.
- Blender 5.2 LTS and Python 3 for canonical asset generation.
- Windows PowerShell is the authoritative local verification environment.
- Inline execution only; do not dispatch subagents.
- Preserve accepted six-axis flight, boost, thermal, Camera C0, canonical fighter identity, twelve thrusters, asteroid field, collision response, reset, and existing HUD.
- No camera-forward fire, convergence, lead, lock, snapping, or aim assistance.
- Never guess or hand-author muzzle transforms.
- Never mutate the preserved Blender source.
- Never publish a partial GLB/manifest/matrix set.
- No GitHub Actions.
- No success claim without fresh user-pasted local output.
- Full verification command: `.\tools\verify\verify.ps1`.

---
### Task 6: Add the stationary armored practice drone

**Files:**
- Create: `src/combat/practice_drone_controller.gd`
- Create: `scenes/combat/practice_drone.tscn`
- Create: `tests/integration/test_practice_drone_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `PracticeDroneController.reset_full()`.
- `PracticeDroneController.get_damage_state() -> DamageState`.
- `PracticeDroneController.is_disabled() -> bool`.
- Drone self-restores after `3.0` seconds.

- [ ] **Step 1: Write the failing scene test**

The test must prove:

- root is `StaticBody3D`;
- collision exists;
- child `DamageState` uses drone tuning;
- shield is `150`, hull is `200`;
- no AI, navigation, flight controller, or weapon node exists;
- destruction disables collision and damage intake;
- simple destruction flash is shown;
- restore occurs after `3.0` seconds at the exact spawn transform;
- restoration returns full shield and hull;
- destroying drone does not alter player state.

- [ ] **Step 2: Create the drone scene**

Use only Godot-ready primitive meshes for this milestone:

- central armored sphere/capsule;
- two side plates;
- small emissive center;
- one convex collision shape;
- no fighter model.

Root properties:

```text
StaticBody3D
collision_layer = 1
collision_mask = 1
```

Children for this task:

```text
VisualRoot
CollisionShape3D
DamageState
DestructionFlash
```

Task 8 adds reusable shield/hull visual controllers, and Task 11 wires those controllers into the arena. The drone lifecycle in this task depends only on `DamageState`, collision, `VisualRoot`, and `DestructionFlash`.

- [ ] **Step 3: Implement lifecycle**

On `DamageState.destroyed`:

- set `_disabled = true`;
- set collision layer and mask to `0`;
- disable further damage application through `DamageState`;
- hide `VisualRoot`;
- show a one-shot simple flash;
- count down `3.0` seconds;
- restore transform, visual, collision, full damage state, and enabled state.

`reset_full()` performs the same restoration immediately and clears countdowns.

- [ ] **Step 4: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 5: Commit**

```powershell
git add `
  src/combat/practice_drone_controller.gd `
  scenes/combat/practice_drone.tscn `
  tests/integration/test_practice_drone_scene.gd `
  tests/test_runner.gd
git commit -m "feat: add armored practice drone"
```

---

### Task 7: Add collision damage without changing rigid-body response

**Files:**
- Create: `src/combat/collision_damage_tuning.gd`
- Create: `src/combat/collision_damage_model.gd`
- Create: `src/combat/collision_contact_tracker.gd`
- Create: `config/combat/collision_damage_tuning.tres`
- Create: `src/player/player_interceptor_body.gd`
- Create: `tests/unit/test_collision_damage_model.gd`
- Create: `tests/unit/test_collision_contact_tracker.gd`
- Create: `tests/integration/test_collision_damage_integration.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `CollisionDamageModel.compute(relative_normal_speed, effective_mass, tuning) -> float`.
- `CollisionDamageModel.effective_mass(player_mass, collider) -> float`.
- `CollisionContactTracker.process_contacts(state: PhysicsDirectBodyState3D)`.
- `CollisionContactTracker.clear_contacts()`.
- Signal: `collision_damage_resolved(result, collider)`.

- [ ] **Step 1: Write pure model tests**

Exact expected values from the approved formula:

```gdscript
assert_equal(model.compute(9.99, 8500.0, tuning), 0.0, "below threshold")
assert_true(
    is_equal_approx(model.compute(30.0, 8500.0, tuning), 100.0),
    "30 m/s reaches clamp"
)
assert_true(
    model.compute(20.0, 4250.0, tuning)
    < model.compute(20.0, 8500.0, tuning),
    "mass scales damage"
)
assert_equal(model.compute(100.0, 20.0, tuning), 0.0, "tiny body ignored")
```

Also prove the `damaging_collision` override bypasses the tiny-body filter.

- [ ] **Step 2: Implement tuning and pure model**

`CollisionDamageTuning` fields:

```gdscript
@export var minimum_relative_normal_speed := 10.0
@export var reference_speed_above_threshold := 20.0
@export var reference_mass := 8500.0
@export var maximum_damage := 100.0
@export var minimum_dynamic_mass := 25.0
@export var renewed_impact_speed_delta := 10.0
```

Model:

```gdscript
var excess_speed := maxf(relative_normal_speed - tuning.minimum_relative_normal_speed, 0.0)
if excess_speed <= 0.0:
    return 0.0
var mass_factor := clampf(effective_mass / tuning.reference_mass, 0.0, 1.0)
var raw := tuning.maximum_damage * mass_factor * pow(
    excess_speed / tuning.reference_speed_above_threshold,
    2.0
)
return clampf(raw, 1.0, tuning.maximum_damage)
```

- [ ] **Step 3: Write contact-rearming tests**

Use a test seam on `CollisionContactTracker`:

```gdscript
func process_sample(
    contact_key: StringName,
    normal_speed: float,
    damage_amount: float,
    collider: Node,
    impact_point: Vector3,
    impact_normal: Vector3
) -> bool
```

The unit test must prove:

- first qualified sample returns `true`;
- same-speed sustained sample returns `false`;
- a `+9.99 m/s` increase returns `false`;
- a `+10.0 m/s` increase returns `true`;
- `mark_separated(key)` rearms;
- `clear_contacts()` rearms everything.

Production `process_contacts` must convert actual direct-body contacts into this same seam.

- [ ] **Step 4: Implement direct-body-state contact processing**

Attach `PlayerInterceptorBody` to the player root and delegate `_integrate_forces`:

```gdscript
class_name PlayerInterceptorBody
extends RigidBody3D

@export var collision_contact_tracker_path: NodePath
var _tracker: CollisionContactTracker

func _ready() -> void:
    _tracker = get_node_or_null(collision_contact_tracker_path) as CollisionContactTracker

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    if _tracker != null:
        _tracker.process_contacts(state)
```

Set on the player body:

```text
contact_monitor = true
max_contacts_reported = 16
```

For every direct contact, calculate:

- world contact point;
- world contact normal;
- player velocity at contact;
- collider velocity at contact;
- closing normal speed only;
- effective mass;
- stable key from collider RID plus local/collider shape indices.

After processing the current frame, mark keys absent from the contact set as separated.

- [ ] **Step 5: Route damage and symmetric ramming**

The tracker owns exported paths to player `DamageState` and tuning. On a qualified event:

- apply one collision packet to player;
- if collider is the practice drone root or contains a direct `DamageState`, apply the same amount to it;
- do not damage asteroids or pylons;
- emit result for visual placement;
- never modify linear velocity, angular velocity, impulse, body transform, or contact solver data.

- [ ] **Step 6: Write integration tests**

Build controlled collisions and prove:

- player shield decreases before hull;
- once shield is zero, later impact reaches hull;
- scraping does not repeat damage;
- separation and re-impact does;
- renewed strong impact while touching rearms;
- player and drone both take ramming damage;
- asteroid collision damages player but not asteroid;
- player bounce/velocity response still occurs with and without shield.

- [ ] **Step 7: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 8: Commit**

```powershell
git add `
  src/combat/collision_damage_tuning.gd `
  src/combat/collision_damage_model.gd `
  src/combat/collision_contact_tracker.gd `
  config/combat/collision_damage_tuning.tres `
  src/player/player_interceptor_body.gd `
  tests/unit/test_collision_damage_model.gd `
  tests/unit/test_collision_contact_tracker.gd `
  tests/integration/test_collision_damage_integration.gd `
  tests/test_runner.gd
git commit -m "feat: route physical impacts through damage state"
```

---
