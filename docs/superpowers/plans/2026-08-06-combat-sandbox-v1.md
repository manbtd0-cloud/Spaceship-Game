# Combat Sandbox v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first complete combat loop: fly, aim, hit a moving practice drone, reveal localized hexagonal shields, break the shield, damage hull, destroy the target, and watch it respawn while player and target combat state remain readable in the HUD.

**Architecture:** Reuse the existing `PulseProjectile`, `PulseProjectilePool`, `DamagePacket`, `DamageResult`, `DamageTuning`, and `DamageState` contracts. Add reusable collision damage, a pooled ellipsoid shield-impact visual, a deterministic force-driven practice drone, lifecycle/respawn control, and a separate combat HUD panel. Existing flight, muzzle, projectile, camera, pause, settings, thruster, and asteroid behavior remains authoritative.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, `ShaderMaterial`, the existing dependency-free test runner, and the Windows PowerShell verifier.

## Global constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Verified baseline: schema-five fighter contract passed, deterministic thruster matrix passed, `PASS: 39 suites`, exact zero inertial speed/direction drift, clean main-scene boot, and manual agile-fighter acceptance passed.
- Final target: `PASS: 44 suites`.
- Projectile speed remains exactly `900 m/s`.
- Projectile damage remains exactly `15`.
- Existing fire cadence, exact muzzle transforms, 32-projectile pool, swept collision, source exclusion, and first-hit cleanup remain unchanged.
- Existing player mass, collider, flight tuning, speed/angular envelopes, AI Assisted, Smart Stabilize, cameras, pause, settings, reset input, and thruster matrix remain unchanged.
- `DamageState` remains the only shield/hull authority: shield first, overflow into hull, destruction at zero hull.
- Collision damage uses `DamagePacket.Kind.COLLISION`; projectile damage uses `DamagePacket.Kind.PROJECTILE`.
- Shields are ship-aligned ellipsoids with procedural hexagonal impacts.
- Shield visuals are invisible at rest, localized on ordinary hits, and briefly full-shell on shield break.
- Practice-drone hull never repairs.
- Drone active motion uses `RigidBody3D.apply_central_force()` and `apply_torque()` only.
- Transform/velocity assignment is allowed only while frozen during reset or respawn.
- No per-frame node, mesh, material, shader, or impact-slot allocation.
- No GitHub Actions.
- No approval pauses between implementation tasks unless a fresh failure exposes a real design contradiction.
- Four substantial batches, at most two implementation commits, one verification/documentation closure commit.
- The user runs one complete Windows verifier only after Tasks 1–3 are implemented and reviewed.

## Locked gameplay values

### Player damage

```text
maximum_shield = 150
maximum_hull = 200
shield_regeneration_delay = 8 s
shield_regeneration_rate = 3/s
shield_reboot_delay = 20 s
hull_repair_enabled = true
hull_repair_delay_after_full_shield = 10 s
hull_repair_rate = 1/s
```

### Practice-drone damage

```text
maximum_shield = 120
maximum_hull = 150
shield_regeneration_delay = 7 s
shield_regeneration_rate = 3/s
shield_reboot_delay = 15 s
hull_repair_enabled = false
respawn_delay = 3 s
```

### Collision damage

```text
minimum_impact_speed = 12 m/s
damage_per_excess_mps = 2
maximum_damage = 80
repeat_guard_frames = 12
```

### Practice-drone movement

```text
mass = 1600 kg
preferred_distance = 140 m
distance_band = 25 m
maximum_speed = 45 m/s
maximum_acceleration = 18 m/s²
orbit_speed = 24 m/s
radial_speed = 30 m/s
vertical_speed = 8 m/s
velocity_response = 1.8
maximum_turn_torque = 12000 Nm
angular_damping = 3000
spawn = (0, 20, -180)
```

---

## File map

### Create

```text
src/combat/collision_damage_math.gd
src/combat/collision_damage_receiver.gd
src/combat/shield_impact_math.gd
src/combat/shield_impact_visualizer.gd
shaders/shield_hex_impact.gdshader
scenes/combat/shield_impact_visualizer.tscn
src/combat/practice_drone_intent.gd
src/combat/practice_drone_tuning.gd
src/combat/practice_drone_steering.gd
src/combat/practice_drone_controller.gd
config/combat/player_damage_tuning.tres
config/combat/practice_drone_damage_tuning.tres
config/combat/practice_drone_tuning.tres
scenes/combat/practice_drone.tscn
src/ui/combat_hud.gd
scenes/ui/combat_hud.tscn
tests/unit/test_collision_damage_math.gd
tests/unit/test_shield_impact_math.gd
tests/unit/test_practice_drone_steering.gd
tests/integration/test_practice_drone_scene.gd
tests/integration/test_combat_sandbox.gd
```

### Modify

```text
src/combat/damage_state.gd
scenes/player/player_interceptor.tscn
src/flight_room/flight_room_controller.gd
scenes/flight_room/flight_room.tscn
scenes/ui/flight_hud.tscn
tests/test_runner.gd
tests/unit/test_damage_state.gd
tests/integration/test_player_scene.gd
tests/integration/test_flight_room_scene.gd
tests/integration/test_pulse_projectile.gd
README.md
docs/superpowers/plans/deferred-milestones.md
```

---

# Task 1: Runtime damage, collision damage, and shield impacts

**Files:** Create collision/shield files and both damage tuning resources. Modify `DamageState`, its tests, and the test runner.

**Produces:**

```gdscript
CollisionDamageMath.compute_damage(
    relative_speed: float,
    minimum_speed: float,
    damage_per_excess_mps: float,
    maximum_damage: float
) -> float
```

```gdscript
ShieldImpactMath.local_direction(
    local_point: Vector3,
    ellipsoid_radii: Vector3
) -> Vector3

ShieldImpactMath.hit_energy(
    applied_shield_damage: float,
    maximum_shield: float
) -> float
```

```gdscript
class_name CollisionDamageReceiver
signal collision_damage_resolved(result: DamageResult)

func resolve_collision_for_test(
    other_body: PhysicsBody3D,
    impact_point: Vector3,
    impact_normal: Vector3,
    physics_tick: int
) -> DamageResult

func reset_runtime_state() -> void
```

```gdscript
class_name ShieldImpactVisualizer
func get_active_impact_count() -> int
func get_last_local_direction() -> Vector3
func get_break_energy() -> float
func reset_visuals() -> void
```

- [ ] **Step 1: Add Task 1 suites and write RED tests**

Add only these two paths to `tests/test_runner.gd`:

```gdscript
"res://tests/unit/test_collision_damage_math.gd",
"res://tests/unit/test_shield_impact_math.gd",
```

Create `tests/unit/test_collision_damage_math.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(is_zero_approx(
        CollisionDamageMath.compute_damage(11.99, 12.0, 2.0, 80.0)
    ), "sub-threshold collision applies no damage")
    assert_true(is_equal_approx(
        CollisionDamageMath.compute_damage(20.0, 12.0, 2.0, 80.0),
        16.0
    ), "collision damage uses excess speed")
    assert_true(is_equal_approx(
        CollisionDamageMath.compute_damage(100.0, 12.0, 2.0, 80.0),
        80.0
    ), "collision damage obeys cap")
    assert_true(is_zero_approx(
        CollisionDamageMath.compute_damage(NAN, 12.0, 2.0, 80.0)
    ), "non-finite speed fails closed")
```

Create `tests/unit/test_shield_impact_math.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var radii := Vector3(8.0, 3.0, 7.0)
    assert_true(
        ShieldImpactMath.local_direction(Vector3(8.0, 0.0, 0.0), radii)
        .is_equal_approx(Vector3.RIGHT),
        "right-side impact maps to local right"
    )
    assert_true(
        ShieldImpactMath.local_direction(Vector3(0.0, 3.0, 0.0), radii)
        .is_equal_approx(Vector3.UP),
        "top impact maps to local up"
    )
    assert_equal(
        ShieldImpactMath.local_direction(Vector3.ZERO, radii),
        Vector3.FORWARD,
        "center fallback is deterministic"
    )
    assert_true(is_equal_approx(
        ShieldImpactMath.hit_energy(15.0, 150.0),
        0.55
    ), "ordinary projectile hit remains readable")
```

Extend `tests/unit/test_damage_state.gd` with:

```gdscript
func _test_runtime_auto_advance() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(30.0))
    for _index: int in range(540):
        state._physics_process(1.0 / 60.0)
    assert_true(
        state.get_shield() > 120.0,
        "runtime DamageState advances regeneration"
    )
```

Call `_test_runtime_auto_advance()` from `run()`.

- [ ] **Step 2: Run Task 1 RED**

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: failure because collision/shield classes do not exist.

- [ ] **Step 3: Implement collision math**

Create `src/combat/collision_damage_math.gd`:

```gdscript
class_name CollisionDamageMath
extends RefCounted

static func compute_damage(
    relative_speed: float,
    minimum_speed: float,
    damage_per_excess_mps: float,
    maximum_damage: float
) -> float:
    if (
        not is_finite(relative_speed)
        or not is_finite(minimum_speed)
        or not is_finite(damage_per_excess_mps)
        or not is_finite(maximum_damage)
    ):
        return 0.0
    var excess := maxf(relative_speed - maxf(minimum_speed, 0.0), 0.0)
    return clampf(
        excess * maxf(damage_per_excess_mps, 0.0),
        0.0,
        maxf(maximum_damage, 0.0)
    )
```

- [ ] **Step 4: Make `DamageState` self-advancing**

Add:

```gdscript
@export var auto_advance: bool = true

func _physics_process(delta: float) -> void:
    if auto_advance:
        advance(delta)
```

No controller may call `advance()` for a tree-owned `DamageState` after this change.

- [ ] **Step 5: Implement collision receiver**

Create `src/combat/collision_damage_receiver.gd` with these defaults:

```gdscript
@export var body_path: NodePath = NodePath("..")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var minimum_impact_speed: float = 12.0
@export var damage_per_excess_mps: float = 2.0
@export var maximum_damage: float = 80.0
@export var repeat_guard_frames: int = 12
```

At `_ready()` resolve one `RigidBody3D` and one `DamageState`, enable contact monitoring, set at least eight reported contacts, and connect `body_entered`.

Use this exact relative-speed calculation in `_resolve()`:

```gdscript
var other_rigid := other_body as RigidBody3D
var other_velocity := (
    other_rigid.linear_velocity
    if other_rigid != null
    else Vector3.ZERO
)
var relative_speed := (_body.linear_velocity - other_velocity).length()
```

Build an unordered contact key from both instance IDs. Ignore the same key inside `repeat_guard_frames`. Apply one `DamagePacket.Kind.COLLISION` with midpoint/normal data and emit `collision_damage_resolved` only when `applied_amount > 0`.

- [ ] **Step 6: Implement shield-impact math**

Create `src/combat/shield_impact_math.gd`:

```gdscript
class_name ShieldImpactMath
extends RefCounted

static func local_direction(
    local_point: Vector3,
    ellipsoid_radii: Vector3
) -> Vector3:
    if not local_point.is_finite() or not ellipsoid_radii.is_finite():
        return Vector3.FORWARD
    var safe := Vector3(
        maxf(absf(ellipsoid_radii.x), 0.001),
        maxf(absf(ellipsoid_radii.y), 0.001),
        maxf(absf(ellipsoid_radii.z), 0.001)
    )
    var value := Vector3(
        local_point.x / safe.x,
        local_point.y / safe.y,
        local_point.z / safe.z
    )
    return value.normalized() if not value.is_zero_approx() else Vector3.FORWARD

static func hit_energy(
    applied_shield_damage: float,
    maximum_shield: float
) -> float:
    if not is_finite(applied_shield_damage) or not is_finite(maximum_shield):
        return 0.0
    if applied_shield_damage <= 0.0 or maximum_shield <= 0.0:
        return 0.0
    return clampf(
        0.35 + (applied_shield_damage / maximum_shield) * 2.0,
        0.35,
        1.0
    )
```

- [ ] **Step 7: Create procedural shield shader**

Create `shaders/shield_hex_impact.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 shield_color : source_color = vec4(0.12, 0.72, 1.0, 1.0);
uniform vec3 impact_direction = vec3(0.0, 0.0, -1.0);
uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float shield_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float full_shell : hint_range(0.0, 1.0) = 0.0;
uniform float hex_scale = 12.0;
varying vec3 local_vertex;

void vertex() {
    local_vertex = VERTEX;
}

float hex_edges(vec2 point) {
    vec2 p = point * hex_scale;
    vec2 q = vec2(p.x * 1.1547005, p.y + p.x * 0.5773503);
    vec2 cell = abs(fract(q) - 0.5);
    return smoothstep(0.38, 0.49, max(cell.x, cell.y));
}

void fragment() {
    vec3 n = normalize(local_vertex);
    vec3 weights = pow(abs(n), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    float hex = hex_edges(n.yz) * weights.x
        + hex_edges(n.xz) * weights.y
        + hex_edges(n.xy) * weights.z;
    float focus = pow(max(dot(n, normalize(impact_direction)), 0.0), 30.0);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
    float reveal = mix(focus, 1.0, full_shell);
    ALBEDO = shield_color.rgb;
    EMISSION = shield_color.rgb * (1.5 + 4.0 * energy);
    ALPHA = energy * reveal * (0.24 + 0.76 * hex)
        * (0.35 + 0.65 * rim) * (0.55 + 0.45 * shield_ratio);
}
```

- [ ] **Step 8: Build pooled shield visual**

Create `scenes/combat/shield_impact_visualizer.tscn`:

```text
ShieldImpactVisualizer (Node3D, script)
├── Impact01 (MeshInstance3D, SphereMesh)
├── Impact02 (MeshInstance3D, SphereMesh)
├── Impact03 (MeshInstance3D, SphereMesh)
├── Impact04 (MeshInstance3D, SphereMesh)
└── BreakShell (MeshInstance3D, SphereMesh)
```

`ShieldImpactVisualizer` must:

- export `damage_state_path`, `ellipsoid_radii`, `shield_color`, `hit_duration = 0.55`, `break_duration = 0.85`;
- resolve and duplicate five materials once at `_ready()`;
- connect `damage_resolved`, `shield_broken`, and `state_changed`;
- assign hits to a four-slot ring;
- map `to_local(result.impact_point)` through `ShieldImpactMath.local_direction()`;
- decay slot energy without creating objects;
- reveal `BreakShell` only for shield break;
- remain invisible when all energy is zero;
- expose the four getters listed above.

- [ ] **Step 9: Create exact damage resources**

Create:

```text
config/combat/player_damage_tuning.tres
config/combat/practice_drone_damage_tuning.tres
```

Use the locked player/drone values exactly.

- [ ] **Step 10: Run Task 1 GREEN**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 41 suites`.

Keep Task 1 changes for the first consolidated commit after Task 2.

---

# Task 2: Force-driven practice drone and respawn lifecycle

**Files:** Create drone intent/tuning/steering/controller/resource/scene and two new tests.

**Produces:**

```gdscript
class_name PracticeDroneIntent
extends RefCounted
var acceleration_world := Vector3.ZERO
var torque_world := Vector3.ZERO
```

```gdscript
PracticeDroneSteering.compute_into(
    result: PracticeDroneIntent,
    relative_position: Vector3,
    relative_velocity: Vector3,
    current_forward: Vector3,
    angular_velocity: Vector3,
    elapsed_seconds: float,
    tuning: PracticeDroneTuning
) -> void
```

```gdscript
class_name PracticeDroneController
signal respawn_started(duration: float)
signal respawn_progress(seconds_remaining: float)
signal respawned

func set_target(body: RigidBody3D) -> void
func reset_to_spawn() -> void
func is_respawning() -> bool
func get_respawn_remaining() -> float
func get_last_intent() -> PracticeDroneIntent
```

- [ ] **Step 1: Add Task 2 suites and write RED tests**

Add:

```gdscript
"res://tests/unit/test_practice_drone_steering.gd",
"res://tests/integration/test_practice_drone_scene.gd",
```

Create `test_practice_drone_steering.gd` with cases for:

```text
far target -> approach acceleration
close target -> retreat acceleration
inside distance band -> nonzero orbit acceleration
acceleration <= maximum_acceleration
torque <= maximum_turn_torque
non-finite input -> zero intent
```

Use this core assertion shape:

```gdscript
var tuning := PracticeDroneTuning.new()
var intent := PracticeDroneIntent.new()
PracticeDroneSteering.compute_into(
    intent,
    Vector3(0.0, 0.0, 260.0),
    Vector3.ZERO,
    Vector3.FORWARD,
    Vector3.ZERO,
    0.0,
    tuning
)
assert_true(intent.acceleration_world.z > 0.0, "far drone approaches")
assert_true(
    intent.acceleration_world.length() <= tuning.maximum_acceleration + 0.001,
    "acceleration remains bounded"
)
```

Create `test_practice_drone_scene.gd` and assert the exact scene contract in Step 6.

- [ ] **Step 2: Run Task 2 RED**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: failure because drone classes/scene do not exist.

- [ ] **Step 3: Implement intent and tuning**

Create `PracticeDroneIntent` as defined above.

Create `PracticeDroneTuning`:

```gdscript
class_name PracticeDroneTuning
extends Resource

@export var preferred_distance: float = 140.0
@export var distance_band: float = 25.0
@export var maximum_speed: float = 45.0
@export var maximum_acceleration: float = 18.0
@export var orbit_speed: float = 24.0
@export var radial_speed: float = 30.0
@export var vertical_speed: float = 8.0
@export var velocity_response: float = 1.8
@export var maximum_turn_torque: float = 12000.0
@export var angular_damping: float = 3000.0
@export var respawn_delay: float = 3.0
```

Create `config/combat/practice_drone_tuning.tres` with exact values.

- [ ] **Step 4: Implement pure steering**

`compute_into()` must:

1. clear the reusable result;
2. fail closed on non-finite input;
3. use `to_player = relative_position.normalized()`;
4. derive a stable orbit tangent from world up, with right-axis fallback;
5. approach beyond 165 m;
6. retreat inside 115 m;
7. orbit inside the band;
8. add vertical sine motion at `0.85 rad/s`;
9. clamp desired velocity to `45 m/s`;
10. compute `(desired_velocity - relative_velocity) * 1.8` and clamp to `18 m/s²`;
11. face the player with `current_forward.cross(to_player)`;
12. subtract angular damping and clamp torque to `12000 Nm`.

The `relative_velocity` argument is explicitly **drone velocity minus target velocity**.

- [ ] **Step 5: Implement controller**

During active life:

```gdscript
var relative_position := _target.global_position - _body.global_position
var relative_velocity := _body.linear_velocity - _target.linear_velocity
PracticeDroneSteering.compute_into(
    _intent,
    relative_position,
    relative_velocity,
    -_body.global_transform.basis.z,
    _body.angular_velocity,
    _elapsed,
    tuning
)
_body.apply_central_force(_intent.acceleration_world * _body.mass)
_body.apply_torque(_intent.torque_world)
```

On destruction:

```text
start 3.0 s respawn
freeze body
disable collision layer/mask
stop force/torque
show DestructionPulse for 0.45 s
hide VisualRoot after 0.12 s
emit respawn signals
reset at countdown zero
```

`reset_to_spawn()` is the only active runtime path allowed to assign transform or velocity. It restores saved layers/masks, visibility, collision, shield/hull, timers, and intent.

- [ ] **Step 6: Build exact drone scene**

```text
PracticeDrone (RigidBody3D)
  mass = 1600
  gravity_scale = 0
  continuous_cd = true
  contact_monitor = true
  max_contacts_reported = 8
├── CollisionShape3D (SphereShape radius 2.4)
├── VisualRoot
│   ├── Core (SphereMesh, metallic dark body)
│   ├── GuardRing (TorusMesh, emissive cyan)
│   ├── FinTop (BoxMesh)
│   ├── FinBottom (BoxMesh)
│   ├── FinLeft (BoxMesh)
│   └── FinRight (BoxMesh)
├── DamageState (drone damage tuning)
├── CollisionDamageReceiver
├── ShieldImpactVisualizer (radii 3.2/2.4/3.2)
├── DestructionPulse (SphereMesh, hidden)
└── PracticeDroneController (drone tuning)
```

The geometric design is intentional for a training drone. `VisualRoot` remains replaceable without changing combat contracts.

- [ ] **Step 7: Run Task 2 GREEN**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS: 43 suites`.

- [ ] **Step 8: First consolidated implementation commit**

Stage only Task 1–2 files and commit:

```powershell
git commit -m "feat: add reusable combat target systems"
```

Do not push or ask the user to verify.

---

# Task 3: Player/room integration, combat HUD, and end-to-end loop

**Files:** Create combat HUD and full sandbox test. Modify player/room/HUD/controller and existing integration tests.

**Produces:**

```gdscript
class_name CombatHud
extends Control

func get_hit_marker_alpha() -> float
func get_player_shield_percent() -> float
func get_player_hull_percent() -> float
func get_target_shield_percent() -> float
func get_target_hull_percent() -> float
func get_target_status_text() -> String
```

- [ ] **Step 1: Add full sandbox suite and write RED**

Add:

```gdscript
"res://tests/integration/test_combat_sandbox.gd",
```

The test loads `res://scenes/flight_room/flight_room.tscn` and verifies:

```text
player DamageState/CollisionDamageReceiver/ShieldImpactVisualizer
one PracticeDrone at (0,20,-180)
FlightHud/CombatHud dependencies resolve
real pooled projectile removes exactly 15 drone shield
shield impact slot activates
hit marker activates only for damageable hit
lethal damage enters respawn and disables collision
3.0 s step restores 120 shield/150 hull at spawn
high-speed collision damages shield before hull
R/reset restores player and drone
player destruction temporarily disables flight/fire then resets
```

Extend:

```text
test_player_scene.gd -> player combat nodes/tuning
test_flight_room_scene.gd -> drone and CombatHud paths
test_pulse_projectile.gd -> DamageResult impact reaches shield visual signal path
```

- [ ] **Step 2: Run Task 3 RED**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: failure because player/room/HUD integration is absent.

- [ ] **Step 3: Add player combat nodes**

Modify `player_interceptor.tscn`:

```text
DamageState (player damage tuning)
CollisionDamageReceiver (body .., state ../DamageState)
ShieldImpactVisualizer (state ../DamageState, radii 8.2/3.0/7.2)
```

Also set:

```text
contact_monitor = true
max_contacts_reported = 8
```

Do not change player mass, collider, layers/masks, flight controller, thrusters, projectile pool, or fire controller.

- [ ] **Step 4: Create combat HUD scene**

```text
CombatHud (Control, full rect)
├── PlayerPanel (bottom-left)
│   └── PLAYER title, shield label/bar, hull label/bar
├── TargetPanel (top-center)
│   └── PRACTICE DRONE title, status, shield label/bar, hull label/bar
└── HitMarker (center, four short corner segments)
```

Use restrained dark translucent panels, cyan shield, warm hull, no oversized arcade banners.

- [ ] **Step 5: Implement combat HUD**

Use exact scene-relative paths from `FlightHud/CombatHud`:

```text
../../PlayerInterceptor/DamageState
../../PracticeDrone/DamageState
../../PracticeDrone/PracticeDroneController
../../PlayerInterceptor/PulseProjectilePool
```

At `_ready()` connect both damage states, drone respawn signals, and player pool `projectile_resolved`.

Hit confirmation rule:

```gdscript
if hit_damageable and result != null and result.applied_amount > 0.0:
    _hit_flash_remaining = 0.12
```

Wall hits and ignored damage never flash. Bars always use ratios from `DamageState`.

Instance `CombatHud` under the existing `FlightHud` without moving telemetry, nose reticle, or velocity marker.

- [ ] **Step 6: Integrate drone/player lifecycle in flight room**

Instance `PracticeDrone` at:

```text
Vector3(0, 20, -180)
```

Add to `FlightRoomController`:

```gdscript
@export var player_damage_state_path: NodePath
@export var practice_drone_controller_path: NodePath

const PLAYER_RESPAWN_DELAY := 1.25
var _player_respawn_remaining := 0.0
```

At `_ready()` resolve player damage and drone controller, call `set_target(_body)`, and connect player destruction.

On player destruction:

```gdscript
_player_respawn_remaining = PLAYER_RESPAWN_DELAY
_body.freeze = true
_controller.set_physics_process(false)
_primary_fire_controller.set_firing_enabled(false)
_projectile_pool.clear_all()
```

At countdown zero call `reset_player()`.

Extend `reset_player()` to reset player damage/collision/shield visuals, reset drone to spawn, and re-enable flight/fire while preserving all existing reset behavior.

- [ ] **Step 7: Run Task 3 GREEN and inertial gate**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/verify_inertial_velocity.gd
```

Required:

```text
PASS: 44 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
```

- [ ] **Step 8: Second consolidated implementation commit**

Stage only Task 3 files and commit:

```powershell
git commit -m "feat: integrate combat sandbox loop"
```

Perform one static scope review. No file outside the declared map may change.

---

# Task 4: Authoritative verification, manual acceptance, and closure

- [ ] **Step 1: Mark documentation verification-pending**

Update `README.md` with:

```text
one deterministic force-driven practice drone
reusable projectile/collision shield-and-hull damage
pooled ship-aligned ellipsoid shield impacts with procedural hex patterns
drone destruction and three-second respawn
player/target shield-hull HUD and damage-confirmed hit marker
PASS: 44 suites
```

Record Combat Sandbox v1 as implementation-complete/verification-pending in `deferred-milestones.md`. Preserve historical AI/Smart Stabilize text.

- [ ] **Step 2: Request one complete Windows verifier**

```powershell
git fetch origin
git rebase origin/agent/playable-flight-room
powershell -ExecutionPolicy Bypass -File .\tools\verify\verify.ps1
```

Required:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 44 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
==> Boot main scene briefly
```

No parser, path, shader compile, orphan-node, retained-resource, runtime, or boot error is acceptable.

- [ ] **Step 3: Debug only from fresh first-failure evidence**

Use `superpowers:systematic-debugging`. Fix the originating contract only. Do not bypass real projectile hits, remove shield visuals, assign active drone velocity directly, weaken strict tests, or alter existing flight verification.

- [ ] **Step 4: Manual combat acceptance**

```powershell
godot --path .
```

Verify:

1. Drone spawns roughly 180 m ahead and moves visibly.
2. It approaches when far, retreats when close, and orbits/evasively strafes inside its band.
3. Movement is smooth and force-driven.
4. Projectile hits reveal localized hex shield impacts on the hit side.
5. Shield is invisible at rest rather than a permanent bright bubble.
6. Ordinary hit removes exactly 15 shield.
7. Regeneration waits and then refills slowly.
8. Shield break flashes the full shell; subsequent hits damage hull.
9. Drone destruction gives a short pulse/disappearance and respawns after three seconds at full state.
10. Wall hits do not show hit confirmation.
11. High-speed collisions damage shield before hull on player and drone.
12. Player destruction briefly disables flight/fire and resets without an explosion requirement.
13. `R` restores player and drone.
14. Assisted, AI Assisted, Inertial, Smart Stabilize, boost, firing, muzzles, thrusters, cameras, pause, settings, asteroid collision, and zero-drift behavior remain functional.

- [ ] **Step 5: Close and commit documentation**

After automated and manual acceptance, set status to:

```text
VERIFIED — schema-five and matrix contracts passed, PASS: 44 suites, exact zero inertial drift, clean main-scene boot, and Windows manual combat acceptance passed.
```

Commit only documentation:

```powershell
git commit -m "docs: verify combat sandbox v1"
```

---

## Completion rule

Do not call Combat Sandbox v1 complete until all are true:

```text
PASS: 44 suites
exact zero inertial speed drift
exact zero inertial direction drift
clean main-scene boot
manual projectile hit/shield break/hull destruction/respawn passed
manual collision damage passed
manual player destruction/reset recovery passed
```
