class_name FlightSteeringMath
extends RefCounted

static func assisted_force(
    local_velocity: Vector3,
    forward_input: float,
    body_mass: float,
    steering_strength: float,
    minimum_speed: float,
    maximum_acceleration: float
) -> Vector3:
    var speed := local_velocity.length()
    var input_amount := clampf(forward_input, 0.0, 1.0)
    if input_amount <= 0.0 or speed < maxf(minimum_speed, 0.0):
        return Vector3.ZERO

    var velocity_direction := local_velocity / speed
    var desired_direction := Vector3.FORWARD
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
    ) * input_amount
    return (
        perpendicular_target.normalized()
        * acceleration
        * maxf(body_mass, 0.0)
    )
