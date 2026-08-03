# Realistic Flight, Camera Modes, and Settings Design

**Date:** 2026-08-04  
**Repository:** `manbtd0-cloud/Spaceship-Game`  
**Branch:** `agent/playable-flight-room`

## Purpose

Build the next flight-control milestone before the approved practice-drone work. The milestone must correct unrealistic speed loss during rotation, preserve a fully inertial flight mode, improve assisted steering without hidden braking, add three selectable chase-camera behaviors, add exact rear and side look controls, add a true velocity-vector HUD marker, and establish a minimal pause/settings system for future configuration work.

The approved practice drone remains fully approved and queued immediately after this milestone. Its shield, damage, destruction, rebuild, and future explosion decisions are unchanged.

## Non-Negotiable Physics Rule

For a spacecraft in vacuum, applying pure rotational torque must not reduce or redirect linear velocity. With no translational force, collision, damping, or external field:

- world-space linear velocity remains constant;
- speed remains constant;
- pitch, yaw, and roll change orientation and angular velocity only.

The game must preserve this behavior in the player-facing **Inertial** flight mode.

## Existing Root Cause

The current manual implementation already produces torque without translational force and the player body has zero linear damping. The observed speed loss comes from assisted-mode translational corrections:

- the controller converts world velocity into the ship's changing local frame;
- after the ship rotates, some of the unchanged world velocity appears as local lateral or vertical drift;
- current assisted damping opposes those local components;
- that opposition can remove kinetic energy and reduce total speed during hard pitch or yaw maneuvers.

The fix must address the assist-force model rather than masking the symptom in HUD telemetry or camera behavior.

## Scope

This milestone includes:

1. verified inertial velocity preservation;
2. energy-preserving assisted steering;
3. three camera behavior modes;
4. independent Close, Standard, and Far distance presets;
5. exact temporary rear, left, and right views;
6. a nose reticle and true velocity-vector marker;
7. a minimal pause/configuration menu;
8. persistent typed player settings;
9. regression and integration coverage for the complete milestone.

This milestone does not include:

- target lock;
- lead calculation;
- enemy AI;
- return fire;
- drone implementation;
- remappable controls UI;
- graphics or audio settings;
- controller/gamepad support;
- cinematic camera modes;
- cockpit view;
- weapon convergence changes.

## Flight Modes

### User-Facing Names

The menu and HUD use:

- **Assisted**
- **Inertial**

The existing internal enum may retain `MANUAL` to avoid unnecessary churn, but all player-facing text must use **Inertial**.

### Inertial Mode

Inertial mode is the physics reference mode.

Requirements:

- no passive translational damping;
- no automatic velocity alignment to the nose;
- no hidden braking;
- no local-axis drift cancellation;
- no coordinated auto-bank;
- no assisted angular damping;
- translational force is produced only by explicit translational input;
- torque is produced only by explicit rotational input;
- pure rotation while coasting preserves world linear velocity and speed;
- changing ship orientation must not rotate the existing world velocity vector.

The normal and boost soft speed envelopes continue to limit only force that would increase speed. They must not create passive drag or interfere with redirection and braking forces.

The collision-free physics acceptance tolerance over two seconds of sustained rotation is:

- speed drift no greater than `0.01 m/s`;
- world-velocity direction drift no greater than `0.01 degrees`.

### Assisted Mode

Assisted mode remains an easier fly-by-wire layer built on top of the same rigid-body physics.

Requirements:

- coordinated banking and angular damping remain assisted-only;
- assisted steering may redirect the velocity vector toward the ship nose;
- the steering component must be perpendicular to current velocity so it changes direction without intentionally changing magnitude;
- no unconditional local X/Y damping may remove speed merely because the ship rotated;
- explicit forward, reverse, strafe, and vertical inputs may still increase or decrease speed through real applied force;
- explicit reverse thrust remains valid braking;
- assisted nose steering is active only when the pilot is commanding forward travel, matching the current control intent;
- coasting with no translational input must not silently bleed speed;
- all assist-force contributions remain separately observable from pilot-force contributions for tests and thruster telemetry.

Small floating-point variation is acceptable, but the design target is energy-neutral steering rather than approximate drag compensation.

## Physics Architecture

### `FlightSteeringMath`

Owns the pure steering calculation.

The steering function must:

- accept current local velocity, desired local direction, input strength, mass, steering strength, minimum speed, and maximum acceleration;
- return zero below the minimum speed or without steering intent;
- calculate the shortest perpendicular correction toward the desired direction;
- remove any component parallel to current velocity before returning force;
- cap acceleration deterministically;
- remain a pure function with no scene-tree dependency.

### `FlightModel`

Combines:

- explicit pilot translational force;
- explicit pilot torque;
- assisted perpendicular steering force;
- assisted angular damping;
- assisted coordinated-bank torque.

The previous unconditional local lateral and vertical damping must be removed from the total assist force. The obsolete `assist_lateral_damping` and `assist_vertical_damping` fields must be removed from `FlightTuning`, the checked-in tuning resource, and tests. They must not remain as ignored or deprecated settings because that would misrepresent the active flight model.

### `ShipFlightController`

Continues to:

- sample input;
- transform world velocity into the ship frame;
- call `FlightModel`;
- transform local force and torque back to world space;
- apply central force and torque to the rigid body;
- expose split pilot and assist telemetry.

It must also expose an explicit setter for flight mode so the settings coordinator can apply a selected mode without simulating the `F` toggle action.

## Camera Model

Camera **behavior** and camera **distance** are separate settings.

### Camera Behaviors

#### 1. Dynamic Chase

This is the current camera and must remain available without being discarded.

Locked baseline values:

```text
position sharpness       5.5
rotation sharpness       7.0
velocity look-ahead      0.08 s
maximum prediction       8.0 m
```

Behavior:

- current smooth positional lag;
- current smooth rotational lag;
- velocity look-ahead;
- speed-based pullback;
- dynamic FOV;
- current hard rear-distance clamping.

No deliberate feel change is required beyond adapting it to the new shared behavior interface.

#### 2. Tactical Chase

This becomes the default behavior.

Locked baseline values:

```text
position sharpness       14.0
rotation sharpness       22.0
velocity look-ahead      0.015 s
maximum prediction       2.0 m
maximum positional error 1.5 m
maximum rotational error 6 degrees
```

Behavior:

- much faster rotational response than Dynamic Chase;
- substantially reduced velocity prediction;
- tightly bounded positional and rotational deviation from the ship-relative desired transform;
- light smoothing to avoid visual vibration;
- speed pullback and dynamic FOV remain available;
- if smoothing would exceed either error bound, clamp or snap to the boundary;
- during hard turns, the camera remains close enough to ship orientation that nose direction is predictable.

Tactical Chase must feel responsive, not perfectly rigid. The baseline values may be adjusted only if the manual acceptance run proves a concrete visual defect; any adjustment must update the checked-in tuning and tests together.

#### 3. Locked Chase

This is the exact reference camera.

Behavior:

- exact ship-relative position every frame;
- exact ship-relative orientation every frame;
- no positional interpolation;
- no rotational interpolation;
- no velocity prediction;
- no turn lag;
- selected Close, Standard, or Far distance still applies;
- dynamic FOV remains because it does not misrepresent direction;
- switching to Locked or changing distance while Locked snaps on the same frame.

Locked Chase exists both for player preference and for diagnosing trajectory-versus-orientation confusion.

### Distance Presets

The existing presets remain:

- Close
- Standard
- Far

Distance is independent of behavior. Tactical + Far and Locked + Close are valid combinations.

The existing `C` action continues to cycle distance presets. The pause menu also allows direct selection.

### Camera Behavior Interface

Introduce a typed camera-behavior enum or equivalent typed value:

- `DYNAMIC`
- `TACTICAL`
- `LOCKED`

`ChaseCameraRig` remains the single owner of the actual `Camera3D` and supports changing behavior at runtime. It must expose:

- select behavior;
- query selected behavior;
- select distance preset;
- query selected distance preset;
- set and query temporary view;
- snap safely when changing to Locked or when leaving a temporary view if interpolation would expose a wrong direction.

A behavior switch must not recreate the camera node or interrupt the current scene.

## Temporary Look Views

Temporary views are hold actions:

```text
B          exact rear view
PageUp     exact right view
PageDown   exact left view
```

The camera keeps the ship in frame by moving to the opposite side of the direction being viewed:

- rear view: camera moves in front of the ship along local `-Z` and looks through the ship toward local `+Z`;
- right view: camera moves to the ship's left along local `-X` and looks through the ship toward local `+X`;
- left view: camera moves to the ship's right along local `+X` and looks through the ship toward local `-X`.

The selected distance preset supplies the view offset, and the selected preset height remains applied.

Requirements:

- view activates only while the key is held;
- releasing the key immediately returns to the selected chase behavior and distance;
- views do not alter the selected behavior or distance;
- views override Dynamic, Tactical, and Locked while active;
- temporary views use exact ship-relative transforms with no lag;
- temporary views remain stable while the ship rotates;
- only one temporary view may be active at a time;
- deterministic priority is rear, then right, then left if multiple keys are held;
- these actions are disabled while the pause menu owns input.

The new input actions must use physical keys and must not conflict with current actions.

## Velocity and Nose HUD

### Nose Reticle

A small fixed center reticle represents:

- ship nose direction;
- weapon-forward direction;
- the canonical fighter `-Z` axis.

It is not a target lock or lead indicator.

### Velocity-Vector Marker

A separate restrained marker represents the direction of true world-space linear velocity.

Requirements:

- hide when speed is below `2.0 m/s`;
- project a point along normalized world velocity through the active `Camera3D`;
- when velocity is in front of the camera, place the marker at its projected screen position;
- when velocity is behind the camera or projects outside the safe viewport, clamp it to a screen edge padded by `32 px`;
- edge-clamped state includes a subtle directional chevron or rotation cue;
- when velocity aligns with the nose, the marker settles close to the center reticle;
- marker calculation is display-only and never feeds physics, steering, targeting, or camera logic;
- marker remains available in all camera behaviors and temporary views;
- pausing freezes its displayed position with the rest of the game.

The projection, behind-camera classification, and edge-clamping math must be isolated into pure testable functions.

## Input Ownership

Add physical-key actions for:

```text
toggle_pause       Escape
look_rear          B
look_right         PageUp
look_left          PageDown
```

`Escape` is removed from `toggle_mouse_capture`. The flight room no longer has a separate free-cursor toggle; pause owns cursor release and recapture. Development-only debug scenes may continue handling Escape directly for exit.

Existing controls remain unchanged, including:

- `F` flight-mode toggle;
- `C` distance-preset cycle;
- `R` flight-room reset.

Gameplay input must not process look, fire, flight-mode, reset, or camera-cycle actions while paused.

## Pause and Settings Foundation

### Escape Behavior

In the flight room, `Escape` becomes pause/resume.

On pause:

- set the scene tree paused;
- stop flight physics, firing, projectiles, camera updates, and gameplay timers;
- release the mouse cursor;
- show the pause panel;
- prevent gameplay actions from leaking through the opening key press.

On resume:

- hide the pause panel;
- restore the previous mouse-capture state, normally captured;
- resume scene-tree processing;
- prevent the closing key press from affecting flight input.

Development-only debug scenes retain their existing `Escape`-to-exit behavior unless explicitly changed by a later milestone.

### Minimal Pause Panel

The first menu is intentionally basic and functional. It contains:

- Resume;
- Camera Behavior: Dynamic / Tactical / Locked;
- Camera Distance: Close / Standard / Far;
- Flight Mode: Assisted / Inertial;
- Restart Flight Room;
- Quit.

Requirements:

- centered readable panel over a dark translucent backdrop;
- keyboard and mouse usable;
- `Tab` or arrow keys move focus, `Enter` activates, and `Escape` resumes;
- processing continues while the tree is paused;
- current values are reflected when opened;
- changing camera behavior, distance, or flight mode updates the settings service immediately and is authoritative when gameplay resumes;
- Restart unpauses safely and invokes the existing reset path rather than duplicating reset logic;
- Quit exits the application;
- no animation, audio, rebinding, tabs, or decorative complexity in this phase.

### `PlayerSettingsService` Autoload

Create one typed autoload named `PlayerSettingsService` responsible for:

- loading settings before the flight room applies defaults;
- exposing typed current values;
- validating values read from disk;
- applying defaults for missing or invalid values;
- saving only when a setting changes;
- emitting typed setting-change signals;
- allowing tests to construct a non-autoload instance with an injected temporary path so tests never overwrite real user settings.

Persist to:

```text
user://settings.cfg
```

Initial stored fields:

```text
camera.behavior
camera.distance
flight.default_mode
```

Defaults:

```text
camera.behavior = Tactical
camera.distance = Standard
flight.default_mode = Assisted
```

The service must not expose a generic mutable dictionary. Consumers use typed getters, setters, enums, and signals.

### `FlightRoomSettingsCoordinator`

Add one room-owned coordinator that:

- resolves `PlayerSettingsService`, `ChaseCameraRig`, and `ShipFlightController`;
- applies all loaded settings once during room startup;
- subscribes once to typed setting-change signals;
- applies runtime camera behavior, distance, and flight mode changes;
- disconnects cleanly with the room;
- exposes no independent copy of settings.

The pause menu writes settings only through `PlayerSettingsService`; it does not directly mutate camera or flight internals.

## Scene Integration

### Flight Room

The main flight room gains:

- pause-menu scene;
- `FlightRoomSettingsCoordinator`;
- nose reticle and velocity marker in the existing HUD;
- runtime application of saved flight mode;
- runtime application of saved camera behavior and distance;
- temporary-view input actions.

The existing player, camera rig, HUD, reset controller, projectile system, and future drone insertion points remain intact.

### Bootstrap

`PlayerSettingsService` loads without a visible loading screen. Invalid or missing settings fall back to defaults and do not block entering the flight room.

## Failure Handling

- Missing settings file: create defaults in memory; save on the first user change.
- Invalid enum or malformed config value: use the documented default and emit one warning.
- Missing pause-menu dependency: report a clear error and keep gameplay running rather than leaving the tree permanently paused.
- Missing camera dependency: retain the current valid camera configuration and reject the invalid change.
- Missing HUD camera reference: hide the velocity marker and emit a clear error; do not affect flight physics.
- Repeated pause/resume: idempotent and free of accumulated signal connections.
- Scene restart while paused: unpause safely before invoking the existing reset route.
- Settings coordinator failure: preserve documented defaults and keep flight playable.

## Testing Strategy

### Physics Unit Tests

Verify:

- inertial rotation input produces torque and zero translational force;
- inertial output remains zero-force for arbitrary local velocity caused by any ship orientation;
- assisted steering force is perpendicular to current velocity within tolerance;
- assisted steering does not include old unconditional lateral/vertical drag;
- assisted coasting with zero translational input produces no translational force;
- explicit forward, reverse, strafe, and vertical input still produce force;
- speed-envelope behavior remains unchanged for acceleration and braking.

### Physics Integration Test

Create a collision-free rigid-body fixture with:

- nonzero initial world linear velocity;
- zero linear damping;
- inertial flight mode;
- sustained pitch or yaw input;
- no translational input.

Advance real physics for two seconds and verify:

- orientation changes;
- angular velocity changes;
- speed drift is at most `0.01 m/s`;
- world-velocity direction drift is at most `0.01 degrees`;
- no hidden assist force is reported.

### Camera Tests

Verify:

- Dynamic behavior preserves current baseline calculations;
- Tactical uses the locked baseline parameters and respects its positional and rotational bounds;
- Locked behavior matches exact ship-relative transform in one update;
- behavior and distance selections are independent;
- C cycles distance without changing behavior;
- rear, right, and left views use the exact local positions and directions specified above;
- release restores selected behavior and distance;
- temporary-view priority is deterministic;
- runtime behavior switches do not recreate the camera.

### HUD Tests

Verify:

- velocity marker hides below `2.0 m/s`;
- aligned forward velocity projects near center;
- lateral drift moves the marker laterally;
- behind-camera velocity clamps to the correct edge;
- all clamped coordinates remain at least `32 px` inside viewport bounds;
- nose reticle remains fixed at center;
- marker math handles zero, non-finite, and near-camera values safely.

### Settings Tests

Verify:

- defaults load when the file is absent;
- valid round-trip persistence;
- malformed fields fall back individually;
- unrelated valid fields survive another field's corruption;
- injected test path prevents real settings mutation;
- camera and flight consumers receive typed values;
- changing a value persists exactly once;
- coordinator subscriptions do not duplicate after room recreation.

### Pause Integration Tests

Verify:

- Escape opens the menu and pauses the tree;
- menu continues processing while paused;
- player physics and firing do not advance while paused;
- gameplay input is blocked while paused;
- Resume restores gameplay and mouse capture;
- menu selections apply and persist;
- restart uses existing reset behavior;
- repeated open/close cycles do not duplicate callbacks or leak nodes.

### Full Regression Gate

The implementation is not complete until:

- Godot imports without parser or resource errors;
- every existing suite remains green;
- new suites pass;
- no orphan-node or resources-in-use warnings appear;
- the main flight room boots headlessly;
- a manual Windows visual check confirms inertial speed preservation, all three camera behaviors, temporary look views, the velocity marker, and pause-menu settings.

## Manual Acceptance Checklist

1. Accelerate to a visible speed.
2. Switch to Inertial.
3. Release all translational controls.
4. Pitch, yaw, and roll hard.
5. Confirm speed remains steady while the ship orientation changes.
6. Confirm the velocity marker stays on the original trajectory while the nose reticle moves.
7. Switch to Assisted and command forward travel through a hard turn.
8. Confirm velocity direction bends toward the nose without obvious speed collapse.
9. Compare Dynamic, Tactical, and Locked from the pause menu.
10. Confirm Tactical remains close during hard turns.
11. Confirm Locked has no lag.
12. Hold B, PageUp, and PageDown individually and verify exact rear, right, and left views.
13. Release each look key and verify immediate restoration.
14. Change camera behavior, distance, and flight mode; restart the game; confirm persistence.
15. Pause while firing and confirm gameplay fully freezes.

## Delivery Order

Implementation must be planned and executed in this order:

1. physics regression tests and assist-force correction;
2. typed settings service and room coordinator;
3. camera behavior architecture and temporary views;
4. velocity-vector HUD and nose reticle;
5. pause menu and settings wiring;
6. consolidated verification and manual acceptance.

After this milestone is closed, resume the already-approved stationary practice-drone milestone with no redesign unless implementation evidence reveals a direct conflict.
