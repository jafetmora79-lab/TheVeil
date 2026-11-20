# C. Implementation contract

For the owner's approval, not wired. **[V]** verified in code, **[P]** proposed. `data/flags_current.json` is the **generated** dictionary of every literal flag in `game/**/*.gd` (307 flags, with the files that set and read each) built by `tools/build_flag_dictionary.py`; this document explains and extends it. Chapter-select fixtures (`game/chapters/setups/dev_chapterN.gd`) are test scaffolding and are **not** campaign history (CLAUDE.md); campaign QA uses real saves.

## C1. Chapter dependency graph (predecessor flags, **[V]** from `game/data/chapters.json` and the chapter headers)

```
intro_seen (new game) ─> [1] wake / keys ─> has_keys, left_house, entered_car
 ─> [2] arrival_shot ─> groceries_done + game_bought (either order)
 ─> [3] p3_mist ─> p3_stepped_out ─> (Frank: lt_frank_done) ─> p3_back_inside ─> p3_in_shop ─> (2 HOURS LATER)
 ─> [4] p3_fled_together ─> p3_in_market ─> p3_doors_shut
 ─> [5] p4_choice_made (wait | noah) ─> p4_threat_done ─> p4_slept
 ─> [6] c5_started ─> c5_talked_both ─> c5_supplies_checked ─> c5_report ─> c5_rested
 ─> [7] ch6_started ─> ch6_ruth_sarah_met ─> voice choice ─> ch6_rested
 ─> [8] ch7_started ─> ch7_backpack_found ─> ch7_note_read ─> marcus_trust_search|marcus_cautious_search ─> ch7_rested
 ─> [9] ch8_started ─> ch8_temp_survivor_died ─> ch8_entrance_secured ─> ch8_rested
 ─> [10] ch9_started ─> ch9_escaped ─> (ch9_marcus_lost | saved) ─> ch9_rendezvous_reached ─> chapter_9_complete
 ─> [11] ch10_started ─> ch10_choice_help|push ─> ch10_refuge_rested ─> chapter_10_complete
 ─> [12] ch11_started ─> noah_clue_campsite ─> noah_clue_farmhouse ─> ch11_light_seen ─> chapter_11_complete
 ─> **[13.0] ch12_rescue_started ─> ch12_noah_found ─> ch12_noah_home** (NEW)
 ─> [13] ch12_started ─> station ─> chapter_12_complete
 ─> [14] ch13_started ─> chapter_13_complete
 ─> [15] ch14_started ─> ch14_rescue ... ch14_separation ─> chapter_14_complete
 ─> [16] ch15_started ─> ch15_decided ─> ch15_choice_a|b|c ─> ch15_ended ─> chapter_15_complete
```

Sleep only *starts* the next chapter after the previous milestone flag is set (bible: "do not auto-advance on sleep" **[V** `phase4.gd:_on_slept`**]**). The new 13.0 does **not** start on sleep (Audit #7).

## C2. Flag dictionary changes

### New flags **[P]** (all booleans unless noted; default false; persisted in `Game.flags`)
| Key | Set by | Read by | Notes |
|---|---|---|---|
| `ch11_ribbon_taken` | `chapter11.gd:_escape_tick` pass-by | `chapter12.gd:_opening` | Eddie pockets the ribbon; fallback prop at the gate if false |
| `ch12_rescue_started` | 13.0a | 13.0b-d, objectives | |
| `ch12_ribbon_read` | inspect of `noahs_ribbon` | 13.0a objective | |
| `ch12_house19_entered` | player reaches HOUSE_19 porch | 13.0d | |
| `ch12_noah_found` | Noah opens the door | everything below | **repeat-safe milestone**, writes `chapter12_noah` checkpoint |
| `ch12_noah_home` | arrival at the mill house | 13.1 and Ch15/16 | |
| `ch12_journal_read` | read `farmers_journal` | 13.1 fallback line | optional |
| `ch12_below_explained` | 13.1 | objective text | one-time |
| `noah_rescued` | alias of `ch12_noah_found` for **old save** migration | epilogue | see C5 |
| `ch14_noah_partner` | (string in `st()`), set at 15.02 | 15.06 | `Ruth`/`Marcus`/`Sarah` |

### World state **[P]** (inside `Game.world_state`, written with the chapter state)
`world_state["noah"] = {"status": "unknown"|"found"|"home", "role": "signaller", "partner": "Ruth", "home_guard": ["Sarah"], "journal": false}`.

### Old -> new key map (nothing is renamed; the map says which **existing** key an **old save** answers to)
| Old key / state | Meaning | New key it implies |
|---|---|---|
| `chapter_11_complete` | farms done | `ch12_rescue_started` becomes *available* (not set) |
| `chapter_12_started` (flag `ch12_started`) | station arc begun | `noah_rescued` stays **false** for old saves |
| `noah_clue_campsite`, `noah_clue_farmhouse` | clues read | unchanged; feed 13.0 only as flavour |
| `ch11_light_seen` | HOUSE_19 light seen | prerequisite for 13.0a (the promise) |
| `ch9_marcus_lost` | Marcus lost | selects 13.0 variant (`c12_ribbon_lost`, `c12_bereave`) |

## C3. Survivor availability model (separate from health, trust, whereabouts)

Today **[V]**: `survivors.gd` owns `trust` (0-100), `morale`, `health` (healthy/injured/serious/recovering) for NAMES = Eddie, Marcus, Ruth, Sarah; `chapter9.gd:roster()` returns Eddie/Ruth/Sarah (+ Marcus unless `ch9_marcus_lost`); `chapter10.gd:group()`; `chapter14.gd:present()` removes `st().missing`; Frank and the temp survivor live elsewhere (`living_town.gd`, `chapter8.gd`). Four different questions are answered in four places.

**[P] One derived record per person**, `Game.world_state["cast"][name]`:
```
{ "alive": true|false,            # only Marcus (and the scripted temp survivor, Frank) can become false in the campaign
  "status": "present"|"away"|"missing"|"lost",   # present = with the group; away = out of the shelter (e.g. Sarah at home guard); missing = left behind (ch14 fence); lost = dead (Marcus)
  "where":  "market"|"mill_house"|"station"|"chamber"|"tunnel"|"unknown",
  "fit":    true|false }            # derived: status == present and health != "serious"
```
- `trust`, `morale`, `health` **stay** in `survivors.gd`. `roster()/group()/present()` become thin wrappers over `cast` (no behaviour change).
- `missing` has **no resolver** in the playable campaign (Audit; B5 16.X). `lost` has no resolver anywhere (never returns).
- **Noah** is added as `cast["Noah"]` with `alive = true` always (no branch kills or loses him), `status in {"unknown","present"}`.
- **Never alive->false for Eddie, Ruth, Sarah.** **Invalid:** `status = lost` and `present`; `status = missing` and any `where = chamber`.

## C4. Transition tables (new and changed beats)

| ID | Entry predicate | Mutations | Resource checks | Checkpoint / skip / retry | Touchpoints |
|---|---|---|---|---|---|
| 13.0a | `chapter_11_complete and not ch12_rescue_started` | set `ch12_rescue_started`; add item `noahs_ribbon`; objective "Go to HOUSE_19 at first light" | none | start: write `chapter12_start` (existing); retry: n/a | `chapter12.gd:_opening`, `items.json`, `objectives.json`, `dialogue.json` (`c12_ribbon_*`), `hud.title_card("FIRST LIGHT")` |
| 13.0b | after 13.0a, control | `st().companion` = chosen name or `""` (solo) | companion must be `fit` | none | the same pattern as `chapter13.gd:companion_options` |
| 13.0c | in the field with `ch12_rescue_started` | Hound loop active; cover points enabled | none | retry resets only the Hound loop; no checkpoint | `VeilHoundAI` reuse, decals (mark atlas), `veil_decal` |
| 13.0d | `ch12_house19_entered` | knock pattern; test; open door -> `ch12_noah_found` | the backpack item **optional** (ribbon alone suffices if absent) | **checkpoint `chapter12_noah` at `ch12_noah_found`**; mid-knock never saved | new interactable `C12_KnockDoor`, `Noah` model (existing NPC set; **no new asset**: see "Asset use" below) |
| 13.0e (lost) | `ch9_marcus_lost` | `Game.world_state["noah"].status = "found"` | none | none | dialogue only |
| 13.0f | walking back with Noah | Noah follows (`VeilCompanionFollow`); `ch12_noah_home` on mill-house arrival | none | save after `ch12_noah_home` restores Noah at the mill house | `survivors.gd` add Noah to NAMES for trust only (optional) |
| 13.1 | `ch12_noah_home` | set `ch12_below_explained`; `home_guard` set | none | skip allowed (hold) | `dialogue.json c12_below_why`, props: window tally |
| 15.02 | meeting | `st().noah_partner` | partner fit | within existing `chapter14` checkpoint (`chapter15_start`) | `chapter14.gd:_meeting` |
| 16.06 | decision | `ch15_choice_*`, commit record | none | **`chapter16_decision` written before the prompt** | `chapter15.gd:_decide`, `_finish`, `_record_ending` |

**Asset use:** Noah has **no model** in the current Meshy cast. The brief allows reuse only: **proposed stand-in = the existing smallest Meshy NPC** (e.g., the `child` or the shortest teen model if the NPC set has one; otherwise the protagonist's model scaled 0.78 with a different face texture) **[P - asset decision; owner approval]**. Face sheets are pending from the owner (see CLAUDE.md "Meshy characters").

## C5. What must be saved together (atomic groups)

1. **Rescue group:** `ch12_noah_found`, `ch12_noah_home`, `world_state["noah"]`, the `cast["Noah"]` record, the added items (`noahs_ribbon`, `farmers_journal`), the `chapter12_noah` checkpoint. A partial write (flag without Noah record) is **invalid** -> on load, re-derive `world_state["noah"]` from the flag.
2. **Pin group (Ch10):** `ch9_marcus_lost` + `cast["Marcus"].status` + `roster()`.
3. **Fence group (Ch15):** `ch14_<name>_missing` + `st().missing` + `cast[name].status = "missing"`.
4. **Ending group:** `ch15_ending_committed`, `st()["ending"]`, `st()["epilogue"]`, `ch15_ended`, `chapter_15_complete`, and the **`user://veil_endings.json`** record (keyed by commit id).

## C6. Migration of existing saves (`SAVE_VERSION` is `1`, `game_state.gd:12` **[V]**)

**[P]** Bump to `2` with a pure, idempotent `Game._migrate_1_to_2(d)` that **adds defaults only** (never deletes, never touches inventory or ending history):

| Old save position | What it contains | Migration | What the player experiences |
|---|---|---|---|
| **Before the farms** (no `chapter_11_complete`) | nothing of 13.0 | defaults only; `noah_rescued=false` | **new content plays normally** when they reach it |
| **After the farms, before the station arc finishes** (`chapter_11_complete`, not `chapter_12_complete`) | they have seen the HOUSE_19 light | `ch12_rescue_started` stays false; **13.0a is scheduled for the next mill-house wake-up** | They wake at the mill house at first light and the ribbon is on the table: **a truthful route** - the promise from `c11_light_alive` ("At first light") is simply kept late. |
| **After the station / district** (`chapter_12_complete` or `chapter_13_complete`, not `chapter_14_complete`) | they have already gone below | 13.0a is scheduled for the next time the group is at the mill house and the player has control (the night in `chapter13.gd:_night`, or 15.01) with Noah's **lamp** answering; `c12_below_why` is **suppressed** (they are already below ground) and replaced by `c12_late_why` (one line: NOAH: "He said *across*. You already went *down*. So I guess you were right.") | The rescue still happens, honestly *late*. |
| **At or after the finale checkpoint** (`chapter_14_complete`, `chapter16_decision` exists) | the mill house is lost | **No rescue content is reachable** (the house is gone). `noah_rescued=false`, `world_state["noah"].status = "unknown"`. **Epilogue uses the *truthful* lines** (table in B5 16.X): "Marcus never stopped looking for Noah." - **no claim a rescue happened.** Endings A/B/C use their CURRENT dialogue (no Noah lines). | Their original storyline continues **unchanged**. |

- **Ending history is never touched** (`user://veil_endings.json` is a separate file).
- **Inventory preserved**: the migration only adds keys with defaults; it never edits `Game.inventory`.
- **Chapter-select fixtures** (`dev_chapter12.gd` and later) should add `ch12_noah_found`, `ch12_noah_home` so tests that start at 13+ model a rescued Noah; a second set of fixtures keeps `noah_rescued=false` to test the old-save path. **Keep both** and name them `dev_chapterN_noah.gd` **[P]**.

## C7. Checkpoint, skip and retry semantics (existing, kept; new additions marked)

| Situation | Behaviour |
|---|---|
| Chapter start | `chapterN_start` checkpoint (existing) |
| New milestone | `chapter12_noah` (new) at `ch12_noah_found` |
| Decision | `chapter16_decision` written **before** the choice; `_record_ending` loads it back after recording (existing) |
| Death | RETRY loads the **last save** (`death_sequence.gd`, existing) |
| Skip | hold-to-skip on conversation/cutscene lines (existing); **no skip** for held-camera sequences that carry a timer |
| Mid-choice failure | choices are re-asked (`while i < 0 and is_inside_tree()`, `_decide`) - cannot be dismissed (existing) |

## C8. Script and asset touchpoints (summary)

`game/world/chapter12.gd` (opening, new 13.0 module `chapter12_noah.gd` recommended to keep the file readable), `game/data/dialogue.json` (new ids listed in B1-B5), `game/data/items.json` (`noahs_ribbon`, `farmers_journal`), `game/data/objectives.json` (new objectives), `game/autoload/game_state.gd` (migration only), `game/world/survivors.gd` (optional Noah trust), `game/world/chapter15.gd` (epilogue table, idempotent `_record_ending`), `game/world/chapter9.gd` (pin scaling), `game/world/world.gd` (`p3_eddie_over_here` line), `game/world/phase4.gd` (`p4_marcus_roof` line). **No new monster, no new level geometry**; one stand-in NPC for Noah.
