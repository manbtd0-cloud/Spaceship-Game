class_name ChaseCameraMath
extends RefCounted

static func exponential_weight(sharpness: float, delta: float) -> float:
    return 1.0 - exp(-maxf(sharpness, 0.0) * maxf(delta, 0.0))

static func local_forward_speed(
    target_transform: Transform3D,
    world_velocity: Vector3
) -> float:
    if not world_velocity.is_finite():
        return 0.0
    var local_velocity := (
        target_transform.basis.orthonormalized().inverse()
        * world_velocity
    )
    return maxf(-local_velocity.z, 0.0)

static func desired_position(
    target_transform: Transform3D,
    world_velocity: Vector3,
    rear_offset: float,
    height: float,
    speed_pullback_rate: float,
    max_speed_pullback: float,
    hard_rear_limit: float
) -> Vector3:
    var safe_rear := maxf(rear_offset, 0.0)
    var safe_height := maxf(height, 0.0)
    var safe_limit := maxf(hard_rear_limit, safe_rear)
    var pullback := minf(
        local_forward_speed(target_transform, world_velocity)
        * maxf(speed_pullback_rate, 0.0),
        maxf(max_speed_pullback, 0.0)
    )
    var final_rear := minf(safe_rear + pullback, safe_limit)
    return (
        target_transform.origin
        + target_transform.basis.orthonormalized()
        * Vector3(0.0, safe_height, final_rear)
    )

static func clamp_rear_position(
    target_transform: Transform3D,
    candidate_position: Vector3,
    hard_rear_limit: float
) -> Vector3:
    if not candidate_position.is_finite():
        return target_transform.origin
    var target_basis := target_transform.basis.orthonormalized()
    var local_position := target_basis.inverse() * (
        candidate_position - target_transform.origin
    )
    local_position.z = clampf(
        local_position.z,
        0.001,
        maxf(hard_rear_limit, 0.001)
    )
    return target_transform.origin + target_basis * local_position

static func desired_look_target(
    target_transform: Transform3D,
    world_velocity: Vector3,
    velocity_look_ahead: float,
    forward_look_ahead: float,
    max_prediction_distance: float
) -> Vector3:
    var safe_velocity := (
        world_velocity if world_velocity.is_finite() else Vector3.ZERO
    )
    var prediction := (
        safe_velocity * maxf(velocity_look_ahead, 0.0)
    ).limit_length(maxf(max_prediction_distance, 0.0))
    var forward := (
        target_transform.basis.orthonormalized()
        * Vector3.FORWARD
    )
    return (
        target_transform.origin
        + prediction
        + forward * maxf(forward_look_ahead, 0.0)
    )

static func interpolate_scalar(
    current: float,
    target: float,
    sharpness: float,
    delta: float
) -> float:
    return lerpf(
        current,
        target,
        exponential_weight(sharpness, delta)
    )

static func desired_camera_basis(
    camera_position: Vector3,
    look_target: Vector3,
    target_transform: Transform3D
) -> Basis:
    var target_basis := target_transform.basis.orthonormalized()
    var look_direction := look_target - camera_position
    if look_direction.length_squared() < 0.0001:
        return target_basis

    look_direction = look_direction.normalized()
    var relative_up := target_basis.y.normalized()
    if absf(look_direction.dot(relative_up)) > 0.98:
        relative_up = target_basis.x.normalized()
    if absf(look_direction.dot(relative_up)) > 0.98:
        relative_up = target_basis.z.normalized()

    return Transform3D(Basis.IDENTITY, camera_position).looking_at(
        look_target,
        relative_up
    ).basis.orthonormalized()

static func desired_fov(
    speed_mps: float,
    boost_amount: float,
    base_fov: float,
    normal_limit: float,
    boost_limit: float,
    normal_max_fov: float,
    boost_max_fov: float,
    boost_bonus: float
) -> float:
    var speed := maxf(speed_mps, 0.0)
    var normal_end := maxf(normal_limit, 0.001)
    var boost_end := maxf(boost_limit, normal_end + 0.001)
    var value: float
    if speed <= normal_end:
        var normal_t := clampf(speed / normal_end, 0.0, 1.0)
        var normal_smooth := normal_t * normal_t * (3.0 - 2.0 * normal_t)
        value = lerpf(base_fov, normal_max_fov, normal_smooth)
    else:
        var boost_t := clampf(
            (speed - normal_end) / (boost_end - normal_end),
            0.0,
            1.0
        )
        var boost_smooth := boost_t * boost_t * (3.0 - 2.0 * boost_t)
        value = lerpf(normal_max_fov, boost_max_fov, boost_smooth)
    value += (
        clampf(boost_amount, 0.0, 1.0)
        * maxf(boost_bonus, 0.0)
    )
    return clampf(
        value,
        base_fov,
        maxf(boost_max_fov, base_fov)
    )
