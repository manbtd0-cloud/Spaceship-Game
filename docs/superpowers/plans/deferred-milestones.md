# Deferred Milestones and Later Additions

This file is the authoritative wait list for approved additions that must not interrupt the active implementation milestone.

## Current execution order

1. Finish the active **Realistic Flight, Camera Modes, Velocity Marker, Pause and Persistent Settings** milestone.
   - Task 6 is verified.
   - Continue Tasks 7–10 without inserting the work below into the active implementation.
2. At milestone closure, select the exact order between the already-approved practice drone and the AI-assisted flight-control milestone below.
3. Do not silently implement either deferred milestone while the current milestone is still open.

---

# Deferred Milestone: AI-Assisted Flight Mode and Universal Smart Stabilize

## Status

- Approved as a future milestone.
- Do not implement during the current flight/camera/settings milestone.
- Requires its own Superpowers design specification, TDD implementation plan, RED tests, implementation, full verifier pass, and Windows manual acceptance.
- The current **Assisted** and **Inertial** modes must remain exactly available and must not have their established physics behavior changed.

## Purpose

The current realistic flight model is fun but difficult for a normal player to master. Add a third, substantially easier mode that behaves like an onboard flight computer interpreting pilot intent and operating the ship's real thrusters for the pilot.

Player-facing mode name:

- **AI Assisted**

Conceptual fiction:

- An onboard ship assistant continuously interprets what the pilot is trying to accomplish.
- The assistant chooses coordinated real thruster and torque commands to produce that result.
- The assistant does not teleport the ship, overwrite transforms, directly assign a fake velocity, or replace the rigid-body physics model.

## Non-regression boundary

The following must remain unchanged unless a separate evidenced defect is found:

- Inertial mode remains true inertial control.
- Existing Assisted mode remains the current energy-neutral assisted model.
- Rigid-body mass, damping, force application, torque application, speed envelopes, boost thermals, coordinated bank, camera behavior, and weapon behavior remain authoritative.
- Pure rotation in Inertial continues to preserve world velocity and speed.
- Existing tests for Assisted and Inertial remain valid and green.
- AI Assisted is additive; it must not be implemented by weakening or replacing the existing modes.

## AI Assisted intent model

AI Assisted should translate pilot input into a desired maneuver rather than treating every input as only a raw local-axis command.

Example:

- The ship is travelling straight with no current thrust.
- The pilot pitches the nose upward.
- In Inertial mode, this remains rotation only.
- In current Assisted mode, existing behavior remains unchanged.
- In AI Assisted mode, the onboard assistant infers that the pilot intends to bend the actual trajectory upward.
- It combines rotational control with appropriate translational thruster force so the world-velocity vector progressively turns toward the intended direction.

The assistant should use coordinated combinations of the ship's real capabilities:

- pitch, yaw, and roll torque;
- forward and reverse thrust;
- lateral strafe thrust;
- vertical thrust;
- angular damping/counter-torque;
- controlled velocity redirection;
- braking support when the requested maneuver cannot be achieved safely by steering force alone.

## AI Assisted baseline behavior

The future design must define and test at least these behaviors:

1. **Continuous attitude stabilization**
   - Uncommanded pitch, yaw, and roll should be actively arrested.
   - Releasing rotational input should cause the flight computer to settle the ship rather than allowing continued uncontrolled spin.

2. **Intent-following trajectory control**
   - Rotational pilot input should normally communicate a desired travel direction as well as a desired nose direction.
   - The flight computer should bend the true velocity vector toward the intended direction using physically applied force.
   - The true velocity marker must visibly converge toward the nose reticle during a commanded turn.

3. **Coordinated thruster allocation**
   - The system chooses an efficient combination of translation and rotation instead of requiring the player to manually coordinate every axis.
   - Strafe and vertical input remain explicit pilot intent and are incorporated into the solution.

4. **Pilot authority**
   - The pilot's current command remains the target intent.
   - Assistance must not fight a sustained explicit command.
   - Mode switching must be deterministic and must clear stale AI integrator/stabilization state.

5. **Physical limits**
   - Forces and torques remain bounded by ship tuning.
   - No instantaneous stopping, snapping, transform warping, or direct fake velocity assignment.
   - The assistant may prioritize stability and achievable motion when a requested maneuver exceeds available authority.

6. **Readable feedback**
   - HUD must show `MODE   AI ASSISTED` when active.
   - The nose reticle continues to show orientation.
   - The velocity marker continues to show actual trajectory, allowing the player to see the assistant redirecting motion.
   - Additional AI-state feedback may be designed later, but it must remain restrained and not clutter the existing telemetry.

## Architecture direction for later design

Keep intent interpretation separate from the existing rigid-body force model.

Likely boundaries to formalize during the future design phase:

- a typed third `FlightMode` value;
- a pure AI flight-intent/steering solver;
- a small runtime AI-assist state object for stabilization and response smoothing;
- bounded output expressed through the same force/torque pipeline used by the ship controller;
- additional tuning fields stored in the existing flight tuning resource;
- no second player controller and no duplicate physics body;
- settings and pause-menu integration through the existing typed settings service and coordinator.

The exact public APIs and tuning values are intentionally deferred until the dedicated design/spec phase.

## Required TDD coverage for AI Assisted

The later implementation plan must include RED tests for:

- the third flight mode being valid and selectable;
- existing Assisted and Inertial behavior remaining unchanged;
- rotational intent while moving producing trajectory-redirection force in AI Assisted;
- no rotational input causing angular stabilization/counter-torque;
- assistance output remaining finite and bounded;
- no direct transform or velocity overwrite;
- sustained pilot input not being cancelled by the assistant;
- mode changes clearing stale AI state;
- velocity marker moving toward the nose during AI-guided turns;
- settings persistence and pause-menu selection for AI Assisted;
- full player-scene and flight-room integration without duplicate controllers.

---

# Universal Ship Feature: Smart Stabilize

## Locked choice

Ahmad selected **C — Smart Stabilize**.

This is a built-in ship function available in all three flight modes:

- Inertial
- Assisted
- AI Assisted

It is not itself a fourth flight mode.

## Intended behavior

When activated, Smart Stabilize temporarily takes priority over ordinary flight assistance:

1. First arrest dangerous/unwanted angular motion using bounded counter-torque.
2. Then progressively brake linear velocity toward zero relative to the current flight-room/world reference frame.
3. Keep using real forces and torques; do not instantly assign zero velocity.
4. Releasing or completing stabilization returns authority to the currently selected flight mode.

The practical player intent is:

- “Stop rotating.”
- “Bring this ship under control.”
- “Brake me to a stable rest relative to the local game-world reference frame.”

The phrase “rest” is a gameplay reference-frame concept, not a claim of absolute rest in space.

## Input reservation

- Reserve one dedicated input action for Smart Stabilize across every mode.
- Exact physical key/button is not locked yet and must be selected during the dedicated design phase after checking all existing bindings.
- The design phase must explicitly decide hold-versus-toggle behavior; no assumption is locked yet.

## Smart Stabilize requirements

- Works in Inertial, Assisted, and AI Assisted.
- Does not permanently change the selected mode.
- Uses bounded real counter-torque and braking force.
- Angular stabilization begins immediately.
- Linear braking follows progressively and predictably.
- Extra activation must not create duplicated force application.
- Reset clears all Smart Stabilize runtime state.
- Pause freezes its progress with the rest of gameplay.
- HUD must provide a clear but restrained active-state indication.
- It must not interfere with camera controls, primary fire, boost heat, or the existing reset action.

## Required TDD coverage for Smart Stabilize

The later implementation plan must test:

- activation in every flight mode;
- angular velocity decreasing toward zero;
- linear speed decreasing progressively rather than snapping;
- force and torque outputs remaining finite and bounded;
- selected flight mode remaining unchanged;
- release/completion returning normal control cleanly;
- reset clearing stabilization state;
- no duplicate application when repeatedly activated;
- pause behavior;
- input-map ownership and non-conflict with all existing controls.

## Manual acceptance for the future milestone

The eventual Windows acceptance must include:

1. Build rotational velocity, activate Smart Stabilize, and confirm spinning is arrested first.
2. Begin with significant drift, activate Smart Stabilize, and confirm gradual world-relative braking.
3. Release during braking and confirm immediate return to the selected mode without a velocity snap.
4. Repeat in Inertial, Assisted, and AI Assisted.
5. In AI Assisted, command a turn and confirm the velocity marker bends toward the nose reticle through real acceleration.
6. Confirm existing Inertial preservation tests still pass when Smart Stabilize is inactive.

## Explicitly deferred decisions

Do not silently decide these before the dedicated design phase:

- exact key/button binding;
- hold versus toggle activation;
- braking strength and maximum deceleration;
- angular settle thresholds;
- whether Smart Stabilize automatically releases at its rest threshold;
- AI Assisted response aggressiveness;
- whether AI Assisted preserves speed by default during turns or permits limited automatic braking;
- any additional HUD animation, assistant voice, or cockpit presentation.
