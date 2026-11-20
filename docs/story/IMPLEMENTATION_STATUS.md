# Implementation status - branch `story/noah-rescue`

**Implemented and tested headless (not visually verified):**
- `game/world/chapter12_noah.gd` - scene 13.0, the Noah rescue: Eddie's ribbon -> who goes (Eddie / alone; Marcus, alive, comes and waits at the fence) -> the field and the existing Hound AI patrolling in front of HOUSE_19 (a bite sends the group back to try again: fair recovery) -> the porch, `[E] Knock (three short, one long)` -> the bag question (a wrong answer, then the keychain) -> Noah opens -> his account, the farmer's journal -> Marcus's reunion or the bereavement choice -> `chapter12_noah` checkpoint -> back to the mill house -> 13.1 "why under the ground" -> the chapter's own map talk with Noah in the room.
- Wiring in `chapter12.gd` (Eddie's talk, tick, guide marker, opening caption "FIRST LIGHT", load restore, `ch12_noah_na` when the district begins without a rescue).
- Data: 28 dialogue ids, items `noahs_ribbon` and `farmers_journal`, 4 objective steps with a new `when` condition (`game_state.gd:current_step`).
- Approved extras: pin window 7/10/13 s by trust (`chapter9.gd`), "FINN" line replaced, epilogue Noah lines, migration `_migrate_noah` (defaults only).
- Tests: `chapter12_noah_test` (both Marcus variants, a load afterwards: PASS); `chapter9_test`, `chapter15_test`, `chapter12_test` updated for the approved changes.

**Not done (honest):**
- The stealth is the existing Hound AI with a patrol line; the three chalked cover points, crouch-specific rules and the waymark decals are not built. Needs your playtest.
- Noah's lamp signal, watch-log prop, the fog-line tally props and the farmer's-journal kitchen prop are not built (the journal is handed over).
- Later Noah beats (15.01 wake line, 15.02 partner, 15.06/15.07, the finale lines `c15_end_*_noah`, the Ending C knock) are not implemented; Noah stays in the mill house after 13.1 and is not yet in the later chapters' groups.
- The late route (an old save already in the mill-house stage of displayed Ch13) works; saves already past it get `ch12_noah_na` and keep their old storyline and the truthful epilogue.
- Visual checks (camera framing, Noah's model at the door, the door opening, the Hound reading as a patrol) are for the owner.
