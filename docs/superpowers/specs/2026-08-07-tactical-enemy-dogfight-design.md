# Tactical Enemy Dogfight — Design Specification

Date: 2026-08-07
Status: Approved design, ready for implementation planning after user review
Target branch: `agent/playable-flight-room`

## 1. Purpose

Replace the current practice-target experience in the default flight room with the first real one-on-one spacecraft dogfight.

The milestone adds exactly one hostile fighter that can:

- pursue and maneuver against the player using physically applied forces and torques;
- manage range, closure, attack geometry, disengagement, and re-entry;
- react to dangerous firing geometry with threat-aware evasive breaks;
- solve predictive pulse-cannon intercepts against a moving player;
- fire back only when it has a valid, fair firing solution;
- receive the existing shield-first projectile and collision damage;
- die, temporarily leave combat, then respawn into a fresh engagement;
- participate in the existing room reset, HUD, shield-impact, projectile, and damage systems.

The intended player-facing result is the first actual repeatable space dogfight loop:

> maneuver → gain firing geometry → exchange pulse fire → damage shields/hull → destroy enemy → enemy respawns → re-engage

This milestone is about tactical flight AI and fair return fire. It is not a general fleet-AI framework and it does not expand the weapon catalogue.

---

## 2. Locked product decisions

The following choices were explicitly approved and are fixed for this milestone.

### Enemy style

**Tactical space fighter.**

The enemy uses pursuit geometry, lead/lag decisions, range control, closure management, disengage/re-entry behavior, and inertial-aware maneuvering. It should not behave like a simple nose-chasing arcade drone.

### Enemy count

**Exactly one enemy fighter at a time.**

The goal is to make one opponent tactically credible and tunable before introducing formations, target prioritization, or multi-enemy pressure.

### Offensive capability

**Pulse-cannon return fire.**

The enemy uses the existing projectile/damage architecture rather than introducing heavy plasma, missiles, hitscan, or a second combat pipeline.

### Aiming

**Predictive lead aiming.**

The enemy solves an intercept from relative position, relative velocity, and projectile speed. It must physically rotate toward the solution and may fire only when the solution is valid and inside its legal firing envelope.

### Flight authority

**Similar physical rules, independently tuned fighter authority.**

The enemy receives its own mass, thrust, torque, speed, and tactical tuning. It is not required to match the player's exact numbers, but it cannot cheat outside its configured limits.

### Defensive behavior

**Threat-aware evasive breaks.**

The enemy may temporarily break from its preferred attack behavior when observable firing geometry becomes dangerous or when recent hostile fire creates credible pressure. It does not perform omniscient per-projectile dodging.

### Destruction lifecycle

**Short-delay respawn.**

The enemy is a repeatable combat-sandbox opponent. Destruction temporarily disables it, then it respawns into a fresh re-entry state.

---

## 3. Scope boundaries

### In scope

- one hostile fighter in the default flight room;
- dedicated tactical dogfight AI;
- predictive pulse-cannon fire control;
- enemy-specific physical tuning;
- enemy-specific projectile pool and weapon cadence;
- player damage from enemy projectiles;
- threat-aware evasive breaks;
- enemy destruction and respawn;
- combat HUD retargeting from the practice drone to the enemy fighter;
- deterministic pure solvers suitable for unit testing;
- integration with the existing shield, collision, projectile, room-reset, and damage systems;
- full regression verification against the existing 44-suite baseline.

### Explicitly out of scope

Do not silently add any of the following during this milestone:

- multiple simultaneous enemies;
- squad, formation, wingman, or fleet AI;
- missiles, torpedoes, heavy plasma, beams, lock-on weapons, or weapon selection;
- hitscan or homing pulse rounds;
- projectile bending or aim correction after firing;
- elaborate explosion VFX;
- asteroid destruction;
- audio overhaul;
- voice assistant callouts;
- target lock UI;
- radar/minimap;
- difficulty modes;
- general-purpose reusable NPC-pilot framework;
- final dedicated enemy spacecraft art;
- GitHub Actions workflows.

If any of these are desired later, record them in the deferred/LATER tracking file rather than expanding this milestone.

---

## 4. Existing systems that remain authoritative

The implementation must build on the current verified combat/flight foundation rather than replacing it.

Authoritative reusable systems include:

- `DamageState` for shield-first damage, hull damage, regeneration, destruction state, and reset;
- `CollisionDamageReceiver` and `CollisionDamageMath`;
- `ShieldImpactVisualizer` and the localized procedural hex shield effect;
- `PulseProjectile` and `PulseProjectilePool`;
- the current projectile speed of **900 m/s**;
- the current normal projectile damage of **15**;
- the player's exact model-derived primary muzzle sockets;
- the existing player flight controller, all three flight modes, Smart Stabilize, speed envelopes, boost thermals, camera modes, and exact thruster contracts;
- the flight-room reset/recovery architecture;
- the current combat HUD concepts for player shield/hull and target shield/hull.

### Non-regression boundary

The enemy milestone must not change the established player behavior unless a separate evidenced defect is found.

Specifically, do not alter:

- player rigid-body mass;
- player thrust/torque authority;
- player speed envelopes;
- player camera behavior;
- player firing cadence;
- player projectile speed/damage;
- player exact muzzle locations;
- player thruster mapping;
- AI Assisted behavior;
- Smart Stabilize behavior;
- Inertial zero-drift behavior.

---

## 5. Chosen architecture

Three approaches were considered.

### Rejected: evolve the practice drone into the fighter

This is fastest initially but would overload the training-drone controller with fighter-specific weapon, pursuit, evasion, and fire-control behavior. It would also make future drone and fighter roles difficult to separate.

### Chosen: dedicated enemy-fighter stack sharing combat infrastructure

Create a dedicated enemy fighter scene/controller and focused pure AI solvers while reusing the established damage, shield, collision, and projectile infrastructure.

This preserves clear boundaries:

- tactical decision-making is independent of physics application;
- aiming math is independent of weapon runtime state;
- weapon cadence is independent of flight steering;
- damage/shield systems remain shared;
- the player controller remains untouched.

### Rejected for now: generic NPC-pilot framework first

A full reusable pilot framework could serve future fighters, bombers, escorts, and fleets, but it is premature for one opponent and would substantially slow the first dogfight milestone.

---

## 6. Scene-level architecture

The default flight room will contain exactly one active hostile fighter instance.

The current `PracticeDrone` instance in the production flight room is replaced by `EnemyFighter` for this milestone. The practice-drone source files may remain in the repository as a standalone training/reference asset unless later cleanup is separately approved; they must not remain simultaneously active in the default dogfight room.

Conceptual enemy scene:

```text
EnemyFighter (RigidBody3D)
├── VisualRoot
│   └── Reused canonical fighter runtime model
├── CollisionShape3D
├── DamageState
├── CollisionDamageReceiver
├── ShieldImpactVisualizer
├── PulseProjectilePool
├── EnemyFighterController
├── EnemyWeaponController
└── DestructionPulse
```

The exact node names may follow current repository conventions, but responsibilities must stay separated as described below.

### Temporary enemy visual model

For this milestone, reuse the existing canonical fighter runtime model as the enemy airframe so actual fighter geometry, silhouette, and muzzle placement are exercised immediately.

The enemy must have a clearly hostile visual treatment that is lightweight and replaceable. The visual treatment must not require modifying the raw source model and must not block later replacement with a dedicated enemy spacecraft.

This is intentionally not the final enemy art milestone.

---

## 7. Physical flight contract

`EnemyFighter` is a real `RigidBody3D`.

### Live movement rule

While alive and active, every translational and rotational maneuver must be produced through real physics authority:

```gdscript
body.apply_central_force(...)
body.apply_torque(...)
```

No active-flight behavior may:

- directly assign `linear_velocity`;
- directly assign `angular_velocity`;
- overwrite the body transform to correct a turn;
- teleport to maintain range;
- snap orientation toward an aim solution;
- temporarily exceed configured authority because the target escaped;
- use hidden impulses outside its tuning contract.

### Respawn/reset exception

Direct transform/velocity assignment is allowed only while the enemy is frozen/inactive during explicit reset or respawn lifecycle operations, matching the existing combat-sandbox reset philosophy.

### Independent tuning

The enemy receives a dedicated tuning resource containing at least:

- rigid-body mass;
- forward/reverse force;
- lateral/vertical force;
- pitch/yaw/roll torque;
- normal speed soft-start and limit;
- angular soft-start and limit values;
- velocity/attitude response factors used by the AI controller;
- preferred combat range and range band;
- disengage/re-entry distance parameters;
- closure thresholds;
- evasion authority/response values;
- weapon range;
- firing cone;
- cadence;
- respawn delay.

Exact numeric values are implementation-tuning decisions. They must be explicit in the implementation plan and covered by bounded-output tests rather than embedded as unexplained magic values across multiple scripts.

---

## 8. Tactical AI boundaries

The tactical system is split into focused units.

### `TacticalDogfightSolver`

A pure decision/steering solver that consumes observable engagement state and produces a desired tactical intent.

Inputs should include only information the enemy is legitimately allowed to observe or infer:

- enemy transform and velocity;
- player transform and velocity;
- relative position;
- distance;
- closure rate;
- both forward directions;
- current tactical state;
- bounded timers/state-memory required for deterministic state transitions;
- recent hostile-fire pressure represented as observable combat activity, not player input state.

Outputs should include a small typed intent such as:

- desired movement/velocity direction;
- desired aim/facing direction;
- translational preference;
- tactical state;
- whether evasion currently has priority;
- optional bounded maneuver bias used to avoid deterministic deadlocks.

The solver does not apply forces itself.

### `ProjectileInterceptSolver`

A pure mathematical solver for pulse-cannon lead prediction.

Inputs:

- shooter position;
- shooter velocity;
- target position;
- target velocity;
- projectile speed.

Output:

- valid/invalid intercept result;
- intercept time when valid;
- intercept point or normalized firing direction when valid.

The solver must reject:

- non-finite input;
- non-positive projectile speed;
- mathematically impossible intercepts;
- negative/zero future solutions that are not usable;
- degenerate directions.

It must not read target input or future target commands.

### `EnemyFighterController`

The runtime orchestration layer.

Responsibilities:

- acquire and validate the player target;
- maintain the tactical state machine;
- gather observable engagement inputs;
- call the pure tactical solver;
- convert desired motion into bounded local force/torque demand;
- apply linear and angular speed envelopes;
- apply forces/torques to the rigid body;
- expose concise state for tests/HUD/debugging;
- stop all active steering while destroyed or respawning;
- reset all tactical memory on room reset/respawn.

The controller must not contain duplicated damage or projectile-hit logic.

### `EnemyWeaponController`

Responsibilities:

- resolve the canonical left/right primary muzzle sockets from the reused fighter model;
- compute predictive intercept through `ProjectileInterceptSolver`;
- measure angular error between the fighter's current firing axis and the valid intercept direction;
- enforce weapon range and firing cone;
- enforce its own cadence;
- alternate/use the canonical muzzle sockets consistently with the existing pulse-cannon pattern;
- fire through the enemy's own `PulseProjectilePool`;
- use the enemy rigid body as the source body so self-hits are excluded;
- stop firing while destroyed, respawning, target-invalid, out of range, or outside the firing cone;
- reset cadence on respawn/room reset.

This controller must not directly rotate the ship or modify tactical steering to fake aim.

---

## 9. Tactical behavior state machine

The enemy must behave as a tactical opponent rather than a permanent nose-chaser.

The exact enum names may vary, but the following behaviors are required.

### Acquire / Re-entry

Used after spawn/respawn or when useful engagement geometry has been lost.

Behavior:

- establish separation and a sensible intercept course;
- close from a useful angle instead of flying directly at the player's current position forever;
- avoid instantly entering a firing state solely because range is technically valid;
- transition toward attack when geometry and closure become suitable.

### Attack run

Primary offensive state.

Behavior:

- pursue a lead/lag geometry suitable for the current relative motion;
- orient toward a predictive firing solution rather than only the player's current location;
- maintain enough translational authority to bend the engagement while respecting inertia;
- seek a legal weapon solution rather than firing continuously.

### Range control

Used when distance or closure becomes tactically poor.

Behavior:

- reduce excessive closure;
- use lateral/vertical displacement rather than simply reversing directly backward every time;
- avoid occupying nearly the same position as the player;
- recover toward the preferred combat band.

### Overshoot prevention

High closing speed must be detected before a guaranteed pass-through.

The solver should respond by combining one or more legal actions:

- reduce forward closure;
- offset laterally/vertically;
- transition to a break/disengage path;
- begin reorientation before the closest pass.

It must not zero velocity or snap around after overshooting.

### Disengage

Used after a poor pass, excessive closure, or strongly unfavorable geometry.

Behavior:

- extend away for a bounded period/distance;
- rebuild separation;
- avoid immediately reversing direction at impossible angular rates;
- transition to re-entry once enough geometry has been recovered.

### Re-entry

Curves the fighter back toward a new attack after disengagement rather than oscillating in place.

### Threat-aware evasive break

Threat response temporarily takes priority over ordinary attack geometry when observable danger becomes strong enough.

Threat assessment may use:

- player facing relative to enemy position;
- distance;
- whether the enemy lies within a dangerous forward firing cone of the player;
- recent confirmed player firing activity or nearby hostile projectile pressure that the game can physically observe.

Threat assessment must not use:

- hidden player input commands;
- exact future player motion;
- omniscient knowledge of which individual projectile will hit;
- magical invulnerability windows.

Evasive response should combine bounded turn and lateral/vertical thrust to create a hard legal break. The break lasts for a bounded interval and then yields back to the normal tactical state machine.

---

## 10. Fire-control and fairness contract

The enemy's threat must come from positioning and aim, not cheating.

### Projectile behavior

Use the existing pulse projectile behavior:

- speed: **900 m/s**;
- normal damage: **15**;
- swept collision and first-hit resolution remain authoritative;
- no homing;
- no hitscan;
- no mid-flight aim correction.

### Firing gates

A shot is legal only when all required gates pass:

1. enemy and target are active;
2. target is within configured weapon range;
3. the intercept solver returns a valid future solution;
4. the valid intercept direction lies inside the configured firing cone relative to the actual current muzzle/fighter firing axis;
5. cadence allows the next shot;
6. muzzle and projectile pool are valid;
7. no destruction/respawn/reset state blocks firing.

If the solution becomes invalid, firing stops immediately.

### Accuracy philosophy

The AI earns hits by maneuvering the rigid body into a useful firing solution.

It does not receive:

- perfect instantaneous orientation;
- zero-spread guaranteed hits;
- target-leading information unavailable from physical state;
- projectile steering;
- range-independent accuracy;
- cadence bypasses.

Initial firing cone and cadence should be tuned so the enemy is threatening but visibly needs to line up a shot.

---

## 11. Damage, shield, and destruction behavior

The enemy reuses the existing combat damage architecture.

### Incoming player fire

Player pulse rounds hit `EnemyFighter` through the same `DamagePacket`/`DamageState` path already proven by the practice drone.

Required behavior:

- shield absorbs damage first;
- shield impacts trigger the localized hex effect at the actual hit location;
- shield break produces the existing brief shell break response;
- overflow damages hull;
- collision damage remains shield-first;
- hull reaching zero enters destruction state once.

### Enemy fire against player

Enemy pulse rounds use the same damage path against the player:

- 15 damage per normal projectile;
- shield first;
- hull after shield depletion;
- player recovery/reset behavior remains the established implementation.

### Enemy destruction

When hull reaches zero:

1. tactical steering stops;
2. weapon firing stops immediately;
3. enemy-owned projectiles are cleared or invalidated according to the final lifecycle implementation so respawn cannot inherit stale offensive state;
4. body freezes/inactivates;
5. collisions disable;
6. temporary existing destruction pulse is shown;
7. visual body hides after the established short destruction presentation;
8. respawn timer begins.

No elaborate explosion system is added in this milestone.

### Respawn

After a short configured delay:

- restore a controlled combat entry transform at safe separation;
- reset linear/angular velocity while frozen;
- restore collision layer/mask;
- restore full shield/hull using `DamageState.reset_state()` or equivalent established API;
- clear shield impact visuals;
- clear collision repeat-guard state;
- reset tactical state/timers/memory;
- reset weapon cadence;
- clear stale enemy projectiles;
- restore model visibility;
- unfreeze;
- begin in Acquire/Re-entry rather than immediately firing at spawn.

The respawn location must not place the enemy directly on top of the player.

---

## 12. Combat HUD integration

The current combat HUD remains restrained.

The target panel is retargeted from `PracticeDrone` to `EnemyFighter` and continues to show:

- target shield percentage/bar;
- target hull percentage/bar;
- active/respawning status.

The existing center hit marker remains tied to real applied damage and must still ignore wall hits/non-damaging resolutions.

No floating world-space health bar, radar, giant target banner, or lock-on reticle is added in this milestone.

Optional debug-only tactical-state text may exist behind tests/development instrumentation if useful, but it must not become permanent player HUD clutter unless separately approved.

---

## 13. Reset and room lifecycle

The existing room reset action remains authoritative.

Pressing reset must restore a deterministic clean combat state for both player and enemy.

Enemy reset requirements:

- frozen reset operation only;
- restore spawn/entry transform;
- zero stale velocities;
- restore collision;
- full shield/hull;
- clear shield visuals;
- clear collision guard;
- clear projectiles;
- reset tactical state;
- reset evasion timers;
- reset weapon cadence;
- restore active visuals;
- resume normal AI only after state restoration is complete.

A player death/reset must not leave the enemy in a stale firing or pursuit state against an invalid/frozen player target.

---

## 14. Determinism and numerical safety

Pure AI math must fail closed rather than emit corrupt physics commands.

Requirements:

- reject non-finite positions, velocities, times, directions, force demands, or torque demands;
- clamp all normalized command components to documented bounds;
- no division by near-zero values without guarded handling;
- intercept solver must select a valid positive future root when one exists;
- tactical state transitions must have explicit thresholds/hysteresis sufficient to prevent rapid state flicker at exact range boundaries;
- repeated identical pure-solver inputs should produce identical outputs;
- any later random personality/jitter system is explicitly outside this baseline unless seeded and separately designed.

---

## 15. Testing strategy

The milestone adds a small number of high-value suites rather than many micro-tests.

### Pure/unit coverage

At minimum verify:

#### Projectile intercept

- stationary target ahead produces a valid forward intercept;
- laterally moving target produces a lead solution;
- relative shooter velocity is accounted for correctly;
- impossible intercept returns invalid;
- non-finite/degenerate input fails closed;
- result time/direction remain finite.

#### Tactical dogfight solver

- far target selects acquire/approach behavior;
- good combat-band geometry selects attack behavior;
- excessive close range selects range-control behavior;
- excessive closure triggers overshoot prevention/disengage behavior before pass-through;
- disengaged fighter eventually selects re-entry when separation is recovered;
- dangerous player firing geometry triggers a bounded evasive break;
- safe geometry does not permanently force evasion;
- outputs are deterministic, finite, and bounded.

#### Authority

- requested force/torque never exceeds enemy tuning;
- speed/angular envelopes preserve opposing corrective authority near caps;
- active tactical code exposes no direct velocity/transform mutation path.

### Integration coverage

At minimum verify:

- production flight room contains exactly one `EnemyFighter` and no active `PracticeDrone` target;
- enemy resolves the player target;
- enemy movement occurs through applied force/torque over physics frames;
- enemy can create a valid predictive firing solution;
- enemy launches real pooled projectiles from the canonical primary muzzle hierarchy;
- enemy does not fire outside configured range;
- enemy does not fire when angular error is outside its firing cone;
- enemy projectile can damage player shield through the existing damage pipeline;
- subsequent damage can reach hull after shield depletion;
- player projectile still damages enemy through the existing path;
- enemy destruction disables steering and firing;
- timed respawn restores health, collisions, tactical state, weapon cadence, and visuals;
- stale enemy projectiles are not inherited across respawn/reset;
- room reset restores both ships;
- player destruction/recovery does not leave enemy fire-control in invalid state;
- target HUD reads the enemy fighter and respawn status;
- existing player hit marker behavior remains correct.

### Regression gate

All pre-existing **44 suites** must continue to pass.

The implementation plan must state the expected new suite count before code is written so test-runner registration does not accidentally create an intermediate impossible-green state.

---

## 16. Runtime verification gate

Before claiming this milestone technically complete:

1. run the repository's full local verification script using the available Godot 4.7.1 Linux binary;
2. confirm schema/thruster validation still passes;
3. confirm every old and new GDScript test suite passes;
4. confirm inertial rigid-body velocity preservation still reports zero/accepted drift;
5. run a full-game virtual-display runtime smoke long enough for the enemy to initialize, maneuver, and exercise weapon/runtime paths;
6. confirm there are no parser errors, invalid node paths, shader compilation errors, invalid calls, or runtime script errors.

Do not use GitHub Actions merely for this milestone's verification.

---

## 17. Manual gameplay acceptance

After automated verification, the remaining acceptance is subjective gameplay feel.

The player should be able to observe that:

1. one enemy fighter enters and actively engages;
2. it does not simply fly straight at the player's current position forever;
3. it closes intelligently from distance;
4. it manages close range rather than stacking on the player;
5. high closure produces an early break/disengage instead of impossible reversal after overshoot;
6. it extends and re-enters after a poor pass;
7. it visibly rotates into predictive firing geometry before shooting;
8. it leads a moving player instead of aiming only at current position;
9. shots can be avoided through maneuvering because projectiles remain physical and non-homing;
10. the enemy sometimes performs a legal evasive break when placed in dangerous firing geometry;
11. evasion does not make it permanently impossible to hit;
12. player and enemy shields/hulls behave consistently;
13. enemy death clearly disables combat behavior;
14. enemy respawns after a short delay and starts a fresh engagement;
15. the dogfight feels threatening and tactical without obvious AI cheating;
16. all existing player flight modes, cameras, stabilization, boost, muzzles, and controls still feel unchanged.

Tuning changes made solely to improve the enemy's own feel are allowed after this subjective pass as long as they remain inside the architectural and fairness contracts above.

---

## 18. Definition of done

This milestone is done only when all of the following are true:

- exactly one tactical enemy fighter is integrated into the default flight room;
- practice-drone target is no longer simultaneously active there;
- enemy live maneuvering is force/torque driven;
- enemy has independently tunable legal physical authority;
- tactical states cover acquire/re-entry, attack, range control, overshoot prevention, disengage, and evasive break;
- predictive intercept aiming is finite and tested;
- return fire uses real existing pulse projectiles and damage;
- firing range/cone/cadence gates are enforced;
- enemy destruction and short-delay respawn work cleanly;
- target HUD follows the enemy fighter;
- room reset remains deterministic;
- all pre-existing tests remain green;
- all new tests pass locally on Godot 4.7.1;
- runtime smoke is clean;
- no player flight/camera/muzzle/thruster regressions are introduced;
- user manually accepts the tactical/fun feel, or only enemy-specific tuning adjustments remain.

---

## 19. Deferred follow-ons

The following remain later additions and must not be merged into this implementation implicitly:

- dedicated enemy fighter Blender/model asset;
- multiple enemies and squad tactics;
- difficulty/personality variants;
- missiles/heavy plasma/secondary weapons;
- target lock/radar systems;
- richer destruction/explosion VFX;
- combat audio;
- asteroid destruction;
- projectile-specific dodge sophistication;
- generalized NPC-pilot framework.
