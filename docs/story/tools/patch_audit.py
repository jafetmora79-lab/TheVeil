"""One-off: appends audit rows 16-18 to docs/story/A_continuity_audit.md (run from the repo root)."""
p = "docs/story/A_continuity_audit.md"
s = open(p, encoding="utf-8").read()
if "| 17 | **A promise" in s:
    raise SystemExit("already patched")
add = (
    "| 16 | **A hard-coded player name.** Eddie's line `p3_eddie_over_here` is \"FINN! Over here - the shop, NOW!\". The player chooses a name in the menu (`Game.player_name`, `game_state.gd:82`) and the bible says not to invent a fixed name; no other dialogue uses a name. | `dialogue.json` line 7111 [V]; `player_name_test.gd` | Replace with a line that needs no name (B1 03.03), or add `{player}` substitution to `Dialogue.say` first **[P]**. |\n"
    "| 17 | **A promise the story does not keep.** Chapter 12 ends with \"At first light.\" (`c11_light_alive`) about HOUSE_19; Chapter 13 opens at the mill house \"before dawn\" with a different plan. | `dialogue.json c11_light_alive`, `chapter12.gd:_opening` [V] | The new 13.0 keeps the promise (B4). |\n"
    "| 18 | **Lock-In choice names.** The brief says \"accept / refuse the search\"; the real flags are `p4_choice_noah` (accept) and `p4_choice_wait` (refuse), and the refuse branch has **no evening creature**, only night banging. | `phase4.gd:_run_threat` [V] | B1 05.02 uses the real flags and describes what each branch shows. |\n"
)
marker = "\n## A2."
i = s.index(marker)
s = s[:i].rstrip("\n") + "\n" + add + s[i:]
open(p, "w", encoding="utf-8").write(s)
print("patched")
