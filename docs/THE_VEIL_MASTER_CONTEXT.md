# THE VEIL — MASTER PROJECT CONTEXT & STORY BIBLE

> **Repository handoff for Claude, Codex, and future collaborators**  
> **Version:** 2026-11-04 (status notes added; see the `UPDATE 2026-11-04` blocks) | **Status:** Working narrative and production reference  
> **Important:** This document combines established decisions, earlier story-draft material, and explicitly marked open questions. **Do not mistake a proposal for locked canon.**

## 0. Instructions for any AI reading this file

1. Read this file before planning or generating assets, scenes, scripts, quests, or characters for THE VEIL.
2. Inspect actual repository files before assuming any asset or implementation exists. This document describes **intent**, not proof of implementation.
3. Preserve established character identities, setting, opening sequence, and visual style. Do not replace named characters with generic NPCs.
4. Resolve conflicts in this order: **latest explicit user direction > existing verified repository story documents > this working context > assistant suggestions**. Report conflicts instead of silently rewriting canon.
5. Keep the project achievable as a small/hobby-scale first-person survival-horror game. Prefer modular systems, reusable assets, and meaningful story beats over uncontrolled scope.
6. Do not generate screenshots, turntable renders, preview videos, or concept-art batches unless expressly requested. Preserve remaining generation budget.
7. Keep edits scoped to the requested pack or task. Never overwrite finished packs, established scenes, or game logic casually.
8. When a detail is marked **TBD**, check the repository and ask or flag it rather than inventing permanent canon.

### Canon-status legend

- **ESTABLISHED** — Supported by prior explicit project direction or repeated story planning.
- **WORKING DRAFT** — Appeared in an earlier story outline, but individual beats may still change.
- **DESIGN PROPOSAL** — Suggested visual/implementation direction; not fixed lore.
- **TBD** — Requires confirmation or is absent from available context.

---

## 1. Game identity and creative pillars

**Title:** THE VEIL  
**Genre:** First-person 3D survival horror with exploration, resource management, environmental storytelling, and limited combat.  
**Setting:** Greyhaven, a fictional American small town.  
**Core premise:** An apparently ordinary Friday evening becomes a struggle to survive when an ancient, unexplained supernatural mist engulfs Greyhaven. Residents disappear, creatures emerge, and survivors uncover fragments of a recurring phenomenon tied to the town's past.  
**Scope:** A coherent, achievable hobby-scale game, not an enormous open-world AAA production.

### Pillars

- **Normality before terror.** Establish a mundane, believable town before the first major supernatural event.
- **Atmosphere over spectacle.** Use sound, silhouettes, limited visibility, unsettling environments, and anticipation.
- **Survival with agency.** Scarce resources, meaningful exploration, limited combat, and choices with consequences.
- **Human stakes.** Distinctive survivors, trust, fear, disagreement, occasional humor, and some preventable losses.
- **Mystery without over-explanation.** The mist's origin is ancient and not neatly reduced to a simple laboratory accident or a conventional villain's plan.
- **Originality.** Horror-game Easter eggs can be subtle and original; do not copy protected characters, stories, or branded assets.

### Visual direction — ESTABLISHED

- Quirky, expressive, deliberately **low-poly** geometry and **pixelated** hand-authored textures.
- Retro indie-horror / PS1-inspired visual language, with readable silhouettes and slightly exaggerated proportions.
- Aesthetic touchstone: the *feel* of stylized indie horror such as *Shift at Midnight*, **not** a request to copy its assets.
- Avoid photorealistic or semi-realistic people, smooth generic primitives, glossy modern PBR looks, and inconsistent asset styles.
- Use the existing texture/material pipeline (Pack 01) and preserve cohesion across the town, characters, props, vehicles, and creatures.
- Keep models performant for Godot 4 on modest desktop hardware, with eventual Android optimization in mind.

---

## 2. Story foundation and opening sequence

### 2.1 Friday, 6:42 PM — opening (ESTABLISHED)

The protagonist, an ordinary adult man living alone in Greyhaven, wakes from an evening nap **on Friday at 6:42 PM**. The player begins inside his home, learns first-person movement and interaction, checks the kitchen, and finds the refrigerator nearly empty. The immediate, grounded objective is **“Get some groceries.”** The player retrieves car keys, exits the home, and drives an older everyday sedan toward the supermarket. He also intends to buy a horror video game during this outing.

**Critical continuity rule:** During the opening drive, Greyhaven is still a normal, inhabited town. People, businesses, traffic and ordinary life establish what will be lost. **The supernatural mist has not arrived yet. Do not trigger the Colossus or catastrophic town takeover during the initial drive.**

### 2.2 Game shop and arrival of the mist (WORKING DRAFT)

An earlier narrative draft places the protagonist in or around Greyhaven's independent video game shop with **Eddie** (the clerk) and **Marcus** (another important survivor) when the mist arrives and a gigantic **Colossus** is glimpsed. The survivors then move toward shelter, including the supermarket. This ordering is a working draft, not permission to contradict the established normal opening drive.

**Continuity check for implementation:** The grocery objective, supermarket visit, and game-shop encounter must be arranged into a believable playable sequence. Verify the intended stop order in the latest script before locking cutscenes, quest triggers, or travel routes.

> **UPDATE 2026-11-04 (implementation, not canon):** the playable build (Phase 2) lets the player do the supermarket
> and the game shop in **either order**, with no mist. The stop order therefore stays open. Eddie sells the game with
> draft lines. Marcus is not placed. See `THE_VEIL_ASSETS_V2/Documentation/STORY_CANON_DECISIONS.md`.

### 2.3 The Veil itself (ESTABLISHED / WORKING DRAFT)

The mist is an **ancient, unexplained** phenomenon associated with Greyhaven and its history. Earlier story planning describes recurring incidents rather than a one-off modern accident. The phenomenon disrupts familiar spaces, threatens survivors, and conceals entities. Survivors discover partial evidence, contradictory accounts, and clues about prior events.

**Do not lock in an unapproved origin** such as a corporation, laboratory experiment, cult summoning, extraterrestrial invasion, or single mastermind. The mystery should remain larger and older than the cast's immediate understanding.

---

## 3. Story structure — working act outline

The following is a **production-oriented synthesis of the earlier Acts 0–IV draft**. It preserves known beats without inventing exact dialogue, quest ordering, or cinematic details.

### Act 0 — Ordinary Friday (ESTABLISHED foundation)

- Wake at 6:42 PM; learn movement, household interaction, pickup and objectives.
- Discover empty refrigerator and grocery objective.
- Retrieve keys, leave home, enter and drive sedan.
- See Greyhaven in its normal state: residential streets, shops, and ordinary townspeople.
- Visit intended commercial destinations; establish Eddie and other survivors before the catastrophe.
- **Do not** start with supernatural fog or a monster attack.

### Act I — The town disappears (WORKING DRAFT)

- The supernatural mist arrives **after** the normal opening has been established.
- Sudden confusion, failed escape routes, missing people, strange sounds, and first encounters with dangerous entities.
- A colossal presence provides a frightening scale reference, but should not immediately become an ordinary boss fight.
- The protagonist encounters or shelters with survivors; the supermarket is an important early refuge in the prior outline.
- Survival systems begin to matter: light, food/water, health, inventory weight, locked routes, and scarce tools.

### Act II — Survivors and clues (WORKING DRAFT)

- Explore neighborhoods, businesses, civic locations, and dangerous routes.
- Find documents and personal evidence of previous Greyhaven incidents.
- Learn what drives Marcus's search for Noah; develop the perspectives of Eddie, Ruth, Sarah, Frank, and Lena.
- Different survivors react with fear, denial, practicality, curiosity, or overconfidence.
- Some losses are scripted; other outcomes can be influenced or prevented by the player.
- Allow occasional human humor and character warmth without undermining the horror.

### Act III — The town's history and the breach (WORKING DRAFT)

- Follow leads into increasingly dangerous or distorted parts of Greyhaven.
- Earlier planning references a major **breach around Day 7**. Treat the precise timing and conditions as provisional until confirmed in quest scripts.
- Supplies, sleep/time progression, survivor relationships, and choices may influence who survives and what information is accessible.
- Reveal more about the mist's recurrence, but retain meaningful ambiguity.

### Act IV — Confrontation and outcome (WORKING DRAFT)

- The player faces an irreversible decision or sequence of decisions regarding escape, survival, and the mystery beneath Greyhaven.
- Earlier draft ending labels: **Clearing**, **Escape**, **Beneath the Town**, and **Last One**.
- These are established *working ending names*, not finalized conditions or cinematic scripts.
- Endings should reflect the player's discoveries, actions, and survivor outcomes rather than arbitrary menu choices.

### Ending concepts — NOT yet locked

| Working ending | Narrative direction to develop | Status |
|---|---|---|
| **Clearing** | A path toward lifting or surviving the mist's hold on Greyhaven | WORKING DRAFT; exact cause and cost TBD |
| **Escape** | A route out of the affected town, potentially at a human cost | WORKING DRAFT; conditions TBD |
| **Beneath the Town** | Pursuing the deeper mystery rather than only fleeing | WORKING DRAFT; reveal TBD |
| **Last One** | A bleak survival outcome shaped by losses and isolation | WORKING DRAFT; trigger TBD |

Do not implement specific ending triggers or declare a canonical ending without a confirmed narrative design.

---

## 4. Character bible

> **UPDATE 2026-11-04 - character looks:** the "Proposed appearance" lines below were design proposals. These models
> now exist in `THE_VEIL_ASSETS_V2/06_Characters/`:
>
> * **Eddie:** the owner's **hand-made model** (`CHR_Eddie`). It is the art-direction reference for all characters.
> * **Marcus:** rev 4, **owner-approved**.
> * **Protagonist** (with first-person arms), **Ruth, Sarah, Frank and Lena:** built in the same style (style rev 4).
>   Not individually approved.
> * **`CHR_Police_Officer`:** an **Officer Hayes candidate** only. Hayes' identity stays TBD.
>
> **Shared systems:** all models share one humanoid rig and the VeilFace texture-swap facial system (expressions,
> blinking, talking). No body animations exist yet.
>
> **Not modelled:** Noah and the secondary cast. Details are in `THE_VEIL_ASSETS_V2/Documentation/CHARACTER_ROSTER.md`.

**Important identity rule: Eddie and Marcus are separate people.** Eddie works at the game shop; Marcus is Noah's father. Do not merge them.

Descriptions below distinguish narrative facts from suggested looks. Character models should be stylized and consistent with Greyhaven, never photorealistic.

### 4.1 Protagonist — player character

- **Role:** Ordinary adult male, lives alone in Greyhaven; player-controlled survivor. **ESTABLISHED**
- **Approximate age:** Early-to-mid 30s in prior character planning; exact age TBD.
- **Personality direction:** Quiet, independent, somewhat withdrawn, not a trained action hero. **WORKING DRAFT**
- **Opening:** Wakes Friday at 6:42 PM; needs groceries; drives older sedan; also plans to buy a horror game. **ESTABLISHED**
- **Proposed appearance:** Short dark hair, muted gray jacket, shirt, dark jeans, ordinary shoes; about 1.78 m tall. **DESIGN PROPOSAL**
- **3D needs:** Full-body model for shadow/other scenes; separate first-person arms/hands for holding objects; appropriate humanoid rig; no assumption of military gear.
- **Name, detailed history, face, and exact clothing:** **TBD**.

### 4.2 Eddie — game-shop clerk

- **Age:** 34 in prior story planning. **WORKING DRAFT**
- **Role:** Clerk at Greyhaven's independent video game shop. **ESTABLISHED**
- **Personality:** Sarcastic, witty, loyal, dependable when matters become serious. **WORKING DRAFT**
- **Narrative function:** Familiar, human connection during the ordinary Friday trip and early disaster; occasional humor amid tension.
- **Proposed appearance:** Messy hair, casual graphic shirt or worn hoodie, jeans/sneakers, expressive face, relaxed/slouched posture. **DESIGN PROPOSAL**
- **Do not confuse with Marcus.**

### 4.3 Marcus — Noah's father

- **Age:** 43 in prior story planning. **WORKING DRAFT**
- **Role:** Father desperately searching for his missing son, Noah. **ESTABLISHED**
- **Personality:** Protective, impulsive, emotionally intense, determined. **WORKING DRAFT**
- **Narrative function:** Makes the catastrophe personal; urgency can drive risky decisions and survivor conflict.
- **Proposed appearance:** Stronger/heavier silhouette than Eddie; short/unkempt hair, weathered jacket, work pants/jeans, practical shoes, exhausted/worried face. **DESIGN PROPOSAL**
- **Exact sequence of Noah's disappearance and resolution:** **TBD**.

### 4.4 Noah — Marcus's son

- **Role/relationship:** Marcus's missing child. **ESTABLISHED**
- **Exact age, appearance, location, fate, and whether he is encountered in person:** **TBD**.
- **3D instruction:** Do not guess his age or produce a definitive model until the story establishes it.
- **UPDATE 2026-11-04:** at the owner's request, a **design-proposal** model `CHR_Noah` exists (built as roughly 10-12).
  It is not canon and not placed in the game. Age, look and fate stay TBD.

### 4.5 Ruth — retired librarian

- **Age:** 68 in prior planning. **WORKING DRAFT**
- **Role:** Longtime resident and retired librarian with knowledge of Greyhaven's history. **WORKING DRAFT**
- **Personality:** Quiet, observant, secretive, knowledgeable.
- **Narrative function:** Helps connect contemporary events to historical disappearances and recurring phenomena.
- **Proposed appearance:** Elderly woman, slightly stooped, gray/white hair, modest cardigan/coat, sensible shoes, calm watchful expression. **DESIGN PROPOSAL**
- **What she knows and when she reveals it:** **TBD**.

### 4.6 Sarah — paramedic

- **Role:** Emergency medical worker. **WORKING DRAFT**
- **Personality:** Practical, skeptical, capable, grounded.
- **Narrative function:** Medical realism, emergency response, and a rational counterpoint to supernatural interpretations.
- **Proposed appearance:** Tied-back hair, emergency-service uniform, utility trousers, radio/medical accessories, sturdy boots. **DESIGN PROPOSAL**
- **Age and exact plot outcome:** **TBD**.

### 4.7 Frank — security guard

- **Role:** Security guard. **WORKING DRAFT**
- **Personality:** Serious, overconfident, expects training and authority to control events.
- **Narrative function:** Illustrates the limits of ordinary authority in the face of the Veil.
- **Proposed appearance:** Middle-aged, stocky, security uniform, radio, belt, stern expression. Not a tactical commando. **DESIGN PROPOSAL**
- **Age and exact plot outcome:** **TBD**.

### 4.8 Lena — student investigator

- **Role:** Student investigating Greyhaven disappearances. **WORKING DRAFT**
- **Personality:** Curious, determined, analytical.
- **Narrative function:** Provides research, clues, questions, and potential investigative quests.
- **Proposed appearance:** Young adult, layered casual clothing, backpack/messenger bag, notebook, alert expression. **DESIGN PROPOSAL**
- **Age and exact findings:** **TBD**.

### 4.9 Secondary named cast

The following names appeared in earlier story planning but have **insufficient confirmed biographies** in the available context:

| Character | Known/possible role | Status |
|---|---|---|
| Danny | Named supporting character; precise role TBD | TBD |
| Walter | Named supporting character; precise role TBD | TBD |
| Kevin | Named supporting character; precise role TBD | TBD |
| Mr. Bell | Named supporting character; precise role TBD | TBD |
| Officer Hayes | Police officer; prioritize over an anonymous generic officer if the story requires a named police character | WORKING DRAFT / details TBD |

**Do not invent their ages, relationships, deaths, or plot functions without reviewing the story files.**

### 4.10 Character relationships — minimal verified graph

- **Marcus → Noah:** Father and son; Marcus is searching for Noah.
- **Eddie → video game shop:** Clerk; connected to the protagonist's planned Friday purchase.
- **Protagonist → Greyhaven:** Lives alone in town; ordinary resident at the start.
- **Ruth → Greyhaven history:** Retired librarian and possible source of records.
- **Sarah → emergency response:** Paramedic.
- **Frank → local security:** Security guard.
- **Lena → disappearances:** Student investigator.
- **Other relationships:** TBD. Do not infer friendships, romances, family ties, betrayals, or deaths.

### 4.11 Deaths and survival consequences

Earlier direction explicitly requested a **mixture of scripted and preventable character deaths**. Which named characters die, when, and under what conditions is **TBD**. Implement this as a story-design principle, not as permission to randomly kill or save characters.

---

## 5. Threats and supernatural creatures

The earlier draft identified these threat types:

| Threat | Known function | Canon status |
|---|---|---|
| **Wanderer** | Human-scale supernatural threat archetype | WORKING DRAFT; appearance/behavior TBD |
| **Hound** | Fast animal-like threat archetype | WORKING DRAFT; appearance/behavior TBD |
| **Colossus** | Enormous, frightening presence associated with the mist's arrival | WORKING DRAFT; appearance/behavior TBD |

> **UPDATE 2026-11-04 - Pack 07 roster (owner's brief):** the **Wanderer is removed**, and no humanoid enemies are
> planned.
>
> The built roster is:
>
> * **Colossus** (four-legged tentacled giant);
> * **Mist Tentacles** in three sizes (thin / medium / large);
> * **Hound**;
> * **Skitter** (six-legged insectoid);
> * **Shellcrawler** (asymmetric shelled crawler).
>
> The models and animation clips exist in `THE_VEIL_ASSETS_V2/07_Creatures/`. Behaviour, encounter rules and
> whether the Colossus can be fought remain TBD (section 11.9).

**Threat design principles:** Distinct silhouettes and audio cues; avoid treating every creature as a simple damage sponge; use uncertainty, concealment, and limited player resources. Do not add a fully explained taxonomy or supernatural origin without approval.

---

## 6. Greyhaven — places and narrative functions

These are intended story locations. **Always inspect actual Pack 02 town-layout files and placement markers before assigning coordinates or changing roads.**

| Location | Narrative/gameplay purpose | Status |
|---|---|---|
| **Player's house** | Opening at 6:42 PM; first interactions; car keys; departure | ESTABLISHED |
| **Residential streets** | Normal-life opening; later exploration and environmental storytelling | ESTABLISHED |
| **Supermarket** | Grocery objective; significant early shelter in previous draft | ESTABLISHED / WORKING DRAFT |
| **Independent video game shop** | Planned horror-game purchase; Eddie; Marcus in earlier arrival sequence | ESTABLISHED / WORKING DRAFT |
| **Gas station** | Commercial landmark, supplies, vehicle-related exploration | DESIGN PLAN |
| **Pharmacy** | Medical supplies, Sarah-related potential; not a confirmed quest location | DESIGN PLAN |
| **Municipal archive / historical records** | Historical research and clues; potential Ruth/Lena connections | DESIGN PLAN |
| **Police / civic areas** | Officer Hayes and public-response potential | TBD |
| **Farmhouse / mill house** | Existing planned town-building zones; specific story use TBD | DESIGN PLAN |
| **Underground / beneath Greyhaven** | Potential deep-mystery area associated with an ending name | WORKING DRAFT; specifics TBD |

> **UPDATE 2026-11-04 - town extension (owner's Phase 1 brief: the opening drive must last at least 60 s):**
>
> * Greyhaven was extended in the game build. Route 9 continues as a county road to a new subdivision: Harlow Ln,
>   Aspen Ct and Fern Ct.
> * The **player's house moved to Fern Ct**, with the same lot geometry. A Ranch B house fills the old Maple Ave lot.
> * Pack 02 itself is unchanged. The extension lives in `game/world/` (`game/tools/build_world.py`).
> * The route is about 1,069 m, about 83 s at 50 km/h.
> * Coordinates are in `THE_VEIL_ASSETS_V2/Documentation/WORLD_LOCATIONS.md`.

### Spatial continuity rules

- Preserve established Greyhaven road and sidewalk network from Pack 02.
- Place residential and commercial buildings using actual map zones/markers; do not invent replacement coordinates.
- Ensure entrances, driveways, and walkable routes are physically reachable.
- Early locations should look ordinary **before** the mist and change through later lighting, audio, set dressing, and scripted events.

---

## 7. Gameplay systems and narrative interaction

### Established mechanics / requirements

- First-person walking, looking, and contextual interaction.
- Doors, household appliances, pickups, and inspectable objects.
- Inventory with approximately **15 kg starting carrying capacity** in earlier design.
- Food, water, keys, tools, weapons, and medical supplies.
- Flashlight and limited visibility.
- Journal, notes, documents, and discovered clues.
- Vehicle entry and driving, including the opening sedan.
- Limited combat rather than constant action-heavy shooting.
- Sleep/rest and passage of days as part of the broader survival loop (working draft).
- Windows controls and an eventual Android-compatible control scheme.

### Systems requiring further design

- Exact hunger/thirst depletion, health and healing values.
- Exact inventory slots, stacking, weight formula, and equipment handling.
- Enemy AI states, detection ranges, combat damage, and encounter pacing.
- Fuel consumption, vehicle damage, road closures, and travel restrictions.
- Time-of-day speed, sleep rules, and how a Day 7 breach is triggered.
- Save/load and checkpoint behavior.
- Dialogue choices, trust, survivor availability, and preventable death conditions.
- Puzzle structure and ending-condition flags.

**Implementation instruction:** Keep values configurable; do not present placeholder numbers as final balance decisions.

---

## 8. Narrative tone, pacing, and content guardrails

- Opening: mundane, familiar, lightly characterful; no premature monster reveal.
- First mist event: disorienting and frightening, with uncertainty about its scale and nature.
- Middle: survival pressure, interpersonal conflict, meaningful exploration, and evidence gathering.
- Late game: escalating dread and hard choices; mystery may deepen instead of being fully solved.
- Humor: occasional, character-driven (especially Eddie); never constant quipping during danger.
- Easter eggs: original, subtle nods to horror-game culture; no copied assets or recognizable protected characters.
- Human stakes: mixed scripted and avoidable losses; avoid arbitrary punishment and untelegraphed irreversible outcomes.
- The mist's origin must remain ancient/unexplained unless the user explicitly changes that direction.

---

## 9. Art and technical production pipeline

**Repository:** `jafetmora79-lab/TheVeil`  
**Previously used working branch:** `claude/practical-cray-hi2y54` (verify current branch before writing)  
**Asset root:** `THE_VEIL_ASSETS_V2/`  
**Online gallery:** `docs/index.html` with `docs/.nojekyll`; intended Pages URL `https://jafetmora79-lab.github.io/TheVeil/` (availability/configuration must be verified).

### Pack roadmap

| Pack | Scope |
|---|---|
| **01** | Pixel-art textures and Godot materials |
| **02** | Greyhaven town, roads, sidewalks, street props, vegetation, utilities, fences, layout |
| **03** | Residential houses, explorable interiors, furniture, player's home |
| **04** | Commercial buildings, supermarket, video game shop, other stores |
| **05** | Vehicles and vehicle interiors |
| **06** | Human characters and NPCs |
| **07** | Supernatural creatures and enemies |
| **08** | Weapons, tools, pickups, inventory objects |
| **09** | Horror environments, effects, and polish |

> **UPDATE 2026-11-04 - pack status:**
>
> * **Packs 01-09 all exist and pass their validators** (see `THE_VEIL_ASSETS_V2/Documentation/ASSET_STATUS.md`).
> * The **character style reference is the owner's hand-made Eddie**. Earlier generated character revisions are kept
>   only as `_v1` to `_v3` backups.
> * A playable Godot project lives at the repository root (`game/`). It has two phases:
>   * Phase 1: the opening;
>   * Phase 2: the town errands.
> * The notes below about "planned" packs and missing characters are historical.

**Note:** Earlier conversations describe these packs as created or planned in different stages. **Check the repository to verify actual contents, quality, rigging, and import success.** Do not assume the full character cast exists. Older realistic character models may exist only on the user's home computer and are not automatically suitable for this stylized pipeline.

### Asset conventions

- Godot 4 compatible, with attention to the Compatibility renderer.
- Individual reusable `.glb` assets; retain editable sources/generation scripts where possible.
- Proper UVs, pixel-art texture maps, normals, origins, and material references.
- Use nearest-neighbor filtering for deliberately pixelated textures.
- Use simple collision and sensible poly budgets; avoid unnecessary materials and draw calls.
- Characters should use shared humanoid rig conventions where practical; model existence does not imply a working rig or animations.
- Browser GLB preview and Godot import are **not the same**. Godot `.tres` material remaps do not automatically appear in a browser viewer; browser previews may require embedded textures or separate preview GLBs.
- Avoid overwriting game-ready GLBs merely to improve web previews.

### Known Pack 02 validation context (from earlier repository review)

An earlier Pack 02 validation report claimed 157 GLBs validated, 23 PNG textures, 31 materials, and successful road/ground checks. Those are **report claims, not independent visual verification**. Recheck the files and import results before depending on them.

### Character pack priority

1. Protagonist (including first-person hands/arms).
2. Eddie.
3. Marcus.
4. Ruth.
5. Sarah.
6. Frank.
7. Lena.
8. Noah **only after confirming age and appearance**.
9. Secondary named characters after confirming their story roles.

**Character visual rule:** No photorealism or semi-realistic humans. Models must match Greyhaven's quirky low-poly/pixel-textured style. Do not waste generation budget on anonymous NPCs when named story characters are needed.

---

## 10. Suggested project documentation layout

Recommended repository files (create only if they do not conflict with existing documentation):

```text
THE_VEIL_ASSETS_V2/
  Documentation/
    THE_VEIL_MASTER_CONTEXT.md        # This file
    STORY_CANON_DECISIONS.md          # Explicit user-approved decisions and dates
    STORY_ACTS_AND_QUESTS.md          # Beat-by-beat quests, triggers, dialogue references
    CHARACTER_ROSTER.md               # Models, identities, rigs, relationships, fates
    WORLD_LOCATIONS.md                # Scene paths, zones, coordinates, story use
    ASSET_STATUS.md                   # Real repo inventory and validation results
```

If the repository already has a story/docs convention, use it instead of creating duplicate documentation trees. Add a short pointer to this document from the root README so Claude can find it.

> **UPDATE 2026-11-04:** the five files above now exist in `THE_VEIL_ASSETS_V2/Documentation/`. This bible stays at
> `docs/THE_VEIL_MASTER_CONTEXT.md`, which the root `README.md` points to. `docs/HANDOFF.md` is the production
> handoff.

---

## 11. Open decisions — do not silently invent

1. Protagonist's name, definitive face, clothing, and backstory.
2. Precise playable order of supermarket vs. video game shop and exact moment of mist arrival.
3. Exact biographies and appearances of Danny, Walter, Kevin, Mr. Bell, and Officer Hayes.
4. Noah's age, physical design, location, and fate.
5. Which character deaths are scripted vs. preventable and what causes them.
6. Exact lore behind recurring mist events and what evidence the player can discover.
7. Meaning, triggers, and consequences of the four working endings.
8. Specific Day 7 breach trigger and whether it can be delayed/prevented.
9. Final monster designs, encounter rules, and whether the Colossus can be fought.
10. Final map coordinates, building interiors, dialogue, quest flags, save/load, and balance values.
11. Whether any earlier realistic character source files from the home PC are worth retaining as references.

---

## 12. Recommended next instruction to Claude

> Read `THE_VEIL_MASTER_CONTEXT.md` in full. Then inspect the actual repository's story files, asset manifests, and relevant scenes. Produce a short discrepancy report distinguishing confirmed canon, working draft, and missing implementation. For Pack 06, use the named story roster instead of generic civilians. Preserve the established quirky low-poly pixel-textured aesthetic. Do not overwrite other packs, invent missing lore, or generate screenshots, renders, or videos. Implement only the specific pack/task requested after reconciling the references.

---

**Maintainer note:** This is a handoff document, not a claim that every plot beat, asset, or feature is already implemented. Update the status tags as narrative decisions are explicitly approved.
