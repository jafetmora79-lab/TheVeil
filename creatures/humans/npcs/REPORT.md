# Meshy NPCs: rigged like the protagonist

Sources (untouched): `source/*.glb` - eddie (Ghost Kart hoodie), plaid_shirt (woman with a shoulder bag), police_officer, teen_blue_jacket, bearded_man. All have the protagonist's body (A-pose, same proportions), a 2048 px texture and about 5,000 triangles.
Meshy scales every model to the same size, so the real heights are ASSUMED (a parameter, easy to change): eddie 1.76 m, plaid_shirt 1.66, police_officer 1.82, teen_blue_jacket 1.62, bearded_man 1.80.

Built by `creatures/tools/build_npc_meshy.py -- <root> <slug> <height> [debug]` (the protagonist build, made generic). Output: `game/prototypes/npc_meshy/CHR_<slug>_Meshy.glb` + `<slug>.json` (walk speed), wrapper `npc_meshy.gd` (`VeilNpcMeshy`), test `game/tests/npc_meshy_test.gd` (all five pass: 51 bones, six clips, height, facing, planted feet under 5 mm, elbows and wrists, head fully on the Head bone), line-up `game/tests/npc_meshy_lineup.gd`.
Same rig, bone names and clips as Sarah and the protagonist: idle, walk (planted-foot IK), nervous idle, injured idle, head turn, scared reaction, hand poses. The game's NpcAnimator and the look-at assist work on them as they do on the others.
Per-character handling added for these models:
- detached pieces that automatic weights cannot skin (a shoulder bag, a strap) get distance weights;
- loose trunk accessories (bag, strap, belt, holster, gear) are weighted rigidly to the trunk bone nearest to them, so they do not stretch when an arm moves; hands, boots, sleeves and hair keep their normal weights;
- every vertex keeps at most 4 bone influences (the head fix is applied after that), so Godot uses lightweight 4-weight skinning;
- the head, hair and jaw are 100% on the Head bone (same fix as the protagonist).
Not done: face expressions (each needs aligned expression images), the textures are untouched.

## Head-turn fix (neck pivot and per-character neck level)
Some heads sat too far back / sideways when turned: the head and neck bones pivoted at the middle of the body, 2 to 3 cm in front of the real neck, so a turn swung the head; and for the teen (chin much lower than the others) the jaw fell in the blend zone and stretched.
`build_npc_meshy.py` now measures, per character, the neck centre (front to back) and the neck level (the smallest front extent between chest and chin): the Neck/Head joint sits at that centre, and the 100%-Head weighting starts at that neck level. Before/after: `work/head_turn_before_after.png`.
