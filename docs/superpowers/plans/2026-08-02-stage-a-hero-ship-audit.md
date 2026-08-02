# Stage A Hero Ship Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one non-destructive Blender audit command that produces eight orientation renders and a validated structural JSON report for the preserved Small Sci-Fi Fighter source.

**Architecture:** Keep Blender-specific scene inspection and rendering inside one headless Blender Python script. Put output names, SHA-256 helpers, and report validation in a separate standard-library Python module so the contract is testable without Blender. A PowerShell wrapper resolves Blender, snapshots the source hash before and after execution, invokes the audit, runs the validator, and fails if any artifact is missing, empty, inconsistent, or if the source changed.

**Tech Stack:** Blender 5.x Python API, Python 3 standard library, PowerShell, `unittest`, Git.

## Global Constraints

- Work only on `agent/playable-flight-room`.
- Stage A must not modify the runtime GLB, player scene, collider, flight controller, camera, or thruster implementation.
- Preserved source: `assets/source/ships/player_candidates/small_sci_fi_fighter/Small Sci-Fi Fighter.blend`.
- Audit output directory: `artifacts/hero_ship_audit/`.
- Required images: `front.png`, `rear.png`, `left.png`, `right.png`, `top.png`, `bottom.png`, `perspective_front.png`, `perspective_rear.png`.
- Required report: `ship_audit.json`.
- The source `.blend` SHA-256 must be identical before and after the audit.
- The audit must never call `bpy.ops.wm.save_*`, overwrite the source, or export a replacement GLB.
- The report must not claim a nose direction, top direction, canonical scale, or thruster role. Those are Stage B calibration decisions based on the audit evidence.
- All renders use a neutral background, consistent lighting, visible bounds, object origin, axis legend, dimensions, view label, and source SHA.
- Use local tooling only. Do not add or trigger GitHub Actions.

---

## File Map

### Create

- `tools/assets/hero_ship_audit_contract.py` — shared artifact names, file hashing, report validation, and CLI entry point.
- `tests/tools/test_hero_ship_audit_contract.py` — standard-library unit tests for the audit contract.
- `tools/assets/audit_small_sci_fi_fighter.py` — Blender-only scene inspection, overlay construction, rendering, and JSON generation.
- `tools/assets/audit-small-fighter.ps1` — Windows entry point, Blender discovery, source immutability guard, and validator invocation.

### Modify

- `README.md` — document the Stage A audit command and generated evidence.

### Generated Locally, Then Pushed for Review

- `artifacts/hero_ship_audit/front.png`
- `artifacts/hero_ship_audit/rear.png`
- `artifacts/hero_ship_audit/left.png`
- `artifacts/hero_ship_audit/right.png`
- `artifacts/hero_ship_audit/top.png`
- `artifacts/hero_ship_audit/bottom.png`
- `artifacts/hero_ship_audit/perspective_front.png`
- `artifacts/hero_ship_audit/perspective_rear.png`
- `artifacts/hero_ship_audit/ship_audit.json`

---

### Task 1: Testable Audit Artifact Contract

**Files:**
- Create: `tools/assets/hero_ship_audit_contract.py`
- Create: `tests/tools/test_hero_ship_audit_contract.py`

**Interfaces:**
- Produces `EXPECTED_RENDER_NAMES: tuple[str, ...]`.
- Produces `sha256_file(path: Path) -> str`.
- Produces `validate_audit_directory(audit_dir: Path, expected_source_sha: str | None = None) -> list[str]`.
- CLI: `python tools/assets/hero_ship_audit_contract.py --audit-dir <path> [--source <blend>]` exits `0` on success and non-zero with one error per line on failure.

- [ ] **Step 1: Write failing contract tests**

Create tests using `tempfile.TemporaryDirectory` and `unittest` for:

```python
class AuditContractTests(unittest.TestCase):
    def test_complete_directory_passes(self): ...
    def test_missing_render_fails(self): ...
    def test_empty_render_fails(self): ...
    def test_report_source_hash_mismatch_fails(self): ...
    def test_report_requires_eight_camera_records(self): ...
    def test_report_rejects_unapproved_orientation_claims(self): ...
```

The valid fixture must write non-empty placeholder PNG bytes and a report containing:

```json
{
  "schema_version": 1,
  "source": {"path": "...Small Sci-Fi Fighter.blend", "sha256": "<64 hex>", "blender_version": "5.2.0"},
  "aggregate_bounds": {"minimum": [0, 0, 0], "maximum": [1, 1, 1], "center": [0.5, 0.5, 0.5], "dimensions": [1, 1, 1]},
  "objects": [],
  "materials": [],
  "empties": [],
  "candidate_nozzle_names": [],
  "renders": {
    "front": {"file": "front.png", "camera_location": [0, -5, 0], "view_direction": [0, 1, 0], "projection": "ORTHO"}
  }
}
```

Fill all eight render records. Explicitly reject top-level keys named `confirmed_nose`, `confirmed_up`, `canonical_dimensions`, or `thruster_roles`.

- [ ] **Step 2: Run tests and verify RED**

```powershell
python .\tests\tools\test_hero_ship_audit_contract.py
```

Expected: import failure because `hero_ship_audit_contract.py` does not exist.

- [ ] **Step 3: Implement the minimal contract module**

Validation must check:

1. all eight image files exist and are non-empty;
2. `ship_audit.json` exists, parses, and has `schema_version == 1`;
3. source SHA is exactly 64 lowercase hexadecimal characters;
4. optional expected source SHA matches the report;
5. aggregate bounds contain finite 3-element vectors and positive dimensions;
6. `objects`, `materials`, `empties`, and `candidate_nozzle_names` are lists;
7. `renders` contains exactly the eight required view keys;
8. every render record points to the corresponding filename and includes finite camera location, finite view direction, and projection `ORTHO` or `PERSP`;
9. the four forbidden calibration keys are absent.

The CLI uses `argparse`, hashes `--source` when supplied, prints `Hero ship audit contract valid.` on success, and prints each validation error to stderr before returning exit code `1`.

- [ ] **Step 4: Run tests and verify GREEN**

```powershell
python .\tests\tools\test_hero_ship_audit_contract.py
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add tools/assets/hero_ship_audit_contract.py tests/tools/test_hero_ship_audit_contract.py
git commit -m "test: define hero ship audit contract"
```

---

### Task 2: Non-Destructive Blender Audit Renderer

**Files:**
- Create: `tools/assets/audit_small_sci_fi_fighter.py`

**Interfaces:**
- Blender invocation arguments after `--`:
  - `--output-dir <directory>`
  - `--source-sha <64-hex>`
- Produces all files required by `hero_ship_audit_contract.py`.
- Never saves the opened `.blend`.

- [ ] **Step 1: Add a failing static safety test**

Extend `tests/tools/test_hero_ship_audit_contract.py` with:

```python
def test_blender_audit_script_contains_no_save_operation(self):
    script = Path("tools/assets/audit_small_sci_fi_fighter.py").read_text(encoding="utf-8")
    forbidden = ("save_as_mainfile", "save_mainfile", "save_homefile")
    self.assertFalse(any(token in script for token in forbidden))
```

- [ ] **Step 2: Run tests and verify RED**

Expected: file-not-found failure for `audit_small_sci_fi_fighter.py`.

- [ ] **Step 3: Implement argument parsing and source checks**

The Blender script must:

- parse arguments only after Blender's `--` separator;
- resolve `Path(bpy.data.filepath)` as the source;
- calculate the source SHA itself and compare it with `--source-sha`;
- create a fresh output directory, deleting only prior files inside `artifacts/hero_ship_audit/`;
- fail when no visible mesh exists.

- [ ] **Step 4: Collect structural evidence without mutating source data**

Create serializable records for every scene object:

```python
{
  "name": obj.name,
  "type": obj.type,
  "parent": obj.parent.name if obj.parent else None,
  "visible_render": not obj.hide_render,
  "visible_viewport": not obj.hide_get(),
  "matrix_world": [[...], [...], [...], [...]],
  "location": [...],
  "rotation_euler_degrees": [...],
  "scale": [...],
  "dimensions": [...],
  "bound_box_world": [[x, y, z], ...],
  "materials": [...]
}
```

Material records must include name, diffuse color, blend method where available, whether nodes are enabled, node types, and whether any node appears emissive by node type/name/input value.

`candidate_nozzle_names` is only a case-insensitive name scan using tokens:

```text
engine, exhaust, nozzle, thruster, thrust, jet, flame, burner, vent, retro, rcs
```

It must not assign semantic roles.

- [ ] **Step 5: Build an in-memory audit overlay collection**

Create temporary objects only in memory:

- aggregate wireframe bounding box;
- small origin marker at world `(0, 0, 0)`;
- center marker at aggregate bounds center;
- X/Y/Z axis arrows with labels;
- text labels for view name, camera direction, dimensions, and source SHA prefix.

Use materials that remain legible against a neutral dark-gray world. Do not alter source mesh transforms, materials, visibility, modifiers, or hierarchy.

- [ ] **Step 6: Configure consistent cameras and lighting**

Calculate aggregate bounds from visible renderable meshes. Let `radius = max(dimensions) * 0.65` and camera distance be at least `radius * 3.2`.

Use these authoritative world-space views, looking at bounds center:

```python
ORTHOGRAPHIC_VIEWS = {
    "front":  (0, -1, 0),
    "rear":   (0,  1, 0),
    "left":   (-1, 0, 0),
    "right":  (1,  0, 0),
    "top":    (0, 0, 1),
    "bottom": (0, 0, -1),
}
```

The vector is the camera position direction from the bounds center; each camera looks back toward the center. Use `ORTHO` with scale `max(dimensions) * 1.35`.

Use perspective cameras at normalized directions `(1, -1, 0.65)` and `(-1, 1, 0.45)`, with a 50 mm lens.

Use one area key light, one area fill light, and one rim light parented independently from source objects. Render at `1400 x 1000`, PNG RGBA, 100% scale, transparent disabled, and a neutral background.

- [ ] **Step 7: Render all eight views and write JSON**

For each render:

- update the view label;
- set the camera;
- render directly to the exact required filename;
- record camera location, view direction, projection, lens/ortho scale, resolution, and output filename.

Write `ship_audit.json` only after all images exist and are non-empty. The report includes:

- `schema_version`;
- source path, SHA, Blender version;
- aggregate bounds;
- object/material/empty records;
- candidate nozzle names;
- render records;
- explicit note: `"calibration_status": "unconfirmed"`.

Do not include any forbidden confirmed-calibration keys.

- [ ] **Step 8: Run standard-library tests and commit**

```powershell
python .\tests\tools\test_hero_ship_audit_contract.py
```

```bash
git add tools/assets/audit_small_sci_fi_fighter.py tests/tools/test_hero_ship_audit_contract.py
git commit -m "feat: add non-destructive fighter audit renderer"
```

---

### Task 3: PowerShell Audit Entry Point and Immutability Gate

**Files:**
- Create: `tools/assets/audit-small-fighter.ps1`

**Interfaces:**
- Command: `.\tools\assets\audit-small-fighter.ps1 [-BlenderBin <path>]`.
- Reuses Blender discovery behavior from `export-small-fighter.ps1`.
- Runs the Python contract validator after Blender exits.

- [ ] **Step 1: Write wrapper with exact paths**

Resolve:

```text
source:    assets/source/ships/player_candidates/small_sci_fi_fighter/Small Sci-Fi Fighter.blend
script:    tools/assets/audit_small_sci_fi_fighter.py
validator: tools/assets/hero_ship_audit_contract.py
output:    artifacts/hero_ship_audit
```

Support `$env:BLENDER_BIN`, `blender` on PATH, versioned directories under `C:\Program Files\Blender Foundation`, and the same common fallback locations as the exporter wrapper.

- [ ] **Step 2: Add source immutability enforcement**

Before Blender runs:

```powershell
$sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
```

Invoke:

```powershell
& $blenderExecutable `
  --background $sourcePath `
  --python $scriptPath `
  -- `
  --output-dir $outputDirectory `
  --source-sha $sourceHashBefore
```

After Blender exits, calculate the hash again and throw when it differs.

- [ ] **Step 3: Validate generated evidence**

Run:

```powershell
python $validatorPath --audit-dir $outputDirectory --source $sourcePath
```

Throw on non-zero exit. Print the nine generated paths and source SHA on success.

- [ ] **Step 4: Add a PowerShell parser check**

Run:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\tools\assets\audit-small-fighter.ps1),
    [ref]$null,
    [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { $errors | Format-List; exit 1 }
```

Expected: no parser errors.

- [ ] **Step 5: Commit**

```bash
git add tools/assets/audit-small-fighter.ps1
git commit -m "feat: add fighter audit command"
```

---

### Task 4: Documentation and Local Evidence Generation

**Files:**
- Modify: `README.md`
- Generate: `artifacts/hero_ship_audit/*`

**Interfaces:**
- Does not calibrate or export the ship.
- Ends at the review gate with evidence pushed to the branch.

- [ ] **Step 1: Document Stage A command**

Add:

```powershell
.\tools\assets\audit-small-fighter.ps1
```

Explain that it creates eight renders and `ship_audit.json`, verifies the source hash is unchanged, and intentionally does not decide orientation, dimensions, or thruster roles.

- [ ] **Step 2: Run all standard-library tests**

```powershell
python .\tests\tools\test_hero_ship_audit_contract.py
```

Expected: all tests pass.

- [ ] **Step 3: Run the audit locally**

```powershell
.\tools\assets\audit-small-fighter.ps1
```

If Blender is not auto-detected:

```powershell
.\tools\assets\audit-small-fighter.ps1 -BlenderBin "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
```

Required outcome:

- eight non-empty PNG files;
- valid `ship_audit.json`;
- identical pre/post source SHA;
- validator success.

- [ ] **Step 4: Inspect generated evidence before pushing**

Confirm manually:

- all six orthographic views show the full ship without clipping;
- front/rear, left/right, and top/bottom are true opposites;
- perspective views reveal nozzle geometry;
- labels and axis legend are readable;
- bounds and origin markers are visible;
- no render is blank or fully transparent.

Do not decide orientation or socket roles yet.

- [ ] **Step 5: Commit tooling, docs, and generated evidence**

```bash
git add \
  README.md \
  tools/assets/hero_ship_audit_contract.py \
  tools/assets/audit_small_sci_fi_fighter.py \
  tools/assets/audit-small-fighter.ps1 \
  tests/tools/test_hero_ship_audit_contract.py \
  artifacts/hero_ship_audit

git commit -m "feat: generate canonical fighter audit evidence"
git push
```

- [ ] **Step 6: Stop at the calibration review gate**

Report:

- source SHA;
- Blender version;
- aggregate dimensions and center;
- list of candidate nozzle-related object/material names;
- links/paths to all eight renders and JSON.

Do not implement Stage B until the renders are reviewed and the calibration decision record is approved.

---

## Final Stage A Review Gate

1. Pure contract tests pass with Python standard library only.
2. PowerShell wrapper parses cleanly.
3. Blender runs headlessly against the preserved source.
4. Source SHA remains unchanged.
5. Eight required renders and the JSON report exist and validate.
6. Every render includes consistent orientation evidence and readable overlays.
7. JSON contains structural evidence but no confirmed calibration claims.
8. No runtime GLB, gameplay scene, physics, camera, or thruster code changes occur in Stage A.
9. Generated audit evidence is pushed for visual review.
10. Work stops before canonical export or socket placement.