# Deterministic Dual-Channel Thruster System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a source-exact, nozzle-anchored fighter thruster system whose direct exhaust follows only current pilot commands, whose assisted corrections remain visible at a capped 35%, and whose twelve actions activate deterministic physically validated thruster sets.

**Architecture:** Split flight physics telemetry into pilot and assisted contributions, generate and check in a deterministic action matrix from the canonical socket manifest, and drive nozzle-local schema-4 meshes through a pure dual-channel mixer and smootherstep envelope. Runtime never solves or reshuffles mappings; it loads validated data, merges direct and assisted targets, and modifies only effect visibility, material output, and nozzle-local scale.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, Blender 5.2 LTS Python API, Python 3 `unittest`, PowerShell/Bash transactional asset wrappers, GL Compatibility renderer.

## Global Constraints

- Direct exhaust appears only from the current `FlightCommand`; retained velocity must never activate direct exhaust.
- Assisted damping, drift correction, auto-bank, and stabilization remain visible but are capped exactly once at `35%` visual intensity.
- Approved arrow mapping is `Down Arrow → pitch up` and `Up Arrow → pitch down`.
- Runtime must use checked-in action-matrix data and must not run a free-form force/torque allocator.
- Full-size effect geometry must reconstruct the original evaluated `EngineFire*` vertices within `0.0001 m` maximum error.
- Direct rise/fall time is `0.22 s`; assisted rise/fall time is `0.16 s`.
- Envelope response is smootherstep; length scale is `lerp(0.04, 1.00, s)`, radius scale is `lerp(0.22, 1.00, s)`, opacity is `e²`, and emission is `e³`.
- Boost can modify only an already-active main or retro effect.
- Export remains transactional: live GLB and manifest are replaced only after schema-4 validation succeeds.
- No GitHub Actions workflow is added; verification is local through `tools/verify/verify.ps1` or `tools/verify/verify.sh`.
- This phase targets only the canonical Small Sci-Fi Fighter; generalized multi-ship propulsion is out of scope.

---

## Planned File Structure

### Flight telemetry

- Modify `src/flight/flight_output.gd` — own pilot, assisted, and total force/torque fields.
- Modify `src/flight/flight_model.gd` — calculate pilot physics separately from assisted corrections.
- Modify `src/player/ship_flight_controller.gd` — preserve the sampled `FlightCommand` and expose split telemetry.

### Deterministic mapping

- Create `src/player/thruster_action.gd` — canonical twelve-action enum and axis targets.
- Create `src/player/thruster_action_matrix.gd` — load and validate checked-in action records.
- Create `config/ships/small_sci_fi_fighter_thruster_actions.json` — immutable runtime mapping generated from schema-4 socket capabilities.
- Create `tools/assets/generate_fighter_thruster_action_matrix.py` — deterministic development-time matrix generator.
- Create `tools/assets/fighter_thruster_action_contract.py` — Python validation of checked-in mappings.
- Remove `src/player/ship_thruster_allocator.gd` after runtime migration.

### Visual state

- Create `src/player/thruster_visual_math.gd` — channel merge, cap, smootherstep, rise/fall, scale, opacity, and emission math.
- Modify `src/player/ship_thruster_visual_controller.gd` — wrapper-safe hierarchy discovery, deterministic action lookup, dual channels, and nozzle-local effect transforms.

### Schema-4 asset pipeline

- Create `tools/assets/export_small_sci_fi_fighter_v4.py` — schema-4 orchestrator.
- Modify `tools/assets/source_exact_thruster_geometry.py` — convert canonical vertices to nozzle-local vertices and record reconstruction error.
- Create `tools/assets/canonical_fighter_contract_v4.py` — schema-4 validation.
- Modify `tools/assets/export-small-fighter.ps1` — use v4 exporter/validator and invoke action-matrix generation before publication.
- Modify `tools/verify/verify.ps1` and `tools/verify/verify.sh` — require schema 4 and the checked-in mapping contract.

### Calibration and tests

- Create `scenes/debug/thruster_calibration.tscn`.
- Create `src/debug/thruster_calibration.gd`.
- Create `tests/unit/test_thruster_action_matrix.gd`.
- Create `tests/unit/test_thruster_visual_math.gd`.
- Create `tests/integration/test_thruster_calibration_scene.gd`.
- Modify `tests/unit/test_flight_model.gd`.
- Modify `tests/unit/test_player_input_math.gd`.
- Modify `tests/unit/test_ship_flight_controller_state.gd`.
- Modify `tests/integration/test_hero_ship_asset.gd`.
- Modify `tests/integration/test_ship_thruster_visual_controller.gd`.
- Modify `tests/test_runner.gd`.
- Create `tests/tools/test_fighter_thruster_action_contract.py`.
- Create `tests/tools/test_canonical_fighter_v4.py`.
- Modify `tests/tools/test_source_exact_thruster_geometry.py`.
- Modify `tests/tools/test_verify_scripts.py`.

---

### Task 1: Restore the Verified Baseline

**Files:**
- Modify: `tests/unit/test_player_input_math.gd`
- Modify: `src/player/ship_thruster_visual_controller.gd`
- Modify: `tests/integration/test_ship_thruster_visual_controller.gd`

**Interfaces:**
- Consumes: imported fighter instance under `VisualRoot/SmallSciFiFighter`.
- Produces: `ShipThrusterVisualController.find_unique_logical_root(root: Node, logical_name: StringName) -> Node3D` and a green baseline before behavior changes.

- [ ] **Step 1: Correct the failing arrow-key assertions**

Replace the two stale assertions with:

```gdscript
assert_true(
    _action_has_key(&"pitch_up", KEY_DOWN),
    "Down Arrow must pitch up"
)
assert_true(
    _action_has_key(&"pitch_down", KEY_UP),
    "Up Arrow must pitch down"
)
```

- [ ] **Step 2: Add a failing wrapper-depth hierarchy test**

Extend `tests/integration/test_ship_thruster_visual_controller.gd` with a synthetic hierarchy containing two anonymous wrapper nodes and one logical effect root:

```gdscript
var imported_wrapper := Node3D.new()
var generated_root := Node3D.new()
var logical_root := Node3D.new()
logical_root.name = "ThrusterEffects"
imported_wrapper.add_child(generated_root)
generated_root.add_child(logical_root)

assert_equal(
    ShipThrusterVisualController.find_unique_logical_root(
        imported_wrapper,
        &"ThrusterEffects"
    ),
    logical_root,
    "logical hierarchy lookup must ignore imported wrapper depth"
)
```

Also add a duplicate-root case and assert the result is `null`.

- [ ] **Step 3: Run the focused test runner and verify RED**

Run:

```powershell
& "C:\Tools\Godot\godot.cmd" --headless --path . --script res://tests/test_runner.gd
```

Expected: the new hierarchy lookup assertion fails because the public helper does not exist; the arrow assertions no longer fail.

- [ ] **Step 4: Implement wrapper-safe logical-root discovery**

Add to `src/player/ship_thruster_visual_controller.gd`:

```gdscript
static func find_unique_logical_root(
    root: Node,
    logical_name: StringName
) -> Node3D:
    var matches: Array[Node3D] = []
    _collect_named_node3d(root, logical_name, matches)
    return matches[0] if matches.size() == 1 else null

static func _collect_named_node3d(
    node: Node,
    logical_name: StringName,
    matches: Array[Node3D]
) -> void:
    var node_3d := node as Node3D
    if node_3d != null and node_3d.name == logical_name:
        matches.append(node_3d)
    for child: Node in node.get_children():
        _collect_named_node3d(child, logical_name, matches)
```

Replace both `_find_single_named_node` calls with `find_unique_logical_root` and delete the old helper.

- [ ] **Step 5: Run the full local verifier**

Run:

```powershell
.\tools\verify\verify.ps1
```

Expected: project imports, the current suite count passes, and the main scene boots. Do not proceed while `ThrusterEffects hierarchy` or arrow assertions remain.

- [ ] **Step 6: Commit the baseline repair**

```powershell
git add tests/unit/test_player_input_math.gd `
  tests/integration/test_ship_thruster_visual_controller.gd `
  src/player/ship_thruster_visual_controller.gd
git commit -m "fix: restore fighter thruster baseline"
```

---

### Task 2: Split Pilot and Assisted Flight Telemetry

**Files:**
- Modify: `src/flight/flight_output.gd`
- Modify: `src/flight/flight_model.gd`
- Modify: `src/player/ship_flight_controller.gd`
- Modify: `tests/unit/test_flight_model.gd`
- Modify: `tests/unit/test_ship_flight_controller_state.gd`

**Interfaces:**
- Consumes: `FlightCommand`, `FlightTuning`, local linear/angular velocity, body mass.
- Produces:
  - `FlightOutput.pilot_force_local: Vector3`
  - `FlightOutput.pilot_torque_local: Vector3`
  - `FlightOutput.assist_force_local: Vector3`
  - `FlightOutput.assist_torque_local: Vector3`
  - `FlightOutput.force_local: Vector3`
  - `FlightOutput.torque_local: Vector3`
  - `ShipFlightController.get_last_command() -> FlightCommand`
  - four split telemetry getters.

- [ ] **Step 1: Write failing split-output tests**

Add to `tests/unit/test_flight_model.gd`:

```gdscript
var coasting_assisted := FlightCommand.new()
coasting_assisted.mode = FlightMode.Value.ASSISTED
var split := FlightModel.compute(
    coasting_assisted,
    tuning,
    Vector3(12.0, -3.0, -80.0),
    Vector3(0.2, -0.4, 0.1),
    8500.0
)
assert_equal(
    split.pilot_force_local,
    Vector3.ZERO,
    "coasting must produce zero pilot force"
)
assert_equal(
    split.pilot_torque_local,
    Vector3.ZERO,
    "coasting must produce zero pilot torque"
)
assert_true(
    split.assist_force_local.length() > 0.0,
    "assisted drift correction must be isolated"
)
assert_true(
    split.assist_torque_local.length() > 0.0,
    "assisted angular damping must be isolated"
)
assert_equal(
    split.force_local,
    split.pilot_force_local + split.assist_force_local,
    "total force must equal split contributions"
)
assert_equal(
    split.torque_local,
    split.pilot_torque_local + split.assist_torque_local,
    "total torque must equal split contributions"
)
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& "C:\Tools\Godot\godot.cmd" --headless --path . --script res://tests/test_runner.gd
```

Expected: parser/property failures for the four new split fields.

- [ ] **Step 3: Add split fields to `FlightOutput`**

Replace `src/flight/flight_output.gd` with:

```gdscript
class_name FlightOutput
extends RefCounted

var pilot_force_local := Vector3.ZERO
var pilot_torque_local := Vector3.ZERO
var assist_force_local := Vector3.ZERO
var assist_torque_local := Vector3.ZERO
var force_local := Vector3.ZERO
var torque_local := Vector3.ZERO

func finalize_totals() -> void:
    force_local = pilot_force_local + assist_force_local
    torque_local = pilot_torque_local + assist_torque_local
```

- [ ] **Step 4: Refactor `FlightModel.compute` without changing physics totals**

Assign speed-envelope output to `pilot_force_local`, direct rotation to `pilot_torque_local`, all damping/steering corrections to assisted fields, then call `output.finalize_totals()` exactly once before returning.

Required structure:

```gdscript
output.pilot_force_local = FlightSpeedEnvelope.apply_to_force(...)
output.pilot_torque_local = Vector3(...)

if command.mode == FlightMode.Value.ASSISTED:
    output.assist_force_local.x -= ...
    output.assist_force_local.y -= ...
    output.assist_force_local += FlightSteeringMath.assisted_force(...)
    output.assist_torque_local -= local_angular_velocity * tuning.assist_angular_damping

output.finalize_totals()
return output
```

- [ ] **Step 5: Store and expose the sampled command and split telemetry**

Add controller state:

```gdscript
var _last_command := FlightCommand.new()
var _last_pilot_force_local := Vector3.ZERO
var _last_pilot_torque_local := Vector3.ZERO
var _last_assist_force_local := Vector3.ZERO
var _last_assist_torque_local := Vector3.ZERO
```

After all command modifications and before `FlightModel.compute`, copy the command:

```gdscript
_last_command = command.duplicate_command()
```

Add `FlightCommand.duplicate_command() -> FlightCommand` to `src/flight/flight_command.gd` if absent:

```gdscript
func duplicate_command() -> FlightCommand:
    var copy := FlightCommand.new()
    copy.mode = mode
    copy.translation = translation
    copy.rotation = rotation
    copy.boost = boost
    return copy
```

Store each split output and expose:

```gdscript
func get_last_command() -> FlightCommand:
    return _last_command.duplicate_command()

func get_last_pilot_force_local() -> Vector3:
    return _last_pilot_force_local

func get_last_pilot_torque_local() -> Vector3:
    return _last_pilot_torque_local

func get_last_assist_force_local() -> Vector3:
    return _last_assist_force_local

func get_last_assist_torque_local() -> Vector3:
    return _last_assist_torque_local
```

Reset all fields in `reset_runtime_state()`.

- [ ] **Step 6: Run all Godot suites**

Expected: existing physics total assertions remain green and new split assertions pass.

- [ ] **Step 7: Commit split telemetry**

```powershell
git add src/flight/flight_command.gd `
  src/flight/flight_output.gd `
  src/flight/flight_model.gd `
  src/player/ship_flight_controller.gd `
  tests/unit/test_flight_model.gd `
  tests/unit/test_ship_flight_controller_state.gd
git commit -m "feat: split pilot and assisted flight telemetry"
```

---

### Task 3: Generate and Check In the Deterministic Action Matrix

**Files:**
- Create: `src/player/thruster_action.gd`
- Create: `src/player/thruster_action_matrix.gd`
- Create: `tools/assets/generate_fighter_thruster_action_matrix.py`
- Create: `tools/assets/fighter_thruster_action_contract.py`
- Create: `config/ships/small_sci_fi_fighter_thruster_actions.json`
- Create: `tests/tools/test_fighter_thruster_action_contract.py`
- Create: `tests/unit/test_thruster_action_matrix.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: schema-4 manifest socket records with semantic path, position, reaction direction, and capacity.
- Produces:
  - `ThrusterAction.Value` enum for twelve actions.
  - `ThrusterAction.target_force(action) -> Vector3`.
  - `ThrusterAction.target_torque(action) -> Vector3`.
  - `ThrusterActionMatrix.load_checked_in(path: String) -> ThrusterActionMatrix`.
  - `ThrusterActionMatrix.intensities_for(command: FlightCommand) -> Dictionary[StringName, float]`.

- [ ] **Step 1: Define the exact action enum and targets in a failing unit test**

Create `tests/unit/test_thruster_action_matrix.gd` asserting:

```gdscript
assert_equal(ThrusterAction.action_count(), 12, "matrix must cover twelve actions")
assert_equal(
    ThrusterAction.target_force(ThrusterAction.Value.FORWARD),
    Vector3.FORWARD,
    "forward target"
)
assert_equal(
    ThrusterAction.target_force(ThrusterAction.Value.REVERSE),
    Vector3.BACK,
    "reverse target"
)
assert_equal(
    ThrusterAction.target_torque(ThrusterAction.Value.PITCH_UP),
    Vector3.RIGHT,
    "positive local X torque is pitch up"
)
assert_equal(
    ThrusterAction.target_torque(ThrusterAction.Value.YAW_LEFT),
    Vector3.UP,
    "positive local Y torque is yaw left"
)
assert_equal(
    ThrusterAction.target_torque(ThrusterAction.Value.ROLL_LEFT),
    Vector3.BACK,
    "positive local Z torque is roll left"
)
```

- [ ] **Step 2: Implement `ThrusterAction`**

Use this enum order so JSON and GDScript remain stable:

```gdscript
enum Value {
    FORWARD,
    REVERSE,
    STRAFE_LEFT,
    STRAFE_RIGHT,
    STRAFE_UP,
    STRAFE_DOWN,
    PITCH_UP,
    PITCH_DOWN,
    YAW_LEFT,
    YAW_RIGHT,
    ROLL_LEFT,
    ROLL_RIGHT,
}
```

Implement `name_of`, `target_force`, `target_torque`, and `action_count` with explicit `match` statements.

- [ ] **Step 3: Write the Python fixture contract first**

Create `tests/tools/test_fighter_thruster_action_contract.py` with a fixture containing twelve semantic actions. Each entry must contain:

```json
{
  "action": "forward",
  "weights": {
    "Thrusters/Main/MainLeft": 1.0,
    "Thrusters/Main/MainRight": 1.0
  },
  "result_force": [0.0, 0.0, -1.0],
  "result_torque": [0.0, 0.0, 0.0],
  "alignment": 1.0,
  "cross_axis_ratio": 0.0
}
```

Tests must reject:

- missing action;
- duplicate action;
- unknown socket path;
- zero or negative weight;
- alignment below `0.85`;
- cross-axis ratio above `0.35`;
- selected contribution with the wrong requested sign;
- runtime matrix generation markers such as `generated_at_runtime: true`.

- [ ] **Step 4: Implement the deterministic offline generator**

`generate_fighter_thruster_action_matrix.py` must:

1. Read schema-4 `sockets`.
2. Build each socket wrench:

```python
force = normalize(reaction_direction) * capacity
torque = cross(position, force)
```

3. Enumerate socket subsets of size `1..4` in sorted semantic-path order.
4. For each subset, solve non-negative weights with 64 projected coordinate-descent passes.
5. Score candidates with:

```python
score = residual_length + cross_axis_ratio * 0.5 + len(subset) * 0.002
```

6. Accept only candidates with target-axis alignment `>= 0.85`, cross-axis ratio `<= 0.35`, and no opposite target-axis contribution.
7. Break equal scores lexicographically by sorted socket paths.
8. Write stable sorted JSON with `schema_version: 1`, `runtime_generated: false`, source manifest SHA-256, socket capability digest, and all twelve actions.

- [ ] **Step 5: Implement Python validation and generate the real checked-in matrix**

Run:

```powershell
python .\tools\assets\generate_fighter_thruster_action_matrix.py `
  --manifest .\assets\runtime\ships\player\small_sci_fi_fighter.manifest.json `
  --output .\config\ships\small_sci_fi_fighter_thruster_actions.json

python .\tools\assets\fighter_thruster_action_contract.py `
  --manifest .\assets\runtime\ships\player\small_sci_fi_fighter.manifest.json `
  --matrix .\config\ships\small_sci_fi_fighter_thruster_actions.json
```

Expected: twelve valid action records. If the current schema-3 manifest lacks required schema-4 fields, keep the fixture tests green and defer real generation to Task 6; do not invent mappings manually.

- [ ] **Step 6: Implement the Godot matrix loader**

`ThrusterActionMatrix.load_checked_in` must reject absent/invalid JSON and expose immutable dictionaries. `intensities_for(command)` combines positive/negative axes by `max`, never by iterative solving:

```gdscript
var output: Dictionary[StringName, float] = {}
_apply_action(output, ThrusterAction.Value.FORWARD, maxf(-command.translation.z, 0.0))
_apply_action(output, ThrusterAction.Value.REVERSE, maxf(command.translation.z, 0.0))
_apply_action(output, ThrusterAction.Value.STRAFE_LEFT, maxf(-command.translation.x, 0.0))
_apply_action(output, ThrusterAction.Value.STRAFE_RIGHT, maxf(command.translation.x, 0.0))
_apply_action(output, ThrusterAction.Value.STRAFE_UP, maxf(command.translation.y, 0.0))
_apply_action(output, ThrusterAction.Value.STRAFE_DOWN, maxf(-command.translation.y, 0.0))
_apply_action(output, ThrusterAction.Value.PITCH_UP, maxf(command.rotation.x, 0.0))
_apply_action(output, ThrusterAction.Value.PITCH_DOWN, maxf(-command.rotation.x, 0.0))
_apply_action(output, ThrusterAction.Value.YAW_LEFT, maxf(command.rotation.y, 0.0))
_apply_action(output, ThrusterAction.Value.YAW_RIGHT, maxf(-command.rotation.y, 0.0))
_apply_action(output, ThrusterAction.Value.ROLL_LEFT, maxf(command.rotation.z, 0.0))
_apply_action(output, ThrusterAction.Value.ROLL_RIGHT, maxf(-command.rotation.z, 0.0))
```

- [ ] **Step 7: Register and run unit/tool tests**

Add `res://tests/unit/test_thruster_action_matrix.gd` to `tests/test_runner.gd`. Run Python and Godot focused suites.

- [ ] **Step 8: Commit the deterministic mapping subsystem**

```powershell
git add src/player/thruster_action.gd `
  src/player/thruster_action_matrix.gd `
  tools/assets/generate_fighter_thruster_action_matrix.py `
  tools/assets/fighter_thruster_action_contract.py `
  config/ships/small_sci_fi_fighter_thruster_actions.json `
  tests/tools/test_fighter_thruster_action_contract.py `
  tests/unit/test_thruster_action_matrix.gd `
  tests/test_runner.gd
git commit -m "feat: add validated fighter thruster action matrix"
```

---

### Task 4: Implement Dual-Channel Mixing and Smootherstep Envelopes

**Files:**
- Create: `src/player/thruster_visual_math.gd`
- Create: `tests/unit/test_thruster_visual_math.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces:
  - `ThrusterVisualMath.merge_target(direct: float, assist_raw: float) -> float`.
  - `ThrusterVisualMath.advance(current: float, target: float, delta: float, rise_seconds: float, fall_seconds: float) -> float`.
  - `ThrusterVisualMath.smootherstep(value: float) -> float`.
  - `ThrusterVisualMath.scale_for(envelope: float, exhaust_axis: Vector3) -> Vector3`.
  - `ThrusterVisualMath.opacity_for(envelope: float) -> float`.
  - `ThrusterVisualMath.emission_for(envelope: float) -> float`.

- [ ] **Step 1: Write failing pure-math tests**

Create tests asserting:

```gdscript
assert_equal(
    ThrusterVisualMath.merge_target(0.0, 1.0),
    0.35,
    "assist must be capped exactly once"
)
assert_equal(
    ThrusterVisualMath.merge_target(0.7, 1.0),
    0.7,
    "direct output must dominate assist"
)
assert_equal(
    ThrusterVisualMath.merge_target(0.0, 0.0),
    0.0,
    "idle remains idle"
)

var rising := 0.0
for _index: int in range(14):
    var next := ThrusterVisualMath.advance(rising, 1.0, 1.0 / 60.0, 0.22, 0.22)
    assert_true(next >= rising, "rise must be monotonic")
    rising = next
assert_true(rising > 0.95, "direct rise reaches full output near 0.22 seconds")

var falling := 1.0
for _index: int in range(14):
    var next := ThrusterVisualMath.advance(falling, 0.0, 1.0 / 60.0, 0.22, 0.22)
    assert_true(next <= falling, "fall must be monotonic")
    falling = next
assert_true(falling < 0.05, "direct fall reaches zero near 0.22 seconds")
```

Also assert endpoint scales, `opacity = e * e`, `emission = e * e * e`, and boost does not change zero output.

- [ ] **Step 2: Implement exact pure math**

Use:

```gdscript
const ASSIST_VISUAL_CAP := 0.35

static func merge_target(direct: float, assist_raw: float) -> float:
    return maxf(
        clampf(direct, 0.0, 1.0),
        clampf(assist_raw, 0.0, 1.0) * ASSIST_VISUAL_CAP
    )

static func smootherstep(value: float) -> float:
    var x := clampf(value, 0.0, 1.0)
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

static func advance(
    current: float,
    target: float,
    delta: float,
    rise_seconds: float,
    fall_seconds: float
) -> float:
    var duration := rise_seconds if target > current else fall_seconds
    if duration <= 0.0:
        return clampf(target, 0.0, 1.0)
    return move_toward(current, clampf(target, 0.0, 1.0), delta / duration)
```

`scale_for` must scale along the manifest-declared local exhaust axis and use radius scale on the two perpendicular axes; do not assume local Z until schema 4 records the axis.

- [ ] **Step 3: Run tests and commit**

```powershell
git add src/player/thruster_visual_math.gd `
  tests/unit/test_thruster_visual_math.gd `
  tests/test_runner.gd
git commit -m "feat: add dual-channel thruster envelope math"
```

---

### Task 5: Build Schema-4 Nozzle-Local Source Geometry

**Files:**
- Modify: `tools/assets/source_exact_thruster_geometry.py`
- Create: `tools/assets/export_small_sci_fi_fighter_v4.py`
- Create: `tools/assets/canonical_fighter_contract_v4.py`
- Create: `tests/tools/test_canonical_fighter_v4.py`
- Modify: `tests/tools/test_source_exact_thruster_geometry.py`

**Interfaces:**
- Consumes: exact evaluated `EngineFire*` faces/vertices, calibrated socket records, canonical hull frame.
- Produces schema-4 `thruster_effects` records containing:
  - `path`
  - `socket_path`
  - `class`
  - `source_object`
  - `source_component_indices`
  - `vertex_count`
  - `face_count`
  - `geometry_sha256`
  - `node_transform_basis`
  - `node_transform_origin`
  - `local_exhaust_axis`
  - `local_bounds_min`
  - `local_bounds_max`
  - `maximum_reconstruction_error_m`
  - `source_exact_geometry: true`.

- [ ] **Step 1: Write schema-4 fixture tests**

`tests/tools/test_canonical_fighter_v4.py` must reject:

- schema version other than `4`;
- missing `socket_path`;
- missing transform origin/basis;
- non-orthonormal basis;
- invalid local exhaust axis;
- reconstruction error over `0.0001`;
- twelve effect paths not matching twelve socket paths one-to-one;
- `procedural_exhaust_geometry != false`;
- `thruster_visual_strategy != "source_exact_nozzle_local_enginefire_geometry"`.

- [ ] **Step 2: Write a pure nozzle-local reconstruction test**

Extend `tests/tools/test_source_exact_thruster_geometry.py` with:

```python
canonical = [(2.0, 3.0, 4.0), (2.0, 3.0, 6.0)]
origin = (2.0, 3.0, 4.0)
basis_rows = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
local = canonical_vertices_to_nozzle_local(canonical, origin, basis_rows)
reconstructed = reconstruct_canonical_vertices(local, origin, basis_rows)
self.assertLess(max_vertex_error(canonical, reconstructed), 1e-9)
```

- [ ] **Step 3: Implement nozzle-local conversion**

For each effect record:

```python
socket_transform = Matrix.Translation(socket.position_blender) @ socket.basis_blender
inverse_socket = socket_transform.inverted_safe()
local_vertices = [inverse_socket @ vertex for vertex in canonical_vertices]
reconstructed = [socket_transform @ vertex for vertex in local_vertices]
maximum_error = max((a - b).length for a, b in zip(canonical_vertices, reconstructed))
if maximum_error > 0.0001:
    raise RuntimeError(...)
```

Create the mesh from `local_vertices`, parent it under its semantic effect group, and assign the socket transform to the effect node. The effect node is no longer required to have identity transform.

- [ ] **Step 4: Create the schema-4 orchestrator and validator**

Base v4 on the proven v3 hull/socket exporter, but write only schema 4. Keep source SHA checks, canonical dimensions, source component digests, and transaction safety.

- [ ] **Step 5: Run Python tests**

```powershell
python -m unittest `
  tests.tools.test_source_exact_thruster_geometry `
  tests.tools.test_canonical_fighter_v4 `
  -v
```

Expected: all pure tests pass before Blender execution.

- [ ] **Step 6: Commit schema-4 source changes**

```powershell
git add tools/assets/source_exact_thruster_geometry.py `
  tools/assets/export_small_sci_fi_fighter_v4.py `
  tools/assets/canonical_fighter_contract_v4.py `
  tests/tools/test_source_exact_thruster_geometry.py `
  tests/tools/test_canonical_fighter_v4.py
git commit -m "feat: add nozzle-local schema four fighter export"
```

---

### Task 6: Integrate Schema 4 with Transactional Export and Matrix Generation

**Files:**
- Modify: `tools/assets/export-small-fighter.ps1`
- Modify: `tools/verify/verify.ps1`
- Modify: `tools/verify/verify.sh`
- Modify: `tests/tools/test_verify_scripts.py`
- Generate locally: `assets/runtime/ships/player/small_sci_fi_fighter.glb`
- Generate locally: `assets/runtime/ships/player/small_sci_fi_fighter.manifest.json`
- Generate locally: `config/ships/small_sci_fi_fighter_thruster_actions.json`

**Interfaces:**
- Consumes: v4 exporter/validator and matrix generator/contract.
- Produces: one atomic publication unit consisting of GLB, manifest, and checked-in action matrix.

- [ ] **Step 1: Write failing wrapper-order tests**

Extend `tests/tools/test_verify_scripts.py` to require this order:

```text
Blender pending export
schema-4 fighter validation
pending action-matrix generation
pending action-matrix validation
publish GLB
publish manifest
publish matrix
```

Assert that the wrapper references `export_small_sci_fi_fighter_v4.py`, `canonical_fighter_contract_v4.py`, and pending matrix filename `small_sci_fi_fighter_thruster_actions.pending.json`.

- [ ] **Step 2: Update transactional wrapper**

Use pending paths for all three outputs. On any failure, delete pending files and preserve all live files. Publish only after both validators return zero.

- [ ] **Step 3: Update both verifiers**

Before Godot starts, require:

```text
manifest.schema_version == 4
thruster_visual_strategy == source_exact_nozzle_local_enginefire_geometry
len(thruster_effects) == 12
maximum reconstruction error <= 0.0001
matrix schema_version == 1
runtime_generated == false
all twelve actions present
```

- [ ] **Step 4: Run Python wrapper tests**

```powershell
python -m unittest `
  tests.tools.test_verify_scripts `
  tests.tools.test_canonical_fighter_v4 `
  tests.tools.test_fighter_thruster_action_contract `
  -v
```

- [ ] **Step 5: Run the actual Blender export**

```powershell
.\tools\assets\export-small-fighter.ps1
```

Required ending:

```text
Schema-4 nozzle-local fighter contract validation passed.
Fighter thruster action matrix contract validation passed.
Published validated assets:
```

- [ ] **Step 6: Commit scripts, generated matrix, and generated runtime assets**

```powershell
git add tools/assets/export-small-fighter.ps1 `
  tools/verify/verify.ps1 `
  tools/verify/verify.sh `
  tests/tools/test_verify_scripts.py `
  config/ships/small_sci_fi_fighter_thruster_actions.json `
  assets/runtime/ships/player/small_sci_fi_fighter.glb `
  assets/runtime/ships/player/small_sci_fi_fighter.manifest.json
git commit -m "feat: publish schema four fighter thruster assets"
```

---

### Task 7: Replace the Runtime Allocator with the Deterministic Dual-Channel Controller

**Files:**
- Modify: `src/player/ship_thruster_visual_controller.gd`
- Delete: `src/player/ship_thruster_allocator.gd`
- Delete or replace: `tests/unit/test_ship_thruster_allocator.gd`
- Modify: `tests/integration/test_ship_thruster_visual_controller.gd`
- Modify: `tests/integration/test_hero_ship_asset.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Consumes: `ShipFlightController.get_last_command`, split assisted telemetry, `ThrusterActionMatrix`, and twelve schema-4 effect records.
- Produces runtime per-thruster state with direct target, raw assist target, merged target, envelope, and visible output.

- [ ] **Step 1: Write failing direct/assist integration tests**

Add controller test hooks:

```gdscript
visual_controller.set_test_command(command)
visual_controller.set_test_assist_wrench(force, torque)
visual_controller.step_visuals(1.0 / 60.0)
```

Test these behaviors:

```gdscript
var coast := FlightCommand.new()
visual_controller.set_test_command(coast)
visual_controller.set_test_assist_wrench(Vector3.ZERO, Vector3.ZERO)
visual_controller.step_visuals(0.25)
assert_true(visual_controller.are_all_effects_hidden(), "coasting remains dark")

var forward := FlightCommand.new()
forward.translation = Vector3.FORWARD
visual_controller.set_test_command(forward)
visual_controller.step_visuals(0.25)
assert_equal(
    visual_controller.get_active_effect_paths(),
    PackedStringArray([
        "ThrusterEffects/MainEffects/MainLeftEffect",
        "ThrusterEffects/MainEffects/MainRightEffect",
    ]),
    "forward must use only approved main effects"
)
```

For assisted-only output, assert each final target is `<= 0.35` and visible emission is lower than direct output.

- [ ] **Step 2: Replace allocator state with action-matrix state**

Controller initialization must load:

```gdscript
const ACTION_MATRIX_PATH := "res://config/ships/small_sci_fi_fighter_thruster_actions.json"
var _action_matrix: ThrusterActionMatrix
var _direct_targets: Dictionary[StringName, float] = {}
var _assist_targets: Dictionary[StringName, float] = {}
var _envelopes: Dictionary[StringName, float] = {}
```

Reject the system if matrix validation or semantic path matching fails.

- [ ] **Step 3: Map assisted wrench deterministically**

Do not reuse velocity or total force. Convert split assisted force/torque signs into an artificial `FlightCommand` using normalized references:

```gdscript
var assist_command := FlightCommand.new()
assist_command.translation = Vector3(
    assist_force.x / force_reference,
    assist_force.y / force_reference,
    assist_force.z / force_reference
).clamp(Vector3(-1.0, -1.0, -1.0), Vector3.ONE)
assist_command.rotation = Vector3(
    assist_torque.x / torque_reference,
    assist_torque.y / torque_reference,
    assist_torque.z / torque_reference
).clamp(Vector3(-1.0, -1.0, -1.0), Vector3.ONE)
```

Feed this command through the same checked-in matrix, then apply the 35% cap only in `ThrusterVisualMath.merge_target`.

- [ ] **Step 4: Apply nozzle-local envelope output**

For every effect:

1. Read direct and raw assist targets.
2. Merge target.
3. Advance envelope with direct timings when direct target is nonzero, otherwise assisted timings when assist is nonzero.
4. Set scale through `ThrusterVisualMath.scale_for` around the imported nozzle-local node pivot.
5. Set alpha/emission from envelope.
6. Hide below `0.001`.
7. Apply boost multiplier only when direct target is nonzero and class is main/retro.

- [ ] **Step 5: Add introspection required by tests/calibration**

Expose:

```gdscript
func get_active_effect_paths() -> PackedStringArray
func get_direct_target(path: StringName) -> float
func get_assist_target(path: StringName) -> float
func get_merged_target(path: StringName) -> float
func get_envelope(path: StringName) -> float
func get_thruster_report() -> Array[Dictionary]
func step_visuals(delta: float) -> void
```

`get_thruster_report` entries must include semantic path, force contribution, torque contribution, direct, assist, merged, and envelope.

- [ ] **Step 6: Delete the free-form allocator**

Remove `ship_thruster_allocator.gd`, remove its suite from `tests/test_runner.gd`, and replace it with the new matrix/math suites. Search for `ShipThrusterAllocator` and require zero remaining results.

- [ ] **Step 7: Run all Godot suites and commit**

```powershell
git add src/player/ship_thruster_visual_controller.gd `
  src/player/ship_thruster_allocator.gd `
  tests/unit/test_ship_thruster_allocator.gd `
  tests/integration/test_ship_thruster_visual_controller.gd `
  tests/integration/test_hero_ship_asset.gd `
  tests/test_runner.gd
git commit -m "feat: drive fighter effects from deterministic dual channels"
```

---

### Task 8: Add the Development Calibration Scene

**Files:**
- Create: `scenes/debug/thruster_calibration.tscn`
- Create: `src/debug/thruster_calibration.gd`
- Create: `tests/integration/test_thruster_calibration_scene.gd`
- Modify: `tests/test_runner.gd`
- Modify: `README.md`

**Interfaces:**
- Consumes: production `player_interceptor.tscn`, `ThrusterAction`, and `ShipThrusterVisualController.get_thruster_report`.
- Produces: a development-only scene that cycles one action at a time without changing production mappings.

- [ ] **Step 1: Write a failing scene contract test**

The test must load `res://scenes/debug/thruster_calibration.tscn` and assert:

- one `PlayerInterceptor` instance;
- one action selector;
- one report label;
- all twelve direct actions are selectable;
- assisted translation and assisted rotation cases are selectable;
- production action-matrix path is used;
- no second mapping table exists in the debug script.

- [ ] **Step 2: Create calibration controller**

Use an enum-like case list:

```gdscript
const CASES: Array[StringName] = [
    &"forward", &"reverse",
    &"strafe_left", &"strafe_right",
    &"strafe_up", &"strafe_down",
    &"pitch_up", &"pitch_down",
    &"yaw_left", &"yaw_right",
    &"roll_left", &"roll_right",
    &"assist_translation", &"assist_rotation",
]
```

Left/Right changes case; Space toggles output; Escape exits. The script builds a `FlightCommand` or assisted wrench and calls the production controller test/debug injection interface.

- [ ] **Step 3: Render a deterministic text report**

For each active thruster print:

```text
path
force=(x,y,z)
torque=(x,y,z)
direct=0.000
assist=0.000
merged=0.000
envelope=0.000
```

Sort rows by semantic path.

- [ ] **Step 4: Register the integration test and document launch command**

README command:

```powershell
godot --path . res://scenes/debug/thruster_calibration.tscn
```

- [ ] **Step 5: Run suite and commit**

```powershell
git add scenes/debug/thruster_calibration.tscn `
  src/debug/thruster_calibration.gd `
  tests/integration/test_thruster_calibration_scene.gd `
  tests/test_runner.gd `
  README.md
git commit -m "feat: add fighter thruster calibration scene"
```

---

### Task 9: Final Verification, Manual Calibration, and Roadmap Return

**Files:**
- Modify only when failures prove necessary: files from Tasks 1–8.
- Update: `README.md` acceptance status after successful verification.

**Interfaces:**
- Produces the acceptance evidence for leaving the dedicated thruster phase.

- [ ] **Step 1: Run every Python contract suite**

```powershell
python -m unittest `
  tests.tools.test_small_fighter_calibration `
  tests.tools.test_fighter_socket_names `
  tests.tools.test_source_exact_thruster_geometry `
  tests.tools.test_canonical_fighter_v4 `
  tests.tools.test_fighter_thruster_action_contract `
  tests.tools.test_verify_scripts `
  tests.tools.test_asteroid_pack `
  -v
```

Expected: all pass.

- [ ] **Step 2: Run the complete Windows verifier**

```powershell
.\tools\verify\verify.ps1
```

Expected:

- schema-4 and matrix preflight pass;
- Godot import exits zero;
- all registered suites pass;
- main scene boots without hierarchy, parser, path, or runtime errors.

- [ ] **Step 3: Run calibration scene through all fourteen cases**

```powershell
godot --path . res://scenes/debug/thruster_calibration.tscn
```

For each case, verify the reported active set and visible set match, force/torque sign is correct, and assisted cases remain visibly dimmer.

- [ ] **Step 4: Run manual flight acceptance**

Verify:

1. Accelerate, release input, and coast: direct exhaust decays to invisible while velocity remains.
2. Hold each translation control independently: only its matrix effects appear.
3. Hold pitch/yaw/roll independently: correct maneuvering effects appear and all expected thrusters participate.
4. Assisted mode with drift and no input: dim corrective jets appear.
5. Manual mode with drift and no input: no correction jets appear.
6. Boost without translation: no exhaust appears.
7. Boost with forward/reverse: only already-active main/retro effects brighten/extend.
8. Every plume remains attached to its nozzle through rise and fall.

- [ ] **Step 5: Commit verification documentation**

After actual success, update README with the exact suite count and schema-4 status, then:

```powershell
git add README.md
git commit -m "docs: record verified fighter thruster milestone"
```

- [ ] **Step 6: Push branch and return to master roadmap**

```powershell
git push origin agent/playable-flight-room
```

Do not continue asteroid composition, additional models, combat, or environment polish until this acceptance gate is complete. Once complete, resume the existing Shattered Orbit roadmap at the next planned gameplay/environment phase rather than adding more flight-room refinements.
