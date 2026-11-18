# Local changes to URSC v1.4.0 (Ultimate Retro Shader Collection, MIT, Zorochase)

- Godot 4.3 does not resolve relative `#include` paths, so the 14 spatial shaders that said
  `#include "../common.gdshaderinc"` now say `#include "res://addons/ursc/spatial/common.gdshaderinc"`.
  Nothing else in the pack was changed.
- `setup.gd` was NOT run: the nine shader globals it adds (plus `vertex_snap_resolution`, used with
  `#define OVERRIDE_VERTEX_SNAP_RESOLUTION`) were written into `project.godot` `[shader_globals]` by hand.
- Nothing in the game uses these shaders yet. The globals are not driven at runtime (fog, snapping resolution and
  so on keep their defaults); that needs a game script when a material starts using them.
- Compile check: `tools/check_ursc_shaders.sh` (needs `xvfb-run`; software GL, compile only).
