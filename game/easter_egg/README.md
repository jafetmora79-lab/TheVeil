# Neggy golden-face Easter egg — updated

Only the Neggy Easter egg is changed on this branch. No Skitter encounter, test launcher, house pointer, project configuration, chapter or normal gameplay code is included. The existing world.gd hook already adds EasterEggGolden.

- Wait: 30 cumulative seconds on foot in the woods before the town arrival; off the driving route.
- Lure: one selected tree shakes, rustles and drops six leaves every two seconds. Character remains hidden until the rush.
- At 10 m: the side-view face rushes into the exact screen centre in 0.2 s; the front-facing close-up holds for 0.25 s, fades into white over 0.8 s, then the white clears (1.55 s total).
- Audio: golden_impact_mix.ogg contains both the original 3-second scare and seconds 1–4 of the supplied grenade recording, loudness-matched and mixed into one 3-second clip.
- The tree is restored, control returns, health/inventory/story/position are unchanged, and the reaction subtitle follows the audio. Once per playthrough, persisted with existing egg flags.

Files: golden_peek.gd, tree_lure.gd, golden_impact_mix.ogg, tree_rustle.wav, their import metadata, and game/tests/easter_egg_test.gd. Existing golden_front.png/golden_side.png/golden_peek.png remain the supplied originals.

The location rules do not add a specific exclusion radius around the player home. They disable after town arrival.

Validation: the runtime/tree/face/audio regression checks passed on the distributed build; the updated test covers the 30-second threshold and two-second lure interval.
