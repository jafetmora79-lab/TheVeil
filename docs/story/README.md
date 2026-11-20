# THE VEIL - story pass (narrative + implementable state specification)

Written on `cinematics/ledger-pilot`; the **approved** parts are implemented on `story/noah-rescue` (see `IMPLEMENTATION_STATUS.md`). Nothing is merged. Companion to the cinematic ledger in `docs/cinematics/`: scene IDs match (`C03.02b` etc.), new beats add suffixes (`03.04.1`, `13.0a`...).

| File | Package item |
|---|---|
| `A_continuity_audit.md` | A. Continuity audit (18 conflicts + resolutions), writer-only history, player-discovery timeline, confirmed / witness / unresolved table, Greyhaven route map |
| `B1_act1_ch1-5.md` ... `B5_act5_ch15-16_endings.md` | B. Scene-by-scene bible and playable script, all 16 chapters, both branch choices, three endings, epilogue table |
| `appendix/` | **Every CURRENT line, verbatim**, per displayed chapter (generated from `game/data/dialogue.json`, 428 scenes) - the B files cite these by id and write **only NEW or REVISED** lines in full, so the text is never duplicated and cannot drift |
| `C_implementation_contract.md` + `data/flags_current.json` | C. Dependency graph, flag dictionary (307 current flags, generated) and the new ones, survivor availability model, transition tables, save-together groups, migration for old saves |
| `D_reachability_qa.md` | D. 14-run covering matrix, per-ending procedures, required/optional/recovery table, invalid combinations with proofs, earliest checkpoints, verified-vs-test-plan list |
| `E_alt_fortified_shelter_memo.md` | the separate memo for the older "stay in a fortified shelter" ending |
| `F_approvals.md` | short approval list, recommendation first |
| `tools/` | `build_dialogue_appendix.py`, `build_flag_dictionary.py`, `verify_story_docs.py` (checks every `file.gd:function` reference; lists every id that is not in the repo so each can be confirmed as a proposal) |

## What the pass decided (summary)

- **Noah's rescue is restored** as a mandatory, repeat-safe milestone at the head of displayed Chapter 13 (13.0), *keeping* the underground arc. The current Chapter 12 ends unchanged (an unreadable light); 13.0 keeps its own promise ("At first light.").
- The rescue chain is built from props that already exist plus a ribbon and a journal: **campsite note -> Noah's message in HOUSE_20 -> the light at HOUSE_19 -> the ribbon ("KNOCK 3 + 1") -> a short stealth entry -> a knock-and-question test that a lure cannot pass -> Noah**.
- **Noah is a capable 13-year-old, never a casualty branch**: signaller and watch-log keeper at the mill house; a named evacuation partner in the siege; his knock code is the finale's last sound in Ending C.
- **Endings stay A leave / B seal / C send ahead** with concrete costs and Noah/Marcus payoffs; the epilogue bug is fixed; interrupted-ending resume is specified.
- **Marcus** can be lost; his pin window scales with trust (7 / 10 / 13 s proposed). **No dead character returns.**

## What was verified, and what was not

- **Source reading [V]** of `chapters.json`, the bible, master-context headers, `world.gd`, `phase4.gd`, `chapter5-15.gd`, `survivors.gd`, `game_state.gd`, `dialogue.json`, `items.json`. Every `file.gd:function` reference in the docs resolves (`tools/verify_story_docs.py`: 60 references, 0 missing). 74 ids/flags in the docs are **not** in the repo; each is a proposal.
- **Not done:** no scene has been implemented or play-tested. Dialogue is written to the repo's conventions (`_alt`/`@1`, `_Sarah/_Ruth/_Marcus`) but is not yet in `dialogue.json`. The 14 walkthroughs in D are a **test plan**.
- **Facts the brief assumed that the code contradicts** (all in the audit): the Marcus 4/8/12 s window (code: flat 10 s); the accept/refuse labels (code: `p4_choice_noah` / `p4_choice_wait`, and refuse has no evening creature); Eddie "may die" (no code kills him); a "four-legged" Colossus (default is three-legged).
- **Two things the pass found on its own:** the hard-coded name "FINN" in `p3_eddie_over_here`, and "Noah was never found." printing whenever Marcus lives.
- Cinematic and performance decisions stay in the Blender brief (`docs/cinematics/`).
