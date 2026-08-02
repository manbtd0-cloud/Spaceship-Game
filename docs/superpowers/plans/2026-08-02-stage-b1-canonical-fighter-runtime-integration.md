# Canonical Fighter Runtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the committed schema-2 canonical fighter at identity transform and drive all twelve imported thruster sockets from the final local force and torque output.

**Architecture:** Preserve the existing physics model. Expose the final local wrench from `ShipFlightController`, solve visual-only socket intensities in a pure allocator, and let a socket visual controller own all exhaust effects under the imported GLB hierarchy.

**Tech Stack:** Godot 4.7.1, typed GDScript, GL Compatibility, existing custom test harness.

## Global Constraints

- Canonical fighter dimensions are approximately `13.714 x 3.562 x 12.000 m`.
- Collider size is exactly `Vector3(14.0, 3.8, 12.2)`.
- Godot local forward is `-Z`, up is `+Y`, right is `+X`.
- No runtime model adapter or corrective transform.
- Exactly 2 main, 2 retro, and 8 maneuver sockets.
- Idle exhaust is completely invisible.
- Visual allocation must not change physics.
- No GitHub Actions.

---

### Task 1: Canonical asset contract

**Files:**
- Modify: `tests/integration/test_hero_ship_asset.gd`
- Delete from runner later: `tests/integration/test_hero_ship_adapter.gd`

**Interfaces:**
- Consumes: committed canonical GLB.
- Produces: integration assertions for identity root, dimensions, socket paths, absent temporary markers/flames.

- [ ] Replace marker-based assertions with schema-2 canonical assertions.
- [ ] Assert dimensions within `0.05 m` of `Vector3(13.714, 3.562, 12.0)`.
- [ ] Assert the twelve exact semantic socket paths exist.
- [ ] Assert socket scales equal `Vector3.ONE`.
- [ ] Assert `EngineFire*`, `ForwardMarker`, and `UpMarker` are absent.
- [ ] Run `godot --headless --path . --script res://tests/test_runner.gd` and verify the new test fails against temporary player integration only, not asset import.
- [ ] Commit.

### Task 2: Final wrench telemetry

**Files:**
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_ship_flight_state.gd` or add `tests/unit/test_ship_flight_controller_state.gd`

**Interfaces:**
- Produces: `get_last_force_local() -> Vector3`, `get_last_torque_local() -> Vector3`.

- [ ] Write failing reset/getter tests.
- [ ] Store `FlightOutput.force_local` and `torque_local` immediately before applying them.
- [ ] Add typed getters.
- [ ] Reset both vectors in `reset_runtime_state()`.
- [ ] Run tests and commit.

### Task 3: Pure thruster allocator

**Files:**
- Create: `src/player/ship_thruster_allocator.gd`
- Create: `tests/unit/test_ship_thruster_allocator.gd`

**Interfaces:**
- Produces: `ShipThrusterAllocator.solve(sockets: Array[Dictionary], desired_force: Vector3, desired_torque: Vector3, force_reference: float, torque_reference: float) -> PackedFloat32Array`.
- Socket dictionary keys: `position: Vector3`, `reaction_direction: Vector3`, `class: StringName`.

- [ ] Write failing tests for zero wrench, forward, reverse, lateral translation, pure torque, combined wrench, bounds, and determinism.
- [ ] Implement a fixed-pass projected coordinate-descent solver over normalized six-dimensional wrench columns.
- [ ] Clamp each intensity to `[0, 1]` and sanitize non-finite values to zero.
- [ ] Run tests and commit.

### Task 4: Reusable socket exhaust effect

**Files:**
- Create: `src/player/thruster_exhaust_effect.gd`
- Create: `tests/unit/test_thruster_exhaust_effect.gd`

**Interfaces:**
- Produces: `set_output(intensity: float, boost: float, thruster_class: StringName) -> void`.

- [ ] Write failing tests for hidden idle and class-dependent scale parameters using pure helper functions.
- [ ] Generate a cylinder/cone mesh and emissive material in code.
- [ ] Align the effect with socket local `-Z` and offset it behind the nozzle.
- [ ] Keep node invisible below `0.001` intensity.
- [ ] Commit.

### Task 5: Socket visual controller

**Files:**
- Create: `src/player/ship_thruster_visual_controller.gd`
- Create: `tests/integration/test_ship_thruster_visual_controller.gd`

**Interfaces:**
- Consumes: canonical model root and `ShipFlightController`.
- Produces: one effect per imported socket and per-frame allocator updates.

- [ ] Write failing scene integration test requiring twelve resolved sockets and twelve hidden effects at idle.
- [ ] Resolve exact socket hierarchy recursively.
- [ ] Build socket dictionaries from position and `basis.z` reaction direction in player-local space.
- [ ] Instantiate one `ThrusterExhaustEffect` per socket.
- [ ] Solve intensities from final force/torque telemetry.
- [ ] Apply boost styling only to active main/retro translational sockets.
- [ ] Fail closed with all effects hidden when the socket contract is invalid.
- [ ] Commit.

### Task 6: Player scene replacement

**Files:**
- Modify: `scenes/player/player_interceptor.tscn`
- Modify: `tests/integration/test_player_scene.gd`
- Delete: `src/player/hero_ship_model_adapter.gd`
- Delete: `src/player/ship_visual_controller.gd`
- Delete: `src/player/ship_visual_math.gd`
- Delete: obsolete tests for adapter/rear-only visual math.

**Interfaces:**
- Consumes: `ShipThrusterVisualController`.

- [ ] Write failing player-scene assertions for collider, no adapter, no glow anchors, and new controller.
- [ ] Set collider to `Vector3(14.0, 3.8, 12.2)`.
- [ ] Keep canonical model transform identity.
- [ ] Remove adapter and old glow nodes/resources.
- [ ] Add new visual controller paths.
- [ ] Update camera target only if required by the wider canonical hull.
- [ ] Commit.

### Task 7: Runner and documentation

**Files:**
- Modify: `tests/test_runner.gd`
- Modify: `README.md`

- [ ] Add allocator/effect/controller suites.
- [ ] Remove obsolete adapter and rear-only exhaust suites.
- [ ] Document canonical identity import and twelve dynamic thrusters.
- [ ] Update expected suite count from actual runner contents.
- [ ] Commit.

### Task 8: Local verification checkpoint

- [ ] Run `python -m unittest tests.tools.test_small_fighter_calibration -v`.
- [ ] Run `.\tools\assets\export-small-fighter.ps1`.
- [ ] Run `.\tools\verify\verify.ps1`.
- [ ] Launch `godot --path .`.
- [ ] Confirm identity orientation, correct scale, dark idle, forward/reverse/strafe/vertical/pitch/yaw/roll jets, assisted steering jets, auto-bank jets, and collision envelope.
- [ ] Commit any generated import metadata only when the repository policy requires it.
