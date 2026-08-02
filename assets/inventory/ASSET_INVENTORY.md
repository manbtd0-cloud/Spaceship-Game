# Asset inventory

| Asset | Source path | Intended role | License | Status |
|---|---|---|---|---|
| Small Sci-Fi Fighter | `assets/source/ships/player_candidates/small_sci_fi_fighter/` | Selected player hero interceptor | No license evidence identified in repository | Development-only; repeatable GLB export prepared; redistribution blocked until license evidence is reviewed |
| The Ship | `assets/source/ships/player_candidates/the_ship/` | Secondary hero/heavy-ship candidate | License evidence pending centralization | Source preserved; not selected for this milestone |
| Space Station 87177 | `assets/source/structures/space_station_87177/` | Station hub visual base | CC0 1.0 | Source and original textures preserved |
| Bennu | `assets/source/environment/asteroids/bennu/` | Irregular asteroid field | NASA source; usage review required | Source preserved; GLB conversion pending |
| Itokawa | `assets/source/environment/asteroids/itokawa/` | Elongated asteroid corridors | NASA source; usage review required | Source preserved; GLB conversion pending |
| Eros | `assets/source/environment/asteroids/eros/` | Large debris/moon fragment | NASA source; usage review required | Source preserved; GLB conversion pending |
| Vesta hollow globe | `assets/source/environment/asteroids/vesta/` | Distant moon or large fragment source | NASA source; usage review required | Source preserved; suitability review pending |
| Ultimate Modular Sci-Fi | `Resources/Ultimate Modular Sci-Fi - Feb 2021/` | Station, relay, hangar, capital-ship kitbash modules | CC0 1.0 | Raw vendor pack preserved and hidden from Godot |

## Selection rules

- Keep untouched source files available for Blender rework.
- Export only selected assets to GLB.
- Generate simple collision meshes separately from visual meshes.
- Do not duplicate FBX, OBJ, and Blend variants into runtime directories.
- Do not remove source assets until a runtime export is verified in Godot and license evidence is recorded.
- Treat the Small Sci-Fi Fighter runtime derivative as development-only until its original license evidence is added and reviewed.
