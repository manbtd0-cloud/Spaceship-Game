# Playable Flight Room Plan Correction

This file is an authoritative correction to `docs/superpowers/plans/2026-08-02-playable-flight-room.md`.

## Task 4 — `ChaseCameraMath.desired_position()`

The velocity term must move the camera opposite the ship velocity so the camera lags behind acceleration. Replace the planned addition:

```gdscript
+ world_velocity * maxf(velocity_look_ahead, 0.0)
```

with:

```gdscript
- world_velocity * maxf(velocity_look_ahead, 0.0)
```

The complete return expression is:

```gdscript
return (
    target_transform.origin
    + target_transform.basis.orthonormalized() * (
        base_offset + Vector3(0.0, 0.0, pullback)
    )
    - world_velocity * maxf(velocity_look_ahead, 0.0)
)
```

For the planned test input `world_velocity = Vector3(0.0, 0.0, -100.0)`, this keeps the desired camera position farther behind the ship (`position.z > 16.0`) and makes the test, design intent, and implementation consistent.
