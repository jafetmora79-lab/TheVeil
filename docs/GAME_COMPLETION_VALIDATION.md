# THE VEIL — completion validation (new game → each ending)

**Honest scope:** no run was played by a human, and no Windows build was launched. "Automated" = a headless test that sets up the chapter state and drives the scripted steps. That proves the logic and the flags, not how it looks or feels.

| Disp. ch. | Title | Source | Automated test | Result (this audit) | Manual / untested |
|---|---|---|---|---|---|
| 1 | An Ordinary Evening | world.gd | opening_test | PASS 237 | feel, visuals |
| 2 | One Last Stop | world.gd | opening_test, pay_first | PASS | visuals |
| 3 | The Veil Arrives | world.gd | opening_test, cinematic | PASS | Colossus framing |
| 4 | The Last Open Door | world.gd | opening_test | PASS | |
| 5 | Lock-In | phase4.gd | opening_test | PASS | |
| 6 | The First Search | chapter5.gd | chapter5_test (updated) | not re-confirmed (timed out in full run) | critical path judged OK by probes |
| 7 | Voices in the Mist | chapter6.gd | chapter6_test | 82 pass, 1 fail (Eddie lag, VB-005) | |
| 8 | A Trace of Noah | chapter7.gd | chapter7_test | softlock fixed (16 → 0 failures) | |
| 9 | Something at the Doors | chapter8.gd | chapter8_test | 95 pass, 3 fail (stale) | |
| 10 | The Fall of the Supermarket | chapter9.gd | chapter9_test | PASS 76 | |
| 11 | No Safe Road | chapter10.gd | chapter10_test | PASS 64 | |
| 12 | The Farm Road | chapter11.gd | chapter11_test | 65 pass, 1 fail (VB-006) | |
| 13 | The Truth Beneath Greyhaven | chapter12.gd | chapter12_test | 60 pass, 2 fail (VB-006) | |
| 14 | Into the Veil | chapter13.gd | chapter13_test | PASS 60 | |
| 15 | The Last Shelter | chapter14.gd | chapter14_test | PASS 52 | |
| 16 | What Remains | chapter15.gd | chapter15_test | PASS 70 | |

- Chapter select: `chapter_select_test` PASS 214 (every chapter 1–16 start, plus the menu path). Chapter starts are synthetic states, not played-through saves.
- **Endings:** `c15_all_endings_recorded` PASS for A, B, C (the endings file records all three). That the endings play correctly with cinematics, audio and final UI is **untested** (no screen).
- Chapter 16 was previously noted by the owner as possibly still having issues; not re-assessed beyond the test.
- Not run in this audit: the second half of the suite (`car_quest`, `town_destruction`, `final_repairs`, trailer tests, etc.) was still running when this was written; check `docs/AUDIT_HANDOFF.md` for what was and was not collected.
- Never done: a continuous new-game-to-ending playthrough, on any platform. Recommended: owner plays Chapter 1→16 on Windows once with saving on, after reading the open issues.
