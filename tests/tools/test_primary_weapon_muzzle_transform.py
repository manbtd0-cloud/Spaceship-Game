from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from primary_weapon_muzzle_transform import (  # noqa: E402
    blender_basis_to_canonical_rows,
    canonical_basis_to_blender_rows,
    canonical_origin_to_blender,
)

IDENTITY = (
    (1.0, 0.0, 0.0),
    (0.0, 1.0, 0.0),
    (0.0, 0.0, 1.0),
)


class PrimaryWeaponMuzzleTransformTests(unittest.TestCase):
    def test_canonical_identity_remains_blender_identity(self) -> None:
        self.assertEqual(canonical_basis_to_blender_rows(IDENTITY), IDENTITY)

    def test_basis_conversion_round_trips(self) -> None:
        canonical = (
            (0.0, 0.0, 1.0),
            (0.0, 1.0, 0.0),
            (-1.0, 0.0, 0.0),
        )
        blender = canonical_basis_to_blender_rows(canonical)
        self.assertEqual(blender_basis_to_canonical_rows(blender), canonical)

    def test_origin_conversion_is_inverse_of_x_z_negative_y_mapping(self) -> None:
        self.assertEqual(
            canonical_origin_to_blender((2.0, 3.0, -4.0)),
            (2.0, 4.0, 3.0),
        )

    def test_invalid_values_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "three rows"):
            canonical_basis_to_blender_rows(((1.0, 0.0, 0.0),))
        with self.assertRaisesRegex(ValueError, "finite"):
            canonical_origin_to_blender((0.0, float("nan"), 0.0))

    def test_schema_five_exporter_uses_canonical_basis_not_forward_tracking(
        self,
    ) -> None:
        source = (
            ASSET_TOOLS / "export_small_sci_fi_fighter_v5.py"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "canonical_basis_to_blender_rows(record.canonical_basis_rows)",
            source,
        )
        self.assertIn(
            "canonical_origin_to_blender(record.canonical_origin)",
            source,
        )
        self.assertIsNone(
            re.search(
                r"(?<![_A-Za-z0-9])record_to_blender_transform\(record\)",
                source,
            ),
            "schema-5 exporter must not call the legacy forward-tracking helper",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
