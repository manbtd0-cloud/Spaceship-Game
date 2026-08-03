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

## Enemies and Combat

- `DEFERRED` Moving enemy fighter with pursuit, attack, retreat, and dogfighting behavior.
- `DEFERRED` Full enemy dogfighting AI after Camera C1 tactical views are available.

## Status History

- 2026-08-03: Ledger created during Combat Kernel 1 design.
