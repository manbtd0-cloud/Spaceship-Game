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

from canonical_fighter_contract_v3 import (  # noqa: E402
    EXPECTED_EFFECT_PATHS,
    EXPECTED_SOCKET_PATHS,
    validate_output,
)
from small_fighter_calibration import SOURCE_SHA256  # noqa: E402


class CanonicalFighterV3Tests(unittest.TestCase):
    def _write_valid_output(self, root: Path) -> tuple[Path, Path]:
        glb = root / "fighter.glb"
        glb.write_bytes(b"glTFfixture")

        socket_classes = (["main"] * 2) + (["retro"] * 2) + (["maneuver"] * 8)
        sockets = []
        for index, (path, socket_class) in enumerate(
            zip(sorted(EXPECTED_SOCKET_PATHS), socket_classes)
        ):
            sockets.append(
                {
                    "path": path,
                    "class": socket_class,
                    "source_object": "EngineFire" if index < 2 else f"EngineFire.{index:03d}",
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

        effect_classes = (["main"] * 2) + (["retro"] * 2) + (["maneuver"] * 8)
        effects = []
        for index, (path, effect_class) in enumerate(
            zip(sorted(EXPECTED_EFFECT_PATHS), effect_classes)
        ):
            effects.append(
                {
                    "path": path,
                    "class": effect_class,
                    "source_object": "EngineFire" if index < 2 else f"EngineFire.{index:03d}",
                    "source_component_indices": [index],
                    "vertex_count": 12,
                    "face_count": 8,
                    "bounds_min": [-1.0, -1.0, -1.0],
                    "bounds_max": [1.0, 1.0, 1.0],
                    "geometry_sha256": "a" * 64,
                    "identity_transform": True,
                    "source_exact_geometry": True,
                }
            )

        manifest = {
            "schema_version": 3,
            "source_sha256": SOURCE_SHA256,
            "canonical_frame": {
                "godot_right": "+X",
                "godot_forward": "-Z",
                "godot_up": "+Y",
                "root_identity": True,
            },
            "dimensions_godot_xyz": [13.714, 3.562, 12.0],
            "collider_size_godot_xyz": [14.0, 3.8, 12.2],
            "removed_from_hull": ["EngineFire"]
            + [f"EngineFire.{index:03d}" for index in range(1, 11)],
            "thruster_visual_strategy": "source_exact_enginefire_geometry",
            "procedural_exhaust_geometry": False,
            "sockets": sockets,
            "thruster_effects": effects,
        }
        manifest_path = root / "fighter.manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        return glb, manifest_path

    def test_valid_schema_three_output_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb, manifest = self._write_valid_output(Path(temporary))
            self.assertEqual(validate_output(glb, manifest, SOURCE_SHA256), [])

    def test_procedural_strategy_and_bad_digest_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb, manifest_path = self._write_valid_output(Path(temporary))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["procedural_exhaust_geometry"] = True
            manifest["thruster_effects"][0]["geometry_sha256"] = "bad"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_output(glb, manifest_path, SOURCE_SHA256)
            self.assertTrue(any("procedural_exhaust_geometry" in error for error in errors))
            self.assertTrue(any("geometry_sha256" in error for error in errors))

    def test_missing_effect_path_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb, manifest_path = self._write_valid_output(Path(temporary))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["thruster_effects"].pop()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_output(glb, manifest_path, SOURCE_SHA256)
            self.assertTrue(any("effect paths mismatch" in error for error in errors))


if __name__ == "__main__":
    unittest.main(verbosity=2)
