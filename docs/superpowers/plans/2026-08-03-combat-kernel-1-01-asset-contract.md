# Combat Kernel 1 Phase 1 — Canonical Fighter Muzzle Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. This project is inline-execution only; stop at every local Blender/Godot checkpoint and use the user's pasted output as the source of truth.

**Goal:** Advance the canonical fighter from schema 4 to schema 5 while preserving every accepted thruster guarantee and adding exactly two source-derived primary muzzle nodes.

**Architecture:** Use pure Python geometry-selection tests, Blender boundary-loop extraction, a schema-5 validator, and the existing transactional publication pipeline. The phase ends only after local Blender export and asset-focused Godot verification output are pasted and inspected.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, GL Compatibility, Blender 5.2 LTS, Python 3, PowerShell, custom `TestCase` harness.

## Global Constraints

- Repository: `manbtd0-cloud/Spaceship-Game`.
- Branch: `agent/playable-flight-room`.
- Base: design/spec commit `1d63819e02c194d762ee08f45c038ac10389fdb0` or a descendant.
- Godot 4.7.1 Standard with GL Compatibility.
- Blender 5.2 LTS and Python 3 for canonical asset generation.
- Windows PowerShell is the authoritative local verification environment.
- Inline execution only; do not dispatch subagents.
- Preserve accepted six-axis flight, boost, thermal, Camera C0, canonical fighter identity, twelve thrusters, asteroid field, collision response, reset, and existing HUD.
- No camera-forward fire, convergence, lead, lock, snapping, or aim assistance.
- Never guess or hand-author muzzle transforms.
- Never mutate the preserved Blender source.
- Never publish a partial GLB/manifest/matrix set.
- No GitHub Actions.
- No success claim without fresh user-pasted local output.
- Full verification command: `.\tools\verify\verify.ps1`.

---
### Task 1: Lock the schema-5 muzzle contract with pure Python tests

**Files:**
- Create: `tools/assets/primary_weapon_muzzle_geometry.py`
- Create: `tests/tools/test_primary_weapon_muzzle_geometry.py`
- Rename: `tests/tools/test_canonical_fighter_v4.py` → `tests/tools/test_canonical_fighter_v5.py`
- Rename: `tools/assets/canonical_fighter_contract_v4.py` → `tools/assets/canonical_fighter_contract_v5.py`

**Interfaces:**
- Produces: `MuzzleCandidate`, `MuzzleRecord`, `select_primary_muzzle_pair(candidates)`, `classify_primary_muzzle_path(origin)`.
- Produces: `canonical_fighter_contract_v5.validate_manifest(path, expected_source_sha) -> list[str]`.
- Preserves: every schema-4 socket, effect, geometry digest, basis, source hash, and GLB-node validation.

- [ ] **Step 1: Rename the versioned validator and its test**

```powershell
git mv tools/assets/canonical_fighter_contract_v4.py tools/assets/canonical_fighter_contract_v5.py
git mv tests/tools/test_canonical_fighter_v4.py tests/tools/test_canonical_fighter_v5.py
```

- [ ] **Step 2: Write failing geometry-selection tests**

Create `tests/tools/test_primary_weapon_muzzle_geometry.py` with synthetic candidates that prove all selection rules:

```python
from tools.assets.primary_weapon_muzzle_geometry import (
    MuzzleCandidate,
    classify_primary_muzzle_path,
    select_primary_muzzle_pair,
)


def candidate(
    name: str,
    x: float,
    y: float,
    z: float,
    radius: float = 0.20,
    normal: tuple[float, float, float] = (0.0, 1.0, 0.0),
) -> MuzzleCandidate:
    return MuzzleCandidate(
        source_object=name,
        source_vertex_indices=(1, 2, 3, 4, 5, 6, 7, 8),
        centroid=(x, y, z),
        normal=normal,
        radius=radius,
        planarity_error=0.001,
        circularity_ratio=1.05,
    )


def test_selects_only_forward_symmetric_pair() -> None:
    left = candidate("Hull", -2.0, 10.0, 0.5)
    right = candidate("Hull", 2.0, 10.0, 0.5)
    noise = candidate("Hull", 0.2, 5.0, 0.0)
    selected = select_primary_muzzle_pair([noise, right, left])
    assert selected[0] == left
    assert selected[1] == right


def test_rejects_ambiguous_pairs() -> None:
    pair_a = [
        candidate("Hull", -2.0, 10.0, 0.5),
        candidate("Hull", 2.0, 10.0, 0.5),
    ]
    pair_b = [
        candidate("Hull", -3.0, 10.0, 0.5),
        candidate("Hull", 3.0, 10.0, 0.5),
    ]
    try:
        select_primary_muzzle_pair(pair_a + pair_b)
    except ValueError as error:
        assert "exactly one primary muzzle pair" in str(error)
    else:
        raise AssertionError("ambiguous source geometry must fail closed")


def test_classifies_left_and_right_paths() -> None:
    assert classify_primary_muzzle_path((-1.0, 0.0, 0.0)) == (
        "Weapons/Primary/LeftMuzzle"
    )
    assert classify_primary_muzzle_path((1.0, 0.0, 0.0)) == (
        "Weapons/Primary/RightMuzzle"
    )
```

- [ ] **Step 3: Run the focused tests and verify the expected failure**

Run:

```powershell
python -m unittest tests.tools.test_primary_weapon_muzzle_geometry -v
```

Expected: import failure because `primary_weapon_muzzle_geometry.py` does not exist.

- [ ] **Step 4: Implement the pure geometry contract**

Create `tools/assets/primary_weapon_muzzle_geometry.py` with immutable records and fail-closed selection:

```python
from __future__ import annotations

from dataclasses import dataclass
import math


Point3 = tuple[float, float, float]


@dataclass(frozen=True)
class MuzzleCandidate:
    source_object: str
    source_vertex_indices: tuple[int, ...]
    centroid: Point3
    normal: Point3
    radius: float
    planarity_error: float
    circularity_ratio: float


@dataclass(frozen=True)
class MuzzleRecord:
    path: str
    side: str
    source_object: str
    source_vertex_indices: tuple[int, ...]
    canonical_origin: Point3
    canonical_basis_rows: tuple[Point3, Point3, Point3]
    canonical_forward: Point3
    extraction_error_m: float


def _distance(left: Point3, right: Point3) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def classify_primary_muzzle_path(origin: Point3) -> str:
    if origin[0] < 0.0:
        return "Weapons/Primary/LeftMuzzle"
    if origin[0] > 0.0:
        return "Weapons/Primary/RightMuzzle"
    raise ValueError("primary muzzle cannot lie on the fighter centerline")


def select_primary_muzzle_pair(
    candidates: list[MuzzleCandidate],
) -> tuple[MuzzleCandidate, MuzzleCandidate]:
    valid = [
        item
        for item in candidates
        if len(item.source_vertex_indices) >= 6
        and item.centroid[1] > 0.0
        and abs(item.normal[1]) >= 0.90
        and 0.04 <= item.radius <= 0.60
        and item.planarity_error <= 0.02
        and item.circularity_ratio <= 1.35
        and abs(item.centroid[0]) >= 0.10
    ]
    pairs: list[tuple[MuzzleCandidate, MuzzleCandidate]] = []
    for left in [item for item in valid if item.centroid[0] < 0.0]:
        for right in [item for item in valid if item.centroid[0] > 0.0]:
            mirrored = (
                abs(abs(left.centroid[0]) - abs(right.centroid[0])) <= 0.15
                and abs(left.centroid[1] - right.centroid[1]) <= 0.15
                and abs(left.centroid[2] - right.centroid[2]) <= 0.15
                and abs(left.radius - right.radius)
                <= max(left.radius, right.radius) * 0.10
                and _distance(left.normal, right.normal) <= 0.20
            )
            if mirrored:
                pairs.append((left, right))
    if len(pairs) != 1:
        raise ValueError(
            "expected exactly one primary muzzle pair, "
            f"found {len(pairs)}"
        )
    return pairs[0]
```

- [ ] **Step 5: Convert the validator from schema 4 to schema 5**

In `canonical_fighter_contract_v5.py`:

- change the exact schema assertion to `5`;
- add `EXPECTED_PRIMARY_MUZZLES`:

```python
EXPECTED_PRIMARY_MUZZLES = {
    "Weapons/Primary/LeftMuzzle": "left",
    "Weapons/Primary/RightMuzzle": "right",
}
```

- validate `primary_muzzles` as exactly two unique records;
- validate `path`, `side`, `source_object`, non-empty unique `source_vertex_indices`;
- validate finite `origin`, orthonormal positive-determinant `basis`, unit `forward`;
- require `dot(forward, (0.0, 0.0, -1.0)) >= 0.95`;
- require `0.0 <= extraction_error_m <= 0.0001`;
- validate that both paths exist as GLB nodes;
- retain all existing thruster and effect checks unchanged.

The manifest loop must use this exact result shape:

```python
for index, muzzle in enumerate(primary_muzzles):
    label = f"primary_muzzles[{index}]"
    path_value = str(muzzle.get("path", ""))
    side_value = str(muzzle.get("side", ""))
    expected_side = EXPECTED_PRIMARY_MUZZLES.get(path_value)
    if expected_side is None:
        errors.append(f"{label}.path is unexpected: {path_value!r}")
    elif side_value != expected_side:
        errors.append(
            f"{label}.side must be {expected_side!r}, got {side_value!r}"
        )
```

- [ ] **Step 6: Extend the renamed validator test**

`tests/tools/test_canonical_fighter_v5.py` must prove:

- schema 4 and schema 2 are rejected;
- missing, extra, duplicated, centerline, non-finite, mirrored-wrong, and backward-facing muzzles are rejected;
- valid schema-5 muzzles pass while all schema-4 thruster checks still execute.

- [ ] **Step 7: Run the focused Python tests**

```powershell
python -m unittest `
  tests.tools.test_primary_weapon_muzzle_geometry `
  tests.tools.test_canonical_fighter_v5 `
  -v
```

Expected: all tests pass.

- [ ] **Step 8: Commit the contract foundation**

```powershell
git add `
  tools/assets/primary_weapon_muzzle_geometry.py `
  tools/assets/canonical_fighter_contract_v5.py `
  tests/tools/test_primary_weapon_muzzle_geometry.py `
  tests/tools/test_canonical_fighter_v5.py
git commit -m "test: define schema five muzzle contract"
```

---

### Task 2: Extract source-derived muzzle nodes and publish schema 5 transactionally

**Files:**
- Create: `tools/assets/primary_weapon_muzzle_extraction.py`
- Rename: `tools/assets/export_small_sci_fi_fighter_v4.py` → `tools/assets/export_small_sci_fi_fighter_v5.py`
- Modify: `tools/assets/export-small-fighter.ps1`
- Modify: `tools/verify/verify.ps1`
- Modify: `tests/tools/test_verify_scripts.py`
- Modify through exporter: canonical GLB and manifest

**Interfaces:**
- Consumes: `MuzzleCandidate`, `MuzzleRecord`, `select_primary_muzzle_pair`.
- Produces: `extract_primary_muzzles(source_frame_inverse, hull_center, scale) -> list[MuzzleRecord]`.
- Produces GLB nodes `Weapons/Primary/LeftMuzzle` and `Weapons/Primary/RightMuzzle`.
- Produces manifest collection `primary_muzzles`.

- [ ] **Step 1: Rename the exporter**

```powershell
git mv `
  tools/assets/export_small_sci_fi_fighter_v4.py `
  tools/assets/export_small_sci_fi_fighter_v5.py
```

- [ ] **Step 2: Implement deterministic boundary-loop extraction**

Create `primary_weapon_muzzle_extraction.py`. The Blender-side algorithm must:

1. inspect evaluated, visible, non-`EngineFire` mesh objects before they are joined;
2. transform vertices into the approved `Cube` source frame;
3. find boundary loops from edges used by exactly one polygon;
4. retain loops in the forward 35% of the source hull (`+Y` in Blender source frame);
5. calculate centroid, best-fit normal, planarity error, radial mean, and circularity ratio;
6. pass candidates to `select_primary_muzzle_pair`;
7. orient normals toward source-frame fighter forward `Vector((0, 1, 0))`;
8. convert origins and bases into canonical Godot coordinates;
9. create exact `MuzzleRecord` evidence with source object and source vertex indices;
10. fail if extraction does not yield exactly one mirrored pair.

Use these exact filters before pair selection:

```python
FORWARD_REGION_START = (
    HULL_CENTER_LOCAL[1] + SOURCE_HULL_DIMENSIONS[1] * 0.15
)
MIN_LOOP_VERTICES = 6
MAX_LOOP_VERTICES = 64
MAX_PLANARITY_ERROR_SOURCE = 0.02
MAX_CIRCULARITY_RATIO = 1.35
MIN_RADIUS_SOURCE = 0.04
MAX_RADIUS_SOURCE = 0.60
```

The conversion must use the repository's existing `base.blender_to_godot_vector` and `base.blender_basis_to_godot_rows`; do not create a second coordinate convention.

- [ ] **Step 3: Integrate muzzle nodes into the schema-5 exporter**

In `export_small_sci_fi_fighter_v5.py`:

- import `extract_primary_muzzles`;
- call it before deleting/joining source detail;
- create hierarchy:

```text
SmallSciFiFighter
└── Weapons
    └── Primary
        ├── LeftMuzzle
        └── RightMuzzle
```

- create each muzzle as an empty `Node3D` using the extracted canonical transform;
- preserve all twelve thruster sockets and effect meshes;
- rename `write_schema_four_manifest` to `write_schema_five_manifest`;
- emit `"schema_version": 5`;
- add `"primary_muzzles": [...]`;
- print the two paths and maximum extraction error.

Manifest record shape:

```python
{
    "path": record.path,
    "side": record.side,
    "source_object": record.source_object,
    "source_vertex_indices": list(record.source_vertex_indices),
    "origin": list(record.canonical_origin),
    "basis": [list(row) for row in record.canonical_basis_rows],
    "forward": list(record.canonical_forward),
    "extraction_error_m": record.extraction_error_m,
}
```

- [ ] **Step 4: Update transactional publication scripts**

`tools/assets/export-small-fighter.ps1` must:

- point to `export_small_sci_fi_fighter_v5.py`;
- point to `canonical_fighter_contract_v5.py`;
- label pending output as schema 5;
- validate pending GLB and manifest before publishing;
- generate and validate the unchanged thruster matrix from the pending schema-5 manifest;
- preserve backup/restore behavior;
- never publish only one or two of the three outputs.

`tools/verify/verify.ps1` must:

- require manifest schema exactly `5`;
- verify exactly two muzzle paths;
- still verify the exact 12 socket and 12 effect path sets;
- invoke `canonical_fighter_contract_v5.py`.

- [ ] **Step 5: Update PowerShell script tests**

Extend `tests/tools/test_verify_scripts.py` to assert both scripts reference:

```text
export_small_sci_fi_fighter_v5.py
canonical_fighter_contract_v5.py
schema_version -ne 5
Weapons/Primary/LeftMuzzle
Weapons/Primary/RightMuzzle
```

It must also assert the v4 validator/exporter names are absent from live scripts.

- [ ] **Step 6: Run Python tests before export**

```powershell
python -m unittest `
  tests.tools.test_primary_weapon_muzzle_geometry `
  tests.tools.test_canonical_fighter_v5 `
  tests.tools.test_fighter_socket_names `
  tests.tools.test_source_exact_thruster_geometry `
  tests.tools.test_fighter_thruster_action_contract `
  tests.tools.test_verify_scripts `
  -v
```

Expected: tests pass except any test that deliberately reads the currently stale live schema-2 manifest. Record that discrepancy; do not weaken a test to make stale generated output pass.

- [ ] **Step 7: Run the transactional Blender export locally**

```powershell
.\tools\assets\export-small-fighter.ps1
```

Expected evidence:

- source SHA remains `1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478`;
- exactly 12 thruster sockets;
- exactly 12 source-exact effect meshes;
- exactly 2 primary muzzle nodes;
- maximum thruster and muzzle extraction/reconstruction error `<= 0.0001 m`;
- pending GLB, manifest, and matrix validate before publication;
- live manifest is schema 5.

This is a mandatory user-output checkpoint. Do not continue until the user pastes the full output.

- [ ] **Step 8: Extend the Godot hero-asset integration test**

Update `tests/integration/test_hero_ship_asset.gd`:

```gdscript
const REQUIRED_MUZZLE_PATHS: Array[String] = [
    "Primary/LeftMuzzle",
    "Primary/RightMuzzle",
]
```

After validating `Thrusters` and `ThrusterEffects`, locate exactly one `Weapons` root and assert both nodes exist under `Weapons/Primary`, have finite origins/bases, identity scale, positive determinant, and forward axis aligned with fighter `-Z`.

- [ ] **Step 9: Run the asset-focused Godot test**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: existing suites plus the updated hero-asset suite pass. Do not claim the full milestone verified yet.

- [ ] **Step 10: Commit schema-5 generated outputs and tooling**

```powershell
git add `
  tools/assets/primary_weapon_muzzle_extraction.py `
  tools/assets/export_small_sci_fi_fighter_v5.py `
  tools/assets/export-small-fighter.ps1 `
  tools/verify/verify.ps1 `
  tests/tools/test_verify_scripts.py `
  tests/integration/test_hero_ship_asset.gd `
  assets/runtime/ships/player/small_sci_fi_fighter.glb `
  assets/runtime/ships/player/small_sci_fi_fighter.manifest.json `
  config/ships/small_sci_fi_fighter_thruster_actions.json
git commit -m "feat: publish schema five fighter muzzles"
```

---
