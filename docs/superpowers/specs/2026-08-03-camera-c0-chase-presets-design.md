# Camera C0: Bounded Chase Presets

Date: 2026-08-03
Status: Approved design
Branch: `agent/playable-flight-room`

## 1. Purpose

The current chase camera becomes excessively distant at high speed because its position combines:

- a fixed rear offset;
- speed-based pullback;
- a full world-velocity positional offset through `-world_velocity * velocity_look_ahead`.

At maximum boost speed, these terms can place the camera roughly 49 metres behind the ship. This makes the ship too small, weakens speed and distance judgment, and will obstruct aiming and target readability in the upcoming combat milestone.

Camera C0 corrects that behavior before combat. It adds three persistent chase-distance presets, binds `C` to cycle them, strictly bounds physical camera distance, and leaves tactical rear/side glance views for Camera C1.

## 2. Roadmap Position

Execution order is fixed as follows:

1. Camera C0: bounded chase position and Close/Standard/Far presets.
2. Combat Kernel 1: rapid pulse cannons, one target or simple enemy, hit detection, shields, hull, defeat, and reset.
3. Camera C1: hold-to-look rear, left, and right before full enemy dogfighting AI.
4. Combat Kernel 2: enemy pursuit/attack/retreat and then slow heavy plasma bolts.

Camera C0 is not optional polish. It is a combat-readability prerequisite.

## 3. Scope

### Included

- Remove world velocity from the camera's physical position.
- Restrict speed pullback to the ship's rear axis.
- Add Close, Standard, and Far chase presets.
- Bind `C` to cycle the chase preset.
- Start in Standard.
- Persist the selected preset during the current game session and through player reset.
- Smoothly transition height and rear distance between presets.
- Cap predictive look-ahead distance.
- Preserve ship-relative roll and inverted-flight camera orientation.
- Add a temporary-view override state boundary for Camera C1 without implementing tactical views yet.
- Add deterministic unit and integration coverage.

### Deferred to Camera C1

- Hold `B` for rear view.
- Hold `PgUp` for left view.
- Hold `PgDn` for right view.
- Combat target framing.
- Camera collision avoidance.
- Cinematic kill, destruction, or replay cameras.

### Explicitly unchanged

- Flight forces and steering behavior.
- Player input sampling for ship movement.
- Thruster visuals.
- Current shared speed-based FOV system, except where required to keep existing behavior compatible with bounded position logic.

## 4. Input Contract

Add a new `camera_cycle` input action bound to physical key `C`.

The camera rig owns this input directly because the action changes only camera state. It must not be added to `FlightCommand`, `PlayerInputSource`, or `ShipFlightController`.

Cycling uses `Input.is_action_just_pressed("camera_cycle")` so holding `C` changes the mode only once.

The fixed cycle order is:

```text
Standard -> Far -> Close -> Standard
```

The game starts in Standard. The selected mode persists through flight-room resets and player respawns for the current runtime session. Closing and reopening the game resets it to Standard.

## 5. Camera State Model

`ChaseCameraRig` owns two independent state values:

- `selected_preset`: `CLOSE`, `STANDARD`, or `FAR`.
- `temporary_view`: `NONE`, with `REAR`, `LEFT`, and `RIGHT` reserved for Camera C1.

Camera C0 always uses `temporary_view = NONE`.

Keeping persistent chase distance and temporary tactical direction separate prevents Camera C1 from replacing or corrupting the selected chase preset. When temporary views are implemented, releasing a glance input will return to the selected preset.

An invalid preset index or enum value must recover to Standard.

## 6. Preset Contract

Preset values are explicit typed data rather than scattered conditionals.

| Setting | Close | Standard | Far |
|---|---:|---:|---:|
| Rear offset | 10.5 m | 14.0 m | 20.0 m |
| Height | 3.2 m | 4.0 m | 5.0 m |
| Maximum speed pullback | 3.5 m | 5.0 m | 7.0 m |
| Hard rear-distance limit | 14.0 m | 19.0 m | 27.0 m |

The hard rear-distance limit is measured along the ship-relative rear axis from the camera target. It is not a world-space radial limit.

The preset collection must be immutable during normal runtime. Malformed preset data must not disable the entire camera. The rig retains the last valid preset and otherwise falls back to Standard.

## 7. Corrected Position Calculation

### Existing problem

The current desired position includes:

```gdscript
-world_velocity * velocity_look_ahead
```

This shifts the physical camera opposite the complete velocity vector. Forward speed adds excessive distance, lateral drift moves the camera sideways, and vertical drift alters camera height.

### New calculation

The desired camera position is:

```text
camera target position
+ ship-relative interpolated preset offset
+ ship-relative rear-axis speed pullback
```

Rules:

1. Remove the world-velocity positional term entirely.
2. Convert world velocity into the target's local frame.
3. Only positive forward speed contributes to rear pullback.
4. Lateral velocity does not change camera position.
5. Vertical velocity does not change camera position.
6. Reverse velocity contributes zero speed pullback.
7. Pullback is clamped to the selected preset's maximum speed pullback.
8. Final rear distance is clamped to the selected preset's hard rear-distance limit.
9. The camera must never cross in front of the target because of speed calculations.

The camera remains ship-relative and continues to follow rolls and inverted flight.

## 8. Predictive Look Target

Velocity remains useful for aiming and motion anticipation, but only in the look target.

The desired look target combines:

- the camera target position;
- existing forward nose look-ahead;
- a velocity-prediction vector capped to 8 metres.

The velocity prediction cap is applied to vector magnitude, not independently per axis. Zero or invalid velocity produces no predictive offset.

This preserves directional anticipation without moving the physical camera farther from the ship.

## 9. Transition Behavior

Preset changes interpolate rather than snap.

- Rear offset and height transition together.
- Expected transition duration is approximately 0.35 to 0.45 seconds under normal frame rates.
- The implementation uses frame-rate-independent exponential interpolation, consistent with existing camera smoothing.
- Interpolated rear distance must remain between the current and target preset values.
- The hard distance limit is enforced during every transition frame, not only after the transition completes.
- Rotation continues using existing ship-relative quaternion smoothing.
- FOV continues using existing smooth speed/boost behavior.

The selected preset changes immediately as state; its visual framing transitions smoothly.

## 10. Component Boundaries

### `ChaseCameraPreset`

A focused immutable value type or equivalent typed record containing:

- display or semantic name;
- rear offset;
- height;
- maximum speed pullback;
- hard rear-distance limit.

It contains no input or scene logic.

### `ChaseCameraMath`

Pure deterministic calculations for:

- local forward speed extraction;
- capped speed pullback;
- desired ship-relative position;
- capped predictive look offset;
- preset transition helpers where pure math is practical;
- existing basis and FOV calculations.

It does not access `Input`, scene nodes, or mutable runtime state.

### `ChaseCameraRig`

Owns:

- node resolution;
- selected preset state;
- reserved temporary-view state;
- `C` input handling;
- interpolation state;
- application of pure math outputs to the rig and `Camera3D`.

It does not own flight physics or mutate the player's velocity.

### Flight tuning

General speed limits and FOV values remain in `FlightTuning`. Preset-specific framing values belong to the camera subsystem rather than the flight-physics tuning resource.

## 11. Failure Handling

- Missing target, controller, camera, or required tuning remains a fatal initialization error for the rig, matching current behavior.
- An invalid selected preset recovers to Standard.
- A malformed non-selected preset does not disable the camera; cycling skips invalid entries or falls back to Standard.
- Non-finite velocity is treated as zero for camera offset calculations.
- Negative preset distances, pullback values, or limits are clamped or rejected by validation.
- The camera retains the last valid framing if a runtime calculation becomes non-finite.
- No camera error may affect ship control, flight forces, or thruster state.

## 12. Automated Verification

### Input tests

- `camera_cycle` exists.
- It is bound to physical key `C`.
- No existing action uses `C`.
- One just-pressed event advances exactly one mode.
- Holding the action does not repeatedly cycle modes.

### State tests

- Initial mode is Standard.
- Cycle order is Standard -> Far -> Close -> Standard.
- Invalid mode state recovers to Standard.
- Player or room reset does not change the selected preset.
- The temporary-view state boundary exists and defaults to NONE.

### Position math tests

For each preset:

- zero-speed desired position matches the preset offset;
- maximum forward speed does not exceed maximum speed pullback;
- final rear distance does not exceed the hard limit;
- lateral velocity does not alter rear distance or side offset;
- vertical velocity does not alter height or rear distance;
- reverse velocity adds no pullback;
- camera position never moves in front of or through the ship due to velocity;
- non-finite or malformed inputs fail safely.

### Look-target tests

- predictive velocity look-ahead never exceeds 8 metres;
- forward nose look-ahead remains active;
- lateral velocity can influence look direction without shifting physical camera position;
- zero velocity produces no predictive offset.

### Transition tests

- rear offset moves monotonically toward the selected preset;
- height moves monotonically toward the selected preset;
- no intermediate frame exceeds the relevant hard limit;
- transitions are frame-rate independent within tolerance.

### Regression tests

- rolled ship camera up remains aligned with ship up;
- inverted ship produces inverted camera perspective;
- existing FOV clamps remain valid;
- flight-room scene still contains and resolves the chase camera rig.

## 13. Manual Acceptance Gate

At normal and boost speeds:

1. Standard is the initial view and provides combat-readable framing.
2. `C` cycles Standard -> Far -> Close -> Standard.
3. Holding `C` does not skip modes.
4. Close keeps the ship large and readable.
5. Far provides wider awareness without making the ship tiny.
6. The camera never reaches the former excessive distance.
7. Sideways drift does not drag the camera sideways.
8. Vertical drift does not pull the camera above or below its preset framing.
9. Reverse thrust does not move the camera through the ship.
10. Rolls and inverted flight preserve ship-relative orientation.
11. Mode transitions are smooth and bounded.
12. Resetting the flight room retains the selected mode.

The local verification command must pass before combat implementation begins:

```powershell
.\tools\verify\verify.ps1
```

No success claim is made until the user provides the local verifier output and confirms the camera behavior in the running game.

## 14. Completion and Next Milestone

Camera C0 is complete only after automated verification and the manual acceptance gate pass locally.

The next implementation milestone is Combat Kernel 1:

- rapid pulse cannons first;
- one target dummy or simple enemy;
- hit detection;
- shields then hull damage;
- defeat and deterministic reset.

Slow heavy plasma bolts are added only after the pulse-cannon loop is complete. Camera C1 tactical views are added before full enemy dogfighting AI.
