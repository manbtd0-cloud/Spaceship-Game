from __future__ import annotations

import math
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from primary_weapon_muzzle_extraction import (  # noqa: E402
    build_candidate_from_loop,
    choose_track_up_axis,
    derive_forward_tip,
    trace_boundary_loops,
)
from primary_weapon_muzzle_geometry import BarrelComponentEvidence  # noqa: E402


def ring(
    center: tuple[float, float, float],
    radius: float,
    count: int = 8,
    reverse: bool = False,
) -> list[tuple[float, float, float]]:
    values = [
        (
            center[0] + math.cos(index * math.tau / count) * radius,
            center[1],
            center[2] + math.sin(index * math.tau / count) * radius,
        )
        for index in range(count)
    ]
    return list(reversed(values)) if reverse else values


class PrimaryWeaponMuzzleExtractionTests(unittest.TestCase):
    def test_traces_two_closed_boundary_loops_deterministically(self) -> None:
        edges = [
            (0, 1),
            (1, 2),
            (2, 3),
            (3, 0),
            (4, 5),
            (5, 6),
            (6, 7),
            (7, 4),
        ]
        self.assertEqual(
            trace_boundary_loops(list(reversed(edges))),
            [(0, 1, 2, 3), (4, 5, 6, 7)],
        )

    def test_open_or_branching_boundary_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "closed degree-two loops"):
            trace_boundary_loops([(0, 1), (1, 2)])
        with self.assertRaisesRegex(ValueError, "closed degree-two loops"):
            trace_boundary_loops(
                [(0, 1), (1, 2), (1, 3), (2, 0), (3, 0)]
            )

    def test_builds_forward_circular_candidate(self) -> None:
        candidate = build_candidate_from_loop(
            "Hull",
            tuple(range(8)),
            ring((-2.0, 10.0, 0.5), 0.2),
            forward_axis=(0.0, 1.0, 0.0),
        )
        self.assertAlmostEqual(candidate.centroid[0], -2.0, places=6)
        self.assertAlmostEqual(candidate.centroid[1], 10.0, places=6)
        self.assertAlmostEqual(candidate.radius, 0.2, places=3)
        self.assertLess(candidate.planarity_error, 1e-6)
        self.assertLess(candidate.circularity_ratio, 1.01)
        self.assertGreater(candidate.normal[1], 0.99)

    def test_reversed_winding_still_orients_normal_forward(self) -> None:
        candidate = build_candidate_from_loop(
            "Hull",
            tuple(range(8)),
            ring((2.0, 10.0, 0.5), 0.2, reverse=True),
            forward_axis=(0.0, 1.0, 0.0),
        )
        self.assertGreater(candidate.normal[1], 0.99)

    def test_derives_tip_from_exact_forwardmost_source_vertices(self) -> None:
        component = BarrelComponentEvidence(
            source_object="Cube",
            source_material="Barrel",
            source_component=0,
            source_vertex_indices=(10, 11, 12, 13, 14),
            centroid=(2.7, 9.0, 0.5),
            bounds_min=(2.3, 2.8, 0.1),
            bounds_max=(3.2, 11.736176, 1.0),
        )
        points = [
            (2.6, 11.0, 0.4),
            (2.7, 11.736176, 0.5),
            (2.8, 11.736176, 0.7),
            (2.9, 11.3, 0.6),
            (2.5, 10.0, 0.3),
        ]
        tip = derive_forward_tip(component, points)
        self.assertEqual(tip.source_vertex_indices, (11, 12))
        self.assertAlmostEqual(tip.centroid[0], 2.75)
        self.assertAlmostEqual(tip.centroid[1], 11.736176)
        self.assertAlmostEqual(tip.centroid[2], 0.6)
        self.assertEqual(tip.forward, (0.0, 1.0, 0.0))
        self.assertLessEqual(tip.extraction_error_source, 0.000001)

    def test_tip_extraction_rejects_mismatched_source_evidence(self) -> None:
        component = BarrelComponentEvidence(
            source_object="Cube",
            source_material="Barrel",
            source_component=0,
            source_vertex_indices=(1, 2),
            centroid=(2.0, 10.0, 0.5),
            bounds_min=(1.5, 5.0, 0.0),
            bounds_max=(2.5, 11.0, 1.0),
        )
        with self.assertRaisesRegex(ValueError, "must match"):
            derive_forward_tip(component, [(2.0, 11.0, 0.5)])

    def test_track_up_axis_never_conflicts_with_local_negative_z(self) -> None:
        self.assertEqual(choose_track_up_axis((0.0, 1.0, 0.0)), "X")
        self.assertEqual(choose_track_up_axis((0.0, 0.0, 1.0)), "Y")

    def test_material_diagnostic_bootstraps_sibling_imports(self) -> None:
        path = ASSET_TOOLS / "diagnose_primary_weapon_material_components.py"
        source = path.read_text(encoding="utf-8")
        self.assertIn("SCRIPT_DIR = Path(__file__).resolve().parent", source)
        self.assertIn("sys.path.insert(0, str(SCRIPT_DIR))", source)
        self.assertLess(
            source.index("sys.path.insert(0, str(SCRIPT_DIR))"),
            source.index("import export_small_sci_fi_fighter as base"),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
