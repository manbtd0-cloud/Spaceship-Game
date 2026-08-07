# Tactical Enemy Dogfight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the production practice target with one physically simulated tactical enemy fighter that maneuvers intelligently, predicts pulse-cannon intercepts, returns fair fire, takes existing shield/hull damage, respawns, and forms a repeatable one-on-one dogfight.

**Architecture:** Keep the verified player controller and combat pipeline unchanged. Add two pure AI/math boundaries (`ProjectileInterceptSolver` and `TacticalDogfightSolver`), a dedicated `EnemyFighterController` that converts tactical intent into bounded rigid-body forces/torques, and a separate `EnemyWeaponController` that gates existing pooled pulse projectiles by intercept validity, line of sight, range, cone, and cadence. Reuse `DamageState`, collision damage, shield impacts, `PulseProjectile`, and `PulseProjectilePool`; replace only the production room's `PracticeDrone` instance, not its source files.

**Tech Stack:** Godot 4.7.1, typed GDScript, RigidBody3D physics, existing dependency-free `TestCase` harness, `tools/verify/verify.ps1` / `tools/verify/verify.sh`.

## Global Constraints

- Target branch: `agent/playable-flight-room`.
- Baseline before implementation: `PASS: 44 suites` plus inertial velocity-preservation verification.
- Exactly one hostile fighter is active at a time in the production flight room.
- Active enemy movement uses `RigidBody3D.apply_central_force()` and `apply_torque()` only.
- Never directly assign enemy transform, `linear_velocity`, or `angular_velocity` during live combat; those writes are permitted only while frozen during explicit reset/respawn.
- Existing player mass, thrust/torque authority, speed envelopes, cameras, firing cadence, projectile speed/damage, exact muzzles, thruster mapping, AI Assisted, Smart Stabilize, and Inertial zero-drift behavior remain unchanged.
- Existing pulse projectile speed remains **900 m/s** and normal damage remains **15**.
- Enemy aiming is predictive but not omniscient: no player-input reading, no hitscan, no homing, no projectile steering, no orientation snapping.
- Enemy fire requires a valid intercept, legal range, legal cone, clear line of sight, cadence availability, valid muzzle/pool, and active combat state.
- Threat-aware evasion derives from observable geometry and recent hostile projectile activity; it must not dodge individual projectiles using future-hit knowledge.
- Enemy tuning is independent from player tuning and must bound all force, torque, speed, tactical, and weapon behavior.
- Reuse the canonical fighter runtime model at `assets/runtime/ships/player/small_sci_fi_fighter.glb`; do not modify raw model sources.
- Do not add multiple enemies, fleets, missiles, heavy plasma, beams, lock-on, radar, final enemy art, elaborate explosions, asteroid destruction, audio overhaul, or GitHub Actions in this milestone.
- Keep GitHub pushes/commits coarse: one meaningful commit per task at most; do not push micro-fixes unless necessary for recovery.

---

## File map

### New pure AI/math files

- `src/combat/projectile_intercept_result.gd` — typed immutable-style result container for predictive intercept math.
- `src/combat/projectile_intercept_solver.gd` — pure quadratic intercept solver using shooter-relative target motion.
- `src/combat/enemy_dogfight_state.gd` — tactical state enum.
- `src/combat/tactical_dogfight_intent.gd` — typed output from tactical solver.
- `src/combat/tactical_dogfight_solver.gd` — pure state/steering decision logic.
- `src/combat/enemy_fighter_tuning.gd` — all enemy flight, tactical, weapon, and respawn tuning.
- `src/combat/enemy_fire_cadence.gd` — configurable alternating twin-muzzle cadence.

### New runtime files

- `src/combat/enemy_fighter_controller.gd` — target acquisition, tactical state, force/torque application, destruction/respawn lifecycle.
- `src/combat/enemy_weapon_controller.gd` — predictive fire control, LOS/range/cone/cadence gates, projectile spawning.
- `src/combat/enemy_fighter_visual_controller.gd` — lightweight hostile material overlay on the reused runtime fighter model.
- `config/combat/enemy_fighter_tuning.tres` — explicit enemy physical/tactical/weapon numbers.
- `config/combat/enemy_fighter_damage_tuning.tres` — enemy shield/hull tuning.
- `scenes/combat/enemy_fighter.tscn` — one hostile RigidBody3D fighter with combat components.

### Modified integration files

- `scenes/flight_room/flight_room.tscn` — replace production `PracticeDrone` instance with `EnemyFighter`.
- `src/flight_room/flight_room_controller.gd` — target/reset wiring for enemy fighter.
- `scenes/ui/combat_hud.tscn` — target paths/title point to enemy fighter.
- `src/ui/combat_hud.gd` — target lifecycle type changes from practice drone to enemy fighter.
- `tests/test_runner.gd` — register new suites only after each suite file exists.
- `tests/integration/test_combat_sandbox.gd` — update production-room assumptions from practice drone to enemy fighter while preserving player combat regression checks.
- `README.md` and `docs/superpowers/plans/deferred-milestones.md` — closure only after fresh full verification passes.

### New tests

- `tests/unit/test_projectile_intercept_solver.gd`
- `tests/unit/test_tactical_dogfight_solver.gd`
- `tests/unit/test_enemy_fire_cadence.gd`
- `tests/integration/test_enemy_fighter_scene.gd`
- `tests/integration/test_enemy_weapon_controller.gd`
- `tests/integration/test_tactical_dogfight_sandbox.gd`

Final runner target: **50 suites**.

---

### Task 1: Predictive intercept math

**Files:**
- Create: `src/combat/projectile_intercept_result.gd`
- Create: `src/combat/projectile_intercept_solver.gd`
- Create: `tests/unit/test_projectile_intercept_solver.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: shooter position/velocity, target position/velocity, projectile speed.
- Produces:
  - `ProjectileInterceptResult.valid: bool`
  - `ProjectileInterceptResult.time_seconds: float`
  - `ProjectileInterceptResult.intercept_point_world: Vector3`
  - `ProjectileInterceptResult.fire_direction_world: Vector3`
  - `ProjectileInterceptSolver.solve(shooter_position: Vector3, shooter_velocity: Vector3, target_position: Vector3, target_velocity: Vector3, projectile_speed: float) -> ProjectileInterceptResult`

- [ ] **Step 1: Write the RED intercept suite**

Create `tests/unit/test_projectile_intercept_solver.gd` with focused assertions for:

```gdscript
extends TestCase

func run() -> void:
    _stationary_target_solution()
    _lateral_moving_target_requires_lead()
    _shooter_velocity_is_accounted_for()
    _impossible_intercept_is_rejected()
    _invalid_inputs_fail_closed()

func _stationary_target_solution() -> void:
    var result := ProjectileInterceptSolver.solve(
        Vector3.ZERO,
        Vector3.ZERO,
        Vector3(0, 0, -900),
        Vector3.ZERO,
        900.0
    )
    expect_true(result.valid, "stationary target should have a solution")
    expect_near(result.time_seconds, 1.0, 0.0001, "900 m at 900 m/s should take one second")
    expect_vector_near(result.fire_direction_world, Vector3(0, 0, -1), 0.0001, "stationary lead should be straight ahead")

func _lateral_moving_target_requires_lead() -> void:
    var result := ProjectileInterceptSolver.solve(
        Vector3.ZERO,
        Vector3.ZERO,
        Vector3(0, 0, -450),
        Vector3(90, 0, 0),
        900.0
    )
    expect_true(result.valid, "moving target should be interceptable")
    expect_true(result.fire_direction_world.x > 0.0, "lead must point ahead of lateral target motion")
    expect_true(result.time_seconds > 0.0, "intercept must be in the future")

func _shooter_velocity_is_accounted_for() -> void:
    var stationary_shooter := ProjectileInterceptSolver.solve(
        Vector3.ZERO, Vector3.ZERO,
        Vector3(0, 0, -900), Vector3(100, 0, 0), 900.0
    )
    var matching_velocity := ProjectileInterceptSolver.solve(
        Vector3.ZERO, Vector3(100, 0, 0),
        Vector3(0, 0, -900), Vector3(100, 0, 0), 900.0
    )
    expect_true(stationary_shooter.valid and matching_velocity.valid, "both cases should solve")
    expect_true(absf(matching_velocity.fire_direction_world.x) < absf(stationary_shooter.fire_direction_world.x), "shared lateral velocity should reduce required lateral lead")

func _impossible_intercept_is_rejected() -> void:
    var result := ProjectileInterceptSolver.solve(
        Vector3.ZERO,
        Vector3.ZERO,
        Vector3(0, 0, -100),
        Vector3(0, 0, -1000),
        900.0
    )
    expect_false(result.valid, "faster receding target should be rejected")

func _invalid_inputs_fail_closed() -> void:
    expect_false(ProjectileInterceptSolver.solve(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, 0.0).valid, "non-positive projectile speed must fail")
    expect_false(ProjectileInterceptSolver.solve(Vector3(INF, 0, 0), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 900.0).valid, "non-finite inputs must fail")
```

If the existing `TestCase` helper names differ, use the exact available helpers while preserving these assertions.

- [ ] **Step 2: Run the suite and confirm RED**

Run:

```powershell
& 'C:\Tools\Godot\godot.exe' --headless --path . --script res://tests/test_runner.gd
```

Expected before implementation: failure to load/resolve `ProjectileInterceptSolver` or the new result type. Do not register the suite in `tests/test_runner.gd` until the file itself exists.

- [ ] **Step 3: Implement typed intercept result**

Create `src/combat/projectile_intercept_result.gd`:

```gdscript
class_name ProjectileInterceptResult
extends RefCounted

var valid := false
var time_seconds := 0.0
var intercept_point_world := Vector3.ZERO
var fire_direction_world := Vector3.ZERO

static func invalid() -> ProjectileInterceptResult:
    return ProjectileInterceptResult.new()

static func solved(
    time_value: float,
    point: Vector3,
    direction: Vector3
) -> ProjectileInterceptResult:
    var result := ProjectileInterceptResult.new()
    result.valid = true
    result.time_seconds = time_value
    result.intercept_point_world = point
    result.fire_direction_world = direction
    return result
```

- [ ] **Step 4: Implement the quadratic solver**

Create `src/combat/projectile_intercept_solver.gd` using the physically correct relative-motion equation for projectiles whose world velocity is `shooter_velocity + fire_direction * projectile_speed`:

```gdscript
class_name ProjectileInterceptSolver
extends RefCounted

const EPSILON := 0.000001

static func solve(
    shooter_position: Vector3,
    shooter_velocity: Vector3,
    target_position: Vector3,
    target_velocity: Vector3,
    projectile_speed: float
) -> ProjectileInterceptResult:
    if (
        not shooter_position.is_finite()
        or not shooter_velocity.is_finite()
        or not target_position.is_finite()
        or not target_velocity.is_finite()
        or not is_finite(projectile_speed)
        or projectile_speed <= EPSILON
    ):
        return ProjectileInterceptResult.invalid()

    var relative_position := target_position - shooter_position
    var relative_velocity := target_velocity - shooter_velocity
    var a := relative_velocity.dot(relative_velocity) - projectile_speed * projectile_speed
    var b := 2.0 * relative_position.dot(relative_velocity)
    var c := relative_position.dot(relative_position)
    var time_seconds := _smallest_positive_root(a, b, c)
    if time_seconds <= EPSILON or not is_finite(time_seconds):
        return ProjectileInterceptResult.invalid()

    var intercept_point := target_position + target_velocity * time_seconds
    var relative_intercept := (
        intercept_point - shooter_position - shooter_velocity * time_seconds
    )
    if not relative_intercept.is_finite() or relative_intercept.length_squared() <= EPSILON:
        return ProjectileInterceptResult.invalid()

    return ProjectileInterceptResult.solved(
        time_seconds,
        intercept_point,
        relative_intercept.normalized()
    )

static func _smallest_positive_root(a: float, b: float, c: float) -> float:
    if absf(a) <= EPSILON:
        if absf(b) <= EPSILON:
            return -1.0
        var linear_root := -c / b
        return linear_root if linear_root > EPSILON else -1.0

    var discriminant := b * b - 4.0 * a * c
    if discriminant < 0.0 or not is_finite(discriminant):
        return -1.0
    var root := sqrt(maxf(discriminant, 0.0))
    var t1 := (-b - root) / (2.0 * a)
    var t2 := (-b + root) / (2.0 * a)
    var best := INF
    if t1 > EPSILON:
        best = t1
    if t2 > EPSILON:
        best = minf(best, t2)
    return best if is_finite(best) else -1.0
```

- [ ] **Step 5: Register and run the new suite**

Add `res://tests/unit/test_projectile_intercept_solver.gd` to `TEST_SCRIPTS` after shield/collision combat math tests.

Run the headless test runner.

Expected: `PASS: 45 suites`.

- [ ] **Step 6: Commit Task 1**

```bash
git add src/combat/projectile_intercept_result.gd src/combat/projectile_intercept_solver.gd tests/unit/test_projectile_intercept_solver.gd tests/test_runner.gd
git commit -m "feat: add predictive projectile intercept solver"
```

---

### Task 2: Tactical dogfight state and pure steering solver

**Files:**
- Create: `src/combat/enemy_dogfight_state.gd`
- Create: `src/combat/tactical_dogfight_intent.gd`
- Create: `src/combat/enemy_fighter_tuning.gd`
- Create: `src/combat/tactical_dogfight_solver.gd`
- Create: `config/combat/enemy_fighter_tuning.tres`
- Create: `tests/unit/test_tactical_dogfight_solver.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `EnemyDogfightState.Value` enum values: `ACQUIRE`, `ATTACK`, `RANGE_CONTROL`, `DISENGAGE`, `REENTRY`, `EVADE`.
- Produces `TacticalDogfightIntent.state`, `.desired_velocity_world`, `.desired_forward_world`, `.evasion_priority`.
- Produces `TacticalDogfightSolver.compute(...) -> TacticalDogfightIntent`.
- `EnemyFighterTuning` becomes the single source for physical, tactical, weapon, and respawn values consumed by Tasks 3–5.

- [ ] **Step 1: Write the RED tactical suite**

Create `tests/unit/test_tactical_dogfight_solver.gd` covering these deterministic cases:

```gdscript
extends TestCase

var tuning := EnemyFighterTuning.new()

func run() -> void:
    _far_target_acquires_and_closes()
    _preferred_range_attacks_with_valid_aim_direction()
    _close_high_closure_triggers_range_control_or_disengage()
    _disengage_transitions_to_reentry_after_separation()
    _dangerous_player_geometry_triggers_evasion()
    _evasion_is_bounded_and_not_projectile_psychic()
    _outputs_fail_closed_on_nonfinite_observation()
```

Use concrete fixtures:

- far: target at `(0, 0, -700)`, low closure → `ACQUIRE`, desired velocity has negative Z component;
- attack band: target around 260 m → `ATTACK`, desired forward follows supplied valid lead direction;
- overshoot: target 80 m ahead with relative closing speed > configured threshold → `RANGE_CONTROL` or `DISENGAGE`, desired velocity must not continue maximum closure;
- re-entry: current state `DISENGAGE`, state time beyond minimum, separation above re-entry threshold → `REENTRY`;
- threat: player forward axis points within configured threat cone at enemy, target inside threat range, or hostile fire pressure > 0 → `EVADE`;
- no per-projectile inputs exist in the solver signature;
- all returned vectors are finite and speed is `<= tuning.maximum_speed`.

- [ ] **Step 2: Run and confirm RED**

Expected: missing tactical types/solver.

- [ ] **Step 3: Create the tactical types**

`src/combat/enemy_dogfight_state.gd`:

```gdscript
class_name EnemyDogfightState
extends RefCounted

enum Value {
    ACQUIRE,
    ATTACK,
    RANGE_CONTROL,
    DISENGAGE,
    REENTRY,
    EVADE,
}
```

`src/combat/tactical_dogfight_intent.gd`:

```gdscript
class_name TacticalDogfightIntent
extends RefCounted

var state: EnemyDogfightState.Value = EnemyDogfightState.Value.ACQUIRE
var desired_velocity_world := Vector3.ZERO
var desired_forward_world := Vector3(0, 0, -1)
var evasion_priority := false

func duplicate_intent() -> TacticalDogfightIntent:
    var copy := TacticalDogfightIntent.new()
    copy.state = state
    copy.desired_velocity_world = desired_velocity_world
    copy.desired_forward_world = desired_forward_world
    copy.evasion_priority = evasion_priority
    return copy
```

- [ ] **Step 4: Implement one explicit tuning resource**

Create `src/combat/enemy_fighter_tuning.gd` with typed exports and these initial values:

```gdscript
class_name EnemyFighterTuning
extends Resource

@export var mass: float = 6500.0
@export var forward_force: float = 130000.0
@export var reverse_force: float = 95000.0
@export var strafe_force: float = 110000.0
@export var vertical_force: float = 110000.0
@export var pitch_torque: float = 180000.0
@export var yaw_torque: float = 210000.0
@export var roll_torque: float = 190000.0
@export var normal_speed_soft_start: float = 120.0
@export var normal_speed_limit: float = 150.0
@export var pitch_angular_soft_start_degrees: float = 72.0
@export var pitch_angular_limit_degrees: float = 95.0
@export var yaw_angular_soft_start_degrees: float = 72.0
@export var yaw_angular_limit_degrees: float = 95.0
@export var roll_angular_soft_start_degrees: float = 105.0
@export var roll_angular_limit_degrees: float = 140.0
@export var velocity_response: float = 1.7
@export var attitude_response: float = 5.0
@export var angular_damping: float = 2.2
@export var preferred_range: float = 280.0
@export var range_band: float = 70.0
@export var close_range: float = 125.0
@export var reentry_range: float = 460.0
@export var disengage_minimum_time: float = 1.25
@export var overshoot_closure_speed: float = 95.0
@export var attack_speed: float = 120.0
@export var range_control_speed: float = 80.0
@export var disengage_speed: float = 135.0
@export var evasion_speed: float = 125.0
@export var evasion_duration: float = 1.1
@export var evasion_cooldown: float = 1.8
@export var threat_range: float = 520.0
@export var threat_cone_degrees: float = 10.0
@export var weapon_range: float = 650.0
@export var firing_cone_degrees: float = 4.5
@export var shots_per_second: float = 3.0
@export var respawn_delay: float = 3.0
```

Create `config/combat/enemy_fighter_tuning.tres` using these values explicitly. The `.tres` is authoritative for production tuning; defaults keep unit tests self-contained.

- [ ] **Step 5: Implement `TacticalDogfightSolver.compute`**

Use this exact signature so later tasks do not invent a competing API:

```gdscript
static func compute(
    relative_position_world: Vector3,
    enemy_velocity_world: Vector3,
    player_velocity_world: Vector3,
    enemy_forward_world: Vector3,
    enemy_up_world: Vector3,
    player_forward_world: Vector3,
    preferred_aim_direction_world: Vector3,
    hostile_fire_pressure: float,
    current_state: EnemyDogfightState.Value,
    state_time: float,
    evasion_cooldown_remaining: float,
    tuning: EnemyFighterTuning
) -> TacticalDogfightIntent
```

Implementation rules:

1. Fail closed to zero desired velocity/current forward on non-finite input or missing tuning.
2. Compute distance and line-of-sight from `relative_position_world`.
3. Compute closure using `(enemy_velocity_world - player_velocity_world).dot(line_of_sight)` with sign interpreted and tested consistently.
4. Threat geometry is true only when player forward points toward the enemy within `threat_cone_degrees` and distance is inside `threat_range`; hostile fire pressure may also trigger threat.
5. `EVADE` takes priority only when threat is true and cooldown is zero, or while the existing evade state is still inside `evasion_duration`.
6. High closure inside `close_range` transitions to `RANGE_CONTROL`/`DISENGAGE` before pass-through.
7. `DISENGAGE` persists for at least `disengage_minimum_time`; once separation reaches `reentry_range`, transition to `REENTRY`.
8. Far targets use `ACQUIRE`/`REENTRY` to close on an offset line rather than pure nose chase.
9. Targets inside the preferred band use `ATTACK`.
10. Deterministic lateral/vertical offset basis comes from line-of-sight crossed with enemy up; when degenerate, fall back to an orthogonal axis. No RNG.
11. Clamp every desired velocity to the state-specific speed and never above `maximum_speed`.
12. Desired forward uses `preferred_aim_direction_world` when finite/non-degenerate; otherwise line-of-sight.

- [ ] **Step 6: Register and run the tactical suite**

Expected: `PASS: 46 suites`.

- [ ] **Step 7: Commit Task 2**

```bash
git add src/combat/enemy_dogfight_state.gd src/combat/tactical_dogfight_intent.gd src/combat/enemy_fighter_tuning.gd src/combat/tactical_dogfight_solver.gd config/combat/enemy_fighter_tuning.tres tests/unit/test_tactical_dogfight_solver.gd tests/test_runner.gd
git commit -m "feat: add tactical dogfight steering solver"
```

---

### Task 3: Physical enemy fighter scene and lifecycle

**Files:**
- Create: `src/combat/enemy_fighter_controller.gd`
- Create: `src/combat/enemy_fighter_visual_controller.gd`
- Create: `config/combat/enemy_fighter_damage_tuning.tres`
- Create: `scenes/combat/enemy_fighter.tscn`
- Create: `tests/integration/test_enemy_fighter_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes Task 1 intercept result for preferred aim direction and Task 2 tactical solver/tuning.
- Produces:
  - signals `respawn_started(duration: float)`, `respawn_progress(seconds_remaining: float)`, `respawned`;
  - `set_target(body: RigidBody3D) -> void`;
  - `set_hostile_projectile_pool(pool: PulseProjectilePool) -> void`;
  - `reset_to_spawn() -> void`;
  - `is_respawning() -> bool`;
  - `get_respawn_remaining() -> float`;
  - `get_tactical_state() -> EnemyDogfightState.Value`;
  - `get_last_intent() -> TacticalDogfightIntent`;
  - `get_damage_state() -> DamageState`.

- [ ] **Step 1: Write the RED enemy-scene integration suite**

Create `tests/integration/test_enemy_fighter_scene.gd` asserting:

```gdscript
extends TestCase

func run() -> void:
    _scene_has_required_combat_components()
    _controller_applies_bounded_physical_authority()
    _live_step_does_not_warp_transform_or_assign_velocity()
    _destruction_disables_live_combat_and_respawn_restores_state()
    _hostile_visual_overlay_is_applied_without_modifying_source_asset()
```

Required scene assertions:

- root is `RigidBody3D` named `EnemyFighter`;
- gravity 0, damping 0, continuous collision enabled, contact monitoring enabled;
- canonical fighter model exists below `VisualRoot`;
- `DamageState`, `CollisionDamageReceiver`, `ShieldImpactVisualizer`, `PulseProjectilePool`, `EnemyFighterController`, `EnemyWeaponController` placeholder path (controller may not yet be scripted until Task 4), and hostile visual controller nodes exist;
- damage state uses enemy tuning;
- controller tuning is `EnemyFighterTuning`;
- root mass equals tuning mass after initialization.

For force authority, use Godot's testable last-output getters rather than trying to infer one physics tick from position. Add controller getters `get_last_force_world()` and `get_last_torque_world()` and assert finite magnitude never exceeds the vector composed from configured per-axis maxima.

For the anti-warp contract, capture transform/velocities before `step_for_test(delta)`, call the controller in a fixture where physics integration is not advanced, and assert the controller did not directly overwrite transform/velocity properties. Force/torque requests may change internal accumulated force but not immediate properties.

- [ ] **Step 2: Run and confirm RED**

Expected: enemy scene/controller missing.

- [ ] **Step 3: Create enemy damage tuning**

Create `config/combat/enemy_fighter_damage_tuning.tres` using the existing `DamageTuning` script with:

```text
maximum_shield = 150
maximum_hull = 180
shield_regeneration_delay = 8 s
shield_regeneration_rate = 3/s
shield_reboot_delay = 18 s
hull_repair_enabled = false
```

This keeps the first fighter durable but still killable with the existing 15-damage pulse rounds.

- [ ] **Step 4: Implement `EnemyFighterController`**

Follow the existing `PracticeDroneController` lifecycle style, but keep tactical decision-making external.

Required exported paths:

```gdscript
@export var body_path: NodePath = NodePath("..")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var collision_receiver_path: NodePath = NodePath("../CollisionDamageReceiver")
@export var shield_visualizer_path: NodePath = NodePath("../ShieldImpactVisualizer")
@export var visual_root_path: NodePath = NodePath("../VisualRoot")
@export var destruction_pulse_path: NodePath = NodePath("../DestructionPulse")
@export var weapon_controller_path: NodePath = NodePath("../EnemyWeaponController")
@export var tuning: EnemyFighterTuning
```

Runtime flow:

```gdscript
func step_for_test(delta: float) -> void:
    initialize()
    if _respawn_remaining > 0.0:
        _advance_respawn(maxf(delta, 0.0))
        return
    if _damage_state == null or _damage_state.is_destroyed():
        _clear_outputs()
        return
    if _target == null or not is_instance_valid(_target):
        _clear_outputs()
        return

    var intercept := ProjectileInterceptSolver.solve(
        _body.global_position,
        _body.linear_velocity,
        _target.global_position,
        _target.linear_velocity,
        PulseProjectilePool compatible speed constant
    )
    var aim_direction := (
        intercept.fire_direction_world
        if intercept.valid
        else (_target.global_position - _body.global_position).normalized()
    )
    var intent := TacticalDogfightSolver.compute(...)
    _apply_intent_through_real_force_and_torque(intent, delta)
```

Do **not** introduce a second projectile-speed literal. Expose `PulseProjectile.PROJECTILE_SPEED` or a shared combat constant only if the existing projectile class does not already expose 900 m/s; if changing constant visibility is necessary, do not change its numeric value.

Force conversion contract:

1. Transform `(desired_velocity_world - current_velocity_world)` into local space.
2. Multiply by `mass * velocity_response` to create requested local force.
3. Clamp X to `±strafe_force`, Y to `±vertical_force`, local negative Z to `forward_force`, positive Z to `reverse_force`.
4. Apply existing `FlightSpeedEnvelope.apply_to_force()` with enemy soft-start/limit.
5. Convert back to world and call `apply_central_force()`.

Torque contract:

1. Transform desired forward into local space.
2. Compute pitch/yaw angular error from local desired direction.
3. Add angular damping against local angular velocity.
4. Clamp X/Y/Z by enemy pitch/yaw/roll torque.
5. Pass requested local torque through `FlightAngularEnvelope.apply_to_torque()` with enemy angular soft/limits.
6. Convert to world and call `apply_torque()`.
7. No live transform or velocity writes.

Track `_state_time` and `_evasion_cooldown_remaining`; reset state time on tactical-state changes. Use the player projectile pool only as a coarse observable `hostile_fire_pressure = 1.0 if pool.get_active_count() > 0 else 0.0`. Never inspect projectile future collision paths.

Lifecycle mirrors the already verified practice drone:

- hull destruction freezes body, disables collisions, clears force/torque outputs, disables weapon controller if available, starts destruction pulse, and starts respawn timer;
- after `tuning.respawn_delay`, reset transform/velocity **while frozen**, restore collisions/damage/shield visual, clear tactical state/cooldown, reset weapon runtime state, then unfreeze;
- room reset calls the same `reset_to_spawn()` path.

- [ ] **Step 5: Implement lightweight hostile visual treatment**

Create `src/combat/enemy_fighter_visual_controller.gd` that resolves `VisualRoot/SmallSciFiFighter`, creates one shared `StandardMaterial3D` overlay in memory, and assigns `material_overlay` recursively to child `MeshInstance3D` nodes.

Use a restrained hostile tint:

```gdscript
overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
overlay.albedo_color = Color(0.45, 0.035, 0.025, 0.16)
overlay.emission_enabled = true
overlay.emission = Color(1.0, 0.06, 0.025, 1.0)
overlay.emission_energy_multiplier = 0.65
```

Do not edit or duplicate the GLB.

- [ ] **Step 6: Build `scenes/combat/enemy_fighter.tscn`**

Required root contract:

```text
EnemyFighter (RigidBody3D)
├── CollisionShape3D          # BoxShape3D size Vector3(14, 3.8, 12.2)
├── VisualRoot
│   └── SmallSciFiFighter    # instance existing GLB
├── DamageState
├── CollisionDamageReceiver
├── ShieldImpactVisualizer   # ellipsoid Vector3(8.2, 3.0, 7.2), hostile/red-tinted shield
├── PulseProjectilePool      # top_level = true
├── EnemyWeaponController    # node present; script attached in Task 4
├── EnemyFighterController
├── EnemyFighterVisualController
└── DestructionPulse
```

Rigid-body values:

```text
mass = 6500
 gravity_scale = 0
 linear_damp = 0
 angular_damp = 0
 continuous_cd = true
 contact_monitor = true
 max_contacts_reported = 8
 can_sleep = false
 collision_layer = 1
 collision_mask = 1
```

The fighter controller is allowed to re-assert `body.mass = tuning.mass` at initialization so scene/resource drift is caught by tests.

- [ ] **Step 7: Register and run the scene suite**

Expected: `PASS: 47 suites`.

- [ ] **Step 8: Commit Task 3**

```bash
git add src/combat/enemy_fighter_controller.gd src/combat/enemy_fighter_visual_controller.gd config/combat/enemy_fighter_damage_tuning.tres scenes/combat/enemy_fighter.tscn tests/integration/test_enemy_fighter_scene.gd tests/test_runner.gd
git commit -m "feat: add physical tactical enemy fighter"
```

---

### Task 4: Fair predictive enemy pulse-cannon fire

**Files:**
- Create: `src/combat/enemy_fire_cadence.gd`
- Create: `src/combat/enemy_weapon_controller.gd`
- Create: `tests/unit/test_enemy_fire_cadence.gd`
- Create: `tests/integration/test_enemy_weapon_controller.gd`
- Modify: `scenes/combat/enemy_fighter.tscn`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `EnemyFireCadence.advance(can_fire: bool, delta: float, shots_per_second: float) -> Array[int]` returns alternating `PrimaryFireCadence.MuzzleSide` values without depending on player input.
- `EnemyFireCadence.reset() -> void`.
- `EnemyWeaponController.set_target(body: RigidBody3D) -> void`.
- `EnemyWeaponController.set_firing_enabled(enabled: bool) -> void`.
- `EnemyWeaponController.reset_runtime_state() -> void`.
- `EnemyWeaponController.get_last_intercept() -> ProjectileInterceptResult`.
- `EnemyWeaponController.has_legal_firing_solution() -> bool`.

- [ ] **Step 1: Write RED cadence tests**

Create `tests/unit/test_enemy_fire_cadence.gd`:

```gdscript
extends TestCase

func run() -> void:
    var cadence := EnemyFireCadence.new()
    var first := cadence.advance(true, 0.0, 3.0)
    expect_equal(first.size(), 1, "first legal solution should fire immediately")
    expect_equal(first[0], PrimaryFireCadence.MuzzleSide.LEFT, "first side should be left")
    expect_equal(cadence.advance(true, 0.1, 3.0).size(), 0, "cadence must block early repeat")
    var second := cadence.advance(true, 0.24, 3.0)
    expect_equal(second.size(), 1, "shot should become legal after ~1/3 second")
    expect_equal(second[0], PrimaryFireCadence.MuzzleSide.RIGHT, "muzzles alternate")
    cadence.advance(false, 0.0, 3.0)
    expect_equal(cadence.advance(true, 0.0, 3.0).size(), 1, "new firing window may fire immediately")
```

Also test non-positive/non-finite `shots_per_second` produces zero shots.

- [ ] **Step 2: Implement `EnemyFireCadence` and register suite**

Mirror the proven `PrimaryFireCadence` state machine but make shot rate a validated method input instead of using the player's `SHOTS_PER_SECOND` constant.

Expected after registration: `PASS: 48 suites`.

- [ ] **Step 3: Write RED weapon-controller integration suite**

Create `tests/integration/test_enemy_weapon_controller.gd` covering:

1. aligned stationary target inside range → legal solution and one pooled projectile;
2. moving lateral target → stored intercept direction leads the target;
3. target outside `weapon_range` → no fire;
4. target inside range but outside `firing_cone_degrees` → no fire;
5. target behind fighter → no fire;
6. static collision blocker between muzzle and target → no fire;
7. remove blocker while all other gates pass → fire resumes;
8. disabled/destroyed state → no fire;
9. projectile world velocity equals enemy body velocity plus muzzle forward × **900 m/s**;
10. fired projectile source body is the enemy so self-collision is excluded.

Use actual physics frames for LOS/blocker assertions rather than stubbing the raycast.

- [ ] **Step 4: Implement `EnemyWeaponController`**

Required exports:

```gdscript
@export var body_path: NodePath = NodePath("..")
@export var model_path: NodePath = NodePath("../VisualRoot/SmallSciFiFighter")
@export var projectile_pool_path: NodePath = NodePath("../PulseProjectilePool")
@export var damage_state_path: NodePath = NodePath("../DamageState")
@export var tuning: EnemyFighterTuning
```

Resolve exactly one `Weapons` hierarchy and the same canonical paths used by `PrimaryFireController`:

```text
Weapons/Primary/LeftMuzzle
Weapons/Primary/RightMuzzle
```

Do not create approximate muzzle nodes.

Each physics tick:

```gdscript
var intercept := ProjectileInterceptSolver.solve(
    _body.global_position,
    _body.linear_velocity,
    _target.global_position,
    _target.linear_velocity,
    900.0 shared constant
)
var legal := (
    _firing_enabled
    and not _damage_state.is_destroyed()
    and intercept.valid
    and distance <= tuning.weapon_range
    and angular_error_degrees <= tuning.firing_cone_degrees
    and _has_clear_line_of_sight(_target)
)
var sides := _cadence.advance(legal, delta, tuning.shots_per_second)
```

Firing uses actual muzzle transforms but projectile velocity uses the **current fighter forward axis** so a legal cone means the ship has physically pointed sufficiently close to the intercept solution:

```gdscript
var forward := -_body.global_transform.basis.z.normalized()
var velocity := _body.linear_velocity + forward * 900.0
_pool.fire(muzzle.global_transform, velocity, _body)
```

Line of sight:

- ray from current muzzle/global body position to target center;
- exclude enemy body RID;
- clear if first hit is target;
- blocked if first hit is any other collider;
- fail closed when physics space state is unavailable.

`EnemyWeaponController` does not rotate the ship.

- [ ] **Step 5: Wire weapon controller into enemy scene/controller lifecycle**

Attach script and tuning in `enemy_fighter.tscn`.

In `EnemyFighterController.set_target`, forward the same target to `EnemyWeaponController`.

On destruction/reset/respawn:

```gdscript
_weapon_controller.set_firing_enabled(false)
_weapon_controller.reset_runtime_state()
# re-enable only after active respawn completion
```

- [ ] **Step 6: Register/run weapon integration suite**

Expected: `PASS: 49 suites`.

- [ ] **Step 7: Commit Task 4**

```bash
git add src/combat/enemy_fire_cadence.gd src/combat/enemy_weapon_controller.gd scenes/combat/enemy_fighter.tscn src/combat/enemy_fighter_controller.gd tests/unit/test_enemy_fire_cadence.gd tests/integration/test_enemy_weapon_controller.gd tests/test_runner.gd
git commit -m "feat: add fair predictive enemy pulse fire"
```

---

### Task 5: Production dogfight room, HUD, respawn loop, and full verification

**Files:**
- Modify: `scenes/flight_room/flight_room.tscn`
- Modify: `src/flight_room/flight_room_controller.gd`
- Modify: `scenes/ui/combat_hud.tscn`
- Modify: `src/ui/combat_hud.gd`
- Modify: `tests/integration/test_combat_sandbox.gd`
- Create: `tests/integration/test_tactical_dogfight_sandbox.gd`
- Modify: `tests/test_runner.gd`
- Modify after verification only: `README.md`
- Modify after verification only: `docs/superpowers/plans/deferred-milestones.md`

**Interfaces:**
- Production room owns one `EnemyFighter`, not `PracticeDrone`.
- `FlightRoomController` exports `enemy_fighter_controller_path` instead of `practice_drone_controller_path`.
- `CombatHud` targets `EnemyFighter/DamageState` and `EnemyFighter/EnemyFighterController`.
- Room reset restores player and enemy through their established reset paths.

- [ ] **Step 1: Write the RED end-to-end dogfight suite**

Create `tests/integration/test_tactical_dogfight_sandbox.gd` with high-value scenarios rather than frame-fragile exact paths:

```gdscript
extends TestCase

func run() -> void:
    _production_room_contains_exactly_one_enemy_fighter_and_no_active_practice_drone()
    _enemy_acquires_player_and_generates_nonzero_bounded_force()
    _enemy_can_reach_a_legal_firing_solution_and_launch_real_projectile()
    _enemy_projectile_damages_player_shield_through_existing_pipeline()
    _player_can_damage_and_destroy_enemy_through_existing_pipeline()
    _enemy_destruction_stops_motion_and_fire_then_respawns_cleanly()
    _room_reset_restores_both_ships_and_clears_both_projectile_pools()
```

For the firing-solution scenario, set both frozen bodies into a deterministic aligned fixture **before** re-enabling the enemy controller; do not weaken weapon gates to make the test pass.

For projectile damage, use a real pooled projectile and physics space, then assert exact **15** shield loss on the player.

For respawn, force lethal damage via the normal `DamagePacket` path, advance the enemy controller through `respawn_delay`, and assert:

- full enemy shield/hull;
- collisions restored;
- visual root restored;
- tactical state reset to `ACQUIRE`;
- weapon cadence reset;
- enemy pool empty;
- body unfrozen and active.

- [ ] **Step 2: Replace practice drone in production room**

In `scenes/flight_room/flight_room.tscn`:

- replace ext_resource `practice_drone.tscn` with `enemy_fighter.tscn`;
- replace node `PracticeDrone` with `EnemyFighter`;
- use initial spawn `Vector3(0, 35, -320)` to give the tactical controller room to acquire/re-enter rather than spawning directly in point-blank fire;
- update `FlightRoomController` path to `../EnemyFighter/EnemyFighterController`.

Do **not** delete `scenes/combat/practice_drone.tscn` or its tests/source files; it remains an available training/reference asset but is no longer active in the default room.

- [ ] **Step 3: Update flight-room orchestration**

In `src/flight_room/flight_room_controller.gd`:

```gdscript
@export var enemy_fighter_controller_path: NodePath
var _enemy_fighter_controller: EnemyFighterController
```

On ready:

```gdscript
_enemy_fighter_controller = get_node_or_null(enemy_fighter_controller_path) as EnemyFighterController
_enemy_fighter_controller.set_target(_body)
_enemy_fighter_controller.set_hostile_projectile_pool(_projectile_pool)
```

On `reset_player()`:

```gdscript
if _enemy_fighter_controller != null:
    _enemy_fighter_controller.reset_to_spawn()
```

Retain every existing player reset, asteroid-field, boundary, pause, camera, and settings behavior.

- [ ] **Step 4: Retarget combat HUD**

In `scenes/ui/combat_hud.tscn`:

```text
target_damage_state_path = ../../EnemyFighter/DamageState
target_controller_path = ../../EnemyFighter/EnemyFighterController
TitleLabel.text = "HOSTILE FIGHTER"
```

In `src/ui/combat_hud.gd`, change only the concrete lifecycle type:

```gdscript
var _target_controller: EnemyFighterController
```

Preserve player shield/hull, target shield/hull, respawn status, and hit marker behavior. The player hit marker must still react only to the **player's** projectile pool.

- [ ] **Step 5: Update existing Combat Sandbox regression expectations**

Modify `tests/integration/test_combat_sandbox.gd` wherever the production room specifically expects `PracticeDrone` so it expects `EnemyFighter` and the new controller. Preserve all existing assertions for:

- shield-first player damage;
- collision damage;
- localized shield impact activation;
- player hit marker behavior;
- player destruction/reset;
- room reset restoring combat state.

Do not delete coverage just because the target changed.

- [ ] **Step 6: Register end-to-end suite and reach the final runner target**

Add `res://tests/integration/test_tactical_dogfight_sandbox.gd` only after the file exists.

Run the headless runner.

Expected: `PASS: 50 suites`.

- [ ] **Step 7: Run the full repository verifier**

Windows canonical command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify\verify.ps1
```

Expected minimum evidence:

```text
Godot 4.7.1
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 50 suites
PASS: inertial rigid-body velocity preservation
speed drift: 0.000000000 m/s
direction drift: 0.000000000 degrees
```

On the Linux sandbox, run the equivalent repository verifier with the uploaded Godot 4.7.1 binary after normalizing only the sandbox copy's shell line endings if required.

Any parser/test/runtime failure blocks completion. Use `superpowers:systematic-debugging` for failures rather than weakening tests.

- [ ] **Step 8: Run an actual runtime smoke**

Launch the main project scene under a virtual display for at least several physics seconds and require:

- process remains alive until intentional timeout/termination;
- no GDScript parser errors;
- no invalid-call/node-path errors;
- no shader errors;
- no repeated runtime errors;
- enemy fighter visibly/structurally remains active enough for physics integration (automated smoke need not judge subjective dogfight quality).

Do not claim gameplay feel from the smoke; Ahmad's later manual pass decides subjective tuning.

- [ ] **Step 9: Documentation closure after verification only**

Update `README.md`:

- runner target from 44 to 50 suites;
- Combat Sandbox target description becomes tactical one-on-one dogfight;
- document enemy predictive pulse return fire and physical/no-cheat AI boundary;
- retain Windows Godot 4.7.1 verification commands.

Update `docs/superpowers/plans/deferred-milestones.md`:

- record Combat Sandbox v1 as verified historical foundation;
- mark Tactical Enemy Dogfight as implemented/technically verified only if Steps 7–8 actually passed;
- preserve deferred heavy plasma, missiles/weapon expansion, final enemy art, elaborate explosions, asteroid destruction, audio, radar/lock-on, multi-enemy/fleet AI, and richer VFX for later phases.

- [ ] **Step 10: Commit the integrated milestone**

```bash
git add scenes/flight_room/flight_room.tscn src/flight_room/flight_room_controller.gd scenes/ui/combat_hud.tscn src/ui/combat_hud.gd tests/integration/test_combat_sandbox.gd tests/integration/test_tactical_dogfight_sandbox.gd tests/test_runner.gd README.md docs/superpowers/plans/deferred-milestones.md
git commit -m "feat: complete tactical enemy dogfight sandbox"
```

Do not push intermediate task commits solely to trigger GitHub Actions. Keep them local until the complete milestone passes local verification; then publish the completed branch/commit set once.

---

## Manual gameplay acceptance after technical verification

Automated completion means the systems are correct enough to hand to the player; it does **not** mean the opponent is subjectively fun yet. Ahmad's manual pass should judge:

1. Enemy does not simply fly straight at the player forever.
2. At long range it closes from a useful angle.
3. At combat range it tries to build a lead firing solution.
4. High closure produces a visible break/range-control action before a silly pass-through.
5. After a bad pass it extends away and re-enters instead of snapping 180 degrees.
6. When the player has dangerous firing geometry, enemy performs a credible bounded evasive break.
7. Enemy cannot magically dodge every projectile.
8. Enemy must point toward its predicted intercept before it can shoot.
9. Its 3 shots/s initial cadence feels threatening but readable.
10. Obstacles block enemy fire.
11. Enemy rounds visibly travel as normal projectiles and damage player shield first.
12. Player rounds hit the exact existing shield/hull pipeline on the enemy.
13. Enemy death stops its movement/fire immediately, then it respawns after ~3 seconds into a fresh engagement.
14. Player death/reset still behaves exactly as before.
15. AI Assisted, Smart Stabilize, Inertial mode, exact player muzzles, thrusters, cameras, pause/settings, asteroids, and zero-drift behavior still feel intact.

If tactical feel is wrong but all contracts pass, tune only `config/combat/enemy_fighter_tuning.tres` first. Change solver architecture only when a concrete behavior cannot be produced by tuning.
