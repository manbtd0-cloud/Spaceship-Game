extends "res://tests/support/test_case.gd"

const HERO_GLB_PATH := "res://assets/runtime/ships/player/small_sci_fi_fighter.glb"
const EXPECTED_DIMENSIONS := Vector3(13.714, 3.562, 12.0)
const BOUNDS_TOLERANCE := 0.05
const REQUIRED_SOCKET_PATHS: Array[String] = [
    "Main/MainLeft",
    "Main/MainRight",
    "Retro/RetroLeft",
    "Retro/RetroRight",
    "Maneuver/FrontUpperLeft",
    "Maneuver/FrontUpperRight",
    "Maneuver/RearUpperLeft",
    "Maneuver/RearUpperRight",
    "Maneuver/RearLowerLeft",
    "Maneuver/RearLowerRight",
    "Maneuver/FrontLowerLeft",
    "Maneuver/FrontLowerRight",
]
const REQUIRED_EFFECT_PATHS: Array[String] = [
    "MainEffects/MainLeftEffect",
    "MainEffects/MainRightEffect",
    "RetroEffects/RetroLeftEffect",
    "RetroEffects/RetroRightEffect",
    "ManeuverEffects/FrontUpperLeftEffect",
    "ManeuverEffects/FrontUpperRightEffect",
    "ManeuverEffects/RearUpperLeftEffect",
    "ManeuverEffects/RearUpperRightEffect",
    "ManeuverEffects/RearLowerLeftEffect",
    "ManeuverEffects/RearLowerRightEffect",
    "ManeuverEffects/FrontLowerLeftEffect",
    "ManeuverEffects/FrontLowerRightEffect",
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
        "canonical fighter must not expose source EngineFire object names"
    )

    var thruster_root := _find_single_named_node(fighter, "Thrusters")
    assert_true(
        thruster_root != null,
        "canonical fighter must contain exactly one Thrusters hierarchy"
    )
    if thruster_root != null:
        for socket_path: String in REQUIRED_SOCKET_PATHS:
            var socket := thruster_root.get_node_or_null(socket_path) as Node3D
            assert_true(
                socket != null,
                "required thruster socket missing: Thrusters/%s" % socket_path
            )
            if socket != null:
                assert_true(
                    socket.scale.is_equal_approx(Vector3.ONE),
                    "thruster socket scale must be identity: Thrusters/%s"
                    % socket_path
                )
                assert_true(
                    socket.transform.basis.is_finite(),
                    "thruster socket basis must be finite: Thrusters/%s"
                    % socket_path
                )

    var effect_root := _find_single_named_node(fighter, "ThrusterEffects")
    assert_true(
        effect_root != null,
        "canonical fighter must contain exactly one ThrusterEffects hierarchy"
    )
    if effect_root != null:
        for effect_path: String in REQUIRED_EFFECT_PATHS:
            var pivot := effect_root.get_node_or_null(effect_path) as Node3D
            assert_true(
                pivot != null,
                "nozzle pivot missing: ThrusterEffects/%s" % effect_path
            )
            if pivot == null:
                continue

            assert_true(
                pivot.transform.origin.is_finite(),
                "nozzle pivot origin must be finite: ThrusterEffects/%s"
                % effect_path
            )
            assert_true(
                pivot.transform.basis.is_finite(),
                "nozzle pivot basis must be finite: ThrusterEffects/%s"
                % effect_path
            )
            assert_true(
                absf(pivot.transform.basis.determinant()) > 0.000001,
                "nozzle pivot basis must be non-degenerate: ThrusterEffects/%s"
                % effect_path
            )
            assert_true(
                pivot.scale.is_equal_approx(Vector3.ONE),
                "authored nozzle pivot scale must begin at one: ThrusterEffects/%s"
                % effect_path
            )

            var mesh_name := "%sMesh" % pivot.name
            var effect_mesh := pivot.get_node_or_null(mesh_name) as MeshInstance3D
            assert_true(
                effect_mesh != null and effect_mesh.mesh != null,
                "source-exact mesh child missing: ThrusterEffects/%s/%s"
                % [effect_path, mesh_name]
            )
            if effect_mesh != null:
                assert_true(
                    effect_mesh.transform.origin.is_equal_approx(Vector3.ZERO),
                    "effect mesh child must begin at pivot origin: ThrusterEffects/%s/%s"
                    % [effect_path, mesh_name]
                )
                assert_true(
                    effect_mesh.scale.is_equal_approx(Vector3.ONE),
                    "effect mesh child scale must begin at one: ThrusterEffects/%s/%s"
                    % [effect_path, mesh_name]
                )

    var hull := fighter.find_child(
        "SmallSciFiFighterMesh",
        true,
        false
    ) as MeshInstance3D
    assert_true(hull != null and hull.mesh != null, "canonical fighter hull mesh required")
    if hull != null and hull.mesh != null:
        var hull_transform := _local_transform_to_ancestor(hull, fighter)
        var local_bounds := hull.get_aabb()
        var minimum := Vector3.ZERO
        var maximum := Vector3.ZERO
        var has_point := false
        for endpoint_index: int in range(8):
            var point := hull_transform * local_bounds.get_endpoint(endpoint_index)
            if not has_point:
                minimum = point
                maximum = point
                has_point = true
            else:
                minimum = Vector3(
                    minf(minimum.x, point.x),
                    minf(minimum.y, point.y),
                    minf(minimum.z, point.z)
                )
                maximum = Vector3(
                    maxf(maximum.x, point.x),
                    maxf(maximum.y, point.y),
                    maxf(maximum.z, point.z)
                )
        var dimensions := maximum - minimum
        for axis: int in range(3):
            assert_true(
                absf(dimensions[axis] - EXPECTED_DIMENSIONS[axis]) <= BOUNDS_TOLERANCE,
                "canonical hull dimension %d outside tolerance: %.6f vs %.6f"
                % [axis, dimensions[axis], EXPECTED_DIMENSIONS[axis]]
            )

    fighter.free()

func _find_single_named_node(root: Node, node_name: String) -> Node3D:
    var candidates := root.find_children(node_name, "Node3D", true, false)
    if candidates.size() != 1:
        return null
    return candidates[0] as Node3D

func _transform_is_identity(value: Transform3D) -> bool:
    return (
        value.origin.is_equal_approx(Vector3.ZERO)
        and value.basis.x.is_equal_approx(Vector3.RIGHT)
        and value.basis.y.is_equal_approx(Vector3.UP)
        and value.basis.z.is_equal_approx(Vector3.BACK)
    )

func _local_transform_to_ancestor(
    node: Node3D,
    ancestor: Node3D
) -> Transform3D:
    var chain: Array[Node3D] = []
    var current: Node = node
    while current != ancestor:
        var current_3d := current as Node3D
        if current_3d == null:
            return Transform3D.IDENTITY
        chain.push_front(current_3d)
        current = current.get_parent()
        if current == null:
            return Transform3D.IDENTITY

    var result := Transform3D.IDENTITY
    for item: Node3D in chain:
        result *= item.transform
    return result
