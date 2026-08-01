# Shattered Orbit asset layout

`assets/source/` contains canonical editable source models and their original license evidence.

`assets/runtime/` is reserved for optimized Godot-ready `.glb` exports, collision meshes, LODs, and runtime textures. Do not point Godot scenes directly at raw `.blend`, `.fbx`, `.obj`, or `.stl` source files.

`assets/licenses/` centralizes license evidence without removing original vendor license files.

`assets/inventory/` records intended roles, cleanup status, conversion status, and final selections.

The large Quaternius modular pack remains under `Resources/Ultimate Modular Sci-Fi - Feb 2021/` for now. The entire `Resources/` directory is hidden from Godot with `.gdignore`, preventing hundreds of unnecessary imports. We will extract only the modules actually used into `assets/runtime/` after Blender review.
