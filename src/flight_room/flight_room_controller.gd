class_name FlightRoomController
extends Node

@export var player_body_path: NodePath
@export var player_controller_path: NodePath
@export var input_source_path: NodePath
@export var reset_volume_path: NodePath
@export var boundary_radius: float = 2500.0

var _body: RigidBody3D
var _controller: ShipFlightController
var _input_source: PlayerInputSource
var _reset_volume: Area3D
var _spawn_transform := Transform3D.IDENTITY

func _ready() -> void:
    _body = get_node_or_null(player_body_path) as RigidBody3D
    _controller = get_node_or_null(player_controller_path) as ShipFlightController
    _input_source = get_node_or_null(input_source_path) as PlayerInputSource
    _reset_volume = get_node_or_null(reset_volume_path) as Area3D

    if _body == null:
        _disable_with_error("FlightRoomController could not resolve player body")
        return
    if _controller == null:
        _disable_with_error("FlightRoomController could not resolve ship controller")
        return
    if _input_source == null:
        _disable_with_error("FlightRoomController could not resolve input source")
        return
    if _reset_volume == null:
        _disable_with_error("FlightRoomController could not resolve reset volume")
        return

    _spawn_transform = _body.global_transform
    if not _controller.reset_requested.is_connected(reset_player):
        _controller.reset_requested.connect(reset_player)
    if not _reset_volume.body_entered.is_connected(_on_reset_volume_body_entered):
        _reset_volume.body_entered.connect(_on_reset_volume_body_entered)

    _input_source.set_mouse_captured(true)
    if not setup_asteroid_field():
        push_warning(
            "Canonical asteroid pack is unavailable; keeping distant reference placeholders"
        )

func _physics_process(_delta: float) -> void:
    if _body.global_position.length() > maxf(boundary_radius, 1.0):
        reset_player()

func setup_asteroid_field(models: Dictionary = {}) -> bool:
    var room := get_parent() as Node3D
    if room == null:
        return false
    var course := room.get_node_or_null("Course") as Node3D
    if course == null:
        return false

    var resolved_models := models
    if resolved_models.is_empty():
        resolved_models = AsteroidField.load_runtime_models()
    if resolved_models.size() != AsteroidFieldLayout.FAMILY_IDS.size():
        return false

    var field := course.get_node_or_null("AsteroidField") as AsteroidField
    var created_field := false
    if field == null:
        field = AsteroidField.new()
        field.name = "AsteroidField"
        course.add_child(field)
        created_field = true

    if not field.build(resolved_models):
        if created_field:
            course.remove_child(field)
            field.free()
        return false

    var references := course.get_node_or_null("DistantReferenceShapes")
    if references != null:
        course.remove_child(references)
        references.free()
    return true

func _on_reset_volume_body_entered(other: Node) -> void:
    if other == _body:
        reset_player()

func reset_player() -> void:
    _body.freeze = true
    _body.global_transform = _spawn_transform
    _body.linear_velocity = Vector3.ZERO
    _body.angular_velocity = Vector3.ZERO
    _controller.reset_runtime_state()
    _body.freeze = false
    _body.sleeping = false

func _disable_with_error(message: String) -> void:
    push_error(message)
    set_physics_process(false)
