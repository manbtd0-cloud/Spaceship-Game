# AI-Assisted Flight and Smart Stabilize Design

**Date:** 2026-08-05  
**Repository:** `manbtd0-cloud/Spaceship-Game`  
**Branch:** `agent/playable-flight-room`  
**Status:** Approved design

## 1. Purpose

Add a third player-facing flight mode, **AI Assisted**, plus a universal hold-to-use **Smart Stabilize** function. Both features must operate through the existing rigid-body force and torque pipeline. They must not replace, weaken, or reinterpret the established Assisted and Inertial modes.

The player experience should be:

- **Assisted:** current behavior, unchanged.
- **AI Assisted:** easier trajectory-following flight where rotational input communicates intended travel direction and the onboard computer coordinates bounded real thrust and torque.
- **Inertial:** current true inertial behavior, unchanged.
- **Smart Stabilize:** hold one key in any mode to arrest rotation first and then brake world-relative drift progressively.

## 2. Locked player controls

### Flight-mode cycle

Physical `F` continues to own the single `toggle_flight_mode` action.

The player-facing cycle is exactly:

```text
ASSISTED -> AI ASSISTED -> INERTIAL -> ASSISTED
```

The implementation must use an explicit cycle function. It must not depend on enum ordinal order.

### Smart Stabilize

Physical `X` owns a new logical action:

```text
smart_stabilize
```

Smart Stabilize is **hold-to-use**, not a toggle.

- Press and hold `X`: stabilization takes priority.
- Release `X`: ordinary control for the currently selected flight mode resumes immediately.
- Smart Stabilize never changes the selected flight mode.
- `X` must have exactly one input-map owner and must not conflict with camera, pause, fire, boost, reset, or movement controls.

## 3. Flight-mode compatibility

Existing persisted numeric values must remain compatible with current `user://settings.cfg` files:

```text
FlightMode.Value.ASSISTED = 0
FlightMode.Value.MANUAL = 1     # player-facing name remains INERTIAL
FlightMode.Value.AI_ASSISTED = 2
```

`MANUAL` may remain the internal enum name. All player-facing text must use `INERTIAL`.

The settings service must accept and persist all three values. Old settings files containing `0` or `1` must retain their original meaning.

## 4. Non-regression boundary

The following behavior remains authoritative and unchanged when the new features are inactive:

- Inertial mode preserves world velocity under pure rotation.
- Existing Assisted steering and angular damping remain unchanged.
- Rigid-body mass, zero damping, force application, torque application, speed envelopes, boost thermals, coordinated banking, camera behavior, HUD vectors, pause behavior, reset behavior, primary fire, projectile motion, and exact thruster visuals remain unchanged.
- The player scene continues to own one body, one flight controller, one input source, one primary-fire controller, and one projectile pool.
- No second physics body, duplicate controller, alternate movement stack, or runtime thruster allocator may be introduced.

## 5. Architecture

### 5.1 Existing controller remains the sole runtime owner

`ShipFlightController` remains the only node that:

- samples the `PlayerInputSource`;
- selects the active flight mode;
- evaluates boost and speed-envelope state;
- calls the force model;
- applies central force and torque to the player rigid body;
- exposes telemetry to the HUD and thruster visual controller.

AI Assisted and Smart Stabilize are additive calculations consumed by this controller. They do not become separate gameplay controllers.

### 5.2 Pure AI intent solver

Add a pure typed solver, named `AiFlightIntentSolver`, under `src/flight/`.

Its public calculation receives:

- the current `FlightCommand`;
- local linear velocity;
- local angular velocity;
- body mass;
- `FlightTuning`.

It returns a typed output containing only:

- bounded local assist force;
- bounded local assist torque.

The solver must not receive a `RigidBody3D`, `Node`, `Transform3D`, `SceneTree`, or input singleton. It cannot mutate runtime state, transforms, or velocities.

### 5.3 Smart Stabilize solver

Add a separate pure typed solver, named `SmartStabilizeSolver`, under `src/flight/`.

Its calculation receives:

- local linear velocity;
- local angular velocity;
- body mass;
- `FlightTuning`.

It returns bounded local force and torque. This separation prevents Smart Stabilize from becoming a fourth flight mode or being entangled with AI Assisted intent interpretation.

### 5.4 Output integration

The existing `FlightOutput` channels remain authoritative:

- pilot command produces `pilot_force_local` and `pilot_torque_local`;
- assistance produces `assist_force_local` and `assist_torque_local`;
- `finalize_totals()` produces the final bounded request passed to the body.

When Smart Stabilize is held, its assist output replaces ordinary Assisted or AI-Assisted assist output for that physics tick. Explicit pilot force/torque is suppressed while stabilizing so held movement input cannot fight the emergency recovery function. Primary fire remains available because weapon input is independent.

When Smart Stabilize is not held:

- Assisted follows the existing `FlightModel` branch unchanged;
- Inertial receives no automatic assist;
- AI Assisted receives `AiFlightIntentSolver` output.

## 6. AI-Assisted behavior

### 6.1 Attitude stabilization

AI Assisted continuously applies bounded counter-torque against uncommanded angular velocity.

- Sustained explicit pitch, yaw, or roll input remains authoritative.
- The solver must not cancel an explicitly commanded axis.
- Releasing rotational input causes rotation to settle progressively rather than snap.
- Per-axis torque magnitude may never exceed the existing pitch, yaw, and roll torque limits.

Initial tuning values:

```text
ai_angular_damping = 42000.0
ai_rotation_command_protection = 0.90
```

`ai_rotation_command_protection` scales damping down on axes with explicit pilot input so the computer stabilizes without fighting the command.

### 6.2 Intent-following trajectory redirection

AI Assisted interprets pitch/yaw intent as a request to bend the actual trajectory toward the ship nose.

Trajectory alignment is active only when at least one of these is true:

- pitch or yaw command magnitude is above `0.08`;
- forward-thrust command magnitude is above `0.08`.

When neither condition is true, AI Assisted preserves linear drift except for explicit pilot translation. This retains deliberate drift and free-aim behavior.

The solver works in ship-local coordinates:

1. Split local velocity into forward and lateral/vertical components.
2. Determine the alignment demand from pitch/yaw magnitude and forward-thrust intent.
3. Request lateral/vertical acceleration opposite the misaligned velocity components.
4. Clamp requested acceleration to the AI steering limit.
5. Convert acceleration to force using body mass.
6. Preserve the pilot’s explicit strafe and vertical commands by never generating correction that opposes an explicitly commanded translation axis.

Initial tuning values:

```text
ai_trajectory_alignment_gain = 1.60
ai_min_alignment_speed = 6.0 m/s
ai_max_steering_acceleration = 20.0 m/s^2
ai_translation_command_protection = 0.90
```

### 6.3 Speed preservation and limited braking

AI Assisted normally redirects velocity without automatically erasing forward speed.

Automatic longitudinal braking is permitted only when either condition is true:

- current speed exceeds the active speed envelope; or
- forward thrust is held while the local velocity points more than `100 degrees` away from ship-forward.

Automatic braking is capped at:

```text
ai_max_braking_acceleration = 10.0 m/s^2
```

The solver may never assign velocity directly or create an instantaneous stop.

### 6.4 Finite and bounded output

Every solver output must be finite. A non-finite input or intermediate result produces zero assist output for that tick.

Force and torque are clamped independently:

- lateral and vertical AI force: body mass times `ai_max_steering_acceleration`;
- longitudinal AI braking force: body mass times `ai_max_braking_acceleration`;
- pitch/yaw/roll AI torque: existing tuning torque limit for that axis.

## 7. Smart Stabilize behavior

### 7.1 Priority sequence

Smart Stabilize follows this continuous sequence while `X` is held:

1. Apply bounded counter-torque immediately.
2. Delay strong linear braking while angular motion is dangerous.
3. Ramp linear braking to full strength as angular velocity settles.
4. Hold the ship near world-relative rest without snapping.

Angular speed thresholds:

```text
full_braking_below = 5 degrees/second
no_braking_above = 15 degrees/second
angular_rest_threshold = 0.5 degrees/second
```

The linear-braking multiplier interpolates from `0.0` at or above `15 degrees/second` to `1.0` at or below `5 degrees/second`.

### 7.2 Braking behavior

Smart Stabilize requests acceleration opposite local linear velocity.

Initial tuning values:

```text
stabilize_angular_damping = 70000.0
stabilize_max_linear_deceleration = 22.0 m/s^2
stabilize_linear_rest_threshold = 0.25 m/s
```

Torque remains clamped to existing per-axis torque authority. Linear force remains clamped to body mass times the maximum deceleration.

Below the linear rest threshold, no further braking force is requested. The function does not assign zero velocity.

### 7.3 Lifecycle

- Holding `X` at rest remains safe and produces no duplicated force application.
- Releasing `X` clears the stabilizing state immediately.
- Reset clears any cached solver state and HUD indication.
- Mode changes clear AI response state but do not alter the physical body velocity.
- Pausing freezes stabilization because the physics tree is paused.

The baseline design uses stateless pure solvers. If response smoothing later requires runtime state, it must be a single typed state object owned by `ShipFlightController`, reset on mode change/reset, and covered by tests. No hidden static state is allowed.

## 8. Input and command data flow

`PlayerInputSource` adds:

```text
is_smart_stabilize_held() -> bool
```

`smart_stabilize` becomes a required action.

The physics-tick flow is:

```text
InputMap
  -> PlayerInputSource
  -> FlightCommand + smart-stabilize held state
  -> ShipFlightController
      -> existing boost/envelope logic
      -> existing FlightModel for Assisted/Inertial pilot output
      -> AiFlightIntentSolver when mode is AI Assisted
      -> SmartStabilizeSolver when X is held
  -> FlightOutput.finalize_totals()
  -> RigidBody3D.apply_central_force/apply_torque
  -> HUD and exact thruster telemetry
```

No solver may read `Input` directly.

## 9. Thruster visual behavior

The existing checked-in action matrix remains authoritative.

AI and Smart Stabilize outputs flow through the existing assisted force/torque telemetry channel. The visual controller therefore uses the same physical socket mappings already used for Assisted corrections.

- AI correction visuals retain the existing dim assisted-output cap.
- Smart Stabilize uses the same dim cap.
- Direct pilot output still dominates when direct and automatic channels request the same thruster.
- No procedural exhaust, new sockets, or runtime allocation is added.

## 10. HUD behavior

`FlightHud.mode_text_for()` must return exactly:

```text
MODE   ASSISTED
MODE   AI ASSISTED
MODE   INERTIAL
```

While Smart Stabilize is held, the mode label appends:

```text
   |   STABILIZING
```

Example:

```text
MODE   AI ASSISTED   |   STABILIZING
```

No additional animated panel, voice assistant, or cockpit overlay is included in this milestone.

The controls line adds `X STABILIZE` while preserving existing control help.

## 11. Pause menu and persistence

The pause menu’s flight-mode option contains exactly:

```text
Assisted
AI Assisted
Inertial
```

The settings service:

- accepts all three enum values;
- persists `flight.default_mode` using the compatible numeric values;
- loads old Assisted/Inertial values without migration;
- rejects all other values and falls back to Assisted only when the stored value is invalid.

The existing room settings coordinator remains the sole adapter that applies the stored default to the live controller.

## 12. Reset and mode switching

`ShipFlightState.toggled_mode()` implements the explicit three-mode cycle.

Changing modes must:

- emit exactly one `flight_mode_changed` signal when the value changes;
- clear coordinated-bank state;
- clear any AI smoothing/integrator state;
- clear Smart Stabilize runtime state;
- preserve body transform, linear velocity, angular velocity, boost heat, and projectile state.

Flight-room reset must additionally:

- clear Smart Stabilize state;
- clear AI state;
- retain the selected flight mode;
- continue clearing momentum, boost runtime state, firing cadence, and active projectiles as already implemented.

## 13. Failure handling

- Invalid flight modes are rejected without changing the active mode.
- Missing `smart_stabilize` input is reported once by the existing required-action validation and behaves as not held.
- Non-finite solver inputs return zero automatic force and torque.
- Missing tuning continues to disable the controller through the existing error path.
- No per-frame error spam is permitted.
- Settings and pause-menu validation remain typed and idempotent.

## 14. Automated verification requirements

The implementation plan must produce tests covering at least:

### Compatibility

- enum numeric compatibility for Assisted and Inertial;
- explicit `F` cycle order;
- old settings values loading with unchanged meaning;
- all existing Assisted and Inertial tests remaining green;
- inertial zero-drift verifier remaining exactly green.

### AI Assisted

- valid selection through controller, settings, coordinator, and pause menu;
- rotational intent while moving producing bounded trajectory-redirection force;
- no turn/forward intent preserving linear drift;
- angular damping occurring without explicit rotation input;
- sustained pilot rotation not being cancelled;
- explicit strafe/vertical intent not being opposed;
- limited braking conditions and caps;
- finite output under malformed/non-finite inputs;
- no transform or velocity assignment in the solver/controller path;
- mode switching clearing AI state.

### Smart Stabilize

- physical `X` unique ownership;
- held-state exposure through `PlayerInputSource`;
- activation in Assisted, AI Assisted, and Inertial;
- angular counter-torque beginning immediately;
- linear braking ramping according to angular speed;
- speed reducing progressively rather than snapping;
- force and torque remaining finite and bounded;
- release returning ordinary control immediately;
- selected mode remaining unchanged;
- reset clearing stabilization state;
- pause freezing progression;
- repeated activation not duplicating application.

### Integration and regressions

- HUD mode/status text;
- pause-menu options and persistence;
- player scene retaining one controller/body/input/fire/pool ownership;
- no duplicate settings state;
- primary fire, camera controls, boost, reset, velocity marker, and thruster visuals remaining functional;
- full verifier and main-scene boot passing without parser errors, orphan nodes, or retained resources.

## 15. Windows manual acceptance

One final Windows session must verify:

1. `F` cycles Assisted -> AI Assisted -> Inertial -> Assisted.
2. AI Assisted: build forward speed, command pitch/yaw, and observe the velocity marker bend progressively toward the nose reticle.
3. Release rotational input and confirm unwanted spin settles.
4. Coast without turn or forward input and confirm AI Assisted does not erase intentional drift.
5. Hold `X` while spinning and confirm rotation is arrested before strong linear braking begins.
6. Continue holding `X` and confirm gradual world-relative braking without snapping.
7. Release `X` mid-brake and confirm immediate return to the selected mode.
8. Repeat Smart Stabilize in all three modes.
9. Change the default mode to AI Assisted in the pause menu, restart the game, and confirm persistence.
10. Confirm LMB/V fire, boost, camera modes, temporary views, pause/resume, restart, HUD vectors, and exact thruster visuals still work.

## 16. Out of scope

This milestone does not include:

- the practice drone or shield-impact visuals;
- target lock, aim assist, or weapon leading;
- obstacle avoidance or navigation autopilot;
- route following, docking, landing, or formation flight;
- voice lines, assistant personality, or cockpit animation;
- a low-level runtime thruster allocator;
- changes to camera behavior;
- changes to current Assisted or Inertial physics.
