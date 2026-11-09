# Running validation

Base revision e912a13d4c2d4e380b9b1848151348a11e0ed990, from claude/chapter7-trace-of-noah.

Added files

- game/animation/running_pose.gd supplies reusable running rotations and a vertical pelvis offset.
- game/tests/anim_running_test.gd loads three real GLB rigs, prepares their arms-down rest, and applies 241 samples across a complete cycle.
- docs/animation/INTEGRATION.md gives the exact optional hooks for the gameplay owner.
- This document records measured results and reproduction instructions.

Godot 4.3 stable was run headless. No editor was opened. The test checks helper instantiation, normalized finite quaternions, hip/knee/elbow rotation bounds, planted Foot/Toes heights, actual ankle translation during stance, zero weight and loop endpoint rotations.

Measured across protagonist, Eddie and Marcus

- Maximum planted height error 0.001068 m, below the required 0.02 m.
- Maximum horizontal ankle drift during contact 0.000209 m.
- Maximum loop endpoint quaternion angle 0.000691 radians, approximately 0.040 degrees including floating-point comparison error.
- All three rig tests passed.

For a normal imported project run

```sh
godot --headless --path . --script res://game/tests/anim_running_test.gd
```

For isolation from gameplay autoloads, as used for the recorded measurements, create a temporary minimal Godot project outside the repository. Symlink its `game` and `THE_VEIL_ASSETS_V2` directories to this checkout. Its project.godot only needs `config_version=5`. Run the same test with `--path` pointing to that temporary project. GLBs are loaded directly with GLTFDocument at runtime, so an editor import is unnecessary.

Optional preview data can be exported by adding `-- --preview-output=/absolute/path/poses.json`. This exports actual skinned protagonist mesh frames at every fourth sample. Preview data is only allocated when that option is supplied. The preview GIF was rendered separately from that data and contains one repeating run cycle.

All added GDScripts were also checked with Script.can_instantiate(). No gameplay integration, Windows/Android execution, terrain tests or subjective visual quality claims are included in these results.
