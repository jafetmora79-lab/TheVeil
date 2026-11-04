# THE VEIL - Pack 05 Vehicles & Transportation

When this pack was started, the repository had no vehicles in any pack. Everything here is new except the reused props
listed below.

Rebuild with `python3 05_Vehicles/Source_Scripts/build_vehicles.py` (deterministic). Validate with
`validate_vehicles.py`; the result is in `VALIDATION_REPORT.md`.

## Conventions (all vehicles)

* **Units and axes:** metres, +Y up, **forward = -Z** (Godot forward), **left = -X**. Left-hand drive: the driver sits
  on -X.
* **Origin:** at ground level, centred across the width and midway between the axles. The tyres touch y = 0.
* **Materials:** 3 per vehicle, all on one 256 px palette-locked atlas with nearest filtering:
  * `M_Veh_Atlas` (opaque);
  * `M_Veh_Glass` (alpha, double-sided);
  * `M_Veh_Lights` (emissive head and tail lamps).
* **Abandoned variants:** these use `M_Veh_Atlas_Weathered`, `M_Veh_Glass_Dirty` and `M_Veh_Lights_Off` instead. The
  geometry is the same; only the material and the pose change.
* **Collision:** each vehicle has simple convex boxes (`Collision_*-convcolonly`), which Godot imports as StaticBody3D
  shapes. Parked and abandoned cars are therefore obstacles straight away. For a future driving controller, move or
  copy these shapes under the VehicleBody3D.

## Movable parts (separate nodes, origin = pivot)

| Node | Pivot | Rotate about |
|---|---|---|
| `Wheel_FL/FR/RL/RR` | wheel centre | local X = spin; local Y = steer (front wheels) |
| `SteeringWheel` | hub, on the tilted column | local Z = column axis |
| `Door_FL/FR/RL/RR` | front (hinge) edge, mid height | local Y. Opening angle: negative on the left (-X) doors, positive on the right |
| `Hood` | rear edge, by the windshield | local X, positive angle opens |
| `Trunk` | front edge, by the rear window | local X, negative angle opens |
| `Tailgate` (pickup) | bottom edge | local X, +90 deg = fully down |
| `RearDoor_L/R` (van) | outer vertical edge | local Y |

Behind each lid and door there is real geometry: the engine bay, the trunk well, the cabin, the cargo bed or the cargo
box.

## Markers (empty nodes inside each vehicle GLB)

These markers are in every vehicle GLB:

* `Marker_Seat_Driver` and `Marker_Seat_Passenger` (hip points). The sedan and the police cruiser also have
  `Marker_Seat_Rear_L/R`.
* `Marker_Camera_FirstPerson` (the driver's eye).
* `Marker_Entry_Driver` and `Marker_Entry_Passenger` (on the ground beside the doors).
* `Marker_Headlight_L/R` and `Marker_Taillight_L/R`.

## Protagonist's sedan (`Protagonist_Sedan/VEH_ProtagonistSedan.glb`) - priority 1

* **Car:** an older early-2000s mid-size sedan in muted slate blue (the fictional "Vale"). It is 4.82 x 1.77 x 1.44 m;
  2.07 m wide across the mirrors. The wheelbase is 2.72 m; the tyres are about 0.62 m in diameter.
* **Exterior:**
  * body with real wheel arches; hood, trunk and 4 doors;
  * headlights, taillights and indicators, grille, front and rear plates (`4KJ-219`, fictional);
  * side mirrors and door handles, wipers, A- and B-pillars, a trunk badge;
  * bumpers with rub strips;
  * the underside: floor pan, exhaust and muffler, fuel tank, axles, wheelhouse liners.
* **Interior** (built as geometry, not flat textures):
  * driver and passenger bucket seats with headrests, and a rear bench;
  * dashboard with cluster hood, instrument cluster, centre stack, vents and glovebox;
  * steering column and a 3-spoke wheel;
  * console with gear selector, brake and accelerator pedals;
  * door cards, headliner, carpet floor, parcel shelf, rear-view mirror.
  * From `Marker_Camera_FirstPerson` the driver should see the wheel, cluster, windshield, hood, side windows, mirror
    and passenger seat. The validator checks this by casting rays from the eye marker through the real triangles:
    * the road is visible through the windshield;
    * the middle of the hood is visible over the wheel rim;
    * the gauges are visible between the hub and the rim;
    * the rear-view mirror and the left window are visible.

    This is geometry, not a render.
* **`Godot_Scenes/Protagonist_Sedan.tscn`:** the reusable scene. Its nodes:
  * `ProtagonistSedan` (Node3D, metadata `vehicle_id`);
  * `Model` (the GLB, including all parts and markers);
  * `DriverCamera` (Camera3D on the eye marker, `current = false`);
  * `Lights/Headlight_L/R` (SpotLight3D) and `Lights/Taillight_L/R` (OmniLight3D), all hidden by default;
  * `Interaction/EntryArea_Driver` and `EntryArea_Passenger` (Area3D and box shape, no script).
* **`Godot_Scenes/Greyhaven_Opening_Driveway.tscn`:** parks the sedan on the PLAYER_HOME driveway of the Pack 03 town,
  nose towards the street (x 31, z -94.2, y 0.15).
* There is no driving code (no VehicleBody3D), as requested.

## Other vehicles - priority 2

* **`Police_Cruiser/VEH_PoliceCruiser.glb`:** Greyhaven Police (fictional).
  * Black-and-white livery, "POLICE" and "GREYHAVEN PD" markings, roof number 07, `GHPD-07` plates.
  * Red/clear/blue lightbar, push bar, A-pillar spotlight, antenna.
  * Prisoner partition and vinyl seats.
  * The same movable parts as the sedan.
* **`Pickup/VEH_PickupTruck.glb`:** a regular-cab pickup.
  * Cargo bed with notched sides, wheel tubs and bedliner.
  * Drop-down `Tailgate` with "GRANGER" stamped on it (fictional).
  * Chrome bumpers, tall taillights, bench seat, cab back with a rear window.
* **`Delivery_Van/VEH_DeliveryVan.glb`:** the Harlow Bakery van (fictional livery).
  * Cargo box with plywood floor, metal walls, wheel tubs and a partition wall.
  * Two hinged rear doors; cab doors with quarter glass; two seats.

## Variants - priority 3

* **`Traffic_Variants/`:** green and beige sedans for ordinary traffic during the opening drive.
* **`Abandoned_Variants/`:**
  * `VEH_Sedan_Dusty`;
  * `VEH_Sedan_Damaged` (cracked windshield, missing passenger window, driver door open, hood sprung);
  * `VEH_PoliceCruiser_Abandoned` (front doors open);
  * `VEH_Pickup_Abandoned` (flat tyres, tailgate down);
  * `VEH_DeliveryVan_BrokenDown` (hood up, rear door open);
  * `Roadside_BrokenDown_Van.tscn` (the van with a warning triangle, gas can, spare and Pack 02 cones).

## Transportation props

* **New** (in `Transportation_Props/`): `TRN_Tire`, `TRN_SpareTire`, `TRN_WheelRim`, `TRN_GasCan` (with a `Grip`
  marker), `TRN_EmergencyTriangle`.
* **Reused, not duplicated:**
  * Pack 02 `SP_TrafficCone`, `SP_RoadBarrier`, `SP_ParkingMeter`, `SP_Sign_BusStop`, `SP_Bench_Wood` and
    `SP_BusShelter`;
  * Pack 09 bicycle and shopping cart, stood upright by `TRN_Bicycle.tscn` and `TRN_ShoppingCart.tscn`. These scenes add
    a transform only.

## Textures

* `T_Veh_Atlas.png` contains:
  * paints: slate blue, sage green, beige, black, white, faded red, van white;
  * trim, chrome, steel, glass, mirror, rubber, tyre tread and sidewall, rims and hubcap;
  * seat fabrics, vinyl, carpet, headliner, dash plastic, bedliner, plywood, cargo wall;
  * engine bay, lenses, plates, cluster, centre stack, door card, police and bakery liveries, cracked glass.
* `T_Veh_Atlas_Weathered.png` is the same layout with dust settled towards the bottom of each patch, rust blooms on the
  paint, and milky glass.
* Pack 01 textures are not applied directly. Using them would add 10-15 separate materials (and draw calls) per car. The
  atlases are painted from the same Pack 01 palette ramps instead, so the colours match the town.

## Limitations

* No screenshots or renders were made, so the look has not been checked by eye. The validation is structural and
  engine-load only.
* The doors open, but the door openings have no rubber seals or jamb detail. The glass is single-layer.
* There are no LODs. Each vehicle is about 2-2.6 k triangles, so none are needed at the town's scale.
* No driving physics, animation or interaction scripts.
* The gallery is a browser viewer: you can orbit around each GLB but not step inside it. The interior is best checked
  in Godot from `DriverCamera`.
