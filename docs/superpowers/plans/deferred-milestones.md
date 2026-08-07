# Deferred Milestones and Later Additions

This file is the authoritative wait list for approved additions that must not interrupt the active implementation milestone.

## Verified foundation

The following are implemented and are **not deferred work anymore**:

- Assisted flight;
- true Inertial flight with zero-drift preservation under pure rotation;
- full-authority AI Assisted flight through bounded physical force/torque;
- universal hold-to-use Smart Stabilize on `X`;
- agile fighter authority and angular-rate envelopes;
- chase-camera behavior/distance modes and temporary rear/right/left views;
- persistent pause/settings workflow;
- exact schema-5 player thruster mapping and source-exact plume geometry;
- exact canonical primary-fire muzzle sockets, pooled 900 m/s pulse projectiles, and 15-damage projectile packets;
- Combat Sandbox v1 shield/hull/collision damage, localized hex shield impacts, player recovery, target lifecycle, and combat HUD;
- Tactical Enemy Dogfight: one physical hostile fighter, predictive lead aiming, fair pulse-cannon return fire, range/closure management, disengage/re-entry, threat-aware evasive breaks, and short-delay respawn.

The Tactical Enemy Dogfight technical gate is **50 suites**, schema-5 validation, deterministic thruster-matrix validation, inertial preservation, and main-scene runtime smoke.

---

## Deferred: Multi-enemy and fleet combat

Do not expand the one-on-one tactical fighter milestone into fleet AI yet.

Later work may include:

- two or more simultaneous hostile fighters;
- formations, wingmen, escorts, bombers, and capital-ship behavior;
- target prioritization and threat selection;
- reinforcement entry logic;
- encounter pacing / difficulty director;
- reusable NPC-pilot framework when multiple ship roles justify the abstraction.

---

## Deferred: Weapon expansion

The current combat baseline remains pulse cannon only.

Later work may include:

- heavy plasma;
- missiles / torpedoes;
- beams;
- weapon selection;
- target lock / lock-on behavior;
- weapon-specific HUD presentation.

Do not weaken the existing physical projectile, source-exclusion, damage, or firing-solution contracts when these are added.

---

## Deferred: Enemy art and combat presentation

The current enemy deliberately reuses the canonical fighter runtime model with a hostile visual treatment.

Later work may include:

- a dedicated enemy fighter model;
- richer destruction / explosion VFX;
- richer localized shield deformation and impact presentation;
- combat audio and weapon audio;
- assistant / voice callouts;
- radar or minimap;
- target-lock UI;
- asteroid destruction;
- environment reaction to combat.

### Dynamic enemy thruster VFX

The reused enemy model currently suppresses the authored `EngineFire*` group instead of displaying every plume simultaneously. A later dedicated pass must drive enemy thruster visuals from the **actual bounded force/torque requested by `EnemyFighterController`**, using verified nozzle geometry/mapping rather than arbitrary glow placement.

Requirements for that later pass:

- no permanently-on all-thruster look;
- only physically relevant nozzles illuminate for the current maneuver;
- visual output cannot imply more authority than the controller actually applies;
- preserve the canonical source-exact nozzle geometry contract;
- do not modify raw Blender/GLB source merely to fake enemy motion.

---

## Deferred: Dogfight tuning and difficulty

The first tactical enemy is independently tunable but intentionally has no formal difficulty system yet.

Later work may include:

- trainee / standard / ace tuning profiles;
- controlled aiming error or reaction-delay profiles;
- tactical aggression profiles;
- encounter-specific spawn geometry;
- difficulty-scaled shield/hull/cadence only through explicit tuning resources.

Never implement difficulty by teleportation, hitscan substitution, projectile homing, hidden velocity writes, or authority beyond configured physical limits.

---

## Rule for future additions

Whenever an implementation discussion says an addition will be done "later," add it here before moving on unless it is already represented above. Deferred work must receive its own design/specification and verification gate before implementation.
