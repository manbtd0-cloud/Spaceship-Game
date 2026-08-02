from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_TOOLS = REPO_ROOT / "tools" / "assets"
if str(ASSET_TOOLS) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOLS))

from canonical_fighter_contract_v4 import (  # noqa: E402
    EXPECTED_EFFECT_TO_SOCKET,
    EXPECTED_EFFECT_PATHS,
    EXPECTED_SOCKET_PATHS,
    validate_output,
)
from small_fighter_calibration import SOURCE_SHA256  # noqa: E402


def _class_for_socket(path: str) -> str:
    if "/Main/" in path:
        return "main"
    if "/Retro/" in path:
        return "retro"
    return "maneuver"


def _write_glb(path: Path, document: dict[str, object]) -> None:
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    payload += b" " * ((4 - len(payload) % 4) % 4)
    total_length = 12 + 8 + len(payload)
    path.write_bytes(
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<I4s", len(payload), b"JSON")
        + payload
    )


class CanonicalFighterV4Tests(unittest.TestCase):
    def _valid_manifest(self) -> dict[str, object]:
        socket_positions: dict[str, list[float]] = {}
        sockets: list[dict[str, object]] = []
        for index, path in enumerate(sorted(EXPECTED_SOCKET_PATHS)):
            position = [float(index + 1), 0.0, 0.0]
            socket_positions[path] = position
            sockets.append(
                {
                    "path": path,
                    "class": _class_for_socket(path),
                    "source_object": "EngineFire" if index < 2 else f"EngineFire.{index:03d}",
                    "source_component": index,
                    "position": position,
                    "exhaust_direction": [0.0, 0.0, 1.0],
                    "reaction_direction": [0.0, 0.0, -1.0],
                    "basis": [
                        [1.0, 0.0, 0.0],
                        [0.0, 1.0, 0.0],
                        [0.0, 0.0, 1.0],
                    ],
                    "capacity": (
                        0.55
                        if "/Main/" in path
                        else 0.35 if "/Retro/" in path else 0.22
                    ),
                }
            )

        effects: list[dict[str, object]] = []
        for index, path in enumerate(sorted(EXPECTED_EFFECT_PATHS)):
            socket_path = EXPECTED_EFFECT_TO_SOCKET[path]
            effects.append(
                {
                    "path": path,
                    "socket_path": socket_path,
                    "class": _class_for_socket(socket_path),
                    "source_object": "EngineFire" if index < 2 else f"EngineFire.{index:03d}",
                    "source_component_indices": [index],
                    "vertex_count": 12,
                    "face_count": 8,
                    "geometry_sha256": "a" * 64,
                    "node_transform_basis": [
                        [1.0, 0.0, 0.0],
                        [0.0, 1.0, 0.0],
                        [0.0, 0.0, 1.0],
                    ],
                    "node_transform_origin": socket_positions[socket_path],
                    "local_exhaust_axis": [0.0, 0.0, -1.0],
                    "local_bounds_min": [-1.0, -1.0, -4.0],
                    "local_bounds_max": [1.0, 1.0, 0.0],
                    "maximum_reconstruction_error_m": 0.0,
                    "source_exact_geometry": True,
                }
            )

        return {
            "schema_version": 4,
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
            "thruster_visual_strategy": "source_exact_nozzle_local_enginefire_geometry",
            "procedural_exhaust_geometry": False,
            "sockets": sockets,
            "thruster_effects": effects,
        }

    def _glb_document(
        self,
        manifest: dict[str, object],
        *,
        baked_effect_path: str | None = None,
        missing_mesh_child_path: str | None = None,
    ) -> dict[str, object]:
        sockets = manifest["sockets"]
        effects = manifest["thruster_effects"]
        assert isinstance(sockets, list)
        assert isinstance(effects, list)
        nodes: list[dict[str, object]] = []

        def add_node(name: str, parent: int | None = None, **values: object) -> int:
            index = len(nodes)
            node: dict[str, object] = {"name": name, **values}
            nodes.append(node)
            if parent is not None:
                children = nodes[parent].setdefault("children", [])
                assert isinstance(children, list)
                children.append(index)
            return index

        root = add_node("SmallSciFiFighter")
        thrusters = add_node("Thrusters", root)
        effects_root = add_node("ThrusterEffects", root)
        socket_groups = {
            "Main": add_node("Main", thrusters),
            "Maneuver": add_node("Maneuver", thrusters),
            "Retro": add_node("Retro", thrusters),
        }
        effect_groups = {
            "MainEffects": add_node("MainEffects", effects_root),
            "ManeuverEffects": add_node("ManeuverEffects", effects_root),
            "RetroEffects": add_node("RetroEffects", effects_root),
        }

        for socket in sockets:
            assert isinstance(socket, dict)
            path = str(socket["path"])
            segments = path.split("/")
            add_node(
                segments[-1],
                socket_groups[segments[-2]],
                translation=socket["position"],
            )

        for effect in effects:
            assert isinstance(effect, dict)
            path = str(effect["path"])
            segments = path.split("/")
            pivot = add_node(
                segments[-1],
                effect_groups[segments[-2]],
                translation=(
                    [0.0, 0.0, 0.0]
                    if path == baked_effect_path
                    else effect["node_transform_origin"]
                ),
            )
            if path != missing_mesh_child_path:
                add_node(f"{segments[-1]}Mesh", pivot, mesh=0)

        return {
            "asset": {"version": "2.0"},
            "scene": 0,
            "scenes": [{"nodes": [root]}],
            "nodes": nodes,
            "meshes": [{"primitives": []}],
        }

    def _write_output(
        self,
        root: Path,
        manifest: dict[str, object] | None = None,
        **glb_options: object,
    ) -> tuple[Path, Path]:
        report = manifest or self._valid_manifest()
        glb = root / "fighter.glb"
        _write_glb(glb, self._glb_document(report, **glb_options))
        manifest_path = root / "fighter.manifest.json"
        manifest_path.write_text(json.dumps(report), encoding="utf-8")
        return glb, manifest_path

    def test_valid_schema_four_output_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            glb, manifest = self._write_output(Path(temporary))
            self.assertEqual(validate_output(glb, manifest, SOURCE_SHA256), [])

    def test_baked_effect_pivot_is_rejected_from_actual_glb(self) -> None:
        baked_path = "ThrusterEffects/MainEffects/MainLeftEffect"
        with tempfile.TemporaryDirectory() as temporary:
            glb, manifest = self._write_output(
                Path(temporary),
                baked_effect_path=baked_path,
            )
            errors = validate_output(glb, manifest, SOURCE_SHA256)
        self.assertTrue(
            any("GLB effect pivot does not match socket" in error for error in errors),
            errors,
        )

    def test_missing_effect_mesh_child_is_rejected(self) -> None:
        missing_path = "ThrusterEffects/MainEffects/MainRightEffect"
        with tempfile.TemporaryDirectory() as temporary:
            glb, manifest = self._write_output(
                Path(temporary),
                missing_mesh_child_path=missing_path,
            )
            errors = validate_output(glb, manifest, SOURCE_SHA256)
        self.assertTrue(
            any("GLB effect mesh child missing" in error for error in errors),
            errors,
        )

    def test_wrong_schema_and_strategy_are_rejected(self) -> None:
        manifest = self._valid_manifest()
        manifest["schema_version"] = 3
        manifest["thruster_visual_strategy"] = "source_exact_enginefire_geometry"
        manifest["procedural_exhaust_geometry"] = True
        with tempfile.TemporaryDirectory() as temporary:
            glb, path = self._write_output(Path(temporary), manifest)
            errors = validate_output(glb, path, SOURCE_SHA256)
        self.assertTrue(any("schema_version must be 4" in error for error in errors))
        self.assertTrue(any("thruster_visual_strategy" in error for error in errors))
        self.assertTrue(any("procedural_exhaust_geometry" in error for error in errors))

    def test_missing_socket_path_and_bad_basis_are_rejected(self) -> None:
        manifest = self._valid_manifest()
        effects = manifest["thruster_effects"]
        assert isinstance(effects, list)
        first = effects[0]
        assert isinstance(first, dict)
        first.pop("socket_path")
        first["node_transform_basis"] = [
            [1.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0],
        ]
        with tempfile.TemporaryDirectory() as temporary:
            glb, path = self._write_output(Path(temporary), manifest)
            errors = validate_output(glb, path, SOURCE_SHA256)
        self.assertTrue(any("socket_path" in error for error in errors))
        self.assertTrue(any("orthogonal" in error for error in errors))

    def test_invalid_axis_and_reconstruction_error_are_rejected(self) -> None:
        manifest = self._valid_manifest()
        effects = manifest["thruster_effects"]
        assert isinstance(effects, list)
        first = effects[0]
        assert isinstance(first, dict)
        first["local_exhaust_axis"] = [0.0, 0.0, 1.0]
        first["maximum_reconstruction_error_m"] = 0.0002
        with tempfile.TemporaryDirectory() as temporary:
            glb, path = self._write_output(Path(temporary), manifest)
            errors = validate_output(glb, path, SOURCE_SHA256)
        self.assertTrue(any("local_exhaust_axis" in error for error in errors))
        self.assertTrue(any("reconstruction" in error for error in errors))

    def test_effect_to_socket_mapping_must_be_one_to_one(self) -> None:
        manifest = self._valid_manifest()
        effects = manifest["thruster_effects"]
        assert isinstance(effects, list)
        first = effects[0]
        second = effects[1]
        assert isinstance(first, dict)
        assert isinstance(second, dict)
        second["socket_path"] = first["socket_path"]
        with tempfile.TemporaryDirectory() as temporary:
            glb, path = self._write_output(Path(temporary), manifest)
            errors = validate_output(glb, path, SOURCE_SHA256)
        self.assertTrue(any("one-to-one" in error for error in errors))


if __name__ == "__main__":
    unittest.main(verbosity=2)
