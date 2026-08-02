class_name AsteroidBody
extends AnimatableBody3D

@export var angular_velocity_degrees := Vector3.ZERO

var _family: StringName = &""
var _configured := false
var _model_mount: Node3D
var _collision: CollisionShape3D

func _ready() -> void:
    _resolve_nodes()

func _physics_process(delta: float) -> void:
    advance_rotation(delta)

func configure(
    model: PackedScene,
    family: StringName,
    angular_velocity: Vector3
) -> bool:
    _resolve_nodes()
    _clear_configuration()
    if model == null or _model_mount == null or _collision == null:
        return false

    var instance := model.instantiate() as Node3D
    if instance == null:
        push_error("AsteroidBody requires a Node3D model root")
        return false
    instance.name = "RuntimeModel"
    _model_mount.add_child(instance)

    var source_collision := _find_collision_shape(instance)
    if source_collision == null or source_collision.shape == null:
        push_error(
            "AsteroidBody model is missing imported convex collision geometry"
        )
        _model_mount.remove_child(instance)
        instance.free()
        return false

    var shape_copy := source_collision.shape.duplicate(true) as Shape3D
    if shape_copy == null:
        push_error("AsteroidBody could not duplicate imported collision shape")
        _model_mount.remove_child(instance)
        instance.free()
        return false

    _collision.shape = shape_copy
    _collision.transform = (
        global_transform.affine_inverse()
        * source_collision.global_transform
    )
    source_collision.disabled = true

    _family = family
    angular_velocity_degrees = angular_velocity
    set_meta("asteroid_family", String(family))
    _configured = true
    return true

func advance_rotation(delta: float) -> void:
    if not _configured or delta <= 0.0:
        return
    rotation += Vector3(
        deg_to_rad(angular_velocity_degrees.x),
        deg_to_rad(angular_velocity_degrees.y),
        deg_to_rad(angular_velocity_degrees.z)
    ) * delta

func is_configured() -> bool:
    return _configured

func get_family() -> StringName:
    return _family

func _resolve_nodes() -> void:
    if _model_mount == null:
        _model_mount = get_node_or_null("ModelMount") as Node3D
    if _collision == null:
        _collision = get_node_or_null("Collision") as CollisionShape3D

func _clear_configuration() -> void:
    if _model_mount != null:
        for child: Node in _model_mount.get_children():
            _model_mount.remove_child(child)
            child.free()
    if _collision != null:
        _collision.shape = null
        _collision.transform = Transform3D.IDENTITY
    _family = &""
    _configured = false
    remove_meta("asteroid_family")

func _find_collision_shape(node: Node) -> CollisionShape3D:
    var direct := node as CollisionShape3D
    if direct != null and direct.shape != null:
        return direct
    for child: Node in node.get_children():
        var found := _find_collision_shape(child)
        if found != null:
            return found
    return null
