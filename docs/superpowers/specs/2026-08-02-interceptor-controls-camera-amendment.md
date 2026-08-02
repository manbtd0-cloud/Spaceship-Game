# Interceptor Controls and Camera Amendment

## Status

User-directed amendment to `2026-08-02-interceptor-flight-refinement-design.md`. This document supersedes only the control bindings and chase-camera horizon behavior described in the original design.

## Final Control Mapping

| Input | Action |
|---|---|
| W / S | Forward / reverse thrust |
| Q / E | Lateral strafe left / right |
| Space / Ctrl | Vertical strafe up / down |
| Mouse | Analog pitch / yaw |
| A / D | Digital yaw left / right |
| Up / Down Arrow | Digital pitch up / down |
| Left / Right Arrow | Roll left / right |
| Shift | Sustained translational boost |
| F | Toggle assisted / manual mode |
| R | Reset flight room and thermal state |
| Escape | Toggle mouse capture |

Roll polarity is explicit: Left Arrow produces positive local-Z roll torque and a left bank; Right Arrow produces negative local-Z roll torque and a right bank. This corrects the previous reversed A/D roll behavior.

Mouse and digital pitch/yaw inputs may compose and clamp. A/D yaw participates in assisted coordinated banking. Arrow-key roll immediately overrides generated banking just as the previous manual-roll binding did.

## Ship-Relative Camera

Space has no preferred upright direction. The chase camera must therefore:

- use the target ship's local `+Y` axis as its camera-up reference;
- follow the ship's roll, inversion, vertical attitude, and arbitrary orientation;
- never blend toward global `Vector3.UP`;
- select another ship-local axis only for the mathematical singularity where the look direction is nearly parallel to ship-local up;
- retain smooth position, rotation, pullback, and FOV interpolation.

The player-owned `CameraTarget` inherits the rigid body's orientation. The chase rig targets that node and computes its desired basis through pure `ChaseCameraMath.desired_camera_basis()`.

## Hero Asset Integration Note

The pushed runtime export is accepted for development integration with manifest dimensions approximately `3.13 x 2.35 x 6.01 m`, `-Z` forward, and `+Y` up. It is the mandatory player visual with no procedural hull fallback. Redistribution remains development-only until license evidence is added and reviewed.
