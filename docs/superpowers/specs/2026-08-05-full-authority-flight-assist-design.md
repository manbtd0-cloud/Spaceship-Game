# Full-Authority AI Assisted Flight and Smart Stabilize Design

**Date:** 2026-08-05  
**Repository:** `manbtd0-cloud/Spaceship-Game`  
**Branch:** `agent/playable-flight-room`  
**Status:** Approved design

## 1. Purpose

Strengthen the existing AI Assisted mode and hold-`X` Smart Stabilize so both visibly and physically use the ship's available thruster authority instead of applying mild correction.

The change is a control-strength correction, not a new movement system. It preserves the existing rigid-body, force, torque, boost, speed-envelope, exact-thruster, camera, weapon, pause, settings, and reset architecture.

## 2. Locked authority rule

Automatic control may use the ship's **full direct-control authority**, but may never exceed what the player can produce through full input on the same axis in the same runtime state.

The authoritative limits are the existing `FlightTuning` values and `FlightModel` rules:

- positive/negative local X: `strafe_force`;
- positive/negative local Y: `strafe_force`;
- local -Z thrust: `forward_force`;
- local +Z thrust: `reverse_force`;
- pitch torque: `pitch_torque`;
- yaw torque: `yaw_torque`;
- roll torque: `roll_torque`.

Translation receives the existing boost multiplier only when boost is actually held, thermally available, and represented by the controller's current effective boost value. Smart Stabilize and AI Assisted do not silently create boost authority. Torque remains unaffected by boost, matching direct player control.

For combined translation, the automatic command is normalized exactly like `PlayerInputMath.compose_translation()`. Automatic diagonal movement therefore cannot obtain full authority independently on every translation axis when a player could not do so with the same combined input.

Combined pitch, yaw, and roll may each reach their existing independent torque limits because current player rotation input can command those axes simultaneously.

## 3. Shared authority calculation

Extract the direct force/torque construction into a pure typed helper used by both `FlightModel` and the automatic solvers.

Suggested name:

```text
FlightAuthority
```

Public responsibilities:

```text
translation_force(command_local, boost_amount, tuning) -> Vector3
rotation_torque(command_local, tuning) -> Vector3
```

Requirements:

- translation input is clamped to length `1.0`;
- asymmetric forward/reverse force remains exact;
- boost uses the existing `lerpf(1.0, boost_multiplier, effective_boost)` rule;
- rotation input is clamped per axis to `[-1, 1]`;
- output is finite;
- the helper does not access nodes, input, transforms, or velocities.

`FlightModel` must use this helper for normal pilot output. Smart Stabilize and AI Assisted must use the same helper for their maximum authority. This prevents automatic control limits from drifting away from player control limits later.

## 4. Full-authority Smart Stabilize

### 4.1 Simultaneous six-axis cancellation

While `X` is held, Smart Stabilize immediately cancels both angular and linear velocity. Linear braking no longer waits for angular velocity to settle.

On every physics tick:

1. Convert current world linear and angular velocity into ship-local coordinates through the existing controller path.
2. Build a translation command opposite local linear velocity.
3. Build pitch, yaw, and roll commands opposite each local angular-velocity component.
4. Use `FlightAuthority` to convert those normalized commands into legal full-output force and torque.
5. Apply force and torque together through the existing `FlightOutput` assistance channels.

Examples:

- rotating left produces maximum legal right-yaw counter-torque;
- pitching upward produces maximum legal downward-pitch counter-torque;
- rolling clockwise produces maximum legal counter-roll torque;
- moving forward activates legal reverse braking authority;
- moving backward activates legal forward braking authority;
- moving left/right or up/down activates the opposite maneuvering authority;
- combined movement and rotation activate every relevant mapped thruster concurrently, subject to the same normalized translation envelope as player input.

### 4.2 Near-rest taper

Full opposite authority is used while velocity is meaningfully above the capture zone. Commands taper only near zero to prevent overshoot and oscillation.

Use per-axis response functions:

```text
linear command magnitude = clamp(abs(axis_velocity) / linear_capture_speed, 0, 1)
angular command magnitude = clamp(abs(axis_rate) / angular_capture_rate, 0, 1)
```

Initial capture values:

```text
linear_capture_speed = 4.0 m/s
angular_capture_rate = 8 degrees/second
linear_rest_threshold = 0.10 m/s
angular_rest_threshold = 0.25 degrees/second
```

Above each capture value, that axis requests full legal authority. Below it, authority tapers continuously to zero at the rest threshold.

### 4.3 Boost and speed-envelope behavior

- Without effective boost, stabilization uses normal full player translation authority.
- With effective boost, stabilization may use the same boosted translation authority available to the player on that tick.
- Stabilization never exceeds the active direct-control authority.
- Braking remains available above the normal or boosted speed limit, matching current player braking behavior.
- Smart Stabilize never assigns velocity directly.

## 5. Full-authority AI Assisted flight

### 5.1 Continuous trajectory target

AI Assisted continuously tries to center the true velocity marker on the nose reticle, not only while turn input is held.

For non-trivial speed:

```text
desired_local_velocity = Vector3.FORWARD * current_speed
velocity_error = desired_local_velocity - current_local_velocity
```

This target preserves current speed conceptually while rotating the velocity vector toward ship-forward.

At very low speed, no automatic translation is needed unless the player provides translation input.

### 5.2 Full legal correction

Convert `velocity_error` into a normalized local translation command.

- Large mismatch: request full legal player-equivalent translation authority.
- Small mismatch: taper proportionally to avoid hunting around the reticle.
- Correct X, Y, and Z together.
- Continue correction after the pilot releases pitch/yaw until the velocity marker is centered.
- Preserve explicit strafe and vertical intent by combining the pilot's current translation target with the alignment target before final normalization rather than generating a force that fights the pilot.
- Preserve explicit reverse intent; AI Assisted must not force forward alignment while the player is intentionally commanding reverse.

Initial response values:

```text
ai_full_authority_error_speed = 12.0 m/s
ai_capture_error_speed = 0.75 m/s
ai_min_alignment_speed = 2.0 m/s
```

The correction command magnitude is:

```text
clamp((error_speed - capture_error_speed) /
      (full_authority_error_speed - capture_error_speed), 0, 1)
```

The command direction follows the velocity error. This gives full authority when the marker is substantially displaced and a smooth taper near the crosshair.

### 5.3 Angular stabilization

AI Assisted uses maximum legal counter-torque on each uncommanded rotational axis when angular velocity is large, tapering only near zero.

Pilot rotational input remains authoritative:

- an explicitly commanded axis is not counter-commanded;
- uncommanded axes remain strongly stabilized;
- after input release, full counter-torque is applied until the rate enters the capture band;
- all torque remains within current pitch/yaw/roll limits.

Use the same angular capture/rest thresholds as Smart Stabilize unless testing identifies a concrete oscillation problem.

## 6. Controller integration

`ShipFlightController` remains the sole runtime owner.

The physics flow remains:

```text
PlayerInputSource
  -> FlightCommand
  -> boost thermal state / effective boost
  -> FlightModel pilot output
  -> AI Assisted or Smart Stabilize automatic command
  -> FlightAuthority legal force/torque
  -> FlightOutput assistance channels
  -> apply_central_force / apply_torque
```

Priority:

1. Smart Stabilize held: suppress ordinary pilot force/torque telemetry and use full-authority stabilization.
2. Otherwise AI Assisted selected: retain pilot output and add legal full-authority alignment/stabilization output.
3. Otherwise preserve existing Assisted or Inertial behavior exactly.

No second body, controller, allocator, transform write, velocity assignment, or per-frame input access is added.

## 7. Thruster visuals

The checked-in schema-5 action matrix remains authoritative.

Visual limits must reflect physical authority without exceeding direct player output:

- legacy Assisted corrections retain the existing `0.35` visual cap;
- AI Assisted automatic output may reach `1.0` when it requests full legal authority;
- Smart Stabilize automatic output may reach `1.0` when it requests full legal authority;
- no automatic visual target may exceed `1.0`;
- direct pilot output retains precedence when direct and automatic requests overlap;
- no new sockets, procedural exhaust, or runtime allocation is introduced.

The controller or telemetry path must expose which assistance source is active so the visual controller can choose `0.35` for legacy Assisted and `1.0` for AI Assisted/Smart Stabilize without guessing from raw force values.

## 8. Non-regression boundary

The following remain unchanged:

- Assisted flight behavior when Smart Stabilize is inactive;
- Inertial zero-drift behavior when Smart Stabilize is inactive;
- direct player force and torque limits;
- boost thermals and lockout;
- speed envelopes;
- coordinated banking in legacy Assisted;
- camera behavior and distances;
- primary fire and projectile behavior;
- exact muzzle transforms;
- exact schema-5 thruster geometry and mappings;
- pause/settings/reset ownership;
- mode persistence and explicit mode cycle.

## 9. Automated verification

Add or strengthen tests for:

### Shared authority

- helper output exactly matches current `FlightModel` direct force/torque for single and combined commands;
- combined translation never exceeds normalized player input authority;
- forward/reverse asymmetry remains exact;
- effective boost scales automatic translation exactly like player translation;
- no automatic output exceeds legal per-axis/direct-command authority.

### Smart Stabilize

- full opposite torque on pitch, yaw, and roll above capture rate;
- simultaneous full legal cancellation for combined angular axes;
- full opposite translation command above capture speed;
- simultaneous legal cancellation for combined X/Y/Z velocity;
- forward drift uses reverse authority and backward drift uses forward authority;
- boost changes stabilization authority only when effective boost is active;
- near-rest taper prevents force/torque at thresholds;
- force/torque remain finite;
- selected mode remains unchanged;
- pilot telemetry stays suppressed while stabilizing;
- full-authority visual output never exceeds `1.0`.

### AI Assisted

- velocity error targets ship-forward at preserved speed;
- correction remains active after rotation input is released;
- large marker displacement requests full legal authority;
- small displacement tapers smoothly;
- X/Y/Z correction is supported;
- explicit strafe, vertical, and reverse input are not fought;
- angular stabilization reaches legal full authority on uncommanded axes;
- commanded rotation remains authoritative;
- AI visuals may reach `1.0` but never exceed direct output.

### Existing gates

- all current suites remain green;
- inertial verifier remains exactly zero drift;
- schema-5 asset and action-matrix validators remain green;
- main scene boots cleanly;
- LMB/V firing, camera, pause, settings, reset, and exact thruster ownership remain intact.

## 10. Windows acceptance

1. Build forward velocity and hold `X`; retro thrusters visibly fire at legal full intensity and speed drops strongly.
2. Build backward velocity and hold `X`; main thrusters visibly fire at legal full intensity.
3. Add lateral and vertical drift together; relevant maneuvering thrusters fire concurrently and cancel both axes.
4. Add pitch, yaw, and roll simultaneously; opposite torque thrusters fire concurrently until rotation settles.
5. Repeat combined linear and angular motion; all required legal counter-thrusters operate together.
6. Hold boost and `X`; stabilization may use the same boosted translation authority, never more.
7. In AI Assisted, create a large velocity-marker offset; the ship strongly drives the marker toward the nose even after releasing turn input.
8. Near alignment, correction tapers without visible oscillation.
9. Explicit strafe, vertical, reverse, primary fire, camera, pause, reset, and mode switching remain usable.
10. Inertial and legacy Assisted remain unchanged when `X` is not held.

## 11. Out of scope

- low-level runtime thruster allocation;
- direct velocity or transform assignment;
- exceeding player-equivalent force or torque;
- automatic boost activation;
- changes to ship mass or direct-control tuning;
- practice drone, target lock, aim assist, docking, navigation, or obstacle avoidance.
