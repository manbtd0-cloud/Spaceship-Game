# Combat Kernel 1 Design

**Status:** Approved for specification review  
**Date:** 2026-08-03  
**Repository:** `manbtd0-cloud/Spaceship-Game`  
**Target branch:** `agent/playable-flight-room`  
**Engine:** Godot 4.7.1 Standard  
**Renderer:** GL Compatibility

## 1. Purpose

Combat Kernel 1 adds the first complete, testable combat loop to the accepted third-person six-axis flight room without reopening the protected flight, thruster, collision, or Camera C0 behavior.

The milestone must let the player:

1. fire source-aligned rapid pulse cannons;
2. hit a stationary armored practice drone;
3. see shield and hull damage resolve predictably;
4. take shield and hull damage from physical collisions;
5. recover shields and, much more slowly, hull integrity;
6. destroy and reset the player or drone deterministically.

This is a combat foundation, not a full dogfighting milestone.

## 2. Protected Baseline

The implementation must preserve the accepted flight-room behavior:

- six-axis local-space flight;
- assisted and manual flight modes;
- boost and thermal lockout;
- canonical Small Sci-Fi Fighter at identity transform;
- twelve source-derived thruster effects and deterministic action mappings;
- four collidable asteroid families;
- navigation course and existing collision response;
- reset behavior;
- Camera C0 Standard, Far, and Close presets;
- existing flight HUD information.

Combat code must extend these systems through narrow interfaces. It must not fold weapons, damage, or shield logic into `ShipFlightController`, `ChaseCameraRig`, or the existing thruster visual controller.

## 3. Scope

### 3.1 Included

- one player primary weapon;
- two alternating source-derived cannon exits;
- one visible swept-collision pulse projectile;
- one stationary armored practice drone;
- reusable shield/hull damage state;
- full shield-to-hull overflow;
- player and drone shield regeneration;
- very slow player hull repair;
- collision damage for the player and practice drone;
- localized pooled shield-hit effects;
- player fighter-shaped shield envelope;
- drone fitted-ellipsoid shield envelope;
- shield-break and hull-hit feedback;
- fighter-forward dynamic pipper and edge indicator;
- deterministic entity and arena reset;
- automated contract, unit, scene, and integration tests;
- a source-derived cannon calibration scene.

### 3.2 Explicitly excluded

- moving enemies or enemy AI;
- enemy weapons;
- target lock, aim assistance, convergence, snapping, lead calculation, or camera-forward fire;
- Camera C1 tactical views;
- secondary or heavy plasma weapons;
- ammunition, magazines, reloads, weapon heat, or resupply;
- destructible asteroids, asteroid health, cracking, fragmentation, or loot;
- advanced shield deformation;
- exact hull-following shield simulation;
- polished destruction sequences, debris, wreckage, kill cameras, or replay cameras;
- player shield physics that changes bounce, impulse, spin, or momentum transfer;
- production combat audio and final audio mixing.

Combat components may expose events for later audio binding, but audio is not an acceptance gate for this milestone.

## 4. Player Weapon

### 4.1 Input

`fire_primary` is one logical input action bound to:

- left mouse button;
- physical `V`.

Holding either input fires continuously. Pressing both at once must still produce only one shared firing cadence.

Firing is disabled while player controls are disabled or while the player is being reset.

### 4.2 Cadence and muzzle order

The primary weapon uses:

- combined cadence: `7.0` shots per second;
- shared interval: `1.0 / 7.0` seconds;
- sequence: Left, Right, Left, Right;
- first held shot: immediate;
- release behavior: stop immediately;
- ammunition: unlimited;
- heat: none;
- reload: none.

The cadence belongs to one `PrimaryFireController`. Individual cannon nodes must not own independent timers.

### 4.3 Direction and projectile velocity

Every pulse fires in true fighter-forward direction:

```text
fighter forward = player global basis × Vector3.FORWARD
Vector3.FORWARD = (0, 0, -1)
```

The projectile does not fire toward the camera, pipper, target, or screen center.

Initial projectile world velocity is:

```text
player world velocity + fighter forward × 900 m/s
```

The projectile receives no guidance, convergence, lead correction, drag, gravity, or homing after launch.

### 4.4 Projectile contract

Each projectile has:

- damage: `15`;
- lifetime: `3.0` seconds;
- a small swept collision shape;
- compact bright pulse visual;
- short trail;
- no physical recoil on the fighter;
- no collision with the firing fighter;
- destruction on its first valid solid hit.

World geometry, pylons, asteroids, the practice drone, and other solid bodies stop the projectile. A hit on a damageable body produces a `DamagePacket`; a hit on non-damageable geometry produces only the impact effect. Asteroids do not track health in this milestone.

Swept collision is required. A projectile may not depend only on discrete frame-position overlap because its speed can cross thin geometry between physics ticks.

## 5. Canonical cannon exits and schema 5

### 5.1 Source-derived requirement

The left and right cannon exits must be extracted from the preserved Blender fighter source. Their origins and bases may not be chosen by eye in Godot and may not be represented as hand-tuned `Marker3D` offsets.

The runtime fighter must expose exactly:

```text
WeaponSockets/Primary/Left
WeaponSockets/Primary/Right
```

Each socket must have:

- a source object or source geometry reference;
- source component identity when applicable;
- canonical origin;
- canonical basis;
- canonical forward axis;
- reconstruction or extraction evidence;
- a stable manifest path.

### 5.2 Schema transition

The fighter manifest advances to schema `5`.

Schema 5 must preserve every schema-4 canonical frame, collider, source hash, thruster socket, thruster effect, geometry digest, reconstruction-error, and deterministic action-matrix requirement while adding exactly two primary-weapon muzzle records.

The schema-5 validator must reject:

- missing or extra primary muzzles;
- duplicate paths;
- duplicate left/right identities;
- non-finite origins or bases;
- bases whose axis lengths or pairwise orthogonality differ from unit/orthogonal by more than `0.0001`;
- bases with a non-positive determinant;
- muzzle-forward axes whose dot product with canonical fighter-forward is below `0.95`;
- source extraction or reconstruction error above `0.0001 m`;
- missing runtime GLB nodes;
- changes that remove or weaken schema-4 thruster guarantees.

### 5.3 Current branch reconciliation gate

The branch currently contains a documentation/tooling contract that expects schema 4, while the checked-in runtime manifest is still schema 2 and lacks the schema-4 `thruster_effects` collection.

The implementation must treat this as a blocking baseline discrepancy. It may publish schema 5 directly, but only if the schema-5 exporter and validator first preserve and revalidate every schema-4 requirement. The stale schema-2 manifest is not an acceptable base for manually appending muzzle data.

No one may claim the branch verified until the regenerated GLB, schema-5 manifest, deterministic thruster matrix, Python tests, Godot tests, project import, and main-scene boot all pass through the local verifier.

### 5.4 Calibration

A development-only cannon calibration scene must use the production fighter asset and display:

- both muzzle paths;
- each source-derived origin;
- each source-derived basis;
- a forward ray from each muzzle;
- the canonical fighter-forward ray;
- a clear failure state when a socket is missing or misoriented.

This scene is a diagnostic tool and must not be used to compensate for incorrect source extraction.

## 6. Damage architecture

### 6.1 Damage packet

All projectile and collision damage enters a reusable damage state as a typed packet containing:

- positive damage amount;
- damage kind: `PROJECTILE` or `COLLISION`;
- world impact point;
- world impact normal;
- source instance identity when available;
- timestamp or physics tick identity;
- optional collision contact key.

### 6.2 Damage result

Applying a packet returns a typed result containing:

- requested damage;
- shield damage applied;
- hull damage applied;
- remaining shield;
- remaining hull;
- whether the shield broke on this packet;
- whether the hull was hit;
- whether the entity was destroyed;
- impact location and normal;
- damage kind.

Visuals, HUD, hit confirmation, reset flow, and later audio subscribe to this result. They must not recompute damage classification independently.

### 6.3 Resolution order and overflow

Damage always resolves in this order:

1. apply as much damage as possible to shield;
2. if the packet exceeds remaining shield, carry the full remainder into hull;
3. if hull reaches zero, mark the entity destroyed exactly once.

Example:

```text
remaining shield: 20
incoming damage: 50
shield damage: 20
hull damage: 30
```

No final-hit immunity, partial overflow reduction, or hidden armor multiplier is included.

### 6.4 Durability values

Player and practice drone both use:

- maximum shield: `150`;
- maximum hull: `200`.

The practice drone is stationary and armored but does not use AI, weapons, pursuit, or evasive motion.

## 7. Shield and repair lifecycle

### 7.1 Passive shield behavior

A shield is automatically active whenever its current value is above zero. There is no manual shield toggle.

Receiving damage interrupts all shield regeneration immediately.

### 7.2 Normal regeneration

When a shield remains above zero:

- regeneration begins after `8.0` seconds without damage;
- regeneration rate is `3.0` shield points per second;
- movement, firing, turning, and boosting do not interrupt regeneration;
- new damage resets the no-damage delay.

A fully depleted 150-point shield requires 50 seconds of active regeneration after its delay.

### 7.3 Shield break and reboot

When shield reaches zero:

- emit one shield-break event;
- stop normal regeneration;
- begin a `20.0` second reboot delay;
- after the reboot completes, regenerate gradually at `3.0` points per second;
- any new damage during reboot restarts the reboot delay;
- once charge rises above zero, the shield becomes active again.

The practice drone uses the same regeneration and reboot rules as the player.

### 7.4 Player hull repair

Player hull does not repair while shield is missing or recharging.

After shield reaches full:

- wait an additional `10.0` seconds without damage;
- repair hull at `1.0` point per second;
- any damage stops hull repair immediately;
- hull repair cannot revive a destroyed player.

The practice drone restores through its destruction/reset lifecycle rather than passive hull repair.

## 8. Collision damage

### 8.1 Physical response

Shield charge never changes collision physics.

The existing fighter body continues to receive normal:

- impulse;
- bounce;
- spin;
- velocity change;
- momentum transfer.

The shield changes only damage routing. With shield charge, collision damage reaches shield first. With no shield charge, the same collision damage reaches hull.

### 8.2 Impact qualification

Collision damage uses relative normal impact speed and effective impact mass.

A contact causes no damage when relative normal impact speed is below `10.0 m/s`. Tangential scraping alone does not count as impact speed.

The initial tuning model is:

```text
excess_speed = max(relative_normal_speed - 10.0, 0.0)
mass_factor = clamp(effective_mass / 8500.0, 0.0, 1.0)
raw_damage = 100.0 × mass_factor × (excess_speed / 20.0)^2
collision_damage = clamp(raw_damage, 1.0, 100.0)
```

`effective_mass` is:

- reduced mass for two finite dynamic bodies;
- the finite dynamic body's mass when the other body is static;
- clamped to a maximum reference mass of `8500 kg`.

Dynamic objects below `25 kg` are ignored for collision damage unless explicitly tagged as damaging. This prevents tiny debris from becoming an exploitative damage source.

The formula is a tuning seam. Constants live in a resource or focused configuration object, not scattered across scripts.

### 8.3 Distinct impacts and rearming

A contact deals one damage event when impact begins.

It may deal damage again only when:

- the bodies fully separate and collide again; or
- while still touching, relative normal impact speed increases by at least `10.0 m/s` above the strongest already-processed impact for that contact.

Resting, sliding, scraping, or being wedged against an object must not repeatedly drain shield or hull.

Contact state must be cleared on separation, entity destruction, and global reset.

### 8.4 Symmetric ramming damage

When the player physically impacts the practice drone, the qualified collision event damages both entities using the same resolved collision amount.

The drone may remain spatially stationary for this milestone. It still receives damage state changes and visual feedback.

### 8.5 Collision shield-hit placement

Projectile shield effects use the projectile's actual impact point.

Collision shield effects are intentionally quantized to a stable directional region rather than attempting exact contact projection onto the visual envelope. The supported regions are:

- front;
- rear;
- left;
- right.

The dominant local-space contact direction selects the region. This keeps collision feedback readable and deterministic while the provisional player shield envelope is being evaluated.

## 9. Shield visuals

### 9.1 Separation from physics

Shield visuals are not colliders and do not participate in collision response. Damage continues to come from projectile sweeps and the existing body contacts.

### 9.2 Player envelope

The player uses a smooth fighter-shaped visual envelope that loosely follows the fuselage and wing silhouette.

This shape is provisional for Combat Kernel 1:

- it must read as fighter-shaped rather than spherical;
- it must remain smooth and convex enough for stable localized effects;
- it must not exactly hug every hull feature;
- it may be tuned after visual inspection without changing damage behavior.

### 9.3 Drone envelope

The practice drone uses a fitted ellipsoid, wider than it is tall, sized around the drone silhouette.

### 9.4 Localized patch system

Normal shield hits use a reusable pool of localized curved hex patches.

Requirements:

- idle shield is invisible;
- a normal hit reveals only a faint local translucent patch;
- nearby hex cells ripple outward;
- patch lifetime is `0.25` seconds;
- each shield owns a pool of `8` patches;
- overlapping hits are allowed;
- a ninth simultaneous hit recycles the oldest active patch;
- exhausted patches return to the pool deterministically;
- normal hits never reveal a permanently glowing full bubble;
- material instances or per-instance parameters must keep overlapping patches independent under GL Compatibility.

A separate hidden full-envelope effect is reserved for shield break.

### 9.5 Depletion instability

Visual intensity changes with shield percentage:

- above 25%: dim, clean, controlled ripple;
- at or below 25%: sharper, brighter, more fragmented ripple with brief instability;
- at zero: one stronger full-envelope flash and dissipation.

The low-shield visual state communicates risk but does not alter damage, recharge, or physics.

### 9.6 Hull impacts

Hull damage produces:

- a short orange-white flash;
- a small spark burst;
- no persistent scorch decal in this milestone.

Asteroid weapon impacts use a small world-impact flash or spark only. They do not create damage state.

## 10. Pipper and hit feedback

### 10.1 Pipper meaning

The pipper represents true fighter-forward direction projected through the active camera.

It is not:

- a target selector;
- a lead indicator;
- a projectile travel predictor;
- a convergence point;
- an aim-assist control.

The pipper may be away from screen center because the camera and fighter orientation are independent.

### 10.2 Off-screen behavior

When fighter-forward projects outside the viewport or behind the camera:

- hide the central pipper;
- show a small directional chevron clamped to the screen edge;
- orient the chevron toward the projected direction.

### 10.3 Color and hit confirmation

The pipper is neutral white.

When a projectile successfully applies damage to a damage state, the pipper may flash briefly. Passing over a target must not change its color, size, or behavior.

Hits on non-damageable world geometry or asteroids do not count as damage confirmation.

## 11. Practice drone

The practice drone is:

- stationary;
- collidable;
- damageable;
- shielded;
- resettable;
- visually distinct from the player fighter;
- free of navigation, AI, weapons, target lock, or flight behavior.

When its hull reaches zero:

1. mark it destroyed;
2. disable its damage intake and collision participation;
3. show a simple destruction flash;
4. wait `3.0` seconds;
5. restore it at its spawn transform with full shield and full hull.

Destroying the drone does not restore player shield or hull.

## 12. Player destruction and reset

When player hull reaches zero:

1. mark the player destroyed exactly once;
2. stop flight and primary-fire control;
3. show a minimal destruction indication;
4. wait `1.0` second;
5. perform the existing safe reset flow;
6. restore full shield and hull;
7. clear projectiles, active impact patches, contact state, timers, and hit feedback;
8. restore control.

A polished destruction animation is intentionally deferred. The temporary destruction indication exists only to make state transition readable.

The existing manual reset action becomes an arena reset. It restores:

- player transform, momentum, flight runtime state, shield, and hull;
- drone transform, shield, hull, and enabled state;
- projectile pool or active projectiles;
- shield impact pools and full-envelope break effects;
- collision contact tracking;
- HUD transient states.

## 13. Component boundaries

The design uses focused components with these responsibilities:

### `PrimaryFireController`

Consumes the logical fire action, player body transform/velocity, and two verified muzzle nodes. Owns the shared cadence and alternating muzzle order. Spawns projectiles and emits firing events.

### `PulseProjectile`

Owns lifetime, world velocity, swept collision, first-hit resolution, self-ignore identity, and impact event emission. It does not own HUD or target health.

### `DamageState`

Owns shield, hull, overflow, regeneration, reboot, player hull repair policy, destruction state, reset, and typed results.

### `CollisionDamageModel`

Pure calculation of qualified impact damage from speed and effective mass.

### `CollisionContactTracker`

Owns contact keys, first-impact detection, separation, renewed-impact thresholds, symmetric ramming dispatch, and reset cleanup.

### `ShieldVisualController`

Consumes typed damage results and shield percentage. Owns patch pooling, directional collision placement, low-shield instability, and break-shell effects. It never applies damage.

### `CombatPipper`

Consumes fighter transform and active camera projection. Owns screen position, edge chevron, and short damage-confirmation flash. It never affects firing direction.

### `PracticeDroneController`

Owns drone spawn state, destruction lockout, simple restoration delay, and reset behavior. Damage math remains in `DamageState`.

### `FlightRoomController`

Remains the arena-level coordinator. It wires player, drone, HUD, and reset lifecycle but does not implement weapon cadence or damage formulas.

### Protected existing components

`ShipFlightController` continues to own only flight behavior.  
`ShipThrusterVisualController` continues to own only thruster visuals.  
The chase camera continues to own only camera behavior.  
The HUD displays combat state but does not compute it.

## 14. Data flow

### Projectile hit

```text
fire input
→ PrimaryFireController cadence
→ verified left/right muzzle
→ PulseProjectile
→ swept collision
→ DamagePacket
→ DamageState.apply_damage
→ DamageResult
→ ShieldVisualController / hull effect / HUD / pipper confirmation
```

### Collision hit

```text
existing rigid-body contact
→ CollisionContactTracker
→ CollisionDamageModel
→ one qualified collision event
→ DamagePacket for player
→ optional symmetric DamagePacket for practice drone
→ DamageState.apply_damage
→ DamageResult
→ shield or hull feedback
```

### Reset

```text
manual reset, boundary reset, or player destruction timeout
→ FlightRoomController arena reset
→ player flight reset
→ player and drone damage reset
→ projectile cleanup
→ contact cleanup
→ effect cleanup
→ HUD transient cleanup
```

## 15. Error handling and fail-closed behavior

The combat system must fail closed when required references are missing:

- missing muzzle nodes disable primary firing and report a clear error;
- missing damage state prevents damage dispatch but does not crash the scene;
- missing shield visual nodes disable only visual feedback;
- malformed schema-5 manifest fails validation before publication;
- failed pending asset validation leaves current live assets untouched;
- projectile collision with an unknown body still produces world-impact cleanup;
- reset clears partial runtime state even after a component was disabled.

No component may silently substitute guessed muzzle positions.

## 16. Testing and verification

### 16.1 Pure/unit tests

Tests must cover:

- shared `7 shots/s` cadence;
- immediate first shot;
- no double cadence from simultaneous LMB and `V`;
- exact Left/Right alternation;
- release stops firing;
- projectile velocity inheritance;
- projectile lifetime;
- first-hit destruction;
- self-ignore behavior;
- shield-first damage;
- full overflow into hull;
- shield-break event emitted once;
- normal recharge delay and rate;
- 20-second reboot behavior;
- new damage resetting recharge or reboot;
- player hull repair gate, delay, and rate;
- collision threshold at `10 m/s`;
- mass scaling;
- `100` damage clamp;
- tiny-object filter;
- one event per sustained contact;
- separation rearming;
- `10 m/s` renewed-impact rearming;
- symmetric player/drone ramming;
- directional collision region selection;
- pipper projection and edge-chevron math;
- deterministic reset of all combat state.

### 16.2 Asset-contract tests

Python tests must prove:

- schema version is exactly 5;
- all schema-4 canonical and thruster guarantees remain enforced;
- exactly two primary muzzle records exist;
- paths and left/right identities are exact;
- GLB nodes match manifest paths;
- origins and bases are finite and source-derived;
- orientation is compatible with canonical fighter-forward;
- publication remains transactional;
- schema-2 or partially upgraded manifests are rejected.

### 16.3 Scene and integration tests

Godot tests must prove:

- high-speed projectiles cannot tunnel through a thin collider;
- projectiles disappear on first world or target hit;
- drone shield and hull values update through actual projectile hits;
- collision damage reaches player shield before hull;
- shield depletion allows later collision damage to reach hull;
- collision damage does not suppress or alter rigid-body response;
- scraping does not repeat damage;
- separating and re-impacting does;
- renewed high-speed impact while touching can rearm;
- ramming damages both player and drone;
- shield patch pool supports overlapping hits and returns patches;
- shield break uses the full-envelope effect once;
- player destruction disables control before reset;
- drone restores after three seconds;
- manual reset restores the full arena;
- existing flight, boost, thruster, asteroid, camera, and HUD suites remain green.

### 16.4 Local verification

The Windows verification entry point remains:

```powershell
.\tools\verify\verify.ps1
```

The verifier must be updated for schema 5 and the expanded test runner. It must still:

1. validate required generated files;
2. validate the fighter manifest and runtime GLB;
3. validate the deterministic thruster matrix;
4. import the Godot project;
5. run every test suite;
6. boot the main scene briefly.

No automated GitHub Actions workflow is added. Verification claims require user-pasted local output.

## 17. Acceptance criteria

Combat Kernel 1 is accepted only when all of the following are true:

- LMB and physical `V` fire one shared alternating cannon cadence;
- both cannon exits are source-derived and validator-proven;
- projectiles travel at inherited ship velocity plus 900 m/s fighter-forward;
- no camera-forward aiming, convergence, lead, lock, or assist exists;
- the stationary drone can be shielded, damaged, destroyed, and restored;
- player and drone both use 150 shield and 200 hull;
- overflow reaches hull exactly;
- shield regeneration, reboot, and slow player hull repair match this spec;
- projectiles and physical collisions share the damage result pipeline;
- shield does not alter physical collision response;
- sustained contact cannot drain damage every frame;
- ramming damages both player and drone;
- player and drone shield visuals match their approved envelopes;
- localized hex patches overlap and clean up deterministically;
- low shield becomes visually unstable and shield break flashes once;
- asteroid hits create effects without asteroid health;
- pipper remains a pure fighter-forward indicator;
- player destruction performs a temporary disable-and-reset flow;
- manual reset clears the full arena;
- existing flight-room behavior has no regressions;
- schema-5 validation and all local verification stages pass.

## 18. Deferred follow-up

The following remain outside this milestone:

- Camera C1;
- moving enemy fighter and dogfighting AI;
- enemy weapons;
- heavy plasma;
- weapon heat and ammunition;
- target lead or aim assistance;
- destructible asteroids;
- advanced shield deformation;
- persistent hull scorch decals;
- polished combat audio;
- full destruction animation, debris, wreckage, and cinematic cameras.
