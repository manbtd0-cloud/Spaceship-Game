# Interceptor Flight Refinement Plan — Authoritative Addendum

This file is authoritative over `docs/superpowers/plans/2026-08-02-interceptor-flight-refinement.md` where the two differ.

## 1. Runtime manifest filename

Use exactly:

`assets/runtime/ships/player/small_sci_fi_fighter.manifest.json`

The shorter `small_sci_fighter.manifest.json` spelling in Task 9 is invalid.

## 2. Thermal suite must prove full cooling

After the six-second recovery assertion in Task 3, continue cooling until heat reaches zero:

```gdscript
var full_cooling_elapsed := recovery_elapsed
while heat > 0.0 and full_cooling_elapsed < 16.0:
    var state := BoostThermalState.advance(
        heat, locked, 0.0, 0.0, 1.0 / 60.0,
        1.0 / 12.0, 1.0 / 15.0, 0.60
    )
    heat = state.heat
    locked = state.locked_out
    full_cooling_elapsed += 1.0 / 60.0
assert_true(
    full_cooling_elapsed >= 14.9 and full_cooling_elapsed <= 15.1,
    "fifteen-second full cooling"
)
assert_true(is_equal_approx(heat, 0.0), "heat must fully cool")
```

## 3. Exact additional `FlightModel` assertions for Task 2

Append:

```gdscript
tuning.pitch_torque = 10.0
tuning.yaw_torque = 20.0
tuning.roll_torque = 30.0

var all_axis_boost := FlightCommand.new()
all_axis_boost.mode = FlightMode.Value.MANUAL
all_axis_boost.translation = Vector3(1.0, 1.0, -1.0).normalized()
all_axis_boost.rotation = Vector3.ONE
all_axis_boost.boost = 1.0
var all_axis_output := FlightModel.compute(
    all_axis_boost, tuning, Vector3.ZERO, Vector3.ZERO
)
assert_true(all_axis_output.force_local.x > tuning.strafe_force, "boost scales lateral thrust")
assert_true(all_axis_output.force_local.y > tuning.strafe_force, "boost scales vertical thrust")
assert_equal(all_axis_output.torque_local, Vector3(10.0, 20.0, 30.0), "axis torques")

var normal_limit_output := FlightModel.compute(
    assisted,
    tuning,
    Vector3(0.0, 0.0, -160.0),
    Vector3.ZERO
)
assert_true(
    is_equal_approx(normal_limit_output.force_local.z, 0.0),
    "normal increasing thrust stops at 160 m/s"
)

var boosted_at_normal_limit := FlightCommand.new()
boosted_at_normal_limit.mode = FlightMode.Value.MANUAL
boosted_at_normal_limit.translation = Vector3.FORWARD
boosted_at_normal_limit.boost = 1.0
var boosted_at_normal_output := FlightModel.compute(
    boosted_at_normal_limit,
    tuning,
    Vector3(0.0, 0.0, -160.0),
    Vector3.ZERO
)
assert_true(boosted_at_normal_output.force_local.z < 0.0, "boost remains available at 160 m/s")

var braking_above_limit := FlightCommand.new()
braking_above_limit.mode = FlightMode.Value.MANUAL
braking_above_limit.translation = Vector3.BACK
var braking_output := FlightModel.compute(
    braking_above_limit,
    tuning,
    Vector3(0.0, 0.0, -180.0),
    Vector3.ZERO
)
assert_true(braking_output.force_local.z > 0.0, "braking remains available above limit")
```

## 4. Exact model-level steering assertions for Task 4

```gdscript
var steering_command := FlightCommand.new()
steering_command.mode = FlightMode.Value.ASSISTED
steering_command.translation = Vector3.FORWARD
var steering_output := FlightModel.compute(
    steering_command,
    tuning,
    Vector3(20.0, 0.0, -20.0),
    Vector3.ZERO,
    8500.0
)
assert_true(steering_output.force_local.x < 0.0, "assisted model bends drift toward nose")

steering_command.mode = FlightMode.Value.MANUAL
var inertial_output := FlightModel.compute(
    steering_command,
    tuning,
    Vector3(20.0, 0.0, -20.0),
    Vector3.ZERO,
    8500.0
)
assert_true(
    inertial_output.force_local.x >= -0.001,
    "manual model receives no nose-steering force"
)
```

## 5. Exact hero asset suite for Task 11

```gdscript
extends "res://tests/support/test_case.gd"

const HERO_PATH := "res://assets/runtime/ships/player/small_sci_fi_fighter.glb"

func run() -> void:
    assert_true(ResourceLoader.exists(HERO_PATH), "hero GLB must exist")
    var packed := load(HERO_PATH) as PackedScene
    assert_true(packed != null, "hero GLB must load")
    if packed == null:
        return

    var hero := packed.instantiate() as Node3D
    assert_true(hero != null, "hero GLB root must be Node3D")
    if hero == null:
        return

    var forward_marker := hero.find_child("ForwardMarker", true, false) as Node3D
    var up_marker := hero.find_child("UpMarker", true, false) as Node3D
    assert_true(forward_marker != null, "ForwardMarker required")
    assert_true(up_marker != null, "UpMarker required")
    if forward_marker != null:
        assert_true(
            forward_marker.position.normalized().dot(Vector3.FORWARD) > 0.99,
            "hero forward marker must use -Z"
        )
    if up_marker != null:
        assert_true(
            up_marker.position.normalized().dot(Vector3.UP) > 0.99,
            "hero up marker must use +Y"
        )

    var bounds := AABB()
    var found_mesh := false
    for child: Node in hero.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := child as MeshInstance3D
        var transformed := mesh_instance.get_aabb() * mesh_instance.transform
        bounds = transformed if not found_mesh else bounds.merge(transformed)
        found_mesh = true

    assert_true(found_mesh, "hero GLB must contain a mesh")
    if found_mesh:
        assert_true(bounds.size.x <= 8.05, "hero width envelope")
        assert_true(bounds.size.y <= 2.55, "hero height envelope")
        assert_true(bounds.size.z <= 12.05, "hero length envelope")
    hero.free()
```

## 6. Blender exporter implementation minimum

The exporter must contain concrete functions with these signatures:

```python
def parse_args() -> argparse.Namespace: ...
def visible_meshes() -> list[bpy.types.Object]: ...
def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]: ...
def remove_non_runtime_objects() -> None: ...
def join_meshes(objects: list[bpy.types.Object]) -> bpy.types.Object: ...
def fit_and_center(mesh: bpy.types.Object) -> Vector: ...
def create_axis_markers(root: bpy.types.Object) -> None: ...
def export_glb(output_path: Path, root: bpy.types.Object) -> None: ...
def write_manifest(path: Path, source_path: Path, dimensions: Vector) -> None: ...
def main() -> None: ...
```

Use `TARGET_BLENDER_DIMENSIONS = Vector((7.6, 11.4, 2.35))`. `world_bounds()` iterates every `bound_box` corner transformed by `matrix_world`. `fit_and_center()` computes a uniform minimum-axis scale, applies it, recomputes bounds, translates the mesh by the negative bounds center, applies location/rotation/scale, and throws when any final dimension exceeds the target by `0.01`.

The PowerShell wrapper must resolve the executable, create the output directory, run Blender with the exact source/script/output/manifest paths, inspect `$LASTEXITCODE`, and throw when either generated file is absent.

## 7. Manual acceptance list must be repeated during Task 12

Execute and record all twenty checks:

1. Pitching upward and applying forward thrust creates a smooth curved climb.
2. Yaw turns bank naturally rather than remaining flat.
3. A/D roll both directions.
4. Q/E translate laterally.
5. Arrow pitch/yaw mirrors mouse steering.
6. Assisted mode remains responsive with readable inertia.
7. Releasing forward thrust preserves forward momentum.
8. Manual mode has no hidden drift damping or steering.
9. Manual angular velocity persists after input release.
10. Normal acceleration fades smoothly from 120 to 160 m/s.
11. Boosted acceleration fades smoothly from 180 to 240 m/s.
12. Ending boost above 160 m/s preserves excess momentum.
13. Continuous boost locks out after approximately 12 seconds.
14. Overheat disables boost only.
15. Lockout clears after approximately 6 seconds of cooling.
16. Full cooling takes approximately 15 seconds.
17. Camera pullback and FOV remain smooth through 240 m/s.
18. The extended course is readable at handling and boost speeds.
19. The fighter faces -Z, uses +Y up, fits the collider envelope, and is centered.
20. Missing or invalid runtime fighter data fails verification without fallback.

## 8. Final comparison base

Use the last user-verified playable milestone commit as the implementation comparison base:

```bash
git diff e550094cb74ea06fab93cbcda3ea51043423727f...HEAD --stat
git diff --check
git status --short
```

Do not use `agent/playable-flight-room~1` as the milestone comparison base.
