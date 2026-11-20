# A. Continuity audit, writer-only history, player timeline, fact table, route map

Branch `cinematics/ledger-pilot` (docs only). Campaign snapshot `3bcf31b6` is an ancestor of this branch; the Meshy art reference is `0aff4cb`. **[V]** = verified in code/data (path given). **[P]** = proposal (needs owner approval, listed in `F_approvals.md`). Nothing here has been play-tested; it is source reading.

The bible's own rules are kept: no definitive source, experiment, dream, simulation or cosmology; the Colossus is invulnerable; the player is an ordinary person; no new monster species; Noah is alive, about 13, resourceful, never a fake-out or expendable escort; Marcus can be lost; Eddie's humor comes from stress.

## A1. Conflicts and resolutions

| # | Conflict | Evidence | Resolution |
|---|---|---|---|
| 1 | **Chapter numbering.** The bible plans ~14 chapters (Ch13 "The Farmhouse", Ch14 "The Last Signal", Ch15 "The Last Crossing"); the game has 16. | `game/data/chapters.json` [V]; bible §9 | Keep the 16 displayed chapters and their internal keys (`chapterN.gd` = displayed N+1 from displayed 6 on; flags `chN_*`). The bible's "Farmhouse" content becomes the opening of displayed Ch13 **[P]**. Always cite displayed numbers; internal file/flag in brackets. |
| 2 | **Noah is never rescued.** The bible makes the rescue a required milestone; no code does it, and the epilogue prints "Noah was never found." (even when Marcus is alive). | `chapter15.gd:epilogue_lines` [V]; `chapter11.gd` header "Noah is not found here" [V] | New mandatory, repeat-safe Noah rescue at the start of displayed Ch13 (internal `chapter12.gd`) **[P]**: scenes 13.0a-13.0f in `B4`. |
| 3 | **Authored clues have no payoff.** Backpack and note (`c7_*`, items `noahs_backpack`/`noahs_note`), campsite note (`ch11_note_found`, `noah_clue_campsite`), Noah's message (`ch11_message_found`, `noah_clue_farmhouse`) and the HOUSE_19 light (`ch11_light_seen`) all point at a farmhouse nobody enters. | `chapter7.gd`, `chapter11.gd`, `game/data/items.json` [V] | Payoff = the rescue (13.0). The "survivor's account" the bible lists is given by the farmer's journal plus Noah's own account **[P]**. |
| 4 | **Ending topology.** Bible: A Beyond the Veil, B The Ones Who Stayed (fortified shelter), C Into the Mist. Code: A LEAVE GREYHAVEN, B SEAL THE CHAMBER, C SEND THE SURVIVORS AHEAD, plus `epilogue_lines`. | `chapter15.gd:_decide` [V]; bible §13 | Keep the code's three as the main treatment (owner's instruction). The fortified-shelter ending is a separate memo, `E_alt_fortified_shelter_memo.md`. The bible's A/C intent is preserved: A = escape with doubt, C = protagonist stays behind. |
| 5 | **Survivor tracking is three overlapping systems.** `survivors.gd` (trust, health, morale; NAMES = Eddie, Marcus, Ruth, Sarah), `chapter9.gd:roster()`, `chapter10.gd:group()`, `chapter14.gd:present()` with `st().missing`. `living_town.gd` Frank and the Chapter 6 temporary survivor (`c5_survivor_*`) are outside all of them. Bible says Eddie "may die in a later preventable event"; no code kills Eddie. | files above [V] | One derived availability model (see C3): `alive`, `present`, `fit`, `whereabouts` are separate from `trust` and `health`. Eddie, Ruth, Sarah never die in the playable campaign (code behaviour, kept); only Marcus can be lost, plus the scripted temporary survivor and Frank. The bible's "Eddie may die" is declared **superseded** **[P]**. |
| 6 | **Optional car vs the failed car.** The sedan dies at the Veil's arrival (`world.gd:_p3_car_dead`), a different abandoned sedan is searched in Ch11, a car-repair quest exists (`car_quest.gd`), Ch15 says the car is used "only if it is really here". | `world.gd`, `chapter10.gd`, `car_quest.gd`, `chapter14.gd` header [V] | Ordinary reason at arrival: the engine will not turn over and the dash fails with the lights (the Veil's power loss, same cause as the market doors). The repaired car (optional) is a **fuel/range shortcut only for the surface route**, never a way past the finale. See Act-I script 03.03 and Act-V 15.x. |
| 7 | **Time and sleep.** Bible: "Do not automatically advance the main story merely because the player slept." Code: chapters start on sleep flags (`p4_slept`, `c5_rested`, `ch6_rested`...) after their milestones are met; "2 HOURS LATER" skip in Ch3. | `chapters.json`, `phase4.gd:_on_slept` [V] | Compatible: sleep only starts the next chapter when the previous one's milestone flag is already set. Keep. New rescue content does not start on sleep; it starts on a physical event at the mill house (the breadcrumb) **[P]**. |
| 8 | **Colossus silhouette.** Bible: "enormous four-legged creature with tentacles". Meshy tripod: three legs (`Leg_L`, `Leg_R`, `Leg_B`); the old rig has four (`Leg_FL/FR/HL/HR`). Default is the tripod; `-- old_colossus` plays the old four-legged encounter. | `game/enemies/tripod_colossus.gd`, `world.gd:_colossus_encounter` [V] | **Decision for the owner.** Recommended: keep the tripod as canon, amend the bible wording to "many-legged", keep the old encounter as a legacy path. In-world no character counts legs (they only see feet and fog), so no script line is affected. |
| 9 | **Map geography.** Three distance systems: town (market near origin), outskirts (mill house at (-92, 14), station at (-80, -28), HOUSE_20 (-78, -92), HOUSE_19 (-78, -116)), district (D_ORIGIN (-125, 30)). | consts in `chapter10/11/12/13.gd` [V] | Route map in A5. Mill house to HOUSE_19 is about 130 m: a short, exposed field walk, believable for a stealth entry. |
| 10 | **Marcus's window.** The brief says the pin window is 4/8/12 s by trust; the snapshot has `PIN_SECONDS := 10.0` for everyone and only *records* `marcus_trust()` (0..2 from `p4_choice_noah`, `marcus_trust_search`). | `chapter9.gd:pin_window` [V] (identical at `3bcf31b`) | **[P]** implement the brief's scaling (trust 0 = 6 s, 1 = 10 s, 2 = 14 s, a smaller spread than 4/8/12 so a low-trust run is not a near-forced loss) or keep 10 s and let trust change the *dialogue*. Recommended: scaling 7/10/13. The player must always have a fair chance. |
| 11 | **Epilogue bugs.** (a) "Noah was never found." prints whenever Marcus is not lost. (b) Ending C line "Nobody came out" is printed before the cast lines. (c) No line for the fence-left survivor's *return*. | `chapter15.gd:epilogue_lines` [V] | Replace the Noah line with the Noah table in B5.4 **[P]**; keep (b); (c) is intentionally unresolved. |
| 12 | **Marcus keeps watch at the mill house** in `c12_symbol_marcus` ("I'll keep watch here"). With a rescue, a living Marcus would not stay. | dialogue `c12_symbol_marcus` [V] | New scene 13.0 comes first; after it Marcus's "keep watch" is spoken by Marcus *with Noah beside him* (revised line, B4). If Noah was never rescued (old save) the original line stands. |
| 13 | **Optional temporary survivor.** Ch6 (`c5_survivor_helped / _informed / _left`) feeds Ch9's temporary survivor "the Chapter 5 survivor, or a stranger who came in the night". Frank appears only in `living_town.gd` (taken by the Skitter). | `chapter5.gd`, `chapter8.gd`, `living_town.gd` [V] | Canon: the stranger and Frank are the *same kind of person* (people who did not make it); nobody returns. See B2/B3. |
| 14 | **Chapter-select fixtures** (`game/chapters/setups/dev_chapterN.gd`) are not campaign history. | CLAUDE.md, chapters/setups [V] | All QA claims below name real-save checkpoints. Fixtures only for smoke tests. |
| 15 | **The Veil's "documents".** Station records already say the lower level was sealed repeatedly "for decades"; Ch14 note says "does not always come from outside". | `c12_clue_*`, `c13_note` [V] | Confirmed: previous encounters and repeated containment attempts are canon. No dates beyond "decades". Writer-only history below uses relative years only. |
| 16 | **A hard-coded player name.** Eddie's line `p3_eddie_over_here` is "FINN! Over here - the shop, NOW!". The player chooses a name in the menu (`Game.player_name`, `game_state.gd:82`) and the bible says not to invent a fixed name; no other dialogue uses a name. | `dialogue.json` line 7111 [V]; `player_name_test.gd` | Replace with a line that needs no name (B1 03.03), or add `{player}` substitution to `Dialogue.say` first **[P]**. |
| 17 | **A promise the story does not keep.** Chapter 12 ends with "At first light." (`c11_light_alive`) about HOUSE_19; Chapter 13 opens at the mill house "before dawn" with a different plan. | `dialogue.json c11_light_alive`, `chapter12.gd:_opening` [V] | The new 13.0 keeps the promise (B4). |
| 18 | **Lock-In choice names.** The brief says "accept / refuse the search"; the real flags are `p4_choice_noah` (accept) and `p4_choice_wait` (refuse), and the refuse branch has **no evening creature**, only night banging. | `phase4.gd:_run_threat` [V] | B1 05.02 uses the real flags and describes what each branch shows. |

## A2. Writer-only chronological history (never shown in full)

Relative to Friday 6:42 PM = day 0. Anything labelled WITNESS is something a character says and can be wrong. Nothing explains the origin.

1. **Long before the town.** A chamber of cut stone under the field (`c12_clue_stone`: "older than the town"). The symbol is carved there again and again (`c13_clue_markings`). Why: unknown. Who: unknown.
2. **Early Greyhaven.** The town grows over the field. Utility tunnels and a pump/maintenance block are built over/near the stone (`c12_clue_map`).
3. **"Decades" of entries.** The maintenance log repeats "Lower level sealed. Do not reopen" (`c12_clue_log`). An inspection report: "vibration persists. Recommend no further entry" (`c12_clue_report`). A handwritten note at the district gate: "does not always come from outside" (`c13_note`). Contradiction kept legible: the report blames vibration (a local effect), the note blames something coming *through* (a presence); neither is confirmed.
4. **The district is abandoned "years ago"** (Ruth, `c12_map`). Reason never given; the broken sign repeats (`c13_sign`).
5. **Friday, day 0.** Mist arrives (`p3_mist`); Colossus; the market doors die; two hours pass in the stockroom (`Chapter 3`); the run to the supermarket (Ch4); lock-in (Ch5).
6. **Day 0, evening, offstage.** Noah (about 13) is separated from Marcus when the mist arrives **[P: where]**: he was at the **pump road bus shelter** on the way back from his afternoon activity **[P]**. He runs west, away from the town sounds, reaches the farm road, and an older farmer taking in his stock at HOUSE_19 pulls him inside (bible §8). The farmer gives him rules: lamp low, never after dark on the road, three short flashes and a long one means "all's well", the mark is the one place the fog sits thinner (the farmer got that from old men in town). **[P]**
7. **Day 1-2.** Noah wants his father; the farmer says wait. Noah leaves a camp trail and a message (campsite jacket, `campsite_note`; the message at HOUSE_20, `noahs_message`) when the farmer takes him on one scouting trip to HOUSE_20 **[P: why two houses]**: HOUSE_20 is the farmer's late brother's place; the farmer checks it for fuel and food each morning, Noah once stayed a night there and heard something outside (`noahs_message`: "I couldn't stay here. I heard something outside last night") and went back with the farmer to HOUSE_19. **[P]**
8. **Day 3-ish.** A Hound crosses the field; Noah shelters, the farmer's lamp flickers. The farmer goes out toward the maintenance block on the road to find fuel (journal) and does not return. **The farmer's fate is not revealed** (bible §8). Noah keeps the lamp low and rations.
9. **Day N (player chapters 6-12).** The player group works through Ch6-12, finds the backpack (Noah's, found in the abandoned car "near the old service road", `noahs_backpack`; the CURRENT note is signed by Noah: "A man said he knew somewhere safer, outside town. He said there's a house near the farms. I'm going with him." **[P]** he left the bag and note in the car on purpose so his father could find them; the man = the farmer), the campsite note and message, and flees HOUSE_20 and sees HOUSE_19's light (`ch11_light_seen`). Offstage, the shape behind HOUSE_19's window is Noah moving with a candle, not a monster.
10. **Next dawn (new Ch13 opening).** Breadcrumb, stealth entry, rescue (B4).
11. **Underground arc (Ch13-14, 14-16).** As written, with the rescue giving the *reason* to go below: the surface is failing.
12. **After the finale.** Three endings. No source, no definitive cosmology.

## A3. Player-discovery timeline (what the player learns, and when)

| When (displayed ch) | Player learns | Source |
|---|---|---|
| 1 | Alone, empty fridge, keys. | `world.gd`, `wake`, `fridge` [V] |
| 3-4 | Mist, a huge thing, Eddie, Marcus (his son is missing), doors die. | [V] |
| 5 | The market is the shelter; Marcus will not abandon Noah (`p4_choice_noah`). | `phase4.gd` [V] |
| 6 | Others exist (HOUSE_05 survivor). | `chapter5.gd` [V] |
| 7 | Voices lure; Ruth and Sarah are real people. | `chapter6.gd` [V] |
| 8 | Noah's backpack and note: alive, helped, west. | `chapter7.gd` [V] |
| 9 | A barrier can fail; someone dies; Sarah is hurt. | `chapter8.gd` [V] |
| 10 | The market falls; Marcus may not make it. | `chapter9.gd` [V] |
| 11 | There is no safe road; the mill house. | `chapter10.gd` [V] |
| 12 | Noah's trail: campsite, message, the farmhouse light. | `chapter11.gd` [V] |
| 13 (new) | Noah, the farmer's journal, the mark, "go below". | **[P]** |
| 13 | The station, decades of sealing. | `chapter12.gd` [V] |
| 14 | The district, the ancient doorway, a before/after. | `chapter13.gd` [V] |
| 15 | The last shelter falls. | `chapter14.gd` [V] |
| 16 | The chamber, the decision, three endings. | `chapter15.gd` [V] |

## A4. Confirmed facts / witness testimony / unresolved phenomena

| Category | Item |
|---|---|
| **Confirmed (physical, the player holds it)** | The mark is on Noah's message and the utility map and carved in stone below (`c12_symbol`, `c13_clue_markings`). The station log repeats "Lower level sealed. Do not reopen." Stone under the concrete is older than the town. The sealed doorway opens by winch and beam. Noah is alive and was sheltered by an older farmer (new, journal + Noah). |
| **Witness testimony (can be wrong)** | Ruth: the district was abandoned "years ago." Eddie: the fog "never seems to move with the wind." Marcus: "someone helped him." The farmer (journal): "the old men said the ground there was never right." Noah: what he heard outside. |
| **Unresolved by design** | What the Veil is. Where the Colossus goes. Why mist moves against wind. What the voices are. What waits behind the seal. What happened to the farmer. Whether the mist behind the survivors is following them (Ending A). Whether Ending B did anything beyond locally. What became of the protagonist (Ending C). |

## A5. Greyhaven route map (all reused locations)

Coordinates are world metres from the code; x east, z south (market at the origin).

```
 HOUSE_19 (-78,-116) ---- farmer's place  [P: Noah]
     |  26 m
 HOUSE_20 (-78, -92) ---- abandoned farmhouse, Noah's message (ch11)
     |  64 m south
 MAINT. STATION (-80, -28) ---- door on the north face; sealed levels below (ch13 / ch16)
     |  ~56 m south-west
 MILL HOUSE (-92, 14) ---- the group's refuge from ch11 to ch15; field behind (fence at (-95, 38), SAFE (-102, 56))
     |  main road z -6..6, west of x -54 open fields
 abandoned SEDAN (-28, 3.9) / roadblock x -46 / side route via gap x -28, gate z -12.6   (ch11, "No Safe Road")
     |
 MARKET (0,0)  --- GAME SHOP across Main Street --- HOUSE_04 (cottage behind) / HOUSE_05 / HOUSE_06 (Ruth & Sarah)
     
 DISTRICT (-125, 30) ---- abandoned streets, checkpoint gate, passage of echoes, ancient doorway under it (U = (-125,-45,120)) (ch14)
 CHAMBER (12, 0, 78) under the field: controls A (-3.2, 74) and B (27.2, 74), seal (12, 86), rubble gap (12, 23) (ch16)
```

Reading order a player walks: market -> main road west -> mill house -> station (north) -> farm road (HOUSE_20 -> HOUSE_19) -> back -> district (west) -> underground. The new Noah rescue sits *between* two places the player already knows (HOUSE_20 and the mill house), so it adds no new geography.

## A6. Firm proposals for missing connective tissue (summary; scripted in B1-B5)

1. **Why the car is unusable at arrival** (ordinary): ignition fails when the power drops. (03.03)
2. **Where Marcus came from, his last contact, why two hours in the stockroom, what changes to risk Main Street**: Marcus was at the game shop (`_p3_place_marcus_in_shop`) because his phone's last text from Noah came from the shop's street (`B1`, 03.04). Two hours: the thing circles; footfalls stop; Eddie's shop radio (`static`) clears for 20 seconds; a human voice on it says "supermarket, the generator" (a practical reason, not a lure: a second, repeating, non-answering loop is the tell). 
3. **Lock-In accept/refuse as a value conflict**: accept = "we find out what is out there"; refuse = "nobody leaves the walls for a guess." Trust effect kept (`p4_choice_*`). Paired scenes expose different information (accept: roof Skitter seen and its movement; refuse: sound only and the seam in the door).
4. **Ruth and Sarah's route** to the group on both invite and non-invite paths (B2).
5. **Why either Hound route intersects the player**: the Hound is drawn by the survivors' scent/noise at the door and the player's own radio use; both routes cross its circuit.
6. **Real vs lure Noah evidence**: real clues carry a corroborating physical detail only a family member would confirm (the bag's colour complaint, the keepsake); lures never do (B2).
7. **Why the market is viable after the first attack and lost after the second** (B3).
8. **Rendezvous plan** by Eddie and Ruth (B3).
9. **Mill house**: plausible refuge (solid fieldstone, one road approach, backs onto open field).
10. **Noah rescue** (B4), **why below ground now** (B4), **why the opened route stays reachable** (B4/B5: the ancient doorway stays open by its winch and beam; the collapse rubble leaves a gap; the repaired ramp chain is jammed in the open position).
11. **Noah's evacuation partner in the siege**: Ruth, or Marcus if alive. (B5)
12. **Why return to the underground mechanism after the earlier collapse**: the surface shelter is gone; the map and Noah's note show the *tunnel's other end* leaves the district; the barrier Ch14 closed is the one thing the farmer's journal said held the fog off the house; and Noah can read the signal pattern that opens the service tunnel (B5).
