# Shattered Orbit

A single-player, third-person space-flight vertical slice built with Godot 4.7.1 and typed GDScript.

## Current milestone

The playable flight room now uses the normalized **Small Sci-Fi Fighter** hero GLB with an agile simcade controller:

- six-axis local-space thrust;
- assisted nose-led maneuvering and coordinated banking;
- fully inertial manual flight;
- total-speed soft envelopes at 160 m/s normally and 240 m/s under boost;
- sustained all-axis translational boost with thermal lockout;
- ship-relative chase camera with no global horizon or preferred world-up direction;
- high-speed course, collision obstacles, telemetry HUD, and safe reset handling.

The existing `RigidBody3D`, 8500 kg mass, simple `8 x 2.5 x 12 m` gameplay collider, and force/torque architecture remain authoritative. The imported mesh never defines collision.

## Requirements

- Godot 4.7.1 Standard
- GL Compatibility renderer
- PowerShell on Windows, or Bash on Linux
- Blender only when regenerating the runtime fighter from its preserved source

No external Godot add-ons or runtime dependencies are required.

## Run

From the repository root:

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

Assisted flight keeps momentum readable while making strong maneuvers practical:

- forward thrust curves the velocity vector gradually toward the nose;
- lateral and vertical drift are damped without braking forward momentum to zero;
- yaw generates a restrained coordinated bank of up to approximately 22 degrees;
- direct roll input overrides generated banking;
- all steering remains force- and torque-based.

### Manual mode

Manual flight removes velocity steering, drift damping, automatic banking, and angular damping. Translation direction and ship orientation remain independent until the pilot applies counter-thrust or counter-rotation.

### Speed and boost

- Normal increasing-speed thrust fades from 120 to 160 m/s.
- Boosted increasing-speed thrust fades from 180 to 240 m/s.
- Braking and redirection remain available above either envelope.
- Ending boost above 160 m/s preserves the excess momentum.
- Continuous active boost overheats in approximately 12 seconds.
- Boost recovers after approximately 6 seconds of cooling and fully cools in approximately 15 seconds.
- Overheat disables boost only; ordinary thrust and rotation remain operational.

## Camera orientation

Space has no preferred upright direction. The chase camera uses the ship's local up axis for its entire perspective, including when the ship is rolled, inverted, or flying vertically. It never blends back toward global `Vector3.UP`.

## Hero ship asset

Gameplay references only:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
```

Regenerate it from the preserved `.blend` source with:

```powershell
.\tools\assets\export-small-fighter.ps1
```

The exporter normalizes the craft to `-Z` forward and `+Y` up, fits it inside the gameplay envelope, and writes an accompanying manifest.

The asset remains **development-only** until its original license evidence is added and reviewed. See:

```text
assets/licenses/small_sci_fi_fighter/PROVENANCE.md
```

## Verify locally

### Windows PowerShell

```powershell
.\tools\verify\verify.ps1
```

Or pass the executable explicitly:

```powershell
.\tools\verify\verify.ps1 -GodotBin "C:\path\to\Godot_v4.7.1-stable_win64.exe"
```

### Linux Bash

```bash
GODOT_BIN="$HOME/Packages/Godot_v4.7.1-stable_linux.x86_64" ./tools/verify/verify.sh
```

When `godot` is available on `PATH`:

```bash
./tools/verify/verify.sh
```

Successful verification must import the project, print:

```text
PASS: 12 suites
```

and boot the main scene briefly without parser, scene, path-case, or runtime errors.

## Manual acceptance focus

After automated verification passes, confirm directly in the flight room:

1. Pitching upward and applying thrust creates a curved climb.
2. A/D yaw predictably; Up/Down pitch; Left/Right roll in the named direction.
3. Q/E retain independent lateral translation.
4. Assisted yaw banks smoothly and manual roll overrides it.
5. Manual mode preserves linear and angular inertia.
6. Normal and boosted acceleration fade smoothly near 160 and 240 m/s.
7. Boost overheats, locks out, recovers, and never disables ordinary flight.
8. Camera orientation remains ship-relative when rolled, inverted, and vertical.
9. The hero fighter is centered, faces local `-Z`, and has no procedural fallback.
10. The extended course remains readable at low and maximum boost speed.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/` or the quarantined legacy `Resources/` folder. Godot-ready GLB exports belong under `assets/runtime/`; gameplay scenes must not point directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.
