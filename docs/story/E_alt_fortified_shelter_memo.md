# E. Alternative development memo - delivering the earlier "stay in a fortified shelter" ending

**Status: memo only. Not in the main draft.** The main draft keeps the implemented endings (A leave, B seal, C send ahead). This memo says how the bible's older **Ending B - "The Ones Who Stayed"** (bible section 13: the protagonist rejects the uncertain crossing; the surviving group remains in a fortified shelter; Noah alive; Marcus present or not) could be delivered **if the owner chooses that version**, with the least change to existing code.

## E1. What would change

1. **Re-label B, do not add a fourth button.** The decision currently has three options (`chapter15.gd:_decide`: LEAVE / SEAL / SEND AHEAD). Keep three buttons; re-label B as *"STAY - hold the shelter we have"* (the group declines to cross and does **not** go back to the mechanism). The seal work (lever A then wheel B) becomes an **optional pre-decision task** done calmly before the choice instead of under falling stone.
2. **Where the group stays:** not the destroyed mill house. The **maintenance station** (the Ch16 refuge, `chapter15.gd:_setup_refuge`) is the only intact shelter. It is fortified by what the player carried plus three props it already has (the fuse box, the storage locker, the lower-door slab shut by the player). No new geometry.
3. **Cost:** the player does not descend again. Whatever was done at the seal stays done; whatever was not, stays not.
4. **Noah:** alive and present; a final scene in the station's upper room: his lamp, the watch log, the signal code. Marcus present: reunion payoff (as in 16.A). Marcus lost: the backpack scene. **No fake-out.**
5. **Epilogue line (replacing B's):** "They stayed. Noah kept the log. Some nights the fog came to the fence and stopped. Some nights it didn't." (Open, no cosmology; local quiet is **not** global victory.)

## E2. Risks and what to keep

- Do **not** make the shelter feel safe: the station's floor is the same stone (`c12_clue_stone`). The scare is quiet, not a siege.
- "The Veil predates recent events" is preserved by the station's own records; no new lore.
- **Keep the actual escape from the collapsing chamber** (the player still leaves the chamber alive); show any refurbished refuge **only with approval**.

## E3. Implementation cost (honest)

Small: one choice label and hover text, one new `_ending_b_stay()` branch (reuses `_to_outer` and `_look_back`), one epilogue line, one optional pre-decision seal task (code exists: `_seal_step`). **No** new assets. The existing seal ending would move to an optional pre-decision action with no separate ending, so the set becomes **Leave / Stay / Send ahead**, matching the bible's A/B/C. **Decision for the owner:** see `F_approvals.md` item 8.
