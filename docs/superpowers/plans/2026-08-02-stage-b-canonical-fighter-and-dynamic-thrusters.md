# Stage B Canonical Fighter and Dynamic Thrusters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a correctly oriented and scaled canonical Small Sci-Fi Fighter GLB with twelve measured thruster sockets, then drive Godot-owned exhaust effects from the controller's final local force and torque.

**Architecture:** Blender converts all retained geometry from source world space into the approved `Cube` local frame, removes every baked `EngineFire*` mesh, extracts twelve sockets from the evaluated plume components, centers and uniformly scales the hull, and exports an identity-root GLB plus a validated manifest. Godot exposes the final applied local wrench, resolves that wrench against imported socket position/direction data using deterministic projected coordinate descent, and instantiates one effect scene per socket. Temporary runtime alignment, fixed glow anchors, and keyboard-derived exhaust are deleted.

**Tech Stack:** Blender 5.2 Python API, Python 3 standard library tests, PowerShell, Godot 4.7.1 typed GDScript, GL Compatibility renderer.

## Global Constraints

- Branch: `agent/playable-flight-room`.
- Source SHA-256 must remain `1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478`.
- Source `.blend` is never saved, overwritten, or deleted.
- Canonical source frame is `Cube` local `+X` right, `+Y` forward, `+Z` up.
- Godot canonical frame is `+X` right, `-Z` forward, `+Y` up.
- Final GLB root position, rotation, and scale are identity.
- Canonical bounds are approximately `13.714 × 3.562 × 12.000 m`, tolerance `0.05 m` per axis.
- Collider is exactly `Vector3(14.0, 3.8, 12.2)`.
- Runtime GLB contains no object whose name starts with `EngineFire`.
- Exactly twelve sockets are required: two main, two retro, eight maneuver.
- Socket local `-Z` is exhaust travel; socket local `+Z` is reaction-force direction.
- Socket extraction fails on ambiguous geometry; it never guesses.
- Flight physics, speed envelopes, thermal timings, mass, controls, and camera behavior do not change.
- Dynamic exhaust reads final local force and torque, not raw keyboard state.
- Zero wrench produces zero visible plume, emission, particles, and light.
- Final registered Godot test target is `PASS: 16 suites`.

---

## File Structure

### Blender and Python tooling

- Create `tools/assets/small_fighter_calibration.py`: immutable approved constants and source-object/socket mappings.
- Create `tools/assets/canonical_fighter_contract.py`: manifest and output validation usable outside Blender.
- Create `tests/tools/test_small_fighter_calibration.py`: pure calibration and manifest contract tests.
- Replace `tools/assets/export_small_sci_fi_fighter.py`: canonical frame conversion, connected-component extraction, socket measurement, cleanup, export, manifest.
- Modify `tools/assets/export-small-fighter.ps1`: source immutability checks and canonical contract validation.

### Godot runtime

- Create `src/player/thruster_socket_data.gd`: parsed socket position, direction, class, and path.
- Create `src/player/thruster_activation.gd`: translation, rotation, total, and boostable activation values.
- Create `src/player/thruster_wrench_solver.gd`: pure deterministic non-negative wrench resolver.
- Create `src/player/thruster_effect_math.gd`: pure visibility, length, radius, emission, and light calculations.
- Create `src/player/ship_thruster_visual_controller.gd`: socket discovery, effect instantiation, solver execution, and smoothing.
- Create `src/vfx/thruster_exhaust.gd`: one socket-owned effect instance.
- Create `scenes/vfx/thruster_exhaust.tscn`: main/retro/maneuver-compatible plume scene.
- Modify `src/player/ship_flight_controller.gd`: retain and expose final local force and torque.
- Modify `scenes/player/player_interceptor.tscn`: identity GLB, approved collider, new thruster controller; remove temporary adapter/glows.

### Tests and cleanup

- Create `tests/unit/test_thruster_socket_data.gd`.
- Create `tests/unit/test_thruster_wrench_solver.gd`.
- Create `tests/unit/test_thruster_effect_math.gd`.
- Create `tests/integration/test_dynamic_thruster_runtime.gd`.
- Modify `tests/integration/test_hero_ship_asset.gd`.
- Modify `tests/integration/test_player_scene.gd`.
- Modify `tests/unit/test_flight_model.gd` or `tests/unit/test_ship_flight_state.gd` for final-wrench telemetry contracts.
- Modify `tests/test_runner.gd`.
- Delete `src/player/hero_ship_alignment.gd`.
- Delete `src/player/hero_ship_model_adapter.gd`.
- Delete `src/player/ship_visual_math.gd`.
- Delete `src/player/ship_visual_controller.gd`.
- Delete `tests/unit/test_hero_ship_alignment.gd`.
- Delete `tests/unit/test_ship_visual_math.gd`.
- Delete `tests/integration/test_hero_ship_adapter.gd`.
- Modify `README.md`.

---

### Task 1: Encode the Approved Calibration as Executable Data

**Files:**
- Create: `tools/assets/small_fighter_calibration.py`
- Create: `tests/tools/test_small_fighter_calibration.py`

**Interfaces:**
- Produces constants consumed by the Blender exporter and pure manifest validator.
- `SOURCE_SHA256: str`
- `SOURCE_FRAME_OBJECT: str`
- `HULL_CENTER_LOCAL: tuple[float, float, float]`
- `CANONICAL_LENGTH_METERS: float`
- `EXPECTED_DIMENSIONS_GODOT: tuple[float, float, float]`
- `COLLIDER_SIZE_GODOT: tuple[float, float, float]`
- `PLUME_GROUPS: dict[str, dict[str, object]]`

- [ ] **Step 1: Write the failing calibration tests**

```python
from small_fighter_calibration import (
    CANONICAL_LENGTH_METERS,
    COLLIDER_SIZE_GODOT,
    EXPECTED_DIMENSIONS_GODOT,
    HULL_CENTER_LOCAL,
    PLUME_GROUPS,
    SOURCE_FRAME_OBJECT,
    SOURCE_SHA256,
)


def test_approved_constants_are_exact():
    assert SOURCE_SHA256 == "1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478"
    assert SOURCE_FRAME_OBJECT == "Cube"
    assert HULL_CENTER_LOCAL == (0.0, -0.5693, 0.5081)
    assert CANONICAL_LENGTH_METERS == 12.0
    assert EXPECTED_DIMENSIONS_GODOT == (13.714, 3.562, 12.0)
    assert COLLIDER_SIZE_GODOT == (14.0, 3.8, 12.2)


def test_plume_groups_account_for_twelve_sockets():
    assert PLUME_GROUPS["EngineFire"]["components"] == 2
    assert sum(int(value["components"]) for value in PLUME_GROUPS.values()) == 12
    assert {value["class"] for value in PLUME_GROUPS.values()} == {
        "main", "retro", "maneuver"
    }
```

- [ ] **Step 2: Run RED**

```powershell
python -m unittest tests.tools.test_small_fighter_calibration -v
```

Expected: import failure because `small_fighter_calibration.py` does not exist.

- [ ] **Step 3: Implement the immutable constants**

```python
SOURCE_SHA256 = "1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478"
SOURCE_FRAME_OBJECT = "Cube"
HULL_CENTER_LOCAL = (0.0, -0.5693, 0.5081)
SOURCE_HULL_DIMENSIONS = (28.1266, 24.6110, 7.3053)
CANONICAL_LENGTH_METERS = 12.0
UNIFORM_SCALE = CANONICAL_LENGTH_METERS / SOURCE_HULL_DIMENSIONS[1]
EXPECTED_DIMENSIONS_GODOT = (13.714, 3.562, 12.0)
COLLIDER_SIZE_GODOT = (14.0, 3.8, 12.2)
BOUNDS_TOLERANCE = 0.05

PLUME_GROUPS = {
    "EngineFire": {"components": 2, "class": "main", "group": "Main"},
    "EngineFire.001": {"components": 1, "class": "retro", "group": "Retro"},
    "EngineFire.004": {"components": 1, "class": "retro", "group": "Retro"},
    "EngineFire.002": {"components": 1, "class": "maneuver", "group": "FrontUpper"},
    "EngineFire.003": {"components": 1, "class": "maneuver", "group": "FrontUpper"},
    "EngineFire.005": {"components": 1, "class": "maneuver", "group": "RearUpper"},
    "EngineFire.006": {"components": 1, "class": "maneuver", "group": "RearUpper"},
    "EngineFire.007": {"components": 1, "class": "maneuver", "group": "RearLower"},
    "EngineFire.008": {"components": 1, "class": "maneuver", "group": "RearLower"},
    "EngineFire.009": {"components": 1, "class": "maneuver", "group": "FrontLower"},
    "EngineFire.010": {"components": 1, "class": "maneuver", "group": "FrontLower"},
}
```

- [ ] **Step 4: Run GREEN and commit**

```powershell
python -m unittest tests.tools.test_small_fighter_calibration -v
```

```bash
git add tools/assets/small_fighter_calibration.py tests/tools/test_small_fighter_calibration.py
git commit -m "test: encode canonical fighter calibration"
```

---

### Task 2: Add the Canonical Manifest Contract

**Files:**
- Create: `tools/assets/canonical_fighter_contract.py`
- Modify: `tests/tools/test_small_fighter_calibration.py`

**Interfaces:**
- `validate_manifest(path: Path, expected_source_sha: str) -> list[str]`
- `validate_output(glb_path: Path, manifest_path: Path, expected_source_sha: str) -> list[str]`

- [ ] **Step 1: Add failing fixture tests**

The valid manifest fixture must include:

```python
{
    "schema_version": 2,
    "source_sha256": SOURCE_SHA256,
    "canonical_frame": {
        "godot_right": "+X",
        "godot_forward": "-Z",
        "godot_up": "+Y",
        "root_identity": True,
    },
    "dimensions_godot_xyz": [13.714, 3.562, 12.0],
    "collider_size_godot_xyz": [14.0, 3.8, 12.2],
    "removed_objects": ["EngineFire", "EngineFire.001"],
    "sockets": [
        {
            "path": f"Thrusters/Maneuver/Socket{index:02d}",
            "class": "maneuver",
            "source_object": "fixture",
            "source_component": index,
            "position": [0.0, 0.0, 0.0],
            "exhaust_direction": [0.0, 0.0, -1.0],
            "reaction_direction": [0.0, 0.0, 1.0],
            "basis": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
        }
        for index in range(12)
    ],
}
```

Tests must reject:

- non-identity root contract;
- dimensions outside `0.05` tolerance;
- socket count not equal to twelve;
- non-unit or non-opposite direction vectors;
- duplicate socket paths;
- missing `EngineFire*` removal evidence;
- incorrect class counts;
- missing or empty GLB.

- [ ] **Step 2: Run RED**

Expected: import failure for `canonical_fighter_contract`.

- [ ] **Step 3: Implement strict validation**

Class counts must be exactly:

```python
{"main": 2, "retro": 2, "maneuver": 8}
```

Direction checks:

```python
abs(length(exhaust) - 1.0) <= 1e-4
abs(length(reaction) - 1.0) <= 1e-4
dot(exhaust, reaction) <= -0.9999
```

Basis checks require three unit orthogonal axes and determinant near `+1`.

- [ ] **Step 4: Run GREEN and commit**

```bash
git add tools/assets/canonical_fighter_contract.py tests/tools/test_small_fighter_calibration.py
git commit -m "test: define canonical fighter manifest contract"
```

---

### Task 3: Rebuild the Blender Exporter Around `Cube` Local Space

**Files:**
- Replace: `tools/assets/export_small_sci_fi_fighter.py`
- Modify: `tests/tools/test_small_fighter_calibration.py`

**Interfaces:**
- Input: the currently opened approved source `.blend`.
- Output: `small_sci_fi_fighter.glb` and schema-version-2 manifest.
- Helper functions that do not require `bpy` belong in `small_fighter_calibration.py` and receive pure tests.

- [ ] **Step 1: Add static exporter safety tests**

Read the exporter as text/AST and assert:

```python
forbidden = ("save_as_mainfile", "save_mainfile", "save_homefile")
assert not any(token in source for token in forbidden)
assert "SOURCE_FRAME_OBJECT" in source
assert "EngineFire" in source
assert "export_extras=True" in source
```

- [ ] **Step 2: Run RED**

Expected: fail because the old exporter does not use the approved source-frame conversion and schema.

- [ ] **Step 3: Validate the source and capture evidence before mutation**

Exporter startup must:

```python
source_path = Path(bpy.data.filepath).resolve()
assert sha256_file(source_path) == SOURCE_SHA256
source_frame = bpy.data.objects.get(SOURCE_FRAME_OBJECT)
if source_frame is None or source_frame.type != "MESH":
    raise RuntimeError("Approved source frame Cube is missing")
source_frame_inverse = source_frame.matrix_world.inverted_safe()
```

Require every key in `PLUME_GROUPS` to resolve to a visible mesh object.

- [ ] **Step 4: Duplicate retained ship geometry into a clean in-memory collection**

Retain visible mesh objects except names beginning with `EngineFire`. For each retained object:

```python
duplicate = source.copy()
duplicate.data = source.data.copy()
duplicate.matrix_world = source_frame_inverse @ source.matrix_world
```

Apply modifiers by converting duplicates to meshes. Do not mutate source objects.

Join retained duplicates under a new identity root named `SmallSciFiFighter` with the render mesh named `SmallSciFiFighterMesh`.

- [ ] **Step 5: Center and uniformly scale the retained hull**

Calculate evaluated bounds in the clean `Cube`-local collection. Verify the center is within `0.02` source units of `HULL_CENTER_LOCAL` and dimensions within `0.05` source units of `SOURCE_HULL_DIMENSIONS`.

Apply:

```python
mesh_translation = -Vector(HULL_CENTER_LOCAL)
mesh_scale = Vector((UNIFORM_SCALE,) * 3)
```

Apply location, rotation, and scale to mesh data so the export root and mesh object use identity transforms.

- [ ] **Step 6: Remove permanent exhaust emission from hull hardware**

Duplicate materials before edits. For the duplicated material named `Thrusters`:

- disconnect `ShaderNodeEmission` nodes from material output;
- set Principled emission color to black;
- set Principled emission strength to zero;
- preserve base color, metallic, roughness, normal, and textures.

Do not alter the source material datablock.

- [ ] **Step 7: Commit the canonical-frame exporter core**

```bash
git add tools/assets/export_small_sci_fi_fighter.py tests/tools/test_small_fighter_calibration.py
git commit -m "feat: canonicalize fighter in Cube local frame"
```

---

### Task 4: Extract Twelve Deterministic Thruster Sockets

**Files:**
- Modify: `tools/assets/export_small_sci_fi_fighter.py`
- Modify: `tools/assets/small_fighter_calibration.py`
- Modify: `tests/tools/test_small_fighter_calibration.py`

**Interfaces:**
- Pure helpers:
  - `connected_components(vertex_count, edges) -> list[list[int]]`
  - `principal_axis(points) -> tuple[float, float, float]`
  - `classify_socket_name(group, position) -> str`
- Blender helper:
  - `extract_socket(component_vertices, hull_bvh, canonical_transform) -> SocketRecord`

- [ ] **Step 1: Write failing pure geometry tests**

Tests must prove:

- two disconnected triangle islands produce two components;
- principal axis of points distributed along Y is unit `±Y`;
- left/right names are selected by canonical X position;
- group names produce unique paths;
- twelve approved source components produce exactly twelve unique paths.

- [ ] **Step 2: Run RED**

Expected: missing helpers.

- [ ] **Step 3: Implement connected-component extraction**

Build an adjacency list from evaluated mesh edges and breadth-first search all vertices referenced by polygons. Ignore isolated unreferenced vertices. Sort components by minimum vertex index for deterministic output.

Verify each source object produces the component count declared in `PLUME_GROUPS`; otherwise fail with source object, expected count, actual count.

- [ ] **Step 4: Implement principal-axis measurement without NumPy**

Compute the symmetric 3×3 covariance matrix around the component centroid. Use 32 iterations of normalized power iteration starting from the longest AABB axis. Fail if covariance magnitude or resulting axis length is below `1e-8`.

- [ ] **Step 5: Resolve nozzle end and axis sign**

For each component:

1. project vertices onto the unsigned principal axis;
2. take the lowest and highest 20% projection slices;
3. calculate each slice centroid and radial RMS around the axis;
4. query the retained hull `BVHTree.find_nearest()` distance for both centroids;
5. require one end to be at least `15%` closer to the hull than the other;
6. require the closer end radial RMS not to be less than `60%` of the far-end RMS;
7. choose the closer centroid as socket origin;
8. choose direction from socket origin toward far centroid as exhaust travel.

Ambiguity raises `RuntimeError` with both distances, radial RMS values, and source component.

- [ ] **Step 6: Convert and name sockets**

Apply the approved center translation and uniform scale. Convert Blender canonical coordinates into exported Y-up coordinates through the glTF exporter, not by manually swapping coordinates.

Create hierarchy:

```text
Thrusters
├── Main
├── Retro
└── Maneuver
```

Create identity-scale empties. Orient each empty so local `-Z` equals measured exhaust travel. Stable semantic names:

```text
Main/Left
Main/Right
Retro/Left
Retro/Right
Maneuver/FrontUpperLeft
Maneuver/FrontUpperRight
Maneuver/RearUpperLeft
Maneuver/RearUpperRight
Maneuver/RearLowerLeft
Maneuver/RearLowerRight
Maneuver/FrontLowerLeft
Maneuver/FrontLowerRight
```

Set custom properties:

```python
socket["thruster_class"] = class_name
socket["source_object"] = source_name
socket["source_component"] = component_index
```

- [ ] **Step 7: Write manifest socket records and export**

Use:

```python
bpy.ops.export_scene.gltf(
    filepath=str(output_path),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=True,
    export_materials="EXPORT",
    export_normals=True,
    export_tangents=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
    export_extras=True,
)
```

Manifest socket paths, positions, directions, and bases must be measured from the final export hierarchy, not pre-export guesses.

- [ ] **Step 8: Run pure GREEN and commit**

```bash
git add tools/assets/export_small_sci_fi_fighter.py tools/assets/small_fighter_calibration.py tests/tools/test_small_fighter_calibration.py
git commit -m "feat: extract canonical fighter thruster sockets"
```

---

### Task 5: Harden the PowerShell Export Gate

**Files:**
- Modify: `tools/assets/export-small-fighter.ps1`
- Modify: `README.md`

**Interfaces:**
- Runs Blender and then Python canonical validation.
- Refuses to finish if source SHA changes or outputs violate the contract.

- [ ] **Step 1: Add source SHA before/after checks**

```powershell
$sourceShaBefore = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sourceShaBefore -ne $expectedSourceSha) {
    throw "Unexpected fighter source SHA: $sourceShaBefore"
}
```

Repeat after Blender exits and require equality.

- [ ] **Step 2: Run canonical validation**

```powershell
& $pythonExecutable $validatorPath `
  --glb $outputPath `
  --manifest $manifestPath `
  --source-sha $sourceShaBefore
if ($LASTEXITCODE -ne 0) {
    throw "Canonical fighter contract validation failed"
}
```

- [ ] **Step 3: Update the README export section**

Document that export now removes baked flames, creates twelve sockets, and produces an identity-root asset. Remove claims about runtime marker correction.

- [ ] **Step 4: Commit**

```bash
git add tools/assets/export-small-fighter.ps1 README.md
git commit -m "build: enforce canonical fighter export contract"
```

---

### Task 6: Local Blender Export Checkpoint

**Files generated:**
- Replace: `assets/runtime/ships/player/small_sci_fi_fighter.glb`
- Replace: `assets/runtime/ships/player/small_sci_fi_fighter.manifest.json`

- [ ] **Step 1: Run pure Python tests**

```powershell
python -m unittest tests.tools.test_small_fighter_calibration -v
```

- [ ] **Step 2: Generate the canonical binary locally**

```powershell
.\tools\assets\export-small-fighter.ps1
```

Or:

```powershell
.\tools\assets\export-small-fighter.ps1 `
  -BlenderBin "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
```

- [ ] **Step 3: Inspect command evidence**

Required output includes:

```text
source SHA validated
Cube-local hull dimensions validated
12 socket components extracted
2 main / 2 retro / 8 maneuver sockets
canonical GLB written
schema version 2 manifest validated
source SHA unchanged
```

- [ ] **Step 4: Commit and push the generated asset pair**

```bash
git add assets/runtime/ships/player/small_sci_fi_fighter.glb assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
git commit -m "feat: export canonical socketed hero fighter"
git push
```

This checkpoint must complete before Tasks 7–13 are integrated.

---

### Task 7: Replace the Godot Hero-Asset Contract

**Files:**
- Modify: `tests/integration/test_hero_ship_asset.gd`
- Delete later: `tests/integration/test_hero_ship_adapter.gd`

**Interfaces:**
- Validates the imported canonical GLB itself.

- [ ] **Step 1: Write the failing canonical assertions**

Require:

```gdscript
var fighter := packed.instantiate() as Node3D
assert_true(fighter.transform.is_equal_approx(Transform3D.IDENTITY), "identity root")
assert_true(fighter.find_child("EngineFire*", true, false) == null, "no baked fire")
var thrusters := fighter.find_child("Thrusters", true, false) as Node3D
assert_true(thrusters != null, "Thrusters hierarchy required")
```

Recursively gather sockets below `Main`, `Retro`, and `Maneuver`; require counts `2`, `2`, and `8`. For every socket:

```gdscript
assert_true(socket.scale.is_equal_approx(Vector3.ONE), "identity socket scale")
var basis := socket.transform.basis.orthonormalized()
assert_true(absf(basis.determinant() - 1.0) < 0.001, "valid socket basis")
assert_true((basis * Vector3.FORWARD).length() > 0.999, "valid exhaust direction")
```

Calculate final transformed mesh bounds and require `13.714 × 3.562 × 12.000` within `0.05`.

- [ ] **Step 2: Run RED against the old GLB**

Expected: identity, socket hierarchy, count, bounds, and baked-fire assertions fail.

- [ ] **Step 3: Pull the canonical binary and run GREEN**

Do not change the GLB in Godot to satisfy the test. Fix exporter output if the asset contract fails.

- [ ] **Step 4: Commit test update**

```bash
git add tests/integration/test_hero_ship_asset.gd
git commit -m "test: enforce canonical socketed hero asset"
```

---

### Task 8: Expose Final Local Wrench Telemetry

**Files:**
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_flight_model.gd`
- Modify: `tests/integration/test_player_scene.gd`

**Interfaces:**
- `get_final_local_force() -> Vector3`
- `get_final_local_torque() -> Vector3`
- Existing flight behavior remains unchanged.

- [ ] **Step 1: Add failing telemetry assertions**

Require default and reset values to be zero. Add a controller test seam:

```gdscript
func set_final_wrench_for_test(force_local: Vector3, torque_local: Vector3) -> void:
    assert(OS.is_debug_build())
```

This seam exists only for runtime visual integration tests and must not mutate physics.

- [ ] **Step 2: Store the computed output immediately before applying it**

```gdscript
_final_local_force = output.force_local
_final_local_torque = output.torque_local
_body.apply_central_force(basis * _final_local_force)
_body.apply_torque(basis * _final_local_torque)
```

- [ ] **Step 3: Reset telemetry**

`reset_runtime_state()` sets both vectors to zero.

- [ ] **Step 4: Run GREEN and commit**

```bash
git add src/player/ship_flight_controller.gd tests/unit/test_flight_model.gd tests/integration/test_player_scene.gd
git commit -m "feat: expose final local flight wrench"
```

---

### Task 9: Parse Canonical Socket Data

**Files:**
- Create: `src/player/thruster_socket_data.gd`
- Create: `tests/unit/test_thruster_socket_data.gd`

**Interfaces:**

```gdscript
class_name ThrusterSocketData
extends RefCounted

var node_path: NodePath
var socket_class: StringName
var position_local: Vector3
var reaction_direction: Vector3
var torque_direction: Vector3

static func from_node(root: Node3D, socket: Node3D) -> ThrusterSocketData
```

- [ ] **Step 1: Write failing tests**

Construct sockets with known transforms and require:

```gdscript
reaction_direction == socket.transform.basis * Vector3.BACK
# Vector3.BACK is local +Z reaction direction.
torque_direction == position_local.cross(reaction_direction)
```

Require class parsing from paths containing `/Main/`, `/Retro/`, or `/Maneuver/`; unknown paths return `null` and one caller warning.

- [ ] **Step 2: Implement normalized parsing**

Convert socket global transform into player-local coordinates through:

```gdscript
var local_transform := root.global_transform.affine_inverse() * socket.global_transform
```

Normalize directions and reject zero reaction or degenerate basis.

- [ ] **Step 3: Run GREEN and commit**

```bash
git add src/player/thruster_socket_data.gd tests/unit/test_thruster_socket_data.gd
git commit -m "feat: parse canonical thruster sockets"
```

---

### Task 10: Implement the Deterministic Wrench Solver

**Files:**
- Create: `src/player/thruster_activation.gd`
- Create: `src/player/thruster_wrench_solver.gd`
- Create: `tests/unit/test_thruster_wrench_solver.gd`

**Interfaces:**

```gdscript
class_name ThrusterActivation
extends RefCounted

var translation_amount := 0.0
var rotation_amount := 0.0
var total_amount := 0.0
var boostable_amount := 0.0
```

```gdscript
static func solve(
    sockets: Array[ThrusterSocketData],
    requested_force: Vector3,
    requested_torque: Vector3,
    force_reference: float,
    torque_reference: float
) -> Array[ThrusterActivation]
```

- [ ] **Step 1: Write failing solver tests**

Cover:

- zero wrench returns all zero;
- forward force chooses only main-compatible reaction directions;
- reverse force chooses retro-compatible directions;
- lateral and vertical force selects appropriate maneuver sockets;
- pure pitch/yaw/roll does not activate main engines;
- combined force and torque produces bounded mixed activations;
- all values remain in `[0, 1]`;
- symmetric socket arrangements produce symmetric activations;
- deterministic repeated calls return equal arrays.

- [ ] **Step 2: Normalize desired force and torque independently**

```gdscript
var desired_force := requested_force / maxf(force_reference, 0.001)
var desired_torque := requested_torque / maxf(torque_reference, 0.001)
if desired_force.length() > 1.0:
    desired_force = desired_force.normalized()
if desired_torque.length() > 1.0:
    desired_torque = desired_torque.normalized()
```

- [ ] **Step 3: Build class-weighted socket contributions**

Use exact weights:

```text
main:     force 1.00, torque 0.15
retro:    force 0.65, torque 0.15
maneuver: force 0.32, torque 1.00
```

Normalize torque lever arms by the maximum socket-position length, minimum `0.001`.

- [ ] **Step 4: Solve translation and rotation separately**

Use 24 deterministic projected coordinate-descent passes. For each socket contribution `c` and current residual `r`:

```text
new_activation = clamp(dot(c, r + old_activation*c) /
                       (dot(c, c) + 0.035), 0, 1)
```

Run once using force contributions only and once using torque contributions only.

Combine:

```gdscript
translation_amount = force_solution[i]
rotation_amount = torque_solution[i]
total_amount = clampf(maxf(translation_amount, rotation_amount), 0.0, 1.0)
boostable_amount = translation_amount
```

- [ ] **Step 5: Run GREEN and commit**

```bash
git add src/player/thruster_activation.gd src/player/thruster_wrench_solver.gd tests/unit/test_thruster_wrench_solver.gd
git commit -m "feat: resolve final wrench across thruster sockets"
```

---

### Task 11: Build Socket-Owned Exhaust Effects

**Files:**
- Create: `src/player/thruster_effect_math.gd`
- Create: `src/vfx/thruster_exhaust.gd`
- Create: `scenes/vfx/thruster_exhaust.tscn`
- Create: `tests/unit/test_thruster_effect_math.gd`

**Interfaces:**

```gdscript
class_name ThrusterEffectMath
extends RefCounted

static func smoothed(current: float, target: float, sharpness: float, delta: float) -> float
static func visible(amount: float) -> bool
static func length_scale(amount: float, boostable: float, boost: float, socket_class: StringName) -> float
static func radius_scale(amount: float, socket_class: StringName) -> float
static func emission_energy(amount: float, boostable: float, boost: float, socket_class: StringName) -> float
static func light_energy(amount: float, boostable: float, boost: float, socket_class: StringName) -> float
```

- [ ] **Step 1: Write failing effect tests**

Require:

- amount zero is invisible and returns zero light/emission;
- boost does nothing when `boostable == 0`;
- main plume is longer than retro; retro longer than maneuver at equal amount;
- outputs increase monotonically;
- smoothing reaches zero without a persistent minimum.

- [ ] **Step 2: Implement exact class scales**

Base maximum lengths:

```text
main: 2.8 m
retro: 1.4 m
maneuver: 0.65 m
```

Base radii:

```text
main: 0.28 m
retro: 0.18 m
maneuver: 0.10 m
```

Boost multiplier:

```gdscript
1.0 + clampf(boostable * boost, 0.0, 1.0) * 0.75
```

Visibility threshold: `0.002`.

- [ ] **Step 3: Create the Compatibility-safe effect scene**

Hierarchy:

```text
ThrusterExhaust (Node3D, ThrusterExhaust script)
├── PlumePivot (Node3D)
│   ├── OuterPlume (MeshInstance3D)
│   └── CorePlume (MeshInstance3D)
└── ExhaustLight (OmniLight3D)
```

Use cylinder/cone meshes with transparent emissive materials. The plume extends from origin along local `-Z`; position mesh centers at half their current negative length. No particles are required in this milestone.

`set_activation(amount, boostable_amount, boost_amount, socket_class, delta)` updates visibility, transform, material emission, and light. At zero it explicitly hides both meshes and light.

- [ ] **Step 4: Run GREEN and commit**

```bash
git add src/player/thruster_effect_math.gd src/vfx/thruster_exhaust.gd scenes/vfx/thruster_exhaust.tscn tests/unit/test_thruster_effect_math.gd
git commit -m "feat: add socket-owned thruster exhaust effect"
```

---

### Task 12: Integrate the Dynamic Thruster Visual Controller

**Files:**
- Create: `src/player/ship_thruster_visual_controller.gd`
- Create: `tests/integration/test_dynamic_thruster_runtime.gd`
- Modify: `scenes/player/player_interceptor.tscn`

**Interfaces:**
- Discovers exactly twelve sockets below the imported `Thrusters` node.
- Instantiates one `thruster_exhaust.tscn` child per socket.
- Reads final force, torque, and boost from `ShipFlightController`.

- [ ] **Step 1: Write the failing runtime integration test**

Instantiate the player inside a temporary `Node3D`, allow one process frame, and require:

- `HeroShipModelAdapter` absent;
- fixed `LeftEngineGlowAnchor` and `RightEngineGlowAnchor` absent;
- `ShipThrusterVisualController` present;
- twelve parsed sockets;
- twelve effect instances;
- all effects invisible at zero wrench;
- test-set forward wrench lights main effects, not retro;
- pure torque lights maneuver effects, not main;
- returning to zero hides every effect after smoothing settles.

- [ ] **Step 2: Implement socket discovery and one-time warnings**

Resolve:

```text
../VisualRoot/SmallSciFiFighter/Thrusters
../ShipFlightController
```

Recursively collect leaf `Node3D` sockets below `Main`, `Retro`, and `Maneuver`, sort by `NodePath` string, and parse with `ThrusterSocketData.from_node()`.

Require exactly twelve. Missing hierarchy disables visuals but never physics.

- [ ] **Step 3: Instantiate effects at socket transforms**

Add each effect as a child of its socket with identity transform. Effects inherit exact exported orientation.

- [ ] **Step 4: Resolve and update every frame**

References:

```gdscript
var force_reference := maxf(
    tuning.forward_force * tuning.boost_multiplier,
    maxf(tuning.reverse_force, tuning.strafe_force) * tuning.boost_multiplier
)
var torque_reference := maxf(
    tuning.pitch_torque,
    maxf(tuning.yaw_torque, tuning.roll_torque)
)
```

Call solver with controller final wrench. Pass each activation and current boost to its effect.

- [ ] **Step 5: Run GREEN and commit**

```bash
git add src/player/ship_thruster_visual_controller.gd tests/integration/test_dynamic_thruster_runtime.gd scenes/player/player_interceptor.tscn
git commit -m "feat: drive dynamic exhaust from final flight wrench"
```

---

### Task 13: Remove Temporary Alignment and Fixed-Glow Architecture

**Files:**
- Modify: `scenes/player/player_interceptor.tscn`
- Modify: `tests/integration/test_player_scene.gd`
- Delete: `src/player/hero_ship_alignment.gd`
- Delete: `src/player/hero_ship_model_adapter.gd`
- Delete: `src/player/ship_visual_math.gd`
- Delete: `src/player/ship_visual_controller.gd`
- Delete: `tests/unit/test_hero_ship_alignment.gd`
- Delete: `tests/unit/test_ship_visual_math.gd`
- Delete: `tests/integration/test_hero_ship_adapter.gd`

- [ ] **Step 1: Replace the collider and scene hierarchy**

```gdscript
BoxShape3D.size = Vector3(14.0, 3.8, 12.2)
```

Required hierarchy:

```text
PlayerInterceptor
├── CollisionShape3D
├── VisualRoot
│   └── SmallSciFiFighter (identity transform)
├── CameraTarget
├── PlayerInputSource
├── ShipFlightController
└── ShipThrusterVisualController
```

No effect geometry is authored manually in the player scene.

- [ ] **Step 2: Update player-scene assertions**

Require identity fighter transform, approved collider, new controller, and absence of all deleted nodes/scripts.

- [ ] **Step 3: Delete obsolete files and references**

Search for:

```text
HeroShipAlignment
HeroShipModelAdapter
ShipVisualMath
ShipVisualController
LeftEngineGlowAnchor
RightEngineGlowAnchor
```

No runtime or test reference may remain.

- [ ] **Step 4: Commit cleanup**

```bash
git add -A
git commit -m "refactor: remove temporary hero alignment and fixed glows"
```

---

### Task 14: Register the Final Sixteen-Suite Gate

**Files:**
- Modify: `tests/test_runner.gd`
- Modify: `tools/verify/verify.ps1`
- Modify: `tools/verify/verify.sh`

- [ ] **Step 1: Replace removed suites and register new suites**

Final list keeps the twelve foundation/camera/room/asset suites, removes three temporary alignment/glow suites, and adds four:

```text
res://tests/unit/test_thruster_socket_data.gd
res://tests/unit/test_thruster_wrench_solver.gd
res://tests/unit/test_thruster_effect_math.gd
res://tests/integration/test_dynamic_thruster_runtime.gd
```

Expected total: `16`.

- [ ] **Step 2: Strengthen verifier preflight**

Require manifest schema `2`, twelve sockets, class counts `2/2/8`, canonical dimensions, and identity-root flag before Godot import.

- [ ] **Step 3: Run the complete local verifier**

```powershell
.\tools\verify\verify.ps1
```

Required evidence:

```text
canonical manifest preflight passed
Godot import completed
PASS: 16 suites
main scene boot completed without errors
```

- [ ] **Step 4: Commit**

```bash
git add tests/test_runner.gd tools/verify/verify.ps1 tools/verify/verify.sh
git commit -m "test: enforce canonical fighter and thruster runtime"
```

---

### Task 15: Manual Orientation and Thruster Acceptance

**Files:**
- Modify: `README.md`
- Modify only with evidence: the smallest affected effect-math or tuning file and its test.

- [ ] **Step 1: Launch the game**

```powershell
godot --path .
```

- [ ] **Step 2: Verify canonical orientation and size**

Confirm:

1. visible nose points into forward travel;
2. visible top follows ship-local up;
3. no scene correction appears on the GLB instance;
4. broad wings match the `13.714 m` width;
5. collision approximately follows `14.0 × 3.8 × 12.2 m`.

- [ ] **Step 3: Verify all dynamic channels**

Confirm:

1. idle: all twelve effects fully dark;
2. W: two main effects;
3. S: two retro effects;
4. Q/E: physically correct lateral maneuver jets;
5. Space/Ctrl: physically correct vertical maneuver jets;
6. pitch: opposing front/rear maneuver pair;
7. yaw: opposing left/right pair;
8. roll: diagonal/opposed maneuver set;
9. assisted steering and auto-bank visibly use maneuver jets;
10. Shift strengthens active translation exhaust only;
11. releasing controls returns every effect to fully hidden;
12. no baked `EngineFire` geometry is visible.

- [ ] **Step 4: Update README with verified behavior**

Document canonical dimensions, collider, socket counts, final-wrench activation, export command, verifier target, and development-only license status.

- [ ] **Step 5: Fresh final verification**

```powershell
python -m unittest tests.tools.test_hero_ship_audit_contract tests.tools.test_small_fighter_calibration -v
.\tools\verify\verify.ps1
git diff --check
git status --short
```

- [ ] **Step 6: Commit documentation**

```bash
git add README.md
git commit -m "docs: verify canonical fighter thruster milestone"
```

---

## Final Review Gate

1. Source SHA remains unchanged.
2. Blender exporter uses `Cube` local space and an identity export root.
3. Hull center and uniform scale match the approved calibration.
4. Runtime GLB bounds are approximately `13.714 × 3.562 × 12.000 m`.
5. Player collider is `14.0 × 3.8 × 12.2 m`.
6. No `EngineFire*` mesh remains in the runtime GLB.
7. Manifest contains exactly two main, two retro, and eight maneuver sockets.
8. Every socket uses local `-Z` exhaust and local `+Z` reaction direction.
9. Runtime contains no model adapter, corrective GLB transform, or fixed glow anchors.
10. Controller exposes the exact final local force and torque it applies.
11. Solver is deterministic, non-negative, bounded, and activates no main engines for pure rotation.
12. Effects are completely invisible at zero activation.
13. Boost strengthens only the translation-derived portion of active exhaust.
14. Godot prints `PASS: 16 suites` and boots cleanly.
15. Manual checks confirm correct orientation, scale, and all available translation/rotation thruster behaviors.
