# B3. Act III - No Place Is Safe (displayed chapters 9-11)

Internal: displayed 9 = `chapter8.gd` / `c8_*` / `ch8_*`; displayed 10 = `chapter9.gd` / `c9_*` / `ch9_*`; displayed 11 = `chapter10.gd` / `c10_*` / `ch10_*`. CURRENT lines: `appendix/current_dialogue_09..11*.md`. Conventions as in B1.

**Act III intent:** teach how fast an imperfect barrier fails (9), spend the shelter and possibly Marcus (10), and make *leaving* a travel problem with real costs (11). Never kill Eddie, Ruth or Sarah (code behaviour, kept); only Marcus can be lost, plus the scripted temporary survivor.

---

## Chapter 9 - Something at the Doors  *(chapter8.gd)*

### 09.00 Night arrivals - see B2 (NEW). Ruth and Sarah are in the market from here on in every variant.

### 09.01 The damaged barricade and the three-board repair  *(CURRENT)*
- **Entry:** `ch7_rested` -> `ch8_started`. `c8_eddie` ("Something hitting the back door." / "this time, it didn't stop after a few knocks."). **Roster:** protagonist, Eddie, Marcus, Ruth, Sarah (+ temp survivor present, see 09.02).
- **Interaction order (CURRENT, in this order):** inspect barricade (`c8_marcus_damage`: "The backup power's barely holding.") -> collect boards (back corridor), duct tape (service counter), hammer (storage, on the loading-bay pallets; real items `duct_tape`, `hammer`) -> first-person repair (pallets back, **three boards** across the door; `c8_repaired`: MARCUS: "That should hold." / "For how long?" / "I'd rather not find out.") -> **the lights fail** (hum, flicker, dark; `c8_power_fail`: RUTH: "We can't stay here in complete darkness.") -> the maintenance panel: reseat the cable (`c8_power_back`) -> partial power.
- **Why this attack is *smaller* than the later fall:** one entrance (the rear door), one creature, a barrier that **mostly** holds; the group is rested, stocked and *together*. The scare is mechanical (three impacts from vibration to visible deformation) not spatial.
- **Fallback if materials are missed:** `_materials_count` shows the shortage; an alternate `c8_missing_material` (MARCUS: "We're short. Try the back corridor again, it's the one place nobody searched.") plays once; the repair is **never** hard-gated on a material that is not in the store.

### 09.02 The attack: temporary survivor and Sarah  *(CURRENT + REVISED recognition)*
- `c8_impact` (SARAH: "What was that?" / MARCUS: "Everybody away from the door." / EDDIE: "Please tell me that's the wind."). Three rear impacts, the barricade gives way (`_give_way`), a Hound comes through (`_hound_burst`).
- **The temporary survivor is caught and dies once** (`_kill_temp`, `ch8_temp_survivor_died`). **Recognition lines by Chapter 6 branch (NEW; all three variants end in the same death):** see B2 06.01. Extra beat in all three, after the death, `c8_temp_mourn` (nobody dies off-camera without a witness): EDDIE *(quiet)*: "I didn't even get his name right." RUTH: "Nobody did. Don't." *(Eddie's humor goes silent here - a deliberate beat.)*
- **Sarah is hurt** (`_sarah_bite`, `c8_sarah_bitten`, `c8_rescue_go/won/lost`).
- **Push a pallet stack across the doorway (no combat; `_push_secure`)** -> the Hound withdraws as the pallet crosses the threshold (CURRENT `c8_rescue_won`: "Get back! GET BACK!" / "The pallets - block the door!").
- **Sarah's medicine choice (CURRENT, `_help_sarah`, `_medical_available`):** treated (`c8_treated`: SARAH: "I think... I think I'm okay." / RUTH: "You got to her in time.") or untreated (`c8_untreated`: RUTH: "We need medicine." / "Not enough."). Medicine is a **carried painkiller pack or the shelter's medical stock, used exactly once**; none = she stays seriously hurt, never dies here.
  - **Effect on later behaviour (specified, because only dialogue/health text exists today):** Treated -> Sarah's health `injured`, she walks at 85% of group speed in 11; untreated -> `serious`, she walks at 65% and the group's rest stop (11) is *forced to be requested* by Ruth. `survivors.gd:set_health` is the single place (kept).
- **Aftermath/decision `c8_aftermath`:** EDDIE: "We can't keep doing this." ... MARCUS: "Noah's note mentioned the farms." ... "We make sure these doors hold one more night." **Exit:** `ch8_rested`.

---

## Chapter 10 - The Fall of the Supermarket  *(chapter9.gd)*

### 10.00 Why the market is viable after the first attack - and lost after the second  *(NEW narrative contract)*
- **Viable after the first attack (09.x):** the breach was a *door*, one Hound, and the group learned the fix; stock for a few more days (`ch8` end state).
- **Lost after the second (10.x):** this time the Hound(s) hit **two** entrances (rear + front), the power is not recoverable (the same breaker, damaged a second time), the fog thickens enough that the front glass shows a shape (the fall's warning), and the repaired barricade has no pallets left to spare. The shelter is lost *because the same fix cannot be used twice*, not because the player did something wrong.

### 10.01 The decision talk, preparation, the warning  *(CURRENT)*
- `c9_decision` (MARCUS: "We need to make a decision." ... "About surviving."). **Prep (order free):** medical stock (`_take_medical`), food and water (`_take_food_water`, real units from the communal stock, **nothing that is not there**), flashlight check, word with Eddie / Ruth / Sarah (`c9_prep_*`, with `_stable` / `_serious` variants for Sarah's health: RUTH: "She can't go far like this. We'll carry her if we have to." / SARAH: "Don't slow down for me." / PROTAGONIST: "We're not leaving anyone.").
- **The warning (`_run_warning`, first person):** distant impacts, scraping at the back, flicker, `c9_warning` (SARAH: "There's something outside." / "Everywhere." / MARCUS: "Get away from the windows.").
- **Missing-speaker rule:** every `c9_prep_*` has `_alt` coverage via `@1` in the Ruth/Sarah variants; Marcus lines only exist if Marcus lives (`marcus_lost` flag not yet possible at this point - he is alive here in every playthrough).

### 10.02 The fall and the escape  *(CURRENT)*
Doorway barricade gives, a Hound forces its way in, another prowls at the front doors (`_run_fall`, `_prowl`, `_front_threat`). **ESCAPE:** the group follows the player east through the store, the staff door, the back corridor, out the rear (`c9_marcus_order`: MARCUS: "Out the back! Through the staff door - move!"; `c9_no_car`: EDDIE: "Not the car - it's out front, right where they're coming in. Out the back. On foot.").

### 10.03 Marcus pinned  *(CURRENT mechanics, NEW telegraph, proposed timing)*
- **Telegraph (so the player knows *who, where, and how long* before the timer starts) - NEW `c9_pin_telegraph`:** as the group funnels through the staff door the player sees Marcus go last, turn back for **Sarah's dropped medicine bag** (the shelter's first-aid stock; he will not leave the one thing that keeps her walking), and the second Hound enters the corridor *behind him*. Sound first: claws on tile, then Eddie: "MARCUS! Behind you!" Then the pin. The player has **two seconds of control** to see the corridor before the countdown begins (`_pin_marcus` -> `_pin_countdown`).
- **Timing - decision (Audit #10):** current code `PIN_SECONDS := 10.0` for everyone and `marcus_trust()` (0..2) only *recorded*. **Proposed scaling (NEW):** trust 0 -> 7 s, trust 1 -> 10 s, trust 2 -> 13 s. `marcus_trust()` counts `p4_choice_noah` and `marcus_trust_search` (**[V]**). *Reflects the relationship in how long he holds on; the player always has a real chance.* Each second shown on the existing countdown; Marcus's line changes with the window: low `c9_pin_low` MARCUS *(gasping)*: "Hurry - I can't - " ; high `c9_pin_high` MARCUS: "I'm okay. Take your time. Do it right."
- **Outcome A: pulled free** -> `c9_marcus_saved` (MARCUS: "I'm okay. Go - go!"), `c9_road_alive` ("Noah's out there. Past the farms. We keep going." / "Together.").
- **Outcome B: lost** (never random): a cut to black while he is dragged back into the corridor (`_marcus_lost`, flag `ch9_marcus_lost`), `c9_marcus_lost` (EDDIE: "Marcus!"), `c9_outside_lost` (RUTH: "Not Marcus." / EDDIE: "He was right behind us..."). **No surprise survivor:** Marcus does not return in any later chapter. The **one object that carries him forward is Noah's backpack, which the player already holds as a key item** (`noahs_backpack`, from 08.01) - nothing new is invented. In the lost variant `[P] c9_backpack_kept` plays once on the road, PROTAGONIST *(quietly, holding it)*: "I'm giving it back to him. Myself." It is handed to Noah in 13.0.
- **Look back and roll call (`_lookback`, `roster()`):** CURRENT `c9_outside_a/_b` and `c9_outside_alive` ("All of us. Barely.") / `c9_outside_lost`.

### 10.04 The rendezvous - a practical plan from Eddie and Ruth  *(CURRENT place + NEW plan lines)*
- Destination: Ruth and Sarah's old front yard (Chapter 8's house, **HOUSE_06**). **Why there (NEW `c9_rv_plan`, spoken during the walk, `_wait_lines`):**
  - RUTH: "My house has a drainage ditch behind the fence. Nothing can follow us down it, and it comes out by the road to the lots."
  - EDDIE: "Pro: ditch. Con: ditch."
  - RUTH: "The con is you."
  - EDDIE: "Fair."
  - Subtext: Ruth has the **plan** (agency); Eddie breaks the tension.
- **Exit:** `ch9_rendezvous_reached`, `chapter_9_complete`; the supermarket is **lost as a shelter**; `chapter10_start` checkpoint.

---

## Chapter 11 - No Safe Road  *(chapter10.gd)*

### 11.01 The plan and the sedan  *(CURRENT)*
`c10_plan_alive` / `c10_plan_lost` (Marcus's line only if alive; the lost variant says "Noah's note pointed that way. We follow it - for Marcus."). The group follows the player along the street, down the open lot, onto the main road (`group()`).
- **One travel problem (NEW narrative glue, so sedan + roadblock + Hound + detour read as one thing):** the main road is the only way west and the town's noise funnels everything onto it. **The abandoned sedan** (-28, 3.9) is the first thing on it: empty gauge (`c10_car_fuel`: "Tank's empty. It isn't going anywhere."), a battery in the glove compartment (`car_battery`), a bottle of water in the trunk (`c10_car`: EDDIE: "Please tell me it starts." / "Not happening."). **The roadblock** at x -46 (`c10_roadblock`: "The road's blocked. We'll have to find a way around.") is the **same reason** the Hound is there: it is working the road end-to-end looking for the noise; the roadblock's wedged van and pickup make the road a dead end, so the *side route* (north through the gap at x -28, west behind the building to the chain-link gate, back to the road) is the only quiet line - and the Hound's silhouette crosses *behind the buildings* on that same line (`c10_followed`: SARAH: "Did you see that?" / "Keep walking." / RUTH: "Nobody stop."). **First person, no fight.**
- **Optional-car status (Audit #6):** this sedan is *not* the player's repaired sedan; the player's own sedan (a different car) is at the market (`world.sedan`). No `car_quest.gd` repair makes this one run.

### 11.02 Sarah can't go on  *(CURRENT choice; REVISED aftermaths)*
`c10_sarah_stable` / `c10_sarah_serious` (RUTH: "Sarah needs to stop." / SARAH: "I'm fine. I'm just... so tired." or "It's the wound. It's worse when I walk."). Choice (CURRENT): **"We stop. She needs a rest."** (`ch10_choice_help`) / **"We can't stop here. Keep moving."** (`ch10_choice_push`). Never a death.
- **Help (stop):** an hour passes, a water or food item is used (or **exposure is recorded** if there is none - the *no softlock* rule). NEW aftermath `c10_help_after`: SARAH: "Thank you." RUTH *(to the protagonist, low, not to Sarah)*: "I won't forget that. Don't make me say it twice." -> Ruth's trust +; logistic cost: one water item, 1 hour; **emotional**: Sarah is rested and quietly steadier through Chapters 12-14 (`survivors.gd:set_health` -> `recovering`).
- **Push (keep moving):** NEW `c10_push_after`: SARAH *(smaller)*: "I can keep going." RUTH: "...Slowly, then. Stay close to me." -> logistic cost: none; **emotional**: Ruth stops looking at the protagonist when she talks and Sarah stays `exhausted` (the group walks slower, one extra Hound beat later at the fence is faster - see 15.x); trust Ruth -.
- **Never silent**: both choices leave a line in the morning-at-the-mill talk (12.01 `c11_morning_*`: Ruth's attitude).

### 11.03 The mill-worker house, rest, the window  *(CURRENT + NEW plausibility)*
`c10_outskirts` (EDDIE: "I think we're actually getting out." / "Don't say that yet."), `c10_house_clear` ("Nobody here. Nothing moving."), `c10_refuge_alive/_lost` (RUTH: "We can stay here for a few hours." / EDDIE: "A few hours sounds amazing."). Rest a few hours (`_rest`), the window (countryside beyond the fog, a distant sound: `_play_call`).
- **Why the mill house is a plausible *temporary* refuge (NEW narrative line `c10_refuge_why`, RUTH inspecting):** "Fieldstone to the sill, one road approach, and the back is open grass - nothing can come at us from three sides without us hearing it cross the gravel." EDDIE: "Great. A fortress with a bad-news back door." Not permanent: no well, no generator, one bed, and the fog is visible from the window.
- **Exit:** `ch10_refuge_rested`, `chapter_10_complete`, checkpoint `chapter11_*`. Survivor state carried: `alive/present`, health, trust.

---

## Act III state at exit (for C)
`chapter_10_complete`; `ch9_marcus_lost` or alive; Sarah health in {injured, serious, recovering, healthy}; `ch10_choice_help|push`; supplies/inventory; Eddie, Ruth, Sarah present. Marcus **cannot be present and lost** (mutually exclusive). Both pin outcomes lead to the same rendezvous.
