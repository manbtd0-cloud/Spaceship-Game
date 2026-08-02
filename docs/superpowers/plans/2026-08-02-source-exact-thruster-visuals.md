# Source-Exact Thruster Visuals Implementation Plan

**Goal:** Replace all procedural exhaust cones with the exact `EngineFire*` geometry authored in the preserved Blender source, while keeping the final-wrench allocator and twelve semantic channels.

### Task 1: Pure component-group contract

- Extend `small_fighter_calibration.py` with deterministic raw component-index grouping.
- Add tests for the four-island/two-main-plume case and ambiguity rejection.

### Task 2: Canonical effect geometry export

- Extend `SocketRecord` with raw component indices and exact geometry metadata.
- Extract source vertices/faces for each physical plume.
- Transform them into canonical fighter coordinates.
- Export twelve identity-transform meshes under `ThrusterEffects`.
- Use a transparent zero-emission import material.
- Write geometry counts, bounds, source components, and SHA-256 digests to schema-3 manifest.

### Task 3: Contract validation

- Require schema 3.
- Require exact socket and effect path sets.
- Require twelve effect records with valid counts, bounds, digests, source components, and identity transforms.
- Update Windows/Linux verifier gates.

### Task 4: Runtime source-exact controller

- Remove procedural `ThrusterExhaustEffect` construction.
- Resolve each semantic socket and matching imported effect mesh.
- Keep effect transforms unchanged.
- Drive only visibility, alpha, and emission energy.
- Preserve final-wrench allocation and boost response.

### Task 5: Godot tests

- Require twelve imported effect meshes.
- Require all effect transforms to be identity.
- Require all effects hidden at idle.
- Require controller validation with twelve socket/effect pairs.
- Remove procedural plume-orientation tests.

### Task 6: Local Blender/Godot gate

Run:

```powershell
python -m unittest tests.tools.test_small_fighter_calibration tests.tools.test_fighter_socket_names -v
.\tools\assets\export-small-fighter.ps1
.\tools\verify\verify.ps1
```

Manual acceptance:

- main exhaust emerges from the two rear vents;
- retro exhaust points outward from the forward-facing vents;
- all maneuvering exhausts emerge from their authored side vents;
- no effect is visible at idle;
- no procedural cone remains;
- no runtime transform adjustment exists.
