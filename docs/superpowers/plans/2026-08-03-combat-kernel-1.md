# Combat Kernel 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This project is inline-execution only; do not dispatch subagents. Execute the linked phase plans in order and stop at every local Blender/Godot verification checkpoint.

**Goal:** Add the first complete combat loop to the accepted Shattered Orbit flight room: source-derived alternating pulse cannons, swept projectiles, a stationary armored practice drone, shield/hull damage, collision damage, localized shield effects, fighter-forward HUD guidance, and deterministic reset.

**Architecture:** Combat Kernel 1 is implemented as five sequential phase plans. The canonical asset contract is fixed first, then weapon/damage foundations, drone/collision behavior, visuals/HUD, and finally arena integration and acceptance. All runtime damage enters `DamageState` through typed `DamagePacket` values and leaves as typed `DamageResult` values; flight, camera, thruster, visuals, HUD, and arena lifecycle remain separate.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, GL Compatibility, Blender 5.2 LTS, Python 3, PowerShell, custom `TestCase` harness.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Start from design/spec commit `1d63819e02c194d762ee08f45c038ac10389fdb0` or a descendant.
- Inline execution only; use `superpowers:executing-plans`.
- Preserve six-axis flight, assisted/manual modes, boost/thermal behavior, Camera C0, canonical fighter identity, twelve source-exact thruster effects, deterministic thruster matrix, asteroid field, physical collision response, reset, and existing HUD.
- Primary fire is fighter-forward only.
- One logical `fire_primary` action binds LMB and physical `V`.
- Shared cadence: `7.0` shots/second, first shot immediate, Left then Right.
- Projectile: inherited ship velocity plus `900.0 m/s` fighter-forward, `3.0` second lifetime, `15.0` damage.
- Player and drone: `150.0` shield and `200.0` hull.
- Shield-first damage with full overflow.
- Shield delay/rate: `8.0` seconds and `3.0` points/second.
- Shield reboot after break: `20.0` seconds.
- Player hull repair: full shield plus `10.0` seconds, then `1.0` point/second.
- Collision threshold: `10.0 m/s`; maximum damage `100.0`; renewed-impact delta `10.0 m/s`; tiny-body cutoff `25.0 kg`.
- Shield visuals never act as colliders or alter impulse, bounce, spin, or momentum.
- Eight localized shield patches per shield, `0.25` second lifetime.
- GL Compatibility only; no dependency on direct `GPUParticles3D.emit_particle()`.
- Never eyeball muzzle transforms.
- Never append data to the stale checked-in schema-2 manifest.
- Never mutate the preserved Blender source.
- Canonical GLB, manifest, and thruster matrix publish transactionally.
- No GitHub Actions.
- No success or verification claim without fresh user-pasted local output.
- Final local verification entry point: `.\tools\verify\verify.ps1`.

---

## Execution Order

### Phase 1 — Canonical fighter muzzle contract

Plan: [`2026-08-03-combat-kernel-1-01-asset-contract.md`](./2026-08-03-combat-kernel-1-01-asset-contract.md)

Delivers:

- schema-5 validator;
- deterministic source-geometry muzzle extraction;
- exact `Weapons/Primary/LeftMuzzle`;
- exact `Weapons/Primary/RightMuzzle`;
- transactional schema-5 GLB/manifest/matrix publication;
- cannon nodes covered by Python and Godot asset tests.

Mandatory checkpoint:

```powershell
.\tools\assets\export-small-fighter.ps1
```

Do not enter Phase 2 until the user pastes output proving schema 5, 12 sockets, 12 source-exact effects, 2 muzzles, preserved source SHA, and extraction/reconstruction error `<= 0.0001 m`.

### Phase 2 — Primary weapon and damage foundation

Plan: [`2026-08-03-combat-kernel-1-02-weapon-damage.md`](./2026-08-03-combat-kernel-1-02-weapon-damage.md)

Delivers:

- LMB/physical-`V` logical input;
- deterministic Left/Right cadence;
- typed `DamagePacket` and `DamageResult`;
- shield, hull, overflow, regeneration, reboot, and hull repair;
- swept `900 m/s` pulse projectiles;
- deterministic projectile pool;
- source-muzzle `PrimaryFireController`.

Entry contract from Phase 1:

```text
VisualRoot/SmallSciFiFighter/Weapons/Primary/LeftMuzzle
VisualRoot/SmallSciFiFighter/Weapons/Primary/RightMuzzle
```

### Phase 3 — Practice drone and collision damage

Plan: [`2026-08-03-combat-kernel-1-03-drone-collision.md`](./2026-08-03-combat-kernel-1-03-drone-collision.md)

Delivers:

- stationary armored practice drone;
- exact three-second drone restoration;
- pure collision-damage formula;
- direct-body contact tracking;
- one event per distinct impact;
- separation/renewed-impact rearming;
- symmetric player/drone ramming damage;
- unchanged rigid-body physics response.

Entry contract from Phase 2:

```gdscript
DamageState.apply_damage(packet: DamagePacket) -> DamageResult
```

### Phase 4 — Shield visuals and combat HUD

Plan: [`2026-08-03-combat-kernel-1-04-visuals-hud.md`](./2026-08-03-combat-kernel-1-04-visuals-hud.md)

Delivers:

- provisional fighter-shaped player shield envelope;
- fitted-ellipsoid drone shield;
- eight pooled localized hex-impact patches;
- low-shield instability and one break flash;
- hull/world spark feedback;
- fighter-forward pipper;
- off-screen edge chevron;
- shield/hull/recharge HUD while preserving existing telemetry.

Entry contract from Phases 2–3:

```gdscript
signal damage_resolved(result: DamageResult)
```

Visual code consumes this signal and never recomputes shield/hull classification.

### Phase 5 — Arena integration and acceptance

Plan: [`2026-08-03-combat-kernel-1-05-integration-verification.md`](./2026-08-03-combat-kernel-1-05-integration-verification.md)

Delivers:

- player combat scene integration;
- arena projectile pool and drone;
- one deterministic arena reset;
- temporary one-second player destruction/reset;
- three-second drone restore;
- cannon calibration scene;
- README/deferred-ledger update;
- final `36`-suite runner;
- full local verification and interactive acceptance.

Final mandatory checkpoint:

```powershell
.\tools\verify\verify.ps1
```

Required evidence:

1. schema-5 fighter validation passes;
2. deterministic thruster matrix validation passes;
3. Godot import exits `0`;
4. test runner prints `PASS: 36 suites`;
5. main scene boots without parser, path, or runtime errors.

---

## Cross-Phase Interface Lock

These names are fixed across all five plans:

```text
Weapons/Primary/LeftMuzzle
Weapons/Primary/RightMuzzle
```

```gdscript
PlayerInputSource.is_primary_fire_held() -> bool
PrimaryFireCadence.advance(held: bool, delta: float) -> Array[int]
PrimaryFireController.set_projectile_pool(pool: PulseProjectilePool)
PrimaryFireController.set_firing_enabled(enabled: bool)
PrimaryFireController.is_firing_enabled() -> bool
PrimaryFireController.reset_runtime_state()
PulseProjectilePool.fire(
    world_transform: Transform3D,
    velocity: Vector3,
    source_body: CollisionObject3D
) -> PulseProjectile
PulseProjectilePool.clear_all()
DamageState.apply_damage(packet: DamagePacket) -> DamageResult
DamageState.set_damage_enabled(enabled: bool)
DamageState.is_damage_enabled() -> bool
DamageState.advance(delta: float)
DamageState.reset_full()
CollisionContactTracker.process_contacts(state: PhysicsDirectBodyState3D)
CollisionContactTracker.clear_contacts()
ShieldVisualController.show_damage(result: DamageResult)
ShieldVisualController.clear_all()
HullImpactEffectController.show_hit(point: Vector3, normal: Vector3)
HullImpactEffectController.clear_all()
CombatPipper.flash_confirmed_hit()
CombatPipper.clear_transient_state()
FlightHud.clear_transient_state()
FlightRoomController.reset_arena()
```

Renaming one of these interfaces during execution requires updating every later phase plan before implementation continues.

## Authoritative Clarifications

These rules override any shorter wording in a phase document:

1. In Phase 1, orient every boundary-loop normal toward source-frame fighter forward `Vector((0, 1, 0))` **before** calling `select_primary_muzzle_pair`; mesh winding must not decide whether a valid mirrored pair is accepted.
2. `DamageState` exposes `set_damage_enabled(enabled: bool)` and `is_damage_enabled()`. Disabled damage intake returns an unchanged zero-application result. `reset_full()` restores full values, clears destruction/timers, and re-enables damage.
3. `PrimaryFireController` exposes `set_firing_enabled(enabled: bool)` and `is_firing_enabled()`. Disabling feeds `false` into cadence immediately. `reset_runtime_state()` resets cadence but does not silently re-enable firing.
4. `CollisionDamageModel.compute` has signature `compute(relative_normal_speed, effective_mass, tuning, bypass_minimum_mass := false)`. Mass below `25.0 kg` returns zero unless `bypass_minimum_mass` is true; the tracker passes true only for colliders in group `damaging_collision`.
5. `CombatPipper.clear_transient_state()` and `FlightHud.clear_transient_state()` are required reset interfaces.
6. The practice drone's checked-in arena transform is exactly `position = Vector3(0, 0, -140)` with identity rotation and scale.
7. Arena reset explicitly re-enables both `ShipFlightController` and `PrimaryFireController` after all state/effect cleanup is complete.

## Commit Sequence

The intended review gates are:

1. `test: define schema five muzzle contract`
2. `feat: publish schema five fighter muzzles`
3. `feat: add deterministic primary fire cadence`
4. `feat: add reusable shield and hull damage state`
5. `feat: add swept pulse projectile weapon`
6. `feat: add armored practice drone`
7. `feat: route physical impacts through damage state`
8. `feat: add localized shield and hull impact visuals`
9. `feat: add fighter forward combat HUD`
10. `feat: integrate combat components with player fighter`
11. `feat: complete combat arena lifecycle`
12. `feat: add cannon socket calibration scene`
13. `docs: finalize Combat Kernel 1 verification`

Every commit must have its focused tests run before proceeding.

## Final Acceptance Boundary

Combat Kernel 1 includes:

- pulse cannon input/cadence/projectiles;
- stationary drone;
- shield/hull damage and recovery;
- collision damage;
- player/drone shield visuals;
- pipper/HUD;
- deterministic reset;
- calibration and verification.

It excludes:

- Camera C1;
- moving enemy fighters;
- enemy AI or weapons;
- heavy plasma;
- ammunition/reload/heat;
- target lead, lock, or aim assist;
- destructible asteroids;
- advanced shield deformation;
- persistent scorch decals;
- polished production audio;
- wreckage, debris, cinematic destruction, kill cameras, or replay cameras.

## Plan Self-Review

- Each approved feature maps to exactly one phase plan.
- The phase order prevents runtime code from depending on unverified muzzle transforms.
- Asset publication remains transactional.
- Existing schema-4 thruster guarantees remain required under schema 5.
- Damage arithmetic has one owner.
- Visuals and HUD consume results without applying damage.
- Collision damage does not alter physical response.
- Player and drone lifecycles converge on deterministic reset contracts.
- All values match the approved design.
- No unresolved implementation choice is delegated back to the user.
- Final acceptance requires fresh local evidence.
