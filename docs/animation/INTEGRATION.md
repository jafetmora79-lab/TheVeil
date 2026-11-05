# Running helper integration

This branch adds an optional full-body running pose. Gameplay does not use it until the owner applies these hooks. It animates the existing humanoid body rigs, including the protagonist, Eddie and Marcus. First-person arms and the player camera are outside this helper.

## Preparation in game/npc/npc_animator.gd

Add these member declarations beside `_phase`.

```gdscript
const RunPose = preload("res://game/animation/running_pose.gd")
var _run_pose := {}
var _run_weight := 0.0
var _run_thigh := 0.0
var _run_shin := 0.0
var _run_height := 0.0
var _run_neutral := Vector3.ZERO
```

At the end of `_ready()`, immediately after `_build_rest()`, measure the existing rig once and prepopulate the output dictionary. Distances are in skeleton-local units. This implementation assumes the unscaled shipped humanoid rigs and flat ground.

```gdscript
var hip := _gp("LeftUpperLeg").origin
var knee := _gp("LeftLowerLeg").origin
var ankle := _gp("LeftFoot").origin
_run_thigh = hip.distance_to(knee)
_run_shin = knee.distance_to(ankle)
_run_height = hip.y - ankle.y
var upper := atan2((knee - hip).dot(F), hip.y - knee.y)
var lower := atan2((ankle - knee).dot(F), knee.y - ankle.y)
_run_neutral = Vector3(upper, lower - upper, (ankle - hip).dot(F))
RunPose.sample(0.0, 0.0, RunPose.BONES, F, U, R,
    _run_thigh, _run_shin, _run_height, _run_neutral, _run_pose)
```

At the start of `_pose()`, before its first `_pose_bone()` call, sample once per frame. The helper returns skeleton-space rotations relative to the animator's existing arms-down rest. The dictionary and constant bone arrays are reused. There are no new movement or physics systems.

```gdscript
_run_weight = clampf(_run * _walk * (1.0 - _sit), 0.0, 1.0)
RunPose.sample(_phase, 1.0, RunPose.BONES, F, U, R,
    _run_thigh, _run_shin, _run_height, _run_neutral, _run_pose)
```

In `_pose_bone(n, q)`, immediately after the missing-bone guard and before `var pb`, blend into the sampled pose. Sampling uses full strength here because the weight is applied exactly once by the slerp.

```gdscript
if _run_pose.has(n):
    q = q.slerp(_run_pose[n], _run_weight)
```

At the end of `_pose()`, after its existing `skel.position.y` assignment, blend the vertical offset by the same weight.

```gdscript
skel.position.y = lerpf(skel.position.y, RunPose.bounce(_phase, 1.0), _run_weight)
```

The existing distance-driven phase already advances one cycle per 1.96 metres at full run, matching `RunPose.STRIDE`. Keep that relationship for planted feet. The helper replaces locomotion rotations while running, so owners should choose whether speech/look-at gestures take priority. No changes to those systems are included here.

## Scope and limitations

Contact lasts 38 percent of each leg cycle, with an overlapping flight phase between alternating contacts. The pelvis lowers by 14 cm and rises by 4.5 cm over each step. The two-segment analytical solve uses the measured thigh and shin lengths. Swing targets use a cubic curve whose endpoint velocities match stance. Arm swings trail the cycle by 0.18 radians, with elbow flexion from 66 to 90 degrees relative to the prepared rest.

The tests measure full-strength running on flat ground at constant forward speed. Partial walk/run blends, stairs, slopes, turning and abrupt speed changes need in-game verification after integration. Foot contact refers to the rig's Foot and Toes bones at their original floor-relative heights, including the existing shoe offset. It does not mean the ankle bone itself lies at zero height.

The supplied GIF is a CPU-rendered preview of the actual protagonist mesh and Godot-sampled bone poses, using sampled texture colours and simple lighting. It is an isolated animation preview, not an in-game capture.
