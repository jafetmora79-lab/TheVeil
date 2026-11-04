# THE VEIL - Story canon decisions

This log records decisions the project owner **explicitly** made or approved. It also records the production
choices taken while implementing them, each marked as not canon. The full story context, with canon-status tags, is
in [`docs/THE_VEIL_MASTER_CONTEXT.md`](../../docs/THE_VEIL_MASTER_CONTEXT.md).

**Conflict order:** latest explicit owner direction > this log and the other story documents > the bible > assistant
suggestions.

**Dates** are the dates of the commits that recorded each decision.

## Owner-approved decisions

| Date | Decision | Source / where it applies |
|---|---|---|
| 2026-11-03 | **Opening (bible 2.1, ESTABLISHED):**<br>• the protagonist wakes Friday at 6:42 PM;<br>• he finds the fridge empty;<br>• goal "Get some groceries";<br>• he takes the car keys, leaves the house and drives the old sedan into a still-normal Greyhaven;<br>• no mist during the opening drive. | Bible 2.1 / Act 0. Implemented: `game/` Phase 1 |
| 2026-11-03 | Eddie and Marcus are separate people: Eddie is the game-shop clerk, Marcus is Noah's father. | Bible 4 |
| 2026-11-03 | Visual direction: quirky low-poly geometry, pixel-art textures, PS1-era indie-horror feel, no photorealism. | Bible 1 |
| 2026-11-04 | The owner's **hand-made Eddie** (Blender) is the art-direction reference for every human character. | Owner upload; `06_Characters/Commercial_NPCs/CHR_Eddie.glb` (commit `5256f68`) |
| 2026-11-04 | **Marcus rev 4 approved** ("I love it, go on with the other ones"). The rest of the cast was rebuilt in the same style. | Commit `e7a252e` |
| 2026-11-04 | Facial expressions must not redesign approved characters. Texture-swap faces (VeilFace) were chosen. | Owner brief; `06_Characters/Facial/` (commit `fba2b9b`) |
| 2026-11-04 | **Wanderer removed** from the creature roster. Pack 07 is Colossus, Mist Tentacles (3 sizes), Hound, Skitter and Shellcrawler. No humanoid enemies. | Owner's Pack 07 brief; `07_Creatures/Documentation/README.md` |
| 2026-11-04 | The opening drive must last **at least 60 s**. Greyhaven was extended (Route 9 county road, Harlow Ln / Aspen Ct / Fern Ct) and the player's house **moved to Fern Ct**. | Owner's Phase 1 brief; `docs/HANDOFF.md` 9.3 |
| 2026-11-04 | No screenshots, renders, turntables or videos. The owner is the visual tester. | Standing instruction |

## Production choices awaiting owner confirmation (NOT canon)

| Date | Choice | Why / status |
|---|---|---|
| 2026-11-04 | **Phase 2 errand order:** after parking, the supermarket and the game shop can be done in **either order**. No mist yet. | Bible 2.2 / open decision 11.2 leave the stop order open, so none was locked. |
| 2026-11-04 | **Supermarket cashier:** an unseen speaker called "Cashier". | No cashier is named in the bible. Placeholder. |
| 2026-11-04 | **Horror game the protagonist buys:** untitled. | Title TBD. Placeholder. |
| 2026-11-04 | **Eddie's and the cashier's lines:** marked `"draft": true` in `game/data/dialogue.json`. | Working lines, to be replaced by the script. |
| 2026-11-04 | **Police officer model:** `CHR_Police_Officer` is an **Officer Hayes candidate** only. | Hayes' identity is TBD (bible 4.9). |
| 2026-11-04 | **Marcus at the game shop:** not placed. | Bible 2.2 puts him there at the mist's arrival (WORKING DRAFT), which Phase 2 does not reach. |

## Still open (bible section 11)

The list is unchanged:

* the protagonist's name and backstory;
* the exact moment the mist arrives;
* the secondary cast (Danny, Walter, Kevin, Mr. Bell, Officer Hayes);
* Noah;
* which deaths are scripted and which are preventable;
* the lore of the mist;
* the four working endings;
* the Day 7 breach;
* final monster rules;
* balance values.

Record a decision here only when the owner states it.
