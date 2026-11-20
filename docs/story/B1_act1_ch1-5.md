# B1. Act I - The Arrival (displayed chapters 1-5)

Conventions for all B files. **Scene ID** = the cinematic ledger ID (`docs/cinematics/SHOT_LEDGER.md`); new material adds a suffix `.n`. **CURRENT** = exists; its exact lines are in `appendix/current_dialogue_*.md` under the quoted ID and are NOT repeated unless revised. **REVISED/NEW** = written in full here with a proposed subtitle ID. Speaker `@1` in an `_alt` ID is the existing convention for "whoever else is present" when the named speaker is missing (`c15_end_a_alt`). The protagonist has no fixed name (bible §7); where a name is needed use the token `{player}` (see Audit #16). Flags are quoted as in code.

**Cast rules for Act I:** Eddie, Marcus and the protagonist only; the clerk and townspeople are background (`living_town.gd`). Nobody dead returns. Eddie's humor = fear management, never constant.

---

## Chapter 1 - An Ordinary Evening  *(world.gd, home_bathroom.gd)*

### 01.00 Before the evening - intro **[BUILT, CURRENT code]**
New game, `intro_seen` unset (`world.gd:_opening`). Black, radio, the town at dusk with the Meshy people, the first wrong notes, the Veil rising with the Colossus faintly in it, THE VEIL, slow fade to black, fade into the game.
- **NEW radio text (replaces the current generic static)** `intro_radio_1`, played over black, then static breaks the sentence:
  - RADIO (local station, male, bored): "...clear skies for Greyhaven tonight, a little cooler after dark, so if you're heading out this evening..."  *[static bites the next word]*
  - RADIO: "...stay on the main road, and... *[static]* ...six-forty on a Friday. Enjoy it."
  - Intent: establish ordinary normality in two sentences, then one broken one. Subtext: the only warning is a weather report nobody is listening to.
- Exit: black; world fades in on the bedroom spawn. Skip: hold E / Esc.

### 01.01 6:42 PM - waking, the empty fridge, the keys  *(CURRENT + 1 NEW beat)*
- **Entry:** `intro_seen` set (or skipped); `Markers/Spawn_WakeUp`. Roster: protagonist. Time 6:42 PM.
- **Intent / subtext:** the protagonist *chose* to be alone; the house shows it. Not sad, just unconsulted.
- **Action:** CURRENT `wake` (nap), CURRENT `wake_hint`, optional bathroom wash (`home_bathroom.gd:wash_face`, `wash_hungry`), `fridge_empty`, `keys` pickup (`has_keys`).
- **NEW beat 01.01.1 (optional, 8 s, kitchen counter):** a landline answering machine, one red blink. Interaction `[E] Play message`.
  - `wake_solitude_1` MACHINE: "Hey, it's Dana from work. Third time. Come to the thing Saturday, you don't have to talk to anyone. ...You don't have to talk to anyone. Okay. Bye."
  - `wake_solitude_2` (protagonist): "Later."
  - Why: shows the chosen solitude without a backstory; no new character appears. *[P - owner may prefer to cut]*
- **Objective:** CURRENT `Game.current_goal()` (get keys, leave).
- **Camera/audio:** first person; `fridge_hum`; machine hiss is the only warm sound in the house.
- **Exit:** front door, `left_house`, driveway, `entered_car`. Control throughout.

---

## Chapter 2 - One Last Stop  *(world.gd, store_merch.gd)*

### 02.01 Arrival and errands  *(CURRENT)*
- `arrival_shot` fires at the market sign (`world.gd:_arrival_shot`, line `town`). Errands are **either order** (`groceries_done`, `game_bought`), pay-before-you-leave (`_pay_guard`, `pay_first_*`).
- **Entry:** `in_car and sedan.driven and not arrival_shot`. **Roster:** protagonist, cashier, Eddie in the game shop.
- **Interaction order (both orders valid):** supermarket checkout (`market_checkout`, `groceries_done`) / game shop (`game_pick`, `eddie_hello`, `eddie_buy`, `eddie_after`, `game_bought`). `errands_done` plays when the second is complete.
- **NEW glue so both orders reach one believable outdoor trigger (02.01.1):** after the second errand the protagonist must walk to the **car** at the kerb (the old goal) - they have never needed to go outdoors earlier than that. The existing trigger is `_outdoors()` while `p3_mist` is set; the mist starts at `_p3_start_mist` the moment *both* flags are set (`world.gd:_p3_tick`). So the player is always either inside the second store (market first -> game shop last, Eddie's shop; or game shop first -> market last, the clerk's) when the mist begins, and the *first outdoor step* after that is the Colossus. **No change needed** - this is a verified fact, written down so no later edit breaks it. [V `world.gd:_p3_tick`]

---

## Chapter 3 - The Veil Arrives  *(world.gd)*

### 03.01 Mist arrival  *(CURRENT, `world.gd:_p3_start_mist`)*
- **Entry:** `groceries_done and game_bought and not p3_mist`. Lights stutter; `p3_fog` ("The lights... what's going on out there?" / "That's not normal fog."); clerk (if in the store zone) goes to the doors; Eddie and Marcus are placed in the game shop (`_p3_place_marcus_in_shop`).
- **NEW Eddie beat (only if the player is in the game shop, `eddie_fog`)** - Eddie, stress humor: "Okay. Okay, so that's either a very serious fog machine or I should have called in sick." (3 s). If in the market: the clerk `clerk_fog`: "That's... that's the power. It's the power, right?" 
- **Exit:** control; the next outdoor step triggers 03.02.

### 03.02a Colossus encounter - original stomp  *(legacy, `-- old_colossus`)* - CURRENT; unchanged.
### 03.02b Colossus encounter - Meshy tripod, 17.8 s of held camera  *(BUILT, default)*
- **Entry:** `p3_mist and not p3_stepped_out and _outdoors()`. **Roster:** protagonist (alone), clerk if outside.
- **Intent / subtext:** the player is no longer in a story about groceries. The creature does not attack; it *looks*, and finds them. Fear = being noticed, not being chased.
- **Beats:** 13 s a shape surfaces out of thick fog facing the player; light sweeps the street; it finds the player's face; jump-scare zoom to the eye (CURRENT); snap back; **GET BACK INSIDE** (`p3_colossus`: "Inside. Get inside. NOW.").
- **Exit state:** first person, controls on, survival HUD, beacon `store_back`, tentacles spawned; `_tripod_watch` holds the light until cover.

### 03.03 Street survival and the failed car  *(CURRENT + REVISED line)*
- **Why the car is unusable at that moment (ordinary):** the same power loss that killed the market doors. `_p3_car_dead`: "Come on, start. Start!" / "Dead. Even the radio's just static." (CURRENT `p3_car_dead`, repeat `p3_car_again`: "Still dead."). **No new line needed**; the cause is stated by the static.
- **Distinguish from the optional repair later:** the repair quest (`car_quest.gd`) needs a battery from the delivery van behind the supermarket (`car_battery`) and fuel (`fuel_can`) - physical parts, not "the car fixing itself". At the Veil's arrival the player has none, and the street is not a place to try. **[V items.json]**
- **Eddie's call:** `p3_eddie_calls` "Hey! HEY! Over here - get inside, now!"; later `p3_eddie_over_here` (Colossus: supermarket doors died). **REVISED (Audit #16):** `p3_eddie_over_here`: "Hey! Over here - the shop, NOW!" (removes the hard-coded name "FINN"). *If the owner wants a name, add `{player}` substitution to `Dialogue.say` first.*
- **Frank (optional, `living_town.gd:_frank`, `lt_frank_done`):** the Skitter takes Frank; the protagonist is locked, then **walks himself to the nearest open door** (CURRENT, built). This also makes the *optional approach to the sedan* safe: the retreat triggers only after Frank, never before the player has had the chance to try the car.
- **Both errand orders:** same scene; only where the player stands differs (market-side: doors die, `_market_doors_die`; shop-side: Eddie is already at the door). **[V `_p3_survival_begins`]**

### 03.04 Stockroom and two hours later  *(CURRENT + NEW connective scene 03.04.1)*
- **Entry:** `p3_back_inside and not p3_in_shop`. **Roster:** protagonist, Eddie, Marcus.
- CURRENT: `p3_shop` (Marcus: "My son is out there. Noah." Eddie: "...we regroup first. The supermarket..."), `_shop_regroup` shots F and G, seated talk `p3_seated_a/b` (Marcus: Noah is thirteen; he came in because the lights were on), `2 HOURS LATER`, `p3_lights`.
- **NEW 03.04.1 - Marcus's last contact (during the two hours, after `p3_seated_b`)**. *Subtext: Marcus is rationing hope.* `p3_marcus_phone` (Marcus holds a phone, 4% battery):
  - MARCUS: "Last text. 6:31. 'Dad I'm at the pump road bus stop, waiting for Mrs. Hale's ride.'"
  - EDDIE: "That's, what, a mile out of town?"
  - MARCUS: "Mile and a half. West."
  - PROTAGONIST: "Did he answer after?"
  - MARCUS: "I called nine times. It rang. Then it stopped ringing."
  - EDDIE (after a beat): "...Rang is good, right? Rang means the phone was on."
  - MARCUS: "Yeah. Rang means that."
  - *(sets up bible §8: Noah went west; ties to the later backpack and farm road)* **[P]**
- **Why two hours:** the footfalls circle the block (`veil_rumble`, `colossus_step` low through the floor); every attempt to look outside is answered by light sweeping the windows (CURRENT `_shop_seated_talk` holds the group away from windows).
- **What changes enough to risk Main Street (NEW 03.04.2, `p3_radio_clear`):** the shop's static radio clears for twenty seconds. A recorded voice reads a **loop**: "...generator at the supermarket. Lights on. Supermarket. Generator..." and cuts. Eddie: "That's a recording. That's somebody's recording." MARCUS: "A recording means somebody set it up on purpose." (Not a lure: it repeats a physical fact the player can check - across the street the lights are on, `p3_lights`.) The tell the player learns here: **real = loops a verifiable thing; lure = answers you** (pays off in 07.x).
- **Camera/audio:** CURRENT `_shop_seated_talk`. Practical light only. **Exit:** half-lit route to the door, `p3_in_shop`.

---

## Chapter 4 - The Last Open Door  *(world.gd)*

### 04.01 Shop exit and Main Street  *(CURRENT)*
`_p3_escape_tentacle` (flag `_p3_shop_talked`, outdoors): the exit lash, `p3_hit` ("Agh! Get away from me!"), then the sprint (`p3_eddie_run` "RUN! The supermarket - go, go!"). Eddie and Marcus run with the player (`companion_at_market_doors`). **Intent:** the trio crosses the street physically (bible §10, all 14 steps are code-verified in `_p3_flee_together`).

### 04.02 The last open door  *(CURRENT)*
`_p3_market_arrival` (polled, `p3_fled_together and not p3_in_market and _near_market_entrance()`): doors are dead; Eddie forces them (`door_open +2 dB`); `_market_blackout`; `p3_market` ("Looks like we weren't the first ones here." / "Water, medicine, canned food... most of it's gone." / "Enough for now. Not enough to stay here forever."); `p3_secure_ask` ("The doors - we have to get them shut. Now!"); `p3_doors`. **Skip:** hold. **Already-inside path:** `_p3_reach_market(from_scene=true)`.
- **Sightlines/exits/communal stock (Lock-In needs this established):** *NEW 04.02.1*, on entering the dark store the three sweep their lights once, so the player sees the *exits* they will manage: the front doors (dead), the loading door at the rear (open 0.9 m), the staff door to the back corridor, the roof hatch's ladder (no use yet). Marcus names the stock: `p3_market_stock`: MARCUS: "Back wall: cans, mostly. Water's in the cooler by the office." EDDIE: "Office has a door that locks, and, I want to point out, a couch." *[P]*

---

## Chapter 5 - Lock-In  *(phase4.gd)*

### 05.01 Lock-In work  *(CURRENT)*
`p3_doors_shut` -> flashlight (`p4_flashlight`), batteries, breaker (`_throw_breaker`), the loading door (`_pull_loading`, and the garage tentacle `garage_tentacle.gd`, flag `p4_garage_done`), rear exit (`_close_back`), pallets (`_push_pallet`), bedding (`_make_bed`, flattened cardboard + blanket and pillow), supplies (`_open_supplies`: **real** food, water, batteries, bedding, nothing invented). **Sleep** (`_on_slept`, `p4_slept`) advances to the morning only after the milestones.

### 05.02 The accept/refuse decision  *(CURRENT choice; REVISED only to make the value conflict legible)*
- **Entry:** talk to Marcus (`phase4.gd:_talk` -> `_on_choices`, dialogue id `p4_talk`, once: `p4_choice_made`). The two real choices **[V `dialogue.json` p4_talk, `phase4.gd:_run_threat`]**:
  - **"We should wait until morning."** -> flag `p4_choice_wait` (= **REFUSE the search**). Nobody goes out; **no creature appears in the evening**; the only event is the **night banging at the rear door** during sleep (`phase4.gd:_on_slept` -> `_night_banging`, flag `p4_night_banging`). Lines CURRENT `p4_choice_wait`.
  - **"We can't just leave Noah out there."** -> flag `p4_choice_noah` (= **ACCEPT the search**). The outside scene starts at once: the protagonist and Marcus step out, the **Skitter** charges, they retreat, the doors shut, the impact lands after (`_hound_charge`, `p4_hound_charged`). Lines CURRENT `p4_choice_noah` (Eddie: "Nobody's leaving him. But nobody's walking into that blind, either.").
  - (A legacy third path - neither flag set - plays scrape / shape behind the glass / `_door_strike`; only reachable from old saves or fixtures. Keep; do not advertise.)
- **The value conflict, in words (subtext only; labels stay CURRENT):** wait = *we keep the people we have alive*; noah = *we owe it to the missing.* Trust: `marcus_trust()` counts `p4_choice_noah` +1 (`chapter9.gd:marcus_trust`), so accepting is trusted by Marcus; refusing earns Eddie's relief (dialogue only). **Neither closes the story**: Marcus is not lost by refusing (he is only quieter), and the same morning follows.
- **Paired scenes expose different information:**
  - **05.02a Accept** (`_hound_charge`, historical name): the player learns **they hunt from rooftops and are fast**, and that the doors are the line. **NEW (P)** `p4_marcus_roof`: on the roof across the street Marcus sees a small shape under a tarp for a second: MARCUS: "That's - " (it is a tarp snapping in wind) MARCUS: "...No." Subtext: hope has started to hurt. Pays off in 08.x (the real clue has a physical corroboration; this does not).
  - **05.02b Refuse** (`_night_banging`, in the night after sleep): sound only - the weak seam in the rear door and a long gap in the banging. The player learns **the rear door is the weak point**; pays off in Ch9 (`chapter8.gd` three-board repair, three impacts). If the player skips both talks... the choice cannot be skipped: the sleep prompt requires `p4_talk_done`.
- **End of Act I (both branches):** `p4_slept`, night report (`record_night`), morning; `c5_started` begins displayed Ch6.

### Act I state at exit (for the contract)
`p3_doors_shut`, `p4_slept`, one of `p4_choice_wait` / `p4_choice_noah`, supplies in `Game.inventory` + communal stock, `p4_garage_done`, optional `lt_frank_done`, `egg_roof_skitter_seen` (optional). Eddie and Marcus alive and present. **Cannot be invalid:** both Lock-In choices lead to the same morning.
