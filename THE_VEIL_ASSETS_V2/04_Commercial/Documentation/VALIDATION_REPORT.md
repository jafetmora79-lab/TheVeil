# THE VEIL - Pack 04 Validation Report

Automated file, architecture, walkability and engine checks only. **Nothing was captured from the renderer** (no screenshots), so the look of the stores has not been verified.

**Result: PASS** - 0 failures, 0 warnings

* GLB names unique across the repository: True
* T_Com4_Atlas.png 512x512 palette-locked: True; 149 atlas regions
* GLBs checked: 67, 77318 triangles
* supermarket: 5 rooms, 58 fixtures, walk paths 19/19 from outside the entrance
* video_game_store: 3 rooms, 25 fixtures, walk paths 13/13 from outside the entrance
* gas_station: 4 rooms, 28 fixtures, walk paths 13/13 from outside the entrance
* pharmacy: 3 rooms, 19 fixtures, walk paths 12/12 from outside the entrance
* municipal_archive: 5 rooms, 41 fixtures, walk paths 12/12 from outside the entrance
* storefront_a: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* storefront_b: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* storefront_c: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* storefront_d: 2 rooms, 4 fixtures, walk paths 5/5 from outside the entrance
* res:// references checked: 416
* gallery lists 67/67 Pack 04 GLBs; Pack 04 filter: True
* Khronos glTF-Validator: 67 files, 0 errors, 0 warnings
* Godot 4.3 headless import: exit 0, 0 error/warning lines
* renderer: OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
* Godot Supermarket.tscn: floor collision under 14/14 nav targets, 3 exterior doorways clear, 17 collision shapes, 16 lights
* Godot VideoGameStore.tscn: floor collision under 10/10 nav targets, 2 exterior doorways clear, 7 collision shapes, 5 lights
* Godot GasStation.tscn: floor collision under 9/9 nav targets, 2 exterior doorways clear, 10 collision shapes, 12 lights
* Godot Pharmacy.tscn: floor collision under 9/9 nav targets, 2 exterior doorways clear, 7 collision shapes, 7 lights
* Godot MunicipalArchive.tscn: floor collision under 7/7 nav targets, 2 exterior doorways clear, 9 collision shapes, 8 lights
* Godot Storefront_A.tscn: floor collision under 3/3 nav targets, 2 exterior doorways clear, 5 collision shapes, 4 lights
* Godot Storefront_B.tscn: floor collision under 3/3 nav targets, 2 exterior doorways clear, 5 collision shapes, 6 lights
* Godot Storefront_C.tscn: floor collision under 3/3 nav targets, 2 exterior doorways clear, 5 collision shapes, 6 lights
* Godot Storefront_D.tscn: floor collision under 3/3 nav targets, 2 exterior doorways clear, 5 collision shapes, 6 lights
* Godot: TOWN nodes=7122 (Greyhaven_Town_Complete.tscn = Pack 02 town + Pack 03 houses + Pack 04 commercial, rendered)

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

None.
