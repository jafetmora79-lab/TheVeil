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

## Run rework (2026-11-20)

**What drives the NPC run:** `NpcAnimator._pose()` -> `Gait.sample()` (`game/animation/gait_pose.gd`), procedural and distance-driven, for every NPC (the Meshy models share the Mixamo-style bone names). `running_pose.gd` (the "RunPose" helper in INTEGRATION.md) and the Marcus V4 run GLB (`CHR_Marcus_v4_Run.glb`, `MARCUS_V4_ANIMATION.md`) are **not** used by gameplay. The model's forward is -Z (`NpcAnimator.F`), left/right bones are `Left*` / `Right*` and measured from the rig.

**Before:** a run had no flight (both feet were never off the floor: 0 % airborne), 240-300 steps/min, the swing leg locked straight for ~5 % of the cycle before landing (knee 2 deg, then a 30 deg/frame snap on touchdown), heel lift only in the last 12 % of stance.

**Changes:**
- Ground contact per foot at a run 0.40 -> 0.30 of the cycle (0.28 at 5.5 m/s): a real flight phase (both feet off around 37 % and 87 % of the loop).
- Tables extended to 5.5 m/s (the companions run at 5.4); bigger lean (chest 14 deg at 4.3 m/s, hips-to-neck reads 8 deg, neck/head counter-rotate so the eyes stay level), arm swing 42 deg, elbows opened to 85-105 deg interior, pelvis yaw 6 deg.
- Toe push-off: from mid-stance the heel rises (up to 36 deg) while the ball stays planted, the toes finish the push; the swing heel is picked up early (lift peaks at ~40 % of the swing, 270-290 mm) and the shin then unfolds toward landing.
- Weight shift: pelvis roll (3 deg at 4.3 m/s), the supporting hip higher, the spine counter-rolls so the shoulders stay level.
- The knee is never locked at a run (95 % of the leg instead of 98.5 %): the foot lands with a soft knee; the hips sit a few cm lower.
- `NpcAnimator`: ground speed ramps at 7 m/s^2 (walk -> run is an acceleration, not a step).

**Measured** (`game/tests/run_pose_test.gd`, 5 rigs x 4.3 / 5.4 m/s; `gait_test.gd` still passes): airborne 17-30 % of the time, heel up with the ball down 44-54 frames per 240, planted ball slip 1.7-16 mm, steady-run knee/hip peak 15.8 deg per frame (was 23), walk -> run peak 24 (was 31), pelvis higher in flight than in stance, opposite arm and leg at left contact, supporting hip higher, knees bend forward, hands stay on their own side, toes never below -15 mm.

**Deviations:** cadence is leg-limited, not 0.72 s: with these ~0.7 m legs a 4.3 m/s run is a 0.52-0.58 s cycle (207-278 steps/min; 0.72 s fits ~3.3 m/s); first-person arms/camera not touched; no heel-strike roll at landing; the head/neck counter-rotate the lean but the pelvis bob (5 cm) still moves the head (no vertical head stabilisation).
**Needs your visual test:** everything about how it looks. Preview: `godot --path . res://game/prototypes/npc_meshy/NpcRunTest.tscn` (all characters running side by side; add `-- side` for the side view of four).

### Run, second pass: upper body, hands, gaze, chase reaction (2026-11-20)

- **Torso:** run lean 20 deg (spine + chest), hips-to-neck reads ~12 deg; neck/head counter-rotate so the eyes stay on the path ahead.
- **Gaze:** while running (`_running_now()`) the head looks straight ahead, ignoring the look-at that turns NPCs toward the camera/player (a scene's held `look_target` still wins).
- **Arms:** forward swing 24 deg, back swing 58 deg (asymmetric, smooth), elbow flexion 60 deg open on the back swing / 80 deg closing forward; the scared "guard" hand-lift only applies to walking/standing (it faded out with run speed). Per-character `arms` styles fade to a full run swing as speed rises (Ruth's back elbow was 7 cm behind the spine before).
- **Hands:** a loose finger curl (index..little, three joints, ~0.25 walking / 0.55 running of 40/55/30 deg), measured per rig (`_measure_fingers`: knuckle axis signed toward the palm); open during a reaction.
- **Chase reaction** (`NpcAnimator.react(seconds, side)`; `chase_reactions` = automatic every 5-9 s while running scared): one hand comes up beside the shoulder (arm 50 deg forward + 35 deg out, forearm 105 deg, twist `react_twist_deg` = -120 so the open palm shows outward), the head glances ~0.66 rad to that side, ~0.8 s, then back to the run.
- **Toe push-off geometry fixed:** the ankle now moves forward and up by exactly what the rising heel would move the ball (`toe_len` and the new `toe_drop` measured from the rig): planted-ball slip at a run 16-27 mm -> 1.7-5.4 mm; walking slip 0.6-3.9 mm.
- **NpcAnimator:** ground speed accelerates at 5 m/s^2 (a gap between two paths keeps its speed; a stop decays at 14 m/s^2).

**Tests:** `game/tests/run_pose_test.gd` (all 15 distinct models: Protagonist, Eddie, Marcus, Noah, Ruth, Sarah, Lena, Frank, Officer, Cashier, Survivor, Civilian_A/B, Res_Walker, Res_Neighbour; two speeds, reaction, walk->run, run->stop) and `gait_test.gd` pass. Preview/recorder: `game/tests/npc_run_preview.gd` (needs a window; side / front / three / close views, `react`, `twist=<deg>`).
**Needs your visual test:** the real game camera and scenes (chases, the Hound, Frank), and the raised palm's direction (a single value to change).
