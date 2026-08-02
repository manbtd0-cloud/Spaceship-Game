class_name AsteroidField
extends Node3D

const ASTEROID_BODY_SCENE := preload("res://scenes/environment/asteroid_body.tscn")
const RUNTIME_MODEL_PATHS := {
    &"bennu": "res://assets/runtime/environment/asteroids/bennu.glb",
    &"eros": "res://assets/runtime/environment/asteroids/eros.glb",
    &"legacy_a": "res://assets/runtime/environment/asteroids/legacy_a.glb",
    &"legacy_b": "res://assets/runtime/environment/asteroids/legacy_b.glb",
}

var _built := false
var _family_counts: Dictionary = {}

static func load_runtime_models() -> Dictionary:
    var models: Dictionary = {}
    for family: StringName in AsteroidFieldLayout.FAMILY_IDS:
        var path := String(RUNTIME_MODEL_PATHS.get(family, ""))
        if path.is_empty() or not ResourceLoader.exists(path):
            push_warning("Canonical asteroid runtime asset missing: %s" % path)
            return {}
        var model := load(path) as PackedScene
        if model == null:
            push_warning("Canonical asteroid runtime asset failed to load: %s" % path)
            return {}
        models[family] = model
    return models

func build_runtime_pack() -> bool:
    var models := load_runtime_models()
    if models.size() != AsteroidFieldLayout.FAMILY_IDS.size():
        return false
    return build(models)

func build(models: Dictionary) -> bool:
    clear_field()

    for family: StringName in AsteroidFieldLayout.FAMILY_IDS:
        if not (models.get(family) is PackedScene):
            push_error("AsteroidField missing PackedScene for family: %s" % family)
            return false

    var records := AsteroidFieldLayout.records()
    for index: int in range(records.size()):
        var record: Dictionary = records[index]
        var family := StringName(record["family"])
        var model := models[family] as PackedScene
        var angular_velocity: Vector3 = record["angular_velocity_degrees"]
        var position: Vector3 = record["position"]
        var rotation_degrees: Vector3 = record["rotation_degrees"]
        var body := ASTEROID_BODY_SCENE.instantiate() as AsteroidBody
        if body == null:
            push_error("AsteroidField could not instantiate AsteroidBody")
            clear_field()
            return false

        body.name = "Asteroid%02d_%s" % [index + 1, String(family)]
        add_child(body)
        if not body.configure(model, family, angular_velocity):
            push_error("AsteroidField could not configure family: %s" % family)
            remove_child(body)
            body.free()
            clear_field()
            return false

        body.position = position
        body.rotation_degrees = rotation_degrees
        var uniform_scale := float(record["scale"])
        body.scale = Vector3.ONE * uniform_scale
        _family_counts[family] = int(_family_counts.get(family, 0)) + 1

    _built = get_child_count() == records.size()
    return _built

func clear_field() -> void:
    for child: Node in get_children():
        remove_child(child)
        child.free()
    _family_counts.clear()
    _built = false

func is_built() -> bool:
    return _built

func get_asteroid_count() -> int:
    return get_child_count()

func get_family_count(family: StringName) -> int:
    return int(_family_counts.get(family, 0))

func are_all_asteroids_collidable() -> bool:
    if not _built or get_child_count() == 0:
        return false
    for child: Node in get_children():
        var asteroid := child as AsteroidBody
        if asteroid == null or not asteroid.is_configured():
            return false
        var collision := asteroid.get_node_or_null("Collision") as CollisionShape3D
        if collision == null or collision.shape == null or collision.disabled:
            return false
    return true
