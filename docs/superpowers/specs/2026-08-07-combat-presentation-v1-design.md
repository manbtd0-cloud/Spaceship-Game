# Combat Presentation v1 — Design

**Date:** 2026-08-07
**Status:** Approved for implementation
**Target:** `agent/playable-flight-room`

## Goal

Make the verified one-on-one tactical dogfight read and feel like a cinematic tactical sci-fi encounter without changing the player controls, dogfight balance, projectile hit probability, flight model, firing legality, or enemy tactical rules. This milestone also owns diagnosis and root-cause repair of the intermittent visible ship/model vibration reported during flight.

## Locked direction

- Full presentation pass.
- Cinematic tactical sci-fi visual language.
- Staged cinematic enemy destruction.
- Strong but disciplined normal-hit feedback.
- Enemy thrusters are physically faithful and driven by actual bounded force/torque.
- Heavy cinematic military sci-fi audio.
- Selective, restrained combat camera response.

## Scope

### In

1. Dynamic enemy thruster VFX driven by the real force/torque produced by `EnemyFighterController`.
2. Stronger localized shield-hit and hull-hit presentation.
3. Staged hostile-fighter destruction: shield collapse where applicable, internal flashes/sparks, core detonation, plasma/shockwave, lightweight curated debris, self-cleanup, existing respawn handoff.
4. Spatialized weapon, shield, hull, thruster, and explosion audio.
5. Selective camera impulses for meaningful player damage, shield break, collisions, and nearby hostile destruction.
6. Hostile visual-identity polish that does not require the final enemy model.
7. Systematic diagnosis and root-cause fix for intermittent model/camera vibration.

### Out

- control redesign;
- dogfight AI retuning;
- projectile hit-probability changes;
- weapon balance changes;
- multi-enemy/fleet expansion;
- missiles, heavy plasma, beams, lock-on;
- final dedicated enemy model;
- full mesh fracture.

The currently reported poor dogfight feel and bullets missing too often are a separate later gameplay/combat-feel milestone and must be recorded in the deferred roadmap.

## Architecture

Presentation is a consumer of simulation state, never the simulation authority.

### Enemy thruster presentation

A dedicated adapter reads the enemy controller's actual applied world force/torque (`get_last_force_world()` / `get_last_torque_world()`), transforms those outputs into local maneuver authority, and drives only the verified schema-5 nozzle effects that physically correspond to the maneuver. Intensity is normalized to configured authority and cannot imply more thrust/torque than the controller applies. Plumes use source-exact existing geometry with smooth rise/fall, controlled emission, heat glow, and restrained variation.

### Impact presentation

Existing `DamageState` events remain authoritative. Shield presentation reacts only to shield damage and shield break. Hull presentation reacts only to hull damage. Presentation never calculates or mutates damage.

Shield hits: localized hex flare, directional ripple, brighter impact center, restrained directional sparks/electrical fragments, short energy-crack sound. Shield break: stronger brief full-shell collapse pulse.

Hull hits: directional sparks/hot fragments, brief incandescent impact flash, metallic/electrical impact sound. No permanent expensive damage simulation in v1.

### Destruction presentation

The existing enemy destruction lifecycle remains authoritative. Presentation layers on top:

- T+0.00: combat disabled by existing lifecycle; final shield-collapse energy if appropriate.
- T+0.05–0.20: internal flashes, sparks, buildup.
- ~T+0.20: compact core detonation.
- Immediately after: expanding plasma/fireball, translucent shockwave, energetic fragments, a few lightweight debris pieces inheriting believable ship momentum.
- Tail: effects and debris self-clean; existing respawn lifecycle restores the fighter.

No fracture system and no change to respawn timing.

### Audio

Combat audio is event-driven and spatialized in 3D. Categories: player pulse, enemy pulse, shield hit, shield collapse, hull impact, enemy thruster, explosion transient, explosion low-frequency tail, debris/spark tail. Where external assets are not necessary, deterministic generated/bundled audio may be used so repository reconstruction remains self-contained. All required files/configuration live in GitHub.

### Camera feedback

A separate combat-feedback component produces presentation-only camera impulses. Normal enemy hits do not shake the camera. Light player shield damage is tiny; shield break and significant collisions are stronger; nearby hostile destruction gives a restrained low-frequency kick; distant destruction is negligible. Camera impulses must never modify ship physics state.

## Vibration/glitch diagnostic gate

Do not mask the reported vibration with arbitrary smoothing. Diagnose first under `systematic-debugging`.

Observe independently:

- player rigid-body transform, linear velocity, angular velocity;
- player visual-root/model local and global transform;
- chase-camera target/pivot/final transform;
- physics-tick versus rendered-frame transform sampling;
- enemy fighter independently where useful.

Reproduce across stationary, coasting, translation, rotation-only, acceleration, AI Assisted, Smart Stabilize, high speed, collision proximity, and Close/Standard/Far camera distances.

Current evidence makes render/physics transform sampling a high-priority hypothesis: `ChaseCameraRig` updates in `_process()` while sampling a physics-driven `RigidBody3D` with ordinary `global_transform`. That can expose 60 Hz physics steps to a render-rate camera. This is a hypothesis until reproduced by a regression/diagnostic test.

If confirmed, the root-cause repair should use Godot physics interpolation correctly: enable project physics interpolation, sample physics targets via `get_global_transform_interpolated()` for render-frame camera calculations, and reset interpolation correctly around explicit teleports/resets. It must preserve true physical motion and inertial zero-drift.

## Stability and performance boundaries

- VFX and audio instances are bounded/reused or guaranteed to self-clean.
- No per-frame unbounded allocation during combat.
- No presentation code writes player/enemy live transform, velocity, damage, targeting, or firing legality.
- No GitHub Actions required for verification.
- Existing schema-5 geometry/matrix contracts remain authoritative.

## Verification gate

Automated coverage must prove:

- enemy thruster activation corresponds to real applied maneuver authority;
- presentation intensity cannot exceed normalized authority;
- shield and hull impacts trigger the correct presentation paths;
- destruction sequencing is deterministic enough to test and cleans all temporary presentation nodes;
- respawn remains correct;
- audio instances remain bounded/clean;
- camera impulses do not mutate physics state;
- the identified jitter regression is fixed at its actual source;
- all pre-existing 50 suites remain green.

Repository gate also requires schema-5 validation, deterministic thruster-matrix validation, inertial rigid-body preservation, and main-scene runtime smoke without parser/path/runtime/shader errors.

Manual acceptance judges visual/audio quality and confirms the intermittent visible vibration is gone under ordinary play.

## Persistence rule

GitHub is the only persistent project state. The sandbox is disposable. Code, scripts, configs, docs, manifests, generated source assets needed for verification, and verified milestone records must be committed. Tool binaries may be re-extracted in a fresh environment. No milestone may depend on `/mnt/data`, caches, symlinks, or an unpushed local worktree surviving.
