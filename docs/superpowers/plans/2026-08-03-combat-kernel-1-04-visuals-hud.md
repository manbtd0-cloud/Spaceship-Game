# Combat Kernel 1 Phase 4 — Shield Visuals and Combat HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This project is inline-execution only; stop at every local Blender/Godot checkpoint and use the user's pasted output as the source of truth.

**Goal:** Add pooled localized shield impacts, provisional player/drone shield envelopes, hull/world hit feedback, and a pure fighter-forward pipper.

**Architecture:** Use one shared envelope-math contract for mesh generation and impact placement, GL-Compatible shaders and CPU particles, and read-only HUD bindings. Visual components consume damage results but never calculate or apply damage.

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
### Task 8: Add pooled localized shield effects and provisional shield envelopes

**Files:**
- Create: `src/combat/shield_envelope_profile.gd`
- Create: `src/combat/shield_envelope_math.gd`
- Create: `src/combat/shield_envelope_mesh_factory.gd`
- Create: `src/combat/shield_impact_patch.gd`
- Create: `src/combat/shield_visual_controller.gd`
- Create: `src/combat/hull_impact_effect_controller.gd`
- Create: `config/combat/player_shield_profile.tres`
- Create: `config/combat/drone_shield_profile.tres`
- Create: `assets/shaders/shield_impact_patch.gdshader`
- Create: `assets/shaders/shield_break_envelope.gdshader`
- Create: `scenes/combat/shield_impact_patch.tscn`
- Create: `tests/unit/test_shield_envelope_math.gd`
- Create: `tests/integration/test_shield_visual_controller.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `ShieldEnvelopeMath.surface_point(direction, profile) -> Vector3`.
- `ShieldEnvelopeMeshFactory.create_mesh(profile) -> ArrayMesh`.
- `ShieldVisualController.show_damage(result)`.
- `ShieldVisualController.clear_all()`.
- `HullImpactEffectController.show_hit(point, normal)`.
- `HullImpactEffectController.clear_all()`.

- [ ] **Step 1: Write envelope math tests**

Player profile tests must prove:

- front/rear reach is approximately `6.5 m`;
- center fuselage width is approximately `3.1 m`;
- lateral wing reach is approximately `7.2 m`;
- top/bottom reach is approximately `2.0 m`;
- every result is finite;
- opposite directions produce mirrored points;
- drone profile produces a fitted ellipsoid using `Vector3(3.2, 2.0, 2.6)`.

Use tolerances rather than comparing generated mesh vertices exactly.

- [ ] **Step 2: Implement profiles and surface math**

`ShieldEnvelopeProfile`:

```gdscript
class_name ShieldEnvelopeProfile
extends Resource

enum Shape {
    PLAYER_FIGHTER,
    DRONE_ELLIPSOID,
}

@export var shape: Shape = Shape.DRONE_ELLIPSOID
@export var fuselage_extents := Vector3(3.1, 2.0, 6.5)
@export var wing_extents := Vector3(7.2, 1.15, 3.8)
@export var ellipsoid_extents := Vector3(3.2, 2.0, 2.6)
```

For the player, calculate ray distance to both ellipsoids and blend toward the wing ellipsoid using:

```gdscript
var lateral := pow(absf(direction.x), 0.65)
var center_band := pow(clampf(1.0 - absf(direction.z), 0.0, 1.0), 1.5)
var wing_weight := lateral * center_band
var radius := lerpf(fuselage_radius, maxf(fuselage_radius, wing_radius), wing_weight)
```

The full-envelope mesh samples this same function; visual mesh and patch placement cannot use different shape math.

- [ ] **Step 3: Create GL-Compatible shaders**

`shield_impact_patch.gdshader` must be `spatial`, transparent, unshaded, depth-draw-never. Exposed uniforms:

```glsl
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float instability : hint_range(0.0, 1.0) = 0.0;
```

It must:

- draw a radial ripple;
- modulate a hex-grid edge function;
- fade fully by `progress == 1.0`;
- increase fragmentation/flicker only through `instability`;
- never reveal a full shell.

`shield_break_envelope.gdshader` exposes `flash_amount` and fades the full mesh. No idle emission.

- [ ] **Step 4: Implement the eight-patch pool**

On `_ready`, `ShieldVisualController` instantiates exactly `8` patch scenes and duplicates each material. `show_damage`:

- ignores results with zero shield damage;
- uses actual projectile point;
- maps collision hits to front/rear/left/right dominant local direction;
- projects the direction through `ShieldEnvelopeMath`;
- starts a `0.25` second patch;
- sets instability to `1.0` at shield ratio `<= 0.25`, otherwise `0.0`;
- recycles the oldest active patch for a ninth simultaneous hit;
- triggers full-envelope flash only when `result.shield_broke`.

`clear_all` hides and resets every patch and the break envelope.

- [ ] **Step 5: Implement hull and asteroid impact feedback**

Use pooled `CPUParticles3D` plus a short-lived emissive flash, never direct GPU particle emission.

- hull hit: orange-white flash plus small sparks;
- asteroid/world hit: smaller neutral spark;
- no scorch decals;
- no asteroid health.

- [ ] **Step 6: Write integration tests**

Prove:

- idle shield is invisible;
- one hit activates one patch;
- overlapping hits use separate materials and timers;
- ninth hit recycles oldest;
- all patches return inactive after `0.25` seconds;
- low shield sets unstable intensity;
- break envelope flashes once;
- collision hits quantize to four stable regions;
- visuals never add or modify collision shapes;
- `clear_all` resets every transient.

- [ ] **Step 7: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass under GL Compatibility.

- [ ] **Step 8: Commit**

```powershell
git add `
  src/combat/shield_envelope_profile.gd `
  src/combat/shield_envelope_math.gd `
  src/combat/shield_envelope_mesh_factory.gd `
  src/combat/shield_impact_patch.gd `
  src/combat/shield_visual_controller.gd `
  src/combat/hull_impact_effect_controller.gd `
  config/combat/player_shield_profile.tres `
  config/combat/drone_shield_profile.tres `
  assets/shaders/shield_impact_patch.gdshader `
  assets/shaders/shield_break_envelope.gdshader `
  scenes/combat/shield_impact_patch.tscn `
  tests/unit/test_shield_envelope_math.gd `
  tests/integration/test_shield_visual_controller.gd `
  tests/test_runner.gd
git commit -m "feat: add localized shield and hull impact visuals"
```

---

### Task 9: Add fighter-forward pipper and combat HUD state

**Files:**
- Create: `src/ui/combat_pipper_math.gd`
- Create: `src/ui/combat_pipper.gd`
- Modify: `src/ui/flight_hud.gd`
- Modify: `scenes/ui/flight_hud.tscn`
- Create: `tests/unit/test_combat_pipper_math.gd`
- Create: `tests/integration/test_combat_pipper.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `CombatPipperMath.clamp_to_viewport(point, viewport_size, margin) -> Vector2`.
- `CombatPipperMath.chevron_angle(direction) -> float`.
- `CombatPipper.flash_confirmed_hit()`.
- `FlightHud` reads `DamageState` but never changes it.

- [ ] **Step 1: Write pipper math tests**

Prove:

- in-bounds points remain unchanged;
- off-screen points clamp to a `24 px` margin;
- zero direction returns viewport center safely;
- chevron angle matches right/up/left/down;
- calculations are finite for very large projections.

- [ ] **Step 2: Implement `CombatPipper`**

Exports:

```gdscript
@export var fighter_path: NodePath
@export var camera_path: NodePath
@export var pipper_path: NodePath
@export var edge_chevron_path: NodePath
```

Every frame:

```gdscript
var forward_point := (
    _fighter.global_position
    - _fighter.global_transform.basis.z.normalized() * 1000.0
)
var behind := _camera.is_position_behind(forward_point)
var projected := _camera.unproject_position(forward_point)
```

- when visible and inside viewport: show central pipper at projected position;
- otherwise: hide central pipper and show the clamped edge chevron;
- do not inspect targets or raycast;
- do not change color when crossing a target;
- `flash_confirmed_hit` briefly brightens pipper only after a projectile applies nonzero damage.

- [ ] **Step 3: Extend the HUD scene**

Keep all existing labels. Add a compact combat panel containing:

- `ShieldBar` as a thin `ProgressBar`;
- `ShieldValueLabel`, text `SHIELD 150 / 150`;
- `HullValueLabel`, text `HULL 200 / 200`;
- `RechargeLabel`, hidden unless `is_recharging()` or `is_rebooting()`;
- `CombatPipper`;
- `EdgeChevron`.

Low-shield warning begins at `<= 25%`. Do not replace existing speed/mode/boost/heat/envelope/capture/control telemetry.

- [ ] **Step 4: Extend `FlightHud`**

Add exported player `DamageState` path and combat widget paths. Refresh:

- current/max shield;
- current/max hull;
- `RECHARGING`;
- `SHIELD REBOOT`;
- low-shield warning;
- no target labels or lock state.

- [ ] **Step 5: Write integration tests**

Prove:

- fighter-forward projection moves independently from screen center;
- off-screen/behind direction uses the edge chevron;
- target overlap does not alter pipper;
- damage confirmation flashes;
- asteroid/world hit does not flash confirmation;
- all prior HUD labels remain.

- [ ] **Step 6: Run tests**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all registered suites pass.

- [ ] **Step 7: Commit**

```powershell
git add `
  src/ui/combat_pipper_math.gd `
  src/ui/combat_pipper.gd `
  src/ui/flight_hud.gd `
  scenes/ui/flight_hud.tscn `
  tests/unit/test_combat_pipper_math.gd `
  tests/integration/test_combat_pipper.gd `
  tests/test_runner.gd
git commit -m "feat: add fighter forward combat HUD"
```

---
