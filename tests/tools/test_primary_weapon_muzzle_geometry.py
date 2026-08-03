from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from primary_weapon_muzzle_geometry import (  # noqa: E402
    BarrelComponentEvidence,
    MuzzleCandidate,
    classify_primary_muzzle_path,
    select_primary_barrel_component_pair,
    select_primary_muzzle_pair,
)


def candidate(
    name: str,
    x: float,
    y: float,
    z: float,
    radius: float = 0.20,
    normal: tuple[float, float, float] = (0.0, 1.0, 0.0),
) -> MuzzleCandidate:
    return MuzzleCandidate(
        source_object=name,
        source_vertex_indices=(1, 2, 3, 4, 5, 6, 7, 8),
        centroid=(x, y, z),
        normal=normal,
        radius=radius,
        planarity_error=0.001,
        circularity_ratio=1.05,
    )


def barrel(
    component: int,
    x: float,
    forward: float,
    z: float,
    *,
    length: float = 8.9,
    width: float = 0.88,
    height: float = 0.85,
) -> BarrelComponentEvidence:
    half_width = width * 0.5
    half_height = height * 0.5
    return BarrelComponentEvidence(
        source_object="Cube",
        source_material="Barrel",
        source_component=component,
        source_vertex_indices=tuple(range(component * 10, component * 10 + 8)),
        centroid=(x, forward - length * 0.5, z),
        bounds_min=(x - half_width, forward - length, z - half_height),
        bounds_max=(x + half_width, forward, z + half_height),
    )


class PrimaryWeaponMuzzleGeometryTests(unittest.TestCase):
    def test_selects_only_forward_symmetric_pair(self) -> None:
        left = candidate("Hull", -2.0, 10.0, 0.5)
        right = candidate("Hull", 2.0, 10.0, 0.5)
        noise = candidate("Hull", 0.2, 5.0, 0.0)
        selected = select_primary_muzzle_pair([noise, right, left])
        self.assertEqual(selected, (left, right))

    def test_rejects_ambiguous_pairs(self) -> None:
        pair_a = [
            candidate("Hull", -2.0, 10.0, 0.5),
            candidate("Hull", 2.0, 10.0, 0.5),
        ]
        pair_b = [
            candidate("Hull", -3.0, 10.0, 0.5),
            candidate("Hull", 3.0, 10.0, 0.5),
        ]
        with self.assertRaisesRegex(ValueError, "exactly one primary muzzle pair"):
            select_primary_muzzle_pair(pair_a + pair_b)

    def test_selects_uniquely_furthest_forward_barrel_pair(self) -> None:
        primary_left = barrel(2, -2.7368, 11.7362, 0.5808)
        primary_right = barrel(0, 2.7368, 11.7362, 0.5808)
        secondary_left = barrel(
            3,
            -3.4789,
            10.5734,
            0.0491,
            length=7.39,
            width=1.05,
            height=0.66,
        )
        secondary_right = barrel(
            1,
            3.4789,
            10.5734,
            0.0491,
            length=7.39,
            width=1.05,
            height=0.66,
        )
        selected = select_primary_barrel_component_pair(
            [secondary_right, primary_right, secondary_left, primary_left]
        )
        self.assertEqual(selected, (primary_left, primary_right))

    def test_rejects_ambiguous_frontmost_barrel_pairs(self) -> None:
        components = [
            barrel(0, 2.0, 11.70, 0.5),
            barrel(1, -2.0, 11.70, 0.5),
            barrel(2, 3.0, 11.55, 0.5),
            barrel(3, -3.0, 11.55, 0.5),
        ]
        with self.assertRaisesRegex(ValueError, "front-most.*ambiguous"):
            select_primary_barrel_component_pair(components)

    def test_classifies_left_and_right_paths(self) -> None:
        self.assertEqual(
            classify_primary_muzzle_path((-1.0, 0.0, 0.0)),
            "Weapons/Primary/LeftMuzzle",
        )
        self.assertEqual(
            classify_primary_muzzle_path((1.0, 0.0, 0.0)),
            "Weapons/Primary/RightMuzzle",
        )

    def test_rejects_centerline_path(self) -> None:
        with self.assertRaisesRegex(ValueError, "centerline"):
            classify_primary_muzzle_path((0.0, 0.0, 0.0))


if __name__ == "__main__":
    unittest.main(verbosity=2)
