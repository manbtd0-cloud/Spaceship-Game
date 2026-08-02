from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

from fighter_thruster_action_contract import (
    CLASS_CAPACITY,
    EXPECTED_ACTIONS,
    TARGETS,
    _add,
    _cross,
    _dot,
    _length,
    _scale,
    load_socket_capabilities,
    validate_matrix,
)

ACTION_WEIGHTS: dict[str, dict[str, float]] = {
    "forward": {
        "Main/MainLeft": 1.0,
        "Main/MainRight": 1.0,
    },
    "reverse": {
        "Retro/RetroLeft": 1.0,
        "Retro/RetroRight": 1.0,
    },
    "strafe_left": {
        "Maneuver/FrontLowerRight": 1.0,
        "Maneuver/FrontUpperRight": 1.0,
        "Maneuver/RearLowerRight": 1.0,
        "Maneuver/RearUpperRight": 1.0,
    },
    "strafe_right": {
        "Maneuver/FrontLowerLeft": 1.0,
        "Maneuver/FrontUpperLeft": 1.0,
        "Maneuver/RearLowerLeft": 1.0,
        "Maneuver/RearUpperLeft": 1.0,
    },
    "strafe_up": {
        "Maneuver/FrontLowerLeft": 1.0,
        "Maneuver/FrontLowerRight": 1.0,
        "Maneuver/RearLowerLeft": 1.0,
        "Maneuver/RearLowerRight": 1.0,
    },
    "strafe_down": {
        "Maneuver/FrontUpperLeft": 1.0,
        "Maneuver/FrontUpperRight": 1.0,
        "Maneuver/RearUpperLeft": 1.0,
        "Maneuver/RearUpperRight": 1.0,
    },
    "pitch_up": {
        "Maneuver/FrontLowerLeft": 0.46,
        "Maneuver/FrontLowerRight": 0.47,
        "Maneuver/RearUpperLeft": 0.54,
        "Maneuver/RearUpperRight": 0.56,
    },
    "pitch_down": {
        "Maneuver/FrontUpperLeft": 0.56,
        "Maneuver/FrontUpperRight": 0.58,
        "Maneuver/RearLowerLeft": 0.53,
        "Maneuver/RearLowerRight": 0.59,
    },
    "yaw_left": {
        "Maneuver/FrontLowerRight": 0.86,
        "Maneuver/FrontUpperRight": 1.0,
        "Maneuver/RearLowerLeft": 0.79,
        "Maneuver/RearUpperLeft": 0.77,
    },
    "yaw_right": {
        "Maneuver/FrontLowerLeft": 0.88,
        "Maneuver/FrontUpperLeft": 1.0,
        "Maneuver/RearLowerRight": 0.83,
        "Maneuver/RearUpperRight": 0.85,
    },
    "roll_left": {
        "Maneuver/FrontLowerRight": 1.0,
        "Maneuver/FrontUpperLeft": 1.0,
        "Maneuver/RearLowerRight": 1.0,
        "Maneuver/RearUpperLeft": 1.0,
    },
    "roll_right": {
        "Maneuver/FrontLowerLeft": 1.0,
        "Maneuver/FrontUpperRight": 1.0,
        "Maneuver/RearLowerLeft": 1.0,
        "Maneuver/RearUpperRight": 1.0,
    },
}


def build_matrix(manifest: dict[str, Any]) -> dict[str, Any]:
    capabilities = load_socket_capabilities(manifest)
    if len(capabilities) != 12:
        raise ValueError(
            f"expected 12 canonical socket capabilities, got {len(capabilities)}"
        )

    records: list[dict[str, Any]] = []
    for action in EXPECTED_ACTIONS:
        weights = ACTION_WEIGHTS[action]
        result_force = (0.0, 0.0, 0.0)
        result_torque = (0.0, 0.0, 0.0)
        for path, weight in weights.items():
            socket = capabilities[path]
            force = _scale(
                socket["reaction_direction"],
                float(socket.get("capacity", CLASS_CAPACITY["maneuver"])) * weight,
            )
            result_force = _add(result_force, force)
            result_torque = _add(
                result_torque,
                _cross(socket["position"], force),
            )

        domain, target = TARGETS[action]
        selected = result_force if domain == "force" else result_torque
        target_amount = _dot(selected, target)
        alignment = target_amount / max(_length(selected), 1e-9)
        cross_vector = _add(selected, _scale(target, -target_amount))
        cross_axis_ratio = _length(cross_vector) / max(abs(target_amount), 1e-9)
        records.append(
            {
                "action": action,
                "weights": dict(sorted(weights.items())),
                "result_force": [round(value, 8) for value in result_force],
                "result_torque": [round(value, 8) for value in result_torque],
                "alignment": round(alignment, 8),
                "cross_axis_ratio": round(cross_axis_ratio, 8),
            }
        )

    output = {
        "schema_version": 1,
        "asset": "Small Sci-Fi Fighter",
        "runtime_generated": False,
        "source_schema_version": int(manifest.get("schema_version", 0)),
        "actions": records,
    }
    errors = validate_matrix(output, manifest)
    if errors:
        raise ValueError("; ".join(errors))
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    matrix = build_matrix(manifest)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(matrix, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    print(f"Generated deterministic twelve-action matrix: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
