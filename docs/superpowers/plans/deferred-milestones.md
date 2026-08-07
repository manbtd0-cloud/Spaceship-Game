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
- Tactical Enemy Dogfight: one physical hostile fighter, predictive lead aiming, fair pulse-cannon return fire, range/closure management, disengage/re-entry, threat-aware evasive breaks, and short-delay respawn;
- Combat Presentation v1: physically faithful enemy thruster VFX driven from real bounded force/torque, stronger localized shield/hull impacts, staged hostile destruction, deterministic spatialized combat audio, selective player-camera feedback, and the render/physics interpolation repair for visible chase-camera/model jitter.

The current Combat Presentation v1 technical gate is **61 suites**, schema-5 fighter validation, deterministic thruster-matrix validation, exact inertial velocity preservation, and main-scene runtime smoke.

---

## Deferred: Combat feel, controls, and projectile connectivity

The current one-on-one dogfight is technically functional but has **not** passed a subjective combat-feel gate. Ahmad reports that the fight is not fun enough yet and pulse rounds do not connect reliably enough during normal dogfighting.

This must be its own gameplay milestone. Later work should cover:

- control scheme / mouse-flight redesign as needed;
- aiming and reticle usability;
- projectile readability and practical hit/connectivity rate;
- target-relative closure/range readability;
- weapon cadence, projectile speed, or aim assistance only if evidence shows they are required;
- enemy/player maneuver tuning needed for fun engagement geometry;
- repeatable manual playtest scenarios and subjective acceptance criteria.

Do not solve this by silently turning the current pulse cannon into homing fire, hitscan substitution, hidden aim snapping, or authority beyond configured physical limits. Any assistance or control-model change must receive its own explicit design and verification gate.

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

## Deferred: Enemy art and later combat presentation

Combat Presentation v1 implements the first real presentation layer, but the current enemy still deliberately reuses the canonical fighter runtime model with a hostile treatment.

Later work may include:

- a dedicated enemy fighter model;
- richer localized shield deformation beyond the current impact layer;
- more elaborate or model-specific breakup once dedicated enemy art justifies it;
- assistant / voice callouts;
- expanded authored combat-audio library and mixing polish beyond the deterministic v1 source synthesis;
- radar or minimap;
- target-lock UI;
- asteroid destruction;
- environment reaction to combat.

The previously deferred **dynamic enemy thruster VFX**, core combat audio, stronger normal impacts, and staged hostile destruction are now implemented by Combat Presentation v1 and must not be listed as unfinished work.

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

GitHub is the persistent project state. Sandboxes, caches, extracted binaries, and local worktrees are disposable; see `docs/development/disposable-environment-recovery.md` for the recovery workflow.
