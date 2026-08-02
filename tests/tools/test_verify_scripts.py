from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class VerifyScriptTests(unittest.TestCase):
    def test_windows_verifier_reads_schema_two_canonical_frame(self) -> None:
        source = (REPO_ROOT / "tools" / "verify" / "verify.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("$manifest.canonical_frame.godot_forward", source)
        self.assertIn("$manifest.canonical_frame.godot_up", source)
        self.assertNotIn("$manifest.godot_forward", source)
        self.assertNotIn("$manifest.godot_up", source)

    def test_linux_verifier_reads_schema_two_canonical_frame(self) -> None:
        source = (REPO_ROOT / "tools" / "verify" / "verify.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('manifest.get("canonical_frame")', source)
        self.assertIn('manifest.get("schema_version") != 2', source)
        self.assertIn('len(manifest.get("sockets", [])) != 12', source)

    def test_asset_wrappers_fail_on_blender_python_exceptions(self) -> None:
        for relative_path in (
            Path("tools/assets/export-small-fighter.ps1"),
            Path("tools/assets/export-asteroid-pack.ps1"),
        ):
            source = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertIn('"--python-exit-code"', source)
            self.assertIn('"1"', source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
