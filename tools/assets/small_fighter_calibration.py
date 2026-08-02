from __future__ import annotations

import math

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
    "EngineFire": {"sockets": 2, "class": "main", "group": "Main"},
    "EngineFire.001": {"sockets": 1, "class": "retro", "group": "Retro"},
    "EngineFire.004": {"sockets": 1, "class": "retro", "group": "Retro"},
    "EngineFire.002": {"sockets": 1, "class": "maneuver", "group": "FrontUpper"},
    "EngineFire.003": {"sockets": 1, "class": "maneuver", "group": "FrontUpper"},
    "EngineFire.005": {"sockets": 1, "class": "maneuver", "group": "RearUpper"},
    "EngineFire.006": {"sockets": 1, "class": "maneuver", "group": "RearUpper"},
    "EngineFire.007": {"sockets": 1, "class": "maneuver", "group": "RearLower"},
    "EngineFire.008": {"sockets": 1, "class": "maneuver", "group": "RearLower"},
    "EngineFire.009": {"sockets": 1, "class": "maneuver", "group": "FrontLower"},
    "EngineFire.010": {"sockets": 1, "class": "maneuver", "group": "FrontLower"},
}

Point3 = tuple[float, float, float]


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


def _centroid(points: list[Point3]) -> Point3:
    if not points:
        raise ValueError("component point cloud must not be empty")
    return tuple(
        sum(point[axis] for point in points) / len(points)
        for axis in range(3)
    )


def _distance(left: Point3, right: Point3) -> float:
    return math.sqrt(
        sum((left[axis] - right[axis]) ** 2 for axis in range(3))
    )


def group_spatial_components(
    components: list[list[Point3]],
    expected_groups: int,
) -> list[list[Point3]]:
    """Merge layered mesh islands into distinct physical plume point clouds."""
    if expected_groups <= 0:
        raise ValueError("expected_groups must be positive")
    if len(components) < expected_groups:
        raise ValueError(
            f"cannot form {expected_groups} plume groups from {len(components)} components"
        )
    if any(not component for component in components):
        raise ValueError("component point clouds must not be empty")

    component_centroids = [_centroid(component) for component in components]
    clusters: list[list[int]] = [[index] for index in range(len(components))]

    def cluster_centroid(cluster: list[int]) -> Point3:
        points = [
            point
            for component_index in cluster
            for point in components[component_index]
        ]
        return _centroid(points)

    while len(clusters) > expected_groups:
        best: tuple[float, int, int] | None = None
        for left_index in range(len(clusters)):
            left_center = cluster_centroid(clusters[left_index])
            for right_index in range(left_index + 1, len(clusters)):
                candidate = (
                    _distance(
                        left_center,
                        cluster_centroid(clusters[right_index]),
                    ),
                    left_index,
                    right_index,
                )
                if best is None or candidate < best:
                    best = candidate
        if best is None:
            raise ValueError("failed to select plume component clusters")
        _, left_index, right_index = best
        merged = sorted(clusters[left_index] + clusters[right_index])
        clusters = [
            cluster
            for index, cluster in enumerate(clusters)
            if index not in {left_index, right_index}
        ]
        clusters.append(merged)
        clusters.sort(key=lambda cluster: tuple(cluster))

    group_centroids = [cluster_centroid(cluster) for cluster in clusters]
    maximum_cluster_radius = 0.0
    for cluster, center in zip(clusters, group_centroids):
        for component_index in cluster:
            maximum_cluster_radius = max(
                maximum_cluster_radius,
                _distance(component_centroids[component_index], center),
            )

    minimum_inter_distance = float("inf")
    for left_index, left_center in enumerate(group_centroids):
        for right_center in group_centroids[left_index + 1 :]:
            minimum_inter_distance = min(
                minimum_inter_distance,
                _distance(left_center, right_center),
            )

    if expected_groups > 1 and minimum_inter_distance <= max(
        maximum_cluster_radius * 3.0,
        1e-5,
    ):
        raise ValueError(
            "plume component groups are not spatially distinct: "
            f"minimum_inter={minimum_inter_distance:.6f}, "
            f"maximum_cluster_radius={maximum_cluster_radius:.6f}, "
            f"centroids={group_centroids}"
        )

    grouped = [
        [
            point
            for component_index in cluster
            for point in components[component_index]
        ]
        for cluster in clusters
    ]
    grouped.sort(key=_centroid)
    return grouped


def _normalize(vector: Point3) -> Point3:
    length = sum(component * component for component in vector) ** 0.5
    if length <= 1e-12:
        raise ValueError("cannot normalize zero vector")
    return tuple(component / length for component in vector)


def principal_axis(points: list[Point3]) -> Point3:
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


def classify_socket_name(group: str, position: Point3) -> str:
    side = "Left" if position[0] < 0.0 else "Right"
    if group == "Main":
        return f"Thrusters/Main/Main{side}"
    if group == "Retro":
        return f"Thrusters/Retro/Retro{side}"
    if group in {"FrontUpper", "RearUpper", "RearLower", "FrontLower"}:
        return f"Thrusters/Maneuver/{group}{side}"
    raise ValueError(f"unsupported socket group: {group}")
