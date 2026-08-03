class_name FlightSteeringMath
extends RefCounted

static func assisted_force(
    local_velocity: Vector3,
    desired_local_direction: Vector3,
    input_amount: float,
    body_mass: float,
    steering_strength: float,
    minimum_speed: float,
    maximum_acceleration: float
) -> Vector3:
    if not local_velocity.is_finite() or not desired_local_direction.is_finite():
        return Vector3.ZERO

    var speed := local_velocity.length()
    var steering_input := clampf(input_amount, 0.0, 1.0)
    if steering_input <= 0.0 or speed < maxf(minimum_speed, 0.0):
        return Vector3.ZERO
    if desired_local_direction.length_squared() < 0.000001:
        return Vector3.ZERO

    var velocity_direction := local_velocity / speed
    var desired_direction := desired_local_direction.normalized()
    var alignment := clampf(
        velocity_direction.dot(desired_direction),
        -1.0,
        1.0
    )
    var perpendicular_target := (
        desired_direction - velocity_direction * alignment
    )
    if perpendicular_target.length_squared() < 0.000001:
        return Vector3.ZERO

    var angle_factor := clampf(acos(alignment) / PI, 0.0, 1.0)
    var acceleration := minf(
        speed * maxf(steering_strength, 0.0) * angle_factor,
        maxf(maximum_acceleration, 0.0)
    ) * steering_input
    var force := (
        perpendicular_target.normalized()
        * acceleration
        * maxf(body_mass, 0.0)
    )

    # Remove floating-point residue parallel to velocity so this steering
    # changes direction without intentionally changing speed.
    force -= velocity_direction * force.dot(velocity_direction)
    return force if force.is_finite() else Vector3.ZERO
