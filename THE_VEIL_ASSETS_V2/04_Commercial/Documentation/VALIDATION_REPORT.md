# THE VEIL - Pack 04 Validation Report

Automated file, architecture, walkability and engine checks only. **Nothing was captured from the renderer** (no screenshots), so the look of the stores has not been verified.

**Result: PASS** - 0 failures, 1 warnings

* GLB names unique across the repository: True
* T_Com4_Atlas.png 512x512 palette-locked: True; 150 atlas regions
* GLBs checked: 74, 76588 triangles
* supermarket: 5 rooms, 58 fixtures, walk paths 19/19 from outside the entrance
* video_game_store: 3 rooms, 25 fixtures, walk paths 13/13 from outside the entrance
* gas_station: 4 rooms, 28 fixtures, walk paths 13/13 from outside the entrance
* pharmacy: 3 rooms, 19 fixtures, walk paths 12/12 from outside the entrance
* municipal_archive: 5 rooms, 41 fixtures, walk paths 12/12 from outside the entrance
* storefront_a: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* storefront_b: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* storefront_c: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* storefront_d: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* res:// references checked: 433
* gallery lists 74/74 Pack 04 GLBs; Pack 04 filter: True

## Locations

| Location | Priority | Rooms | Exterior doors | Fixtures | Walk paths | Lights | Status |
|---|---|---|---|---|---|---|---|
| supermarket | P1 | 5 | 3 | 58 | 19/19 | 16 | pass |
| video_game_store | P1 | 3 | 2 | 25 | 13/13 | 5 | pass |
| gas_station | P2 | 4 | 2 | 28 | 13/13 | 8 | pass |
| pharmacy | P2 | 3 | 2 | 19 | 12/12 | 7 | pass |
| municipal_archive | P3 | 5 | 2 | 41 | 12/12 | 8 | pass |
| storefront_a | P3 | 2 | 2 | 4 | 5/5 | 4 | pass |
| storefront_b | P3 | 2 | 2 | 4 | 5/5 | 6 | pass |
| storefront_c | P3 | 2 | 2 | 4 | 5/5 | 6 | pass |
| storefront_d | P3 | 2 | 2 | 4 | 5/5 | 6 | pass |

## Failures

None.

## Warnings

* Godot check not run
