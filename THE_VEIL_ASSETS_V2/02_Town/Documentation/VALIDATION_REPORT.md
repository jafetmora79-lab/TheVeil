# THE VEIL - Pack 02 Validation Report

Automated checks only. **Visual quality has NOT been verified** - no renders or screenshots were made; judge the look in Godot.

- Failures: **0**
- Warnings: 0

## Summary

- GLB files parsed: 157
- Khronos glTF-Validator: 157 files, 0 errors, 0 warnings
- Surface modules coverage-tested at 5 cm: 28
- Road ports: 95 road modules; open ports = 3 (all at declared termini: WOODS_TRAILHEAD, ESCAPE_ROUTE_EAST, QUARRY_ENTRANCE)
- Road network: 1 connected component (95 modules)
- Supermarket <-> game shop: 37 m apart across Main St; crosswalks within reach: 3
- Estimated static draw surfaces (before Godot culling): ~2143 (1141 woods/undergrowth items batched into 32 chunk meshes)
- Scene: 128 external scenes, 929 instances, 1055 nodes, ~285,447 visual triangles
- Godot: import: exit 0, 0 error lines
- Godot: mesh instances=990 surfaces using library .tres=2204, surfaces with other/null material=0
- Godot: static bodies=882 collision shapes=882
- Godot: Pack 02 materials loaded: 31
- Godot: opening-route probes: 54/54 hit ground, surface height 0.000..0.150 m
- Godot: curb-crossing collision heights (road->sidewalk ramps): 0.000 0.060 0.105 0.150 0.150 0.150 0.150 
- Godot: capsule walk road->sidewalk over 15 cm curb at (-45, 0.9, 1.5): ok (end (-45, 1.025864, 4.815927))
- Godot: capsule walk road->sidewalk over 15 cm curb at (40, 0.9, -101.5): ok (end (40, 1.025844, -96.98394))
- Godot: DONE

## Drivable routes from PLAYER_HOME (graph distance through placed modules)

| From | To | Route length |
|---|---|---|
| PLAYER_HOME | SUPERMARKET | 206 m |
| PLAYER_HOME | GAME_SHOP | 167 m |
| PLAYER_HOME | PHARMACY | 177 m |
| PLAYER_HOME | MUNICIPAL_ARCHIVE | 187 m |
| PLAYER_HOME | GAS_STATION | 267 m |
| PLAYER_HOME | QUARRY_ENTRANCE | 311 m |
| PLAYER_HOME | ESCAPE_ROUTE_EAST | 301 m |
| PLAYER_HOME | WOODS_TRAILHEAD | 311 m |
| PLAYER_HOME | FARMHOUSE | 320 m |
| PLAYER_HOME | MILL_HOUSE | 256 m |

## Models per category

| Category | Models | Visual triangles (min / median / max) |
|---|---|---|
| Roads | 27 | 2 / 10 / 234 |
| Sidewalks | 12 | 4 / 16 / 80 |
| Street_Props | 38 | 10 / 56 / 514 |
| Utilities | 14 | 10 / 90 / 252 |
| Vegetation | 19 | 6 / 80 / 612 |
| Fences | 12 | 10 / 84 / 290 |
