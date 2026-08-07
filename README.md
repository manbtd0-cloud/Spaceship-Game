# Shattered Orbit

A single-player, third-person space-flight vertical slice built with Godot 4.7.1 and typed GDScript.

## Current milestone

The playable flight room provides:

- six-axis local-space thrust;
- agile-fighter authority with 150 kN forward/strafe thrust, 110 kN reverse thrust, and 190/230/210 kNm pitch/yaw/roll torque;
- smooth physical angular-rate envelopes at 100 deg/s pitch, 100 deg/s yaw, and 150 deg/s roll;
- full opposing counter-torque above every angular limit;
- the established Assisted nose-led maneuvering and coordinated banking;
- full-authority AI Assisted flight that continuously redirects real velocity toward the ship's nose through legal physical thrust;
- fully inertial flight with exact world-velocity preservation under pure rotation;
- hold-to-use Smart Stabilize that simultaneously counters all local linear and angular velocity axes;
- automatic control capped to the same force, torque, combined-input, and effective-boost authority available to direct player control;
- total-speed soft envelopes at 160 m/s normally and 240 m/s under boost;
- sustained translational boost with thermal lockout;
- Dynamic, Tactical, and Locked chase-camera behaviors;
- independent Close, Standard, and Far camera distances;
- exact hold views for rear, right, and left observation;
- a fixed nose reticle and a true world-velocity marker with safe-edge clamping;
- a process-always pause menu with persistent camera and three-mode flight settings;
- the canonical Small Sci-Fi Fighter at identity transform;
- twelve source-exact nozzle-local player thruster effects and deterministic mappings for twelve pilot actions;
- four imported asteroid families and a deterministic collidable field;
- shield-first projectile/collision damage with localized procedural hex shield impacts;
- one physically simulated tactical hostile fighter with independent thrust/torque/speed tuning;
- predictive pulse-cannon return fire using the same 900 m/s, 15-damage projectile architecture as the player;
- tactical pursuit, range/closure control, overshoot handling, disengage/re-entry, and threat-aware evasive breaks;
- physically faithful hostile thruster presentation driven by the enemy controller's actual bounded force/torque through the verified schema-5 matrix;
- stronger localized shield and hull hit presentation with bounded effect pools;
- staged hostile destruction with rupture buildup, core detonation, expanding shockwave, bounded debris, and clean respawn handoff;
- deterministic spatialized combat audio using a fixed seven-emitter pool and in-engine generated source audio;
- selective camera feedback for meaningful player damage, shield break, collision pressure, and nearby hostile destruction;
- render/physics-interpolated chase-camera target sampling that removes the previously identified visible vibration caused by render frames sampling discrete physics transforms;
- a high-speed navigation course, telemetry/combat HUD, collisions, primary fire, and pause-safe reset handling.

The tactical enemy never teleports or overwrites live velocity/orientation to obtain a firing solution. Active enemy maneuvering is produced through bounded `RigidBody3D.apply_central_force()` and `apply_torque()` calls. Transform and velocity writes are reserved for frozen reset/respawn lifecycle operations.

Combat Presentation v1 is deliberately a presentation/stability layer. It does **not** claim to solve the subjective dogfight-feel problem. The current controls, aiming experience, and practical projectile connectivity are recorded as a separate deferred gameplay milestone in `docs/superpowers/plans/deferred-milestones.md`.

## Requirements

- Godot 4.7.1 Standard
- GL Compatibility renderer
- Blender 5.2 LTS for canonical asset generation
- Python 3 for asset-contract validation
- PowerShell on Windows, or Bash on Linux

## Run

```powershell
godot --path .
```

## Controls

| Input | Action |
|---|---|
| `W` / `S` | Forward / reverse thrust |
| `Q` / `E` | Strafe left / right |
| `Space` / `Ctrl` | Vertical strafe up / down |
| Mouse | Analog pitch / yaw |
| `A` / `D` | Digital yaw left / right |
| `Down` | Nose up |
| `Up` | Nose down |
| `Left` / `Right` | Roll left / right |
| `Shift` | Sustained translational boost |
| `F` | Cycle Assisted / AI Assisted / Inertial flight |
| `X` | Hold Smart Stabilize |
| `LMB` / `V` | Hold primary fire |
| `C` | Cycle Standard / Far / Close camera distance |
| `B` | Hold exact rear view |
| `PageUp` | Hold exact right view |
| `PageDown` | Hold exact left view |
| `Escape` | Pause / resume and open configuration |
| `R` | Reset player and hostile fighter to spawn, clear momentum/projectiles, and reset boost heat |

The three flight modes remain distinct:

- **Assisted** retains the established nose-led steering, damping, and coordinated bank.
- **AI Assisted** continuously drives the true velocity vector toward ship-forward. Large velocity-marker separation requests full legal player-equivalent authority; correction tapers near the nose reticle. Explicit strafe, vertical, reverse, and rotation inputs remain authoritative.
- **Inertial** keeps true momentum and receives no automatic force or torque.

Smart Stabilize is not another mode. While `X` is held, it suppresses ordinary movement commands and applies legal opposing thrust and torque on every active local velocity axis. Releasing `X` returns control to the selected mode without snapping velocity or changing the mode.

Automatic flight control never exceeds the ship's direct-control limits. AI pilot output and automatic correction are combined before force generation, so they cannot stack beyond one legal command. Boosted automatic authority exists only while `Shift` is held and boost is thermally available.

The pause menu writes only through the typed `PlayerSettingsService` and persists:

```text
camera.behavior
camera.distance
flight.default_mode
```

Settings are stored in `user://settings.cfg`.

## Canonical fighter and thrusters

The generated and checked-in files are:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
config/ships/small_sci_fi_fighter_thruster_actions.json
```

The schema-5 contract establishes:

```text
Godot right/forward/up: +X / -Z / +Y
Root transform: identity
Canonical hull size: 13.714 × 3.562 × 12.000 m
Collider: 14.0 × 3.8 × 12.2 m
Sockets: 2 main + 2 retro + 8 maneuver
Effect meshes: 2 main + 2 retro + 8 maneuver
Visual strategy: exact evaluated EngineFire geometry in nozzle-local coordinates
Maximum reconstruction error: 0.0001 m
Procedural exhaust geometry: forbidden
Runtime matrix generation: forbidden
```

The schema-5 exporter preserves the exact evaluated source vertices, extracts a verified socket position/basis for every physical nozzle, converts each plume into nozzle-local coordinates, reconstructs canonical vertices under a `0.0001 m` error gate, and records the geometry/mapping contract in the checked-in manifest.

### Player thruster activation

Direct exhaust comes from the current pilot command, never retained velocity:

```text
input held → approved direct thrusters rise toward full output
input released → direct thrusters decay to invisible
ship still coasting → no direct exhaust
```

All automatic player output uses the same checked-in action matrix. AI Assisted and Smart Stabilize display direction-correct applied authority and may reach full output, while direct output retains precedence when direct and automatic requests overlap.

### Enemy thruster activation

The hostile fighter reuses the canonical airframe, but its twelve imported source-exact effect meshes are no longer hidden as an all-or-nothing group. `EnemyThrusterVisualController` reads the enemy controller's **actual applied world force and torque**, converts them to local normalized authority, and feeds that command through the same checked-in `ThrusterActionMatrix`.

Only physically relevant nozzles illuminate. Visual targets remain in `[0,1]` and cannot imply more authority than the enemy controller actually applied. Source nozzle pivots and raw GLB data remain untouched.

Generate and validate the canonical fighter outputs with:

```powershell
python -m unittest `
  tests.tools.test_small_fighter_calibration `
  tests.tools.test_fighter_socket_names `
  tests.tools.test_source_exact_thruster_geometry `
  tests.tools.test_canonical_fighter_v4 `
  tests.tools.test_fighter_thruster_action_contract `
  tests.tools.test_verify_scripts `
  -v

.\tools\assets\export-small-fighter.ps1
.\tools\verify\verify.ps1
```

## Tactical enemy dogfight

The default flight room contains exactly one `EnemyFighter`. The old `PracticeDrone` scene remains available as a training/reference asset but is no longer active in the production room.

The enemy uses independently tunable physical authority and a deterministic tactical state model:

```text
ACQUIRE → ATTACK / RANGE_CONTROL → DISENGAGE → REENTRY
                             ↘ EVADE when observable threat is credible
```

Predictive aiming solves a future intercept from both ships' world positions/velocities and the shared `PulseProjectile.DEFAULT_SPEED` of `900 m/s`. A shot is legal only when the solution is valid, the player is within the configured range and firing cone, cadence permits it, the enemy is active, and the physics ray has clear line of sight. Pulse rounds do not home or bend after firing.

Threat-aware evasion uses observable player-facing geometry and nearby hostile projectile activity. It does not read player input or predict which individual projectile will hit. Hostile projectile pressure is local: projectiles outside the configured `220 m` awareness radius do not trigger evasive state.

## Combat Presentation v1

### Render/physics vibration repair

The reported intermittent model/camera vibration was traced to the render-frame chase camera sampling ordinary transforms from a physics-driven target while physics interpolation was disabled. The repair enables project physics interpolation, keeps the render-driven chase rig on manual interpolation, samples the target through `get_global_transform_interpolated()`, and resets interpolation at explicit teleport/pool-reuse boundaries.

This is a render/presentation repair, not extra physical damping. Inertial movement, Smart Stabilize, AI Assisted flight, and the rigid-body velocity-preservation contract remain unchanged.

### Shield and hull impacts

Shield damage retains the localized procedural hex shell but receives a sharper impact core, wider energy halo, stronger cell contrast, and stronger break presentation. Hull damage is routed separately through `HullImpactVisualizer`: a fixed four-slot pool provides directional sparks and a brief incandescent impact flash. Shield-only hits never emit hull sparks, and ignored damage emits no false presentation.

### Hostile destruction

Enemy destruction uses a deterministic presentation timeline layered on the existing three-second respawn lifecycle:

```text
0.00–0.20 s  rupture buildup / internal flashes
0.20–0.55 s  core detonation
0.22–1.15 s  expanding shockwave
0.20–1.40 s  five bounded debris fragments / energy tail
>=1.40 s     temporary presentation fully cleaned
3.00 s       existing enemy respawn authority restores the fighter
```

The debris presentation inherits cached pre-destruction ship momentum, but it is presentation-only and does not replace the enemy's physical lifecycle.

### Combat audio

The production room owns one `CombatAudioController` with exactly seven preallocated `AudioStreamPlayer3D` emitters. It routes player/enemy pulse fire, shield hits/breaks, hull impacts, enemy thruster output, hostile explosion, and debris tail into dedicated `Ship`, `Weapons`, `Impacts`, and `Environment` buses.

The seven source streams are generated deterministically in code by `CombatAudioSynth` as PCM16/44.1 kHz audio. This intentionally avoids downloaded audio dependencies and makes a fresh disposable environment fully reconstructible from GitHub source alone.

### Selective camera response

`CombatCameraFeedbackController` owns only the `Camera3D` child's local presentation offset. Ordinary hits **on the enemy** do not shake the player camera. Player damage creates a small bounded impulse; collisions and shield break are stronger; hostile destruction is distance-attenuated to zero beyond the configured presentation range.

The feedback layer never mutates player transform, linear velocity, angular velocity, or the chase rig's physical/render target state.

## Debug scenes

### Thruster calibration

```powershell
godot --path . res://scenes/debug/thruster_calibration.tscn
```

The scene cycles direct actions plus assisted translation/rotation using the production player scene, visual controller, and checked-in action matrix.

### Primary fire showcase

```powershell
godot --path . res://scenes/debug/primary_fire_showcase.tscn
```

The showcase uses the production player scene, verified schema-5 muzzle sockets, seven-shots-per-second cadence, swept 900 m/s pulse projectiles, deterministic 32-projectile pool, source-body exclusion, and first-hit cleanup.

## Four-source asteroid pack

The required sources are:

```text
assets/source/environment/asteroids/bennu/asteroid_bennu_textured.blend
assets/source/environment/asteroids/eros/asteroid_eros_true_color.glb
assets/source/environment/asteroids/legacy_a/asteroid_legacy_a.blend
assets/source/environment/asteroids/legacy_b/asteroid_legacy_b.blend
```

Generate them with:

```powershell
python -m unittest tests.tools.test_asteroid_pack -v
.\tools\assets\export-asteroid-pack.ps1
```

Eros includes embedded CC BY 4.0 attribution. The other three sources remain development-only until original license evidence is recorded. See `assets/licenses/asteroids/PROVENANCE.md`.

## Verify locally

### Windows

```powershell
.\tools\verify\verify.ps1
```

### Linux

```bash
GODOT_BIN="$HOME/Packages/Godot_v4.7.1-stable_linux.x86_64" bash ./tools/verify/verify.sh
```

The current runner target is:

```text
PASS: 61 suites
```

The Combat Presentation v1 verification gate also requires:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: inertial rigid-body velocity preservation
speed drift: 0.000000000 m/s
direction drift: 0.000000000 degrees
```

A real main-scene runtime smoke must also remain alive for several physics seconds without parser, invalid-call, node-path, shader, resource-load, or repeated runtime errors.

Do not claim a milestone verified until the verifier validates the schema-5 fighter contract and deterministic matrix, imports the project, runs every suite, verifies real rigid-body inertial preservation, and boots the main scene cleanly.

## Disposable-environment recovery

**GitHub is persistent project state; the sandbox is a disposable workstation.** Do not rely on `/mnt/data`, caches, extracted binaries, symlinks, `.godot/`, or local worktrees surviving between sessions.

A fresh environment should restore Godot, reconstruct/checkout the current GitHub branch, import the project, run the verifier, and continue only from that verified GitHub head. The detailed recovery procedure is in:

```text
docs/development/disposable-environment-recovery.md
```

An older uploaded ZIP may be used only as a bulk cache for unchanged files after authoritative GitHub changes are overlaid and the baseline verification is rerun.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/`. Runtime scenes may load only Godot-ready assets under `assets/runtime/`; gameplay must not point directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.
