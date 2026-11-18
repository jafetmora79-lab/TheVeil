# THE VEIL — audit handoff

- **Branch:** `audit/full-game-review-2026` (from `claude/practical-cray-hi2y54` @ `1f9d5b8`). Not merged, no PR.
- **Commits:**
  - `95c0619` VB-002 car exit (+ `vehicle_exit_test`)
  - `48e8673` Blender repair plan + `tools/blender/inspect_asset.py`, `rebase_pivot_copy.py` (both **untested**, no bpy here)
  - `b48c418` VB-001 atomic save (+ `save_atomic_test`)
  - `4402537` VB-003 note-read softlock (inventory `viewed`; chapter7/chapter11)
  - `6cffab6` `chapter5_test` brought up to date; new `audit_npc_placement_test`
  - (this docs commit)
- **Remaining issues:** see `docs/VERIFIED_BUGS.md` (VB-004…VB-009).
- **Windows ZIP:** **not built** — it cannot be launched or verified here, so no unverified build is offered. Rebuild per `CLAUDE.md` after merging.
- **Tests (isolated `XDG_DATA_HOME` per run; first-pass results):** chapter_select 214/0, qa_softlock 9/0, retry 16/0, opening 237/0, chapter9/10/13/14/15 all pass, chapter7 16→0 after fix, save_atomic PASS, vehicle_exit PASS, navigation/map/edge_bounds/loading_door/stock_door/tentacle_entrance/handwash/inventory_layout PASS. Failing/unclear: chapter5 (timed out), chapter6 (1), chapter8 (3, stale), chapter11 (1), chapter12 (2), death (7, test artifact), house_audit (2), house_loot (3), threat (2), shelter_systems (1), survivors (1), expedition (stale), stairs (74/340 cases), audit_npc_placement (1). Tests after `expedition` in the suite had not finished when written.
- **Next actions:** (1) play Ch.1→16 on Windows; (2) decide VB-004 (rubble/stairs); (3) repro Eddie lag and Ch.12/13 stalls; (4) triage unexplained failures (house_loot, threat, house_audit, Ch.10 Sarah placement); (5) run the Blender plan on the sidewalk marks and roof Skitter.

## Second half of the suite (collected later; the run was still going, so `living_town` onward is not recorded)
- **Pass:** town_destruction 17, pay_first 9, car_repair_anim 12, road_home 9, easter_egg 35, roof_skitter_handoff 26, frank_skitter 9, colossus_market_last 14, colossus_shot 3, click_struggle 4, supplies_sidearm 13, scavenge_companion 18, sarah_rescue 16, four_fixes 12, tentacle_entrance 21, cinematic (no checks).
- **Fail, NOT investigated (stale test vs game unknown):** car_quest 71/2, handgun 26/1, supply_grace 7/1, systems_repair 17/6, world_repair 20/5, final_repairs 44/1.
- **Follow-up:** see the "Follow-up: investigation of the failing tests" section of `docs/VERIFIED_BUGS.md` (VB-010 root-caused; one stale test confirmed; the rest unresolved).

## Suite finished (final tail)
- **Pass:** ch6_supplies_map 12, intro_trailer 19, trailer 26, anim_running (floor error 0.001 m, rig slide 0.0002 m, loop 0.0007 rad).
- **Fail, NOT investigated:** living_town 32/1, player_name 16/1 (exit 134, an engine abort: unknown whether a real crash or the known shutdown quirk).
- Whole-suite note: every failing test not named in `docs/VERIFIED_BUGS.md` as a confirmed bug is **unclassified** (stale test vs game bug unknown). Missing coverage here is not a confirmed defect.

## Third pass (see the last section of `docs/VERIFIED_BUGS.md`)
Most remaining failures were stale or flaky tests and are fixed in the tests. New open game finding: **VB-011** (a Hound roams from 19 s into every trip, against the documented calm tuning). Still undiagnosed: Eddie lag (VB-005), Ch.12/13 stalls (VB-006), `house_audit` doors, `chapter8`, `death`, the rest of `expedition_test`, `house_loot` (stale by data).

## Fourth pass
New: **VB-012** (Chapter 13 exit ramp has a 13 cm lip the player cannot step over because step-up is disabled on slopes; root-caused by probe, not changed). Explained as stale: `chapter8_test` (the attack flow was redesigned), `chapter6_test` Eddie lag (0.2 m over a hard limit), `chapter11_test` walk upstairs (route). Still open: `house_audit` doors in the two lootable houses EXT_HOUSE_24/25; `death_test` not re-probed.
