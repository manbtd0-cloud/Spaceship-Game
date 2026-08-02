# Canonical Hero Ship Calibration and Dynamic Thrusters Design

## Status

Approved design for replacing the unreliable runtime-alignment experiment with a canonical Blender export and a deterministic dynamic-thruster system.

## Problem Statement

The current Small Sci-Fi Fighter runtime asset is visibly misaligned and underscaled. The existing `ForwardMarker` and `UpMarker` were generated from an unverified source-axis assumption, so runtime marker alignment cannot guarantee that the visible nose and top are correct. The current exhaust implementation also treats rear flames as simple always-present scene meshes rather than representing all visible maneuvering nozzles dynamically.

The next milestone must establish the ship orientation, scale, center, and actual nozzle layout from visual evidence before generating a new runtime GLB.

## Goals

- Produce an objective Blender audit of the preserved source without modifying it.
- Establish the true nose direction, top direction, physical center, and desired scale from rendered evidence.
- Export one canonical GLB whose root uses identity rotation and scale in Godot.
- Add named sockets only at visible, confirmed nozzles.
- Drive every exhaust effect from the controller's final local force and torque output.
- Support main engines, retro thrust, translation jets, pitch, yaw, roll, assisted steering, drift correction, and automatic banking.
- Keep flames, lights, particles, and animation entirely under Godot control.
- Remove runtime model-alignment adapters and corrective scene transforms after the canonical GLB is integrated.

## Non-Goals

- Do not change flight physics, speed envelopes, thermal timing, input mapping, mass, or camera behavior.
- Do not invent nozzles that are not visibly present on the audited ship.
- Do not use mesh-derived gameplay collision.
- Do not add final production VFX, sound, damage, weapons, or alternate ships.
- Do not overwrite or delete the source `.blend`.

## Phase 1: Non-Destructive Blender Audit

### Command

```powershell
.\tools\assets\audit-small-fighter.ps1
```

The wrapper opens the preserved source headlessly and writes audit outputs under:

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

### Render Requirements

All renders use the same neutral background, fixed lighting, consistent focal treatment, and a visible bounding box. Each image includes:

- view name and camera direction;
- Blender world-axis legend;
- object origin;
- dimensions;
- bounding-box center;
- source-file SHA-256.

The six orthographic views must be geometrically consistent. Perspective views exist only to resolve ambiguous silhouette and nozzle details.

### JSON Requirements

`ship_audit.json` records:

- source path and SHA-256;
- Blender version;
- every visible object, parent, type, transform, dimensions, and bounding box;
- mesh and material names;
- emissive materials and nodes;
- current empties and helpers;
- candidate nozzle-related names;
- camera transforms used for each render;
- aggregate bounds and center;
- no claimed nose, top, or nozzle role unless explicitly confirmed later.

The audit tool must not save the source file or modify the source on disk.

## Phase 2: Calibration Decision Record

After the audit outputs are pushed, one committed calibration document records the visually confirmed facts:

```text
Blender nose direction
Blender top direction
Godot target forward: -Z
Godot target up: +Y
physical center
canonical dimensions
visible main-engine nozzles
visible retro nozzles
visible translation/maneuver nozzles
baked flame or emissive geometry to remove
```

Object names are supporting evidence only. The orthographic and perspective renders are the authoritative evidence.

No canonical exporter or socket placement is implemented until this record is approved.

## Phase 3: Canonical Blender Export

The exporter works on an in-memory copy of the source scene and produces:

```text
assets/runtime/ships/player/small_sci_fi_fighter.glb
assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
```

### Canonical Transform Contract

In Godot, the exported root must have:

```text
rotation = 0, 0, 0
scale    = 1, 1, 1
forward  = local -Z
up       = local +Y
origin   = approved physical center
```

The visible ship must require no Godot corrective rotation, runtime alignment adapter, or guessed marker transformation.

### Canonical Scale

The calibration record defines one exact visual envelope. The exporter scales uniformly, never non-uniformly. The gameplay collider is updated only if the approved canonical dimensions require it, and remains a simple box independent from the mesh.

### Cleanup

The exporter removes from the runtime derivative:

- cameras and lights;
- source-only helpers;
- hidden or irrelevant geometry;
- armatures or animations not required by the static ship;
- visible baked flame meshes;
- source emissive objects that represent permanent exhaust rather than hardware.

Materials and actual ship geometry are preserved.

## Thruster Socket Contract

Sockets are Blender empties parented under a `Thrusters` hierarchy. Only sockets supported by visible nozzle evidence are created.

### Local Axis Convention

For every socket:

```text
origin   = nozzle exit center
local -Z = exhaust plume travel direction
local +Z = reaction-force direction applied to the ship
scale    = 1, 1, 1
```

This convention matches Godot's local forward convention and prevents effect-direction ambiguity.

### Naming

Sockets use stable semantic paths, for example:

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

The final hierarchy may contain fewer sockets. Missing physical nozzles are not fabricated merely to complete the taxonomy.

Each socket is unique, uses identity scale, and is positioned close to visible nozzle geometry. The manifest records socket path, position, exhaust direction, role, and class (`main`, `retro`, or `maneuver`).

## Runtime Wrench Telemetry

`ShipFlightController` exposes the final local-space wrench after all flight computations:

```text
final local force
final local torque
boost amount
flight mode
```

This telemetry is read-only. It represents the actual force and torque applied after:

- pilot translation and rotation input;
- speed-envelope attenuation;
- assisted drift damping;
- nose-led steering;
- coordinated banking;
- counter-thrust;
- boost thermal availability.

The visual layer must never infer thruster activation directly from keyboard state.

## Runtime Thruster Resolution

### Socket Physics Model

For a socket at local position `r` with reaction direction `d`, a normalized activation contributes:

```text
force contribution  = d
 torque contribution = r × d
```

The runtime resolver compares the requested local force and torque against all exported sockets and calculates non-negative activation values from `0.0` to `1.0`.

The resolver prioritizes:

1. correct force direction;
2. correct torque direction;
3. using the smallest physically sensible socket set;
4. avoiding unnecessary opposing simultaneous jets;
5. stable values without frame-to-frame flicker.

Main and retro engines primarily satisfy translation. Maneuver sockets may satisfy translation, rotation, or a combined wrench depending on their real position and direction.

### Fallback Behavior

- Missing individual sockets disable only the corresponding visual contribution and emit one clear warning.
- A missing `Thrusters` hierarchy disables dynamic exhaust without affecting flight physics.
- No generic rear flame or procedural fallback hull is displayed.

## Godot-Owned Exhaust Effects

The GLB contains ship geometry and sockets only. Godot instantiates effect scenes at each socket.

### Effect Classes

- Main engines: longer sustained plume, brightest core, strongest boost response.
- Retro engines: shorter but substantial plume.
- Maneuvering jets: short, sharp, fast-response pulses.

### Activation Rules

- Zero activation means fully invisible and non-emissive.
- Low activation produces a short pulse.
- High activation increases plume length, core brightness, and light energy.
- Boost strengthens only active translational exhaust.
- Rotational torque alone does not create main-engine boost flames.
- Opposing sockets may activate together only when the final requested wrench genuinely requires both.
- Smoothing prevents flicker but must not leave visible idle exhaust.

## Removal of Temporary Runtime Correction

After the canonical GLB is verified:

- remove `HeroShipModelAdapter` from the player scene;
- remove runtime marker alignment and scale correction code;
- remove any corrective model rotation or scale from `player_interceptor.tscn`;
- keep the final root transform at identity;
- retain only the canonical GLB, socket-driven exhaust system, collider, camera target, input source, and flight controller.

## Verification

### Audit Verification

- All eight renders exist and are non-empty.
- JSON source SHA matches the preserved `.blend`.
- The audit script leaves the source SHA unchanged after execution.
- Every image uses the documented camera direction.

### Canonical Asset Verification

- GLB imports as `PackedScene`.
- Root rotation is identity.
- Root scale is identity.
- Confirmed nose points toward Godot local `-Z`.
- Confirmed top points toward Godot local `+Y`.
- Bounds match the approved canonical envelope within tolerance.
- Origin matches the approved physical center tolerance.
- No baked exhaust geometry remains visible.
- Every socket has identity scale and valid non-zero exhaust direction.
- Socket positions and roles match the approved calibration record.
- No runtime model adapter or corrective transform remains.

### Thruster Solver Tests

Pure tests cover:

- main engines responding to forward force;
- retro engines responding to reverse force;
- correct lateral and vertical socket selection;
- pitch, yaw, and roll torque selecting physically appropriate pairs;
- combined force and torque requests;
- assisted steering and generated bank using final wrench telemetry;
- no activation at zero wrench;
- no unrelated main-engine activation from pure rotation;
- bounded activation values;
- stable smoothing and complete idle disappearance;
- graceful handling of missing sockets.

## Manual Acceptance

The milestone is accepted only when:

1. The ship appears correctly oriented from spawn with no corrective runtime transform.
2. The ship's visible size matches the approved calibration renders and collider.
3. Idle ship has no flame, glow, or exhaust light.
4. Forward thrust activates the confirmed main engines.
5. Reverse thrust activates confirmed retro thrusters.
6. Left/right and up/down translation activate visible nozzles that produce the correct reaction direction.
7. Pitch, yaw, and roll activate physically sensible nozzle pairs.
8. Assisted steering and automatic banking activate the corresponding maneuvering jets.
9. Boost intensifies active translational exhaust only.
10. The exhaust direction matches each nozzle orientation.
11. No visible nozzle is assigned an impossible role.
12. Missing optional sockets do not affect physics or crash the scene.
13. The full local verifier passes without parser, import, scene, or runtime errors.

## Completion Gate

The milestone is not complete until:

- audit outputs and JSON are generated and reviewed;
- the calibration decision record is approved;
- the canonical GLB and manifest are regenerated;
- runtime correction adapters are removed;
- dynamic socket-based exhaust is integrated;
- automated tests pass locally;
- manual orientation, scale, and all available thruster groups are verified in Godot 4.7.1.
