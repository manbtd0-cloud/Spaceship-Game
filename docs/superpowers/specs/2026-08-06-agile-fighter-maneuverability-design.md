# Agile Fighter Maneuverability Design

**Date:** 2026-08-06  
**Repository:** `manbtd0-cloud/Spaceship-Game`  
**Branch:** `agent/playable-flight-room`  
**Status:** Approved design

## 1. Purpose

Increase the fighter's base maneuverability so pitch, yaw, roll, strafing, vertical thrust, and reverse braking feel like an agile combat spacecraft rather than a heavy transport.

This change targets the ship's real physical authority. It does not alter AI Assisted behavior, Smart Stabilize logic, mass, collision geometry, speed limits, camera behavior, controls, weapons, thruster sockets, or the checked-in thruster action matrix.

## 2. Locked handling target

The selected profile is **Agile Fighter**:

- fast initial rotational response;
- strong lateral and vertical translation;
- strong reverse braking;
- clear physical momentum rather than instant arcade snapping;
- controllable maximum angular rates;
- full compatibility with AI Assisted and Smart Stabilize;
- automatic control remains limited to the same authority available to direct player input.

## 3. Mass and collision preservation

Keep the production `RigidBody3D` mass at:

```text
8500 kg
```

Keep the existing collider, inertia calculation, gravity settings, damping settings, continuous collision detection, and sleep behavior unchanged.

The mass must not be reduced to create agility. Lowering mass would unintentionally change collision momentum, projectile/body interactions, every translation acceleration value, and the established physical scale.

## 4. Translation authority

Update the checked-in `FlightTuning` values to:

```text
forward_force = 150000 N
reverse_force = 110000 N
strafe_force = 150000 N
```

`strafe_force` remains the shared authority for local X and local Y, so left/right and up/down retain equal maximum acceleration.

At `8500 kg`, the approximate unboosted accelerations become:

```text
forward: 17.65 m/s²
reverse: 12.94 m/s²
strafe/vertical: 17.65 m/s²
```

Requirements:

- combined translation remains normalized to one command envelope through `FlightAuthority`;
- forward/reverse asymmetry remains exact;
- boost continues to use the existing `1.8` multiplier and thermal lockout;
- normal and boosted speed limits remain `160 m/s` and `240 m/s`;
- the speed envelope continues to attenuate only force that increases total speed;
- braking and redirection remain fully available above the speed envelope;
- Smart Stabilize and AI Assisted automatically inherit these new legal translation limits.

## 5. Rotational authority

Update the checked-in torque values to:

```text
pitch_torque = 190000 Nm
yaw_torque = 230000 Nm
roll_torque = 210000 Nm
```

Yaw receives the highest torque because the wide/long fighter body has the greatest practical resistance around that axis. Roll remains faster than pitch/yaw in its allowed angular-rate ceiling, but not because of unlimited torque growth.

Requirements:

- direct player rotation uses the new torque values;
- AI Assisted counter-torque uses the same values;
- Smart Stabilize counter-torque uses the same values;
- no automatic system may exceed full direct-player torque on any axis;
- no angular velocity is assigned directly.

## 6. Per-axis angular speed envelope

Add a pure per-axis angular speed envelope so strong torque creates fast response without allowing endlessly increasing spin.

### 6.1 Limits

Use these checked-in values:

```text
pitch_angular_soft_start_degrees = 75
pitch_angular_limit_degrees = 100

yaw_angular_soft_start_degrees = 75
yaw_angular_limit_degrees = 100

roll_angular_soft_start_degrees = 112.5
roll_angular_limit_degrees = 150
```

The soft start is 75% of each limit.

### 6.2 Behavior

For each local angular axis independently:

- below soft start, torque that increases the current angular rate remains at full authority;
- between soft start and limit, same-direction torque smoothly fades toward zero;
- at or above the limit, same-direction torque is removed;
- torque opposing the current angular velocity remains fully available at every rate;
- torque on another axis is evaluated independently;
- zero or near-zero angular velocity does not create artificial damping;
- non-finite input fails closed to zero output.

This means a player can reach useful turn rates quickly, but holding rotation cannot accelerate the ship into uncontrollable infinite spin.

### 6.3 Architecture

Create a focused pure helper:

```text
FlightAngularEnvelope
```

Suggested interface:

```gdscript
FlightAngularEnvelope.apply_to_torque(
    torque_local: Vector3,
    angular_velocity_local: Vector3,
    soft_start_degrees: Vector3,
    limit_degrees: Vector3
) -> Vector3
```

The helper performs no node, body, input, or transform access.

`ShipFlightController` applies this envelope once to the final composed torque after pilot and automatic commands have already been combined through the legal authority system.

This placement guarantees:

- pilot plus AI cannot stack beyond legal torque;
- the cap evaluates the actual final requested torque;
- Smart Stabilize opposing torque is never weakened;
- legacy Assisted behavior uses the same safe final cap;
- only one torque vector is applied to the body.

## 7. Flight-mode behavior

### Assisted

Retains coordinated banking, existing nose-led steering, and existing damping architecture. It gains the new physical torque and translation authority and the final angular speed envelope.

### AI Assisted

Its trajectory-centering logic remains unchanged. It gains the increased physical authority and therefore becomes more capable, but it still obeys the shared player-equivalent cap and angular speed envelope.

### Inertial

Pure rotation input uses the new torque and angular-rate envelope. With no input and no Smart Stabilize, it still applies no automatic force or torque and must retain exact inertial velocity preservation.

### Smart Stabilize

Its command logic remains unchanged. It inherits the new maximum force and torque values. Because the angular envelope never attenuates opposing torque, Smart Stabilize retains full legal counter-torque even above the rotation limits.

## 8. Thruster feedback

The checked-in schema-five thruster action matrix remains authoritative.

Requirements:

- stronger direct commands continue to map through the existing action matrix;
- automatic output remains direction-correct and capped to actual legal authority;
- no visual target exceeds `1.0`;
- no socket, effect mesh, nozzle transform, or runtime allocation changes;
- legacy Assisted visual cap remains `0.35`;
- AI Assisted and Smart Stabilize may show full output when their legal commands reach full authority.

No additional visual intensity multiplier is needed. The existing command-normalized visual system already represents full command authority as `1.0`.

## 9. Non-regression boundary

The following remain unchanged:

- production mass and collider;
- flight mode cycle and persistence;
- AI trajectory target and explicit-input protection;
- Smart Stabilize command generation;
- normal and boosted speed limits;
- boost heat, lockout, cooling, and recovery;
- inertial zero-drift contract;
- primary fire and projectile behavior;
- exact muzzle transforms;
- camera modes, distances, and temporary views;
- pause, settings, and reset ownership;
- HUD copy and velocity marker math;
- schema-five asset contract;
- deterministic thruster matrix;
- scene hierarchy and raw assets.

## 10. Automated verification

Add one focused unit suite for `FlightAngularEnvelope`, increasing the runner target from `PASS: 38 suites` to `PASS: 39 suites`.

Required tests:

### Angular envelope

- full torque below soft start;
- smooth partial authority between soft start and limit;
- zero same-direction torque at or above the limit;
- full opposing torque above the limit;
- independent pitch, yaw, and roll evaluation;
- roll uses its higher ceiling;
- finite fail-closed behavior;
- zero angular velocity preserves requested torque.

### Authority tuning

- checked-in production values exactly match `150000`, `110000`, `150000`, `190000`, `230000`, and `210000`;
- mass remains exactly `8500`;
- speed limits remain `160` and `240`;
- boost multiplier remains `1.8`.

### Controller integration

- final same-direction torque is attenuated near each angular limit;
- final opposing torque remains full above each limit;
- Smart Stabilize receives full counter-torque above the limit;
- AI plus pilot still cannot exceed one legal torque command;
- inertial no-input output remains zero;
- existing thruster visual and mode tests remain green.

### Full verifier

The authoritative Windows gate must report:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 39 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
```

The main scene must boot without parser, path, runtime, orphan-node, or retained-resource errors.

## 11. Manual acceptance

Launch with:

```powershell
godot --path .
```

Acceptance criteria:

1. Pitch and yaw begin responding quickly from rest.
2. Roll feels faster than pitch/yaw but remains controllable.
3. Holding rotation reaches a stable maximum rate rather than accelerating indefinitely.
4. Releasing input in Inertial preserves the current angular rate.
5. Holding `X` strongly arrests rotation even when above the normal angular limit.
6. Sideways and vertical movement feel substantially stronger.
7. Reverse thrust provides meaningful braking.
8. Combined translation remains controlled and does not gain diagonal extra authority.
9. AI Assisted remains aggressive but does not exceed player authority.
10. Assisted, Inertial, firing, boost, cameras, pause, reset, collisions, HUD vectors, exact muzzles, and exact thrusters remain functional.

## 12. Completion rule

Do not mark this maneuverability correction verified until both the `PASS: 39 suites` Windows verifier and the manual acceptance session pass.
