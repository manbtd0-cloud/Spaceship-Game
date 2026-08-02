# Canonical Hero Ship Calibration and Dynamic Thrusters Design

## Status

Approved design for replacing unreliable runtime alignment with a canonical Blender export and a deterministic socket-driven thruster system.

## Problem

The current Small Sci-Fi Fighter is visibly misaligned and underscaled. Its markers were generated from an unverified source-axis assumption, so they describe the assumption rather than proving the visible nose and top. Runtime rotation and scale correction therefore cannot guarantee the right result.

The current exhaust implementation is also incomplete: it represents rear flames only and does not model the fighter's visible maneuvering nozzles or the final force and torque actually applied by the flight controller.

## Goals

- Audit the preserved `.blend` without modifying it.
- Establish the true nose, top, physical center, dimensions, visible nozzles, and baked exhaust geometry from rendered evidence.
- Export one canonical GLB with identity root transform in Godot.
- Create sockets only at confirmed visible nozzles.
- Drive exhaust from the controller's final local force and torque, including assistance and automatic banking.
- Support main, retro, translation, pitch, yaw, and roll jets wherever the audited model physically provides them.
- Keep flames, particles, lights, and animation entirely under Godot control.
- Remove all runtime model-alignment adapters after canonical integration.

## Non-Goals

- No changes to flight physics, speed limits, thermal timing, controls, mass, or camera behavior.
- No invented nozzles.
- No mesh-derived gameplay collision.
- No final production VFX, audio, combat, damage, or alternate ships.
- Never overwrite or delete the preserved source `.blend`.

## Mandatory Execution Staging

This work has two separately approved implementation stages.

### Stage A — Audit only

The first implementation plan creates and verifies only the Blender audit tooling. It ends when the eight renders and JSON report are pushed.

### Calibration gate

The audit outputs are reviewed and a concrete calibration record is committed and approved. That record supplies the exact nose axis, top axis, center, canonical dimensions, baked-flame removals, and socket list.

### Stage B — Canonical export and runtime thrusters

Only after the calibration record is approved may a second implementation plan define the exact Blender rotations, dimensions, socket transforms, manifest contents, Godot hierarchy, solver fixtures, and runtime integration.

This staging prevents another exporter or socket layout from being built on guesses.

## Stage A: Non-Destructive Blender Audit

### Command

```powershell
.\tools\assets\audit-small-fighter.ps1
```

### Outputs

```text
artifacts/hero_ship_audit/
├── front.png
├── rear.png
├── left.png
├── right.png
├── top.png
├── bottom.png
├── perspective_front.png
├── perspective_rear.png
└── ship_audit.json
```

### Render contract

All images use the same neutral background and fixed lighting. Orthographic renders share one scale. Each image visibly includes:

- view name;
- camera position and viewing direction;
- Blender world-axis legend;
- source object origin;
- aggregate bounding box and center;
- aggregate dimensions;
- source SHA-256.

The six orthographic views are geometrically consistent. Perspective views exist only to resolve ambiguous silhouette, cockpit, tail, and nozzle details.

### JSON contract

`ship_audit.json` records:

- source path and SHA-256;
- Blender version;
- every visible object's name, parent, type, world transform, dimensions, and world bounds;
- all mesh and material names;
- emissive materials and nodes;
- existing empties and helpers;
- names containing engine, thrust, nozzle, flame, glow, jet, exhaust, or similar terms;
- aggregate bounds and center;
- exact camera transforms used by each render.

It does not claim which direction is the nose or top and does not assign nozzle roles. The audit script must not save the source file. The source SHA before and after execution must match.

## Calibration Decision Record

After Stage A, create:

```text
docs/assets/small-sci-fi-fighter-calibration.md
```

It records exact approved values for:

- Blender-space nose direction;
- Blender-space top direction;
- Godot target forward `-Z`;
- Godot target up `+Y`;
- physical-center definition and coordinates;
- canonical Godot dimensions;
- collider dimensions if a change is justified;
- meshes/materials to remove as baked exhaust;
- every confirmed nozzle's position, exhaust direction, class, and role;
- audit images supporting each decision.

Object and material names are supporting evidence only. The rendered model is authoritative.

## Stage B: Canonical Blender Export

The exporter works on an in-memory copy and writes:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
```

### Canonical Godot contract

```text
root rotation = identity
root scale    = 1,1,1
visible nose = local -Z
visible top  = local +Y
origin       = approved physical center
```

The player scene requires no corrective rotation, corrective scale, marker-driven adapter, or guessed transform.

Scaling is uniform. The collider remains a simple independent box and changes only if the approved calibration record requires it.

The runtime derivative removes cameras, lights, source-only helpers, irrelevant hidden geometry, unused armatures/animations, baked flame meshes, and permanent exhaust-only emissive geometry. Actual ship hardware and useful materials remain.

## Thruster Socket Contract

Sockets are Blender empties under `Thrusters`. Only audited visible nozzles receive sockets.

### Axis convention

```text
socket origin   = nozzle exit center
socket local -Z = exhaust plume travel direction
socket local +Z = reaction-force direction on the ship
socket scale    = 1,1,1
```

### Naming

Stable semantic paths are used where those nozzles exist, for example:

```text
Thrusters/Main/Left
Thrusters/Main/Right
Thrusters/Retro/Left
Thrusters/Retro/Right
Thrusters/StrafeLeft/Front
Thrusters/StrafeLeft/Rear
Thrusters/StrafeRight/Front
Thrusters/StrafeRight/Rear
Thrusters/VerticalUp/Front
Thrusters/VerticalUp/Rear
Thrusters/VerticalDown/Front
Thrusters/VerticalDown/Rear
Thrusters/PitchUp/Front
Thrusters/PitchUp/Rear
Thrusters/PitchDown/Front
Thrusters/PitchDown/Rear
Thrusters/YawLeft/Front
Thrusters/YawLeft/Rear
Thrusters/YawRight/Front
Thrusters/YawRight/Rear
Thrusters/RollLeft/Upper
Thrusters/RollLeft/Lower
Thrusters/RollRight/Upper
Thrusters/RollRight/Lower
```

The final list may be smaller. The manifest records each socket's path, class, role, position, exhaust direction, reaction direction, and maximum visual authority.

## Runtime Wrench Telemetry

`ShipFlightController` exposes read-only final local-space telemetry:

```text
final force_local
final torque_local
boost amount
flight mode
```

These values are captured after pilot input, speed attenuation, assisted damping, nose-led steering, coordinated banking, counter-thrust, and thermal boost availability. Visuals never infer activation from keyboard state.

## Deterministic Thruster Resolver

For socket `i` at local position `r_i` with normalized reaction direction `d_i`, one unit of activation contributes:

```text
force_i  = d_i
 torque_i = r_i × d_i
```

The resolver constructs one six-dimensional column per socket:

```text
column_i = [d_i.x, d_i.y, d_i.z,
            (r_i × d_i).x / L,
            (r_i × d_i).y / L,
            (r_i × d_i).z / L]
```

`L` is one documented reference length derived from the canonical ship dimensions. The target vector is the normalized requested force and torque using the same torque scaling.

The resolver computes bounded non-negative activations `x_i ∈ [0,1]` by minimizing:

```text
||W(Ax - b)||² + λ||x - previous_x||² + μ||x||²
```

- `W` controls force-versus-torque importance.
- `λ` supplies temporal stability without leaving idle output.
- `μ` discourages unnecessary simultaneous jets.
- Zero requested wrench returns exactly zero activation before smoothing.
- A small dead zone prevents numerical flicker.
- Opposing sockets activate together only when that improves the requested combined wrench.

Use a deterministic fixed-iteration projected-gradient or active-set implementation with no per-frame allocation. Solver weights and iteration count are data-driven and covered by pure tests.

Main and retro engines primarily satisfy translation. Maneuvering sockets may satisfy translation, rotation, or a combined wrench according to their actual position and direction.

## Godot Exhaust Effects

The GLB contains ship geometry and sockets only. Godot instantiates one effect scene per socket.

- Main engines: longest plume, brightest core, strongest boost response.
- Retro engines: shorter substantial plume.
- Maneuvering jets: short, sharp, fast-response pulses.

Rules:

- Zero activation means invisible mesh, particles stopped, light energy zero, and emission energy at idle value zero.
- Low activation creates a short pulse.
- Higher activation increases plume length, particle rate, emission, and light energy.
- Boost strengthens only active translational exhaust.
- Pure torque does not activate main engines unless their real lever arm contributes to that torque.
- Smoothing may decay quickly but must reach complete invisibility at idle.

## Failure Isolation

- Missing individual sockets disable only those effects and emit one warning per missing path.
- Missing `Thrusters` disables all exhaust visuals but not physics.
- Invalid duplicate socket paths fail the asset contract.
- Invalid zero-length socket directions fail verification.
- No generic rear flame, guessed socket, runtime corrective model transform, or procedural hull fallback is permitted.

## Removing Temporary Corrections

After the canonical GLB passes verification:

- remove `HeroShipModelAdapter` from the player scene;
- remove runtime marker-alignment and scale code;
- remove corrective model transforms;
- keep the GLB root at identity;
- retain only the canonical visual, sockets, effect controller, collider, camera target, input source, and flight controller.

## Verification

### Stage A

- All eight PNGs and JSON exist and are non-empty.
- Render dimensions and camera transforms match the audit contract.
- JSON source SHA matches the preserved source.
- Source SHA is unchanged after the audit.
- The audit can be run twice with identical structural JSON and equivalent renders.

### Stage B asset contract

- GLB imports as `PackedScene`.
- Root rotation and scale are identity.
- Visible nose and top match approved directions.
- Bounds and center match the calibration record within tolerance.
- No baked exhaust remains.
- Every socket has a unique path, identity scale, non-zero direction, and approved transform.
- No runtime adapter or corrective transform remains.

### Resolver tests

- Forward, reverse, lateral, and vertical force select physically correct sockets.
- Pitch, yaw, and roll torque select physically correct nozzle combinations.
- Combined force and torque are approximated within documented error tolerance.
- Assisted steering and automatic banking use final wrench telemetry.
- Zero wrench produces exact zero activation.
- Pure rotation does not create unrelated main-engine exhaust.
- Activations remain bounded and deterministic.
- Smoothing does not leave idle exhaust.
- Missing sockets degrade safely.

## Manual Acceptance

1. Correct orientation at spawn with identity runtime transform.
2. Approved size and centered collider relationship.
3. No idle flame, particles, glow, or exhaust light.
4. Forward thrust uses confirmed main engines.
5. Reverse thrust uses confirmed retro engines.
6. Lateral and vertical translation use physically correct visible nozzles.
7. Pitch, yaw, and roll use physically sensible nozzle combinations.
8. Assisted steering and automatic banking visibly use maneuvering jets.
9. Boost intensifies active translational exhaust only.
10. Every plume follows its socket's exported direction.
11. No visible nozzle is assigned an impossible role.
12. Missing optional sockets do not affect physics or crash the scene.
13. Local Godot 4.7.1 verifier passes without parser, import, scene, or runtime errors.

## Completion Gate

The overall milestone is complete only after Stage A audit review, calibration-record approval, Stage B canonical export, removal of runtime correction, dynamic socket integration, automated verification, and manual validation of every nozzle group actually present on the ship.
