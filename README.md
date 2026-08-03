# Shattered Orbit

A single-player, third-person space-flight vertical slice built with Godot 4.7.1 and typed GDScript.

## Current milestone

The playable flight room provides:

- six-axis local-space thrust;
- assisted nose-led maneuvering and coordinated banking;
- fully inertial manual flight;
- total-speed soft envelopes at 160 m/s normally and 240 m/s under boost;
- sustained translational boost with thermal lockout;
- a ship-relative chase camera with bounded Close, Standard, and Far presets;
- the canonical Small Sci-Fi Fighter at identity transform;
- twelve source-exact nozzle-local thruster effects;
- deterministic mappings for twelve pilot actions;
- separate direct-pilot and dim assisted-correction visuals;
- nozzle-anchored rise and fall envelopes;
- four imported asteroid families and a deterministic collidable field;
- a high-speed navigation course, telemetry HUD, collisions, and safe reset handling.

The temporary model adapter, rear-only glow anchors, procedural exhaust cones, and free-form runtime thruster allocator have been removed.

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
| `F` | Toggle assisted / manual flight |
| `C` | Cycle Standard / Far / Close chase-camera presets |
| `Escape` | Release / recapture mouse |
| `R` | Reset to spawn, clear momentum, and reset boost heat |

## Canonical fighter and thrusters

The generated and checked-in files are:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
config/ships/small_sci_fi_fighter_thruster_actions.json
```

The schema-4 contract establishes:

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

### Why plume growth stays attached

The preserved Blender source contains exhaust meshes authored against the real vents. The schema-4 exporter:

1. identifies twelve physical plume groups from the eleven `EngineFire*` objects;
2. preserves the exact evaluated source vertices, faces, and component indices;
3. extracts a verified socket position and basis for every physical nozzle;
4. converts each plume from canonical ship space into its nozzle-local coordinate frame;
5. reconstructs every canonical vertex and rejects error above `0.0001 m`;
6. exports the effect node at the verified nozzle transform;
7. records its socket pair, local axis, transform, bounds, geometry digest, and reconstruction error.

At full output, the authored source geometry is reconstructed exactly. Runtime scaling changes only the local plume length and radius while its node origin remains fixed at the nozzle.

### Activation behavior

Direct exhaust comes from the current pilot command, never retained velocity:

```text
input held → approved direct thrusters rise toward full output
input released → direct thrusters decay to invisible
ship still coasting → no direct exhaust
```

Assisted damping, stabilization, and automatic banking use the same checked-in action matrix, but their visual target is capped exactly once at 35 percent. Direct output always dominates when both channels request the same thruster.

The action matrix explicitly requires both main thrusters for forward acceleration and both retro thrusters for reverse acceleration. It is generated and validated offline, then checked into the repository; gameplay never solves or reshuffles mappings dynamically.

Generate and validate all three publication outputs transactionally:

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

The exporter writes pending GLB, manifest, and matrix files. It validates all three before replacing live files and restores backups if publication itself fails.

## Thruster calibration scene

Launch the development-only calibration scene with:

```powershell
godot --path . res://scenes/debug/thruster_calibration.tscn
```

Controls:

```text
Left / Right  previous / next calibration case
Space         pause / resume output
Escape        exit
```

The scene cycles all twelve direct actions plus assisted translation and assisted rotation. It uses the production player scene, production visual controller, and production checked-in action matrix. The report displays each active effect path, force, torque, direct target, raw assist target, merged target, and current envelope.

## Primary fire showcase

Launch the development-only production firing showcase with:

```powershell
godot --path . res://scenes/debug/primary_fire_showcase.tscn
```

Controls:

```text
LMB / physical V  hold primary fire
R                 clear projectiles and reset cadence/counters
Escape            exit showcase
```

The showcase uses the production player scene, verified schema-5 left/right muzzle sockets, production seven-shots-per-second cadence, swept 900 m/s pulse projectiles, deterministic 32-projectile pool, source-body exclusion, and first-hit cleanup. The fighter remains stationary in a controlled neon firing lane so alternating muzzle fire and projectile behavior can be inspected directly.

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

Each family is centered, uniformly scaled to a 100 m longest dimension, cleaned of cameras/lights/flat helper geometry, and exported with a reduced `CollisionProxy-convcolonly` mesh.

Eros includes embedded CC BY 4.0 attribution. The other three sources remain development-only until original license evidence is recorded. See:

```text
assets/licenses/asteroids/PROVENANCE.md
```

## Verify locally

### Windows

```powershell
.\tools\verify\verify.ps1
```

### Linux

```bash
GODOT_BIN="$HOME/Packages/Godot_v4.7.1-stable_linux.x86_64" ./tools/verify/verify.sh
```

The current runner target is:

```text
PASS: 27 suites
```

Do not claim the milestone verified until the verifier validates schema 4 and the deterministic matrix, imports the project, runs every suite, and boots the main scene without parser, path, or runtime errors.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/`. Runtime scenes may load only Godot-ready assets under `assets/runtime/`; gameplay must not point directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.