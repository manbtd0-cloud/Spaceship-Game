from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class VerifyScriptTests(unittest.TestCase):
    def test_windows_verifier_reads_schema_three_source_exact_contract(self) -> None:
        source = (REPO_ROOT / "tools" / "verify" / "verify.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("$manifest.canonical_frame.godot_forward", source)
        self.assertIn("$manifest.canonical_frame.godot_up", source)
        self.assertIn("$manifest.schema_version -ne 3", source)
        self.assertIn("source_exact_enginefire_geometry", source)
        self.assertIn("$manifest.thruster_effects", source)
        self.assertIn('"ThrusterEffects/MainEffects/MainLeftEffect"', source)
        self.assertIn('"ThrusterEffects/RetroEffects/RetroRightEffect"', source)
        self.assertIn('"ThrusterEffects/ManeuverEffects/FrontUpperLeftEffect"', source)
        self.assertNotIn('"ThrusterEffects/Main/MainLeftEffect"', source)
        self.assertNotIn('"ThrusterEffects/Retro/RetroLeftEffect"', source)

    def test_linux_verifier_reads_schema_three_source_exact_contract(self) -> None:
        source = (REPO_ROOT / "tools" / "verify" / "verify.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('manifest.get("canonical_frame")', source)
        self.assertIn('manifest.get("schema_version") != 3', source)
        self.assertIn('source_exact_enginefire_geometry', source)
        self.assertIn('manifest.get("thruster_effects", [])', source)
        self.assertIn('"ThrusterEffects/MainEffects/MainLeftEffect"', source)
        self.assertIn('"ThrusterEffects/RetroEffects/RetroRightEffect"', source)
        self.assertIn('"ThrusterEffects/ManeuverEffects/FrontUpperLeftEffect"', source)
        self.assertNotIn('"ThrusterEffects/Main/MainLeftEffect"', source)
        self.assertNotIn('"ThrusterEffects/Retro/RetroLeftEffect"', source)

    def test_asset_wrappers_fail_on_blender_python_exceptions(self) -> None:
        for relative_path in (
            Path("tools/assets/export-small-fighter.ps1"),
            Path("tools/assets/export-asteroid-pack.ps1"),
        ):
            source = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertIn('"--python-exit-code"', source)
            self.assertIn('"1"', source)

    def test_fighter_wrapper_uses_schema_three_exporter_and_validator(self) -> None:
        source = (REPO_ROOT / "tools" / "assets" / "export-small-fighter.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("export_small_sci_fi_fighter_v3.py", source)
        self.assertIn("canonical_fighter_contract_v3.py", source)
        self.assertNotIn('export_small_sci_fighter.py"', source)

    def test_fighter_wrapper_replaces_live_assets_only_after_validation(self) -> None:
        source = (REPO_ROOT / "tools" / "assets" / "export-small-fighter.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("small_sci_fi_fighter.pending.glb", source)
        self.assertIn("small_sci_fi_fighter.pending.manifest.json", source)
        validation_index = source.index("& $pythonExecutable $validatorPath")
        glb_move_index = source.index("Move-Item -LiteralPath $pendingOutputPath")
        manifest_move_index = source.index("Move-Item -LiteralPath $pendingManifestPath")
        self.assertLess(validation_index, glb_move_index)
        self.assertLess(validation_index, manifest_move_index)
        self.assertNotIn("foreach ($stalePath in @($outputPath, $manifestPath))", source)

    def test_fighter_wrapper_writes_pending_manifest_without_utf8_bom(self) -> None:
        source = (REPO_ROOT / "tools" / "assets" / "export-small-fighter.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("[System.Text.UTF8Encoding]::new($false)", source)
        self.assertIn("[System.IO.File]::WriteAllText", source)
        self.assertNotIn(
            "Set-Content -LiteralPath $pendingManifestPath -Encoding utf8",
            source,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
