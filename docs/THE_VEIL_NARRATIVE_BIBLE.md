# THE VEIL — MASTER NARRATIVE & DEVELOPMENT CONTEXT
## Version 3.1 — Approved Story Foundation

**Project:** THE VEIL  
**Engine:** Godot 4  
**Repository:** `jafetmora79-lab/TheVeil`  
**Primary development branch:** `claude/practical-cray-hi2y54`  
**Genre:** First-person psychological survival horror  
**Visual direction:** Stylized, low-poly, pixel-textured, early-2000s/PSX-inspired horror.

---

# 1. PURPOSE OF THIS DOCUMENT

This document defines the approved narrative direction, gameplay philosophy, and development rules for THE VEIL.

All developers working on the project must follow it.

The game is being developed incrementally using Claude, Codex, and ChatGPT.

**IMPORTANT: ChatGPT is responsible for writing and approving the narrative content. Claude and Codex are responsible for implementation.**

Do not invent additional story events, characters, dialogue, endings, supernatural explanations, or major gameplay mechanics.

If something is missing, report it as an unresolved requirement rather than inventing a solution.

Chapter-specific implementation prompts will provide the exact dialogue, scene directions, objectives, interactions, and branching conditions.

This document establishes the overall direction but does not authorize implementation of future chapters by itself.

---

# 2. EXISTING PROJECT — PRESERVE ALL WORK

Before modifying the project, inspect:

- `docs/THE_VEIL_MASTER_CONTEXT.md`
- `docs/HANDOFF.md`
- `game/README.md`
- `THE_VEIL_ASSETS_V2/Documentation/STORY_CANON_DECISIONS.md`
- `THE_VEIL_ASSETS_V2/Documentation/STORY_ACTS_AND_QUESTS.md`
- Existing Godot scenes, scripts, assets, save systems, and dialogue systems.

Preserve existing functionality.

Do not recreate working systems.

Do not delete or replace existing 3D models without explicit authorization.

Do not generate screenshots, renders, or preview videos unless specifically requested.

Do not automatically merge branches.

Each implementation task must use the branch specified in its individual prompt.

When an existing document conflicts with this master context, identify the conflict and report it. Do not silently overwrite historical canon or existing implementation.

---

# 3. CORE STORY PREMISE

THE VEIL follows an ordinary person living alone in the town of Greyhaven.

On a Friday evening, the protagonist wakes at 6:42 PM.

The refrigerator is empty.

They collect their car keys and leave home to buy groceries and a horror video game.

Both errands can be completed in either order.

During the evening, a mysterious mist suddenly engulfs Greyhaven.

The protagonist witnesses an enormous four-legged creature, known in development as the Colossus, moving through the fog.

The creature's upper body is obscured.

Its feet strike the ground with immense force.

The protagonist encounters Eddie, a video game store clerk, and Marcus, a father searching for his missing son Noah.

The three take refuge in the supermarket.

As the story progresses, the survivors explore Greyhaven, encounter other people, search for supplies, and attempt to discover whether escape is possible.

The emotional center of the game is Marcus's search for Noah.

The supernatural mystery is never fully explained.

---

# 4. THE VEIL — ABSOLUTE NARRATIVE RULES

The Veil is ancient, mysterious, and unexplained.

Its origin must never be definitively revealed.

Do not establish that it is:

- A government experiment.
- A laboratory accident.
- A dream.
- A simulation.
- A conventional alien invasion.
- A curse with a confirmed source.
- A supernatural phenomenon that can be permanently defeated by destroying one object or creature.

Characters may propose theories.

The game must not confirm those theories.

The Veil can produce unexplained phenomena, including:

- Unreliable radio transmissions.
- Familiar voices heard from empty places.
- Conflicting timestamps.
- Strange sounds.
- Roads that appear to lead somewhere unexpected.
- Creatures emerging from the fog.

These phenomena must remain ambiguous.

Avoid overusing supernatural events.

Ordinary silence and environmental tension are essential to the horror.

---

# 5. GAMEPLAY PHILOSOPHY

THE VEIL is survival horror, not an action shooter.

Core gameplay:

1. Explore.
2. Scavenge.
3. Avoid danger.
4. Manage supplies.
5. Return to shelter.
6. Sleep.
7. Advance the story when the appropriate milestones are complete.

Combat is extremely limited.

Ammunition is scarce.

Weapons may temporarily stop or discourage certain smaller enemies.

Most encounters are better survived through hiding, evasion, or environmental distractions.

The Colossus cannot be killed or fought.

Avoid conventional boss battles.

---

# 6. STORY PROGRESSION

The game has five acts and approximately fourteen main chapters.

There is no fixed number of in-game days.

Sleep advances time.

Major story events advance when their required milestones are complete.

Players may spend additional nights exploring, collecting supplies, or preparing.

Do not automatically advance the main story merely because the player slept.

Do not punish additional exploration with arbitrary character deaths or unavoidable narrative failure.

Story progression must persist across save/load.

---

# 7. MAIN CHARACTERS

## Protagonist

An ordinary person who initially prefers being alone.

Begins as a reluctant survivor.

Gradually becomes responsible for others.

Personality is shaped through dialogue choices and actions.

Do not invent a fixed name or detailed personal history without approval.

## Eddie

The video game store clerk.

Nervous, observant, practical, and occasionally funny.

Uses humor to manage fear.

Over time, becomes more courageous and dependable.

His survival can depend on player decisions.

Avoid making him a constant comedy character.

## Marcus

A father searching for his missing son, Noah.

Desperate, emotional, and sometimes reckless.

His decisions can create conflict with Eddie.

His trust in the protagonist depends on actions and dialogue.

**Marcus may die before Noah is rescued.**

His survival must not be guaranteed.

If he survives, he can reunite with Noah.

## Noah

Marcus's son.

Approximately 13 years old, within the approved 12–14 age range.

Intelligent, frightened, and resourceful.

He survived by hiding and following instructions from an adult who helped him.

Noah is alive.

He is rescued near the final act.

Noah must not be portrayed as a fearless fighter or helpless escort character.

His rescue is a required story milestone.

## Supporting survivors

Proposed recurring characters:

- Ruth — practical survival knowledge.
- Sarah — medical knowledge.
- Frank — suspicious and self-preserving.
- Lena — familiar with Greyhaven's outskirts.

These names and roles are provisional until checked against existing character canon.

Do not create new character models or implement these characters without a chapter-specific prompt and approval.

---

# 8. NOAH AND THE FARMHOUSE

Noah survives the Veil's arrival.

He travels toward the countryside.

An older farmhouse owner discovers him and helps him reach a rural farmhouse outside Greyhaven.

The owner provides shelter, food, and instructions for staying safe.

Later, the owner disappears after leaving the property.

The owner's fate remains unknown.

Do not reveal whether the owner died, escaped, or was taken by the Veil.

Throughout the game, the protagonist discovers evidence of Noah's movements.

Clues include:

1. Noah's backpack.
2. A handwritten message.
3. A survivor's account.
4. Evidence of the farmhouse owner's assistance.
5. The location of the farmhouse.

Noah is eventually found alive inside the farmhouse.

The protagonist rescues him.

If Marcus is alive, they reunite.

If Marcus died, Noah learns the truth and the rescue becomes bittersweet.

Do not turn Noah into a supernatural illusion or false rescue.

---

# 9. CHAPTER STRUCTURE

## ACT I — THE ARRIVAL

Chapter numbering (corrected; the game displays these numbers, from the central mapping in
`game/data/chapters.json`). The original "Ordinary Friday" chapter is now two chapters: An Ordinary Evening (Chapter 1) and
One Last Stop (Chapter 2). Every later chapter moved up by one. Internal ids in the code (flags, objective ids, file names
such as `chapter5.gd`) keep their old numbers.

### Chapter 1 — An Ordinary Evening

Wake up at home at 6:42 PM, explore the house, the empty refrigerator, the car keys, leave home and start the drive into town.

### Chapter 2 — One Last Stop

Arrive in town (the cinematic zoom toward the stores), the supermarket and the video game store.

### Chapter 3 — The Veil Arrives

The mist descends, the Colossus appears, and Greyhaven becomes dangerous.

### Chapter 4 — The Last Open Door

The protagonist, Eddie, and Marcus escape the video game shop area and run together toward the supermarket.

They physically enter the supermarket.

They do not teleport or appear there without explanation.

### Chapter 5 — Lock-In

Restore emergency lighting, secure entrances, find supplies, experience the first night, and sleep.

Existing implementations of Chapters 1–5 must be preserved and repaired rather than rebuilt.

## ACT II — THE MISSING

### Chapter 6 — The First Search

First major scavenging expedition.

Learn stealth, supply collection, and returning to shelter.

### Chapter 7 — Voices in the Mist

Encounter other survivors.

Experience unreliable voices and the first significant pursuit threat.

### Chapter 8 — A Trace of Noah

Recover Noah's backpack.

Discover evidence that he survived and traveled toward the outskirts.

## ACT III — NO PLACE IS SAFE

### Chapter 9 — Something at the Doors

Supermarket defenses deteriorate.

A temporary survivor dies in a scripted attack.

Other casualties may be preventable.

### Chapter 10 — The Fall of the Supermarket

The shelter is compromised.

The group evacuates.

Marcus may survive or die depending on player decisions.

### Chapter 11 — No Safe Road (formerly "The Other Shelter")

The group leaves Greyhaven on foot after losing the supermarket. Along the way:

- an abandoned car;
- a roadblock and a side route;
- something following them;
- a hard choice over an exhausted or hurt survivor.

They reach a temporary refuge, an old mill-worker house on the outskirts. It is not a permanent shelter.

Still open for later chapters: maps, radio clues and the exact route toward the farms.

## ACT IV — THE FARMHOUSE

### Chapter 12 — The Road Beyond Town

Explore countryside roads.

Avoid creatures.

Discover evidence that Noah reached a farmhouse.

### Chapter 13 — The Farmhouse

Locate Noah.

Discover the farmhouse owner's journal.

Rescue Noah through a stealth-focused sequence.

Return to shelter.

If Marcus is alive, reunite father and son.

If Marcus is dead, acknowledge the loss in a separate scene.

## ACT V — THE LAST CROSSING

### Chapter 14 — The Last Signal

Investigate a possible escape route.

Combine radio clues, physical exploration, and survivor knowledge.

### Chapter 15 — The Last Crossing

The survivors make their final decision.

Possible outcomes:

- Escape.
- Remain sheltered.
- Protagonist sacrifices their own safety to help others.

The Veil remains unexplained.

---

# 10. CHAPTER 4 (formerly 3) — APPROVED ESCAPE SEQUENCE CHANGE

IMPORTANT NEW REQUIREMENT:

Eddie and Marcus must physically accompany the protagonist during the escape from the video game shop to the supermarket.

They must not suddenly appear inside the supermarket.

The sequence must be continuous and believable.

Required narrative flow:

1. The Colossus cinematic ends.
2. Eddie calls the protagonist back inside the game shop.
3. Eddie, Marcus, and the protagonist physically regroup inside.
4. The group discusses the need for better shelter.
5. The supermarket is selected as the destination.
6. Eddie and Marcus prepare to leave.
7. The protagonist opens or approaches the shop exit.
8. Eddie and Marcus follow the protagonist outside.
9. All three run across Main Street toward the supermarket.
10. Eddie and Marcus remain visibly present during the crossing.
11. The group enters the supermarket through a believable entrance.
12. Eddie and Marcus move to appropriate interior positions.
13. The player secures the entrance.
14. The existing Chapter 5 (Lock-In) handoff continues.

Implementation requirements:

- Reuse existing Eddie and Marcus character models.
- Reuse existing movement and navigation systems.
- Use believable running animations.
- Keep companions within a reasonable distance.
- Do not teleport characters into view.
- Prevent companions from clipping through walls or vehicles.
- Avoid blocking the player's path.
- Preserve collision.
- Preserve existing fog and lighting.
- Maintain the player's first-person perspective.
- Avoid camera clipping.
- Keep objective text synchronized with story progression.
- Save and restore the correct chapter state.

This document approves the narrative change only.

The actual implementation must wait for the dedicated Chapter 4 (formerly Chapter 3) prompt, which will include dialogue, timing, navigation behavior, camera instructions, and acceptance tests.

---

# 11. CREATURES

## Colossus

Enormous four-legged creature with tentacles.

Its upper body remains hidden in the fog.

Feet should visibly contact the ground.

It cannot be defeated.

Used for major cinematic or environmental encounters.

## Hounds

Fast pursuit enemies.

Dangerous in close quarters.

Avoidance preferred.

## Insect-like creatures

Smaller ambush threats.

Used sparingly.

## Crab-like creatures

Slow but dangerous obstacles.

Can block routes.

## Mist tentacles

Environmental hazards.

Do not explain their biological origin.

Reuse existing approved creature models.

Do not invent additional monster species without approval.

---

# 12. CHARACTER DEATHS

The game uses a mixture of scripted and preventable deaths.

Scripted deaths establish danger and emotional stakes.

Preventable deaths depend on player preparation, decisions, and actions.

Major survivors must not die randomly without a visible cause.

Marcus may die during the supermarket evacuation.

Eddie may die in a later preventable event.

Supporting survivors may survive or die depending on specific conditions.

Noah remains alive and is rescued.

Do not create additional character deaths without approval.

---

# 13. ENDINGS

## Ending A — Beyond the Veil

The protagonist and surviving companions attempt to escape Greyhaven.

The player has rescued Noah and discovered the crossing route.

Survivor outcomes depend on previous decisions.

The survivors emerge into an apparently normal landscape.

The final scene leaves subtle doubt about whether the Veil is truly behind them.

## Ending B — The Ones Who Stayed

The protagonist rejects the uncertain crossing.

The surviving group remains in a fortified shelter.

Noah is alive.

Marcus may or may not be present.

The survivors prepare for an uncertain future.

## Ending C — Into the Mist

During the final crossing, the protagonist takes a dangerous action to protect the others.

The protagonist disappears into the fog.

Their fate is not confirmed.

The Veil's nature remains unknown.

No ending may reveal the origin of the Veil.

---

# 14. ART DIRECTION

THE VEIL must retain its established visual identity.

- Stylized low-poly 3D.
- PSX-inspired textures.
- Pixelated appearance.
- Unsettling character proportions.
- Dark, atmospheric lighting.
- Dense, convincing fog.
- Limited visibility.
- Restrained cinematic effects.

Avoid photorealistic assets.

Avoid high-fidelity modern horror aesthetics.

Do not replace approved characters or monsters with more realistic models.

Preserve texture filtering and existing material conventions.

---

# 15. ASSET REUSE

The project already contains numerous environment, character, monster, vehicle, furniture, and prop assets.

Before creating any new asset:

1. Search the existing asset library.
2. Check whether an existing asset can be reused.
3. Inspect whether it imports correctly into Godot.
4. Verify materials, scale, collision, and animation readiness.
5. Report genuinely missing assets.

Do not generate replacement models automatically.

Do not create new characters, buildings, or monsters without explicit authorization.

A missing animation does not automatically justify replacing a model.

---

# 16. DEVELOPMENT RESPONSIBILITIES

## ChatGPT — Narrative Design

Responsible for:

- Approved story events.
- Dialogue scripts.
- Character arcs.
- Chapter objectives.
- Cinematic directions.
- Branching decisions.
- Ending conditions.
- Complete chapter implementation prompts.

## Claude — Implementation

Responsible for:

- Godot scenes and scripts.
- Character movement.
- Animation integration.
- AI.
- Interactions.
- Dialogue implementation.
- Camera systems.
- Quest progression.
- Gameplay integration.

Claude must not independently invent missing narrative material.

## Codex — Technical Validation

Responsible for:

- Automated tests.
- Save/load verification.
- Scene validation.
- Export compatibility.
- Integration checks.
- Regression prevention.

Developers must coordinate through separate branches.

---

# 17. CHAPTER IMPLEMENTATION CONTRACT

Each future chapter prompt will provide:

1. Exact starting state.
2. Required existing scenes and assets.
3. Scene-by-scene story sequence.
4. Exact dialogue.
5. Character positions and movement.
6. Player objectives.
7. Interaction triggers.
8. Cinematic and camera directions.
9. Enemy encounters.
10. Branching decisions.
11. Save/load requirements.
12. Ending state.
13. Acceptance tests.
14. Explicit exclusions.

Claude must implement the supplied content rather than invent replacements.

If an asset or required system is missing, Claude should report it and implement only the portions that can be completed safely.

Do not invent dialogue to fill gaps.

Do not invent optional quests.

Do not invent new story scenes.

Do not introduce unapproved characters.

Do not alter ending conditions.

---

# 18. TECHNICAL QUALITY REQUIREMENTS

Every implementation must preserve:

- Existing gameplay systems.
- Player movement.
- Collision.
- Inventory.
- Health and stamina.
- Flashlight and batteries.
- Dialogue interactions.
- Objective HUD.
- Save/load.
- Android controls where applicable.
- Windows compatibility.
- Web compatibility where feasible.

Avoid duplicate managers or competing systems.

Do not introduce unnecessary dependencies.

Do not rewrite functioning scenes when a targeted fix is sufficient.

Tests should cover progression, state persistence, interaction completion, and major failure cases.

Never claim a feature is fully tested if it was not actually executed.

---

# 19. CREDIT EFFICIENCY RULES

Claude credits are limited.

Prioritize implementation over exploration or unnecessary output.

Do not:

- Generate screenshots unless requested.
- Produce renders or videos.
- Repeatedly summarize the story.
- Rewrite dialogue.
- Invent missing quests.
- Generate unused models.
- Create duplicate systems.
- Perform unrelated refactoring.
- Rebuild approved environments.
- Produce extensive design documents when a concise implementation report is enough.

Use the existing assets and systems wherever possible.

If a requirement is unclear, identify the blocker instead of spending credits experimenting with an invented solution.

At the end of each task, provide a concise report:

- What changed.
- Files changed.
- Tests performed.
- What remains blocked.
- Commit hash.

---

# 20. FINAL PROJECT VISION

THE VEIL is a grounded psychological survival-horror experience about ordinary people trapped in an impossible situation.

The player must survive, search for supplies, protect companions, rescue Noah, and decide whether escape is worth the risk.

The story should be frightening, emotionally meaningful, occasionally human and humorous, and never fully explain the supernatural.

The player's choices determine who survives.

The Veil remains.

**END OF MASTER CONTEXT v3.1**
