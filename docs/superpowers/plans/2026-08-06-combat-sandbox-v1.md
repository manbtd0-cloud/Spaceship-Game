# Combat Sandbox v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first complete combat loop: fly, aim, hit a moving practice drone, reveal localized hexagonal shields, break the shield, damage hull, destroy the target, and watch it respawn while player and target combat state remain readable in the HUD.

**Architecture:** Reuse the existing `PulseProjectile`, `PulseProjectilePool`, `DamagePacket`, `DamageResult`, `DamageTuning`, and `DamageState` contracts. Add a reusable collision-damage receiver, pooled ellipsoid shield-impact visual, deterministic rigid-body practice drone, lifecycle/respawn controller, and a separate combat HUD panel. The existing player flight, muzzle, projectile, camera, pause, settings, thruster, and asteroid systems remain authoritative.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, `RigidBody3D`, `ShaderMaterial`, dependency-free test runner, Windows PowerShell verifier.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Verified baseline: schema-five fighter contract passed, deterministic thruster matrix passed, `PASS: 39 suites`, exact zero inertial speed/direction drift, clean main-scene boot, manual agile-fighter acceptance passed.
- Final runner target: `PASS: 44 suites`.
- Existing projectile speed remains exactly `900 m/s`.
- Existing projectile damage remains exactly `15`.
- Existing primary-fire cadence, muzzle transforms, 32-projectile pool, swept collision, source exclusion, and first-hit cleanup remain unchanged.
- Existing player mass, collider, flight forces, torques, speed envelopes, angular envelopes, AI Assisted, Smart Stabilize, cameras, pause, settings, reset input, and thruster matrix remain unchanged.
- Shield damage is resolved by the existing `DamageState`: shield first, overflow into hull, destruction at zero hull.
- Collision damage uses `DamagePacket.Kind.COLLISION`; projectile damage uses `DamagePacket.Kind.PROJECTILE`.
- Shield visuals are ship-aligned ellipsoids and use procedural hexagonal impact patterns; no texture download or runtime image generation.
- Shield visuals are normally invisible; a hit reveals a localized hex impact and shield break reveals a short full-shell flash.
- Automatic shield regeneration remains slow and damage restarts its delay/reboot timers.
- Practice-drone hull never repairs.
- The practice drone uses real `RigidBody3D` force and torque; no direct velocity assignment during active gameplay.
- Respawn/reset may assign transforms and clear velocity while the body is frozen.
- No per-frame node, mesh, material, shader, or impact-slot allocation.
- No GitHub Actions.
- No approval pauses between implementation tasks unless a fresh verifier failure exposes a design contradiction.
- Execute in four substantial batches. Use at most two implementation commits and one verification/documentation closure commit.
- Do not ask the user to run intermediate commands. Request one complete Windows verifier only after Tasks 1–3 are implemented and statically reviewed.

---

## Locked gameplay values

### Player damage tuning

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

### Practice-drone damage tuning

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
respawn_delay = 3 s
spawn = (0, 20, -180)
```

---

## File map

### Create

- `src/combat/collision_damage_math.gd`
- `src/combat/collision_damage_receiver.gd`
- `src/combat/shield_impact_math.gd`
- `src/combat/shield_impact_visualizer.gd`
- `shaders/shield_hex_impact.gdshader`
- `scenes/combat/shield_impact_visualizer.tscn`
- `src/combat/practice_drone_intent.gd`
- `src/combat/practice_drone_tuning.gd`
- `src/combat/practice_drone_steering.gd`
- `src/combat/practice_drone_controller.gd`
- `config/combat/player_damage_tuning.tres`
- `config/combat/practice_drone_damage_tuning.tres`
- `config/combat/practice_drone_tuning.tres`
- `scenes/combat/practice_drone.tscn`
- `src/ui/combat_hud.gd`
- `scenes/ui/combat_hud.tscn`
- `tests/unit/test_collision_damage_math.gd`
- `tests/unit/test_shield_impact_math.gd`
- `tests/unit/test_practice_drone_steering.gd`
- `tests/integration/test_practice_drone_scene.gd`
- `tests/integration/test_combat_sandbox.gd`

### Modify

- `src/combat/damage_state.gd`
- `scenes/player/player_interceptor.tscn`
- `src/flight_room/flight_room_controller.gd`
- `scenes/flight_room/flight_room.tscn`
- `scenes/ui/flight_hud.tscn`
- `tests/test_runner.gd`
- `tests/unit/test_damage_state.gd`
- `tests/integration/test_player_scene.gd`
- `tests/integration/test_flight_room_scene.gd`
- `tests/integration/test_pulse_projectile.gd`
- `README.md`
- `docs/superpowers/plans/deferred-milestones.md`

---

# Task 1: Reusable runtime damage, collision damage, and shield impacts

**Files:**
- Create all collision/shield files and player/drone damage tuning resources listed above.
- Modify `src/combat/damage_state.gd`.
- Modify `tests/test_runner.gd`.
- Create `tests/unit/test_collision_damage_math.gd`.
- Create `tests/unit/test_shield_impact_math.gd`.
- Modify `tests/unit/test_damage_state.gd`.

**Interfaces:**

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
```

```gdscript
class_name ShieldImpactVisualizer
func get_active_impact_count() -> int
func get_last_local_direction() -> Vector3
func get_break_energy() -> float
func reset_visuals() -> void
```

- [ ] **Step 1: Register the five new suites immediately**

Add these paths to `TEST_SCRIPTS` in `tests/test_runner.gd`:

```gdscript
"res://tests/unit/test_collision_damage_math.gd",
"res://tests/unit/test_shield_impact_math.gd",
"res://tests/unit/test_practice_drone_steering.gd",
"res://tests/integration/test_practice_drone_scene.gd",
"res://tests/integration/test_combat_sandbox.gd",
```

The runner target becomes `44` suites from this point onward.

- [ ] **Step 2: Write the collision-damage RED**

Create `tests/unit/test_collision_damage_math.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_true(
        is_zero_approx(CollisionDamageMath.compute_damage(11.99, 12.0, 2.0, 80.0)),
        "sub-threshold collision applies no damage"
    )
    assert_true(
        is_equal_approx(CollisionDamageMath.compute_damage(20.0, 12.0, 2.0, 80.0), 16.0),
        "collision damage uses excess speed only"
    )
    assert_true(
        is_equal_approx(CollisionDamageMath.compute_damage(100.0, 12.0, 2.0, 80.0), 80.0),
        "collision damage obeys maximum cap"
    )
    assert_true(
        is_zero_approx(CollisionDamageMath.compute_damage(NAN, 12.0, 2.0, 80.0)),
        "non-finite speed fails closed"
    )
    assert_true(
        is_zero_approx(CollisionDamageMath.compute_damage(30.0, NAN, 2.0, 80.0)),
        "non-finite tuning fails closed"
    )
```

- [ ] **Step 3: Write the shield-impact RED**

Create `tests/unit/test_shield_impact_math.gd`:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
    var radii := Vector3(8.0, 3.0, 7.0)
    assert_true(
        ShieldImpactMath.local_direction(Vector3(8.0, 0.0, 0.0), radii)
        .is_equal_approx(Vector3.RIGHT),
        "ellipsoid right-side impact maps to local right"
    )
    assert_true(
        ShieldImpactMath.local_direction(Vector3(0.0, 3.0, 0.0), radii)
        .is_equal_approx(Vector3.UP),
        "ellipsoid top impact maps to local up"
    )
    assert_true(
        ShieldImpactMath.local_direction(Vector3.ZERO, radii)
        .is_equal_approx(Vector3.FORWARD),
        "center fallback remains deterministic"
    )
    assert_true(
        is_equal_approx(ShieldImpactMath.hit_energy(15.0, 150.0), 0.55),
        "ordinary projectile hit produces readable energy"
    )
    assert_true(
        is_equal_approx(ShieldImpactMath.hit_energy(150.0, 150.0), 1.0),
        "full-shield hit clamps at full energy"
    )
```

- [ ] **Step 4: Add a runtime-advance RED to `test_damage_state.gd`**

Add a test that puts `DamageState` in the test tree, applies 30 damage, advances physics frames through the normal eight-second delay, and confirms automatic regeneration begins without another controller calling `advance()`.

```gdscript
func _test_tree_runtime_auto_advance() -> void:
    var state := _make_state(true)
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(state)
    state.apply_damage(_packet(30.0))
    for _index: int in range(540):
        state._physics_process(1.0 / 60.0)
    assert_true(
        state.get_shield() > 120.0,
        "tree-owned DamageState automatically advances regeneration"
    )
    tree.root.remove_child(state)
```

Do not add a second runtime damage controller elsewhere.

- [ ] **Step 5: Run one RED batch**

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: the runner loads 44 paths and fails because the new classes/scenes do not exist.

- [ ] **Step 6: Implement pure collision math**

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

- [ ] **Step 7: Make `DamageState` self-advancing in runtime**

Add to `src/combat/damage_state.gd`:

```gdscript
@export var auto_advance: bool = true

func _physics_process(delta: float) -> void:
    if auto_advance:
        advance(delta)
```

Keep all existing regeneration, reboot, hull-repair, destruction, and signal semantics unchanged.

- [ ] **Step 8: Implement collision receiver**

Create `src/combat/collision_damage_receiver.gd` with these exact defaults and behavior:

```gdscript
class_name CollisionDamageReceiver
extends Node

signal collision_damage_resolved(result: DamageResult)

@export var body_path: NodePath = NodePath("..")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var minimum_impact_speed: float = 12.0
@export var damage_per_excess_mps: float = 2.0
@export var maximum_damage: float = 80.0
@export var repeat_guard_frames: int = 12

var _body: RigidBody3D
var _damage_state: DamageState
var _last_contact_tick: Dictionary = {}

func _ready() -> void:
    _body = get_node_or_null(body_path) as RigidBody3D
    _damage_state = get_node_or_null(damage_state_path) as DamageState
    if _body == null or _damage_state == null:
        push_error("CollisionDamageReceiver requires body and DamageState")
        return
    _body.contact_monitor = true
    _body.max_contacts_reported = maxi(_body.max_contacts_reported, 8)
    if not _body.body_entered.is_connected(_on_body_entered):
        _body.body_entered.connect(_on_body_entered)

func _on_body_entered(other: Node) -> void:
    var other_body := other as PhysicsBody3D
    if other_body == null:
        return
    var delta := _body.global_position - other_body.global_position
    var normal := delta.normalized() if not delta.is_zero_approx() else Vector3.UP
    var point := (_body.global_position + other_body.global_position) * 0.5
    _resolve(other_body, point, normal, Engine.get_physics_frames())

func resolve_collision_for_test(
    other_body: PhysicsBody3D,
    impact_point: Vector3,
    impact_normal: Vector3,
    physics_tick: int
) -> DamageResult:
    return _resolve(other_body, impact_point, impact_normal, physics_tick)
```

The private `_resolve()` must:

```gdscript
var other_velocity := (
    other_body.linear_velocity
    if other_body is RigidBody3D
    else Vector3.ZERO
)
var relative_speed := (_body.linear_velocity - other_velocity).length()
var amount := CollisionDamageMath.compute_damage(
    relative_speed,
    minimum_impact_speed,
    damage_per_excess_mps,
    maximum_damage
)
```

Build a deterministic unordered contact key from the two instance IDs, ignore repeats within `repeat_guard_frames`, apply one `DamagePacket.Kind.COLLISION`, emit the result when damage was applied, and expose `reset_runtime_state()` to clear the contact dictionary.

- [ ] **Step 9: Implement shield-impact math**

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
    var normalized := Vector3(
        local_point.x / safe.x,
        local_point.y / safe.y,
        local_point.z / safe.z
    )
    return normalized.normalized() if not normalized.is_zero_approx() else Vector3.FORWARD

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

- [ ] **Step 10: Add the procedural shield shader**

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
    float edge = max(cell.x, cell.y);
    return smoothstep(0.38, 0.49, edge);
}

void fragment() {
    vec3 n = normalize(local_vertex);
    vec3 weights = pow(abs(n), vec3(4.0));
    weights /= max(weights.x + weights.y + weights.z, 0.0001);
    float hex = (
        hex_edges(n.yz) * weights.x
        + hex_edges(n.xz) * weights.y
        + hex_edges(n.xy) * weights.z
    );
    float focus = pow(max(dot(n, normalize(impact_direction)), 0.0), 30.0);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
    float reveal = mix(focus, 1.0, full_shell);
    float alpha = (
        energy
        * reveal
        * (0.24 + 0.76 * hex)
        * (0.35 + 0.65 * rim)
        * (0.55 + 0.45 * shield_ratio)
    );
    ALBEDO = shield_color.rgb;
    EMISSION = shield_color.rgb * (1.5 + 4.0 * energy);
    ALPHA = alpha;
}
```

- [ ] **Step 11: Build the reusable shield scene and visualizer**

Create `scenes/combat/shield_impact_visualizer.tscn` with this exact node contract:

```text
ShieldImpactVisualizer (Node3D, script)
├── Impact01 (MeshInstance3D, SphereMesh)
├── Impact02 (MeshInstance3D, SphereMesh)
├── Impact03 (MeshInstance3D, SphereMesh)
├── Impact04 (MeshInstance3D, SphereMesh)
└── BreakShell (MeshInstance3D, SphereMesh)
```

All five meshes share one `SphereMesh`; each receives a unique duplicated `ShaderMaterial` at `_ready()`. The script must:

- export `damage_state_path`, `ellipsoid_radii`, `shield_color`, `hit_duration = 0.55`, and `break_duration = 0.85`;
- pre-resolve all five mesh/material slots at `_ready()`;
- connect `DamageState.damage_resolved`, `shield_broken`, and `state_changed`;
- assign each shield hit to the next slot in a four-slot ring;
- convert world impact point through `to_local()` and `ShieldImpactMath.local_direction()`;
- decay energy in `_process()` without allocating nodes/materials;
- reveal the full `BreakShell` only for shield break;
- remain completely invisible when all energies are zero;
- expose the four test getters listed in the interface block.

- [ ] **Step 12: Create exact tuning resources**

Create `config/combat/player_damage_tuning.tres` and `config/combat/practice_drone_damage_tuning.tres` with the locked values at the top of this plan.

- [ ] **Step 13: Run the Task 1 green gate**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected at this checkpoint: the Task 1 suites pass; drone/room suites may still fail because their scenes are intentionally not created until Task 2.

Keep changes unpushed for the first consolidated implementation commit after Task 2.

---

# Task 2: Deterministic rigid-body practice drone and lifecycle

**Files:**
- Create all practice-drone source, tuning, scene, and test files listed in the file map.

**Interfaces:**

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

- [ ] **Step 1: Write the steering RED**

Create `tests/unit/test_practice_drone_steering.gd` with these required cases:

```gdscript
extends "res://tests/support/test_case.gd"

func run() -> void:
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
    assert_true(intent.acceleration_world.z > 0.0, "far drone approaches player")
    assert_true(
        intent.acceleration_world.length() <= tuning.maximum_acceleration + 0.001,
        "drone acceleration remains bounded"
    )

    PracticeDroneSteering.compute_into(
        intent,
        Vector3(0.0, 0.0, 50.0),
        Vector3.ZERO,
        Vector3.FORWARD,
        Vector3.ZERO,
        1.0,
        tuning
    )
    assert_true(intent.acceleration_world.z < 0.0, "close drone retreats from player")

    PracticeDroneSteering.compute_into(
        intent,
        Vector3(140.0, 0.0, 0.0),
        Vector3.ZERO,
        Vector3.FORWARD,
        Vector3.ZERO,
        2.0,
        tuning
    )
    assert_true(absf(intent.acceleration_world.z) > 0.0, "drone orbits inside distance band")
    assert_true(
        intent.torque_world.length() <= tuning.maximum_turn_torque + 0.001,
        "turn torque remains bounded"
    )

    PracticeDroneSteering.compute_into(
        intent,
        Vector3(NAN, 0.0, 0.0),
        Vector3.ZERO,
        Vector3.FORWARD,
        Vector3.ZERO,
        0.0,
        tuning
    )
    assert_equal(intent.acceleration_world, Vector3.ZERO, "non-finite input fails closed")
    assert_equal(intent.torque_world, Vector3.ZERO, "non-finite input clears torque")
```

- [ ] **Step 2: Write the drone-scene RED**

Create `tests/integration/test_practice_drone_scene.gd` to assert:

```gdscript
const DRONE_SCENE := "res://scenes/combat/practice_drone.tscn"
```

The instantiated root must be `RigidBody3D` with:

- mass exactly `1600`;
- zero gravity;
- continuous collision detection;
- contact monitoring with at least eight contacts;
- one collider;
- `VisualRoot`;
- `DamageState` using 120 shield, 150 hull, no hull repair;
- `CollisionDamageReceiver`;
- `ShieldImpactVisualizer` with radii `Vector3(3.2, 2.4, 3.2)`;
- `PracticeDroneController`;
- `DestructionPulse` visual;
- a deterministic `reset_to_spawn()` that restores shield/hull, visibility, collision, zero velocities, and saved spawn transform.

- [ ] **Step 3: Implement drone intent and tuning types**

Create `src/combat/practice_drone_intent.gd` exactly as defined in the interface block.

Create `src/combat/practice_drone_tuning.gd`:

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

Create `config/combat/practice_drone_tuning.tres` with these exact values.

- [ ] **Step 4: Implement pure drone steering**

`PracticeDroneSteering.compute_into()` must:

1. clear `result` before validation;
2. fail closed for any non-finite input or missing tuning;
3. define `to_player = relative_position.normalized()`;
4. build an orbit tangent from `to_player.cross(Vector3.UP)` and fall back to `to_player.cross(Vector3.RIGHT)` when needed;
5. use a deterministic orbit sign from `sin(elapsed_seconds * 0.65)`;
6. approach outside `preferred_distance + distance_band`;
7. retreat inside `preferred_distance - distance_band`;
8. orbit inside the distance band;
9. add vertical motion `Vector3.UP * sin(elapsed_seconds * 0.85) * vertical_speed`;
10. clamp desired velocity to `maximum_speed`;
11. compute acceleration `(desired_velocity - relative_velocity) * velocity_response`, clamped to `maximum_acceleration`;
12. face the player using `current_forward.cross(to_player)`;
13. compute torque `facing_error * maximum_turn_torque - angular_velocity * angular_damping`, clamped to `maximum_turn_torque`.

No random generator and no direct body access are allowed in this helper.

- [ ] **Step 5: Implement `PracticeDroneController`**

The controller owns one reusable `PracticeDroneIntent`. During active life it:

```gdscript
var relative_position := _target.global_position - _body.global_position
var relative_velocity := _target.linear_velocity - _body.linear_velocity
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

On `DamageState.destroyed` it must:

- begin a `3.0 s` respawn countdown;
- freeze the body;
- set collision layer/mask to zero;
- stop AI force/torque;
- reveal and animate `DestructionPulse` for `0.45 s`;
- hide `VisualRoot` after the first `0.12 s`;
- emit `respawn_started` and `respawn_progress`;
- call `reset_to_spawn()` when countdown reaches zero;
- emit `respawned`.

`reset_to_spawn()` is the only runtime path allowed to assign drone transform and zero velocity. It must restore saved layer/mask, visibility, collision, damage state, timers, and intent.

- [ ] **Step 6: Build the practice-drone scene**

Create `scenes/combat/practice_drone.tscn` with this exact contract:

```text
PracticeDrone (RigidBody3D, mass 1600, gravity 0, CCD, contact monitor)
├── CollisionShape3D (SphereShape3D radius 2.4)
├── VisualRoot (Node3D)
│   ├── Core (SphereMesh, metallic dark body)
│   ├── GuardRing (TorusMesh, emissive cyan)
│   ├── FinTop (BoxMesh)
│   ├── FinBottom (BoxMesh)
│   ├── FinLeft (BoxMesh)
│   └── FinRight (BoxMesh)
├── DamageState (drone damage tuning)
├── CollisionDamageReceiver
├── ShieldImpactVisualizer (instance, radii 3.2/2.4/3.2)
├── DestructionPulse (SphereMesh, hidden)
└── PracticeDroneController (drone tuning)
```

The geometric design is intentional for a training drone, not a placeholder spacecraft. It remains replaceable through `VisualRoot` without changing combat or AI contracts.

- [ ] **Step 7: Run the Task 2 green gate**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: the three new unit suites and practice-drone scene suite pass. Only the full room integration suite may remain failing until Task 3.

- [ ] **Step 8: Create the first consolidated implementation commit**

```powershell
git add src/combat shaders/shield_hex_impact.gdshader scenes/combat config/combat tests/unit/test_collision_damage_math.gd tests/unit/test_shield_impact_math.gd tests/unit/test_practice_drone_steering.gd tests/integration/test_practice_drone_scene.gd tests/test_runner.gd tests/unit/test_damage_state.gd
git commit -m "feat: add reusable combat target systems"
```

Do not push or ask for verification yet.

---

# Task 3: Player, room, combat HUD, and end-to-end loop

**Files:**
- Create `src/ui/combat_hud.gd` and `scenes/ui/combat_hud.tscn`.
- Modify player, room, HUD, controller, and integration tests listed in the file map.

**Interfaces:**

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

- [ ] **Step 1: Write the full combat-sandbox RED**

Create `tests/integration/test_combat_sandbox.gd`. It must load `res://scenes/flight_room/flight_room.tscn` and assert:

1. player has `DamageState`, `CollisionDamageReceiver`, and `ShieldImpactVisualizer`;
2. room has one `PracticeDrone` at `Vector3(0, 20, -180)`;
3. `FlightHud/CombatHud` resolves player state, target state, target controller, and player projectile pool;
4. firing one actual pooled projectile into the drone reduces shield by exactly 15, activates one shield-impact slot, and activates hit confirmation;
5. a wall hit does not activate hit confirmation;
6. enough actual damage destroys the drone, disables its collision, and enters respawn;
7. stepping the drone controller for 3.0 seconds restores full 120 shield and 150 hull at spawn;
8. high-speed collision damage reduces shield before hull;
9. `FlightRoomController.reset_player()` restores player damage state and resets drone;
10. player destruction disables flight/fire briefly and then restores the player without an explosion requirement.

- [ ] **Step 2: Extend existing scene/projectile RED coverage**

Update:

- `tests/integration/test_player_scene.gd` to lock player damage/shield nodes and tuning;
- `tests/integration/test_flight_room_scene.gd` to lock the drone and combat HUD paths;
- `tests/integration/test_pulse_projectile.gd` to assert shield visual receives the exact `DamageResult.impact_point` through the damage signal path without modifying projectile code.

- [ ] **Step 3: Add player combat nodes**

Modify `scenes/player/player_interceptor.tscn` by adding:

```text
DamageState (player damage tuning)
CollisionDamageReceiver (body .., state ../DamageState)
ShieldImpactVisualizer (instance, state ../DamageState, radii 8.2/3.0/7.2)
```

Set player `contact_monitor = true` and `max_contacts_reported = 8`. Do not change mass, collider, collision layer/mask, or any flight/combat child already present.

- [ ] **Step 4: Build the combat HUD scene**

Create `scenes/ui/combat_hud.tscn`:

```text
CombatHud (Control, full rect, script)
├── PlayerPanel (PanelContainer, bottom-left)
│   └── VBox
│       ├── TitleLabel: PLAYER
│       ├── ShieldLabel
│       ├── ShieldBar (ProgressBar, 0..100)
│       ├── HullLabel
│       └── HullBar (ProgressBar, 0..100)
├── TargetPanel (PanelContainer, top-center)
│   └── VBox
│       ├── TitleLabel: PRACTICE DRONE
│       ├── StatusLabel
│       ├── ShieldLabel
│       ├── ShieldBar (ProgressBar, 0..100)
│       ├── HullLabel
│       └── HullBar (ProgressBar, 0..100)
└── HitMarker (Control, center, hidden)
    ├── TopLeft
    ├── TopRight
    ├── BottomLeft
    └── BottomRight
```

The panel style remains restrained: dark translucent backgrounds, cyan shield, warm hull, no large arcade banners.

- [ ] **Step 5: Implement `CombatHud`**

Use these exact scene-relative paths when the combat HUD is instanced under `FlightHud`:

```text
player_damage_state_path = ../../PlayerInterceptor/DamageState
target_damage_state_path = ../../PracticeDrone/DamageState
target_controller_path = ../../PracticeDrone/PracticeDroneController
projectile_pool_path = ../../PlayerInterceptor/PulseProjectilePool
```

At `_ready()`:

- resolve all four dependencies;
- connect both `state_changed` signals;
- connect target `respawn_started`, `respawn_progress`, and `respawned`;
- connect player pool `projectile_resolved`;
- initialize all labels and bars.

On projectile resolution:

```gdscript
if (
    hit_damageable
    and result != null
    and result.applied_amount > 0.0
):
    _hit_flash_remaining = 0.12
```

Wall hits and ignored packets do not flash. `_process()` decays the marker alpha and updates respawn countdown text. Use percentage values, not raw maximum assumptions.

- [ ] **Step 6: Integrate combat HUD into existing HUD**

Instance `CombatHud` as `FlightHud/CombatHud` in `scenes/ui/flight_hud.tscn`. Do not move or rewrite the current telemetry panel, nose reticle, or velocity marker.

- [ ] **Step 7: Integrate the drone and player lifecycle into the room**

Instance `PracticeDrone` in `scenes/flight_room/flight_room.tscn` at:

```text
position = Vector3(0, 20, -180)
```

Modify `FlightRoomController` to export/resolve:

```gdscript
@export var player_damage_state_path: NodePath
@export var practice_drone_controller_path: NodePath
```

At `_ready()`:

- resolve player `DamageState`;
- resolve `PracticeDroneController`;
- call `practice_drone.set_target(_body)`;
- connect player `destroyed` to `_on_player_destroyed`.

Add:

```gdscript
var _player_respawn_remaining := 0.0
const PLAYER_RESPAWN_DELAY := 1.25
```

On player destruction:

```gdscript
_player_respawn_remaining = PLAYER_RESPAWN_DELAY
_body.freeze = true
_controller.set_physics_process(false)
_primary_fire_controller.set_firing_enabled(false)
_projectile_pool.clear_all()
```

During `_physics_process(delta)`, count down only while the tree is unpaused. At zero, call `reset_player()`.

Extend `reset_player()` to:

- call player `DamageState.reset_full()`;
- call player collision receiver `reset_runtime_state()`;
- reset player shield visuals;
- call `practice_drone.reset_to_spawn()`;
- re-enable controller physics and firing;
- preserve all existing transform, velocity, thermal, pool, pause, and mouse behavior.

- [ ] **Step 8: Run the complete 44-suite gate**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/verify_inertial_velocity.gd
```

Required:

```text
PASS: 44 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
```

- [ ] **Step 9: Create the second consolidated implementation commit**

```powershell
git add scenes/player/player_interceptor.tscn scenes/flight_room/flight_room.tscn scenes/ui/flight_hud.tscn scenes/ui/combat_hud.tscn src/flight_room/flight_room_controller.gd src/ui/combat_hud.gd tests/integration/test_player_scene.gd tests/integration/test_flight_room_scene.gd tests/integration/test_pulse_projectile.gd tests/integration/test_combat_sandbox.gd
git commit -m "feat: integrate combat sandbox loop"
```

Perform one static scope review. No scene or code outside the declared file map may change.

---

# Task 4: Authoritative verification, manual acceptance, and closure

**Files:**
- Modify `README.md`.
- Modify `docs/superpowers/plans/deferred-milestones.md`.
- Modify implementation only when fresh verifier evidence identifies a concrete defect.

- [ ] **Step 1: Update documentation to verification-pending**

Add to `README.md`:

```text
- one deterministic force-driven practice drone;
- reusable projectile/collision shield-and-hull damage;
- pooled ship-aligned ellipsoid shield impacts with procedural hex patterns;
- drone destruction and three-second respawn;
- player and target shield/hull HUD with damage-confirmed hit marker.
```

Change runner target to:

```text
PASS: 44 suites
```

Record the combat sandbox as implementation-complete/verification-pending in `deferred-milestones.md`. Preserve historical AI/Smart Stabilize text instead of deleting it.

- [ ] **Step 2: Request one complete Windows verifier**

```powershell
git fetch origin
git rebase origin/agent/playable-flight-room
powershell -ExecutionPolicy Bypass -File .\tools\verify\verify.ps1
```

Required output:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 44 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
==> Boot main scene briefly
```

No parser, path, orphan-node, retained-resource, shader compile, runtime, or boot errors are acceptable.

- [ ] **Step 3: Debug only from the first fresh failure**

Use `superpowers:systematic-debugging`. Fix the originating contract only. Do not remove shield visuals, lower test strictness, bypass real projectile collisions, assign active drone velocity directly, or weaken existing flight verification merely to pass.

- [ ] **Step 4: Run one manual combat acceptance session**

```powershell
godot --path .
```

Verify:

1. Practice drone spawns approximately 180 m ahead and visibly moves.
2. Drone approaches when far, retreats when too close, and performs readable orbit/evasion inside its distance band.
3. Drone movement remains smooth and force-driven rather than teleporting.
4. Pulse projectile hits trigger localized hexagonal shield impacts at the hit side.
5. Shield effect is invisible at rest and readable without becoming a permanent bright bubble.
6. Shield bar loses exactly 15 per ordinary projectile while shield remains.
7. Shield regeneration waits through its delay and then refills slowly.
8. Shield break triggers a short full-shell flash; later hits damage hull.
9. Destroyed drone gives clear disappearance/pulse feedback and respawns after three seconds at full shield/hull.
10. Wall misses do not show hit confirmation.
11. High-speed collision damages shield before hull on player and drone.
12. Player destruction disables control/fire briefly and resets without an explosion requirement.
13. `R` restores player and drone state.
14. Assisted, AI Assisted, Inertial, Smart Stabilize, boost, firing, exact muzzles, thrusters, cameras, pause, settings, asteroid collision, and zero-drift behavior remain functional.

- [ ] **Step 5: Close the milestone after both gates pass**

Update status to:

```text
VERIFIED — schema-five and matrix contracts passed, PASS: 44 suites, exact zero inertial drift, clean main-scene boot, and Windows manual combat acceptance passed.
```

- [ ] **Step 6: Create one closure commit**

```powershell
git add README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "docs: verify combat sandbox v1"
git status --short
git diff --stat HEAD~3..HEAD
```

Expected total scope: reusable collision damage, shield impact visual, practice drone, player/room integration, combat HUD, focused tests, and documentation only. No raw Blender asset, camera implementation, flight tuning, projectile cadence/speed/damage, muzzle, thruster matrix, workflow, or GitHub Actions changes.

---

## Completion rule

Do not call Combat Sandbox v1 complete until all of the following are true:

```text
PASS: 44 suites
exact zero inertial speed drift
exact zero inertial direction drift
clean main-scene boot
manual projectile hit/shield break/hull destruction/respawn loop passed
manual collision damage passed
manual player reset/destruction recovery passed
```
