from __future__ import annotations

SOURCE_SHA256 = "1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478"
SOURCE_FRAME_OBJECT = "Cube"
HULL_CENTER_LOCAL = (0.0, -0.5693, 0.5081)
SOURCE_HULL_DIMENSIONS = (28.1266, 24.6110, 7.3053)
CANONICAL_LENGTH_METERS = 12.0
UNIFORM_SCALE = CANONICAL_LENGTH_METERS / SOURCE_HULL_DIMENSIONS[1]
EXPECTED_DIMENSIONS_GODOT = (13.714, 3.562, 12.0)
COLLIDER_SIZE_GODOT = (14.0, 3.8, 12.2)
BOUNDS_TOLERANCE = 0.05
SOURCE_DIMENSION_TOLERANCE = 0.05
SOURCE_CENTER_TOLERANCE = 0.02
SOCKET_COUNTS = {"main": 2, "retro": 2, "maneuver": 8}

PLUME_GROUPS: dict[str, dict[str, object]] = {
    "EngineFire": {"components": 2, "class": "main", "group": "Main"},
    "EngineFire.001": {"components": 1, "class": "retro", "group": "Retro"},
    "EngineFire.004": {"components": 1, "class": "retro", "group": "Retro"},
    "EngineFire.002": {"components": 1, "class": "maneuver", "group": "FrontUpper"},
    "EngineFire.003": {"components": 1, "class": "maneuver", "group": "FrontUpper"},
    "EngineFire.005": {"components": 1, "class": "maneuver", "group": "RearUpper"},
    "EngineFire.006": {"components": 1, "class": "maneuver", "group": "RearUpper"},
    "EngineFire.007": {"components": 1, "class": "maneuver", "group": "RearLower"},
    "EngineFire.008": {"components": 1, "class": "maneuver", "group": "RearLower"},
    "EngineFire.009": {"components": 1, "class": "maneuver", "group": "FrontLower"},
    "EngineFire.010": {"components": 1, "class": "maneuver", "group": "FrontLower"},
}


def connected_components(vertex_count: int, edges: list[tuple[int, int]]) -> list[list[int]]:
    adjacency: list[set[int]] = [set() for _ in range(vertex_count)]
    referenced: set[int] = set()
    for left, right in edges:
        if left < 0 or right < 0 or left >= vertex_count or right >= vertex_count:
            raise ValueError(f"edge index out of range: {(left, right)}")
        adjacency[left].add(right)
        adjacency[right].add(left)
        referenced.add(left)
        referenced.add(right)

    components: list[list[int]] = []
    visited: set[int] = set()
    for start in sorted(referenced):
        if start in visited:
            continue
        queue = [start]
        visited.add(start)
        component: list[int] = []
        while queue:
            current = queue.pop(0)
            component.append(current)
            for neighbor in sorted(adjacency[current]):
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        components.append(sorted(component))
    components.sort(key=lambda component: component[0])
    return components


def _normalize(vector: tuple[float, float, float]) -> tuple[float, float, float]:
    length = sum(component * component for component in vector) ** 0.5
    if length <= 1e-12:
        raise ValueError("cannot normalize zero vector")
    return tuple(component / length for component in vector)


def principal_axis(points: list[tuple[float, float, float]]) -> tuple[float, float, float]:
    if len(points) < 2:
        raise ValueError("at least two points are required")
    centroid = tuple(sum(point[index] for point in points) / len(points) for index in range(3))
    covariance = [[0.0] * 3 for _ in range(3)]
    for point in points:
        centered = tuple(point[index] - centroid[index] for index in range(3))
        for row in range(3):
            for column in range(3):
                covariance[row][column] += centered[row] * centered[column]

    minimum = tuple(min(point[index] for point in points) for index in range(3))
    maximum = tuple(max(point[index] for point in points) for index in range(3))
    spans = tuple(maximum[index] - minimum[index] for index in range(3))
    longest_axis = max(range(3), key=lambda index: spans[index])
    vector = tuple(1.0 if index == longest_axis else 0.0 for index in range(3))
    for _ in range(32):
        multiplied = tuple(
            sum(covariance[row][column] * vector[column] for column in range(3))
            for row in range(3)
        )
        vector = _normalize(multiplied)
    return vector


def classify_socket_name(group: str, position: tuple[float, float, float]) -> str:
    side = "Left" if position[0] < 0.0 else "Right"
    if group in {"Main", "Retro"}:
        return f"Thrusters/{group}/{side}"
    if group in {"FrontUpper", "RearUpper", "RearLower", "FrontLower"}:
        return f"Thrusters/Maneuver/{group}{side}"
    raise ValueError(f"unsupported socket group: {group}")
