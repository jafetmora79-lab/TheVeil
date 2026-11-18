# THE VEIL — Verified bugs (audit 2026)

Branch `audit/full-game-review-2026`, from `claude/practical-cray-hi2y54` @ `1f9d5b8`. Evidence = a headless test or probe run in the cloud session. **Nothing was seen on screen** (no GPU, no Windows PC). "Verified" means reproduced by a headless run; visual issues are listed separately as *needs your visual test*.

| ID | Sev | Area | Status | Commit |
|---|---|---|---|---|
| VB-001 | High | Save file | **Fixed** | b48c418 |
| VB-002 | High | Car exit | **Fixed** | 95c0619 |
| VB-003 | **Critical** | Ch.8 / Ch.12 note reading | **Fixed** | 4402537 |
| VB-004 | Medium | Wrecked houses: stairs | Open (owner decision) | – |
| VB-005 | Medium | Followers (Eddie) lag | Open, needs repro on Windows | – |
| VB-006 | Medium | Ch.12 farmhouse landing walk; Ch.13 escape run / Skitter | Open, needs confirmation | – |
| VB-007 | Low | Tests overwrite the real save | Open (documented) | – |
| VB-008 | Low | SAVE_VERSION never bumped | Open (documented) | – |
| VB-009 | Info | Stale tests (not game bugs) | Partly updated | 6cffab6 |

## VB-001 Save file could be left half-written (High) — FIXED
- **Repro:** kill the game during `Game.save_game()` (it wrote `veil_save.json` in place).
- **Expected:** Continue still works. **Actual (before):** truncated JSON → `has_save()` false / load fails; progress lost.
- **Root cause:** in-place write, no backup.
- **Fix:** write `.tmp`, verify length, copy previous to `.bak`, rename; `_read_save()` falls back to `.bak`; `has_save()` uses it.
- **Evidence:** `game/tests/save_atomic_test.gd` PASS (valid main, no .tmp, .bak = previous, truncated/missing main loads from .bak, stale .tmp harmless, `no_save` writes nothing). `chapter_select`, `qa_softlock`, `opening`, `retry` still pass.

## VB-002 Player can be held inside the car (High) — FIXED
- **Repro:** park the sedan with all 8 usual exit offsets blocked (walls, rubble, props). `PlayerSedan.exit_spot` returned null → no exit.
- **Fix:** each spot is tested with a ground ray (slope ≤ 46°) + capsule clearance; then a ring search (3.8–9 m, 16 angles). Null only if everything fails.
- **Evidence:** `game/tests/vehicle_exit_test.gd` FAIL before, PASS after.

## VB-003 Chapter 8 (and 12) note could never be "read" (Critical) — FIXED
- **Scene:** Noah's note (`chapter7.gd`, displayed Ch.8); campsite message (`chapter11.gd`, displayed Ch.12).
- **Repro:** pick up the note, open the inventory, inspect it. Opening the inventory sets `get_tree().paused = true`; chapter nodes are pausable, so their read timers (`_process`) stop → `ch7_note_read` never set → story stalls.
- **Fix:** the inventory panel (always-process) records the longest continuous view of each item (`viewed`); chapters read that instead of their own timers.
- **Evidence:** `chapter7_test` 16 failures → 0; `chapter11_test` note/message steps PASS (`c11_note_read`, `c11_message_read`).

## VB-004 Stairs in wrecked houses (Medium) — OPEN, design decision
- **Evidence:** `stairs_test`: 74 of 340 cases fail, all in 21 of the 25 town-destruction target houses, all involving `DestroyedCol` (trimesh + debris boxes); 4 colossus wrecks fail even plain walks. None overlaps `scavenge_houses.json` houses or houses named in `chapter5.gd`, `expedition.gd`, `living_town.gd`.
- **Impact:** not on the critical path as far as code references show; the player can be stopped by rubble on stairs in wrecked houses.
- **Not changed:** changing collision on the destroyed set is a redesign-level change (see `docs/FULL_GAME_AUDIT.md`, "Documented, not changed").

## VB-005 Eddie falls 16.2 m behind (Medium) — OPEN
`chapter6_test: c6_eddie_lag FAIL 16.2`. Follower logic (`companion_follow.gd`, `npc_route`) not changed; could be a test-timing artifact (the test teleports the player). Needs a Windows walk-through.

## VB-006 Stalls in late chapters (Medium) — OPEN, needs confirmation
`chapter11_test: c11_walk_upstairs FAIL` (Ch.12 farmhouse landing, stair collision, same family as VB-004?); `chapter12_test: c12_escape_run`, `c12_skitter_moved step 0.34 m` (Ch.13 underground). Not investigated to root cause. Not confirmed as player-facing.

## VB-007 / VB-008 (Low)
- Most `chapterN_test` write `user://veil_save.json` (the player's real save). Back it up before running.
- `SAVE_VERSION` is 1 and has never been bumped; any future save-format change needs a migration.

## VB-009 Stale tests, not game bugs
Investigated with probes before classification:
- `chapter5_test` (updated 6cffab6: supply crate, shelter-exit menu, van detour routes, inventory design). It was killed by the runner timeout at 813 s in the full run (47 pass / 39 fail before the update was re-run isolated) — **its final number was not re-confirmed**.
- `chapter8_test` (3 failures: control timing, hound guards, doorway) — stale expectations.
- `death_test` (7 `*_false` failures) — indoor pause artifact of the test; the outdoor death sequence is sound.
- `expedition_test` — written for the pre-menu shelter exit; watchdog.
- `house_audit` (EXT_HOUSE_24/25 door spacing), `house_loot` (houses_opened, refill, load_keeps_day), `threat` (A_danger_critical, D_tentacle_emerged), `shelter_systems` (storage panel totals), `survivors` (`sv_eddie_carries`) — **not investigated**; unknown whether test or game.
- `audit_npc_placement_test` (new): chapters 3–16, one failure, `ch10_Sarah_not_in_solid` at (30.4, 0.19, −33.4): a survivor capsule intersects solid geometry at the Ch.10 start. Not diagnosed; probably the "NPC inside furniture" class.

---
# Follow-up: investigation of the failing tests

Evidence levels: **ROOT-CAUSED** (probe shows the cause), **STALE** (the test checks something the code no longer does that way; read from code), **UNRESOLVED** (not diagnosed).

## VB-010 Auto-park from the west driveway is blocked by supermarket furnishing collision (Medium) — ROOT-CAUSED, open
- **Tests:** `final_repairs P_park_west_slow`, `world_repair park_from_anywhere`, `systems_repair L_park_from_the_west_driveway_slow`. **They fail identically on the pre-audit code (1f9d5b8)**: not caused by this audit's changes.
- **Probe (temporary print in `world._auto_park`, reverted):** the sedan accelerates to 7 m/s then stops dead at about (16.9, 0.11, −14.2) with 22.7 m of the approach path left. `get_slide_collision` shows it pressed against `/root/World/Commercial/SUPERMARKET/Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Col` at (19.35, 1.06, −13.57), normal (−1, 0, 0).
- **Effect:** after 1.5 s without movement `_auto_park` gives up (`ok:false`) and falls back to the fade-and-place path, so the player is not softlocked: they get a fade instead of the driven manoeuvre. Whether a *player-driven* car hits the same collision on that route is **not tested**.
- **Cause (not proven):** a furnishing collision shape in `COM_Supermarket_Furnishing.glb` stands on the planned approach line. Last touched 2026-11-07. Needs a look at that collision body in the editor/Blender (a prop box or an over-large hull?) — see Blender plan. Not changed here.

## Stale tests (the game is fine; the test is out of date)
- `shelter_systems storage_panel_shows_actual_totals` — STALE. It expects `"Food 0"`; `phase4._open_supplies` now writes `"Food: %d / %d …"` (phase4.gd:1435).
- `chapter8_test` (3), `death_test` (7), `expedition_test` (18) — STALE/test artifact, as listed above.
- `player_name confirmed_name_starts_world` (exit 134) — UNRESOLVED: the check asserts the scene switches to `World.tscn` after the name dialog; headless scene change plus engine abort at shutdown. Likely a teardown quirk, **not confirmed**.

## Unresolved (assertion read, cause not found)
| Test | Assertion | Read |
|---|---|---|
| `survivors sv_eddie_carries` | Eddie hands back a canned food on securing | not diagnosed |
| `threat A_danger_critical` (UNEASY, not level 3 after 3 min), `D_tentacle_emerged` | threat level and tentacle emergence | tuned values may have moved since the test; not diagnosed |
| `living_town R2_traffic_while_in_car` | cars spawn while the player sits in the car | 3 → 3 after 14 s; not diagnosed |
| `car_quest fit_once` | a spare fuse stays in the pack after a repeat fit | inventory ended with no fuse at all; possible small real bug; not diagnosed |
| `car_quest struggle_won_recover` | Crab AI enters RECOVER after the struggle is won | ended in CHASE; not diagnosed |
| `world_repair gh_look_*`, `fall_recovered (nan)` | greenhouse look scene; fall recovery | not diagnosed (`nan` position suggests a test setup problem) |
| `systems_repair H_*, I_*, J_*` | leave menu, quiet first 5 min, encounters, struggle controller | likely the shelter-exit-menu and threat-timing redesign, not confirmed |
| `living_town`, `audit_npc_placement ch10_Sarah_not_in_solid` | see above | not diagnosed |

## Diagnosed in a second pass — both STALE tests, now updated (the game is fine)
- **`handgun food_restocks`:** the test waited for `exp/cache_lot_food_d1`, but `expedition._spawn_caches` deliberately restocks only about half the spots each new day (`(idx + day) % 2 == 1` is skipped) and `lot_food` (index 0) is skipped on day 1. Probe: day 1 spawned `street_water`, `road_water`, `west_water`, `lot2_food`, `west2_water`, `east_water`, `road2_water` (`_d1`). Food does restock. The test now accepts any food spot. Passes.
- **`supply_grace companion_opens_doors`:** `world.companion_at_market_doors` returns early while `expedition.doors_held()` (probe: true, with the player in the store and no story departure) — the deliberate rule from commit 96919b1 (2026-11-07): "shelter time: a companion never opens the exit on its own". The test now asserts that rule, and that a companion does open the doors on a story outing (`story_departure = true`). Passes.

---
# Third pass: the rest of the failing tests (each probed or read against the code; fixes are to tests only unless stated)

## Fixed in the tests — the game was right (stale or flaky tests)
| Test | Cause | Evidence |
|---|---|---|
| `car_quest fit_once` | The pack holds one of each part (`Game.add_item` ignores a duplicate unless it is a shelter resource); the "second fuse" was never added. Count after the fit is 0 | read `game_state.gd:176`; test PASS after |
| `car_quest struggle_won_recover` | `struggle._release` waits 0.25 s (shove tween) before `ai.recoil()`; the test checked the same frame | test PASS after a 30-frame wait |
| `survivors sv_eddie_carries` | A companion's pack is filled by `_give` and deposited into the shelter stores (`survivors.deposit_pack`), not into the player's pack; the test never gave Eddie anything | PASS after giving a water bottle and checking the stores |
| `threat A_danger_critical`, `D_tentacle_emerged` | Calm tuning (commit 8abadde): danger steps are 5/10/15/20 min (`danger_thresholds_s`), tentacle only from CRITICAL; the test assumed 45/90/150/240 s | with the fast steps set in the test, the whole threat test PASSes (director works) |
| `shelter_systems storage_panel_shows_actual_totals` | text is now `Food: 0 / N` | PASS |
| `living_town R2_traffic_while_in_car` | **Flaky**: the next car is due 5–10 s at random, the test waited a fixed 14 s | failed 1 in 3 before; 3 of 4 runs pass after zeroing the timer. See residual below |
| `systems_repair H_*`, `I_encounters_happen`, `J_struggle_available` | The handgun hand-over (`sidearm.handover_pending`) pre-empts the leave menu on the first exit; the trip never started, so no creatures | marking the hand-over done: H, I_encounters, J pass |
| `systems_repair J_creature_released` | After 2.5 s the creature has already shaken it off (SUSPICIOUS/CHASE) | accepted states widened |
| `player_name confirmed_name_starts_world` | A new game now opens the intro cinematic (`Cinematic.tscn`, mode `intro`), not World directly | PASS. The signal-11 at the end is the known shutdown crash after the result line |
| `expedition_test` | Same hand-over cause: the menu now opens. Option labels differ from the test's expectations (`Continue Story - Talk to Marcus`, `Go Scavenging`, `Sleep / End Day`, `Stay Inside`) and later steps depend on them | **partly**: `exp_menu_opens` passes, 4 later checks still fail and the test still times out |

## New: VB-011 A roaming Hound appears 19 s into every trip, against the documented calm tuning (Medium) — OPEN, owner decision
- **Evidence:** `systems_repair I_quiet_first_5_min`: first appearances over a 21-minute simulated trip were hound **19 s**, skitter 617 s, crab 901 s. The data file's own note (commit 8abadde) says "0–5 min quiet (distant sounds only); 5–10 rare roaming Hound".
- **Cause:** `expedition.gd:1240` spawns a roamer when `(lv >= 1 or el >= 20.0)`; `_reset_director` sets `_next_roam = maxf(20.0, …)` — a hard-coded 20 s that survived the retune.
- **Not changed:** it sets difficulty. `threat_test` (fast steps) relies on early encounters. Fix would be to start roamers at the first threshold.

## Still open after investigation
- **VB-010 parking (extended):** `world_repair park_from_anywhere` → `gh_look_starts/done/once`, `fall_recovered (nan)`. The probe shows the test's side-on start point (lot x −6, z 22.5) is **inside the supermarket building collision** (the ground ray hits `COM_Supermarket_Col` at y 0.16); the sedan sinks below it (y −0.76) and falls (about −28 m). The `gh_look_*` checks need `world.in_car` false and the player visible; these are probably a cascade of the same state, **not confirmed**. Unproven whether a real car can reach that spot.
- **VB-010 minor:** `_fade_park` computes `lift = car.y − ground.y` at the *start*; if the car was ever under the ground, the car is placed under the stall's ground as well (no clamp). Harmless in normal play; not changed.
- **`audit_npc_placement ch10_Sarah_not_in_solid`:** Sarah's capsule overlaps `/root/World/Commercial/SUPERMARKET/C8_FrontSeat/RES_CardboardBox_Closed/…_Col` (layer 1) at (30.42, 0.19, −33.43) at the Chapter 10 start. A story prop's box collision vs the NPC. Cosmetic (she stands inside a box); whether the real chapter-9→10 flow places her there is not tested.
- **`house_loot`:** `houses_opened` expects 6 houses but 21 are open — `scavenge_houses.json` grew on 2026-11-08 ("seven more lootable Maple Ave houses", commit 4536afb) after the test was written; `refilled_one_container` and `load_keeps_day` read a fixed container of `HOUSE_15` and the half-restock rule/loot layout. **Stale by data change, not edited** (needs the loot spec).
- **`living_town R3_brakes_for_car_ahead`:** a second flaky check (1 in 8 runs: gap 3.6 m against `> 4.0`). The traffic AI can stop closer than 4 m centre-to-centre behind a car parked ahead at the top of its random speed range. Marginal; not changed.
- **Not investigated at all:** `chapter6 c6_eddie_lag` (VB-005), `chapter11 c11_walk_upstairs`, `chapter12 c12_escape_run/c12_skitter_moved` (VB-006), `house_audit` EXT_HOUSE_24/25 door spacing, `chapter8` (3), `death` (7, indoor-pause artifact per earlier probe).

---
# Fourth pass: the previously undiagnosed failures

## VB-012 Chapter 13 exit ramp: a 13 cm lip stops the player at the top (Medium) — ROOT-CAUSED, open, needs a geometry decision
- **Test:** `chapter12_test c12_escape_run` (and `c12_skitter_moved`'s companion state).
- **Probe (temporary, reverted):** the player sprints up `C12_Facility/Ramp` and stops dead at (0.22, −0.31, 28.68 relative to the facility origin), velocity 0, controls on, on the floor, for 2 s. A forward ray finds the vertical face of `C12_Facility/Slab` 0.36 m ahead (normal (0, 0, 1)); the ramp surface there is about 0.13 m below the slab top (y 0).
- **Cause:** `player.gd:166` only calls `_step_up` when `get_floor_normal().y > 0.93` ("flat ground only: stairs are ramps"). This ramp is about 26.6° (normal.y ≈ 0.894), so the step-up is never tried and the capsule is held by the 13 cm lip where the ramp meets the slab. `VeilSurvivorBody.step_landing` itself would succeed there (probe: rise 0.31 m, STEP is 0.35), so the geometry is the problem, not the step code.
- **Impact:** the player cannot walk out of the underground onto the slab at the end of the Skitter chase. A jump clears it (if the stamina rule allows; the probe shows stamina is 0.4 / 100 after the 40 m sprint, and a survival jump costs stamina, so an exhausted player may not be able to jump). Not confirmed on screen; the physics is the same engine as the game.
- **Not changed:** the fix is geometry (raise the ramp top 0.13 m / extend it under the slab, then check the bottom end does not get a new lip) or allowing a step-up on a slope when a low vertical face blocks; both change how the area plays. See `game/world/chapter12.gd:354` (`_box(fac, "Ramp", …)`).
- **Also in that run:** `skitter_max_step` was 0.34 m per frame against the test's 0.25 limit (the Skitter's fastest bound, about 20 m/s); not judged a defect.

## Stale tests, now explained (no game bug found)
- **`chapter8_test c8_control_back / c8_hound_guards / c8_doorway_blocked`:** since 92eda07 (2026-11-07, "the Hound bites Sarah, a click rescue, then the barricade") the attack scene is longer: control returns after **1162 frames (19 s)**, not within the test's 360; the current objective is `c8_help` (help the injured survivor), not `c8_secure`; the Hound has already been driven off (`c8.hound` null, `hound_spawns` 1) and the doorway blocker is not up yet (layer 0). The test describes the old flow. It needs rewriting for the bite → click rescue → help → barricade order; not done.
- **`chapter6_test c6_eddie_lag`:** the maximum lag is 16.2 m against a hard 16.0 m limit — 0.2 m over, with `c6_eddie_no_teleport` and `c6_eddie_no_wall_crossing` passing. Marginal; no defect shown (VB-005 is downgraded to Low).
- **`chapter11_test c11_walk_upstairs`:** the walker reaches the top landing (local y 3.60, floor normal up) and is stopped by a wall face 0.3 m ahead on its straight route to the next waypoint (probe), while moves sideways (±x) are free. The landing is not a dead end; the test's route is straight where the layout turns. Not a progression block (the later upstairs steps pass).

## Still not diagnosed
- **`house_audit`:** `EXT_HOUSE_24` (Cottage) and `EXT_HOUSE_25` (Ranch), both lootable Maple Ave houses added 2026-11-08, have 7 doors that the test cannot walk through in either direction (21 other houses pass; `holes 0`); `INT_Door_GarageKitchen` in house 25 has a 0.58 m floor step (0.60 → 0.02). Not found whether the doors are really blocked or the test's door-centre sampling misses on these two. **Worth a look because these houses are scavenged.**
- **`death_test` (7 `*_false`):** classified earlier as an indoor-pause artifact of the test; not re-probed in this pass.
