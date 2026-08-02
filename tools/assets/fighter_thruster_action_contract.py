from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

EXPECTED_ACTIONS = (
    "forward",
    "reverse",
    "strafe_left",
    "strafe_right",
    "strafe_up",
    "strafe_down",
    "pitch_up",
    "pitch_down",
    "yaw_left",
    "yaw_right",
    "roll_left",
    "roll_right",
)

KNOWN_SOCKET_PATHS = {
    "Main/MainLeft",
    "Main/MainRight",
    "Retro/RetroLeft",
    "Retro/RetroRight",
    "Maneuver/FrontUpperLeft",
    "Maneuver/FrontUpperRight",
    "Maneuver/RearUpperLeft",
    "Maneuver/RearUpperRight",
    "Maneuver/RearLowerLeft",
    "Maneuver/RearLowerRight",
    "Maneuver/FrontLowerLeft",
    "Maneuver/FrontLowerRight",
}

CLASS_CAPACITY = {
    "main": 0.55,
    "retro": 0.35,
    "maneuver": 0.22,
}

TARGETS: dict[str, tuple[str, tuple[float, float, float]]] = {
    "forward": ("force", (0.0, 0.0, -1.0)),
    "reverse": ("force", (0.0, 0.0, 1.0)),
    "strafe_left": ("force", (-1.0, 0.0, 0.0)),
    "strafe_right": ("force", (1.0, 0.0, 0.0)),
    "strafe_up": ("force", (0.0, 1.0, 0.0)),
    "strafe_down": ("force", (0.0, -1.0, 0.0)),
    "pitch_up": ("torque", (1.0, 0.0, 0.0)),
    "pitch_down": ("torque", (-1.0, 0.0, 0.0)),
    "yaw_left": ("torque", (0.0, 1.0, 0.0)),
    "yaw_right": ("torque", (0.0, -1.0, 0.0)),
    "roll_left": ("torque", (0.0, 0.0, 1.0)),
    "roll_right": ("torque", (0.0, 0.0, -1.0)),
}


def _add(left: tuple[float, float, float], right: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(left[index] + right[index] for index in range(3))  # type: ignore[return-value]


def _scale(value: tuple[float, float, float], amount: float) -> tuple[float, float, float]:
    return tuple(component * amount for component in value)  # type: ignore[return-value]


def _dot(left: tuple[float, float, float], right: tuple[float, float, float]) -> float:
    return sum(left[index] * right[index] for index in range(3))


def _length(value: tuple[float, float, float]) -> float:
    return math.sqrt(_dot(value, value))


def _cross(left: tuple[float, float, float], right: tuple[float, float, float]) -> tuple[float, float, float]:
    return (
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    )


def normalize_socket_path(path: str) -> str:
    normalized = path.removeprefix("Thrusters/")
    aliases = {
        "Main/Left": "Main/MainLeft",
        "Main/Right": "Main/MainRight",
        "Retro/Left": "Retro/RetroLeft",
        "Retro/Right": "Retro/RetroRight",
    }
    return aliases.get(normalized, normalized)


def load_socket_capabilities(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    capabilities: dict[str, dict[str, Any]] = {}
    for raw_socket in manifest.get("sockets", []):
        if not isinstance(raw_socket, dict):
            continue
        path = normalize_socket_path(str(raw_socket.get("path", "")))
        if path not in KNOWN_SOCKET_PATHS:
            continue
        position = raw_socket.get("position")
        direction = raw_socket.get("reaction_direction")
        thruster_class = str(raw_socket.get("class", ""))
        if not (
            isinstance(position, list)
            and isinstance(direction, list)
            and len(position) == 3
            and len(direction) == 3
            and thruster_class in CLASS_CAPACITY
        ):
            continue
        capabilities[path] = {
            "position": tuple(float(value) for value in position),
            "reaction_direction": tuple(float(value) for value in direction),
            "capacity": float(raw_socket.get("capacity", CLASS_CAPACITY[thruster_class])),
        }
    return capabilities


def validate_matrix(
    matrix: dict[str, Any],
    manifest: dict[str, Any] | None = None,
) -> list[str]:
    errors: list[str] = []
    if matrix.get("schema_version") != 1:
        errors.append("matrix schema_version must be 1")
    if matrix.get("runtime_generated") is not False:
        errors.append("matrix must declare runtime_generated false")

    records = matrix.get("actions")
    if not isinstance(records, list):
        return errors + ["actions must be a list"]

    by_name: dict[str, dict[str, float]] = {}
    for record in records:
        if not isinstance(record, dict):
            errors.append("every action record must be an object")
            continue
        action = str(record.get("action", ""))
        if action not in EXPECTED_ACTIONS:
            errors.append(f"unknown action: {action}")
            continue
        if action in by_name:
            errors.append(f"duplicate action: {action}")
            continue
        raw_weights = record.get("weights")
        if not isinstance(raw_weights, dict) or not raw_weights:
            errors.append(f"{action}: weights must be a non-empty object")
            continue
        weights: dict[str, float] = {}
        for raw_path, raw_weight in raw_weights.items():
            path = str(raw_path)
            if path not in KNOWN_SOCKET_PATHS:
                errors.append(f"{action}: unknown socket path {path}")
                continue
            try:
                weight = float(raw_weight)
            except (TypeError, ValueError):
                errors.append(f"{action}: non-numeric weight for {path}")
                continue
            if not math.isfinite(weight) or not 0.0 < weight <= 1.0:
                errors.append(f"{action}: weight for {path} must be in (0, 1]")
                continue
            weights[path] = weight
        by_name[action] = weights

    missing = sorted(set(EXPECTED_ACTIONS) - set(by_name))
    if missing:
        errors.append(f"missing actions: {', '.join(missing)}")

    forward = by_name.get("forward", {})
    if set(forward) != {"Main/MainLeft", "Main/MainRight"}:
        errors.append("forward must use exactly the two main thrusters")
    elif not math.isclose(
        forward["Main/MainLeft"],
        forward["Main/MainRight"],
        rel_tol=1e-7,
        abs_tol=1e-7,
    ):
        errors.append("forward main-thruster weights must be symmetric")

    reverse = by_name.get("reverse", {})
    if set(reverse) != {"Retro/RetroLeft", "Retro/RetroRight"}:
        errors.append("reverse must use exactly the two retro thrusters")

    if manifest is None:
        return errors

    capabilities = load_socket_capabilities(manifest)
    missing_sockets = sorted(KNOWN_SOCKET_PATHS - set(capabilities))
    if missing_sockets:
        errors.append(f"manifest missing socket capabilities: {', '.join(missing_sockets)}")
        return errors

    for action in EXPECTED_ACTIONS:
        weights = by_name.get(action)
        if not weights:
            continue
        result_force = (0.0, 0.0, 0.0)
        result_torque = (0.0, 0.0, 0.0)
        for path, weight in weights.items():
            socket = capabilities[path]
            force = _scale(
                socket["reaction_direction"],
                socket["capacity"] * weight,
            )
            result_force = _add(result_force, force)
            result_torque = _add(
                result_torque,
                _cross(socket["position"], force),
            )

        domain, target = TARGETS[action]
        result = result_force if domain == "force" else result_torque
        target_amount = _dot(result, target)
        result_length = _length(result)
        if target_amount <= 0.0 or result_length <= 1e-9:
            errors.append(f"{action}: selected thrusters have the wrong target sign")
            continue
        alignment = target_amount / result_length
        cross_vector = _add(result, _scale(target, -target_amount))
        cross_axis_ratio = _length(cross_vector) / max(abs(target_amount), 1e-9)
        if alignment < 0.85:
            errors.append(f"{action}: alignment {alignment:.6f} is below 0.85")
        if cross_axis_ratio > 0.35:
            errors.append(
                f"{action}: cross-axis ratio {cross_axis_ratio:.6f} exceeds 0.35"
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--matrix", required=True, type=Path)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()

    matrix = json.loads(args.matrix.read_text(encoding="utf-8-sig"))
    manifest = (
        json.loads(args.manifest.read_text(encoding="utf-8-sig"))
        if args.manifest is not None
        else None
    )
    errors = validate_matrix(matrix, manifest)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Deterministic fighter thruster action matrix validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
