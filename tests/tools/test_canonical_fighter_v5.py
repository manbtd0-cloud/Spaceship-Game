from __future__ import annotations

import copy
import json
import math
import struct
import tempfile
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from canonical_fighter_contract_v5 import (  # noqa: E402
    EXPECTED_EFFECT_PATHS,
    EXPECTED_PRIMARY_MUZZLES,
    EXPECTED_SOCKET_PATHS,
    validate_output,
)

SOURCE_SHA = "1b41311543974b94ead9bb90eee053bac831b0d62512cbbe190ffb374c20a478"


def _write_glb(path: Path, document: dict[str, object]) -> None:
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    payload += b" " * ((4 - len(payload) % 4) % 4)
    total_length = 12 + 8 + len(payload)
    path.write_bytes(
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<I4s", len(payload), b"JSON")
        + payload
    )


class CanonicalFighterV5Tests(unittest.TestCase):
    def _valid_manifest(self) -> dict[str, object]:
        return {
            "schema_version": 5,
            "source_sha256": SOURCE_SHA,
            "sockets": [
                {"path": path} for path in sorted(EXPECTED_SOCKET_PATHS)
            ],
            "thruster_effects": [
                {"path": path} for path in sorted(EXPECTED_EFFECT_PATHS)
            ],
            "primary_muzzles": [
                {
                    "path": "Weapons/Primary/LeftMuzzle",
                    "side": "left",
                    "source_object": "Hull",
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
                    "source_object": "Hull",
                    "source_vertex_indices": [
                        9,
                        10,
                        11,
                        12,
                        13,
                        14,
                        15,
                        16,
                    ],
                    "origin": [2.0, 0.4, -5.4],
                    "basis": [
                        [1.0, 0.0, 0.0],
                        [0.0, 1.0, 0.0],
                        [0.0, 0.0, 1.0],
                    ],
                    "forward": [0.0, 0.0, -1.0],
                    "extraction_error_m": 0.00001,
                },
            ],
        }

    def _glb_document(self, include_right: bool = True) -> dict[str, object]:
        nodes: list[dict[str, object]] = []

        def add(
            name: str,
            parent: int | None = None,
            translation: list[float] | None = None,
        ) -> int:
            index = len(nodes)
            node: dict[str, object] = {"name": name}
            if translation is not None:
                node["translation"] = translation
            nodes.append(node)
            if parent is not None:
                children = nodes[parent].setdefault("children", [])
                assert isinstance(children, list)
                children.append(index)
            return index

        root = add("SmallSciFiFighter")
        weapons = add("Weapons", root)
        primary = add("Primary", weapons)
        add("LeftMuzzle", primary, [-2.0, 0.4, -5.4])
        if include_right:
            add("RightMuzzle", primary, [2.0, 0.4, -5.4])
        return {
            "asset": {"version": "2.0"},
            "scene": 0,
            "scenes": [{"nodes": [root]}],
            "nodes": nodes,
        }

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
            _write_glb(glb_path, self._glb_document(include_right))
            return validate_output(glb_path, manifest_path, SOURCE_SHA)

    def test_valid_schema_five_output_passes_and_delegates_base_checks(
        self,
    ) -> None:
        self.assertEqual(self._validate(self._valid_manifest()), [])
        invalid = self._valid_manifest()
        invalid["sockets"] = []
        self.assertTrue(
            any(
                "socket paths mismatch" in error
                for error in self._validate(invalid)
            )
        )

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

    def test_centerline_nonfinite_wrong_side_and_backward_are_rejected(
        self,
    ) -> None:
        mutations = [
            ("origin", [0.0, 0.4, -5.4]),
            ("origin", [math.nan, 0.4, -5.4]),
            ("side", "right"),
            ("forward", [0.0, 0.0, 1.0]),
        ]
        for field, value in mutations:
            manifest = self._valid_manifest()
            items = manifest["primary_muzzles"]
            assert isinstance(items, list) and isinstance(items[0], dict)
            items[0][field] = value
            errors = self._validate(manifest)
            self.assertTrue(errors, (field, errors))

    def test_negative_determinant_and_excess_error_are_rejected(self) -> None:
        manifest = self._valid_manifest()
        items = manifest["primary_muzzles"]
        assert isinstance(items, list) and isinstance(items[0], dict)
        items[0]["basis"] = [
            [-1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
        ]
        items[0]["extraction_error_m"] = 0.0002
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
