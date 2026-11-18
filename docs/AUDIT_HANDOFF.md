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
