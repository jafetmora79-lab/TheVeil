# Marcus v4 running variants

- `Marcus/CHR_Marcus_v4_Run.glb`: original worried face, looping in-place run (`Run`).
- `Marcus/CHR_Marcus_v4_Scared_Run.glb`: same run with a scared pixel face (`Run_Scared`).
- The v4 source was promoted upstream to `CHR_Marcus.glb`; that asset is preserved. The builder accepts either source filename. Geometry, materials, rig and skin weights are unchanged. Only the scared variant changes the embedded head texture.
- 0.72-second cycle, 25 samples, 20 rotation tracks and hip translation. No root travel; move the character controller separately. Enable looping in Godot AnimationPlayer; glTF itself does not standardize playback looping. These are authored clips, not motion capture.
- The stride has distinct landing, push-off, flight and recovery phases. The shin folds back toward the thigh during recovery, and the support boot meets the floor during stance.
- Scared face retains the 128x64 UV layout, palette, stubble and nose, with wide eyes, raised inner brows and a small open mouth. This is a static texture expression, not a facial rig.
- Gallery: choose either variant under Pack 06. Playback starts automatically; the docs gallery has animation selection and Play/Pause controls.

## Rebuild

Install numpy and Pillow, then run `python THE_VEIL_ASSETS_V2/06_Characters/Source_Scripts/animate_marcus_v4.py` from the repository root.

## Validation

Khronos glTF validator 2.0.0-dev.3.10: both variants have zero errors and four inherited NODE_SKINNED_MESH_NON_ROOT warnings. All original geometry/skin accessors compare exactly to v4; all animation tracks have identical first and last samples, finite values and normalized rotation quaternions. JavaScript syntax check passes. Both knees were checked in world space at all 25 samples per clip (25.3 to 103.9 degrees of flexion in the correct direction). A textured side-view preview was inspected across eight poses. Godot runtime import and browser playback have not been visually tested.

