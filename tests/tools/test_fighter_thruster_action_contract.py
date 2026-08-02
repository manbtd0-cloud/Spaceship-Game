from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from fighter_thruster_action_contract import validate_matrix  # noqa: E402
from generate_fighter_thruster_action_matrix import build_matrix  # noqa: E402

MATRIX_PATH = (
    REPO_ROOT
    / "config"
    / "ships"
    / "small_sci_fi_fighter_thruster_actions.json"
)
MANIFEST_PATH = (
    REPO_ROOT
    / "assets"
    / "runtime"
    / "ships"
    / "player"
    / "small_sci_fi_fighter.manifest.json"
)


class FighterThrusterActionContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.matrix = json.loads(MATRIX_PATH.read_text(encoding="utf-8-sig"))
        self.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8-sig"))

    def test_checked_in_matrix_is_physically_valid(self) -> None:
        self.assertEqual(validate_matrix(self.matrix, self.manifest), [])

    def test_forward_requires_equal_main_thrusters(self) -> None:
        broken = copy.deepcopy(self.matrix)
        forward = next(
            record for record in broken["actions"] if record["action"] == "forward"
        )
        forward["weights"]["Main/MainRight"] = 0.5
        errors = validate_matrix(broken, self.manifest)
        self.assertTrue(
            any("symmetric" in error for error in errors),
            errors,
        )

    def test_runtime_generation_and_unknown_paths_are_rejected(self) -> None:
        broken = copy.deepcopy(self.matrix)
        broken["runtime_generated"] = True
        broken["actions"][0]["weights"]["Unknown/Thruster"] = 1.0
        errors = validate_matrix(broken, self.manifest)
        self.assertTrue(any("runtime_generated false" in error for error in errors))
        self.assertTrue(any("unknown socket path" in error for error in errors))

    def test_generator_is_deterministic_and_preserves_symmetric_forward_pair(self) -> None:
        first = build_matrix(self.manifest)
        second = build_matrix(self.manifest)
        self.assertEqual(first, second)
        forward = next(
            record for record in first["actions"] if record["action"] == "forward"
        )
        self.assertEqual(
            forward["weights"],
            {
                "Main/MainLeft": 1.0,
                "Main/MainRight": 1.0,
            },
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
