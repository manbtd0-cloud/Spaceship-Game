# Combat Kernel 1 Phase 5 — Arena Integration and Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This project is inline-execution only; stop at every local Blender/Godot checkpoint and use the user's pasted output as the source of truth.

**Goal:** Wire player combat components, drone, projectile pool, destruction/reset lifecycle, cannon calibration, documentation, and the final 36-suite verification gate.

**Architecture:** `FlightRoomController` remains the arena coordinator, while player flight retains only a generic control gate. All reset sources converge on one deterministic arena reset. Completion requires schema-5 validation, 36 Godot suites, project import, main-scene boot, calibration, and user gameplay inspection.

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
### Task 10: Integrate player combat components and temporary destruction/reset lifecycle

**Files:**
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `scenes/player/player_interceptor.tscn`
- Create: `tests/integration/test_player_combat_scene.gd`
- Modify: `tests/integration/test_player_scene.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `ShipFlightController.set_control_enabled(enabled: bool)`.
- `ShipFlightController.is_control_enabled() -> bool`.
- Player scene exposes exact children: `DamageState`, `PrimaryFireController`, `CollisionContactTracker`, `ShieldVisualController`, `HullImpactEffectController`.
- `PrimaryFireController` receives the arena projectile pool through `set_projectile_pool` after the flight room resolves both nodes.

- [ ] **Step 1: Add a generic flight-control gate**

This is not damage logic. Add:

```gdscript
var _control_enabled := true

func set_control_enabled(enabled: bool) -> void:
    _control_enabled = enabled
    if not enabled:
        _last_command = FlightCommand.new()
        _last_pilot_force_local = Vector3.ZERO
        _last_pilot_torque_local = Vector3.ZERO
        _last_assist_force_local = Vector3.ZERO
        _last_assist_torque_local = Vector3.ZERO
        _last_force_local = Vector3.ZERO
        _last_torque_local = Vector3.ZERO

func is_control_enabled() -> bool:
    return _control_enabled
```

In `_physics_process`, keep capture/reset handling available, but skip command forces when control is disabled.

- [ ] **Step 2: Wire the player scene**

Root uses `PlayerInterceptorBody`. Add:

```text
DamageState
PrimaryFireController
CollisionContactTracker
ShieldVisualController
HullImpactEffectController
DestructionIndicator
```

Wire:

- player damage tuning;
- player shield profile;
- exact model and muzzle paths;
- projectile pool is injected by `FlightRoomController`; no parent-relative pool path is stored in the player scene;
- contact tracker path on root;
- `contact_monitor = true`;
- `max_contacts_reported = 16`.

Do not add weapon or damage code to `ShipFlightController`.

- [ ] **Step 3: Connect result flow**

- projectile/collision results → `ShieldVisualController` or `HullImpactEffectController`;
- successful projectile damage → `CombatPipper.flash_confirmed_hit`;
- `DamageState.destroyed` → arena lifecycle signal;
- shield/hull values → HUD through read-only paths.

- [ ] **Step 4: Write player integration tests**

Prove:

- all exact components exist;
- root still has mass `8500`, zero gravity/damping, continuous CD, canonical collider, canonical model identity;
- both muzzle nodes resolve;
- fire controller disables itself if either muzzle is missing;
- damage state values are exact;
- collision tracker does not alter body physics properties;
- control gate stops thrust but leaves reset available;
- existing thruster controller and camera target remain.

- [ ] **Step 5: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 6: Commit**

```powershell
git add `
  src/player/ship_flight_controller.gd `
  scenes/player/player_interceptor.tscn `
  tests/integration/test_player_combat_scene.gd `
  tests/integration/test_player_scene.gd `
  tests/test_runner.gd
git commit -m "feat: integrate combat components with player fighter"
```

---

### Task 11: Integrate the arena, drone, symmetric ramming, and deterministic reset

**Files:**
- Modify: `src/flight_room/flight_room_controller.gd`
- Modify: `scenes/flight_room/flight_room.tscn`
- Modify: `scenes/combat/practice_drone.tscn`
- Modify: `src/combat/practice_drone_controller.gd`
- Modify: `tests/integration/test_flight_room_scene.gd`
- Modify: `tests/integration/test_collision_damage_integration.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `FlightRoomController.reset_arena()`.
- Player destruction requests reset after `1.0` second.
- Manual `R`, boundary exit, reset volume, and player destruction all use the same arena reset.

- [ ] **Step 1: Add arena nodes**

Add to `flight_room.tscn`:

```text
CombatProjectiles       # PulseProjectilePool
PracticeDrone           # instance
```

Place the drone on the navigation route far enough from spawn to permit a clean firing run, but not inside an asteroid or pylon. Use one checked-in transform and assert it in the scene test.

- [ ] **Step 2: Expand controller paths**

`FlightRoomController` exports paths for:

- player damage state;
- player primary fire;
- player contact tracker;
- player shield visuals;
- player hull visuals;
- projectile pool;
- practice drone;
- HUD/pipper transient reset.

Resolve all paths fail-closed. Missing optional visuals disable only visuals; missing player body/controller/damage/pool/drone disables combat lifecycle and reports a clear error.

- [ ] **Step 3: Implement one arena reset**

Rename internal reset use to `reset_arena()` and perform in order:

1. freeze player;
2. restore spawn transform;
3. zero linear/angular velocity;
4. reset flight runtime;
5. reset primary-fire cadence;
6. reset player damage;
7. clear player contact tracker;
8. clear projectiles;
9. clear shield/hull effects and pipper flash;
10. reset drone immediately;
11. unfreeze/wake player;
12. restore flight and firing control.

All existing reset triggers call this function.

- [ ] **Step 4: Implement temporary player destruction flow**

On player destroyed:

- disable flight and primary fire immediately;
- show minimal `DestructionIndicator`;
- wait `1.0` second in the arena controller;
- call `reset_arena`;
- do not create debris, wreckage, camera cut, or polished explosion.

A second destroyed signal during the delay must not schedule a second reset.

- [ ] **Step 5: Verify symmetric ramming path**

When the collider is the practice drone, `CollisionContactTracker` resolves the same damage amount into both player and drone. The drone remains static and does not receive an artificial physics impulse from damage routing.

- [ ] **Step 6: Extend flight-room tests**

Prove:

- drone and projectile pool exist;
- player can fire into actual drone and reduce shield;
- drone destruction disables then restores after three seconds;
- player destruction disables controls before one-second reset;
- manual reset clears player, drone, projectile, contacts, effects, timers, and HUD transient state;
- boundary/reset-volume behavior still works;
- collision shield does not suppress bounce;
- asteroid hits produce effect only and no health state.

- [ ] **Step 7: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 8: Commit**

```powershell
git add `
  src/flight_room/flight_room_controller.gd `
  scenes/flight_room/flight_room.tscn `
  scenes/combat/practice_drone.tscn `
  src/combat/practice_drone_controller.gd `
  tests/integration/test_flight_room_scene.gd `
  tests/integration/test_collision_damage_integration.gd `
  tests/test_runner.gd
git commit -m "feat: complete combat arena lifecycle"
```

---

### Task 12: Add production-socket cannon calibration

**Files:**
- Create: `src/debug/cannon_calibration.gd`
- Create: `scenes/debug/cannon_calibration.tscn`
- Create: `tests/integration/test_cannon_calibration_scene.gd`
- Modify: `tests/test_runner.gd`
- Modify: `README.md`

**Interfaces:**
- Uses the production `player_interceptor.tscn`.
- Displays both exact muzzle paths, origins, basis vectors, and forward rays.
- Never creates fallback marker positions.

- [ ] **Step 1: Create the calibration scene**

Scene contains:

- production player instance;
- fixed inspection camera;
- left/right colored forward rays;
- canonical fighter-forward ray;
- text report;
- failure panel.

Controls:

```text
Left / Right    select left/right muzzle
Space           pause/resume ray animation
Escape          exit
```

- [ ] **Step 2: Implement fail-closed calibration script**

Resolve:

```text
VisualRoot/SmallSciFiFighter/Weapons/Primary/LeftMuzzle
VisualRoot/SmallSciFiFighter/Weapons/Primary/RightMuzzle
```

Display:

- path;
- local and global origin;
- basis rows;
- forward dot fighter-forward;
- schema-5 manifest source object and vertex indices.

If a node or manifest record is missing/mismatched, show failure and disable the normal report. Never synthesize a marker.

- [ ] **Step 3: Write integration tests**

Prove:

- scene loads;
- production player is used;
- both exact nodes resolve;
- no fallback `Marker3D` or hard-coded offsets exist;
- reported forward dot is `>= 0.95`;
- manifest and runtime paths match.

- [ ] **Step 4: Document launch command**

Add to README:

```powershell
godot --path . res://scenes/debug/cannon_calibration.tscn
```

Describe the controls and state that the scene is diagnostic only.

- [ ] **Step 5: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 6: Commit**

```powershell
git add `
  src/debug/cannon_calibration.gd `
  scenes/debug/cannon_calibration.tscn `
  tests/integration/test_cannon_calibration_scene.gd `
  tests/test_runner.gd `
  README.md
git commit -m "feat: add cannon socket calibration scene"
```

---

### Task 13: Finalize the test runner, verifier, documentation, and local acceptance gate

**Files:**
- Modify: `tests/test_runner.gd`
- Modify: `tools/verify/verify.ps1`
- Modify: `README.md`
- Modify: `docs/roadmap/LATER.md`
- Verify all files changed by Tasks 1–12

**Interfaces:**
- Final Godot runner target: `PASS: 36 suites`.
- Final verification entry point: `.\tools\verify\verify.ps1`.

- [ ] **Step 1: Register the exact fourteen new Godot suites**

Append these paths once, with no duplicates:

```gdscript
"res://tests/unit/test_primary_fire_cadence.gd",
"res://tests/unit/test_damage_state.gd",
"res://tests/unit/test_collision_damage_model.gd",
"res://tests/unit/test_collision_contact_tracker.gd",
"res://tests/unit/test_shield_envelope_math.gd",
"res://tests/unit/test_combat_pipper_math.gd",
"res://tests/integration/test_primary_fire_input.gd",
"res://tests/integration/test_pulse_projectile.gd",
"res://tests/integration/test_practice_drone_scene.gd",
"res://tests/integration/test_player_combat_scene.gd",
"res://tests/integration/test_collision_damage_integration.gd",
"res://tests/integration/test_shield_visual_controller.gd",
"res://tests/integration/test_combat_pipper.gd",
"res://tests/integration/test_cannon_calibration_scene.gd",
```

The existing 22 plus these 14 must produce `PASS: 36 suites`.

- [ ] **Step 2: Run all Python contract tests**

```powershell
python -m unittest `
  tests.tools.test_small_fighter_calibration `
  tests.tools.test_fighter_socket_names `
  tests.tools.test_source_exact_thruster_geometry `
  tests.tools.test_canonical_fighter_v5 `
  tests.tools.test_primary_weapon_muzzle_geometry `
  tests.tools.test_fighter_thruster_action_contract `
  tests.tools.test_verify_scripts `
  tests.tools.test_asteroid_pack `
  -v
```

Expected: zero failures and zero errors.

- [ ] **Step 3: Run the full local verifier**

```powershell
.\tools\verify\verify.ps1
```

Expected stages:

1. schema-5 GLB/manifest validation passes;
2. deterministic thruster matrix validation passes;
3. Godot project import exits `0`;
4. Godot runner prints `PASS: 36 suites`;
5. main scene boots briefly with no parser, path, or runtime errors.

This is a mandatory user-output checkpoint. Do not state that Combat Kernel 1 passes until the complete output is pasted and inspected.

- [ ] **Step 4: Run interactive calibration**

```powershell
godot --path . res://scenes/debug/cannon_calibration.tscn
```

User acceptance checklist:

- both muzzle rays emerge from actual visible cannon exits;
- rays remain fighter-forward;
- no offset visibly floats away from the model;
- left/right identity is correct;
- thruster visuals remain source-exact and unaffected.

- [ ] **Step 5: Run the game interactively**

```powershell
godot --path .
```

User acceptance checklist:

- LMB and `V` share one cadence;
- holding both does not increase fire rate;
- Left/Right alternation is visible;
- pipper follows fighter-forward, not camera center;
- high-speed shots hit the drone;
- shield ripple is localized and dim;
- low shield becomes visibly unstable;
- shield break flashes once;
- collisions still bounce/spin normally;
- collision damage reaches shield then hull;
- sustained scraping does not drain continuously;
- ramming damages player and drone;
- shield and hull recovery timing feels as specified;
- player and drone reset deterministically;
- Camera C0 and all existing flight controls remain unchanged.

- [ ] **Step 6: Update README and deferred ledger**

README must state:

- current milestone includes Combat Kernel 1;
- controls include LMB/`V`;
- damage and regeneration values;
- calibration command;
- verifier target `PASS: 36 suites`;
- no claim beyond pasted verification.

`docs/roadmap/LATER.md` must:

- mark Combat Kernel 1 active/completed with links to design and plan;
- keep Camera C1, enemy AI, enemy weapons, heavy plasma, heat/ammo, aim assistance, destructible asteroids, advanced shield deformation, polished audio, scorch decals, and full destruction effects deferred;
- remove no unrelated entries.

- [ ] **Step 7: Review the diff for scope**

```powershell
git status --short
git diff --stat 1d63819e02c194d762ee08f45c038ac10389fdb0..HEAD
git diff --check
```

Reject unrelated refactors, raw source-asset mutations, GitHub Actions, camera changes, or gameplay loading from `assets/source/`.

- [ ] **Step 8: Commit final verification/docs updates**

```powershell
git add `
  tests/test_runner.gd `
  tools/verify/verify.ps1 `
  README.md `
  docs/roadmap/LATER.md
git commit -m "docs: finalize Combat Kernel 1 verification"
```

- [ ] **Step 9: Record the verified head**

```powershell
git rev-parse HEAD
git status --short
```

Expected: clean working tree. Record the exact commit only after the user-pasted verifier output confirms all stages.

---
