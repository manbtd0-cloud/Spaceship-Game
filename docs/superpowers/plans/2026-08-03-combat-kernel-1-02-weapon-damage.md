# Combat Kernel 1 Phase 2 — Primary Weapon and Damage Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This project is inline-execution only; stop at every local Blender/Godot checkpoint and use the user's pasted output as the source of truth.

**Goal:** Add one logical fire input, exact alternating cadence, reusable shield/hull state, and swept pooled pulse projectiles.

**Architecture:** Keep input sampling, cadence, projectile sweep, pooling, and damage arithmetic isolated. Projectiles create typed `DamagePacket` values and consume typed `DamageResult` values; flight and camera code remain uninvolved.

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
### Task 3: Add one logical fire input and deterministic alternating cadence

**Files:**
- Modify: `project.godot`
- Modify: `src/input/player_input_source.gd`
- Create: `src/combat/primary_fire_cadence.gd`
- Create: `tests/unit/test_primary_fire_cadence.gd`
- Create: `tests/integration/test_primary_fire_input.gd`
- Modify: `tests/integration/test_input_map.gd`

**Interfaces:**
- Produces: `PlayerInputSource.is_primary_fire_held() -> bool`.
- Produces: `PrimaryFireCadence.advance(held: bool, delta: float) -> Array[int]`.
- Muzzle-side enum: `LEFT = 0`, `RIGHT = 1`.
- Produces: `PrimaryFireCadence.reset()`.

- [ ] **Step 1: Write the failing cadence test**

`tests/unit/test_primary_fire_cadence.gd` must assert:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var cadence := PrimaryFireCadence.new()

    var first := cadence.advance(true, 0.0)
    assert_equal(first, [PrimaryFireCadence.MuzzleSide.LEFT], "first shot")

    var early := cadence.advance(true, 0.10)
    assert_true(early.is_empty(), "no shot before 1/7 second")

    var next := cadence.advance(true, 0.05)
    assert_equal(next, [PrimaryFireCadence.MuzzleSide.RIGHT], "second shot")

    var released := cadence.advance(false, 1.0)
    assert_true(released.is_empty(), "release stops immediately")

    var resumed := cadence.advance(true, 0.0)
    assert_equal(resumed, [PrimaryFireCadence.MuzzleSide.LEFT], "alternation persists")

    cadence.reset()
    assert_equal(
        cadence.advance(true, 0.0),
        [PrimaryFireCadence.MuzzleSide.LEFT],
        "reset restores left-first order"
    )
```

Also test a `0.50` second held step emits the correct number and order without dropping cadence.

- [ ] **Step 2: Run the test and verify it fails**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: suite load failure until the new test is added to the runner later, or direct script parse/import failure when loaded manually. Do not add it to the runner before the class exists.

- [ ] **Step 3: Implement `PrimaryFireCadence`**

Create:

```gdscript
class_name PrimaryFireCadence
extends RefCounted

enum MuzzleSide {
    LEFT,
    RIGHT,
}

const SHOTS_PER_SECOND := 7.0
const SHOT_INTERVAL := 1.0 / SHOTS_PER_SECOND

var _was_held := false
var _time_until_next_shot := 0.0
var _next_side: MuzzleSide = MuzzleSide.LEFT

func advance(held: bool, delta: float) -> Array[int]:
    var shots: Array[int] = []
    var safe_delta := maxf(delta, 0.0)

    if not held:
        _was_held = false
        _time_until_next_shot = 0.0
        return shots

    if not _was_held:
        _was_held = true
        shots.append(_consume_side())
        _time_until_next_shot = SHOT_INTERVAL
        return shots

    _time_until_next_shot -= safe_delta
    while _time_until_next_shot <= 0.0:
        shots.append(_consume_side())
        _time_until_next_shot += SHOT_INTERVAL
    return shots

func reset() -> void:
    _was_held = false
    _time_until_next_shot = 0.0
    _next_side = MuzzleSide.LEFT

func _consume_side() -> int:
    var result := _next_side
    _next_side = (
        MuzzleSide.RIGHT
        if _next_side == MuzzleSide.LEFT
        else MuzzleSide.LEFT
    )
    return result
```

- [ ] **Step 4: Bind LMB and physical `V` to one action**

Update `project.godot` so `fire_primary` has two events:

- `InputEventMouseButton` button index `1`;
- `InputEventKey` physical keycode `86`.

Do not create separate mouse and keyboard fire actions.

- [ ] **Step 5: Expose the logical held state**

Add `&"fire_primary"` to `PlayerInputSource.REQUIRED_ACTIONS` and:

```gdscript
func is_primary_fire_held() -> bool:
    return _strength(&"fire_primary") > 0.0
```

- [ ] **Step 6: Write input-map integration assertions**

`test_primary_fire_input.gd` must inspect `InputMap.action_get_events(&"fire_primary")` and prove exactly one mouse-left binding and one physical-`V` binding exist. `test_input_map.gd` must add `fire_primary` to required actions.

- [ ] **Step 7: Run focused tests**

Temporarily add the two new suites to `tests/test_runner.gd`, then run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 8: Commit**

```powershell
git add `
  project.godot `
  src/input/player_input_source.gd `
  src/combat/primary_fire_cadence.gd `
  tests/unit/test_primary_fire_cadence.gd `
  tests/integration/test_primary_fire_input.gd `
  tests/integration/test_input_map.gd `
  tests/test_runner.gd
git commit -m "feat: add deterministic primary fire cadence"
```

---

### Task 4: Implement typed shield, hull, regeneration, repair, and overflow

**Files:**
- Create: `src/combat/damage_packet.gd`
- Create: `src/combat/damage_result.gd`
- Create: `src/combat/damage_tuning.gd`
- Create: `src/combat/damage_state.gd`
- Create: `config/combat/player_damage_tuning.tres`
- Create: `config/combat/drone_damage_tuning.tres`
- Create: `tests/unit/test_damage_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `DamagePacket.create(amount, kind, point, normal, source_id, tick, contact_key)`.
- `DamageState.apply_damage(packet) -> DamageResult`.
- `DamageState.advance(delta)`.
- `DamageState.reset_full()`.
- Signals: `damage_resolved`, `shield_broken`, `destroyed`, `state_changed`.

- [ ] **Step 1: Write failing damage-state tests**

`tests/unit/test_damage_state.gd` must cover:

- `50` damage from full state produces shield `100`, hull `200`;
- `50` damage with shield `20` produces shield `0`, hull `170`;
- break signal/result occurs once;
- destroyed result occurs once;
- normal regen starts only after `8.0` seconds;
- regen rate is `3.0` per second;
- zero shield waits `20.0` seconds before charge rises;
- new damage resets normal delay or reboot;
- player hull repair requires full shield plus `10.0` seconds and runs at `1.0` per second;
- drone tuning never repairs hull;
- destroyed states do not regenerate or repair;
- reset returns full values and clears timers.

Construct test tuning in code rather than loading resources so the unit test remains isolated.

- [ ] **Step 2: Run and verify failure**

Add the suite to `tests/test_runner.gd` and run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: failure because the damage classes do not exist.

- [ ] **Step 3: Implement typed packets and results**

`damage_packet.gd`:

```gdscript
class_name DamagePacket
extends RefCounted

enum Kind {
    PROJECTILE,
    COLLISION,
}

var amount: float
var kind: Kind
var impact_point: Vector3
var impact_normal: Vector3
var source_instance_id: int
var physics_tick: int
var contact_key: StringName

static func create(
    requested_amount: float,
    requested_kind: Kind,
    point: Vector3,
    normal: Vector3,
    source_id: int = 0,
    tick: int = 0,
    key: StringName = &""
) -> DamagePacket:
    var packet := DamagePacket.new()
    packet.amount = maxf(requested_amount, 0.0)
    packet.kind = requested_kind
    packet.impact_point = point
    packet.impact_normal = normal.normalized() if not normal.is_zero_approx() else Vector3.UP
    packet.source_instance_id = source_id
    packet.physics_tick = tick
    packet.contact_key = key
    return packet
```

`damage_result.gd` must expose requested/applied values, remaining state, break/hull/destroy flags, point, normal, and kind without performing calculations.

- [ ] **Step 4: Implement tuning resources**

`DamageTuning` exact defaults:

```gdscript
class_name DamageTuning
extends Resource

@export var maximum_shield := 150.0
@export var maximum_hull := 200.0
@export var shield_regeneration_delay := 8.0
@export var shield_regeneration_rate := 3.0
@export var shield_reboot_delay := 20.0
@export var hull_repair_enabled := false
@export var hull_repair_delay_after_full_shield := 10.0
@export var hull_repair_rate := 1.0
```

Create:

- `player_damage_tuning.tres` with `hull_repair_enabled = true`;
- `drone_damage_tuning.tres` with `hull_repair_enabled = false`.

- [ ] **Step 5: Implement `DamageState`**

`DamageState` owns all arithmetic and timers. Required public API:

```gdscript
func apply_damage(packet: DamagePacket) -> DamageResult
func advance(delta: float) -> void
func reset_full() -> void
func get_shield() -> float
func get_hull() -> float
func get_shield_ratio() -> float
func get_hull_ratio() -> float
func is_destroyed() -> bool
func is_rebooting() -> bool
func is_recharging() -> bool
func is_repairing_hull() -> bool
```

Rules:

- use `min(current_shield, packet.amount)` for shield;
- carry exact remainder to hull;
- set reboot timer whenever shield becomes or remains zero after damage;
- emit `shield_broken` only on the positive-to-zero transition;
- emit `destroyed` only on the positive-to-zero hull transition;
- no arithmetic in visual or HUD subscribers;
- clamp all values;
- ignore zero-damage packets without changing timers.

- [ ] **Step 6: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 7: Commit**

```powershell
git add `
  src/combat/damage_packet.gd `
  src/combat/damage_result.gd `
  src/combat/damage_tuning.gd `
  src/combat/damage_state.gd `
  config/combat/player_damage_tuning.tres `
  config/combat/drone_damage_tuning.tres `
  tests/unit/test_damage_state.gd `
  tests/test_runner.gd
git commit -m "feat: add reusable shield and hull damage state"
```

---

### Task 5: Add swept pulse projectiles, pooling, and primary-fire controller

**Files:**
- Create: `src/combat/pulse_projectile.gd`
- Create: `src/combat/pulse_projectile_pool.gd`
- Create: `src/combat/primary_fire_controller.gd`
- Create: `scenes/combat/pulse_projectile.tscn`
- Create: `tests/integration/test_pulse_projectile.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `PulseProjectile.activate(world_transform, velocity, source_body, damage, lifetime)`.
- `PulseProjectile.deactivate()`.
- Signal: `resolved(projectile, damage_result, hit_damageable)`.
- `PulseProjectilePool.fire(world_transform, velocity, source_body) -> PulseProjectile`.
- `PulseProjectilePool.clear_all()`.
- `PrimaryFireController.set_projectile_pool(pool: PulseProjectilePool)`.
- `PrimaryFireController.reset_runtime_state()`.
- Signal: `shot_fired(side, world_transform)`, `damage_confirmed(result)`.

- [ ] **Step 1: Write the failing projectile integration test**

The test must build a temporary `Node3D` world containing:

- a thin `StaticBody3D` wall;
- a damageable body with `DamageState`;
- a projectile pool;
- a source `RigidBody3D`.

Assertions:

- a `900 m/s` projectile crossing a thin wall in one physics frame still resolves a hit;
- the projectile deactivates on the first hit;
- source body is excluded permanently;
- damageable target receives exactly `15`;
- non-damageable wall resolves cleanup without hit confirmation;
- inherited velocity is included;
- lifetime deactivates at `3.0` seconds;
- reset clears all active projectiles.

- [ ] **Step 2: Run and verify failure**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: missing projectile classes/scenes.

- [ ] **Step 3: Create the projectile scene**

`pulse_projectile.tscn` root is `Node3D` with:

- `MeshInstance3D` using a small emissive capsule or sphere mesh;
- short `TrailMesh` child, not a long laser;
- no physics body;
- script `PulseProjectile`.

Use a `SphereShape3D` with radius `0.15` for query sweeps inside the script.

- [ ] **Step 4: Implement swept collision**

Each physics step:

```gdscript
var motion := velocity * delta
var query := PhysicsShapeQueryParameters3D.new()
query.shape = _query_shape
query.transform = global_transform
query.motion = motion
query.collision_mask = collision_mask
query.exclude = [_source_body.get_rid()] if is_instance_valid(_source_body) else []

var fractions := get_world_3d().direct_space_state.cast_motion(query)
var safe_fraction := float(fractions[0])
if safe_fraction < 1.0:
    global_position += motion * safe_fraction
    _resolve_first_hit(query, motion, safe_fraction)
else:
    global_position += motion
```

At the impact transform, call `get_rest_info` to obtain collider, point, and normal. Search the collider itself and its direct children for `DamageState`; do not walk arbitrary scene ancestors beyond the collider root.

On a damageable hit:

```gdscript
var packet := DamagePacket.create(
    damage,
    DamagePacket.Kind.PROJECTILE,
    hit_point,
    hit_normal,
    _source_body.get_instance_id(),
    Engine.get_physics_frames()
)
var result := damage_state.apply_damage(packet)
```

Then emit once and deactivate.

- [ ] **Step 5: Implement deterministic pooling**

`PulseProjectilePool` prewarms `32` projectiles. `fire` uses the first inactive projectile; if all are active, recycle the oldest active projectile. `clear_all` deactivates every projectile and resets sequence age.

- [ ] **Step 6: Implement `PrimaryFireController`**

Exports:

```gdscript
@export var body_path: NodePath
@export var input_source_path: NodePath
@export var model_path: NodePath
```

Resolve exact muzzle paths under the model. The pool is injected later by `FlightRoomController`; absence of a pool keeps firing inactive without invalidating the standalone player scene:

```gdscript
const LEFT_MUZZLE := NodePath("Weapons/Primary/LeftMuzzle")
const RIGHT_MUZZLE := NodePath("Weapons/Primary/RightMuzzle")
```

If either is absent, disable only primary firing and report an error.

For every side returned by `PrimaryFireCadence.advance`:

```gdscript
var muzzle := _left_muzzle if side == PrimaryFireCadence.MuzzleSide.LEFT else _right_muzzle
var forward := -_body.global_transform.basis.z.normalized()
var velocity := _body.linear_velocity + forward * 900.0
_pool.fire(muzzle.global_transform, velocity, _body)
```

The projectile orientation must come from the verified muzzle transform, while travel direction remains exact fighter-forward.

- [ ] **Step 7: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass, including high-speed no-tunneling.

- [ ] **Step 8: Commit**

```powershell
git add `
  src/combat/pulse_projectile.gd `
  src/combat/pulse_projectile_pool.gd `
  src/combat/primary_fire_controller.gd `
  scenes/combat/pulse_projectile.tscn `
  tests/integration/test_pulse_projectile.gd `
  tests/test_runner.gd
git commit -m "feat: add swept pulse projectile weapon"
```

---
