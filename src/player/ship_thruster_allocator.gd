class_name ShipThrusterAllocator
extends RefCounted

const SOLVER_PASSES := 48
const EPSILON := 0.00000001
const WRENCH_SIZE := 6

static func solve(
    sockets: Array[Dictionary],
    desired_force: Vector3,
    desired_torque: Vector3,
    force_reference: float,
    torque_reference: float
) -> PackedFloat32Array:
    var intensities := PackedFloat32Array()
    intensities.resize(sockets.size())
    intensities.fill(0.0)

    if sockets.is_empty():
        return intensities
    if force_reference <= EPSILON or torque_reference <= EPSILON:
        return intensities
    if not desired_force.is_finite() or not desired_torque.is_finite():
        return intensities

    var target := PackedFloat32Array([
        desired_force.x / force_reference,
        desired_force.y / force_reference,
        desired_force.z / force_reference,
        desired_torque.x / torque_reference,
        desired_torque.y / torque_reference,
        desired_torque.z / torque_reference,
    ])
    if _dot(target, target) <= EPSILON:
        return intensities

    var columns: Array[PackedFloat32Array] = []
    for socket: Dictionary in sockets:
        columns.append(
            _build_column(socket, force_reference, torque_reference)
        )

    var current := PackedFloat32Array()
    current.resize(WRENCH_SIZE)
    current.fill(0.0)

    for _pass_index: int in range(SOLVER_PASSES):
        for socket_index: int in range(columns.size()):
            var column: PackedFloat32Array = columns[socket_index]
            var denominator := _dot(column, column)
            if denominator <= EPSILON:
                intensities[socket_index] = 0.0
                continue

            var old_value := intensities[socket_index]
            var numerator := 0.0
            for axis: int in range(WRENCH_SIZE):
                numerator += column[axis] * (
                    target[axis]
                    - current[axis]
                    + column[axis] * old_value
                )

            var new_value := clampf(numerator / denominator, 0.0, 1.0)
            if not is_finite(new_value):
                new_value = 0.0
            intensities[socket_index] = new_value

            var delta := new_value - old_value
            if absf(delta) <= EPSILON:
                continue
            for axis: int in range(WRENCH_SIZE):
                current[axis] += column[axis] * delta

    return intensities

static func _build_column(
    socket: Dictionary,
    force_reference: float,
    torque_reference: float
) -> PackedFloat32Array:
    var position: Vector3 = socket.get("position", Vector3.ZERO)
    var reaction_direction: Vector3 = socket.get(
        "reaction_direction",
        Vector3.ZERO
    )
    var capacity := clampf(float(socket.get("capacity", 0.0)), 0.0, 1.0)

    if (
        not position.is_finite()
        or not reaction_direction.is_finite()
        or reaction_direction.length_squared() <= EPSILON
        or capacity <= EPSILON
    ):
        return PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

    reaction_direction = reaction_direction.normalized()
    var normalized_force := reaction_direction * capacity
    var normalized_torque := (
        position.cross(reaction_direction * capacity)
        * (force_reference / torque_reference)
    )
    return PackedFloat32Array([
        normalized_force.x,
        normalized_force.y,
        normalized_force.z,
        normalized_torque.x,
        normalized_torque.y,
        normalized_torque.z,
    ])

static func _dot(left: PackedFloat32Array, right: PackedFloat32Array) -> float:
    var result := 0.0
    var count := mini(left.size(), right.size())
    for index: int in range(count):
        result += left[index] * right[index]
    return result
