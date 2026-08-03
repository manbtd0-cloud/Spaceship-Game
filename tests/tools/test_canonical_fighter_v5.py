from __future__ import annotations

import copy
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from canonical_fighter_contract_v5 import validate_output  # noqa: E402
from small_fighter_calibration import SOURCE_SHA256  # noqa: E402
from tests.tools import test_canonical_fighter_v4 as v4_fixture  # noqa: E402


class CanonicalFighterV5Tests(unittest.TestCase):
    def setUp(self) -> None:
        self._v4 = v4_fixture.CanonicalFighterV4Tests(methodName="runTest")

    def _valid_manifest(self) -> dict[str, object]:
        manifest = self._v4._valid_manifest()
        manifest["schema_version"] = 5
        manifest["primary_muzzles"] = [
            {
                "path": "Weapons/Primary/LeftMuzzle",
                "side": "left",
                "source_object": "SmallSciFiFighterMesh",
                "source_vertex_indices": [1, 2, 3, 4, 5, 6, 7, 8],
                "origin": [-2.0, 0.4, -5.4],
                "basis": [
                    [1.0, 0.0, 0.0],
                    [0.0, 1.0, 0.0],
                    [0.0, 0.0, 1.0],
                ],
                "forward": [0.0, 0.0, -1.0],
                "extraction_error_m": 0.00001,
            },
            {
                "path": "Weapons/Primary/RightMuzzle",
                "side": "right",
                "source_object": "SmallSciFiFighterMesh",
                "source_vertex_indices": [9, 10, 11, 12, 13, 14, 15, 16],
                "origin": [2.0, 0.4, -5.4],
                "basis": [
                    [1.0, 0.0, 0.0],
                    [0.0, 1.0, 0.0],
                    [0.0, 0.0, 1.0],
                ],
                "forward": [0.0, 0.0, -1.0],
                "extraction_error_m": 0.00001,
            },
        ]
        return manifest

    def _glb_document(
        self,
        manifest: dict[str, object],
        include_right: bool = True,
    ) -> dict[str, object]:
        document = self._v4._glb_document(manifest)
        nodes = document["nodes"]
        scenes = document["scenes"]
        assert isinstance(nodes, list)
        assert isinstance(scenes, list)
        scene = scenes[0]
        assert isinstance(scene, dict)
        roots = scene["nodes"]
        assert isinstance(roots, list)
        root_index = int(roots[0])

        def add(
            name: str,
            parent: int,
            translation: list[float] | None = None,
        ) -> int:
            index = len(nodes)
            node: dict[str, object] = {"name": name}
            if translation is not None:
                node["translation"] = translation
            nodes.append(node)
            parent_node = nodes[parent]
            assert isinstance(parent_node, dict)
            children = parent_node.setdefault("children", [])
            assert isinstance(children, list)
            children.append(index)
            return index

        weapons = add("Weapons", root_index)
        primary = add("Primary", weapons)
        add("LeftMuzzle", primary, [-2.0, 0.4, -5.4])
        if include_right:
            add("RightMuzzle", primary, [2.0, 0.4, -5.4])
        return document

    def _validate(
        self,
        manifest: dict[str, object],
        include_right: bool = True,
    ) -> list[str]:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest_path = root / "fighter.manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            glb_path = root / "fighter.glb"
            v4_fixture._write_glb(
                glb_path,
                self._glb_document(manifest, include_right),
            )
            return validate_output(glb_path, manifest_path, SOURCE_SHA256)

    def test_valid_schema_five_output_passes_and_delegates_base_checks(
        self,
    ) -> None:
        self.assertEqual(self._validate(self._valid_manifest()), [])
        invalid = self._valid_manifest()
        invalid["sockets"] = []
        errors = self._validate(invalid)
        self.assertTrue(any("socket paths mismatch" in error for error in errors))

    def test_schema_four_and_two_are_rejected(self) -> None:
        for version in (4, 2):
            manifest = self._valid_manifest()
            manifest["schema_version"] = version
            errors = self._validate(manifest)
            self.assertTrue(
                any("schema_version must be 5" in error for error in errors),
                errors,
            )

    def test_missing_extra_and_duplicate_muzzles_are_rejected(self) -> None:
        for mutator in (
            lambda items: items.pop(),
            lambda items: items.append(copy.deepcopy(items[0])),
            lambda items: items.append(
                {
                    **copy.deepcopy(items[0]),
                    "path": "Weapons/Primary/Center",
                }
            ),
        ):
            manifest = self._valid_manifest()
            items = manifest["primary_muzzles"]
            assert isinstance(items, list)
            mutator(items)
            errors = self._validate(manifest)
            self.assertTrue(
                any(
                    "primary muzzle" in error or "primary_muzzles" in error
                    for error in errors
                ),
                errors,
            )

    def test_invalid_muzzle_geometry_is_rejected(self) -> None:
        mutations = [
            (0, "origin", [0.0, 0.4, -5.4]),
            (0, "origin", [math.nan, 0.4, -5.4]),
            (0, "side", "right"),
            (0, "forward", [0.0, 0.0, 1.0]),
            (1, "origin", [2.0, 1.0, -5.4]),
        ]
        for index, field, value in mutations:
            manifest = self._valid_manifest()
            items = manifest["primary_muzzles"]
            assert isinstance(items, list)
            record = items[index]
            assert isinstance(record, dict)
            record[field] = value
            errors = self._validate(manifest)
            self.assertTrue(errors, (index, field, errors))

    def test_negative_determinant_and_excess_error_are_rejected(self) -> None:
        manifest = self._valid_manifest()
        items = manifest["primary_muzzles"]
        assert isinstance(items, list)
        first = items[0]
        assert isinstance(first, dict)
        first["basis"] = [
            [-1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
        ]
        first["extraction_error_m"] = 0.0002
        errors = self._validate(manifest)
        self.assertTrue(any("determinant" in error for error in errors), errors)
        self.assertTrue(
            any("extraction_error_m" in error for error in errors),
            errors,
        )

    def test_missing_glb_muzzle_node_is_rejected(self) -> None:
        errors = self._validate(self._valid_manifest(), include_right=False)
        self.assertTrue(
            any("GLB primary muzzle" in error for error in errors),
            errors,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
