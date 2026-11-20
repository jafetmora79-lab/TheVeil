# B2. Act II - The Missing (displayed chapters 6-8)

Conventions as in B1. Internal ids in brackets: displayed 6 = `chapter5.gd` / `c5_*`, displayed 7 = `chapter6.gd` / `c6_*`, displayed 8 = `chapter7.gd` / `c7_*`. CURRENT lines are in `appendix/current_dialogue_06..08*.md`.

**Act II intent:** the group stops being three people in a shop and becomes a small community with a *method*. Eddie and the protagonist learn what a supply trip costs; the group learns the difference between a **voice that answers** and **evidence that corroborates**.

---

## Chapter 6 - The First Search  *(chapter5.gd)*

### 06.01 First expedition  *(CURRENT, with 3 REVISED/NEW lines)*
- **Entry:** `p4_slept` or `c5_started`; morning in the supermarket. **Roster:** protagonist, Eddie, Marcus (alive at this point in every playthrough).
- **Intent:** an *understandable* first trip: the stock is thin (`c5_eddie_morning`: "I checked what we have left. It's not great."), so the nearest houses are searched. HOUSE_04 (cottage behind the market, ~40 m) first; HOUSE_05 beside it.
- **Interaction order (CURRENT, `chapter5.gd`):** talk to Eddie (`c5_eddie_morning`) + Marcus (`c5_marcus_morning`) -> `c5_talked_both` -> check supplies (`c5_supplies_checked`) -> confirm at the doors (`_head_out`, Eddie follows, `VeilCompanionFollow`) -> search kitchen / nightstand / bathroom cabinet (real pickups, `c5_found_supplies`) -> radio (`c5_radio_broadcast`, `c5_radio_eddie`) -> optional survivor in HOUSE_05 (`c5_survivor`, three choices) -> back in -> `c5_report`.
- **Radio, reworded to be a *tell* not a clue (REVISED `c5_radio_broadcast_2`, replaces the last two radio lines only):** RADIO: "...drivers are advised to use caution in areas of reduced visibility..." / RADIO *(same sentence again, identical, to the syllable)*: "...drivers are advised to use caution in areas of reduced visibility..." / *[STATIC]*. EDDIE: "It said that already. Word for word." PROTAGONIST: "Yeah." Subtext: a **loop** can be real (a recording) but never *answers*. This is the same rule as the shop radio in 03.04.2 and pays off in 07.02.
- **Temporary survivor (optional, HOUSE_05).** Three real branches **[V `dialogue.json` c5_survivor]**:
  - `c5_survivor_helped` ("We have a place nearby. It's safer than staying here alone.") -> survivor follows (`c5_survivor_following`), reported (`c5_report_survivor`: MARCUS: "You brought someone back." / "Then we'll make room.").
  - `c5_survivor_informed` ("There's a supermarket nearby. We've secured the entrances.") -> arrives later at night.
  - `c5_survivor_left` ("We have to go.") -> the survivor still turns up later (see Chapter 9: "a stranger who came in the night").
  - **How this affects later recognition (NEW, 3 lines, Chapter 9 scene 09.02):** if `helped`, Eddie knows him: "Gary, from the cottage. Gary, get *down*." If `informed`, Marcus recognises him by his coat: "You're the one from the cottage. You came." If `left`, the group has never seen him; Eddie: "I don't - who are you?" and the survivor says "I followed your lights." The scripted death is the same in all three; only the *grief* and the recognition change. **[P]** (names are provisional: "Gary" only if the owner approves; otherwise Eddie says "the guy from the cottage").
- **Scare setup/payoff:** none lethal; the first exposure to the street's quiet (`c5_street`: EDDIE: "Yesterday people were arguing over parking spaces. Now look at it.").
- **Exit state:** `c5_report` done, `c5_rested` after sleep -> displayed Ch7. Flags: `c5_survivor_*`, supplies in `Game.inventory`. **Missing-speaker rule:** Marcus and Eddie both present; no `_alt` needed.

---

## Chapter 7 - Voices in the Mist  *(chapter6.gd)*

### 07.01 Marcus heard a voice; Ruth and Sarah  *(CURRENT + REVISED)*
- **Entry:** `c5_rested` -> `ch6_started`. `c6_marcus` (a voice calling for help; it *stopped*), `c6_eddie` ("People usually call for help when something's wrong."). Eddie follows (`ch6_eddie_following`). **Roster:** protagonist, Eddie (Marcus stays: `c6_marcus`: "Be careful.").
- **The bungalow, HOUSE_06** two lots past the cottage. `c6_ruth_sarah` (CURRENT; Ruth is armed and wary - `Ruth: "That's what worries me."`; Sarah is the peacemaker: "Ruth, they're just people."). Three choices (CURRENT): **invite** / **directions** / **leave**.
- **Coherence across invite and non-invite (REVISED, because code (`chapter8.gd:178`) has all three paths end with Ruth and Sarah in the market by displayed Ch9):**
  - **invite** -> they follow (`ruth_sarah = "following"`), reaching the market with the group.
  - **directions** -> NEW `c6_rs_directions_2` (Ruth, as the protagonist walks away): RUTH: "Main road, past the cottage, the doors are shut but there's a side panel." SARAH: "Ruth." RUTH: "I'm *telling* them it's a trap-free instruction, Sarah. For the record." (humor from Ruth's dryness, not Eddie.) -> **that night** they do come (`ruth_sarah_arrived`), written as NEW scene **09.00** at the start of displayed Ch9 (below).
  - **leave** -> NEW `c6_rs_leave_2`: SARAH *(calling softly)*: "If it gets worse... we'll find you." RUTH: "No we won't." SARAH: "We might." -> they too arrive that night, **hurt by the east-route Hound** (this is why Sarah arrives with a wound in the leave/directions variants and why `chapter8.gd` makes her the injured one **[V `chapter8.gd:_sarah_bite`]**).
  - **Plans and agency (the owner asked):** Ruth is a plans person: she carries a **hand-drawn route** of the east-road drainage line behind the cottages (a real, quiet path); Sarah is the one who reads people (she is the one who says "don't" at the voice, below).

### 07.02 The lure voice  *(CURRENT `c6_voice`, `c6_voice_eddie`, with REVISED explanation)*
- **Where/when:** deeper in the houses after the bungalow; `ch6_ruth_sarah_met` -> voice heard. `c6_voice`: DISTANT VOICE: "Hello?" / "Can somebody help me?" / "Please..." (source never shown).
- **Rule given to the player (NEW `c6_voice_tell`, plays after `c6_voice_eddie`, only if Sarah/Ruth present or as Eddie otherwise):**
  - SARAH *(or `@1` in `_alt`)*: "It said 'somebody'. Everyone says somebody. Real people say a name, or *where they are*."
  - EDDIE: "It also stopped every time we got closer."
  - Subtext: the lure never gives a location or a name and it never answers a question; real evidence (a radio loop, a bag, a note) does give a *checkable physical detail*. 
- **Choices (CURRENT):** `ch6_voice_choice_investigate` ("We should check.") / `ch6_voice_choice_retreat` ("We're going back.").
- **Why either Hound route intersects the player (NEW explanation, written as one line each; the code spawns the Hound on both):**
  - **Investigate:** the voice is bait; the Hound is *where the voice stops* (the back alley). `c6_hound_seen` (CURRENT). NEW `c6_hound_why_a` (EDDIE, after the chase): "It stopped *because* it got what it wanted. Us."
  - **Retreat:** the Hound is on the east route home because it had already been circling the market's noise (the generator hum, the radio the protagonist used in 06.01). NEW `c6_hound_why_b` (RUTH, if present, else `@1`): "It's been walking this side of town since dusk. We just crossed its line."
  - Both: avoid or escape (`VeilHoundAI`, no kill needed). **Control:** player control; flags `ch6_voice_choice_*`, `ch6_hound_encounter_started`.
- **Camera/audio:** `_growl_wave`, `_bark_wave`, `_breath_wave`; the voice is restrained, off-axis, never lip-synced. **Exit:** `c6_return` ("I'm never complaining about a boring day again." / "You said that yesterday." / "And I meant it yesterday too.").

### 07.03 Report at the market  *(CURRENT)*
`c6_report_a` + one of `c6_report_invite / _directions / _leave`, `c6_report_b`. **Exit:** `ch6_rested` after sleep -> displayed Ch8.

---

## Chapter 8 - A Trace of Noah  *(chapter7.gd)*

Chapter 8 is the **first true Noah lead**. **No creature reveals** in this stretch except the car's Skitters (a physical obstacle, not a scare).

### 08.01 Backpack and trust  *(CURRENT with REVISED lines)*
- **Entry:** `ch6_rested` -> `ch7_started`; `c7_marcus` (someone told Marcus about a car near the old service road with a kid's backpack), `c7_eddie` ("He's convinced because he needs it to be."). **Roster:** protagonist, Marcus (walks with the player: `VeilCompanionFollow`), Eddie stays.
- **Route:** out through the real front doors (`market/doors_shut`), west on the main road to the **abandoned sedan where the asphalt ends**, two Skitters around the car (`c7_skitters_intro`: "Something loud. Away from the car." - the noise distraction, `_set_off_alarm`), the backpack (`c7_backpack`).
- **The real-vs-lure corroboration (CURRENT + NEW detail, the part that makes this evidence credible):**
  - CURRENT `c7_backpack`: MARCUS: "That's Noah's." / "I bought it for him." / "He complained about the color for a week."
  - NEW physical detail the player can *verify* (REVISED item text `noahs_backpack`): inside, a **school-bus keychain with one eye missing** (Marcus: "He picked the eye off in third grade.") and the note. This is the *keepsake Marcus recognised at once* already in the item description **[V `items.json` noahs_backpack]**; the new line is `c7_keepsake`: MARCUS *(turning it over)*: "The eye. He picked the eye off in third grade. Nobody else would have kept it."
  - This is the tell that distinguishes **evidence** from a **lure** (07.02): a lure can say "Dad"; it cannot know which eye.
- **The note (CURRENT `c7_note` + item `noahs_note`; exact item text [V `items.json`]):** *"I couldn't stay there. / A man said he knew somewhere safer, outside town. / He said there's a house near the farms. / I'm going with him. - Noah"*. Dialogue CURRENT: MARCUS: "He wrote this." / PROTAGONIST: "Looks like he got out of town." / MARCUS: "Someone helped him." / "But he was alive. After all of this started, he was alive."
  - **Plausibly with help** is already stated by Noah himself ("A man said he knew somewhere safer"). **Noah moved west after the mist** follows from the car's position west of town and from the note being left in it. **[P] reading of the note:** he left the bag and note in the abandoned car **on purpose, so his father could find them** (the helper's rule "leave a sign", see A2 / the farmer's journal). One optional line `c7_note_sign` (EDDIE): "He left it on purpose. Kid's smarter than all of us." MARCUS: "He's thirteen. He's always been smarter than me."
- **Trust/caution choice (CURRENT, `c7_road`):** "We'll find him. But we need to prepare first." (`marcus_trust_search`) / "We can't keep going without supplies and a plan." (`marcus_cautious_search`).
  - **REVISED writing so Marcus can take caution as rejection OR as a plan, depending on tone:** both answers already exist (`c7_road_promise` / `c7_road_safety`). NEW second beat only for the cautious branch: `c7_road_safety_2` MARCUS *(after "Fine.")*: "...Give me the list. What do you need, to go?" PROTAGONIST: "Water, batteries, a route that isn't the road." MARCUS: "...Okay. That's a plan. I can work with a plan." *The caution is accepted as method only if the player names concrete items; trust effect unchanged (flag only).* 
- **Quiet return** (CURRENT `_returned`, no creatures) and **Eddie debrief** `c7_report` ("We need to find those farms." / "We will. But not tonight.").
- **End of Act II - shared decision about when there is enough information to move (NEW scene 08.02 `c7_enough`, before sleep; all four present):**
  - **EDDIE:** "So we know three things. He's alive. He had help. West."
  - **RUTH:** "Farms are west. That's a lot of fields."
  - **SARAH:** "And a lot of nights."
  - **MARCUS:** "I don't need more. I need to go."
  - **PROTAGONIST:** "We go when the supplies and the doors say we can. Not when we're scared."
  - **RUTH:** "That's a rule, then. Supplies, doors, then we go."
  - **EDDIE:** "I'm writing that down. In my head. My head's very full."
  - *[P]* Gives the player a *stated criterion*: the next chapters' preconditions (Ch9 repair + power, Ch10 supplies, then leave) are the group's own rule, not an arbitrary gate.
- **Exit:** `ch7_rested` after sleep -> displayed Ch9. Flags: `ch7_backpack_found`, `ch7_note_read`, `ch7_vehicle_reached`, `marcus_trust_search` / `marcus_cautious_search`.

### Scene 09.00 (placed at the start of displayed Ch9) - Night arrivals  *(NEW, for the directions/leave variants)*
- **Entry:** `ch7_started` + `c6.ruth_sarah` in {directions, leave}. Location: market front doors, ~2 AM. **Roster:** all; Sarah wounded (leave) or tired (directions).
- Action: knocks on the glass; Eddie: "Nobody knocks. Things don't knock." Marcus opens the side panel. Ruth supports Sarah.
- `c8_night_arrive` RUTH: "You said the doors were shut. They were." / SARAH *(weak)*: "We saw your lights." / MARCUS: "Get them inside."
- Why they came: the east-route Hound found their lot (leave variant), or the loop on the radio stopped making sense (directions variant: Ruth heard the same sentence twice, as in 06.01).
- Missing speaker: none. Exit: the injured-Sarah variant matches `chapter8.gd:_sarah_bite` in the following chapter.

---

## Act II dependency summary

`p4_slept` -> `c5_started` (6) -> `c5_rested` -> `ch6_started` (7) -> `ch6_rested` -> `ch7_started` (8) -> `ch7_rested` -> `ch8_started` (9). Optional: HOUSE_05 survivor (`c5_survivor_*`), `egg_roof_skitter_seen`, `lt_*`. Cannot be skipped: backpack + note (`ch7_backpack_found`, `ch7_note_read`) - fallback: if a player never reads the note in the inventory screen, Marcus reads it aloud on the quiet return (`c7_note` replays once from `_after_note`).
