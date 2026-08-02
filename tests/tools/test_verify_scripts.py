from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class VerifyScriptTests(unittest.TestCase):
    def test_windows_verifier_reads_schema_four_nozzle_local_contract(self) -> None:
        source = (REPO_ROOT / "tools" / "verify" / "verify.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("$manifest.canonical_frame.godot_forward", source)
        self.assertIn("$manifest.canonical_frame.godot_up", source)
        self.assertIn("$manifest.schema_version -ne 4", source)
        self.assertIn("source_exact_nozzle_local_enginefire_geometry", source)
        self.assertIn("$manifest.thruster_effects", source)
        self.assertIn("maximum_reconstruction_error_m", source)
        self.assertIn("node_transform_basis", source)
        self.assertIn("local_exhaust_axis", source)

    def test_linux_verifier_reads_schema_four_nozzle_local_contract(self) -> None:
        source = (REPO_ROOT / "tools" / "verify" / "verify.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn('manifest.get("schema_version") != 4', source)
        self.assertIn('source_exact_nozzle_local_enginefire_geometry', source)
        self.assertIn('manifest.get("thruster_effects", [])', source)
        self.assertIn("maximum_reconstruction_error_m", source)
        self.assertIn("node_transform_basis", source)
        self.assertIn("local_exhaust_axis", source)

    def test_local_verifiers_validate_checked_in_thruster_matrix(self) -> None:
        windows = (REPO_ROOT / "tools" / "verify" / "verify.ps1").read_text(
            encoding="utf-8"
        )
        linux = (REPO_ROOT / "tools" / "verify" / "verify.sh").read_text(
            encoding="utf-8"
        )
        for source in (windows, linux):
            self.assertIn("fighter_thruster_action_contract.py", source)
            self.assertIn("small_sci_fi_fighter_thruster_actions.json", source)
            self.assertIn("--matrix", source)
            self.assertIn("--manifest", source)

    def test_asset_wrappers_fail_on_blender_python_exceptions(self) -> None:
        for relative_path in (
            Path("tools/assets/export-small-fighter.ps1"),
            Path("tools/assets/export-asteroid-pack.ps1"),
        ):
            source = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertIn('"--python-exit-code"', source)
            self.assertIn('"1"', source)

    def test_fighter_wrapper_uses_schema_four_exporter_and_validator(self) -> None:
        source = (REPO_ROOT / "tools" / "assets" / "export-small-fighter.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("export_small_sci_fi_fighter_v4.py", source)
        self.assertIn("canonical_fighter_contract_v4.py", source)
        self.assertNotIn("export_small_sci_fi_fighter_v3.py", source)
        self.assertNotIn("canonical_fighter_contract_v3.py", source)

    def test_fighter_wrapper_validates_all_pending_outputs_before_publication(self) -> None:
        source = (REPO_ROOT / "tools" / "assets" / "export-small-fighter.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("small_sci_fi_fighter.pending.glb", source)
        self.assertIn("small_sci_fi_fighter.pending.manifest.json", source)
        self.assertIn("small_sci_fi_fighter_thruster_actions.pending.json", source)
        self.assertIn("generate_fighter_thruster_action_matrix.py", source)
        self.assertIn("fighter_thruster_action_contract.py", source)

        schema_validation_index = source.index("& $pythonExecutable $validatorPath")
        matrix_generation_index = source.index("& $pythonExecutable $matrixGeneratorPath")
        matrix_validation_index = source.index("& $pythonExecutable $matrixValidatorPath")
        glb_move_index = source.index("Move-Item -LiteralPath $pendingOutputPath")
        manifest_move_index = source.index("Move-Item -LiteralPath $pendingManifestPath")
        matrix_move_index = source.index("Move-Item -LiteralPath $pendingMatrixPath")

        self.assertLess(schema_validation_index, matrix_generation_index)
        self.assertLess(matrix_generation_index, matrix_validation_index)
        self.assertLess(matrix_validation_index, glb_move_index)
        self.assertLess(matrix_validation_index, manifest_move_index)
        self.assertLess(matrix_validation_index, matrix_move_index)
        self.assertNotIn(
            "foreach ($stalePath in @($outputPath, $manifestPath, $matrixPath))",
            source,
        )

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
