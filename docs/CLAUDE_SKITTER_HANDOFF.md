# Claude handoff — optional rooftop Skitter encounter

## Owner request and status
The user approved the direction of the latest V5 test encounter and asked Claude to finish it for the real game. The Skitter still visibly floats. **Do not treat the animation or ground contact as finished.** Preserve the encounter's approved direction while fixing it and integrating it into your latest finished-game branch.

This handoff contains only the encounter script, its two original synthesized sounds, and a regression script. It deliberately excludes the temporary Chapter 3 save, turquoise pointer, F6 reset launcher, project.godot changes, EXEs and ZIPs. Nothing has been merged into a gameplay branch.

## Approved behavior
- Optional, non-story encounter at the distant house `Residential/Houses/EXT_HOUSE_12`, world origin approximately (214.0215, 0.15, 450).
- Only after `p3_mist`, on foot, controls available, outside dialogue/cinematics; once per playthrough via `egg_roof_skitter_seen`.
- Restrict the trigger to the designated player-facing approach side. Current tested house-local zone: abs(x) < 5.5, 12 < z < 20, -1 < y < 2. Verify that side and its bounds against the final house placement; do not let a rear/side/interior approach trigger the shot.
- Readable, lit rooftop reveal: slow animated crawl under a locked tracking zoom, then a higher arcing leap into a continuous first-person grab.
- The creature visibly tries to bite during the struggle. Centered pulsing red **GET IT OFF!** using `VeilUI` / VeilPixel; 12 individual left-click presses in 3 seconds.
- Success: no damage. Failure: halve **current** health, not max health. It leaves in both outcomes.
- Throw it to the player's LEFT onto the ground. It must face the actual camera/player, raise its front legs, and make the short insect-like screech.
- Then dart very quickly in a creepy LEFTWARD zigzag around the exterior and hide behind the house. No backwards sliding, retreat behind the player's back, wall clipping or disappearing in clear view.
- Return controls, camera and FOV; do not change inventory, objectives, companions or chapter progress. No repeat attack.

## Files
- `game/encounters/roof_skitter.gd`: current V5 implementation, **unfinished visual movement**.
- `game/encounters/skitter_hiss.wav`: short raspy insect stridulation/screech (latest V5).
- `game/encounters/skitter_rattle.wav`: rooftop/attack cue.
- `game/tests/roof_skitter_handoff_test.gd`: logic regression for success/failure, actual skeleton head-facing direction, leftward escape and house occlusion. Uses a throwaway test run; not a test launcher for the release.

Reuses the existing Skitter scene:
`res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn`.
Its rig faces +Z (Head lies ahead of Body in +Z). The existing Alert clip raises the front legs. Attack_Lunge is duplicated as a local looping Struggle/Bite animation.

## Priority fixes — floating and animation
1. Fix real foot/body contact with the roof and ground throughout crawl, leap, landing, hiss and escape. Current `_ground()` is a vertical ray helper; a successful comparison against that same helper is NOT proof of visible ground contact. Audit collider hits, roof/furniture/ground selection, the rest-pose `feet_y` offset, animated bone displacement and changing scale (0.55 to 1.0).
2. The script currently moves a collision-disabled CharacterBody3D manually. Prefer the game's collision-aware controller/navigation or equivalent swept motion on valid surfaces. Avoid visual hovering, gliding through geometry or stepping across unsupported spans.
3. Correct the grab/throw/landing animation transitions and root transforms. Align leg gait speed with travel speed; blend the held bite loop into a believable throw, ground impact, raised-leg threat and fast scuttle. Keep the approved first-person framing.
4. The V5 escape planner has explicit LEFT-side exterior waypoints and per-segment full-span sphere sweeps. Re-evaluate them for the final world placement. If a route is obstructed, choose another genuinely valid route or skip/defer this optional encounter. Never force a fallback through walls or silently substitute a backwards escape.
5. Ensure the entire creature, not just one sampled point, visibly disappears behind the house. Current end-of-route ray checks the body center against the house collider; verify the actual final render.
6. Keep the short insect-like sound. The user rejected earlier synthetic rising/whistling sounds and backwards-facing hiss staging. V5 verifies the animated Head-to-Body direction against the actual camera, not just root yaw.

## Integration
Base of this handoff: original `claude/easter-egg-golden` commit `e92c5d39512b7da8e36f5684563e89d83b932267`. This is an isolated source handoff, not the latest story branch. Apply only this handoff commit/files onto your current finished-game work; do not replace your branch with this older base.

The release-world hook has deliberately NOT been changed here. Add this once to the current world setup, after player/house nodes exist (the tested setup used deferred initialization):

```gdscript
var roof_egg: Node = load("res://game/encounters/roof_skitter.gd").new()
roof_egg.name = "OptionalRoofSkitterEncounter"
add_child(roof_egg)
roof_egg.setup.call_deferred(self)
```

Check for an existing hook before adding it. Keep this independent of the golden Neggy Easter egg and its separately published update (`codex/neggy-easter-egg-updated`, commit `73753f8`).

## Acceptance before merging into the finished game
- Manually view the entire encounter in the Compatibility renderer. **The user found floating despite earlier automated checks passing. Headless tests do not validate the animation's appearance.**
- Approach from the designated front, left, right, rear and interior; only the correct exterior side should trigger.
- Confirm continuous physical contact, clear rooftop visibility, readable mouth/leg biting motion and seamless leap/grab.
- Win and fail the clicks; confirm damage/control/camera restoration, unchanged story/inventory and no repeated encounter after save/load.
- Confirm the hiss faces the camera, the first escape movement is leftward, the run is fast and zigzagging, all geometry is respected and the monster hides behind the actual house.
- Keep the temporary test save, pointer and reset behavior OUT of the finished game.

The existing automated V5 logic test passed using its packaged executable. This is evidence for flow and state handling only, not a claim that the visible animation is correct.
