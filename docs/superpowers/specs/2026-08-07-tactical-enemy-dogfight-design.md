# Tactical Enemy Dogfight — Design Specification

Date: 2026-08-07
Status: Approved design, pending final user review before implementation planning
Target branch: `agent/playable-flight-room`

## 1. Purpose

Replace the current practice-target experience in the default flight room with the first real one-on-one spacecraft dogfight.

The milestone adds exactly one hostile fighter that can:

- pursue and maneuver against the player using physically applied forces and torques;
- manage range, closure, attack geometry, disengagement, and re-entry;
- react to dangerous firing geometry with threat-aware evasive breaks;
- solve predictive pulse-cannon intercepts against a moving player;
- fire back only when it has a valid, fair, unobstructed firing solution;
- receive the existing shield-first projectile and collision damage;
- die, temporarily leave combat, then respawn into a fresh engagement;
- participate in the existing room reset, HUD, shield-impact, projectile, and damage systems.

The intended loop is:

> maneuver → gain firing geometry → exchange pulse fire → damage shields/hull → destroy enemy → enemy respawns → re-engage

This milestone is about tactical flight AI and fair return fire. It is not a general fleet-AI framework and it does not expand the weapon catalogue.

---

## 2. Locked product decisions

These choices are fixed for this milestone.

- **Enemy style:** tactical space fighter using pursuit geometry, lead/lag behavior, range control, closure management, disengage/re-entry, and inertial-aware maneuvering.
- **Enemy count:** exactly one enemy fighter at a time.
- **Offense:** pulse-cannon return fire using the existing projectile/damage architecture.
- **Aiming:** predictive lead aiming based on physical state, not hidden input or perfect aim.
- **Flight authority:** similar physical rules to the player, but independently tuned mass/thrust/torque/speed envelopes.
- **Defense:** threat-aware evasive breaks, not omniscient projectile dodging.
- **Destruction lifecycle:** short-delay respawn for continuous dogfight testing.

---

## 3. Scope boundaries

### In scope

- one hostile fighter in the default flight room;
- dedicated tactical dogfight AI;
- predictive pulse-cannon fire control;
- independent enemy physical tuning;
- enemy projectile pool and cadence;
- player damage from enemy projectiles;
- threat-aware evasive breaks;
- enemy destruction and respawn;
- target HUD retargeted from practice drone to enemy fighter;
- deterministic pure solvers suitable for unit testing;
- integration with existing shield, collision, projectile, room-reset, and damage systems;
- full regression verification against the existing 44-suite baseline.

### Explicitly out of scope

Do not silently add:

- multiple simultaneous enemies;
- squad, formation, wingman, or fleet AI;
- missiles, torpedoes, heavy plasma, beams, lock-on weapons, or weapon selection;
- hitscan or homing pulse rounds;
- projectile bending or post-fire aim correction;
- elaborate explosion VFX;
- asteroid destruction;
- combat audio overhaul;
- voice assistant callouts;
- radar/minimap or target-lock UI;
- difficulty modes;
- a general-purpose NPC-pilot framework;
- final dedicated enemy spacecraft art;
- GitHub Actions workflows.

Any newly approved later addition must be recorded in the deferred/LATER tracking file rather than expanding this milestone.

---

## 4. Existing systems that remain authoritative

Reuse the current verified combat/flight foundation rather than replacing it.

Authoritative systems include:

- `DamageState` for shield-first damage, hull damage, regeneration, destruction, and reset;
- `CollisionDamageReceiver` and `CollisionDamageMath`;
- `ShieldImpactVisualizer` and the localized procedural hex shield effect;
- `PulseProjectile` and `PulseProjectilePool`;
- projectile speed **900 m/s**;
- normal projectile damage **15**;
- the canonical fighter model's exact primary muzzle sockets;
- the current player flight controller, all three flight modes, Smart Stabilize, speed envelopes, boost thermals, cameras, and exact thruster contracts;
- flight-room reset/recovery architecture;
- existing player/target combat HUD concepts.

### Non-regression boundary

Do not alter established player behavior unless a separate evidenced defect is found.

Specifically do not change:

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

### Rejected: evolve the practice drone into the fighter

Fast initially, but it would overload the training-drone controller with fighter-specific pursuit, evasion, aiming, and weapon logic.

### Chosen: dedicated enemy-fighter stack sharing combat infrastructure

Create a dedicated enemy fighter scene/controller and focused pure AI solvers while reusing established damage, shield, collision, and projectile infrastructure.

Boundaries:

- tactical decision-making is independent of physics application;
- intercept math is independent of weapon runtime state;
- weapon cadence is independent of flight steering;
- damage/shield systems remain shared;
- the player controller remains untouched.

### Rejected for now: generic NPC-pilot framework first

Useful later for fleets, escorts, and bombers, but premature for one opponent and would slow this milestone.

---

## 6. Scene-level architecture

The production flight room contains exactly one active hostile fighter.

The current `PracticeDrone` instance in the default room is replaced by `EnemyFighter`. Practice-drone source files may remain as a standalone training/reference asset, but the practice drone must not remain simultaneously active in the dogfight room.

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

Exact node names may follow current repository conventions, but responsibilities must remain separated.

### Temporary enemy visual

Reuse the canonical fighter runtime model so fighter geometry and exact muzzle placement are exercised immediately. Apply a clearly hostile but lightweight replaceable visual treatment without editing raw source assets.

This is intentionally not the final enemy-art milestone.

---

## 7. Physical flight contract

`EnemyFighter` is a real `RigidBody3D`.

### Live movement

While alive and active, every maneuver must be produced through real physics authority:

```gdscript
body.apply_central_force(...)
body.apply_torque(...)
```

Active flight may not:

- directly assign `linear_velocity`;
- directly assign `angular_velocity`;
- overwrite transform to correct a turn;
- teleport to maintain range;
- snap orientation toward aim;
- temporarily exceed configured authority because the target escaped;
- use hidden impulses outside tuning.

### Respawn/reset exception

Direct transform/velocity assignment is allowed only while frozen/inactive during explicit reset or respawn lifecycle operations.

### Independent enemy tuning

A dedicated resource must define at least:

- mass;
- forward/reverse force;
- lateral/vertical force;
- pitch/yaw/roll torque;
- linear speed soft-start and cap;
- angular soft-start and cap;
- AI velocity/attitude response;
- preferred combat range and range band;
- disengage/re-entry thresholds;
- closure/overshoot thresholds;
- evasion strength and duration limits;
- weapon range;
- firing cone;
- cadence;
- respawn delay.

Exact numeric values are implementation-tuning choices, but the implementation plan must choose them explicitly and tests must enforce bounded authority.

---

## 8. AI component boundaries

### `TacticalDogfightSolver`

Pure tactical solver. It consumes observable engagement state and returns desired tactical intent.

Allowed inputs include:

- enemy transform/velocity;
- player transform/velocity;
- relative position and distance;
- closure rate;
- both forward directions;
- current tactical state;
- bounded state timers/memory;
- recent hostile-fire pressure observable from game state.

It must not read player control input.

Output should be a small typed intent containing, as needed:

- desired movement/velocity direction;
- desired aim/facing direction;
- tactical state;
- whether evasion has temporary priority;
- bounded maneuver bias used to prevent deterministic deadlocks.

The solver never applies forces.

### `ProjectileInterceptSolver`

Pure pulse-cannon lead solver.

Inputs:

- shooter position;
- shooter velocity;
- target position;
- target velocity;
- projectile speed.

Output:

- valid/invalid result;
- positive future intercept time when valid;
- intercept point or normalized firing direction.

Reject:

- non-finite input;
- non-positive projectile speed;
- impossible intercepts;
- unusable non-positive roots;
- degenerate directions.

It must not read target input or future target commands.

### `EnemyFighterController`

Runtime orchestration layer.

Responsibilities:

- acquire/validate player target;
- maintain tactical state;
- gather observable engagement inputs;
- call pure tactical solver;
- convert desired motion into bounded local force/torque demand;
- apply linear/angular envelopes;
- apply force/torque to the rigid body;
- expose concise state for tests/debugging;
- stop steering while destroyed/respawning;
- reset tactical memory on respawn/reset.

It does not duplicate damage or projectile-hit logic.

### `EnemyWeaponController`

Responsibilities:

- resolve canonical left/right primary muzzle sockets from the reused fighter model;
- compute predictive intercept through `ProjectileInterceptSolver`;
- measure angular error from the actual current firing axis;
- enforce weapon range and firing cone;
- perform a real physics-space line-of-sight test before firing;
- treat the enemy body and its own projectile infrastructure as excluded/self geometry for that check;
- treat blocking world geometry or another collision body between muzzle and intended intercept path as obstruction;
- enforce its own cadence;
- alternate/use canonical muzzle sockets consistently with the existing pulse-cannon pattern;
- fire through the enemy's own `PulseProjectilePool`;
- use enemy rigid body as projectile source so self-hits are excluded;
- stop firing while destroyed, respawning, target-invalid, obstructed, out of range, or outside firing cone;
- reset cadence on respawn/reset.

The weapon controller does not rotate the ship or fake aim.

---

## 9. Tactical state machine

The enemy must behave as a tactical opponent rather than a permanent nose-chaser.

### Acquire / Re-entry

Used after spawn/respawn or when useful geometry is lost.

- establish separation and a sensible intercept course;
- close from a useful angle instead of always steering at current player position;
- do not enter firing state solely because range is technically valid;
- transition toward attack when geometry and closure are suitable.

### Attack run

- use lead/lag geometry appropriate to relative motion;
- orient toward predictive firing solution rather than only current player position;
- bend the engagement while respecting inertia;
- seek a legal firing solution rather than continuously firing.

### Range control

When too close or closure becomes poor:

- reduce excessive closure;
- use lateral/vertical displacement rather than only reversing straight backward;
- avoid occupying nearly the same position as the player;
- recover toward preferred combat band.

### Overshoot prevention

Detect high closure before pass-through and respond through legal force/torque:

- reduce forward closure;
- offset laterally/vertically;
- break/disengage;
- begin reorientation before closest pass.

Never zero velocity or snap around after overshooting.

### Disengage

After a poor pass or strongly unfavorable geometry:

- extend away for a bounded period/distance;
- rebuild separation;
- avoid impossible instant reversal;
- transition to re-entry after geometry recovers.

### Re-entry

Curve back toward a new attack run rather than oscillating in place.

### Threat-aware evasive break

Threat response temporarily overrides normal attack behavior when observable danger becomes strong enough.

Allowed threat inputs:

- player facing relative to enemy position;
- distance;
- whether enemy lies inside a dangerous player-forward firing cone;
- recent player firing activity or nearby hostile projectile pressure observable in the world.

Forbidden threat inputs:

- hidden player input commands;
- exact future player motion;
- omniscient knowledge that a specific projectile will hit;
- magical invulnerability.

Evasion combines bounded rotation and lateral/vertical thrust for a hard legal break. It lasts a bounded interval and then yields to the normal tactical state machine.

---

## 10. Fire-control and fairness contract

### Projectile behavior

Use existing pulse projectile behavior:

- speed **900 m/s**;
- normal damage **15**;
- swept collision and first-hit resolution remain authoritative;
- no homing;
- no hitscan;
- no post-fire aim correction.

### Firing gates

A shot is legal only when all gates pass:

1. enemy and target are active;
2. target is inside configured weapon range;
3. intercept solver returns a valid positive future solution;
4. intercept direction lies inside configured firing cone relative to the real current firing axis;
5. line of sight from the active muzzle toward the intended shot path is unobstructed by blocking world/collision geometry;
6. cadence allows the shot;
7. muzzle and projectile pool are valid;
8. no destruction, respawn, reset, or invalid-target state blocks firing.

If any required gate becomes invalid, firing stops immediately.

### Accuracy philosophy

The AI earns hits by physically maneuvering into a useful firing solution.

No:

- perfect instantaneous orientation;
- guaranteed zero-error hits;
- hidden future-input knowledge;
- projectile steering;
- range-independent accuracy;
- cadence bypasses;
- firing through solid obstructions.

Initial cone and cadence should make the enemy threatening while visibly requiring alignment.

---

## 11. Damage, shield, and destruction

### Player fire against enemy

Player pulse rounds use the existing `DamagePacket`/`DamageState` path.

Required:

- shield-first damage;
- localized hex shield impact at actual hit;
- existing shield-break response;
- overflow to hull;
- shield-first collision damage;
- hull zero enters destruction once.

### Enemy fire against player

Enemy pulse rounds use the same path:

- 15 damage per normal projectile;
- shield first;
- hull after shield depletion;
- established player death/recovery remains unchanged.

### Enemy destruction

When hull reaches zero:

1. steering stops;
2. firing stops immediately;
3. stale enemy projectiles are cleared/invalidated so respawn cannot inherit offensive state;
4. body freezes/inactivates;
5. collisions disable;
6. current temporary destruction pulse is shown;
7. visual body hides after the short destruction presentation;
8. respawn timer begins.

No elaborate explosion system is added here.

### Respawn

After a short configured delay:

- restore a controlled combat-entry transform at safe separation;
- reset linear/angular velocity while frozen;
- restore collision layer/mask;
- restore full shield/hull using established damage reset API;
- clear shield visuals;
- clear collision repeat-guard state;
- reset tactical state/timers/memory;
- reset weapon cadence;
- clear stale enemy projectiles;
- restore visual body;
- unfreeze;
- begin in Acquire/Re-entry rather than firing immediately.

Respawn must never place the enemy directly on top of the player.

---

## 12. HUD integration

The existing combat HUD remains restrained.

Retarget the target panel from `PracticeDrone` to `EnemyFighter` while retaining:

- target shield percentage/bar;
- target hull percentage/bar;
- ACTIVE/RESPAWN status.

The center hit marker remains tied to real applied damage and must still ignore wall hits/non-damaging resolutions.

Do not add floating world-space health bars, radar, giant target banners, or lock-on UI in this milestone.

Debug-only tactical-state instrumentation may exist for testing but must not become permanent HUD clutter without separate approval.

---

## 13. Reset and lifecycle

The existing room reset remains authoritative.

Enemy reset must:

- run transform/velocity restoration while frozen;
- restore safe spawn/entry transform;
- zero stale velocities;
- restore collision;
- restore full shield/hull;
- clear shield visuals and collision guard;
- clear enemy projectiles;
- reset tactical state/evasion timers;
- reset weapon cadence;
- restore visuals;
- resume AI only after restoration completes.

Player death/reset must not leave the enemy firing at an invalid/frozen player target.

---

## 14. Determinism and numerical safety

Pure AI math must fail closed.

Requirements:

- reject non-finite positions, velocities, times, directions, force demand, or torque demand;
- clamp normalized commands to documented bounds;
- guard near-zero division;
- intercept solver selects a valid positive future root when one exists;
- tactical transitions use explicit thresholds/hysteresis to prevent boundary flicker;
- identical pure-solver inputs produce identical outputs;
- random personality/jitter is outside this baseline unless separately designed and seeded.

---

## 15. Testing strategy

Use a small number of high-value suites rather than many micro-tests.

### Pure/unit coverage

#### Projectile intercept

Verify:

- stationary target ahead gives valid intercept;
- lateral moving target produces lead;
- relative shooter velocity is accounted for;
- impossible intercept is invalid;
- non-finite/degenerate input fails closed;
- result time/direction remain finite.

#### Tactical solver

Verify:

- far target selects acquire/approach;
- good combat-band geometry selects attack;
- excessive close range selects range control;
- excessive closure triggers overshoot prevention/disengage before pass-through;
- disengaged fighter selects re-entry after separation recovers;
- dangerous player firing geometry triggers bounded evasive break;
- safe geometry does not permanently force evasion;
- outputs are deterministic, finite, and bounded.

#### Authority

Verify:

- force/torque never exceeds enemy tuning;
- speed/angular envelopes preserve opposing corrective authority near caps;
- active tactical code has no direct velocity/transform mutation path.

### Integration coverage

Verify:

- production room contains exactly one `EnemyFighter` and no active `PracticeDrone` target;
- enemy resolves the player;
- live movement occurs through force/torque over physics frames;
- enemy can create a valid predictive solution;
- enemy launches pooled projectiles from canonical primary muzzles;
- enemy does not fire outside range;
- enemy does not fire outside firing cone;
- enemy does not fire when line of sight is blocked by solid geometry;
- enemy projectile damages player shield through existing pipeline;
- damage can reach player hull after shield depletion;
- player projectile still damages enemy through existing pipeline;
- destruction disables steering and firing;
- timed respawn restores health, collision, tactical state, cadence, projectiles, and visuals;
- stale enemy projectiles do not survive respawn/reset;
- room reset restores both ships;
- player recovery does not leave enemy fire-control invalid;
- target HUD reads enemy fighter and respawn state;
- existing player hit-marker behavior remains correct.

### Regression gate

All pre-existing **44 suites** remain green.

The implementation plan must choose the expected new suite count before code is written so runner registration does not create an impossible intermediate green gate.

---

## 16. Runtime verification gate

Before claiming technical completion:

1. run the full local repository verifier using the available Godot 4.7.1 Linux binary;
2. confirm schema/thruster validation still passes;
3. confirm every old/new test suite passes;
4. confirm inertial rigid-body velocity preservation remains within its accepted zero-drift contract;
5. run a full-game virtual-display smoke long enough for enemy initialization, maneuvering, and weapon paths;
6. confirm no parser errors, invalid node paths, shader errors, invalid calls, or runtime script errors.

Do not use GitHub Actions merely to verify this milestone.

---

## 17. Manual gameplay acceptance

After automated verification, subjective acceptance should confirm:

1. one enemy fighter actively engages;
2. it does not permanently nose-chase current player position;
3. it closes intelligently from distance;
4. it manages close range instead of stacking on the player;
5. high closure causes an early break/disengage rather than impossible reversal after overshoot;
6. it extends and re-enters after a poor pass;
7. it physically rotates into predictive firing geometry before shooting;
8. it leads a moving player rather than only aiming at present position;
9. shots remain avoidable because pulse rounds are physical and non-homing;
10. solid world geometry blocks enemy firing when it obstructs the shot path;
11. it performs legal evasive breaks under dangerous firing geometry;
12. evasion does not make it permanently impossible to hit;
13. player/enemy shields and hull behave consistently;
14. destruction clearly disables enemy combat behavior;
15. enemy respawns after a short delay and starts a fresh engagement;
16. the fight feels tactical and threatening without obvious cheating;
17. existing player flight modes, cameras, stabilization, boost, muzzles, thrusters, and controls remain unchanged in feel.

Enemy-specific tuning may be adjusted after subjective testing as long as the fairness and physics contracts stay intact.

---

## 18. Definition of done

Complete only when:

- exactly one tactical enemy fighter is integrated into default flight room;
- practice-drone target is not simultaneously active there;
- live enemy maneuvering is force/torque driven;
- enemy has independently tunable legal physical authority;
- tactical behavior covers acquire/re-entry, attack, range control, overshoot prevention, disengage, and evasive break;
- predictive intercept aiming is finite and tested;
- return fire uses real existing pulse projectiles/damage;
- range, cone, line-of-sight, and cadence gates are enforced;
- destruction and short-delay respawn work cleanly;
- target HUD follows the enemy fighter;
- room reset is deterministic;
- all pre-existing tests remain green;
- all new tests pass locally on Godot 4.7.1;
- runtime smoke is clean;
- no player flight/camera/muzzle/thruster regression is introduced;
- user manually accepts tactical/fun feel, or only enemy-specific tuning remains.

---

## 19. Deferred follow-ons

Remain later:

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
