# Primary Fire Showcase Design

## Purpose

Provide a directly launchable debug scene that lets the player visibly inspect the already-tested primary firing system before the practice-drone milestone begins.

## Scope

The showcase is an isolated development scene. It does not alter the main flight room, player flight behavior, damage tuning, projectile rules, or the approved practice-drone design.

## Scene

Launch path:

```powershell
godot --path . res://scenes/debug/primary_fire_showcase.tscn
```

The scene contains:

- the production `player_interceptor.tscn` fighter at the origin;
- the canonical schema-5 left and right muzzle sockets;
- the production `PrimaryFireController` attached to the player instance;
- the production `PulseProjectilePool` and `pulse_projectile.tscn`;
- the production chase camera following the stationary fighter;
- a dark controlled firing lane with emissive depth rings;
- one large non-damageable impact wall at the end of the lane;
- a small overlay showing controls, total shots, active projectiles, resolved impacts, and the most recently fired side.

## Behavior

- The fighter is frozen in place, with zero linear and angular velocity.
- Holding left mouse or physical `V` fires at the production 7 shots/second cadence.
- Fire alternates Left, Right, Left, Right using the production cadence state.
- Projectile origin and orientation come from the verified fighter muzzle transforms.
- Projectile travel remains body-forward at 900 m/s.
- Projectiles collide with the wall using the production swept collision query and deactivate on impact.
- `R` clears the pool and resets showcase counters and cadence.
- `Escape` exits the showcase.
- Mouse capture stays disabled because the scene is for weapon observation, not flight control.

## Architecture

`PrimaryFireShowcaseController` owns only showcase wiring and telemetry. It injects the pool into the production fire controller, freezes the ship, handles reset/exit, and updates labels. It contains no cadence, projectile, muzzle, collision, or damage arithmetic.

## Verification

An integration test must prove:

- the scene loads and uses `PrimaryFireShowcaseController`;
- the production player, chase camera, pool, fire controller, wall, lane markers, and UI exist;
- the fire controller points to the exact player body, input source, and canonical model paths;
- showcase initialization injects the pool and leaves firing enabled;
- one held-fire step creates exactly one active projectile from the left muzzle;
- resetting clears active projectiles, counters, and cadence;
- the test leaves no orphan nodes or retained resources.

## Deferred

The showcase does not add shield impacts, damageable targets, drone visuals, explosions, audio, camera shake, or main-flight-room integration. Those remain in later Combat Kernel milestones.
