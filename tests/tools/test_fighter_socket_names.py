from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from canonical_fighter_contract import EXPECTED_SOCKET_PATHS  # noqa: E402
from small_fighter_calibration import classify_socket_name  # noqa: E402


class FighterSocketNameTests(unittest.TestCase):
    def test_main_and_retro_leaves_are_globally_unique_in_blender(self) -> None:
        self.assertEqual(
            classify_socket_name("Main", (-1.0, 0.0, 0.0)),
            "Thrusters/Main/MainLeft",
        )
        self.assertEqual(
            classify_socket_name("Main", (1.0, 0.0, 0.0)),
            "Thrusters/Main/MainRight",
        )
        self.assertEqual(
            classify_socket_name("Retro", (-1.0, 0.0, 0.0)),
            "Thrusters/Retro/RetroLeft",
        )
        self.assertEqual(
            classify_socket_name("Retro", (1.0, 0.0, 0.0)),
            "Thrusters/Retro/RetroRight",
        )

    def test_maneuver_leaves_remain_unique_and_semantic(self) -> None:
        self.assertEqual(
            classify_socket_name("FrontUpper", (-1.0, 0.0, 0.0)),
            "Thrusters/Maneuver/FrontUpperLeft",
        )
        self.assertEqual(
            classify_socket_name("RearLower", (1.0, 0.0, 0.0)),
            "Thrusters/Maneuver/RearLowerRight",
        )

    def test_manifest_contract_uses_the_exact_twelve_runtime_paths(self) -> None:
        self.assertEqual(
            EXPECTED_SOCKET_PATHS,
            {
                "Thrusters/Main/MainLeft",
                "Thrusters/Main/MainRight",
                "Thrusters/Retro/RetroLeft",
                "Thrusters/Retro/RetroRight",
                "Thrusters/Maneuver/FrontUpperLeft",
                "Thrusters/Maneuver/FrontUpperRight",
                "Thrusters/Maneuver/RearUpperLeft",
                "Thrusters/Maneuver/RearUpperRight",
                "Thrusters/Maneuver/RearLowerLeft",
                "Thrusters/Maneuver/RearLowerRight",
                "Thrusters/Maneuver/FrontLowerLeft",
                "Thrusters/Maneuver/FrontLowerRight",
            },
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
