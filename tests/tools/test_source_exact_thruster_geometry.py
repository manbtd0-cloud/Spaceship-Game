from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from small_fighter_calibration import (  # noqa: E402
    classify_effect_name,
    group_spatial_component_indices,
)


class SourceExactThrusterGeometryTests(unittest.TestCase):
    def test_layered_main_shells_preserve_raw_component_indices(self) -> None:
        components = [
            [(-3.00, -2.0, 0.0), (-3.00, 2.0, 0.0)],
            [(-3.08, -2.0, 0.1), (-3.08, 2.0, 0.1)],
            [(3.00, -2.0, 0.0), (3.00, 2.0, 0.0)],
            [(3.07, -2.0, -0.1), (3.07, 2.0, -0.1)],
        ]
        groups = group_spatial_component_indices(components, expected_groups=2)
        self.assertEqual(groups, [[0, 1], [2, 3]])

    def test_single_plume_preserves_its_only_component(self) -> None:
        components = [[(0.0, 0.0, 0.0), (0.0, 3.0, 0.0)]]
        self.assertEqual(
            group_spatial_component_indices(components, expected_groups=1),
            [[0]],
        )

    def test_effect_paths_are_unique_and_semantic(self) -> None:
        self.assertEqual(
            classify_effect_name("Main", (-1.0, 0.0, 0.0)),
            "ThrusterEffects/Main/MainLeftEffect",
        )
        self.assertEqual(
            classify_effect_name("Retro", (1.0, 0.0, 0.0)),
            "ThrusterEffects/Retro/RetroRightEffect",
        )
        self.assertEqual(
            classify_effect_name("FrontUpper", (-1.0, 0.0, 0.0)),
            "ThrusterEffects/Maneuver/FrontUpperLeftEffect",
        )

    def test_exporter_contains_exact_mesh_pipeline_and_no_procedural_cones(self) -> None:
        orchestrator = ASSET_TOOLS / "export_small_sci_fi_fighter_v3.py"
        geometry_builder = ASSET_TOOLS / "source_exact_thruster_geometry.py"
        orchestrator_source = orchestrator.read_text(encoding="utf-8")
        geometry_source = geometry_builder.read_text(encoding="utf-8")
        ast.parse(orchestrator_source)
        ast.parse(geometry_source)
        self.assertIn("schema_version\": 3", orchestrator_source)
        self.assertIn("ThrusterEffects", geometry_source)
        self.assertIn("source_component_indices", geometry_source)
        self.assertIn("geometry_sha256", geometry_source)
        self.assertIn("from_pydata", geometry_source)
        self.assertNotIn("CylinderMesh", orchestrator_source + geometry_source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
