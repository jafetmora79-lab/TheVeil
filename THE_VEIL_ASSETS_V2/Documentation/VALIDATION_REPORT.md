# THE VEIL - Pack 01 Validation Report

Automated file/data checks only. **Visual quality is NOT verified by this report** - it must be judged by a person in Godot.

- Textures checked: 72
- Failures: 0
- Warnings: 0

Checks: file exists, PNG readable, resolution = spec, RGB/RGBA mode matches transparency, alpha actually used and decal borders clear, every colour from the master palette, not flat/placeholder, not duplicate, seam continuity on tiled axes, .import lossless+mipmaps, material exists and points at the right texture, transparency/filter/UV scale consistent, manifest complete, atlas cells match sources.

Seam A/B (see seam_metrics): A = wrap-edge jump vs. average interior jump (damped); B = wrap-edge jump vs. the strongest deliberate interior lines. Fail only if A > 1.6 AND B > 1.25. This catches gross wrap breaks; subtle seams still need a visual check in Godot. Orphans = share of pixels with no same-colour 4-neighbour (high values suggest noise rather than pixel clusters).

## Per-texture metrics

| ID | Res | Tiles | Alpha | Colours | Dominant | Orphans | Seam U | Seam V | Alpha cover |
|---|---|---|---|---|---|---|---|---|---|
| `Arch_SidingWhite` | 128x128 | uv | none | 7 | 38% | 0% | 1.31/0.35 | 2.37/0.58 | - |
| `Arch_SidingBlue` | 128x128 | uv | none | 7 | 39% | 0% | 1.24/0.29 | 1.61/0.32 | - |
| `Arch_SidingGreen` | 128x128 | uv | none | 7 | 39% | 0% | 0.74/0.06 | 1.44/0.28 | - |
| `Arch_WoodPlanksAged` | 128x128 | uv | none | 7 | 46% | 1% | 0.64/0.15 | 2.55/0.54 | - |
| `Arch_BrickRed` | 128x128 | uv | none | 9 | 28% | 1% | 1.13/0.50 | 1.99/0.65 | - |
| `Arch_BrickWeatheredBrown` | 128x128 | uv | none | 10 | 29% | 1% | 0.78/0.30 | 1.62/0.54 | - |
| `Arch_ConcreteFoundation` | 128x128 | uv | none | 8 | 49% | 3% | 2.09/0.64 | 4.40/0.72 | - |
| `Arch_RoofShinglesDarkGray` | 128x128 | uv | none | 6 | 36% | 6% | 1.12/0.41 | 3.90/0.81 | - |
| `Arch_RoofShinglesBrown` | 128x128 | uv | none | 6 | 24% | 7% | 0.49/0.17 | 3.04/0.68 | - |
| `Arch_RoofTilesWeathered` | 128x128 | uv | none | 10 | 21% | 3% | 1.49/0.55 | 1.74/0.43 | - |
| `Arch_TrimPainted` | 64x64 | uv | none | 6 | 38% | 1% | 0.60/0.13 | 0.76/0.31 | - |
| `Arch_WindowGlassDirty` | 64x64 | none | blend | 6 | 25% | 6% | - | - | 100% |
| `Road_Asphalt` | 256x256 | uv | none | 7 | 51% | 4% | 1.12/0.65 | 0.94/0.53 | - |
| `Road_AsphaltCracked` | 256x256 | uv | none | 9 | 35% | 5% | 0.50/0.11 | 1.14/0.57 | - |
| `Road_SidewalkConcrete` | 128x128 | uv | none | 7 | 42% | 12% | 8.41/1.20 | 4.63/0.98 | - |
| `Road_ConcreteCracked` | 128x128 | uv | none | 14 | 45% | 3% | 0.34/0.08 | 1.34/0.58 | - |
| `Road_CurbConcrete` | 64x64 | uv | none | 7 | 62% | 1% | 0.81/0.05 | 0.58/0.13 | - |
| `Road_ParkingLotAsphalt` | 256x256 | uv | none | 7 | 44% | 3% | 0.80/0.27 | 0.85/0.27 | - |
| `Road_MarkingYellow` | 64x64 | uv | blend | 5 | 54% | 3% | 1.14/0.49 | 1.11/0.60 | 90% |
| `Road_MarkingWhite` | 64x64 | uv | blend | 5 | 40% | 2% | 0.67/0.19 | 0.77/0.37 | 65% |
| `Road_Gravel` | 128x128 | uv | none | 12 | 35% | 10% | 1.47/0.93 | 1.29/0.90 | - |
| `Road_DirtRoad` | 256x256 | uv | none | 12 | 48% | 2% | 1.06/0.54 | 0.86/0.36 | - |
| `Road_RoadPatch` | 128x128 | uv | none | 8 | 50% | 2% | 0.84/0.32 | 1.27/0.48 | - |
| `Grnd_GrassShort` | 128x128 | uv | none | 9 | 44% | 20% | 0.94/0.52 | 1.02/0.60 | - |
| `Grnd_GrassOvergrown` | 128x128 | uv | none | 9 | 34% | 19% | 0.75/0.53 | 1.17/0.91 | - |
| `Grnd_GrassDry` | 128x128 | uv | none | 12 | 33% | 20% | 0.98/0.69 | 0.62/0.39 | - |
| `Grnd_Mud` | 128x128 | uv | none | 8 | 42% | 2% | 1.14/0.54 | 0.94/0.48 | - |
| `Grnd_Soil` | 128x128 | uv | none | 8 | 27% | 4% | 1.26/0.81 | 1.26/0.79 | - |
| `Grnd_LeavesFallen` | 128x128 | uv | none | 15 | 20% | 12% | 1.10/0.74 | 0.96/0.55 | - |
| `Grnd_Moss` | 64x64 | uv | none | 6 | 27% | 12% | 1.19/0.83 | 1.32/0.94 | - |
| `Grnd_TreeBark` | 128x128 | uv | none | 8 | 27% | 2% | 1.34/0.62 | 1.05/0.44 | - |
| `Grnd_HedgeFoliage` | 128x128 | uv | none | 7 | 25% | 21% | 0.95/0.76 | 0.91/0.70 | - |
| `Grnd_DeadVegetation` | 128x128 | uv | none | 9 | 46% | 16% | 1.18/0.86 | 1.16/0.94 | - |
| `Int_DrywallLight` | 128x128 | uv | none | 4 | 53% | 1% | 1.23/0.82 | 0.96/0.21 | - |
| `Int_WallpaperFaded` | 128x128 | uv | none | 7 | 60% | 1% | 2.65/0.35 | 1.27/0.66 | - |
| `Int_WallpaperPatterned` | 128x128 | uv | none | 8 | 59% | 6% | 2.90/1.06 | 0.63/0.18 | - |
| `Int_FloorboardsOld` | 128x128 | uv | none | 8 | 34% | 1% | 0.61/0.09 | 3.80/0.78 | - |
| `Int_CarpetWorn` | 128x128 | uv | none | 5 | 35% | 7% | 1.21/0.58 | 0.82/0.38 | - |
| `Int_TilesKitchen` | 128x128 | uv | none | 13 | 24% | 0% | 5.11/0.79 | 6.06/0.99 | - |
| `Int_TilesBathroom` | 128x128 | uv | none | 8 | 39% | 0% | 3.37/0.94 | 3.39/0.83 | - |
| `Int_Linoleum` | 128x128 | uv | none | 6 | 33% | 0% | 2.89/0.70 | 4.41/1.11 | - |
| `Int_BasementConcrete` | 128x128 | uv | none | 8 | 62% | 2% | 0.93/0.32 | 1.11/0.32 | - |
| `Int_PlasterDamaged` | 128x128 | uv | none | 13 | 34% | 2% | 1.43/0.74 | 1.16/0.43 | - |
| `Furn_WoodLight` | 64x64 | uv | none | 5 | 70% | 2% | 0.51/0.10 | 1.01/0.65 | - |
| `Furn_WoodDark` | 64x64 | uv | none | 5 | 39% | 7% | 1.50/0.51 | 0.44/0.29 | - |
| `Furn_WoodPainted` | 64x64 | uv | none | 7 | 37% | 1% | 0.67/0.20 | 0.80/0.40 | - |
| `Furn_LeatherWorn` | 64x64 | uv | none | 6 | 40% | 8% | 0.98/0.62 | 1.11/0.70 | - |
| `Furn_FabricUpholstery` | 64x64 | uv | none | 6 | 45% | 3% | 0.94/0.76 | 1.05/0.82 | - |
| `Furn_Denim` | 64x64 | uv | none | 5 | 46% | 1% | 1.25/0.92 | 1.63/0.97 | - |
| `Furn_PlasticDirty` | 32x32 | uv | none | 4 | 42% | 2% | 0.51/0.13 | 0.37/0.06 | - |
| `Furn_MetalBrushed` | 64x64 | uv | none | 5 | 39% | 1% | 1.06/0.41 | 1.39/0.62 | - |
| `Furn_MetalRusted` | 64x64 | uv | none | 8 | 27% | 9% | 0.76/0.35 | 0.66/0.28 | - |
| `Furn_Rubber` | 32x32 | uv | none | 4 | 53% | 20% | 0.37/0.11 | 0.37/0.11 | - |
| `Furn_Cardboard` | 64x64 | uv | none | 5 | 43% | 4% | 1.63/0.81 | 0.82/0.11 | - |
| `Com_SupermarketFloorTiles` | 128x128 | uv | none | 7 | 39% | 5% | 5.82/1.10 | 4.71/1.07 | - |
| `Com_StorefrontBrick` | 128x128 | uv | none | 9 | 36% | 1% | 2.52/0.66 | 3.82/0.95 | - |
| `Com_StorefrontConcrete` | 128x128 | uv | none | 6 | 53% | 1% | 0.86/0.04 | 0.51/0.01 | - |
| `Com_CeilingTiles` | 128x128 | uv | none | 7 | 44% | 8% | 3.24/0.58 | 4.08/0.87 | - |
| `Com_MetalShelving` | 64x64 | uv | none | 6 | 64% | 6% | 0.42/0.09 | 0.56/0.18 | - |
| `Com_MetalDoorPainted` | 64x128 | none | none | 12 | 53% | 0% | - | - | - |
| `Com_GasStationPavement` | 256x256 | uv | none | 8 | 60% | 1% | 18.72/0.70 | 18.92/0.68 | - |
| `Com_SignageBacking` | 64x64 | uv | none | 9 | 56% | 1% | 0.69/0.22 | 0.32/0.02 | - |
| `Com_StorageConcrete` | 128x128 | uv | none | 9 | 38% | 3% | 4.23/1.03 | 5.91/1.00 | - |
| `Com_IndustrialWallDirty` | 128x128 | uv | none | 13 | 28% | 0% | 0.39/0.12 | 0.40/0.00 | - |
| `Hor_StainOrganicDark` | 64x64 | none | blend | 4 | 46% | 1% | - | - | 35% |
| `Hor_DampWall` | 128x128 | uv | none | 9 | 32% | 5% | 0.45/0.11 | 0.26/0.02 | - |
| `Hor_ResidueStrange` | 64x64 | none | blend | 5 | 52% | 0% | - | - | 18% |
| `Hor_FoliageDead` | 64x64 | none | scissor | 8 | 22% | 6% | - | - | 28% |
| `Hor_WarningSignWeathered` | 64x64 | none | scissor | 10 | 48% | 0% | - | - | 99% |
| `Hor_GroundMistCorrupted` | 128x128 | uv | none | 13 | 36% | 18% | 1.25/0.84 | 0.87/0.43 | - |
| `Hor_WoodDarkened` | 128x128 | uv | none | 9 | 51% | 1% | 0.96/0.23 | 1.36/0.45 | - |
| `Hor_GrimeAbandoned` | 128x128 | uv | blend | 5 | 27% | 13% | 1.09/0.56 | 0.95/0.55 | 46% |
