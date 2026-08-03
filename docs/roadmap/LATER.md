# Deferred Work Ledger

This file is the canonical list of features explicitly postponed during design or implementation.

## Rules

- Whenever a feature is described as “later”, “deferred”, “after this phase”, or equivalent, add it here in the same change set or design pass.
- Record only decisions that were actually discussed and deferred.
- Do not remove an item until it is implemented, rejected, or superseded by an approved design.
- When an item moves into active work, link its design/spec and mark it `ACTIVE` before implementation.

## Camera

- `DEFERRED` Camera C1 tactical views: hold `B` for rear view, hold `PgUp` for left view, and hold `PgDn` for right view, with smooth return to the selected Close/Standard/Far chase preset.
- `DEFERRED` Combat target framing for the chase camera.
- `DEFERRED` Camera collision avoidance.
- `DEFERRED` Cinematic kill, destruction, and replay cameras.

## Weapons

- `DEFERRED` Primary-cannon heat buildup, overheat lockout, recovery, and heat HUD.
- `DEFERRED` Finite ammunition, magazines, reload behavior, ammunition HUD, and resupply.
- `DEFERRED` Slow heavy plasma bolts after the rapid pulse-cannon combat loop is complete.
- `DEFERRED` Target lead indicator for moving enemies.
- `DEFERRED` Optional mild aim assistance; fixed ship-forward fire remains the approved initial behavior.

## Shields and Damage Visuals

- `ACTIVE` Initial player and practice-drone shield impact visuals are governed by [`docs/superpowers/specs/2026-08-03-combat-kernel-1-design.md`](../superpowers/specs/2026-08-03-combat-kernel-1-design.md).
- `DEFERRED` Advanced shield deformation beyond the initial localized hexagonal impact ripple.
- `DEFERRED` Persistent hull scorch decals.
- `DEFERRED` Polished destruction animation, debris, wreckage, and cinematic destruction presentation.

## Enemies and Combat

- `DEFERRED` Moving enemy fighter with pursuit, attack, retreat, and dogfighting behavior.
- `DEFERRED` Full enemy dogfighting AI after Camera C1 tactical views are available.
- `DEFERRED` Enemy weapons.
- `DEFERRED` Production combat audio and final audio mixing.

## Environment

- `DEFERRED` Refine asteroid clustering and resolve any visually awkward overlap after the combat loop is playable.
- `DEFERRED` Asteroid health, cracking, fragmentation, and destruction.

## Tooling and Asset Polish

- `DEFERRED` Investigate and clean up the non-blocking Blender tangent warning without reopening the accepted canonical fighter/thruster contract.

## Status History

- 2026-08-03: Ledger created during Combat Kernel 1 design.
- 2026-08-03: Added deferred player shield visuals, advanced shield deformation, asteroid clustering refinement, and Blender tangent-warning cleanup.
- 2026-08-03: Combat Kernel 1 design superseded the player-shield deferral; marked initial player/drone shield visuals active and recorded the remaining destruction, audio, and asteroid-destruction deferrals.
