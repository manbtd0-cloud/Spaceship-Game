from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from small_fighter_calibration import (  # noqa: E402
    CANONICAL_LENGTH_METERS,
    COLLIDER_SIZE_GODOT,
    EXPECTED_DIMENSIONS_GODOT,
    HULL_CENTER_LOCAL,
    PLUME_GROUPS,
    SOCKET_COUNTS,
    SOURCE_FRAME_OBJECT,
    SOURCE_SHA256,
    classify_socket_name,
    connected_components,
    principal_axis,
)


class CalibrationTests(unittest.TestCase):
    def test_approved_constants_are_exact(self) -> None:
        self.assertEqual(
            SOURCE_SHA256,
            "1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478",
        )
        self.assertEqual(SOURCE_FRAME_OBJECT, "Cube")
        self.assertEqual(HULL_CENTER_LOCAL, (0.0, -0.5693, 0.5081))
        self.assertEqual(CANONICAL_LENGTH_METERS, 12.0)
        self.assertEqual(EXPECTED_DIMENSIONS_GODOT, (13.714, 3.562, 12.0))
        self.assertEqual(COLLIDER_SIZE_GODOT, (14.0, 3.8, 12.2))

    def test_plume_groups_account_for_twelve_sockets(self) -> None:
        self.assertEqual(PLUME_GROUPS["EngineFire"]["components"], 2)
        self.assertEqual(
            sum(int(value["components"]) for value in PLUME_GROUPS.values()),
            12,
        )
        class_counts = {name: 0 for name in SOCKET_COUNTS}
        for value in PLUME_GROUPS.values():
            class_counts[str(value["class"])] += int(value["components"])
        self.assertEqual(class_counts, SOCKET_COUNTS)

    def test_connected_components_are_deterministic(self) -> None:
        self.assertEqual(
            connected_components(7, [(0, 1), (1, 2), (4, 5), (5, 6)]),
            [[0, 1, 2], [4, 5, 6]],
        )

    def test_principal_axis_follows_long_distribution(self) -> None:
        axis = principal_axis(
            [(0.0, -4.0, 0.0), (0.0, 0.0, 0.0), (0.0, 5.0, 0.0)]
        )
        self.assertGreater(abs(axis[1]), 0.9999)
        self.assertLess(abs(axis[0]), 0.0001)
        self.assertLess(abs(axis[2]), 0.0001)

    def test_socket_names_are_semantic_and_unique(self) -> None:
        names = {
            classify_socket_name("Main", (-1.0, 0.0, 0.0)),
            classify_socket_name("Main", (1.0, 0.0, 0.0)),
            classify_socket_name("Retro", (-1.0, 0.0, 0.0)),
            classify_socket_name("Retro", (1.0, 0.0, 0.0)),
        }
        for group in ("FrontUpper", "RearUpper", "RearLower", "FrontLower"):
            names.add(classify_socket_name(group, (-1.0, 0.0, 0.0)))
            names.add(classify_socket_name(group, (1.0, 0.0, 0.0)))
        self.assertEqual(len(names), 12)


if __name__ == "__main__":
    unittest.main(verbosity=2)
