# Combat Presentation v1 Implementation Plan

> **For agentic workers:** Execute inline with `superpowers:executing-plans`; this project explicitly does not use subagents. Follow `superpowers:test-driven-development` for behavior changes, `superpowers:systematic-debugging` for the vibration defect, and `superpowers:verification-before-completion` before completion claims.

**Goal:** Add cinematic tactical combat presentation to the verified one-on-one dogfight while preserving simulation rules, and eliminate the reported intermittent visible ship/model vibration at its diagnosed root cause.

**Architecture:** Presentation-only adapters consume existing controller outputs and combat events. Simulation remains owned by the existing flight/combat/AI systems. Every visual/audio/camera effect is bounded and must cleanly survive reset/respawn.

**Tech Stack:** Godot 4.7.1, typed GDScript, GL Compatibility current project renderer, existing schema-5 fighter asset/thruster matrix, dependency-free `TestCase` harness, local PowerShell/Bash verification.

## Global constraints

- Authoritative integration target: `agent/playable-flight-room`.
- Starting verified runner target: 50 suites.
- No control, dogfight-tuning, projectile hit-probability, or weapon-balance changes in this milestone.
- Active ship motion remains physical; no live transform/velocity cheating.
- Presentation may read simulation state but never define it.
- No GitHub Actions.
- GitHub is persistent state; sandbox is disposable.
- Record the later controls/dogfight-feel/bullet-connectivity pass in `docs/superpowers/plans/deferred-milestones.md`.

---

## Task 1 — Diagnose and fix intermittent render/physics vibration

**Likely files:**
- `src/camera/chase_camera_rig.gd`
- `project.godot`
- player/enemy reset owners only if interpolation reset is required
- new focused diagnostic/regression test
- `tests/test_runner.gd`

1. Inspect current player scene, camera scene/rig, rigid-body process callbacks, interpolation project setting, and every live writer of player/model/camera transforms.
2. Build a deterministic diagnostic fixture that separates physics-body movement from visual/camera sampling. Prefer a low physics tick rate in the fixture so stair-step sampling is measurable.
3. RED: prove current render-frame follow samples discrete rigid-body transforms rather than an interpolated target when the regression is present. The failure must be about target sampling/smoothness, not subjective graphics.
4. Trace reset/teleport paths and confirm whether stale interpolation history can produce one-frame glitches.
5. State one root-cause hypothesis and test it minimally.
6. GREEN only after evidence: apply the smallest root-cause repair. If the transform-sampling hypothesis is confirmed, enable Godot physics interpolation, have render-frame camera calculations use `get_global_transform_interpolated()`, and call interpolation reset only at explicit teleport/reset boundaries where required.
7. Verify camera modes, temporary views, player reset, enemy reset, AI Assisted, Smart Stabilize, and inertial preservation remain unchanged.
8. Commit one meaningful Task 1 boundary locally.

Expected runner target after a new suite: 51 suites.

---

## Task 2 — Physically faithful enemy thruster presentation

**Likely files:**
- new pure `enemy_thruster_presentation_math.gd`
- new/updated enemy thruster presentation controller
- `scenes/combat/enemy_fighter.tscn`
- focused unit + integration tests

1. RED pure tests that map normalized real local force/torque into legal schema-5 action intensities.
2. Require finite outputs in `[0,1]`, no permanently-on effects, and no output beyond actual bounded authority.
3. Reuse the checked-in schema-5 action matrix/nozzle geometry rather than inventing decorative sockets.
4. GREEN implement the pure mapping.
5. RED integration test: enemy presentation consumes `EnemyFighterController.get_last_force_world()` / `get_last_torque_world()` and only relevant imported effect nodes illuminate.
6. GREEN implement smooth rise/fall, restrained emission/heat variation, and authoritative reset/destruction clearing.
7. Verify raw GLB/source files are untouched.

Expected runner target: 53 suites.

---

## Task 3 — Strong but disciplined shield/hull hit presentation

**Likely files:**
- extend `ShieldImpactVisualizer`/shader only through presentation parameters
- new hull impact presentation controller/scene
- tests for shield-vs-hull routing and cleanup

1. RED tests: shield damage activates localized hex feedback but not hull sparks; hull damage activates hull presentation; disabled/no-op damage creates no false presentation.
2. Strengthen localized hex identity, directional center energy, and shield-break pulse without a permanent bubble.
3. Add bounded directional hull spark/hot-fragment presentation and brief emissive impact flash.
4. Ensure multiple impacts remain bounded and self-clean.
5. Preserve exact damage amounts and `DamageState` logic unchanged.

Expected runner target: 55 suites.

---

## Task 4 — Staged hostile destruction presentation

**Likely files:**
- new deterministic destruction presentation state/timeline
- new enemy destruction presentation controller/scene pieces
- lightweight reusable debris presentation
- integration test

1. RED pure timeline test for buildup → core blast → shockwave/debris → tail/cleanup.
2. GREEN implement deterministic presentation-state math independent of rendering.
3. RED scene test proving lethal enemy damage starts presentation, disables ordinary presentation/fire through the existing lifecycle, and temporary nodes clean before/at respawn.
4. GREEN implement internal flashes/sparks, core blast, plasma/shockwave, and a small bounded debris set inheriting believable spawn transform/velocity presentation data.
5. Do not change the existing 3-second respawn authority.
6. Verify reset during destruction cleans presentation immediately.

Expected runner target: 57 suites.

---

## Task 5 — Heavy cinematic military sci-fi combat audio

**Likely files:**
- `default_bus_layout.tres` or project audio-bus configuration
- reusable combat audio controller/event definitions
- deterministic/generated bundled WAV assets where suitable
- audio tests

1. RED test required buses/events and bounded emitter behavior.
2. Establish/retain buses at minimum for Ship, Weapons, Impacts, and Environment under Master, consistent with project architecture.
3. Add spatialized events for player/enemy pulse fire, shield hit/break, hull hit, enemy thruster, explosion transient/tail, and debris/spark tail.
4. Prefer repository-contained/generated assets so a fresh sandbox is self-contained; document provenance for any external asset.
5. Prevent unbounded emitter accumulation; reset/respawn clears loops/transients appropriately.
6. Keep audio presentation separate from damage/fire authority.

Expected runner target: 59 suites.

---

## Task 6 — Selective cinematic camera impulses

**Likely files:**
- new pure camera-impulse state/math
- `chase_camera_rig.gd` presentation integration
- player damage/collision/destruction event wiring
- tests

1. RED pure tests: no ordinary enemy-hit shake, tiny player light-hit impulse, stronger shield-break/collision impulse, distance-attenuated nearby explosion impulse, finite bounded decay.
2. GREEN implement deterministic impulse state.
3. Integrate as a final camera presentation offset only; never mutate player/enemy physics or camera target simulation state.
4. Verify temporary rear/side views and camera behavior/distance modes remain correct.
5. Verify the new impulse code cannot reintroduce the vibration regression.

Expected runner target: 61 suites.

---

## Task 7 — Production integration, persistence tooling, deferred roadmap, closure

**Files:**
- production scene wiring as needed
- `README.md`
- `docs/superpowers/plans/deferred-milestones.md`
- a small persistent bootstrap/restore note or script if reconstruction steps are not already explicit
- final integration test(s) only where they add new behavior coverage

1. Record a separate deferred **Combat Feel / Controls / Projectile Connectivity** milestone covering the user's report that current dogfighting is not fun and bullets are not connecting reliably. Do not fix it in this milestone.
2. Document the disposable-sandbox recovery rule: restore Godot binary, reconstruct/checkout current GitHub branch, run verifier, continue from GitHub head.
3. Run targeted presentation suites, then entire test runner. Expected minimum: 61 suites if each planned suite remains separate.
4. Run the full repository verifier: schema-5 contract, deterministic thruster matrix, all GDScript suites, inertial rigid-body preservation.
5. Run actual main-scene runtime smoke for several physics seconds; fail on parser, node-path, shader, retained-resource, or repeated runtime errors.
6. Inspect `git diff --check`, status, changed-file scope, and recent log.
7. Use `verification-before-completion` before any success claim.
8. Merge verified feature branch into `agent/playable-flight-room`, rerun the authoritative verification on the merged tree, then publish the authoritative branch once.
9. Verify remote compare shows only intended presentation/stability/docs changes. Do not trigger GitHub Actions.

## Manual acceptance after technical gate

Ahmad's manual pass should judge:
- enemy plume correctness/readability;
- shield/hull hit readability;
- destruction quality;
- audio weight/balance;
- selective camera feedback;
- absence of the reported random visible model vibration.

Subjective dogfight fun, controls, and bullet-connectivity are explicitly deferred to the next gameplay-feel milestone.
