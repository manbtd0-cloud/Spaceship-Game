# Interceptor Flight Refinement and Hero Ship Integration Design

## Status

Approved design for the next Shattered Orbit milestone on `agent/playable-flight-room`.

## Goal

Refine the working six-axis flight foundation into a polished agile-interceptor experience, add a manageable total-speed envelope, implement sustained boost with thermal lockout, introduce assisted nose-led maneuvering, extend the flight room for the higher speed range, and replace the procedural craft visuals with the normalized Small Sci-Fi Fighter runtime model.

The proven `RigidBody3D`, collider, input source, camera target, controller boundaries, and pure force/torque architecture must remain intact.

## Product Identity

The player ship is an agile interceptor with simcade handling:

- responsive attitude control;
- readable inertia;
- assisted stabilization for cinematic nose-led turns;
- fully inertial manual mode;
- six-axis translation remains available;
- no atmospheric lift simulation or fake wing aerodynamics;
- no hidden teleportation, velocity snapping, or hard speed clamping.

## Control Scheme

| Input | Action |
|---|---|
| W / S | Forward / reverse thrust |
| Q / E | Lateral strafe left / right |
| Space / Ctrl | Vertical strafe up / down |
| Mouse | Analog pitch / yaw |
| Arrow keys | Digital pitch / yaw alternative |
| A / D | Manual roll left / right |
| Shift | Sustained translational boost |
| F | Toggle assisted / manual flight mode |
| R | Reset to the flight-room spawn |
| Escape | Release / capture mouse |

Mouse is the primary steering interface. Arrow keys mirror pitch and yaw for keyboard-only control. A/D are reserved for deliberate roll. Space/Ctrl remain true vertical translation; a nose-led climb is performed by pitching up and applying forward thrust.

## Flight Modes

### Assisted Mode

Assisted mode combines direct thruster control with restrained flight-computer corrections.

- Mouse or arrow input directly commands pitch and yaw torque.
- A/D directly commands roll torque.
- Q/E and Space/Ctrl remain independent lateral and vertical translation.
- Forward thrust while the nose changes direction gradually curves the velocity vector toward local `-Z`.
- Velocity-vector steering scales with forward-thrust input, current speed, alignment error, and tuning.
- Steering is implemented as a bounded lateral force perpendicular to the current velocity vector, preserving speed magnitude as closely as the physics step permits.
- Steering never assigns, rotates, or clamps velocity directly.
- Lateral, vertical, and angular drift are damped gradually.
- Forward momentum is preserved when forward thrust is released.
- There is no automatic return to cruise speed and no automatic braking toward rest.

### Coordinated Turn Banking

Assisted yaw produces a restrained automatic roll into the turn.

- Initial maximum automatic bank offset: 22 degrees.
- Bank offset scales with yaw command and current maneuvering state.
- The offset is tracked relative to the pilot-commanded attitude, not relative to global `Vector3.UP`; the system assumes no world horizon.
- Releasing yaw smoothly returns only the generated bank offset toward zero.
- Manual A/D roll input immediately overrides automatic banking.
- Automatic banking resumes only after manual roll input is released.
- Torque is bounded and damped to avoid oscillation and snapping.

### Manual Mode

Manual mode is fully inertial.

- No velocity-vector steering.
- No automatic banking.
- No lateral or vertical drift damping.
- No angular damping.
- Releasing pitch, yaw, or roll preserves angular velocity.
- Translation direction and ship orientation remain independent.
- Counter-thrust and counter-rotation are required.

Mode changes preserve transform, linear velocity, angular velocity, boost heat, and overheat state.

## Speed Envelope

The speed envelope applies to total world-space speed, regardless of direction. It modifies only the component of requested translational force that would increase total speed. Perpendicular steering force and force opposing the current velocity remain available.

### Normal Envelope

- Target soft speed: 160 m/s.
- Positive-speed thrust attenuation begins at 120 m/s.
- The increasing-speed component of thrust falls smoothly to zero at 160 m/s.
- There is no hard velocity clamp or automatic braking force.
- If already above 160 m/s, non-boosted thrust cannot increase total speed further, but momentum remains untouched.
- Thrust that reduces speed or redirects the velocity vector remains available.

### Boost Envelope

- Target boosted soft speed: 240 m/s.
- Positive-speed thrust attenuation begins at 180 m/s while boost is effective.
- The increasing-speed component of boosted thrust falls smoothly to zero at 240 m/s.
- When boost ends above 160 m/s, excess speed is preserved.
- Normal thrust cannot add further total speed until the ship falls below the normal envelope.
- No immediate or gradual bleed-back to 160 m/s is applied.

The envelope is a gameplay-management system, not simulated atmospheric drag.

## Boost Thermal System

Boost amplifies all translational thrust: forward, reverse, lateral, and vertical. Rotational torque is unchanged.

Heat is normalized from `0.0` to `1.0`.

### Initial Endurance Cycle

- Cold-to-overheat buildup rate: `1 / 12` heat per second.
- Heat builds at the full configured rate whenever boost is held and any non-zero translational command is being amplified; direction and command magnitude do not weight the rate.
- At `1.0` heat, boost enters complete lockout.
- Normal thrust and all attitude controls remain available during lockout.
- Cooling rate: `1 / 15` heat per second.
- Recovery threshold: `0.60` heat, reached after approximately 6 seconds of cooling from maximum.
- Full cooling takes approximately 15 seconds.
- Heat and lockout state persist through flight-mode changes.
- Reset returns heat to `0.0` and clears lockout.

The HUD must display heat, active boost, overheat lockout, and recovery progress clearly.

## Architecture

### Data-Driven Tuning

`FlightTuning` remains the central editable resource and gains values for:

- normal envelope onset and soft-speed threshold;
- boosted envelope onset and soft-speed threshold;
- speed-envelope response curve;
- translational boost multiplier;
- heat buildup and cooling rates;
- lockout and recovery thresholds;
- assisted velocity-vector steering strength;
- minimum speed for steering assistance;
- maximum steering force;
- lateral and vertical drift damping;
- angular damping;
- auto-bank maximum offset, response, and recovery;
- separate pitch, yaw, and roll torque multipliers;
- camera speed pullback and FOV response.

### Pure Math and State Units

The design adds or extends focused, deterministic units:

- `FlightModel`: remains the only pure calculator that produces final local force and torque commands;
- `BoostThermalState`: computes heat, lockout, recovery, and effective boost state;
- `FlightSteeringMath`: computes a bounded assisted steering-force contribution without mutating physics state;
- `CoordinatedTurnMath`: computes automatic bank offset and corrective roll-torque contribution;
- `PlayerInputMath`: composes mouse and arrow pitch/yaw, A/D roll, and Q/E lateral translation;
- `ChaseCameraMath`: computes speed-aware pullback, look targeting, and FOV.

`FlightModel` composes the contributions from the other pure helpers into the final output. Runtime nodes store state, call pure units, and apply only the resulting force and torque. Equations are not duplicated in runtime nodes.

### Controller Responsibilities

`ShipFlightController` coordinates:

1. input sampling;
2. flight-mode selection;
3. boost thermal state;
4. active speed envelope;
5. pure flight-model computation;
6. force and torque application;
7. telemetry exposure.

It must never hard-clamp `linear_velocity` during ordinary flight.

## Hero Ship Pipeline

### Selected Asset

The primary player visual is:

`assets/source/ships/player_candidates/small_sci_fi_fighter/Small Sci-Fi Fighter.blend`

The secondary `The Ship` candidate is not integrated in this milestone.

### Blender Normalization

The source file remains untouched. A repeatable Blender preparation/export step must:

- open the preserved source;
- remove unused cameras, lights, hidden helpers, duplicate geometry, and irrelevant objects from the exported copy;
- apply rotation and scale;
- enforce `-Z` forward and `+Y` up;
- place the origin near the physical center of mass;
- fit the craft inside the existing approximately `8 x 2.5 x 12 m` gameplay envelope;
- preserve useful material slots;
- generate valid normals and tangents;
- avoid unnecessary animation, armature, or source-only data;
- export one optimized GLB to `assets/runtime/ships/player/small_sci_fighter.glb`.

The Godot scene must not require a corrective rotation to make the ship face forward.

### Godot Player Hierarchy

```text
PlayerInterceptor (RigidBody3D)
├── CollisionShape3D
├── VisualRoot
│   └── SmallSciFiFighter (runtime GLB instance)
├── CameraTarget
├── LeftEngineGlowAnchor
├── RightEngineGlowAnchor
├── PlayerInputSource
└── ShipFlightController
```

The existing rigid body, mass, collider, controller, and input hierarchy remain authoritative. The imported visual mesh never defines gameplay collision.

There is no procedural visual fallback. Missing, malformed, incorrectly oriented, or incorrectly scaled runtime geometry is a verification failure and prevents a release-quality boot.

Godot-owned nodes may provide engine glow, boost intensity, navigation lights, future hardpoints, the camera target, and a development-only center-of-mass marker without destructively editing the imported model.

## Camera

- Base FOV remains approximately 68 degrees.
- FOV widens gradually toward 84 degrees near the boosted envelope.
- Speed adds moderate camera pullback.
- Boost adds a restrained additional FOV and pullback response.
- Position, rotation, bank influence, and FOV remain exponentially smoothed.
- No ordinary-flight camera snapping is allowed.
- Camera prediction considers world velocity and changing ship-forward direction.
- Partial roll influence remains for spatial readability.

## Flight Room

The current room remains one scene and preserves the low-speed handling section near spawn. It is extended modestly to support the 160/240 m/s envelopes:

- longer route;
- wider navigation-ring spacing;
- farther reset boundary;
- additional distant scale references;
- enough clear distance to reach and observe the boosted envelope;
- no separate world-streaming or infinite-flight system;
- no dynamic procedural room expansion.

The course must remain useful at both low handling speed and maximum boost speed.

## HUD and Telemetry

The HUD adds:

- total speed;
- flight mode;
- boost command state;
- boost heat percentage;
- overheat lockout status;
- recovery indication;
- normal and boost speed-envelope context;
- current control reference reflecting the revised mapping.

Telemetry APIs remain read-only from the HUD.

## Error Handling

- Invalid node paths emit one clear error and disable only the affected runtime process.
- Missing tuning data prevents controller activation with a precise error.
- Missing runtime GLB fails the player-scene contract.
- Incorrect runtime asset path casing fails verification.
- Invalid model bounds or orientation fail the asset contract.
- Overheat affects boost only; it must not disable normal thrust or rotation.
- Reset restores spawn transform, clears linear and angular velocity, resets heat to zero, and clears lockout.

## Automated Verification

Deterministic tests must cover:

- positive-speed force reduction from 120 to 160 m/s;
- positive-speed boosted-force reduction from 180 to 240 m/s;
- no hard velocity clamp or forced braking;
- decelerating and perpendicular force remaining available above the envelope;
- uniform heat buildup for any boosted translation direction or magnitude;
- lockout at maximum heat;
- recovery only below `0.60` heat;
- 12-second heat endurance under fixed-step simulation;
- 6-second lockout recovery and 15-second full-cooling timing within fixed-step tolerance;
- assisted perpendicular steering force toward local `-Z`;
- no assisted steering in manual mode;
- automatic bank bounded at 22 degrees without using global up;
- manual roll overriding automatic bank;
- mouse and arrow pitch/yaw composition;
- A/D roll mapping;
- Q/E lateral translation mapping;
- exact runtime GLB path;
- absence of old procedural visual nodes;
- preservation of the rigid body, collider, input source, and controller;
- required camera target and engine anchors;
- extended course composition and reset boundary.

The suite count may increase beyond seven. The verifier must continue importing the project, running all registered suites, and briefly booting the main scene.

## Manual Acceptance

The milestone is accepted only when all of these are observed in Godot 4.7.1 Standard using GL Compatibility:

1. Pitching upward and applying forward thrust creates a smooth curved climb.
2. Yaw turns bank naturally instead of remaining visually flat.
3. A/D perform deliberate roll in both directions.
4. Q/E retain independent lateral translation.
5. Arrow keys mirror mouse pitch/yaw predictably.
6. Assisted mode feels responsive while preserving readable inertia.
7. Releasing forward thrust in assisted mode preserves forward momentum.
8. Manual mode has no hidden stabilization or steering.
9. Manual angular velocity persists after rotational input is released.
10. Normal acceleration fades smoothly from 120 to 160 m/s.
11. Boost acceleration fades smoothly from 180 to 240 m/s.
12. Ending boost above 160 m/s preserves excess momentum.
13. Boost overheats after approximately 12 seconds of sustained use.
14. Overheat disables boost but not ordinary flight controls.
15. Boost recovers after approximately 6 seconds of cooling and fully cools in approximately 15 seconds.
16. Camera pullback and FOV remain smooth across the full speed range.
17. The extended course remains readable and navigable at low and high speed.
18. The imported fighter faces `-Z`, uses `+Y` up, fits the approved envelope, and appears centered on its collider.
19. Missing or invalid runtime fighter data causes a clear verification failure rather than a procedural fallback.
20. The full verifier passes without path-case warnings, parse failures, scene failures, or boot errors.

## Scope Exclusions

This milestone does not include:

- weapons or combat;
- ship damage from overheating;
- atmospheric lift, stalls, or aerodynamic drag;
- gamepad support;
- alternate player ships;
- world streaming;
- infinite acceleration corridors;
- missions or enemy AI;
- final VFX, audio, or production-quality materials;
- detailed mesh-derived collision;
- changes to the established mass or gameplay collider unless runtime evidence proves a defect.

## Completion Gate

The milestone is complete only after:

- the implementation follows this specification;
- all automated suites pass on the user’s local Godot 4.7.1 verifier;
- the main scene boots without warnings or errors;
- the manual acceptance list is completed;
- the branch diff contains only the approved refinement, runtime-asset pipeline, room extension, tests, and documentation;
- no raw source asset is referenced directly by gameplay scenes.
