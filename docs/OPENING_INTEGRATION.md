# Final-game opening integration

Base: `claude/final-merged` at `a54662d99eab765ace8884403eb4b28c50c93274` (latest integrated build inspected).
Handwashing source: `codex/chapter1-handwashing-polish` at `fca1ef2456e4029dd13bd94993a365a730092e8a`.
Delivery branch: `codex/final-opening-polish`. Claude branches are unchanged.

## Changes

- Integrates only the handwashing scripts/test from the polish branch. The base bathroom script was unchanged since the polish base, so both patches applied without conflicts.
- Keeps the original sequence duration and story/control flow. Adds a 26 cm washing-camera lean, limits sleeve extension to 1.55, and keeps rotated full hand bounds clear of the bathroom wall. Existing palm/finger corrections and contact-driven splashes remain.
- New Game asks for an optional name (24 characters); Cancel leaves the current state intact. Blank names display YOU. The identity is used only for the player subtitle label, never NPC identity, story data, scene nodes or quest keys.
- Saves/checkpoints include a backwards-compatible `player_name` field. Old normal saves default to YOU; old checkpoints lacking the field retain the current player's name. Save version unchanged.
- Main menu uses `game/ui/backgrounds/greyhaven_market.png`, a real unedited 1280x720 Godot 4.3 Compatibility capture of the existing market and night lighting, without HUD. It is not AI artwork. The menu is placed over the darker right half. No world models, lighting presets or environments were changed.

Capture provenance: existing World.tscn, restored mist-stage town, market-relative camera `(15, 1.7, -20)` looking at `(-3, 2.4, 2)`, FOV 70. Rendering used Linux Mesa llvmpipe. The image shows the game assets as rendered, with no invented creature or composited scenery.

## Validation actually performed

Godot 4.3 stable, isolated runtime copy, headless fixed 60 FPS:

- `game/tests/handwash_test.gd`: 14 checks passed, 0 failures; full hand wall clearance, limited extension, separate wrists, smooth turns, water contact, dry intervals, cleanup, controls and Chapter 1 objective.
- `game/tests/opening_test.gd`: 222 checks passed, RESULT PASS (0 failures); existing opening/story interactions through the Chapter 5 start.
- `game/tests/qa_softlock_test.gd`: 9 checks passed, RESULT PASS; late-game save repairs retained.
- `game/tests/player_name_test.gd`: 17 checks passed, 0 failures; trimming, control characters, length, Unicode, blank fallback, save/load, old saves, checkpoints, prompt cancellation, player vs NPC subtitle labels, confirmed new-game startup and story reset.
- Actual Compatibility rendering: captured the existing market, menu and name prompt; inspected menu placement and prompt layout. No animation appearance claim is based on headless tests.
- `git diff --check`: clean.

The existing opening harness also prints its pre-existing initial `Identifier not found: Game` diagnostic from interactable.gd before completing all assertions. Import/exit logs include existing resource UID/cache and resource-leak warnings; this is not a warning-free run. These were outside the requested opening polish scope.

Windows execution and a complete Chapters 1-16 manual playthrough were not performed. No Windows binaries or ZIPs were rebuilt in this change. Existing checked-in builds do not contain these new source changes until exported.

## Game-shop mist menu follow-up

The menu now shows the actual Game Haven storefront rather than Greyhaven Market. New capture: `game/ui/backgrounds/game_haven_mist.png`, 1280x720, existing World.tscn and active mist-stage lighting, game-shop-relative camera `(10, 1.7, -15)` looking at `(-2, 2.0, 1)`, FOV 70. The existing mist node followed this camera during capture. No game geometry, lighting presets or encounter scripts were changed.

`game/ui/backgrounds/menu_mist.gdshader` overlays slow drifting fog using the existing Pack 09 `T_Veil_MistNoise.png`, the existing layer shader's drift/noise combination and stepped opacity. It is a menu-only 2D adaptation over the real screenshot, not a live town simulation. Two noise samples per pixel, no extra viewport, screen/depth reads, particles or per-frame GDScript work. The layer ignores mouse input and sits below the controls. The original market capture is preserved.

Validation: `player_name_test.gd` rerun, all 17 checks pass. Rendered the actual menu under Godot 4.3 Compatibility/llvmpipe, captured an 80-frame 4-second preview and checked frames differ as the mist drifts. Shader compiled without errors. Existing exit resource warnings remain. Windows performance and execution remain untested. No gameplay or handwashing source changed in this follow-up.
