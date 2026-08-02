# Asteroid Asset Provenance

## Runtime policy

All four asteroid sources are preserved under `assets/source/environment/asteroids/`. Canonical Godot GLBs are generated under `assets/runtime/environment/asteroids/` by `tools/assets/export-asteroid-pack.ps1`.

The exporter never saves or replaces a source file. Source identity is enforced by SHA-256 before and after export.

## Eros

- Runtime family: `eros`
- Source filename: `asteroid_eros_true_color.glb`
- SHA-256: `73994d18c12b696d273abdb2c79d132f755ada014dde972a8ba3b480c7eb95ef`
- Title embedded in glTF metadata: `Asteroid Eros True Color`
- Author embedded in glTF metadata: Reuben Reyes (`hitechmex` on Sketchfab)
- Source URL embedded in glTF metadata: `https://sketchfab.com/3d-models/asteroid-eros-true-color-2f7ea65a0a3c4768aeadb0f90ec4a94a`
- License embedded in glTF metadata: CC BY 4.0
- Required attribution status: satisfied by this file and must remain in distributed notices.

## Bennu

- Runtime family: `bennu`
- Source filename: `asteroid_bennu_textured.blend`
- SHA-256: `e01e7aa3364d8f7dc91aeaf4149b8aa82111f986467bec00ed7fa9ecd2f0bd5a`
- Current status: development-only pending original source and license evidence.

## Legacy A

- Runtime family: `legacy_a`
- Source filename: `asteroid_legacy_a.blend`
- SHA-256: `8bfa230c83fa9ebeea952b21d2a64d96aa81599413c907fd994372df88185032`
- Current status: development-only pending original source and license evidence.

## Legacy B

- Runtime family: `legacy_b`
- Source filename: `asteroid_legacy_b.blend`
- SHA-256: `5012f846592e69b955bdae10d5e98ac43eb5116541ddbfdb0d3cd489b16035d6`
- Current status: development-only pending original source and license evidence.

## Restrictions

Do not ship Bennu, Legacy A, or Legacy B in a public or commercial build until their original provenance and license evidence are recorded. Eros may be distributed under CC BY 4.0 while preserving attribution.
