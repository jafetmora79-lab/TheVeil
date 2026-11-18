# THE VEIL — full game audit (2026-11)

Authoritative branch: `claude/practical-cray-hi2y54` @ `1f9d5b8` (per `CLAUDE.md`: all other branches merged). Audit branch: `audit/full-game-review-2026`. Nothing merged.

**Limits:** cloud container, headless Godot 4.3 dummy renderer. No screenshots, no Windows launch, no Blender. Visual, audio-feel, animation-quality and performance conclusions are therefore *not* made here.

## Overall condition
Logic is in good shape: all 16 chapter starts load, the opening passes (237 checks), chapters 10, 11, 14, 15, 16 pass, `qa_softlock`, `retry`, `navigation`, `map`, `edge_bounds`, `loading_door`, `stock_door`, `tentacle_entrance`, `inventory_layout`, `handwash` pass. One critical softlock (VB-003) was found and fixed; two high-severity robustness issues fixed (VB-001, VB-002). Remaining open items are medium/low and listed in `docs/VERIFIED_BUGS.md`.

## What was audited, by area
- **Assets/GLB:** parsed with Python (no bpy); see `docs/BLENDER_DESKTOP_REPAIR_PLAN.md` for what needs a desktop Blender.
- **Progression/save:** flags, chapter numbering, save atomicity (fixed), checkpoints, chapter select.
- **Gameplay logic:** note reading (fixed), car exit (fixed), pay-before-you-leave, death/retry, supply chest, shelter exit menu, NPC placement (`audit_npc_placement_test`, one failure in Ch.10), house reachability.
- **UI:** inventory sizing at test resolutions (no overflow); text shrinks at 720p — visual check needed. The inventory lists all items (owner earlier said "only usable"): confirm intent.
- **Horror presentation (qualitative rubric from the supplied horror-writing skill, no new dialogue written):** dread depends on restraint and withheld information; the Garage tentacle (10 s window) and mist/Colossus beats are structured that way in code. Whether they land is *needs your visual test*.

## Documented, not changed (high risk / owner decision)
1. **Stairs vs `DestroyedCol` in 21 of 25 wrecked houses** (VB-004). Fix would alter the destruction collision set.
2. **NPC baked animation / procedural poses** (`npc_animator.gd`): changing it is a redesign; the roof Skitter appearing to float is documented by the author and needs a Windows visual test.
3. **Follower lag** (VB-005) and late-chapter stalls (VB-006): need on-PC repro before touching AI.
4. **Sidewalk dark marks:** undiagnosed; needs a look in Blender/Godot editor.
5. **SAVE_VERSION** unchanged; no migration exists.
6. Tests that overwrite the real save (VB-007).

## Needs your visual test (nothing here is claimed fixed)
Trailer shots, Colossus walk, Eddie head turn, mist, roof Skitter, wrecked-house interiors, all 16 chapter starts on Windows, ending sequences, inventory text at 720p, sidewalk marks.
