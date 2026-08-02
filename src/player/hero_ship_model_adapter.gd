class_name HeroShipModelAdapter
extends Node

@export var model_path: NodePath
@export var target_dimensions := Vector3(7.2, 4.2, 10.8)

var _model: Node3D
var _applied_scale := 1.0

func _ready() -> void:
    if not normalize_model():
        set_process(false)

func normalize_model() -> bool:
    _model = get_node_or_null(model_path) as Node3D
    if _model == null:
        push_error(
            "HeroShipModelAdapter could not resolve model at %s"
            % model_path
        )
        return false

    var forward_marker := _model.find_child(
        "ForwardMarker",
        true,
        false
    ) as Node3D
    var up_marker := _model.find_child(
        "UpMarker",
        true,
        false
    ) as Node3D
    if forward_marker == null or up_marker == null:
        push_error(
            "HeroShipModelAdapter requires ForwardMarker and UpMarker"
        )
        return false

    var source_forward := _model.to_local(
        forward_marker.global_position
    )
    var source_up := _model.to_local(up_marker.global_position)
    if (
        source_forward.length_squared() <= 0.000001
        or source_up.length_squared() <= 0.000001
        or absf(source_forward.normalized().dot(source_up.normalized())) > 0.999
    ):
        push_error("HeroShipModelAdapter received invalid axis markers")
        return false

    var alignment := HeroShipAlignment.alignment_basis(
        source_forward,
        source_up
    )
    var dimensions := _aligned_mesh_dimensions(alignment)
    if dimensions.length_squared() <= 0.000001:
        push_error("HeroShipModelAdapter found no renderable fighter mesh")
        return false

    _applied_scale = HeroShipAlignment.uniform_fit_scale(
        dimensions,
        target_dimensions
    )
    _model.transform = Transform3D(
        alignment.scaled(Vector3.ONE * _applied_scale),
        Vector3.ZERO
    )
    return true

func get_applied_scale() -> float:
    return _applied_scale

func _aligned_mesh_dimensions(alignment: Basis) -> Vector3:
    var state := {
        "has_mesh": false,
        "minimum": Vector3.ZERO,
        "maximum": Vector3.ZERO,
    }
    var model_inverse := _model.global_transform.affine_inverse()
    _collect_mesh_bounds(
        _model,
        model_inverse,
        alignment,
        state
    )
    if not bool(state["has_mesh"]):
        return Vector3.ZERO
    return state["maximum"] - state["minimum"]

func _collect_mesh_bounds(
    node: Node,
    model_inverse: Transform3D,
    alignment: Basis,
    state: Dictionary
) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        var relative_transform := (
            model_inverse * mesh_instance.global_transform
        )
        var local_bounds := mesh_instance.get_aabb()
        for endpoint_index in range(8):
            var model_point := (
                relative_transform
                * local_bounds.get_endpoint(endpoint_index)
            )
            _include_point(state, alignment * model_point)

    for child in node.get_children():
        _collect_mesh_bounds(
            child,
            model_inverse,
            alignment,
            state
        )

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
