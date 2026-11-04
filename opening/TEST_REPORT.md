# Opening prototype — validation report

Validated on 2026-11-03 against Godot 4.3 stable, Linux x86_64, headless mode. Base: `0d8088dc6dff65a526f2b09df777f0fa92ab445e`. No screenshots, concept art or replacement assets were generated.

## Repository inspection

- Read `docs/THE_VEIL_MASTER_CONTEXT.md`, residential scene metadata, residential README, furniture generation source, combined town/residential scene and `greyhaven_layout.json`.
- The source had no runnable `project.godot` and no gameplay GDScript. Existing systems available to reuse were mesh collisions, home furnishing instances, interaction/pickup metadata, wake-path markers, lot placement and town journey markers.
- Residential metadata and baked clock art say **6:47**; the explicit requested/master-context **6:42 PM** takes precedence in this runtime only. Source art is preserved.
- No commercial building pack, sedan mesh or existing vehicle implementation was found. The prototype ends at the existing supermarket parking marker and supplies guided driving without a new model.
- Supermarket-first is used only to end this grocery opening at an existing destination. The subsequent game-shop visit and mist sequencing remain unresolved and unimplemented.

## Executed checks

| Check | Result / scope |
|---|---|
| Godot editor import | Passed with website folder excluded; no errors in final import log |
| Main scene launch | Loaded and ran 120 frames headlessly; exit 0; no script/parser errors |
| Required interaction metadata | More than 20 targets resolved; front door, fridge and keys found |
| Fridge targeting | Contextual focus selected fridge from kitchen position using physics line-of-sight check |
| Keys targeting | Contextual focus selected keys from entry position |
| Departure gate | Front door refused departure before grocery/key requirements |
| Out-of-order pickup | Keys collected before fridge; did not bypass fridge requirement |
| Fridge/door animation state | Opening updated progression and retained hinge state after tween completion |
| Real collision body: wake route | Capsule moved through the authored bed → bedroom door → living room → front door → porch → driveway marker path |
| Real collision body: kitchen | Capsule moved from bedroom through hall/living room into kitchen fridge approach |
| Drive idle | No movement without throttle |
| Drive braking | S input brought speed to zero |
| Drive arrival | W input and drive updates reached the actual supermarket parking marker, set completion and ended the drive |
| Existing embedded GLB images | Python/Pillow verification identified one corrupt image in pre-existing `docs/Eerie_Customer_TPose.glb`, image 11; website folder excluded from Godot rather than modifying the GLB |

`opening/tests/smoke.gd` printed **OPENING_SMOKE: PASS** and exited **0**. It instantiates the real opening scene and uses its collision body, interactions and drive updater. Interaction focus uses camera placement in the test; key presses and mouse movement were not manually exercised through a desktop UI. The drive test feeds Godot input actions and fixed delta updates rather than real-time human driving.

## Engine diagnostic

Both the main-scene headless run and smoke test print the Godot dummy-renderer diagnostic `Parameter "m" is null` from `mesh_get_surface_count` on teardown. Exit codes remain 0 and the smoke assertions pass. The source of this renderer diagnostic has not been isolated; it is not claimed fixed. Headless success does not establish correct material rendering.

## Not tested / unfinished

- No rendered or human desktop playtest, Windows export, packaged executable, gamepad/mobile validation, performance profiling or visual/material review.
- Pause/resume, manual mouse feel, every optional household hinge/switch and restart need desktop playtesting. Test coverage concentrates on the required opening path.
- Kitchen/driveway traversal tests use direct capsule velocity and physics frames, not simulated WASD movement; there is no assertion about movement feel.
- Driving is guided, without free steering/reverse, vehicle collisions or visible sedan/interior. Intersection camera turns snap. No traffic simulation or audio.
- Existing characters are static visual placeholders; no conversations/animation/crowds were implemented.
- Fridge door animates and inspection text establishes its empty state, but the source fridge carcass is solid and has no visible hollow shelves.
- No supermarket building/interior, purchases, playable follow-up destination, save/load or supernatural event.

## Preservation

All changes are confined to the new gameplay/configuration/documentation files, `.gitignore`, and `docs/.gdignore`. Asset import settings regenerated during local Godot validation were restored before commit. Existing asset models, textures, scene files, generator scripts and gallery HTML are unchanged. Work is committed only to `work/opening-prototype`; Claude's branch is neither merged into nor updated by this work.

## Browser export follow-up

- Added a Godot 4.3 single-threaded Web preset and click-to-capture mouse input for browser user-gesture requirements.
- Official Godot 4.3 export templates successfully produced the release Web build. Prepared gzip transport files round-trip to the original declared pack/engine lengths (13,761,376 and 35,376,909 bytes).
- The cloud-browser HTTP preview displayed Godot's missing-feature notice for WebGL2 and Secure Context. No browser gameplay or visual playthrough is claimed. HTTPS hosting addresses the secure-context requirement; the browser still needs WebGL2 support.
- The browser build reuses the existing opening source and assets. Claude's branch and the gallery remain unchanged.

## Blank browser screen repair

The first Web export omitted `opening/player.gd` and `opening/progress.gd`: the source-project test passed, but the actual exported pack failed with `Preload file ... does not exist`. This prevented the opening script from loading, leaving the default blank viewport. The Web preset now explicitly includes both scripts.

The repaired **exported pack**, without access to source-project resources, was tested with:

```sh
godot --headless --main-pack /absolute/export/index.pck --quit-after 120
godot --headless --main-pack /absolute/export/index.pck --script /absolute/TheVeil/opening/tests/smoke.gd
```

The pack launch had no script/parser errors. The full exported-pack smoke test printed `OPENING_SMOKE: PASS` and exited 0, exercising the same house traversal, targeting, progression, braking and arrival checks. There are UID warnings that fall back to valid text paths and the previously documented dummy-renderer teardown diagnostic; these remain unresolved. Rendered browser playthrough remains unverified in the WebGL2-limited cloud browser.

The transport postprocessor now rejects packs missing either required script remap and includes a pack hash in download URLs so updated game data does not reuse old browser-cached payloads.

## 3D visibility compatibility mitigation

The user's screenshot after the missing-script repair showed the HUD and town sky but no structures. The exported pack contains 1,596 MeshInstance3D nodes / 4,327 surfaces, including valid house/town meshes and the expected player camera at `(30.65, 2.31, -85.05)`. Thus mesh absence in the archive is not the explanation established by these checks. The exact failure on the user's graphics driver remains unconfirmed.

All sampled static meshes used compressed vertex attributes. As a compatibility mitigation, the Web runtime rebuilds static meshes as ordinary uncompressed ArrayMesh surfaces, caching by original resource and preserving vertices, materials and instancing. Skinned and blend-shape meshes are excluded. No source GLB, texture or asset scene is replaced.

`render_contract.gd`, run against the exported pack with the fallback explicitly invoked, passed checks for 1,593 static instances: identical vertex arrays, identical material references/surface counts, and no compressed vertex attributes after reconstruction. The exported-pack gameplay smoke test also passed. These are data/logic checks, not a claim of visual browser success.

The original town scene already had a WorldEnvironment; the prototype had added a competing environment. Opening lighting now uses the existing environment node and disables the duplicate original sun, ensuring fog is actually off. The HTML page now exposes a Graphics diagnostics panel with initialization status and client errors to support further investigation if the compatibility mitigation does not resolve rendering.
