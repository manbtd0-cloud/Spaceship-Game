# Shattered Orbit

A single-player, third-person space-combat vertical slice built with Godot 4.7.1 and typed GDScript.

## Current milestone

Playable flight room: a procedural interceptor, six-axis physics, assisted/manual flight modes, keyboard and mouse controls, a smooth chase camera, telemetry HUD, spatial navigation course, collision obstacles, and safe reset handling.

The real Blender ship candidates remain quarantined until this controller and camera milestone passes runtime acceptance.

## Requirements

- Godot 4.7.1 Standard
- GL Compatibility renderer
- PowerShell on Windows, or Bash on Linux
- Blender only when source assets are prepared for runtime export

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
| `A` / `D` | Strafe left / right |
| `Space` / `Ctrl` | Move up / down |
| Mouse | Pitch / yaw |
| `Q` / `E` | Roll left / right |
| `Shift` | Boost |
| `F` | Toggle assisted / manual flight |
| `Escape` | Release / recapture mouse |
| `R` | Reset to spawn and clear momentum |

Assisted mode gradually opposes lateral, vertical, and angular drift. Manual mode preserves six-axis momentum when no thrust or torque is applied.

## Verify locally

### Windows PowerShell

When Godot is available on `PATH` or stored in a common location:

```powershell
.\tools\verify\verify.ps1
```

Otherwise pass the exact executable path:

```powershell
.\tools\verify\verify.ps1 -GodotBin "C:\path\to\Godot_v4.7.1-stable_win64.exe"
```

Successful verification must include:

```text
PASS: 7 suites
```

### Linux Bash

```bash
GODOT_BIN="$HOME/Packages/Godot_v4.7.1-stable_linux.x86_64" ./tools/verify/verify.sh
```

When `godot` is available on `PATH`:

```bash
./tools/verify/verify.sh
```

The verifier imports the project headlessly, runs all registered suites, and boots the main scene briefly.

## Manual acceptance

After automated verification passes, launch the game and confirm:

1. All six movement axes respond in local ship space.
2. Mouse up pitches the nose upward and horizontal motion yaws predictably.
3. Boost is obvious and the HUD reaches 100%.
4. Mode switching preserves transform and velocities.
5. Assisted mode gradually reduces drift while manual mode preserves it.
6. Camera follow, pullback, and FOV changes remain smooth.
7. Escape updates capture state and `R` resets safely.
8. Gates, pylons, markers, and distant shapes make speed and scale readable.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/` or the quarantined legacy `Resources/` folder. Godot-ready GLB exports belong under `assets/runtime/`; gameplay scenes must not point directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.
