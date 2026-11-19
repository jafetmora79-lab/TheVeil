# THE VEIL - World locations

This file lists scene paths, zones, world coordinates and story use for each location.

## Coordinate conventions

* **World frame:** metres, +Y up, the road network of Pack 02. The game world is `game/scenes/World.tscn`. It
  instances:
  * `game/world/Greyhaven_Core.tscn` (the Pack 02 town);
  * `Greyhaven_Extension` (the new roads);
  * `Greyhaven_Houses` (Pack 03 lots);
  * `04_Commercial/Godot_Scenes/Greyhaven_Commercial.tscn`.
* **Building origins** are given as `(x, y, z)` with yaw. Commercial entrances face the street.
* **Story status** follows bible section 6.

## Locations

| Location | Scene / node | World origin | Story use | Status |
|---|---|---|---|---|
| Player's house | Pack 03 `RES_PlayerHome` at `World/Residential/Houses/PLAYER_HOME`, zone `PLAYER_HOME` | (56, 0.15, 508.5), yaw -90°, **Fern Ct** (moved from Maple Ave by the Phase 1 extension) | Wake-up, fridge, keys, sedan on the driveway (`Markers/Sedan_Driveway`) | ESTABLISHED. Implemented. |
| Drive route | `game/world/world_data.json` `route` | 1,069 m: residential A, county road C, transition B, commercial D, destination E | Opening drive of at least 60 s through a normal town | Implemented |
| Supermarket ("Greyhaven Market") | `04_Commercial/Godot_Scenes/Supermarket.tscn` at `Commercial/SUPERMARKET`, zone `SUPERMARKET` | (33, 0.15, -27), yaw 180°. Parking trigger centre (31, -16). | Grocery errand: auto doors, shelf pickups, lane-4 checkout. Early shelter in the draft. | ESTABLISHED / WORKING DRAFT. Phase 2 implemented. |
| Video game shop ("Game Haven") | `VideoGameStore.tscn` at `Commercial/GAME_SHOP`, zone `GAME_SHOP` | (14, 0.15, 7), yaw 0° (across Main St from the supermarket) | Horror-game purchase; Eddie (`NavTargets/BehindCounter`) | ESTABLISHED. Phase 2 implemented. |
| Gas station | `GasStation.tscn` at `Commercial/GAS_STATION` | (156, 0.15, -26), yaw 180° | Landmark, supplies | DESIGN PLAN. Asset only. |
| Pharmacy | `Pharmacy.tscn` at `Commercial/PHARMACY` | (-19, 0.15, 7) | Medical supplies; possible Sarah link | DESIGN PLAN. Asset only. |
| Municipal archive | `MunicipalArchive.tscn` at `Commercial/MUNICIPAL_ARCHIVE` | (-32, 0.15, -14) | Historical records; possible Ruth / Lena link | DESIGN PLAN. Asset only. |
| Main St storefronts A-D | `Storefront_A..D.tscn` | A (27.5, 7) · B (45, 7) · C (-43, 7) · D (80.5, 7) | Unassigned tenants | DESIGN PLAN. Shells only. |
| Residential streets | Pack 02 core plus the extension: Harlow Ln, Aspen Ct, Fern Ct; 60+ Pack 03 houses | `world_data.json` `houses` | Normal-life opening; later exploration | ESTABLISHED |
| Police / civic | none | - | Officer Hayes potential | TBD. No asset. |
| Farmhouse / mill house | Pack 03 `RES_House_Farmhouse`, `RES_House_MillWorker` variants | Pack 02 zones | Story use TBD | DESIGN PLAN |
| Beneath Greyhaven | none | - | "Beneath the Town" ending | WORKING DRAFT. No asset. |

## Location metadata

Interior room rectangles, exterior doors, interaction markers (`Interaction/*`, each with `kind` and `fixture`) and
navigation targets (`NavTargets/*`) are stored in every Pack 04 location scene. Use those markers instead of
hard-coded coordinates.

**Rebuild rule:** after any Pack 02 or Pack 03 change, run in order:

1. `python3 game/tools/build_world.py`;
2. `python3 game/tools/check_world.py`, which must report 0 failures;
3. the playthrough test.
