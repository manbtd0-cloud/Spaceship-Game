# Shattered Orbit

A single-player, third-person space-flight vertical slice built with Godot 4.7.1 and typed GDScript.

## Current milestone

The playable flight room provides:

- six-axis local-space thrust;
- assisted nose-led maneuvering and coordinated banking;
- fully inertial manual flight;
- total-speed soft envelopes at 160 m/s normally and 240 m/s under boost;
- sustained all-axis translational boost with thermal lockout;
- a ship-relative chase camera with no global horizon;
- a high-speed navigation course, telemetry HUD, collisions, and safe reset handling.

The currently committed runtime fighter still uses the temporary alignment and rear-glow layer. That scene is not the final visual target. The audit-backed canonical exporter is now authoritative, and runtime integration begins only after its replacement GLB and schema-2 manifest are generated and pushed.

## Requirements

- Godot 4.7.1 Standard
- GL Compatibility renderer
- PowerShell on Windows, or Bash on Linux
- Blender 5.2 LTS when auditing or exporting the hero fighter
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

## Audit evidence

Generate or refresh the non-destructive Blender audit with:

```powershell
.\tools\assets\audit-small-fighter.ps1
```

The committed evidence is under:

```text
artifacts/hero_ship_audit/
```

The approved calibration record is:

```text
docs/superpowers/specs/2026-08-02-small-sci-fi-fighter-calibration-record.md
```

It establishes:

```text
Source frame: Cube local axes
Blender forward/up: +Y / +Z
Godot forward/up: -Z / +Y
Canonical size: 13.714 × 3.562 × 12.000 m
Approved collider: 14.0 × 3.8 × 12.2 m
Sockets: 2 main + 2 retro + 8 maneuver
Baked EngineFire geometry: removed
Runtime correction after integration: none
```

## Generate the canonical fighter

Run the pure contracts first:

```powershell
python -m unittest tests.tools.test_small_fighter_calibration -v
```

Generate the canonical GLB and manifest:

```powershell
.\tools\assets\export-small-fighter.ps1
```

If Blender is not detected automatically:

```powershell
.\tools\assets\export-small-fighter.ps1 `
  -BlenderBin "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
```

The command:

- verifies the preserved source SHA before and after Blender;
- converts retained geometry into approved `Cube` local space;
- removes all eleven `EngineFire*` source objects from the derivative;
- disables permanent exhaust emission on physical nozzle hardware;
- centers and uniformly scales the hull;
- measures twelve socket locations and exhaust directions from the baked plume geometry;
- exports an identity-root GLB with `Thrusters/Main`, `Thrusters/Retro`, and `Thrusters/Maneuver` hierarchies;
- writes a schema-version-2 manifest;
- validates bounds, collider metadata, socket classes, directions, bases, and unique paths.

Generated files:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
```

The source asset remains development-only until its original license evidence is added and reviewed. See:

```text
assets/licenses/small_sci_fi_fighter/PROVENANCE.md
```

## Verify the current Godot milestone

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

The current pre-integration test target remains:

```text
PASS: 15 suites
```

After canonical runtime and dynamic-thruster integration, the target becomes `PASS: 16 suites`.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/` or the quarantined legacy `Resources/` folder. Runtime scenes may load only Godot-ready assets under `assets/runtime/`; gameplay must not point directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.
