# Canonical Fighter and Four-Asteroid Field Design

## Status

Approved by the user on 2026-08-02.

## Goal

Finish the audit-backed canonical player fighter, including all twelve dynamic thruster sockets, then replace the flight-room box references with a fully collidable asteroid field that uses every supplied asteroid source.

## Scope order

1. Integrate the already-generated schema-2 fighter GLB and manifest.
2. Build a reproducible canonical export pipeline for four asteroid families.
3. Integrate the validated asteroid outputs into the flight room.
4. Verify the complete flight scene locally without GitHub Actions.

The asteroid work must not overwrite, postpone, or revert the fighter work.

## Canonical fighter input

Gameplay consumes these committed files as immutable generated inputs:

- `assets/runtime/ships/player/small_sci_fi_fighter.glb`
- `assets/runtime/ships/player/small_sci_fighter.manifest.json` is not a valid alias and must never be referenced.
- `assets/runtime/ships/player/small_sci_fi_fighter.manifest.json`

The manifest contract is schema version 2 and records:

- root identity;
- Godot `+X` right, `-Z` forward, `+Y` up;
- dimensions approximately `13.714 x 3.562 x 12.000 m`;
- collider size `14.0 x 3.8 x 12.2 m`;
- all eleven `EngineFire*` objects removed;
- two main sockets, two retro sockets, and eight maneuver sockets.

No runtime rotation, alignment marker, non-uniform scaling, or `HeroShipModelAdapter` is allowed.

## Fighter runtime architecture

### Flight telemetry

`ShipFlightController` stores and exposes the final local force and torque from `FlightModel.compute()`. This is the output after boost, speed-envelope limiting, assisted steering, drift damping, angular damping, and coordinated banking.

The visual system must use this final wrench instead of raw keys. Therefore automatic banking, assisted steering, and counter-thrust produce appropriate visual jets.

### Thruster allocation

`ShipThrusterAllocator` receives:

- each socket's local position;
- each socket's local reaction direction (`socket.transform.basis.z`);
- desired local force;
- desired local torque;
- force and torque reference magnitudes.

Each socket contributes:

- force `reaction_direction`;
- torque `position.cross(reaction_direction)`.

A deterministic bounded projected coordinate-descent solver produces one intensity in `[0, 1]` per socket. The solver is visual-only and does not alter flight physics.

The solver must:

- return zero for a zero wrench;
- remain deterministic;
- never return negative or non-finite intensities;
- activate main engines for forward force;
- activate retro engines for reverse force;
- use maneuver jets for translation and rotation;
- support combined force and torque requests;
- keep boost as an intensity/style multiplier only for already-active translational engines.

### Socket visual controller

`ShipThrusterVisualController` resolves the imported `Thrusters` hierarchy recursively, validates exactly twelve semantic sockets, creates a Godot-owned exhaust effect under each socket, and updates those effects every frame.

Every effect is invisible at zero intensity. Main effects are largest, retro effects medium-sized, and maneuver effects short and sharp. Effect length, radius, and emissive energy respond to intensity. Main effects receive extra boost styling only while active.

The old `LeftEngineGlowAnchor`, `RightEngineGlowAnchor`, `ShipVisualController`, and `ShipVisualMath` rear-only path are removed from the player scene.

### Player scene

The player scene uses:

- the canonical GLB at identity transform;
- collider size `Vector3(14.0, 3.8, 12.2)`;
- no model adapter;
- one dynamic thruster visual controller;
- the existing force/torque flight body and mass.

## Asteroid source pack

All four supplied sources are required:

1. `Asteroid Bennu Textured.blend`
2. `asteroid_eros_true_color.glb`
3. `Asteroid.blend`
4. `asteroid(1).blend`

They remain preserved under `assets/source/environment/asteroids/` with stable filenames and SHA-256 records.

### Runtime families

The canonical outputs are:

- `assets/runtime/environment/asteroids/bennu.glb`
- `assets/runtime/environment/asteroids/eros.glb`
- `assets/runtime/environment/asteroids/legacy_a.glb`
- `assets/runtime/environment/asteroids/legacy_b.glb`

Each output has a sibling schema-1 manifest recording source hash, Blender version, retained mesh count, removed objects, dimensions, canonical diameter, material status, texture status, provenance status, and collision-proxy statistics.

### Cleaning and normalization

The Blender exporter operates only on in-memory duplicates and never saves a source file. For every family it:

- removes cameras, lights, helpers, flat backdrop/plane geometry, and unrelated objects;
- joins retained asteroid geometry while preserving usable materials;
- centers the visual at the aggregate bounds center;
- applies identity rotation and scale;
- uniformly scales the longest dimension to a documented base diameter;
- exports a clean GLB with one canonical root;
- creates a reduced convex collision proxy as a named child;
- fails instead of exporting if no meaningful mesh remains.

The Eros source preserves its embedded CC BY 4.0 attribution. Other sources remain development-only until provenance is recorded.

### Collision

Every placed asteroid is collidable. Runtime scenes use `AnimatableBody3D` so asteroids may rotate slowly while retaining deterministic collision.

Collision uses the exported low-detail convex proxy, never the full render mesh. Each asteroid instance contains:

- `VisualModel`;
- `CollisionShape3D` or imported proxy converted to collision geometry;
- deterministic angular velocity settings.

### Flight-room field

`Course/DistantReferenceShapes` and all box placeholders are removed. A new `Course/AsteroidField` contains instances from all four families.

Placement requirements:

- every family appears at least twice;
- at least twelve total asteroids;
- near-course, mid-distance, and far-distance tiers;
- all instances collidable;
- deterministic positions, rotations, scales, and angular velocities;
- no asteroid directly overlaps the spawn or mandatory navigation-ring centerline;
- the course remains readable at boost speed;
- large far objects remain reachable and collidable.

## Asset handoff gate

The uploaded source binaries cannot be represented by placeholder paths. The asteroid integration plan therefore has a strict gate:

1. Commit the source files under the required source directory.
2. Run the local Blender exporter.
3. Validate and commit all four runtime GLBs and manifests.
4. Only then modify the flight-room scene to reference them.

The project must never commit a scene that references missing asteroid outputs.

## Tests

### Fighter

- canonical asset imports with dimensions within tolerance;
- root transform is identity;
- all twelve socket paths exist and have identity scale;
- `EngineFire*`, `ForwardMarker`, and `UpMarker` are absent;
- player collider matches the manifest;
- model adapter and old glow anchors are absent;
- allocator unit tests cover zero, forward, reverse, translation, torque, combined requests, bounds, and determinism;
- idle scene has no visible exhaust.

### Asteroids

- source-intake validator requires all four hashes/files;
- canonical manifests validate all four output families;
- output GLBs exist and are non-empty;
- collision proxy statistics are non-zero and substantially lower than visual geometry;
- flight room contains the required family coverage and total count;
- every field child is collidable;
- no box placeholder remains.

## Verification

No GitHub Actions are required. Final local verification uses:

```powershell
python -m unittest tests.tools.test_small_fighter_calibration -v
python -m unittest tests.tools.test_asteroid_pack -v
.\tools\assets\export-small-fighter.ps1
.\tools\assets\export-asteroid-pack.ps1
.\tools\verify\verify.ps1
```

Manual acceptance checks orientation, scale, all thruster directions, idle darkness, asteroid family variety, collision, readable course flow, and stable performance.
