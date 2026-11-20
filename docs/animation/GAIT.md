# Walk / run gait (procedural, distance-driven)

`game/animation/gait_pose.gd` + `NpcAnimator` (`_update_walk`, `_pose`). Replaces the sine walk while moving; talk, look-at
(layered on neck/head), seated and jump keep priority (gait weight 0). Physics/path movement is untouched.

- Phase advances by real displacement / cycle length (`moved / _cyc * TAU`), so planted feet do not slide at any speed.
- Cycle length, stance fraction, lift, pelvis dip, arm swing, lean are tables of ground speed (`gait_pose.gd`), scaled by
  the rig's leg length and a per-character profile (`profile_for`: Eddie short/guarded, Marcus forward, Ruth economical, Sarah stable).
- Starts begin in the passing pose with alternating lead foot; stopping fades the gait out over ~0.2 s.
- Player: first-person head bob now advances one bob per footfall using the same step length (amplitudes unchanged; the
  head_bob setting still disables it).

## Measured (headless, `game/tests/gait_test.gd`, 5 rigs x 1.25 / 2.4 / 4.3 m/s)
Planted-foot slip 0.4-10 mm; toes within 3 mm of the floor; loop seam < 0.002 rad; no joint pop at start/arrival.

## Deviations / not done
- The brief's 1.20 m step at 2.4 m/s and 30/28-frame cycles are not reachable with these ~0.67-0.74 m legs. Cadence is
  leg-limited instead: ~180 steps/min at 1.25 m/s, ~210 at 2.4, ~240 at 4.3 (short-legged rigs). Pelvis drops 6-15 cm (bent knees).
- No Blender clips (procedural poses only). No heel-strike roll in stance (flat foot; heel rise at toe-off only).
- Not implemented: strafe/backpedal, sharp-turn steps, stairs/uneven-ground foot correction, injury limp, viewmodel/hand layer,
  footstep audio retiming (recorded loops are pitch-scaled by speed as before).
- Needs your visual test: everything about how it looks, incl. the cadence of small characters at 2.4 m/s.
- `opening_test` does not finish headless here (stops at a pre-existing `VeilMeshyNpcFace._mat` error); not re-verified.
