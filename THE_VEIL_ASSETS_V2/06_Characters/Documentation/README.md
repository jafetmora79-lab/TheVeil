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
