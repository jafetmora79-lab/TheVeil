# THE VEIL - Pack 04 Commercial Buildings & Stores

## Inventory before this pass

When this pass began, Pack 04 had no files at all: no folder, buildings, fixtures, scenes or gallery entries. These
pieces already existed in other packs:

* **Layout (Pack 02):** zones for `SUPERMARKET`, `GAME_SHOP`, `PHARMACY`, `GAS_STATION` + `GAS_PUMP_CANOPY`,
  `MUNICIPAL_ARCHIVE`, `STOREFRONT_A-D` and `COMMERCIAL_SPARE`.
* **Supermarket surroundings (Pack 02):** the parking lot (4 modules), its edge sidewalk, and the service yard with a
  dumpster, AC unit, transformer and electrical cabinet.
* **Gas station surroundings (Pack 02):** forecourt pavement, street lamps, a phone booth and a dumpster.
* **Archive surroundings (Pack 02):** a brick wall with a gap for the walkway, trees and ivy.
* **Textures (Pack 01):** commercial textures (supermarket floor tiles, ceiling tiles, storefront brick and concrete,
  metal shelving, storage concrete, signage backing, metal door).
* **Pack 03:**
  * the building kit: walls with real openings, hinged, garage and sliding doors, floors, ceilings, walk collision
    and room metadata;
  * the walk-grid checker;
  * 85 furniture pieces.
* **Pack 05:** the upright shopping cart scene.
* **Pack 09:** the `LGT_Empty_Supermarket` and `LGT_Dark_Video_Game_Shop` lighting presets.

Everything listed below is new.

## How to use

```bash
python3 04_Commercial/Source_Scripts/build_commercial.py
```

```bash
python3 04_Commercial/Source_Scripts/validate_commercial.py --gltf-validator <dir> --godot <Godot_4.3> --godot-project <scratch>
```

* **One location:** instance `Godot_Scenes/<Location>.tscn`. It contains:
  * the building (shell, interior, door nodes, walk collision) and the batched furnishing (static, trimesh
    collision);
  * scene-instanced props (carts, bins);
  * lights;
  * `Doorways/*_Outside|_Inside` markers on each exterior door;
  * `Interaction/*` markers: registers, cooler doors, freezer lid, demo station, pumps, air pump, drawers, browsing
    spots, cart pickup;
  * `NavTargets/*` markers for every key spot.
* **Whole town:** `Godot_Scenes/Greyhaven_Commercial.tscn` places every location in its Pack 02 zone.
  `Greyhaven_Town_Complete.tscn` combines the Pack 02 town, the Pack 03 houses and Pack 04. Other packs' scenes are
  instanced there, never edited.
* **Coordinates:** the Pack 03 zone frame. In it, x runs across the frontage, z is the depth from the zone front line,
  and y = 0 is lot level (world y 0.15). Store floors sit 4 cm above the sidewalk, so entrances are step-free; the
  archive's floor is raised 0.75 m behind portico steps.
* **Doors:** hinged doors use the Pack 03 interactive door nodes (`veil_interact = hinge`). The supermarket entrance
  has bi-parting automatic doors (`INT_AutoDoor_Entrance_L/R`, `veil_interact = slide`, `auto = true`). All leaves are
  built in the closed pose; no door logic is included.

## Locations

| Location | Zone | Rooms | Highlights |
|---|---|---|---|
| **Supermarket** - Greyhaven Market (P1) | SUPERMARKET, 40 x 17.4 m, 4.2 m ceiling | vestibule, sales floor, backroom, office, staff restroom | entrance bump-out with a raised sign, auto doors, 6 storefront windows with banners, front walk joining the Pack 02 lot, bollards, loading door + pad on the service-yard side, back exit; inside: cart area (8 Pack 05 carts), baskets, 4 checkout lanes (conveyor, register, card reader, dividers, bags, candy rack, lane light), customer service counter, 8 stocked gondolas = 7 numbered aisles with hanging signs, 8 dairy / drink reach-in coolers, 4 freezer reach-ins + 2 chest freezers, produce wall cases + tables, staff doors with signs, exit signs, troffer lighting; backroom pallet racks, pallets, shelving; office; restroom; 2 cart corrals in the lot |
| **Video game store** - Game Haven (P1) | GAME_SHOP, 11.2 x 11.3 m, 3.3 m ceiling | shop floor, stock room, office / employee workspace | glass door, display window with platform, console boxes, posters and a neon OPEN sign, lit sign; new and used game wall shelves, console wall shelf, 2 island racks (New Releases / Used Games), console glass case, demo station with CRT and controller, CRT TV + console on a stand, poster boards, checkout counter with register and glass case, behind-counter storage, office with computer desk, stock room |
| **Gas station** - Quarry Fuel & Food Mart (P2) | GAS_STATION + GAS_PUMP_CANOPY | sales floor, storage, restroom, office | canopy with lit fascia and underside lights, 2 pump islands with 4 pumps, price pylon, 5 painted parking stalls, ice chest, air pump, trash bins (Pack 02), raised walk; inside: drink coolers, 2 snack gondolas, wall shelf, checkout counter with candy rack and register, coffee station, restroom door from the store, storage, office |
| **Pharmacy** - Hollis Drug (P2) | PHARMACY, 21 x 10.3 m, 3.4 m ceiling | sales floor, dispensary, stock room | glass door, 4 windows, lit sign; front service counter, 3 health / personal-care gondolas, wall shelves, pharmacy counter set into the dispensary wall (glass screen, PHARMACY / PICK UP sign, pick-up bags), waiting chairs, dispensary shelves, stock room |
| **Municipal archive** (P3) | MUNICIPAL_ARCHIVE, set back behind the lawn | lobby / reception, reading room, offices, records stacks, archive storage | brick civic building with a hip roof, a columned portico with a pediment and 5 steps, a plaque, and a walkway from the gap in the Pack 02 brick wall; reception desk, notice board, reading tables with lamps and chairs, records shelves (bankers boxes, binders), filing cabinets, document boxes, office desks, storage shelving, back exit with steps |
| **Storefronts A-D** (P3, partial) | STOREFRONT_A-D | shop, back room | explorable generic shells: glass door, windows, a blank sign band, a counter, shelving, a back room and exit. Tenants are left unassigned because the bible names no other businesses. |

## Shared fixtures (`Shared_Props/`, 49 GLBs)

These are reused across locations, and all use one atlas material.

* **Shelving:**
  * gondolas: 5 grocery stock sets, snacks, health;
  * wall shelves: grocery, health, mart, games, used games, consoles;
  * dispensary shelf, records shelf.
* **Refrigeration:** dairy, frozen and drinks reach-in coolers; chest freezer; produce wall case.
* **Produce:** produce table.
* **Counters:** checkout lane, service counter, retail counter, mart counter, pharmacy counter, coffee station,
  reception desk.
* **Supermarket props:** basket stack, cart corral, grocery bag, pallet stack, pallet rack.
* **Game shop:** new and used game racks, console case, demo station, poster board.
* **Gas station:** fuel pump, pump island, canopy, price sign, air pump, ice chest.
* **Archive:** filing cabinet, document boxes, reading table, notice board.
* **Seating:** waiting chairs.

Each fixture:

* has its origin at the floor centre, with the front facing +Z;
* has convex collision;
* has interaction points in its metadata.

Fixtures are placed with wall snapping: wall units sit 1 cm off the real wall face. Pack 03 furniture is reused by name
(desks, chairs, shelving, boxes, toilets, sinks, CRT TV, game console, clocks, calendars, lamps).

## Textures and materials

* **Atlas:** `Textures/T_Com4_Atlas.png`, 512 x 512, palette-locked, 149 regions. It contains:
  * fixture swatches;
  * 39 product strips (fictional groceries, drinks, frozen food, household, health, snacks, motor oil, pill bottles);
  * game cases (12 fictional titles), console boxes, binders, bankers boxes;
  * store signs, aisle and department signs, staff, exit and restroom signs, fuel prices;
  * register, pump face, conveyor, price tags;
  * 6 fictional game posters and window banners.
* **Materials:** `M_Com4_Atlas`, `M_Com4_Glass` and `M_Com4_Glow` (emissive: light panels, lit signs, screens). All use
  nearest filtering and no repeat.
* **Building shells:** Pack 01 materials only (storefront brick and concrete, red brick, floor and ceiling tiles,
  drywall, carpet, linoleum, basement concrete, storage concrete, bathroom tiles, roofing).
* **Branding:** every brand is fictional: Greyhaven Market, Game Haven, Quarry Fuel / Food Mart, Hollis Drug, and the
  NOVA / ORB consoles. No real logos or game artwork are used.

## Performance

* **Draw calls:** each location is one building mesh plus one batched furnishing mesh. They use the shared atlas
  material and Pack 01 materials.
* **Triangles:** about 21k for the supermarket (building and furnishing) and 4–13k for each other location. That
  counts fully stocked shelves, because one block carries four product facings.
* **Lights:** few and shadowless (5–16 omni lights per location). The fluorescent look comes from emissive troffer
  panels.
* **Collision:** simple trimesh collision for walls, floors and furnishing; convex boxes on doors and fixtures.

## Limitations

* No screenshots or renders were made, so the look has not been checked by eye. The checks are structural,
  walkability and engine-load only.
* Products are textured blocks (four facings each), not individual pickable items. Pickups stay in Pack 08.
* The doors are interactive nodes in the closed pose. There are no door scripts, quests or NPCs. Eddie is not included
  (Pack 06).
* Storefronts A–D are generic shells; `COMMERCIAL_SPARE` is still empty because the bible reserves it without
  naming a business.
* Gallery GLBs show individual buildings and fixtures. Only the Godot scenes combine a building with its furnishing,
  lights and markers into an explorable location.
