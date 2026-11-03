# THE VEIL - Pack 06: Greyhaven Characters

Eight rigged, pixel-textured, low-poly story characters, plus first-person arms for the player.

* **Generated:** `Source_Scripts/build_characters.py`; the output is deterministic.
* **Validated:** `Source_Scripts/validate_characters.py`.
* **Results:** see `VALIDATION_REPORT.md`.
* **Dimensions and triangle counts:** see `CHARACTER_MANIFEST.json`.

Nothing in this pack was rendered or visually inspected. The validator checks files, skinning and engine behaviour only.

## Roster

The roster follows `docs/THE_VEIL_MASTER_CONTEXT.md`. Named story characters were used instead of anonymous NPCs, following the bible's own priority list.

| Model | Story character | Replaces requested slot |
|---|---|---|
| `Protagonist/CHR_Protagonist.glb` + `CHR_Protagonist_FP_Arms.glb` | Player character (name TBD) | Protagonist |
| `Marcus/CHR_Marcus.glb` | Marcus, 43, Noah's father | Marcus |
| `Commercial_NPCs/CHR_Eddie.glb` | Eddie, 34, game-shop clerk | Store clerk |
| `Commercial_NPCs/CHR_Frank.glb` | Frank, security guard | Adult male resident |
| `Civilians/CHR_Ruth.glb` | Ruth, 68, retired librarian | Older resident |
| `Civilians/CHR_Lena.glb` | Lena, student investigator | Adult female resident |
| `Civilians/CHR_Sarah.glb` | Sarah, paramedic | Supermarket employee (a named cast member was prioritised) |
| `Police/CHR_Police_Officer.glb` | Greyhaven officer; candidate for **Officer Hayes**, whose identity is TBD | Police officer |

**Noah is not built.** The bible says not to model him until his age and appearance are confirmed.

**Looks are design proposals.** They follow the bible's DESIGN PROPOSAL notes: the protagonist's gray jacket and dark jeans, Eddie's slouch, messy hair and worn hoodie, and so on. Faces, colours and small accessories are this pack's proposals, not new canon.

## Rev 3: sculpted Eddie and Marcus (new construction method, awaiting approval)

* **Models:** `Commercial_NPCs/CHR_Eddie_v3.glb` and `Marcus/CHR_Marcus_v3.glb`. They are built by `chr_sculpt*.py`,
  not by the primitive-assembly generator.
* **Method:** each character is a skeleton plus hand-placed organic volumes, smoothly blended into one continuous
  surface (signed-distance sculpting). That surface is converted to a mesh (marching cubes) and reduced to low-poly
  (quadric decimation), with denser budgets for the face and hands.
* **Construction:** clothing is volume over the body, so there is no hidden interior geometry. The face, nose,
  cheeks, jaw, ears, eye sockets and mouth line are sculpted; the eyebrows and glasses are explicit meshes.
* **Skinning:** bone-heat diffusion within anatomical groups.
* **Textures:** 256×256 pixel atlas painted per chart. The face is front-projected, and the eyes and mouth are
  painted exactly where the sculpt carved them.
* **Budget:** about 7.1–7.6 k triangles each, one material, the same 23-bone skeleton and socket conventions.
* **Build dependencies:** scikit-image, scipy, pyfqmr (`pip install scikit-image scipy pyfqmr`). Blender is not
  required.
* **Validation:** automated checks pass (`VALIDATION_REPORT.md`). The warnings are localized armpit and hip-crease
  stretch under extreme 70° test poses. 99% of edges stay within 1.6×, but a few crease edges reach 4–10×. These
  need hand weight-painting before animation.
* **Visual inspection:** none. Only the texture atlases were looked at, so the visual result is unverified and
  needs your review in the gallery.
* **Backups:** rev 1 and rev 2 models are kept unchanged as backups.

## Rev 2 art-direction pass: Eddie and Marcus (awaiting approval)

`Commercial_NPCs/CHR_Eddie_v2.glb` and `Marcus/CHR_Marcus_v2.glb` are the redesigned examples for the quirky
indie-horror direction. The v1 models stay untouched until the redesign is approved; a rebuild reproduces them
byte-identically. The same shared generator built both versions. The v2 features are switched on per character
in `chr_roster.ROSTER_V2` and implemented in `chr_body_v2.py`:

* **Proportions:** oversized heads (about 0.28–0.31 m), with the body re-proportioned below the neck so the
  total height stays correct. Per-character leg ratio, neck length, slouch and head lean.
* **Sculpted heads:**
  * 16 segments, packed toward the face so it gets twice the texels.
  * Controls for jaw, chin length and width, cheeks, brow, forehead slope and back of the head.
  * Geometric eyebrows with per-side shapes (raised quizzical brow or worried pinch).
  * Ears that stick out, with lobes and asymmetric height and angle.
  * Large, varied noses (bulb, droop, hook, bridge).
  * Painted eyes and mouths, bigger and more expressive (smirk with a tooth, worried frown, eye bags).
* **Arms:** shoulders, deltoids, biceps, elbows, forearm bulge and wrists, not pipes. Sleeve cuffs have real
  volume.
* **Hands:** chunky stylised hands with a palm, four two-segment fingers of different lengths and a two-segment
  thumb, curled per character.
* **Clothing:**
  * Jackets and hoodies are volume shells over the torso, with an open front, flared hem with thickness,
    closed shoulders and a raised collar.
  * The shirt underneath follows the torso.
* **Trousers and shoes:** trouser silhouettes (baggy or straight) with thick hems. Chunky shoes and boots with
  separate soles, turned-out toes.

| | Eddie v2 | Marcus v2 |
|---|---|---|
| Silhouette | lanky, sloped shoulders, slouch | broad wall of a man, short legs, hunched |
| Clothes | oversized open mustard hoodie, baggy jeans, huge duck-footed sneakers | open canvas work jacket with raised collar, navy flannel, straight work pants, heavy boots |
| Head | tall egg head, long jutting chin, big droopy nose, stick-out ears (one higher), lopsided hair swoop | wide square head, slab jaw, potato nose, heavy brow |
| Face | thick glasses, one quizzical raised brow, smirk | eyebrows pinched up with worry, bagged eyes, stubble |
| Hands | relaxed | big, half-closed |
| Triangles | 2,162 | 1,988 |

Both versions use the same 23-bone skeleton, a 256×256 palette-locked atlas and one material. Both pass the
full validator (`VALIDATION_REPORT.md`). Marcus's short, thick neck stretches up to 1.96× in the 60° head-turn
test, which is within the 3.0 limit. Nothing was rendered or visually inspected.

## Conventions

* **Space:** metres, +Y up, characters face **+Z**, origin between the feet.
* **Rest pose:** a relaxed A-pose. Every bone's rest rotation is identity.
* **Shared skeleton** (`Shared_Rigs/VEIL_Humanoid_Skeleton.json`): 23 bones named after Godot's `SkeletonProfileHumanoid`, so Godot's retargeting maps them automatically:
  * Root, Hips, Spine, Chest, UpperChest, Neck, Head
  * Left/Right: Shoulder, UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toes
* **Item sockets:** `LeftHand_ItemSocket` and `RightHand_ItemSocket` sit in front of each palm. The protagonist also has `Head_EyeLevel`. Godot 4.3 imports these as extra, unweighted bones, so attach items with a `BoneAttachment3D` that names them.
* **First-person arms** (`CHR_Protagonist_FP_Arms.glb`) are modelled in camera space:
  * Origin is the camera; parent the arms under the player's `Camera3D`. They look down −Z, the same as Godot.
  * 9 bones: Root plus both arm chains with the same names. The right hand rests in a grip pose with its socket ready for held items.
* **Skinning:** up to 4 weights per vertex, normalised. Joints blend across neighbouring bones, and hands, head and shoes are rigid.
* **Textures and materials:**
  * One 256×256 atlas per character (`Textures/T_Chr_*.png`), drawn only from Greyhaven palette colours: the Pack 01 ramps plus a small set of skin, hair, lip and reflective-tape ramps.
  * Every character uses the same atlas layout.
  * The atlas is **embedded** in the GLB, so the browser gallery and other tools show it.
  * The `.glb.import` remaps the material to `Materials/M_Chr_*.tres` (nearest filtering, no metal or specular effects), so Godot uses the shared pipeline material.
* **Budget:** about 1.1–1.3 k triangles per character (252 for the first-person arms), one material, one draw call. This suits integrated graphics and Android.

## Godot

* Instance the GLB, or `Shared_Rigs/Characters_Lineup.tscn` to see all of them.
* The import creates a `Skeleton3D` (23 bones plus sockets) and a skinned `MeshInstance3D`.
* For a `CharacterBody3D`, use a capsule about 0.35 m in radius, with height matching the character (1.60–1.83 m).
* No animations are included. Retarget Godot or Mixamo-style humanoid animation through the bone map, or author clips on this skeleton.

## Known limitations

* **Nothing has been visually inspected.** Proportions, faces and silhouettes are only checked numerically (height, orientation, deformation).
* **No animations, facial rig or finger bones.** Hands are mitten-style: palm, two-segment fingers and a thumb, all weighted to the hand bone.
* **Hidden geometry:** clothing and accessories are part of each body mesh, so the trousers under Ruth's skirt and the ends of the limb tubes inside the torso are a few centimetres of hidden geometry.
* **Sockets import as bones** in Godot 4.3, not as `BoneAttachment3D` nodes.
* **Story conflict:** the bible says the wake-up time is 6:42 PM, but Pack 03's alarm-clock texture shows 6:47. Pack 03 was not changed; this needs a decision.
* **Officer Hayes:** the officer's identity (gender, age, face) is unconfirmed. Treat the model as a generic officer until the story fixes it.
