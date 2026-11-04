# THE VEIL - Asset status

This is the real repository inventory and the latest validation results, as of 2026-11-04 (branch
`claude/practical-cray-hi2y54`).

**Validation coverage:** the checks cover structure, glTF validity, Godot import and scene and physics tests. They
are not visual verification. The owner is the visual tester, and no screenshots or renders are made.

## Packs

| Pack | Content | GLBs | Latest validation | Report |
|---|---|---|---|---|
| 01 Textures | Pixel-art textures and Godot materials | - | 0 failures | `Documentation/VALIDATION_REPORT.md` |
| 02 Town | Roads, sidewalks, street props, vegetation, utilities, fences, layout | 157 | 0 failures | `02_Town/Documentation/VALIDATION_REPORT.md` |
| 03 Residential | 23 house variants, interiors, furniture, player home | 201 | PASS, 0 failures, 6 warnings. Regenerated 2026-11-04 in the z-fight polish pass. | `03_Residential/Documentation/VALIDATION_REPORT.md` |
| 04 Commercial | Supermarket, game shop, gas station, pharmacy, archive, 4 storefronts, 49 fixtures | 67 | PASS, 0 failures, 0 warnings. Regenerated 2026-11-04. | `04_Commercial/Documentation/VALIDATION_REPORT.md` |
| 05 Vehicles | Player sedan, traffic, abandoned variants, transport props | 16 | PASS, 0 / 0 | `05_Vehicles/Documentation/VALIDATION_REPORT.md` |
| 06 Characters | Style-rev-4 cast, owner-made Eddie, VeilFace facial system, backups | 22 | PASS, 0 failures, 6 warnings | `06_Characters/Documentation/VALIDATION_REPORT.md` |
| 07 Creatures | Colossus, Mist Tentacles x3, Hound, Skitter, Shellcrawler (rigged, with clips) | 7 | PASS, 0 / 0 | `07_Creatures/Documentation/VALIDATION_REPORT.md` |
| 08 Inventory | Food and supplies, medical, puzzle items, tools and weapons | 53 | PASS, 0 / 0 | `08_Inventory/Documentation/VALIDATION_REPORT.md` |
| 09 Horror atmosphere | Mist, abandoned props, lighting / effects | 27 | PASS, 0 / 0 | `09_Horror_Atmosphere/Documentation/VALIDATION_REPORT.md` |

## Game build (`game/`, repository root is the Godot project)

* **Phase 1 (opening) and Phase 2 (town errands):** playable. The browser build is in `docs/play/`.
* **Tests:** `game/tests/opening_test.gd` reports `RESULT PASS`. It covers the wake-up, house, keys, drive (about
  83 s at 50 km/h), parking, both errands, the end card and save / load. `check_world.py` reports 0 failures.
* **Placeholders in the game:**
  * Cashier speaker;
  * untitled horror game;
  * draft Eddie / Cashier lines;
  * Eddie's runtime-lowered arms, because no body animations exist yet.

## Known gaps

* **Not implemented:**
  * Acts I-IV;
  * survival systems (hunger, thirst, health, weight, flashlight battery);
  * NPC body animation;
  * Noah and the secondary cast;
  * police / civic and underground locations.
* **Z-fighting:** about 99 m² of visible coplanar overlap remains, found by `Source_Scripts/zfight_scan.py`. It is
  mostly Pack 03 house shells (foundation band vs siding) and supermarket gondola tops above eye height.
* **Open edges:** about 141 m of open mesh edges in furniture, mostly hidden.
* **Draw calls:** about 2,300 per frame with the whole town loaded. This is heavy for browsers.
