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
