# Acceptance results (headless) - branch `story/noah-rescue`

Run on 2026-11-20, tests one at a time (they share `user://` saves). Raw logs: `ACCEPTANCE_RAW.txt` (first pass, **contaminated**: two runners overlapped),
`ACCEPTANCE_RERUN.txt` (clean serial rerun), `ACCEPTANCE_BASELINE.txt` (default branch; **not** a fair baseline, that branch is 436 commits behind).

**Nothing here is visual.** Every framing, the Colossus staging, the Skitter drag, the intro fade and the Noah scenes still need the owner's playtest.

## Passing (clean serial run)

intro_trailer_test, chapter_select_test (all 16 starts), chapter9, chapter10, chapter12_noah (the Noah rescue, Marcus alive and lost, plus a load), noah_late_test,
chapter13, chapter15, frank_skitter_test, colossus_market_last_test, colossus_shot_test, trailer_test, tripod_gait_test, pay_first_test,
town_destruction_test, roof_skitter_handoff_test, cinematic_test.

## Failing, and already failing before this session

Same counts at commit `743bc37` (before the Meshy defaults) as on this branch's tip, so not caused by this work:

| Test | Failures |
|---|---|
| chapter5_test | 39 (also at `1805cd5`) |
| chapter6_test | 1 (`c6_rs_talk_camera`) |
| chapter7_test | 15 |
| chapter11_test | 30 |
| chapter8_test, chapter12_test (2 Skitter-chase checks), death_test, chapter14_test (`c14_run_back`, `c14_run_done`) | identical on the original files / with `-- old_monsters` |

## Fixed in the test (not the game)

`opening_test` read `eddie_face._mat`, which the Meshy face wrapper does not have; the test crashed there and printed no result. It now accepts either face type.
See the end of this file for the result of the re-run.

## Not covered

Camera paths and anything that depends on rendering (the headless renderer is a dummy).

## opening_test: unresolved

Three full runs on this branch, no failed check in any of them, but none reached a RESULT line:
- run 1 ended silently right after `saved_in_car` (the reload of the world while driving);
- run 2 got to 75 passed checks (the game-shop section) and hit the 1500 s limit;
- run 3 (after the `_mat` test fix) again ended silently after `saved_in_car` (64 passed, no error text).
At commit `743bc37` the same test passed in one run (0 failures). So it is either a flaky headless crash on the world reload or something this branch changed in that reload;
not yet told apart. Needs a run on a machine without other Godot processes, or a bisect of the reload step.
