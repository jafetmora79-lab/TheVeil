# THE VEIL - Pack 09 Validation Report

Automated file, reference and engine checks only. **Nothing was captured from the renderer** (no screenshots), so the look of the mist, lighting and corruption has not been verified.

**Result: PASS** - 0 failures, 0 warnings

* GLB names unique across the repository: True
* textures checked: 21 (palette-locked; white effect masks allowed)
* GLBs checked: 27, triangles total 4008
* files scanned for references / unsupported features: 110, res:// references 186
* Khronos glTF-Validator: 27 files, 0 errors, 0 warnings
* Godot 4.3 headless import: exit 0, 0 error/warning lines
* renderer: OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
* presets loaded as VeilAtmospherePreset: 13/13
* GLBs instanced and rendered: 27/27
* scenes instanced and rendered (3 frames each): 23 + demo
* `DEMO flicker_nodes=23 corruption_nodes=14`
* `STATE 0 fog=0.0040 ambient=0.55 mist=0.00 corr_visible=0 rain=false`
* `STATE 1 fog=0.0080 ambient=0.45 mist=0.15 corr_visible=0 rain=false`
* `STATE 2 fog=0.0200 ambient=0.42 mist=0.45 corr_visible=5 rain=false`
* `STATE 3 fog=0.0550 ambient=0.46 mist=0.80 corr_visible=11 rain=false`
* `STATE 4 fog=0.0400 ambient=0.38 mist=0.60 corr_visible=14 rain=false`
* `TWEEN ok fog=0.0400`

## Failures

None.

## Warnings

None.
