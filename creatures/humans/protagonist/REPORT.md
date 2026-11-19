# Meshy protagonist: rig

Source: `source/protagonist_meshy.glb` (Meshy, 5,045 tris, one 2048 px texture). The texture is untouched (shown nearest-neighbour in Godot).
Built by `creatures/tools/build_protagonist_meshy.py` (derived from the Sarah build): turned to face the game's forward, scaled to 1.78 m, welded and flat shaded,
the same 51-bone humanoid rig (same bone names as Sarah, so the game's NpcAnimator and all clips work), automatic weights, and the head fix
(head, hair and jaw 100% on the Head bone, short blend through the neck).
Clips: idle, walk (planted-foot IK, 0.548 m/s, no slide), head_turn, nervous_idle, injured_idle, scared_reaction, one-frame hand poses.
Output: `game/prototypes/protagonist_meshy/CHR_Protagonist_Meshy.glb`. Test: `game/tests/protagonist_meshy_test.gd`.
Not in any game scene yet. No face expression decals yet (they need the same capture/paint pass Sarah had).
Fingers are laid out from the hand's proportions (the hand is a mitten shape), so they curl as a block.
Sheet: `work/protagonist_rig_sheet.png`.

## Test scene
`godot --path . res://game/prototypes/protagonist_meshy/ProtagonistTest.tscn` (F6 in the editor): the real chapter 7 supermarket with the protagonist at the till, animated by the game's NpcAnimator (idle, look-at with the torso-twist assist, talking gestures, scared mood). Walk up and press E. Keys: 6/7 body calm/scared, 8 walk to the doors and back. Screenshot mode: `-- shots <dir>`. Sheet: `work/protagonist_test_sheet.png`. Save file is backed up and restored.
