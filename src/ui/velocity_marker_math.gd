class_name VelocityMarkerMath
extends RefCounted

const EPSILON := 0.000001

static func project(
    camera_transform: Transform3D,
    vertical_fov_degrees: float,
    viewport_size: Vector2,
    world_velocity: Vector3,
    minimum_speed: float,
    safe_margin: float
) -> VelocityMarkerState:
    var hidden := VelocityMarkerState.new()
    if not _inputs_are_valid(
        vertical_fov_degrees,
        viewport_size,
        world_velocity,
        minimum_speed,
        safe_margin
    ):
        return hidden

    var speed := world_velocity.length()
    if not _is_finite_float(speed) or speed < minimum_speed or speed <= EPSILON:
        return hidden

    var camera_basis := camera_transform.basis.orthonormalized()
    var local_direction := camera_basis.inverse() * (world_velocity / speed)
    if not _is_finite_vector3(local_direction):
        return hidden

    var viewport_center := viewport_size * 0.5
    var edge_direction := Vector2.ZERO

    if local_direction.z < -EPSILON:
        var tangent := tan(deg_to_rad(vertical_fov_degrees) * 0.5)
        if not _is_finite_float(tangent) or tangent <= EPSILON:
            return hidden

        var aspect := viewport_size.x / viewport_size.y
        var inverse_depth := -local_direction.z
        var ndc := Vector2(
            local_direction.x / (inverse_depth * tangent * aspect),
            local_direction.y / (inverse_depth * tangent)
        )
        var screen_position := Vector2(
            (ndc.x * 0.5 + 0.5) * viewport_size.x,
            (0.5 - ndc.y * 0.5) * viewport_size.y
        )
        if not _is_finite_vector2(screen_position):
            return hidden
        if _inside_safe_rect(screen_position, viewport_size, safe_margin):
            return VelocityMarkerState.new(true, screen_position, false, 0.0)
        edge_direction = screen_position - viewport_center
    elif absf(local_direction.z) <= EPSILON:
        edge_direction = Vector2(local_direction.x, -local_direction.y)
    else:
        edge_direction = Vector2(-local_direction.x, local_direction.y)

    if edge_direction.length_squared() <= EPSILON * EPSILON:
        edge_direction = Vector2.UP

    var normalized_direction := edge_direction.normalized()
    return VelocityMarkerState.new(
        true,
        _clamp_to_safe_rect(normalized_direction, viewport_size, safe_margin),
        true,
        atan2(normalized_direction.y, normalized_direction.x)
    )

static func _inputs_are_valid(
    vertical_fov_degrees: float,
    viewport_size: Vector2,
    world_velocity: Vector3,
    minimum_speed: float,
    safe_margin: float
) -> bool:
    if (
        not _is_finite_float(vertical_fov_degrees)
        or not _is_finite_vector2(viewport_size)
        or not _is_finite_vector3(world_velocity)
        or not _is_finite_float(minimum_speed)
        or not _is_finite_float(safe_margin)
    ):
        return false
    if vertical_fov_degrees <= 0.0 or vertical_fov_degrees >= 179.0:
        return false
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return false
    if minimum_speed < 0.0 or safe_margin < 0.0:
        return false
    return (
        viewport_size.x > safe_margin * 2.0
        and viewport_size.y > safe_margin * 2.0
    )

static func _inside_safe_rect(
    position: Vector2,
    viewport_size: Vector2,
    safe_margin: float
) -> bool:
    return (
        position.x >= safe_margin
        and position.x <= viewport_size.x - safe_margin
        and position.y >= safe_margin
        and position.y <= viewport_size.y - safe_margin
    )

static func _clamp_to_safe_rect(
    direction: Vector2,
    viewport_size: Vector2,
    safe_margin: float
) -> Vector2:
    var center := viewport_size * 0.5
    var half_extents := center - Vector2.ONE * safe_margin
    var x_scale := 1.0e20
    var y_scale := 1.0e20
    if absf(direction.x) > EPSILON:
        x_scale = half_extents.x / absf(direction.x)
    if absf(direction.y) > EPSILON:
        y_scale = half_extents.y / absf(direction.y)
    var edge_distance := minf(x_scale, y_scale)
    var result := center + direction * edge_distance
    return Vector2(
        clampf(result.x, safe_margin, viewport_size.x - safe_margin),
        clampf(result.y, safe_margin, viewport_size.y - safe_margin)
    )

static func _is_finite_float(value: float) -> bool:
    return not is_nan(value) and not is_inf(value)

static func _is_finite_vector2(value: Vector2) -> bool:
    return _is_finite_float(value.x) and _is_finite_float(value.y)

static func _is_finite_vector3(value: Vector3) -> bool:
    return (
        _is_finite_float(value.x)
        and _is_finite_float(value.y)
        and _is_finite_float(value.z)
    )
