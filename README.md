# Shattered Orbit

A single-player, third-person space-combat vertical slice built with Godot 4.7.1 and typed GDScript.

## Current milestone

Milestone 0: reproducible project foundation and pure flight simulation logic.

## Requirements

- Godot 4.7.1 Standard
- PowerShell on Windows, or Bash on Linux
- Blender only when source assets are prepared for runtime export

No external Godot add-ons or runtime dependencies are required.

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

You can also set the environment variable for the current PowerShell session:

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.1-stable_win64.exe"
.\tools\verify\verify.ps1
```

### Linux Bash

```bash
GODOT_BIN="$HOME/Packages/Godot_v4.7.1-stable_linux.x86_64" ./tools/verify/verify.sh
```

When `godot` is available on `PATH`, run:

```bash
./tools/verify/verify.sh
```

The verifier imports the project headlessly, runs all registered suites, and boots the main scene briefly.

## Asset policy

Editable vendor and Blender sources remain under `assets/source/` or the quarantined legacy `Resources/` folder. Godot-ready GLB exports belong under `assets/runtime/`; do not point gameplay scenes directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` files.
