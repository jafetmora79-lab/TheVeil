# Browser gallery repair

The game files under `THE_VEIL_ASSETS_V2` are unchanged.

## White geometry

Pack 02 GLBs contain Godot `-colonly` and `-convcolonly` nodes. Godot imports these as collision shapes and hides their meshes; standard glTF viewers render their unmaterialed geometry, which can obscure the textured visual meshes with white shapes.

The GLBs also reference external relative PNGs. They already contain glTF PBR materials and UV transforms; they do not require `.tres` parsing for browser display. Godot's `.import` files substitute shared `.tres` materials when importing into the engine.

`preview-glb.js` makes a separate GLB in browser memory on selection. It removes mesh references only from collision nodes, embeds the referenced PNG bytes, and sets texture samplers to nearest-neighbor. It retains visual geometry, colors, alpha settings, UVs, KHR_texture_transform, PBR settings, and wrap modes. The original file is never overwritten. The download link saves that self-contained `_browser.glb` preview.

## Discovery and counts

A previous replacement corrupted the `PREFIX` string. API refresh consequently removed all assets from the list while the already-loaded model stayed visible. `gallery.js` uses the literal `THE_VEIL_ASSETS_V2/` prefix and retains the bundled catalog on failed, truncated, or unexpectedly empty API responses. Counts distinguish total models, total assets, and visible filtered entries. Pack 02 selects all Greyhaven GLB/GLTF models.

The bundled catalog is in `docs/index.html`; the page refreshes discovery from the configured branch on startup and via Refresh GitHub assets. New supported uploads on this branch appear through live discovery; API rate limiting is reported visibly.

## Validation (no images or videos generated)

- Converted all 157 repository GLBs in memory: 632 external texture references embedded; 135 collision-node mesh references removed.
- Every referenced image exists. Embedded buffer view offsets and output lengths checked.
- Visual mesh primitives, accessors, and material definitions compared unchanged.
- All generated samplers use nearest-neighbor min/mag filtering.
- Discovery and filter tests: 380 assets, 157 models, Pack 02 results, search results, API failure fallback, and empty-tree protection.
- JavaScript syntax checked. No screenshots, renders, or videos generated.
