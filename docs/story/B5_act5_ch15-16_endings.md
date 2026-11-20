# B5. Act V - The Last Crossing (displayed chapters 15-16) and the three endings

Internal: displayed 15 = `chapter14.gd` / `c14_*` / `ch14_*`; displayed 16 = `chapter15.gd` / `c15_*` / `ch15_*`. CURRENT lines: `appendix/current_dialogue_15*.md`, `_16*.md`. Conventions as in B1; `_alt` with `@1` covers any missing named speaker; companion variants follow `c13_setout_Sarah/_Ruth/_Marcus`.

**Act V intent:** the shelter falls for the same reasons the player has seen all game (fog, resources, injuries, exits) and each preparation *visibly* pays; the group reaches the station refuge; the finale is a decision with **telegraphed costs**, three different endings with real costs for Noah and the group, and no explanation of the Veil.

---

## Chapter 15 - The Last Shelter  *(chapter14.gd)*

### 15.01 The vibration and the window  *(CURRENT + REVISED wake line)*
- **Entry:** `chapter_13_complete` -> `ch14_started`. Bed height (`BED (1.4, 0.61, 6)`), a deep vibration, the window silhouette (`_window_scene`).
- **REVISED wake line (Noah rescued, `c14_wake_noah`):** NOAH *(shaking the protagonist's shoulder)*: "You need to see this. Look at my line." *(He points at the pencil tally on the window frame: the fog line has jumped past the road.)* CURRENT `c14_wake` (RUTH: "You need to see this.") plays when Noah is not in the saved world (old saves).
- `c14_window` (EDDIE: "It wasn't this close yesterday." / RUTH: "Something's changed." / "It's coming this way."). **Scare setup:** a vast shape moves between far buildings (CURRENT; the tripod Colossus in its fog band).

### 15.02 The meeting and the three preparations  *(CURRENT; the player can SEE what each does)*
- Meeting (`c14_meeting`, `_meeting_end`: "Supplies. The doors. A way out the back."): **every living survivor in the room**, now including Noah, who contributes the **watch log** (`c14_noah_log` NEW: NOAH: "Fog line, hour by hour. It doesn't come on Mondays." EDDIE: "It's Friday." NOAH: "Then it's coming.") - Eddie's stress humor, Noah's dry literalness.
- **Three preparations, any order** (CURRENT): **supplies** (`_check_supplies`; treat the injured with painkillers; pack provisions; if short, an emergency run - faster danger, a Hound from the fog; `c14_pack_enough` / `c14_pack_short`), **reinforce the entrances** (front door `c14_defend_front` "The cabinet's against the front door. It won't stop them. It'll slow them.", front window `c14_defend_window` "Boards over the window. Nailed twice.", back door `c14_defend_back` "wedged - from inside, so we can still get out"; each recorded in `st().defenses`), **prepare the escape route** (the back way; the car only if it is really here - `c14_no_car`: EDDIE: "And the car's still back at the supermarket. So - walking. Great.").
- **Payoff readability (REVISED, props/feedback, no new story):** each reinforcement adds a **distinct visible state** the player sees *before* the siege - a nailed board count on the window, the cabinet's bolt-through marks, a rope handrail along the back route. During the siege `_brace_window` / barricade flex is **scaled to those states** (the braced window holds longer, the unbraced one is the one the Skitters pick - "Skitters at the window").
- **Noah's evacuation partner and location (NEW, `st().noah_partner`):** **Ruth** by default (she has the plan: "The ditch, then the fence line, then the field"); **Marcus** if alive and fit ("I'm not letting go of this one"); else **Sarah**. Meeting point: the **field edge at `SAFE (-102, 56)`**. Said once at the end of the meeting: RUTH: "Noah, with me. Back door, the ditch, the field edge. If I say run, you don't wait." NOAH: "I know the route. I drew it." *(he did: the log shows the route)* - **he is a capable partner, not a casualty branch: Noah cannot be 'caught' (see 15.05).**

### 15.03 The calm and optional talks  *(CURRENT)*
`c14_calm_Eddie` (EDDIE: "You know, I really thought buying a video game was going to be the worst decision I made that day." / "Still might be." / "Yeah. Fair point.") and per-survivor talks (Ruth, Sarah, Marcus) that **remember trust and earlier choices**. **NEW Noah talk (`c14_calm_Noah`, optional):** NOAH: "Dad says you promised him first light." *(Marcus alive)* / "He told me what you said. About the bag." *(lost)* PROTAGONIST: "I did." NOAH: "Okay. Then I'll trust it." *(Plays Noah's trust in the protagonist as a character; no mechanical effect.)*

### 15.04 The siege  *(CURRENT)*
Skitters at the window -> Hounds at the weakest door -> it breaks (`_siege`, `_skitters`, `_hounds`, `weak_door`). **Variation by reinforcement** (above). **The threatened survivor is readable before control returns:** `_rescue`: Sarah if present, else Ruth (never Eddie, who speaks for the group; `rescue_target()`), with a **named, spoken cue** `c14_threatened_alt`: EDDIE: "*Sarah's* by the door - " (so the player knows *who* before the timer).

### 15.05 The table save - and why it is fair  *(CURRENT `_shove`: control first, then a 10 s timer)*
- Order (**verified**): control returns, **then** the ten-second table-shove timer starts - so the player has the whole room in view first. **Saved** (`ch14_rescue = "saved"`): `c14_after_saved` (EDDIE: "That was too close. Everyone okay?"). **Seriously hurt** (never killed): `c14_after_hurt` (EDDIE: "Get her - get them away from the door! Keep pressure on it!"). Both are carried as health only.
- **Noah is not a target here:** by plan Noah is already at the back-door end with his partner when the door goes (his position in `st().noah_partner` is set at the end of 15.02); he is **never** the rescue target.

### 15.06 The Shellcrawler blocks the front; the evacuation  *(CURRENT)*
`c14_crab` (EDDIE: "It's at the front!" / "We can't stay here."), `c14_go` (EDDIE: "Out the back! Everyone, stay together!"), **forced open** if the back was not prepared (`_force_back`, `_open_back`). Evacuation on foot; **injured survivors are slower** (`_slow_injured` from `chapter15.gd` is the *Ch16* rule; Ch15 uses `survivors.gd:health`).
- **Noah and his partner** reach the field edge first (the route the log drew) - they wait; the player sees them wave a lamp (`3+1`, **NEW prop shot**). Pays off in the field.

### 15.07 The fence - distinct from the door injury  *(CURRENT choice; NEW emotional scaffolding)*
- Someone is caught behind a **fallen fence** (`FENCE_AT (-95.4, 0.15, 38.2)`; `c14_go`: "I'm caught - the fence! Go! Don't wait for me!" / SARAH: "I can't get through! Go - just go!" / MARCUS: "My leg's caught! Go! Find Noah!"). The caught person is **not** the same person as the door injury (the code picks a different target: `separation_target()` != `rescue_target()`, **[V `chapter14.gd:rescue_target`/`separation_target`]**).
- **Go back for them** (`c14_went_back`: PROTAGONIST: "Got you. Move!") **or keep moving** (`c14_kept_moving`: EDDIE: "We can't stop. We can't. Keep going."). **Leaving behind = `missing`** (`st().missing` -> `ch14_<name>_missing`): *their fate belongs to the next chapter and is **never resolved** by this pass* (see C: "what could resolve a missing person" - nothing in the playable campaign **[P]**: the owner may add an optional epilogue update later).
- **If Marcus is the one caught and Noah is present:** NOAH *(running back; held by Ruth)*: "DAD!" - the scene gives the player the **hardest version of the choice**. If the player keeps moving, Marcus is **missing, not dead**, and Noah's grief is *waiting* (see A: Ending A/C Noah lines). **Noah himself cannot be separated.**
- Supplies tear on the fence (`c14_lost_supplies`: "The bag tore on the fence. Some of the food is gone." / EDDIE: "That was the last safe place we had."). The field: the shelter disappears into the mist (`_house_gone`, `c14_back`: "Back to where this started."). **Exit:** `chapter_14_complete`, checkpoint `chapter15_end`.

---

## Chapter 16 - What Remains  *(chapter15.gd)*

### 16.01 The station refuge: roster, treatment, last map talk  *(CURRENT + REVISED reason to go back down)*
- **Entry:** `chapter_14_complete` -> `ch15_started`. The station (`STATION (-80, 0, -28)`) as a **roadside refuge** (nothing more). Roster = `present()` (never the dead, never the missing). **Treat** (`_supplies`), refuge's last supplies, talks that remember trust (`c15_talk_*`, `_low` / `_saved` / `_hurt` / `_back` variants).
- **Why return to the underground mechanism despite the earlier collapse (NEW, `c15_why_below`; the group's argument, in order):**
  1. *The surface is gone*: no shelter, no road (`c15_no_car`).
  2. *The earlier collapse left the route open*: the slab fell *into the floor*, the beam's chain is jammed; only the **rubble gap** remains (see 14).
  3. *The map's other end leaves the district* (`c15_map_under`: PROTAGONIST: "Where the tunnels meet - and where one of them *doesn't*."), and **the farmer's last line** ("they went *across*") - Noah has it by heart.
  4. *What the farmer's journal said held the fog off the house*: the mark. **The barrier** is the thing Chapter 14 opened.
  - **Script `c15_why_below`:** RUTH: "We can't stay here." / EDDIE: "We can't go *back*." / NOAH *(from the cot, quietly)*: "He said across. Not out. *Across*." / SARAH: "Across what?" / NOAH: "I don't know. He didn't either." / PROTAGONIST: "There's one place that has a door that opens both ways." / EDDIE: "Ah. The creepy one."
- **The plan (`c15_plan` / `c15_plan_alt` / `c15_plan_evidence`):** CURRENT; with Noah present: **NOAH stays at the station's upper room with Sarah** until the tunnel mouth is reached, then joins at the mouth **(never into the chamber)** - `c15_plan_noah`.

### 16.02 The road west and the Colossus crossing  *(CURRENT; the Meshy tripod, now 60 m, slow)*
- `c15_colossus` (the field: a few finds - medicine, batteries, water, a last note about earlier escapes). **First person**: the view is turned and drawn up a leg into the mist (`_colossus_reveal`); then **cover to cover while it walks and looks** (`_crossing_tick`): **seen in the open = reaction, the ground shakes, back to the last cover** (`_detected`, `_retry`: a fair retry, a concise fade, a minor injury **8 HP, never lethal**). **Detection audible** and **a retry window**: `c15_detected` HUD text (CURRENT hint "IT SAW YOU - GET TO COVER!"). It is **invulnerable** (rule kept).
- **Geography (reconnect passage to map/evidence/notes):** the three covers (`COVERS[0..2]`) are on the **map Eddie holds** as pencil Xs; the last note about earlier escapes (`c15_*` find) is in the **same hand** as the maintenance log's two re-seal entries (A: not a source, only continuity).

### 16.03 The district, the rubble, the passage  *(CURRENT)*
A Skitter on the roofs, a Hound up the road behind; the passage (`_passage_tick`); **the rubble of Chapter 14's collapse, a gap** (`GAP (12, 0, 23)`; `_squeeze`): the player and group squeeze through. `chapter16_passage` checkpoint.

### 16.04 The sealed doorway and the great chamber  *(CURRENT; inspection REQUIRED vs OPTIONAL)*
- The sealed doorway, now open; the ancient passage (one mist-filled pocket to avoid, `_below_tick`); **the great chamber** (`GREAT (12, 0, 78)`, x -6..30, z 62..96): the symbols (`c15_clue_symbols`), the damaged seals (`c15_clue_seals`), records of earlier containment (`c15_clue_records`, `c15_clue_records_evidence` if evidence kept), the stone structure, **a shape behind it** (`_horror`).
- **Required vs optional (so there is no softlock):** **required**: reach the chamber, examine **at least one** of the four clue props *or* walk to both control points (the **two controls** are what gates the decision, `CTRL_A (-3.2, 0, 74)` and `CTRL_B (27.2, 0, 74)`, in `_control` / `_control_done_look`). **Optional**: the clue props (they are *fairness* - the player can read what the final mechanism does *before* choosing).
- **Putting the two controls, the temporary barrier and the service tunnel in the player's mental map (NEW, `c15_map_room`; Noah's code makes it readable):** from the chamber's south end the player sees **three lit points** in a straight line: control A (west), the **seal** (centre, `SEAL (12, 0, 86)`), control B (east). The **service tunnel** is the **fourth light**, small, behind the seal. As the group comes in, Eddie holds the map up against the wall: EDDIE: "West lever. East wheel. Door in the middle. Exit behind the door." RUTH: "And the *temporary* barrier?" PROTAGONIST *(touches the stone)*: "This. It won't hold on its own." *(plays right before `c15_two_ways`)*.

### 16.05 Two control points, the final mechanism, falling stone  *(CURRENT)*
At the seal the flashlight falters, **a vast shadow crosses**, the **stone begins falling** (`_drop_stone`, `_horror`). Hand control back **before** the two control points (A then B). **Falling-stone fairness:** each control has a **safe window** (the stone falls in a rhythm the player can read: three impacts, a pause, then clear).
- **Checkpoint:** `chapter16_decision` is written **before** the decision (CURRENT `_decide`); it is **the earliest checkpoint for each ending** (A, B and C all load it). It is also the *replayable pre-choice checkpoint* (CURRENT `_record_ending` loads it back after recording).

### 16.06 The decision  *(CURRENT choice, REVISED to telegraph risks)*
`c15_two_ways` (PROTAGONIST: "The tunnel out. Or back to the mechanism. It won't hold on its own."). Choice text (`choice.ask`, CURRENT):
- **LEAVE GREYHAVEN - escape with everyone through the service tunnel** (A).
- **SEAL THE CHAMBER - go back to the mechanism and try to close it** (B).
- **SEND THE SURVIVORS AHEAD - stay and hold the passage** (C).
- **REVISED telegraph (each option gets a one-line hover text shown under the choice, `c15_choice_cost_A/B/C`):**
  - A: "Everyone lives. The barrier does not hold."
  - B: "Everyone may live. You go back in under falling stone."
  - C: "Everyone lives. You do not come out."
  - This keeps the *prompt* CURRENT and adds only information, never an extra option.

---

## The three endings (all CURRENT mechanics; REVISED payoff)

### 16.A - Leave Greyhaven
- **Procedure (player):** choose LEAVE GREYHAVEN; follow the **live exit objective** along the service tunnel with everyone present (`_leave_tunnel`); reach the fields (`_to_outer(and_player=true)`, thinner mist, the sky shows); look back at Greyhaven under its fog (`_look_back`); the survivors walk away (`_walk_away`); the mist edge moves subtly (`_mist_edge`).
- **CURRENT lines:** `c15_end_a` / `_alt` (RUTH: "We made it." / "Yeah." / EDDIE: "So... what now?" / "We keep going.").
- **Noah/Marcus payoff (NEW `c15_end_a_noah_alive` / `_lost`):**
  - **Marcus alive:** NOAH *(from his father's shoulders, not on them: he's thirteen)* walks beside him, holding the lamp. MARCUS: "I looked back more than anyone." NOAH: "I know. I counted." MARCUS: "...How many?" NOAH: "Eleven." *(Quiet laugh.)* PROTAGONIST *(looking at the mist)*: "It's still behind us." EDDIE: "That's not what I meant by 'what now'."
  - **Marcus lost, Noah present - Noah's grief moment:** NOAH *(stops walking; the group waits; nobody says anything)*: "He didn't see it." RUTH *(`@1` if Ruth absent)*: "See what?" NOAH: "The sky." *(He lifts the backpack; walks again.)* No music; wind.
  - **Marcus alive, Noah NOT rescued (old save):** CURRENT epilogue only; no Noah line.
- **Alternate living spokesperson if needed:** Eddie speaks the group's lines; if Eddie is missing (a `ch14_eddie_missing` flag - the code never produces it for Eddie; kept as a rule), **Ruth**; if Ruth and Eddie are both gone, **Sarah**; never Noah, never a dead character.
- **The escape physically works; the metaphysical question stays open** (no line says the mist is gone or that it follows).
- **Epilogue line (CURRENT):** "Behind them, the mist reached a little farther every night."

### 16.B - Seal the Chamber
- **Procedure:** choose SEAL THE CHAMBER; the group **waits at the tunnel mouth** (Noah with them, lamp on); the player returns to the mechanism; **pull lever A, then turn wheel B** under falling stone (`_seal_step`, `_refresh_seal_prompts`); **the slab closes locally** (shown); escape through the service tunnel; **partial withdrawal of mist**: the fog line over the fields retreats a few paces and *stops* (CURRENT: "Over Greyhaven the mist thinned. Not gone. Quieter.").
- **Difference between intervening at risk and fleeing immediately:** B costs the player **health** and **time**, and **nothing is promised**: CURRENT `c15_end_b` (EDDIE: "Did we stop it?" / "I don't know." / "But it's getting smaller.") - the ending's *only* claim is **local and partial**.
- **What the group intends next (NEW `c15_end_b_next`):** RUTH: "The map shows farms on this side." SARAH: "People, maybe." NOAH: "The old man had a route to the next town. I know the first three turns." EDDIE: "I'll take the ones I know I can't mess up." - *they walk on toward other people; they do not stay.*
- **How it differs from the old "The Ones Who Stayed":** nobody fortifies a shelter; the closing is an act at risk, not a settlement. *(If the owner prefers the older shape, see `E_alt_fortified_shelter_memo.md`.)*

### 16.C - Send the Survivors Ahead
- **Procedure:** choose SEND THE SURVIVORS AHEAD; **the trade is explicit before the commit** (the hover text "You do not come out" + CURRENT `c15_stay`: EDDIE: "You're coming with us, right?" / "Get them out." / "That's not what I asked." / "Go!"); **companions including Noah clear the tunnel** (`_to_outer(and_player=false)`: the exterior cutaway, an onlooker's view); the player works lever A then wheel B (`_ending_c`); **the passage collapses after their crossing**; the flashlight flickers on the shut slab, then dies into silence.
- **The final voice motif (REVISED to be the code - the only voice the player would recognise, ambiguous):** the player taps **three short and one long** on the stone in the dark (an on-screen prompt only, held like the knock in 13.0d). A moment of silence. Then, faintly, **three short and one long** answers from beyond the stone. *Unknown whether it is the group, the stone, or something else.* CURRENT `c15_voice` ("Distant voice ...") plays under it.
- **Confirm others got out:** the exterior cutaway (CURRENT `epilogue_lines` "They waited at the tunnel mouth until morning. Nobody came out.") plus the roster lines; **the protagonist's fate is unresolved** (bible Ending C).
- **Noah's emotional change:** NOAH *(at the tunnel mouth, to Ruth, not to anyone)*: "He knocked back." RUTH: "Who?" NOAH: "Nobody." *(He is protecting the group from a hope he cannot prove.)*

### 16.X - Epilogue and records
- **Source of truth:** `chapter15.gd:epilogue_lines(ending)` + the roster, health, trust and flags (CURRENT). **Fixed table (REVISED; replaces the single bug line "Noah was never found."):**

| Condition (all [P] unless noted) | Line |
|---|---|
| `ch12_noah_found` and Marcus present and not missing | "Noah walked beside his father the whole way." |
| `ch12_noah_found` and Marcus lost (`ch9_marcus_lost`) | "Noah carried his father's backpack. He did not put it down." |
| `ch12_noah_found` and Marcus missing at the fence (`ch14_marcus_missing`) | "Noah stopped at every turn in the road and looked back. Nobody told him to stop." |
| **No** `ch12_noah_found` and Marcus lost (old saves) | "Marcus did not leave the supermarket. He never stopped looking for Noah." *(CURRENT)* |
| **No** `ch12_noah_found` and Marcus present | **(replaces the bug)** "Marcus never stopped looking for Noah." *(truthful; no claim of a rescue)* |

  - Cast lines per Eddie/Ruth/Sarah/Marcus: CURRENT (made it out / carried / limping; trust >= 50 vs < 50; missing line "last seen at the fence behind the mill-worker house. What happened after is not known."). **A later update could legitimately resolve a missing person** only by an **optional post-credits record** (e.g., a found note at the tunnel mouth) - **not in this pass** **[P approval item]**.
  - Ending lines (CURRENT): A "Behind them, the mist reached a little farther every night." B "Over Greyhaven the mist thinned. Not gone. Quieter." C "Below Greyhaven, something waits behind the stone. Something else waits with it."
- **Title, credits, THANK YOU FOR PLAYING, menu return** (CURRENT `_credits`, `_menu_main`, `_menu_replay`, `_menu_load`).
- **Ending history** stays in `user://veil_endings.json` (CURRENT `_record_ending`); the player's save goes back to `chapter16_decision` with `endings_seen` recorded so the finale is always replayable.
- **Interrupted-ending resume. CORRECTION (found while implementing): the code ALREADY does this** - `game_state.gd:_finale_rollback` loads any save made after `ch15_decided` as the complete pre-decision checkpoint (`chapter16_decision`), keeps the endings seen, and applies nothing twice **[V]**. The commit-record design below is therefore **not needed** and is kept only as the fallback if that rollback is ever removed:
  1. Before any side effect, `_finish` writes a **commit record** `ch15_ending_commit = {ending, epilogue, roster}` into `st()` (and sets `ch15_ending_committed`).
  2. `_record_ending` becomes **idempotent**: it keys the history entry by `commit_id` (hash of ending + play_time) and **skips if present**.
  3. On load, if `ch15_ending_committed` and not `ch15_ended`, the game **replays the presentation only** (epilogue cards, credits) from the stored lines - it never re-runs `_ending_a/b/c`, never re-applies injuries, supplies or seals, and never re-records.
  4. If the player loads the `chapter16_decision` checkpoint, `ch15_ending_committed` and `ch15_choice_*` are cleared (the existing behaviour of loading a checkpoint) and the endings-seen list is preserved from `user://veil_endings.json`.

---

## Act V state at exit
`ch15_ended`, `chapter_15_complete`, `ch15_choice_a|b|c`, `st()["epilogue"]`, ending record. Invalid: ending A/B/C **and** `chapter16_decision` still unwritten (the decision cannot be reached without the checkpoint); two different `ch15_choice_*` flags at once (`_decide` is guarded by `ch15_decided`).
