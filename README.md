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
- the audit-backed canonical Small Sci-Fi Fighter at identity transform;
- twelve imported thruster sockets driven by the final local force and torque;
- a high-speed navigation course, telemetry HUD, collisions, and safe reset handling.

The temporary runtime alignment adapter and rear-only glow anchors have been removed. The canonical fighter dimensions are approximately `13.714 × 3.562 × 12.000 m`, and its gameplay collider is `14.0 × 3.8 × 12.2 m`.

The next generated-asset gate is the four-family asteroid pack. Its Blender/Python pipeline, reusable collidable asteroid body, deterministic sixteen-asteroid layout, and injectable field builder are committed. The flight room is not allowed to reference those runtime GLBs until all four outputs have been generated and validated locally.

## Requirements

- Godot 4.7.1 Standard
- GL Compatibility renderer
- PowerShell on Windows, or Bash on Linux
- Blender 5.2 LTS for canonical asset generation
- Python 3 for asset-contract validation

No external Godot add-ons or runtime dependencies are required.

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
| `Up` / `Down` | Digital pitch up / down |
| `Left` / `Right` | Roll left / right |
| `Shift` | Sustained translational boost |
| `F` | Toggle assisted / manual flight |
| `Escape` | Release / recapture mouse |
| `R` | Reset to spawn, clear momentum, and reset boost heat |

Left Arrow produces left roll and Right Arrow produces right roll.

## Flight behavior

### Assisted mode

- Forward thrust gradually curves velocity toward the nose.
- Lateral and vertical drift are damped without cancelling forward momentum.
- Yaw generates restrained coordinated banking up to approximately 22 degrees.
- Direct roll overrides generated banking.
- Steering remains force- and torque-based.

### Manual mode

Manual flight removes velocity steering, drift damping, automatic banking, and angular damping. Translation direction and orientation remain independent until counter-thrust or counter-rotation is applied.

### Speed and boost

- Normal increasing-speed thrust fades from 120 to 160 m/s.
- Boosted increasing-speed thrust fades from 180 to 240 m/s.
- Braking and redirection remain available above either envelope.
- Ending boost above 160 m/s preserves excess momentum.
- Continuous active boost overheats in approximately 12 seconds.
- Boost recovers after approximately 6 seconds and fully cools in approximately 15 seconds.
- Overheat disables boost only.

## Camera orientation

Space has no preferred upright direction. The chase camera uses the ship's local up axis when rolled, inverted, or vertical and never blends back toward global `Vector3.UP`.

## Canonical fighter

The committed runtime files are:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
```

The schema-2 manifest establishes:

```text
Godot right/forward/up: +X / -Z / +Y
Root transform: identity
Canonical size: 13.714 × 3.562 × 12.000 m
Collider: 14.0 × 3.8 × 12.2 m
Sockets: 2 main + 2 retro + 8 maneuver
Baked EngineFire geometry: removed
Runtime alignment correction: none
```

Regenerate and validate it with:

```powershell
python -m unittest tests.tools.test_small_fighter_calibration -v
.\tools\assets\export-small-fighter.ps1
```

The runtime visual controller reads the final local force and torque produced by the flight model. This means pilot thrust, assisted steering, angular damping, drift correction, and automatic banking all drive the appropriate socket effects. Idle output is fully hidden.

## Four-source asteroid pack

All four supplied sources are mandatory:

```text
assets/source/environment/asteroids/bennu/asteroid_bennu_textured.blend
assets/source/environment/asteroids/eros/asteroid_eros_true_color.glb
assets/source/environment/asteroids/legacy_a/asteroid_legacy_a.blend
assets/source/environment/asteroids/legacy_b/asteroid_legacy_b.blend
```

Extract `asteroid_source_pack.zip` into the repository root, then run:

```powershell
python -m unittest tests.tools.test_asteroid_pack -v
.\tools\assets\export-asteroid-pack.ps1
```

If Blender is not detected automatically:

```powershell
.\tools\assets\export-asteroid-pack.ps1 `
  -BlenderBin "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
```

The pipeline generates:

```text
assets/runtime/environment/asteroids/bennu.glb
assets/runtime/environment/asteroids/eros.glb
assets/runtime/environment/asteroids/legacy_a.glb
assets/runtime/environment/asteroids/legacy_b.glb
```

Each GLB has a sibling manifest. Every family is centered, uniformly scaled to a 100 m longest dimension, cleaned of cameras/lights/flat helper geometry, and exported with a reduced `CollisionProxy-convcolonly` mesh. The flight-room asteroid field is integrated only after all four manifests pass `asteroid_pack_contract.py`.

Eros includes embedded CC BY 4.0 attribution. The other three sources remain development-only until their original license evidence is recorded. See:

```text
assets/licenses/asteroids/PROVENANCE.md
```

## Verify locally

### Windows PowerShell

```powershell
.\tools\verify\verify.ps1
```

Or:

```powershell
.\tools\verify\verify.ps1 -GodotBin "C:\path\to\Godot_v4.7.1-stable_win64.exe"
```

### Linux Bash

```bash
GODOT_BIN="$HOME/Packages/Godot_v4.7.1-stable_linux.x86_64" ./tools/verify/verify.sh
```

The pre-asteroid-generation runner target is:

```text
PASS: 19 suites
```

Do not claim the milestone verified until the Windows verifier imports the project, runs all suites, and boots the main scene without parser, path, or runtime errors.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/` or the quarantined legacy `Resources/` folder. Runtime scenes may load only Godot-ready assets under `assets/runtime/`; gameplay must not point directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.
