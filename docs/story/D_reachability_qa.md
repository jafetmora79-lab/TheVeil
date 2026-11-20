# D. Reachability and writing QA

**Status honesty.** Nothing here was play-tested for this pass. **[V]** = the branch/state exists in code and was read (path given). **[T]** = a test plan, not executed. Existing automated tests that touch these beats are named; they were not re-run for this document except where stated in `README.md`. Campaign checks use **real saves played through**, never chapter-select fixtures (CLAUDE.md).

## D1. Variables and their real domains

| Variable | Values | Where it is decided | [V] |
|---|---|---|---|
| Errand order | market-first / shop-first | `groceries_done`, `game_bought` (either order) | `world.gd:_p3_tick` |
| Lock-In choice | `p4_choice_wait` / `p4_choice_noah` | `phase4.gd:_on_choices` | yes |
| Ch6 survivor (HOUSE_05) | helped / informed / left | `chapter5.gd` flags `c5_survivor_*` | yes |
| Ch7 Ruth & Sarah | invite / directions / leave | `chapter6.gd` | yes |
| Hound route | investigate / retreat | `ch6_voice_choice_*` | yes |
| Backpack clue | seen+picked / (cannot be skipped) | `ch7_backpack_found`, `ch7_note_read` | yes |
| Trust | `marcus_trust()` 0/1/2 | `p4_choice_noah`, `marcus_trust_search` | yes |
| Sarah | treated / untreated | `chapter8.gd:_help_sarah` | yes |
| Marcus | pulled free / lost | `chapter9.gd:_pin_marcus` | yes |
| Sarah rest (Ch11) | help / push | `ch10_choice_*` | yes |
| Door injury | Sarah (else Ruth) | `chapter14.gd:rescue_target` | yes |
| Fence | go back / keep moving | `chapter14.gd:_separation` | yes |
| Evidence (Ch14) | help companion / secure evidence | `chapter13.gd:_help_companion` / `_take_evidence` | yes |
| Supplies at finale | high / mid / low | `chapter14.gd:_check_supplies` | yes |
| Spokesperson | Eddie > Ruth > Sarah (never Noah) | derived | **[P]** |
| Noah (new) | rescued (all new saves) / not rescued (old saves) | 13.0 | **[P]** |
| Ending | A / B / C | `chapter15.gd:_decide` | yes |

## D2. Minimal covering set of walkthroughs (14 runs cover every value at least once and every Marcus x fence x ending cell)

| Run | Errand | Lock-In | Ch6 surv. | Ruth/Sarah | Hound | Sarah med | Marcus | Ch11 rest | Fence | Evidence | Supplies | Ending |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | market | noah | helped | invite | investigate | treated | **free** | help | go back | help | high | **A** |
| 2 | shop | wait | informed | directions | retreat | untreated | **lost** | push | keep moving | secure | low | **B** |
| 3 | market | noah | left | leave | investigate | treated | **free** | push | keep moving (**Marcus missing**) | help | mid | **C** |
| 4 | shop | wait | helped | invite | retreat | untreated | **lost** | help | go back | secure | mid | **A** |
| 5 | market | wait | informed | leave | investigate | treated | free | help | keep moving (Ruth missing) | help | low | **B** |
| 6 | shop | noah | left | directions | retreat | untreated | lost | push | keep moving (Sarah missing) | secure | high | **C** |
| 7 | market | noah | informed | invite | retreat | treated | free | help | go back | secure | high | **B** |
| 8 | shop | wait | left | invite | investigate | untreated | lost | push | go back | help | low | **C** |
| 9 | market | wait | helped | directions | investigate | untreated | free | push | keep moving (Marcus missing) | secure | mid | **A** |
| 10 | shop | noah | informed | leave | retreat | treated | lost | help | keep moving (Sarah missing) | help | low | **A** |
| 11 | market | wait | left | invite | retreat | treated | free | help | go back | help | high | **C** |
| 12 | shop | noah | helped | leave | investigate | untreated | free | push | go back | secure | low | **B** |
| 13 | market | noah | informed | directions | investigate | treated | lost | help | keep moving (Ruth missing) | secure | high | **C** |
| 14 | shop | wait | helped | invite | retreat | untreated | free | push | keep moving (Marcus missing) | help | mid | **B** |

All 14 reach the finale **with Noah rescued** (new saves). Each run also takes **an alternate spokesperson** in the epilogue where the named speaker is `missing` (Ruth missing -> Eddie speaks; if Eddie were missing -> Ruth; code never produces Eddie missing, see Audit #5 - **[V]** `chapter14.gd:_separation` picks Ruth/Sarah/Marcus). **Old-save runs** (Noah not rescued): replay runs 1, 2, 5 from a save made before `chapter_11_complete`, after `chapter_11_complete`, and at `chapter16_decision` to test C6.

## D3. Plain-English procedures (player view) for each ending

**Shared route to the decision (all three)** *(required unless marked optional)*:
1. Complete Chapters 1-12 (**required**, ordered) including **the Noah rescue 13.0** *(new, required)*. 2. At the mill house, **go to the station** (13) *(required)*, find the fuse, restore power, read at least the **log** (**optional**: the map is a handoff, the fuse is required). 3. Chapter 14: **cross the district**, open the gate, reach the doorway, choose **help companion** *or* **secure evidence** *(required choice)*. 4. Chapter 15: **prepare** (supplies, entrances, escape - any order, **none required** but each visibly helps), survive the siege, shove the table, evacuate, decide **go back / keep moving** at the fence *(required choice)*. 5. Chapter 16: refuge talk *(optional)*, **cross the fields using cover** *(required)*, **squeeze through the rubble gap** *(required)*, **ancient passage** *(required)*, chamber *(inspect ≥1 clue or reach both controls: required)*, **operate control A then B** *(required)*, **final mechanism under falling stone** *(required)*, **decision** *(required; checkpoint `chapter16_decision` written first)*.

**A - Leave:** choose LEAVE GREYHAVEN, follow the **live exit objective** along the service tunnel with everyone present; reach the fields; look back; walk away; watch the mist edge. **Costs:** nothing physical; the barrier stays open. **Noah:** reunion (Marcus alive) or grief moment (lost).
**B - Seal:** choose SEAL THE CHAMBER; the group waits at the tunnel; go **back to the mechanism**; **lever A, then wheel B**, dodging falling stone; slab closes; escape through the service tunnel. **Costs:** health and time; no promise. **Noah:** the group intends to find other people; he knows the first three turns.
**C - Send ahead:** choose SEND THE SURVIVORS AHEAD; the group (incl. Noah) clears the tunnel; **lever A, then wheel B**; the passage collapses after them; the protagonist stays. **Costs:** the protagonist. **Noah:** he hears the knock back and tells no one.

## D4. Required vs optional vs recoverable (so no mandatory interaction can softlock)

| Interaction | Required? | If missed / failed |
|---|---|---|
| Breadcrumb (ribbon) | **required** | fallback prop at the mill house gate (13.0a) |
| Stealth loop at HOUSE_19 | required | retry only resets the Hound loop; **leashed** chase (`chapter11.gd:_pursue` pattern) |
| Knock pattern | required | second chance; after 30 s Noah opens (fixture/old-save fallback) |
| Backpack colour test | required | alternate: show the keychain; alternate: the ribbon alone |
| Farmer's journal | optional | 13.1 argument works without it (`ch12_journal_read` false: Noah gives the one line) |
| Station records (≥1) | optional | the map is the required handoff (`c12_map`) |
| Colossus crossing | required | `_retry` fade to the last cover; 8 HP minor; never lethal |
| Rubble gap, passage | required | the gap is the only moving geometry; `GAP (12, 0, 23)` always passable |
| Controls A and B | required | prompts refreshed by `_refresh_seal_prompts`; falling stone has a readable safe window |
| Low supplies (finale) | n/a | **no softlock**: `c14_pack_short` plays; the emergency run is optional; hunger/exposure is recorded, never a fail state |

## D5. Invalid combinations and why they are invalid

| Combination | Why it cannot exist |
|---|---|
| Marcus **present** and `ch9_marcus_lost` | `roster()` returns Marcus only when `ch9_marcus_lost` is false **[V** `chapter9.gd:roster`**]**; the two flags are mutually exclusive by one writer (`_marcus_lost`) |
| A dead Eddie, Ruth or Sarah | no code path sets `alive=false` for them; `survivors.gd` rules: "never kills, revives, duplicates" **[V]** |
| Noah **missing**, dead or left behind | 13.0f/15.05/15.07: Noah is never a target (`rescue_target`/`separation_target` exclude him **[P]**), he is never in `st().missing` |
| `ch12_noah_home` without `ch12_noah_found` | the only setter of the former is the arrival scene, entered only after the latter |
| Two `ch15_choice_*` at once | `_decide` returns early on `ch15_decided` **[V]** |
| A decision made but `chapter16_decision` unwritten | `chapter15.gd` writes it in the final-mechanism step (`k == "C"`: `Game.set_flag("ch15_mechanism_done")`, `world.save_checkpoint("chapter16_decision")`, then `_decide()`), i.e. **before** the prompt **[V]** |
| The temp survivor present **after** `ch8_temp_survivor_died` | `temp.visible = false` (caught, "gone: no body, no gore") **[V** `chapter8.gd:433`**]** |
| Frank returns | `lt_frank_done` + `people["Frank"].state = "taken"` + `_unregister` **[V]** |
| A rescued fence-missing character is present at the finale | `present()` excludes `st().missing`; nothing writes back to it **[V]** |

## D6. Earliest checkpoint per final branch

| Branch | Earliest checkpoint | Notes |
|---|---|---|
| A, B, C (any) | **`chapter16_decision`** | written before the decision; `_record_ending` loads it back so the finale is always replayable **[V]** |
| Pin/Marcus outcome | `chapter9_*` (the chapter's own start checkpoint) | a failed pin is a **retry** (RETRY loads last save) |
| Noah rescue | `chapter12_noah` **[P]** | at `ch12_noah_found` |
| Fence | `chapter15_end` **[V]** | start of 16 |

## D7. Verified in code vs test plans

| Beat | Status |
|---|---|
| Both errand orders -> one outdoor trigger | **[V]** `world.gd:_p3_tick`; test plan [T] 2 runs |
| Colossus (tripod) encounter, held camera 17.8 s, control return | **[V]** code; `colossus_market_last_test` passes; **visual not verified** |
| Frank/Skitter + retreat | **[V]** `frank_skitter_test` passes |
| Lock-In wait vs noah | **[V]** code; [T] both full runs |
| Voice/Hound routes | **[V]** code; [T] both |
| Backpack/note | **[V]** code; [T] |
| Ch9 attack, pin, fall | **[V]** code; `chapter8_test` fails in this checkout identically with old creatures (baseline); [T] |
| Marcus scaling 7/10/13 | **[P]** not implemented |
| Noah rescue 13.0 | **[P]** not implemented; [T] all branches in D2 |
| Ch15 siege/fence | **[V]** code; `chapter14_test` exists; [T] |
| Finale + endings | **[V]** code; `chapter15_test` passes; [T] the new epilogue table |
| Interrupted-ending resume | **[P]** not implemented |
| Chapter reload, mid-choice failure, skipped cutscenes | **[T]** per D4/C7 |
