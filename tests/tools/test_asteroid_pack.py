from __future__ import annotations

import ast
import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from asteroid_pack_contract import (  # noqa: E402
    CANONICAL_DIAMETER_METERS,
    FAMILIES,
    validate_outputs,
    validate_sources,
)


class AsteroidPackTests(unittest.TestCase):
    def _write_sources(self, root: Path) -> None:
        for specification in FAMILIES.values():
            path = root / specification.source_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(specification.fixture_bytes)

    def _write_outputs(self, root: Path) -> None:
        for specification in FAMILIES.values():
            glb_path = root / specification.output_path
            manifest_path = root / specification.manifest_path
            glb_path.parent.mkdir(parents=True, exist_ok=True)
            glb_path.write_bytes(b"glTFasteroid")
            manifest = {
                "schema_version": 1,
                "source_id": specification.source_id,
                "source_sha256": specification.fixture_sha256,
                "canonical_frame": {
                    "godot_right": "+X",
                    "godot_forward": "-Z",
                    "godot_up": "+Y",
                    "root_identity": True,
                },
                "canonical_diameter_meters": CANONICAL_DIAMETER_METERS,
                "dimensions_godot_xyz": [100.0, 62.0, 81.0],
                "visual_vertices": 5000,
                "visual_faces": 9000,
                "proxy_vertices": 96,
                "proxy_faces": 188,
                "material_count": 1,
                "texture_present": specification.source_id in {"bennu", "eros"},
                "removed_objects": ["Camera", "Light"],
                "provenance_status": specification.provenance_status,
            }
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    def test_family_contract_contains_all_four_sources(self) -> None:
        self.assertEqual(set(FAMILIES), {"bennu", "eros", "legacy_a", "legacy_b"})
        self.assertEqual(
            {specification.canonical_name for specification in FAMILIES.values()},
            {"Bennu", "Eros", "LegacyA", "LegacyB"},
        )

    def test_missing_source_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            errors = validate_sources(Path(temporary), use_fixture_hashes=True)
            self.assertEqual(len(errors), 4)
            self.assertTrue(all("missing" in error for error in errors))

    def test_wrong_source_hash_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._write_sources(root)
            first = next(iter(FAMILIES.values()))
            (root / first.source_path).write_bytes(b"wrong")
            errors = validate_sources(root, use_fixture_hashes=True)
            self.assertTrue(any(first.source_id in error and "SHA" in error for error in errors))

    def test_complete_fixture_pack_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._write_sources(root)
            self._write_outputs(root)
            self.assertEqual(validate_sources(root, use_fixture_hashes=True), [])
            self.assertEqual(validate_outputs(root, use_fixture_hashes=True), [])

    def test_missing_runtime_glb_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._write_sources(root)
            self._write_outputs(root)
            specification = FAMILIES["eros"]
            (root / specification.output_path).unlink()
            errors = validate_outputs(root, use_fixture_hashes=True)
            self.assertTrue(any("eros" in error and "GLB missing" in error for error in errors))

    def test_full_detail_collision_proxy_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._write_sources(root)
            self._write_outputs(root)
            specification = FAMILIES["legacy_a"]
            manifest_path = root / specification.manifest_path
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["proxy_faces"] = manifest["visual_faces"]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_outputs(root, use_fixture_hashes=True)
            self.assertTrue(any("legacy_a" in error and "proxy_faces" in error for error in errors))

    def test_invalid_frame_and_diameter_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._write_sources(root)
            self._write_outputs(root)
            specification = FAMILIES["bennu"]
            manifest_path = root / specification.manifest_path
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["canonical_frame"]["root_identity"] = False
            manifest["canonical_diameter_meters"] = 200.0
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = validate_outputs(root, use_fixture_hashes=True)
            self.assertTrue(any("root_identity" in error for error in errors))
            self.assertTrue(any("diameter" in error for error in errors))

    def test_exporter_is_parseable_and_never_saves_source(self) -> None:
        exporter = ASSET_TOOLS / "export_asteroid_family.py"
        source = exporter.read_text(encoding="utf-8")
        ast.parse(source)
        for forbidden in ("save_as_mainfile", "save_mainfile", "save_homefile"):
            self.assertNotIn(forbidden, source)
        self.assertIn("CollisionProxy-convcolonly", source)
        self.assertIn("VisualModel", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
