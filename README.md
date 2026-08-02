# Shattered Orbit

A single-player, third-person space-flight vertical slice built with Godot 4.7.1 and typed GDScript.

## Current milestone

The playable flight room provides:

- six-axis local-space thrust;
- assisted nose-led maneuvering and coordinated banking;
- fully inertial manual flight;
- total-speed soft envelopes at 160 m/s normally and 240 m/s under boost;
- sustained translational boost with thermal lockout;
- a ship-relative chase camera with no global horizon;
- the canonical Small Sci-Fi Fighter at identity transform;
- twelve semantic thruster channels driven by final local force and torque;
- four imported asteroid families and a deterministic collidable field;
- a high-speed navigation course, telemetry HUD, collisions, and safe reset handling.

The temporary model adapter, rear-only glow anchors, and procedural exhaust cones have been removed.

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
| `Escape` | Release / recapture mouse |
| `R` | Reset to spawn, clear momentum, and reset boost heat |

## Canonical fighter

The generated runtime files are:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
```

The schema-3 contract establishes:

```text
Godot right/forward/up: +X / -Z / +Y
Root transform: identity
Canonical hull size: 13.714 × 3.562 × 12.000 m
Collider: 14.0 × 3.8 × 12.2 m
Sockets: 2 main + 2 retro + 8 maneuver
Effect meshes: 2 main + 2 retro + 8 maneuver
Visual strategy: exact evaluated EngineFire vertices and faces
Procedural exhaust geometry: forbidden
Runtime effect transform correction: forbidden
```

### Why the effect geometry is exact

The preserved Blender source already contains the exhaust meshes authored against the real vents. The schema-3 exporter:

1. identifies the twelve physical plume groups from the eleven `EngineFire*` objects;
2. preserves the exact raw mesh-component indices;
3. copies their evaluated vertices and faces;
4. transforms them through the same approved `Cube`-local centering and scale used by the hull;
5. exports them as identity-transform meshes under `ThrusterEffects`;
6. records counts, bounds, source components, and a SHA-256 geometry digest for every effect.

Godot does not create replacement cones and does not move, rotate, or scale these effect meshes. Runtime code changes only visibility, alpha, and emission energy.

Generate and validate:

```powershell
python -m unittest `
  tests.tools.test_small_fighter_calibration `
  tests.tools.test_fighter_socket_names `
  tests.tools.test_source_exact_thruster_geometry `
  tests.tools.test_canonical_fighter_v3 `
  tests.tools.test_verify_scripts `
  -v

.\tools\assets\export-small-fighter.ps1
.\tools\verify\verify.ps1
```

Do not accept an older schema-2 manifest. Both local verifiers require schema 3, twelve exact effect paths, identity effect transforms, and valid geometry digests.

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
PASS: 19 suites
```

Do not claim the milestone verified until the verifier imports the project, runs every suite, and boots the main scene without parser, path, or runtime errors.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/`. Runtime scenes may load only Godot-ready assets under `assets/runtime/`; gameplay must not point directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.
