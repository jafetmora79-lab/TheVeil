# THE VEIL - Pack 05 Validation Report

Automated file, structure and engine checks only. **Nothing was captured from the renderer** (no screenshots), so the look of the vehicles has not been verified.

**Result: PASS** - 0 failures, 0 warnings

* GLB names unique across the repository: True
* atlases palette-locked: T_Veh_Atlas.png, T_Veh_Atlas_Weathered.png
* driver sightlines (ray casts from the eye marker: road through the windshield, hood over the wheel rim, cluster past the wheel hub, steering wheel, rear-view mirror, left window) checked on 9 vehicles with closed driver doors
* GLBs checked: 16 (11 vehicles), triangles total 26912
* res:// references checked: 72; reused props present: 8
* gallery lists 16/16 Pack 05 GLBs, Pack 05 filter present: True
* Khronos glTF-Validator: 16 files, 0 errors, 0 warnings
* Godot 4.3 headless import: exit 0, 0 error/warning lines
* renderer: OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
* `SCENE Protagonist_Sedan.tscn cam_offset=0.0000 lights=4 areas=2 hinge_fixed=true`
* Godot (gl_compatibility): 16/16 GLBs instanced with external Pack 05 materials, separate wheel nodes and collision; 5 scenes instanced and rendered

## Assets

| Asset | Category | Tris | Size (m) | Movable parts | Status |
|---|---|---|---|---|---|
| `VEH_ProtagonistSedan` | hero vehicle | 2430 | 2.07 x 1.44 x 4.824 | Hood, Trunk, Door_FL, Door_FR, Door_RL, Door_RR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, SteeringWheel | pass |
| `VEH_PoliceCruiser` | vehicle | 2684 | 2.16 x 1.82 x 5.247 | Hood, Trunk, Door_FL, Door_FR, Door_RL, Door_RR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, SteeringWheel | pass |
| `VEH_PickupTruck` | vehicle | 2131 | 2.22 x 1.83 x 5.424 | Hood, Door_FL, Door_FR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, Tailgate, SteeringWheel | pass |
| `VEH_DeliveryVan` | vehicle | 2283 | 2.32 x 2.26 x 5.625 | Hood, Door_FL, Door_FR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, RearDoor_L, RearDoor_R, SteeringWheel | pass |
| `VEH_Sedan_Traffic_Green` | traffic variant | 2430 | 2.07 x 1.44 x 4.824 | Hood, Trunk, Door_FL, Door_FR, Door_RL, Door_RR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, SteeringWheel | pass |
| `VEH_Sedan_Traffic_Beige` | traffic variant | 2430 | 2.07 x 1.44 x 4.824 | Hood, Trunk, Door_FL, Door_FR, Door_RL, Door_RR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, SteeringWheel | pass |
| `VEH_Sedan_Dusty` | abandoned variant | 2430 | 2.07 x 1.44 x 4.824 | Hood, Trunk, Door_FL, Door_FR, Door_RL, Door_RR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, SteeringWheel | pass |
| `VEH_Sedan_Damaged` | abandoned variant | 2428 | 1.944 x 1.44 x 4.824 | Hood, Trunk, Door_FL, Door_FR, Door_RL, Door_RR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, SteeringWheel | pass |
| `VEH_PoliceCruiser_Abandoned` | abandoned variant | 2684 | 1.974 x 1.82 x 5.247 | Hood, Trunk, Door_FL, Door_FR, Door_RL, Door_RR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, SteeringWheel | pass |
| `VEH_Pickup_Abandoned` | abandoned variant | 2131 | 2.22 x 1.746 x 5.424 | Hood, Door_FL, Door_FR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, Tailgate, SteeringWheel | pass |
| `VEH_DeliveryVan_BrokenDown` | abandoned variant | 2283 | 2.32 x 2.26 x 5.625 | Hood, Door_FL, Door_FR, Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, RearDoor_L, RearDoor_R, SteeringWheel | pass |
| `TRN_Tire` | transportation prop | 128 | 0.62 x 0.2 x 0.62 | - | pass |
| `TRN_SpareTire` | transportation prop | 168 | 0.13 x 0.585 x 0.6 | - | pass |
| `TRN_WheelRim` | transportation prop | 112 | 0.37 x 0.13 x 0.38 | - | pass |
| `TRN_GasCan` | transportation prop | 100 | 0.17 x 0.427 x 0.362 | - | pass |
| `TRN_EmergencyTriangle` | transportation prop | 60 | 0.493 x 0.442 x 0.18 | - | pass |

## Failures

None.

## Warnings

None.
