# THE VEIL - Character roster

This roster covers models, identities, rigs, relationships and fates. Identity and role text follows
`docs/THE_VEIL_MASTER_CONTEXT.md` section 4. Model data is from
`06_Characters/Documentation/CHARACTER_MANIFEST.json`.

**Approval status** is shown per model. A model's existence does not make its look canon unless the owner approved
it.

## Shared rig and faces

* **Rig:** every current model uses the Eddie humanoid rig (`Hips` ... `Head`, `Left/RightUpperArm` ...,
  `Socket_Head` / `Socket_Back` / hand sockets).
* **Animations:** no body animation clips exist yet. The game lowers Eddie's arms at runtime.
* **Faces:** texture-swap through `06_Characters/Facial/veil_face.gd` (VeilFace):
  * 10 expressions, eye actions and visemes;
  * talking styles: idle, angry, scared, happy and whisper;
  * per-character atlases in `Facial/Faces/T_Face_<Name>.png`.

## Named cast

| Character | Model (current) | Look status | Role (bible) | Relationships | Fate |
|---|---|---|---|---|---|
| Protagonist | `Protagonist/CHR_Protagonist.glb` (2,706 tris) + `CHR_Protagonist_FP_Arms.glb` | Style rev 4. Built in the approved style, not individually approved. | Ordinary man, early-to-mid 30s, lives alone (ESTABLISHED). Name TBD. | Lives in Greyhaven (Fern Ct house in the game build). | Player |
| Eddie | `Commercial_NPCs/CHR_Eddie.glb` (2,740 tris, 1.82 m) | **Owner-made reference**. Do not modify. | Game-shop clerk, 34 (WORKING DRAFT); sarcastic, loyal | Works at the game shop; sells the protagonist the game (Phase 2, draft lines) | TBD |
| Marcus | `Marcus/CHR_Marcus.glb` (2,716 tris, 1.76 m) | **Approved** 2026-11-04 | Noah's father, 43 (WORKING DRAFT); protective, impulsive | Father of Noah; searching for him | TBD |
| Ruth | `Civilians/CHR_Ruth.glb` | Style rev 4 | Retired librarian, 68 (WORKING DRAFT) | Greyhaven history | TBD |
| Sarah | `Civilians/CHR_Sarah.glb` | Style rev 4 | Paramedic (WORKING DRAFT) | Emergency response | TBD |
| Frank | `Commercial_NPCs/CHR_Frank.glb` | Style rev 4 | Security guard (WORKING DRAFT) | Local security | TBD |
| Lena | `Civilians/CHR_Lena.glb` | Style rev 4 | Student investigator (WORKING DRAFT) | Disappearances | TBD |
| Officer Hayes? | `Police/CHR_Police_Officer.glb` | Style rev 4. **Candidate only**. | Police officer (WORKING DRAFT, details TBD) | TBD | TBD |
| Noah | none | Do not model until his age and look are confirmed | Marcus's missing son (ESTABLISHED) | Son of Marcus | TBD |
| Danny, Walter, Kevin, Mr. Bell | none | Roles TBD | Named in earlier planning only | TBD | TBD |
| Cashier (supermarket) | none (unseen) | **Placeholder speaker**. Not in the bible. | Phase 2 checkout lines only | - | - |

**Superseded backups:** `_v1`, `_v2` and `_v3` versions are kept next to each model and listed in the manifest. Do
not use them in game scenes.

## Creatures (Pack 07)

The bible's threat list is being updated to match.

| Creature | Model | Bible status |
|---|---|---|
| Colossus | `07_Creatures/Colossus/CRT_Colossus.glb` | In the bible (WORKING DRAFT); look now built |
| Hound | `07_Creatures/Hounds/CRT_Hound.glb` | In the bible (WORKING DRAFT); look now built |
| Mist Tentacles (Thin / Medium / Large) | `07_Creatures/Mist_Tentacles/` | Added by the owner's Pack 07 brief |
| Skitter | `07_Creatures/Skitter/CRT_Skitter.glb` | Added by the owner's Pack 07 brief |
| Shellcrawler | `07_Creatures/Shellcrawler/CRT_Shellcrawler.glb` | Added by the owner's Pack 07 brief |
| Wanderer | none | **Removed** by the owner's Pack 07 brief |

Behaviour, detection and damage values are TBD for every creature.
