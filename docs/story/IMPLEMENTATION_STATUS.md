# Implementation status - branch `story/noah-rescue`

**Implemented and tested headless (none of it visually verified - the owner's playtest):**
- **13.0 the Noah rescue** (`game/world/chapter12_noah.gd`, wired in `chapter12.gd`): Eddie's ribbon -> who goes (Eddie / alone; Marcus, alive, comes and waits at the fence) -> the field, three chalked waymark posts (the group falls back to the last one passed) and the existing Hound AI patrolling a line in front of HOUSE_19 (a bite sends the group back to try again) -> the porch, `[E] Knock (three short, one long)` -> the bag question (wrong answer, then the keychain) -> Noah opens -> his account, the farmer's journal -> Marcus's reunion, or the bereavement choice -> checkpoint `chapter12_noah` -> back to the mill house -> 13.1 "why under the ground" -> the chapter's own map talk with Noah in the room.
- **Noah in the mill house:** a signal lamp in the window (three short, one long, every 8 s, off when you stand at the window) and a pencilled fog tally on the frame that grows with the chapters.
- **Chapter 15 (`chapter14.gd`):** Noah wakes the protagonist (`c14_wake_noah`), reads his watch log, names his evacuation partner (Ruth by default, Marcus if alive and fit, else Sarah), and goes with the group in the evacuation.
- **Chapter 16 (`chapter15.gd`):** Noah is at the refuge, the "why go back down" talk (`c15_why_below`), his last lines in each ending (A reunion or grief, B the way on, C "He knocked back."), and the Ending C knock: three short and one long on the stone, then a faint answer from beyond it.
- **Approved extras:** pin window 7/10/13 s by trust; the "FINN" line replaced; epilogue Noah lines; old-save migration (`ch12_noah_na`); objective steps with a new `when` condition (`game_state.gd`).
- **Data:** ~40 dialogue ids, items `noahs_ribbon` and `farmers_journal`, 4 objective steps (`tools/add_noah_rescue_data.py` is idempotent).
- **Tests:** `chapter12_noah_test` (Marcus alive and lost, a load afterwards) and `noah_late_test` (chapters 15-16 with and without the rescue) PASS; `chapter9_test`, `chapter12_test` (rescue skipped), `chapter13_test`, `chapter15_test`, `chapter_select_test` (13, 14) PASS. `chapter14_test` has 2 failures (`c14_run_back`, `c14_run_done`) that are **identical on the commit before this work** (baseline, not caused by it).

**Deliberately different from the plan:**
- The farmer's journal is **handed over by Noah**, not found on a kitchen table.
- The optional Noah talk in the calm (`c14_calm_Noah`) and the hover cost text on the final decision (`c15_choice_cost_*`), the chamber map-room beat (`c15_map_room`) and the chapter-14 `c13_noah_lamp` line are **not built** (cuttable extras; the lamp itself is built as a prop).
- Interrupted-ending resume: **not needed** - the game already rolls any post-decision save back to `chapter16_decision` (`game_state.gd:_finale_rollback`).

**Still for the owner's eyes:** how the Hound reads as a patrol, the chalk posts, Noah's model in the doorway, the door opening, the lamp and the tally, the Ending C knock timing, and every camera framing in the ledger.
