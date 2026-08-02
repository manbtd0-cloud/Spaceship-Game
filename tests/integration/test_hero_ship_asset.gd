extends "res://tests/support/test_case.gd"

const HERO_GLB_PATH := "res://assets/runtime/ships/player/small_sci_fi_fighter.glb"
const MAXIMUM_DIMENSIONS := Vector3(8.0, 2.5, 12.0)
const BOUNDS_TOLERANCE := 0.05

func run() -> void:
    assert_true(
        ResourceLoader.exists(HERO_GLB_PATH),
        "hero fighter GLB must exist at the exact runtime path"
    )

    var packed := load(HERO_GLB_PATH) as PackedScene
    assert_true(packed != null, "hero fighter GLB must import as PackedScene")
    if packed == null:
        return

    var fighter := packed.instantiate() as Node3D
    assert_true(fighter != null, "hero fighter root must be Node3D")
    if fighter == null:
        return

    var forward_marker := fighter.find_child(
        "ForwardMarker",
        true,
        false
    ) as Node3D
    var up_marker := fighter.find_child(
        "UpMarker",
        true,
        false
    ) as Node3D
    assert_true(forward_marker != null, "ForwardMarker required")
    assert_true(up_marker != null, "UpMarker required")

    if forward_marker != null:
        assert_true(
            forward_marker.position.normalized().dot(Vector3.FORWARD) > 0.99,
            "ForwardMarker must point toward local -Z"
        )
    if up_marker != null:
        assert_true(
            up_marker.position.normalized().dot(Vector3.UP) > 0.99,
            "UpMarker must point toward local +Y"
        )

    var bounds_state := {
        "has_mesh": false,
        "minimum": Vector3.ZERO,
        "maximum": Vector3.ZERO,
    }
    _collect_mesh_bounds(
        fighter,
        Transform3D.IDENTITY,
        bounds_state
    )
    assert_true(bool(bounds_state["has_mesh"]), "hero fighter must contain a mesh")

    if bool(bounds_state["has_mesh"]):
        var dimensions: Vector3 = (
            bounds_state["maximum"] - bounds_state["minimum"]
        )
        assert_true(
            dimensions.x <= MAXIMUM_DIMENSIONS.x + BOUNDS_TOLERANCE,
            "hero fighter width exceeds gameplay envelope: %.3f" % dimensions.x
        )
        assert_true(
            dimensions.y <= MAXIMUM_DIMENSIONS.y + BOUNDS_TOLERANCE,
            "hero fighter height exceeds gameplay envelope: %.3f" % dimensions.y
        )
        assert_true(
            dimensions.z <= MAXIMUM_DIMENSIONS.z + BOUNDS_TOLERANCE,
            "hero fighter length exceeds gameplay envelope: %.3f" % dimensions.z
        )

    fighter.free()

func _collect_mesh_bounds(
    node: Node,
    parent_transform: Transform3D,
    state: Dictionary
) -> void:
    var current_transform := parent_transform
    var node_3d := node as Node3D
    if node_3d != null:
        current_transform = parent_transform * node_3d.transform

    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        var local_bounds := mesh_instance.get_aabb()
        for endpoint_index: int in range(8):
            _include_point(
                state,
                current_transform * local_bounds.get_endpoint(endpoint_index)
            )

    for child: Node in node.get_children():
        _collect_mesh_bounds(child, current_transform, state)

func _include_point(state: Dictionary, point: Vector3) -> void:
    if not bool(state["has_mesh"]):
        state["has_mesh"] = true
        state["minimum"] = point
        state["maximum"] = point
        return

    var minimum: Vector3 = state["minimum"]
    var maximum: Vector3 = state["maximum"]
    state["minimum"] = Vector3(
        minf(minimum.x, point.x),
        minf(minimum.y, point.y),
        minf(minimum.z, point.z)
    )
    state["maximum"] = Vector3(
        maxf(maximum.x, point.x),
        maxf(maximum.y, point.y),
        maxf(maximum.z, point.z)
    )
