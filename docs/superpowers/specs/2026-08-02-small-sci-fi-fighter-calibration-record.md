# Small Sci-Fi Fighter Calibration Record

## Status

Approved on 2026-08-02 from the committed Stage A audit evidence under `artifacts/hero_ship_audit/`.

This record is the authoritative input for the canonical runtime export and dynamic thruster implementation. It replaces every previous guessed axis marker, runtime alignment adapter, corrective model rotation, and forced narrow visual envelope.

## Evidence

- Source: `assets/source/ships/player_candidates/small_sci_fi_fighter/Small Sci-Fi Fighter.blend`
- Source SHA-256: `1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478`
- Audit report: `artifacts/hero_ship_audit/ship_audit.json`
- Audit renders:
  - `front.png`
  - `rear.png`
  - `left.png`
  - `right.png`
  - `top.png`
  - `bottom.png`
  - `perspective_front.png`
  - `perspective_rear.png`
- Blender version used for the audit: `5.2.0 LTS`

The source SHA was checked before, during, and after the audit. The audit did not modify the source file.

## Confirmed Source Frame

The visible fighter and its child exhaust objects are authored relative to the Blender object named `Cube`.

The correct aircraft frame is `Cube` local space:

```text
Right   = local +X
Forward = local +Y
Up      = local +Z
```

Blender glTF Y-up conversion maps that frame to the required Godot frame:

```text
Blender local +X -> Godot local +X
Blender local +Y -> Godot local -Z
Blender local +Z -> Godot local +Y
```

Therefore, the canonical export must convert every retained child from source world space into `Cube` local space before centering and scaling:

```text
canonical_child_transform = inverse(Cube.matrix_world) * child.matrix_world
```

The existing `Cube` world transform must not be baked into the runtime ship:

```text
Rotation: X 0.000000°, Y 36.459768°, Z 17.691802°
Scale:    X 1.092070,  Y 1.627880,  Z 1.000000
```

Those values are presentation transforms in the source scene, not the fighter's canonical gameplay orientation.

## Canonical Transform Contract

The generated GLB root must import into Godot with:

```text
position = (0, 0, 0)
rotation = (0, 0, 0)
scale    = (1, 1, 1)
forward  = local -Z
up       = local +Y
right    = local +X
```

Godot must not apply:

- `HeroShipModelAdapter`;
- runtime marker alignment;
- corrective scene rotation;
- corrective scene scale;
- non-uniform scaling.

## Hull Bounds and Center

The Stage A aggregate world bounds include the baked flame objects and are not the canonical hull dimensions.

After excluding every `EngineFire*` object and evaluating the fighter in `Cube` local space, the confirmed hull dimensions are:

```text
Width  X = 28.1266 source units
Length Y = 24.6110 source units
Height Z = 7.3053 source units
```

The confirmed hull-bounds center in `Cube` local space is:

```text
(0.0000, -0.5693, 0.5081)
```

The exporter must translate retained ship geometry by the negative of this center before applying canonical scale.

## Canonical Gameplay Size

The approved canonical length is exactly `12.000 m`.

The required uniform scale factor is:

```text
12.0000 / 24.6110 = 0.487587 approximately
```

Expected canonical Godot dimensions:

```text
Width  X = 13.714 m
Height Y = 3.562 m
Length Z = 12.000 m
```

Tolerance for automated bounds verification: `±0.05 m` per axis.

The approved simple gameplay collider is:

```text
BoxShape3D size = (14.0, 3.8, 12.2)
```

The collider remains independent of render geometry.

## Baked Exhaust Geometry

The source contains eleven visible baked exhaust objects:

```text
EngineFire
EngineFire.001
EngineFire.002
EngineFire.003
EngineFire.004
EngineFire.005
EngineFire.006
EngineFire.007
EngineFire.008
EngineFire.009
EngineFire.010
```

`EngineFire` contains two disconnected rear plumes. The remaining ten objects each represent one plume. Together they provide twelve confirmed exhaust locations.

All `EngineFire*` render geometry must be removed from the canonical runtime GLB. Their evaluated geometry and transforms are calibration evidence for socket position and exhaust direction only.

No baked flame mesh, permanent plume, permanent exhaust glow, or exhaust light may remain visible at idle.

## Confirmed Thruster Groups

The twelve approved sockets are derived from the baked plume geometry:

| Source evidence | Canonical sockets | Class | Role |
|---|---:|---|---|
| `EngineFire`, split into two connected components | 2 | `main` | Primary forward reaction thrust |
| `EngineFire.001`, `EngineFire.004` | 2 | `retro` | Reverse translation |
| `EngineFire.002`, `EngineFire.003` | 2 | `maneuver` | Front upper pair |
| `EngineFire.005`, `EngineFire.006` | 2 | `maneuver` | Rear upper pair |
| `EngineFire.007`, `EngineFire.008` | 2 | `maneuver` | Rear lower pair |
| `EngineFire.009`, `EngineFire.010` | 2 | `maneuver` | Front lower pair |

Total:

```text
Main:      2
Retro:     2
Maneuver:  8
All:      12
```

The eight maneuver sockets form front/rear and upper/lower pairs. The runtime wrench solver may combine them to represent lateral translation, vertical translation, pitch, yaw, roll, assisted steering, drift correction, and coordinated banking.

The final semantic socket names are assigned by the canonical exporter from measured canonical position and reaction direction, not by the original numeric `EngineFire` suffix alone.

## Socket Extraction Contract

For each baked plume or connected plume component:

1. Convert evaluated vertices into `Cube` local space.
2. Apply the approved hull-center translation and uniform scale.
3. Determine the plume's principal longitudinal axis from its vertex covariance.
4. Resolve axis sign using cross-sectional area and proximity to the confirmed hull:
   - the wide end nearest the hull is the nozzle exit;
   - the narrow/far end points along exhaust travel.
5. Create one socket at the nozzle-exit center.
6. Orient the socket so:

```text
local -Z = exhaust travel direction
local +Z = reaction-force direction
scale    = (1, 1, 1)
```

7. Record canonical position, basis, exhaust direction, reaction direction, class, semantic role, and source object/component in the manifest.

If automatic end detection is ambiguous for any component, the exporter must fail rather than invent a socket.

## Material Policy

The actual hull and nozzle hardware remain.

The source material named `Thrusters` may remain assigned to physical nozzle surfaces, but the runtime derivative must not contain permanent exhaust emission. Any emission representing always-on flame must be disabled or replaced with a non-emissive hardware material in the exported derivative.

The `Muzzle` material is unrelated to flight exhaust and must not be used to infer thruster sockets.

## Runtime Exhaust Policy

The GLB contains only:

- canonical ship geometry;
- physical nozzle hardware;
- the `Thrusters` socket hierarchy;
- metadata required by the manifest.

Godot owns every plume, light, particle, pulse, and activation animation.

Runtime activation is driven from the final local force and torque actually applied by `ShipFlightController`, after assistance, damping, steering, speed envelopes, auto-bank, boost availability, and counter-thrust.

The visual layer must not infer activation from keyboard state.

## Acceptance Requirements

The calibration is implemented correctly only when:

1. The canonical GLB imports at identity position, rotation, and scale.
2. The visible nose points toward Godot local `-Z`.
3. The visible top points toward Godot local `+Y`.
4. Final bounds equal approximately `13.714 × 3.562 × 12.000 m`.
5. The collider equals `14.0 × 3.8 × 12.2 m`.
6. The hull is centered using the approved local bounds center.
7. No `EngineFire*` geometry appears in the runtime GLB.
8. Exactly twelve sockets are exported unless the exporter fails with explicit ambiguous-geometry evidence.
9. Every socket has identity scale and a valid orthonormal basis.
10. Idle flight displays no plume, glow, particles, or exhaust light.
11. Runtime model-alignment code and corrective scene transforms are removed.
12. Dynamic thrusters respond to the controller's final local wrench and pass automated and manual verification.
