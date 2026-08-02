# Four-Source Collidable Asteroid Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert all four supplied asteroid sources into validated canonical GLBs with reduced convex collision proxies, then replace flight-room box placeholders with a deterministic fully collidable asteroid field.

**Architecture:** A source contract binds exact paths and hashes. A Blender exporter cleans and normalizes one family per invocation, creates a reduced `CollisionProxy-convcolonly` mesh, and emits a manifest. A PowerShell wrapper exports all four and validates them before any scene references are introduced.

**Tech Stack:** Blender 5.2 LTS, Python standard library, Godot 4.7.1, typed GDScript, PowerShell.

## Global Constraints

- All four supplied sources are mandatory.
- Source files remain unchanged.
- Every placed asteroid is collidable.
- Collision uses reduced convex proxies, not render geometry.
- At least twelve runtime asteroid instances.
- Every family appears at least twice.
- No box placeholder remains.
- No scene may reference a missing GLB.
- No GitHub Actions.

---

### Task 1: Source intake contract

**Files:**
- Create: `tools/assets/asteroid_pack_contract.py`
- Create: `tests/tools/test_asteroid_pack.py`

**Interfaces:**
- Produces exact family specifications for `bennu`, `eros`, `legacy_a`, and `legacy_b` including path, SHA-256, canonical diameter, and output paths.

- [ ] Add fixture tests for missing source, wrong hash, missing output, invalid manifest, missing proxy statistics, and complete pack success.
- [ ] Implement source/output validation using only the Python standard library.
- [ ] Commit.

### Task 2: Blender canonical exporter

**Files:**
- Create: `tools/assets/export_asteroid_family.py`

**Interfaces:**
- Consumes `--source-id`, `--input`, `--output`, and `--manifest`.
- Produces one canonical GLB and manifest.

- [ ] Add AST/static safety assertions to `tests/tools/test_asteroid_pack.py` before implementation.
- [ ] For `.blend`, use the already-open source scene; for `.glb`, clear the factory scene and import glTF.
- [ ] Retain renderable non-flat meshes; remove cameras, lights, helpers, and flat backdrop/plane geometry.
- [ ] Duplicate data/materials before modifying.
- [ ] Join retained visual geometry, center at aggregate bounds center, uniformly scale longest dimension to `100 m`, and apply identity transforms.
- [ ] Duplicate the visual mesh, decimate toward at most `384` faces, create a convex hull, and name it `CollisionProxy-convcolonly`.
- [ ] Name the visual mesh `VisualModel` and root `Asteroid_<Family>`.
- [ ] Export selected hierarchy with materials and no animation, camera, or light data.
- [ ] Write manifest fields for source hash, dimensions, visual/proxy vertex and face counts, material count, texture presence, removed objects, provenance, and canonical frame.
- [ ] Never call a Blender save operation.
- [ ] Commit.

### Task 3: Four-family PowerShell wrapper

**Files:**
- Create: `tools/assets/export-asteroid-pack.ps1`

**Interfaces:**
- Resolves Blender and Python, validates exact source hashes, invokes Blender four times, verifies source hashes afterward, then validates the complete pack.

- [ ] Delete stale runtime outputs before each family export.
- [ ] Use `--python-exit-code 1` for every Blender invocation.
- [ ] Open `.blend` inputs directly and use `--factory-startup` for Eros glTF import.
- [ ] Stop immediately on one failed family.
- [ ] Print all generated outputs and family statistics.
- [ ] Commit.

### Task 4: Runtime asteroid body

**Files:**
- Create: `src/environment/asteroid_body.gd`
- Create: `scenes/environment/asteroid_body.tscn`
- Create: `tests/integration/test_asteroid_body_scene.gd`

**Interfaces:**
- `AsteroidBody.configure(model: PackedScene, family: StringName, angular_velocity: Vector3) -> void`.

- [ ] Write failing tests requiring `AnimatableBody3D`, visual model root, collision child, family metadata, and deterministic rotation state.
- [ ] Implement slow local rotation in `_physics_process` without translation.
- [ ] Require the imported GLB collision generated from `CollisionProxy-convcolonly`.
- [ ] Fail closed if visual or collision nodes are missing.
- [ ] Commit.

### Task 5: Deterministic asteroid field

**Files:**
- Create: `src/environment/asteroid_field.gd`
- Create: `config/environment/asteroid_field_layout.gd`
- Modify: `scenes/flight_room/flight_room.tscn`
- Modify: `tests/integration/test_flight_room_scene.gd`

**Interfaces:**
- Layout records contain family, position, rotation degrees, scale, and angular velocity.

- [ ] Write failing tests for twelve instances, all four families at least twice, all children collidable, and no `DistantReferenceShapes` node.
- [ ] Define at least twelve deterministic placements across near, middle, and far tiers.
- [ ] Keep spawn and navigation-ring centers unobstructed.
- [ ] Replace all box references with `Course/AsteroidField`.
- [ ] Commit.

### Task 6: Runner and documentation

**Files:**
- Modify: `tests/test_runner.gd`
- Modify: `README.md`
- Create: `assets/licenses/asteroids/PROVENANCE.md`

- [ ] Add asteroid body/field suites and update exact suite count.
- [ ] Record Eros CC BY 4.0 attribution from embedded glTF metadata.
- [ ] Mark the three Blender sources development-only pending provenance.
- [ ] Document source-pack extraction, export, validation, and local verification.
- [ ] Commit.

### Task 7: Local generated-asset gate

- [ ] Extract `asteroid_source_pack.zip` into repository root.
- [ ] Run `python -m unittest tests.tools.test_asteroid_pack -v`.
- [ ] Run `.\tools\assets\export-asteroid-pack.ps1`.
- [ ] Commit the four source files, four runtime GLBs, four manifests, and provenance file.
- [ ] Run `.\tools\verify\verify.ps1`.
- [ ] Launch the flight room and verify variety, collision, readable course flow, and performance.
