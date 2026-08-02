extends "res://tests/support/test_case.gd"

const HERO_GLB_PATH := "res://assets/runtime/ships/player/small_sci_fi_fighter.glb"
const EXPECTED_DIMENSIONS := Vector3(13.714, 3.562, 12.0)
const BOUNDS_TOLERANCE := 0.05
const REQUIRED_SOCKET_PATHS: Array[String] = [
    "Thrusters/Main/Left",
    "Thrusters/Main/Right",
    "Thrusters/Retro/Left",
    "Thrusters/Retro/Right",
    "Thrusters/Maneuver/FrontUpperLeft",
    "Thrusters/Maneuver/FrontUpperRight",
    "Thrusters/Maneuver/RearUpperLeft",
    "Thrusters/Maneuver/RearUpperRight",
    "Thrusters/Maneuver/RearLowerLeft",
    "Thrusters/Maneuver/RearLowerRight",
    "Thrusters/Maneuver/FrontLowerLeft",
    "Thrusters/Maneuver/FrontLowerRight",
]

func run() -> void:
    assert_true(
        ResourceLoader.exists(HERO_GLB_PATH),
        "canonical hero fighter GLB must exist at the exact runtime path"
    )

    var packed := load(HERO_GLB_PATH) as PackedScene
    assert_true(packed != null, "canonical hero fighter GLB must import as PackedScene")
    if packed == null:
        return

    var fighter := packed.instantiate() as Node3D
    assert_true(fighter != null, "canonical hero fighter root must be Node3D")
    if fighter == null:
        return

    assert_true(
        _transform_is_identity(fighter.transform),
        "canonical fighter root transform must be identity"
    )
    assert_true(
        fighter.find_child("ForwardMarker", true, false) == null,
        "canonical fighter must not contain ForwardMarker"
    )
    assert_true(
        fighter.find_child("UpMarker", true, false) == null,
        "canonical fighter must not contain UpMarker"
    )
    assert_true(
        fighter.find_children("EngineFire*", "", true, false).is_empty(),
        "canonical fighter must not contain baked EngineFire geometry"
    )

    for socket_path: String in REQUIRED_SOCKET_PATHS:
        var socket := fighter.get_node_or_null(socket_path) as Node3D
        assert_true(socket != null, "required thruster socket missing: %s" % socket_path)
        if socket != null:
            assert_true(
                socket.scale.is_equal_approx(Vector3.ONE),
                "thruster socket scale must be identity: %s" % socket_path
            )
            assert_true(
                socket.transform.basis.is_finite(),
                "thruster socket basis must be finite: %s" % socket_path
            )

    var bounds_state := {
        "has_mesh": false,
        "minimum": Vector3.ZERO,
        "maximum": Vector3.ZERO,
    }
    _collect_mesh_bounds(fighter, Transform3D.IDENTITY, bounds_state)
    assert_true(bool(bounds_state["has_mesh"]), "canonical fighter must contain a mesh")

    if bool(bounds_state["has_mesh"]):
        var minimum: Vector3 = bounds_state["minimum"]
        var maximum: Vector3 = bounds_state["maximum"]
        var dimensions := maximum - minimum
        for axis: int in range(3):
            assert_true(
                absf(dimensions[axis] - EXPECTED_DIMENSIONS[axis]) <= BOUNDS_TOLERANCE,
                "canonical fighter dimension %d outside tolerance: %.6f vs %.6f"
                % [axis, dimensions[axis], EXPECTED_DIMENSIONS[axis]]
            )

    fighter.free()

func _transform_is_identity(value: Transform3D) -> bool:
    return (
        value.origin.is_equal_approx(Vector3.ZERO)
        and value.basis.x.is_equal_approx(Vector3.RIGHT)
        and value.basis.y.is_equal_approx(Vector3.UP)
        and value.basis.z.is_equal_approx(Vector3.BACK)
    )

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
