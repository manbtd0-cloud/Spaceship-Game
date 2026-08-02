from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from nozzle_local_geometry import (  # noqa: E402
    canonical_vertices_to_nozzle_local,
    max_vertex_error,
    reconstruct_canonical_vertices,
)
from small_fighter_calibration import group_spatial_component_indices  # noqa: E402
from thruster_paths import classify_effect_name  # noqa: E402


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
            "ThrusterEffects/MainEffects/MainLeftEffect",
        )
        self.assertEqual(
            classify_effect_name("Retro", (1.0, 0.0, 0.0)),
            "ThrusterEffects/RetroEffects/RetroRightEffect",
        )
        self.assertEqual(
            classify_effect_name("FrontUpper", (-1.0, 0.0, 0.0)),
            "ThrusterEffects/ManeuverEffects/FrontUpperLeftEffect",
        )

    def test_nozzle_local_conversion_reconstructs_canonical_vertices(self) -> None:
        canonical = [(2.0, 3.0, 4.0), (2.0, 3.0, 6.0)]
        origin = (2.0, 3.0, 4.0)
        basis_rows = (
            (1.0, 0.0, 0.0),
            (0.0, 1.0, 0.0),
            (0.0, 0.0, 1.0),
        )
        local = canonical_vertices_to_nozzle_local(
            canonical,
            origin,
            basis_rows,
        )
        reconstructed = reconstruct_canonical_vertices(
            local,
            origin,
            basis_rows,
        )
        self.assertEqual(local, [(0.0, 0.0, 0.0), (0.0, 0.0, 2.0)])
        self.assertLess(max_vertex_error(canonical, reconstructed), 1e-9)

    def test_nozzle_local_conversion_supports_rotated_basis(self) -> None:
        canonical = [(4.0, 2.0, 3.0), (6.0, 2.0, 3.0)]
        origin = (4.0, 2.0, 3.0)
        basis_rows = (
            (0.0, 0.0, 1.0),
            (0.0, 1.0, 0.0),
            (-1.0, 0.0, 0.0),
        )
        local = canonical_vertices_to_nozzle_local(
            canonical,
            origin,
            basis_rows,
        )
        reconstructed = reconstruct_canonical_vertices(
            local,
            origin,
            basis_rows,
        )
        self.assertLess(max_vertex_error(canonical, reconstructed), 1e-9)

    def test_exporters_contain_exact_mesh_pipeline_and_no_procedural_cones(self) -> None:
        v3_orchestrator = ASSET_TOOLS / "export_small_sci_fi_fighter_v3.py"
        v4_orchestrator = ASSET_TOOLS / "export_small_sci_fi_fighter_v4.py"
        geometry_builder = ASSET_TOOLS / "source_exact_thruster_geometry.py"
        v3_source = v3_orchestrator.read_text(encoding="utf-8")
        v4_source = v4_orchestrator.read_text(encoding="utf-8")
        geometry_source = geometry_builder.read_text(encoding="utf-8")
        ast.parse(v3_source)
        ast.parse(v4_source)
        ast.parse(geometry_source)
        self.assertIn('"schema_version": 3', v3_source)
        self.assertIn('"schema_version": 4', v4_source)
        self.assertIn("ThrusterEffects", geometry_source)
        self.assertIn("source_component_indices", geometry_source)
        self.assertIn("geometry_sha256", geometry_source)
        self.assertIn("maximum_reconstruction_error_m", v4_source)
        self.assertIn("from_pydata", geometry_source)
        self.assertNotIn("CylinderMesh", v3_source + v4_source + geometry_source)

    def test_blender_entrypoints_bootstrap_sibling_module_imports(self) -> None:
        for name in (
            "export_small_sci_fi_fighter_v3.py",
            "export_small_sci_fi_fighter_v4.py",
        ):
            orchestrator = ASSET_TOOLS / name
            source = orchestrator.read_text(encoding="utf-8")
            self.assertIn("SCRIPT_DIR = Path(__file__).resolve().parent", source)
            self.assertIn("sys.path.insert(0, str(SCRIPT_DIR))", source)
            self.assertLess(
                source.index("sys.path.insert(0, str(SCRIPT_DIR))"),
                source.index("import export_small_sci_fi_fighter as base"),
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
