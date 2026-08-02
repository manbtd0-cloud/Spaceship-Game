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

from hero_ship_audit_contract import (  # noqa: E402
    EXPECTED_RENDER_NAMES,
    validate_audit_directory,
)


VALID_SHA = "a" * 64


class AuditContractTests(unittest.TestCase):
    def _write_valid_fixture(self, root: Path) -> None:
        root.mkdir(parents=True, exist_ok=True)
        for filename in EXPECTED_RENDER_NAMES:
            (root / filename).write_bytes(b"\x89PNG\r\n\x1a\nAUDIT")

        renders = {}
        for index, filename in enumerate(EXPECTED_RENDER_NAMES):
            view_name = Path(filename).stem
            renders[view_name] = {
                "file": filename,
                "camera_location": [float(index + 1), -5.0, 2.0],
                "view_direction": [0.0, 1.0, 0.0],
                "projection": (
                    "PERSP" if view_name.startswith("perspective_") else "ORTHO"
                ),
            }

        report = {
            "schema_version": 1,
            "source": {
                "path": "assets/source/ships/player_candidates/"
                "small_sci_fi_fighter/Small Sci-Fi Fighter.blend",
                "sha256": VALID_SHA,
                "blender_version": "5.2.0",
            },
            "aggregate_bounds": {
                "minimum": [0.0, 0.0, 0.0],
                "maximum": [1.0, 1.0, 1.0],
                "center": [0.5, 0.5, 0.5],
                "dimensions": [1.0, 1.0, 1.0],
            },
            "objects": [],
            "materials": [],
            "empties": [],
            "candidate_nozzle_names": [],
            "renders": renders,
            "calibration_status": "unconfirmed",
        }
        (root / "ship_audit.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )

    def test_complete_directory_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            audit_dir = Path(temporary)
            self._write_valid_fixture(audit_dir)
            self.assertEqual(
                validate_audit_directory(audit_dir, VALID_SHA),
                [],
            )

    def test_missing_render_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            audit_dir = Path(temporary)
            self._write_valid_fixture(audit_dir)
            (audit_dir / "rear.png").unlink()
            errors = validate_audit_directory(audit_dir, VALID_SHA)
            self.assertTrue(any("rear.png" in error for error in errors))

    def test_empty_render_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            audit_dir = Path(temporary)
            self._write_valid_fixture(audit_dir)
            (audit_dir / "top.png").write_bytes(b"")
            errors = validate_audit_directory(audit_dir, VALID_SHA)
            self.assertTrue(any("top.png" in error for error in errors))

    def test_report_source_hash_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            audit_dir = Path(temporary)
            self._write_valid_fixture(audit_dir)
            errors = validate_audit_directory(audit_dir, "b" * 64)
            self.assertTrue(any("source SHA" in error for error in errors))

    def test_report_requires_eight_camera_records(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            audit_dir = Path(temporary)
            self._write_valid_fixture(audit_dir)
            report_path = audit_dir / "ship_audit.json"
            report = json.loads(report_path.read_text(encoding="utf-8"))
            report["renders"].pop("bottom")
            report_path.write_text(json.dumps(report), encoding="utf-8")
            errors = validate_audit_directory(audit_dir, VALID_SHA)
            self.assertTrue(any("render records" in error for error in errors))

    def test_report_rejects_unapproved_orientation_claims(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            audit_dir = Path(temporary)
            self._write_valid_fixture(audit_dir)
            report_path = audit_dir / "ship_audit.json"
            report = json.loads(report_path.read_text(encoding="utf-8"))
            report["confirmed_nose"] = "-Y"
            report_path.write_text(json.dumps(report), encoding="utf-8")
            errors = validate_audit_directory(audit_dir, VALID_SHA)
            self.assertTrue(any("confirmed_nose" in error for error in errors))


if __name__ == "__main__":
    unittest.main(verbosity=2)
