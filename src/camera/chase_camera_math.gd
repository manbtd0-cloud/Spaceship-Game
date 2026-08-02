class_name ChaseCameraMath
extends RefCounted

static func exponential_weight(sharpness: float, delta: float) -> float:
    return 1.0 - exp(-maxf(sharpness, 0.0) * maxf(delta, 0.0))

static func desired_position(
    target_transform: Transform3D,
    world_velocity: Vector3,
    base_offset: Vector3,
    velocity_look_ahead: float,
    speed_pullback: float,
    max_pullback: float
) -> Vector3:
    var pullback := minf(
        world_velocity.length() * maxf(speed_pullback, 0.0),
        maxf(max_pullback, 0.0)
    )
    return (
        target_transform.origin
        + target_transform.basis.orthonormalized() * (
            base_offset + Vector3(0.0, 0.0, pullback)
        )
        - world_velocity * maxf(velocity_look_ahead, 0.0)
    )

static func desired_look_target(
    target_transform: Transform3D,
    world_velocity: Vector3,
    velocity_look_ahead: float,
    forward_look_ahead: float
) -> Vector3:
    var forward := (
        target_transform.basis.orthonormalized()
        * Vector3.FORWARD
    )
    return (
        target_transform.origin
        + world_velocity * maxf(velocity_look_ahead, 0.0)
        + forward * maxf(forward_look_ahead, 0.0)
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
