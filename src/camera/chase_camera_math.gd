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
    look_ahead_distance: float
) -> Vector3:
    return target_transform.origin + world_velocity * maxf(look_ahead_distance, 0.0)

static func desired_fov(
    speed_mps: float,
    boost_amount: float,
    base_fov: float,
    speed_fov_gain: float,
    boost_fov_gain: float,
    max_fov: float
) -> float:
    return clampf(
        base_fov
        + maxf(speed_mps, 0.0) * maxf(speed_fov_gain, 0.0)
        + clampf(boost_amount, 0.0, 1.0) * maxf(boost_fov_gain, 0.0),
        base_fov,
        maxf(max_fov, base_fov)
    )
