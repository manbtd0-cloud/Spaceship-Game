from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from canonical_fighter_contract import validate_output  # noqa: E402
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
    group_spatial_components,
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
        self.assertEqual(PLUME_GROUPS["EngineFire"]["sockets"], 2)
        self.assertEqual(
            sum(int(value["sockets"]) for value in PLUME_GROUPS.values()),
            12,
        )
        class_counts = {name: 0 for name in SOCKET_COUNTS}
        for value in PLUME_GROUPS.values():
            class_counts[str(value["class"])] += int(value["sockets"])
        self.assertEqual(class_counts, SOCKET_COUNTS)

    def test_connected_components_are_deterministic(self) -> None:
        self.assertEqual(
            connected_components(7, [(0, 1), (1, 2), (4, 5), (5, 6)]),
            [[0, 1, 2], [4, 5, 6]],
        )

    def test_layered_mesh_islands_merge_into_two_physical_plumes(self) -> None:
        components = [
            [(-3.00, -2.0, 0.0), (-3.00, 0.0, 0.0), (-3.00, 2.0, 0.0)],
            [(-3.08, -2.0, 0.1), (-3.08, 0.0, 0.1), (-3.08, 2.0, 0.1)],
            [(3.00, -2.0, 0.0), (3.00, 0.0, 0.0), (3.00, 2.0, 0.0)],
            [(3.07, -2.0, -0.1), (3.07, 0.0, -0.1), (3.07, 2.0, -0.1)],
        ]
        grouped = group_spatial_components(components, expected_groups=2)
        self.assertEqual(len(grouped), 2)
        centroids_x = sorted(
            sum(point[0] for point in group) / len(group)
            for group in grouped
        )
        self.assertLess(centroids_x[0], -3.0)
        self.assertGreater(centroids_x[1], 3.0)
        self.assertEqual(sorted(len(group) for group in grouped), [6, 6])

    def test_ambiguous_component_grouping_is_rejected(self) -> None:
        components = [
            [(0.0, -1.0, 0.0), (0.0, 1.0, 0.0)],
            [(1.0, -1.0, 0.0), (1.0, 1.0, 0.0)],
            [(2.0, -1.0, 0.0), (2.0, 1.0, 0.0)],
        ]
        with self.assertRaisesRegex(ValueError, "not spatially distinct"):
            group_spatial_components(components, expected_groups=2)

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

    def _write_valid_manifest(self, root: Path) -> tuple[Path, Path]:
        glb_path = root / "fighter.glb"
        glb_path.write_bytes(b"glTFfixture")
        socket_classes = (["main"] * 2) + (["retro"] * 2) + (["maneuver"] * 8)
        sockets = []
        for index, socket_class in enumerate(socket_classes):
            group = socket_class.capitalize() if socket_class != "maneuver" else "Maneuver"
            sockets.append(
                {
                    "path": f"Thrusters/{group}/Socket{index:02d}",
                    "class": socket_class,
                    "source_object": "EngineFire"
                    if index < 2
                    else f"EngineFire.{index:03d}",
                    "source_component": index,
                    "position": [float(index), 0.0, 0.0],
                    "exhaust_direction": [0.0, 0.0, -1.0],
                    "reaction_direction": [0.0, 0.0, 1.0],
                    "basis": [
                        [1.0, 0.0, 0.0],
                        [0.0, 1.0, 0.0],
                        [0.0, 0.0, 1.0],
                    ],
                }
            )
        manifest = {
            "schema_version": 2,
            "source_sha256": SOURCE_SHA256,
            "canonical_frame": {
                "godot_right": "+X",
                "godot_forward": "-Z",
                "godot_up": "+Y",
                "root_identity": True,
            },
            "dimensions_godot_xyz": [13.714, 3.562, 12.0],
            "collider_size_godot_xyz": [14.0, 3.8, 12.2],
            "removed_objects": ["EngineFire"]
            + [f"EngineFire.{index:03d}" for index in range(1, 11)],
            "sockets": sockets,
        }
        manifest_path = root / "fighter.manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        return glb_path, manifest_path

    def test_valid_canonical_output_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb_path, manifest_path = self._write_valid_manifest(Path(temporary))
            self.assertEqual(validate_output(glb_path, manifest_path, SOURCE_SHA256), [])

    def test_manifest_rejects_bad_root_and_socket_count(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb_path, manifest_path = self._write_valid_manifest(Path(temporary))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["canonical_frame"]["root_identity"] = False
            manifest["sockets"].pop()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_output(glb_path, manifest_path, SOURCE_SHA256)
            self.assertTrue(any("root_identity" in error for error in errors))
            self.assertTrue(any("socket count" in error for error in errors))

    def test_manifest_rejects_invalid_direction_and_duplicate_path(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb_path, manifest_path = self._write_valid_manifest(Path(temporary))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["sockets"][1]["path"] = manifest["sockets"][0]["path"]
            manifest["sockets"][0]["reaction_direction"] = [0.0, 0.0, -1.0]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_output(glb_path, manifest_path, SOURCE_SHA256)
            self.assertTrue(any("opposite" in error for error in errors))
            self.assertTrue(any("unique" in error for error in errors))

    def test_output_rejects_missing_glb_and_wrong_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb_path, manifest_path = self._write_valid_manifest(Path(temporary))
            glb_path.unlink()
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["dimensions_godot_xyz"][0] = 99.0
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_output(glb_path, manifest_path, SOURCE_SHA256)
            self.assertTrue(any("GLB missing" in error for error in errors))
            self.assertTrue(any("dimension X" in error for error in errors))

    def test_exporter_uses_canonical_frame_and_never_saves_source(self) -> None:
        exporter_path = ASSET_TOOLS / "export_small_sci_fi_fighter.py"
        source = exporter_path.read_text(encoding="utf-8")
        for forbidden in ("save_as_mainfile", "save_mainfile", "save_homefile"):
            self.assertNotIn(forbidden, source)
        self.assertIn("SOURCE_FRAME_OBJECT", source)
        self.assertIn("source_frame_inverse @ source.matrix_world", source)
        self.assertIn("group_spatial_components", source)
        self.assertIn("EngineFire", source)
        self.assertIn("export_extras=True", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
