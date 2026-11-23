extends Node
class_name VeilChapter10
## THE VEIL - displayed CHAPTER 11 "No Safe Road" (internal ids keep the file's numbering: chapter10.gd, flags
## ch10_*, chapter_10_complete). Starts at the rendezvous right after "The Fall of the Supermarket" (flag
## chapter_9_complete); created by chapter9.gd. State: story flags + Game.world_state["ch10"].
##
## Eddie at the rendezvous (Ruth and Sarah's yard): the plan (Marcus's line only if he made it out) -> the group
## follows the player (the previous chapter's followers) along the street, down the open lot and onto the main
## road -> an abandoned sedan: driver's door, fuel gauge (empty), glove compartment (a battery), trunk (a bottle
## of water) -> the road west is blocked at x -46 (a broken-down van, a pickup and barriers wedged between the
## roadside building and the south wall) -> the side route: north through the gap at x -28, west behind the
## building to a chain-link fence, through its gate, back down to the road -> something follows them (a Hound's
## silhouette in the fog behind, gone behind a building; first person, no fight) -> Sarah can't go on (tired if
## she was treated, her wound if not): stop and help (an hour passes, a water or food item is used, or exposure is
## recorded) or keep moving (she stays exhausted) - never a death -> the outskirts: the old mill-worker house on
## the gravel road -> the entrance, the main room (empty), the group gathers -> the talk -> rest a few hours ->
## the window: the countryside beyond the fog, a distant sound -> "CHAPTER 11 COMPLETE". The next chapter is not
## started. Checkpoints at the start and the end go to their own files (never the player's save slot).

const STATE := "ch10"
const CHAPTER := 11                                    # displayed number (game/data/chapters.json)
const SEDAN := preload("res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Sedan_Dusty.glb")
const VAN := preload("res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_DeliveryVan_BrokenDown.glb")
const PICKUP := preload("res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Pickup_Abandoned.glb")
const BARRIER := preload("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_RoadBarrier.glb")
const CONE := preload("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_TrafficCone.glb")
const CHAINLINK := preload("res://THE_VEIL_ASSETS_V2/02_Town/Fences/FN_ChainLink_2.5m.glb")
const GATE := preload("res://THE_VEIL_ASSETS_V2/02_Town/Fences/FN_FenceGate_Privacy_1.25m.glb")
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"

# ---- world (collision-mapped: the main road z -6..6; a low roadside building along z -7 from x -49 to -13 with a
# 1 m gap at x -28; the south wall along z 7 from x -54 to -32; a building block x -43..-21, z -21..-35; open
# fields west of x -54; the mill-worker house at (-92, 14), front porch toward the road)
const ROUTE := [Vector3(51.0, 0.2, -57.5), Vector3(30.0, 0.2, -52.0), Vector3(4.0, 0.2, -47.0), Vector3(4.0, 0.2, -8.0),
	Vector3(-12.0, 0.2, 0.0), Vector3(-24.0, 0.2, 0.5)]
const CAR_POS := Vector3(-28.0, 0.15, 3.9)
const CAR_YAW := -PI * 0.5                             # parked on the south side, facing east; driver's door to the road
const BLOCK_X := -46.0
const SIDE_ROUTE := [Vector3(-28.0, 0.2, -3.0), Vector3(-28.0, 0.2, -11.0), Vector3(-40.0, 0.2, -13.2)]
const FENCE_X := -44.0
const FENCE_Z0 := -7.6                                  # the fence runs north (-z) from the roadside building
const GATE_Z := -12.6                                   # the gate leaf spans z -12.6 .. -13.85
const BACK_TO_ROAD := [Vector3(-48.0, 0.2, -13.2), Vector3(-51.5, 0.2, -10.0), Vector3(-52.5, 0.2, -2.0)]
const HOUND_PATH_PTS := [Vector3(-17.0, 0.0, -15.0), Vector3(-18.5, 0.0, -37.0), Vector3(-30.0, 0.0, -38.5)]
const CHOICE_X := -60.0
const OUTSKIRTS_X := -76.0
const HOUSE := "MILL_HOUSE"
## ---- directed-moment markers (WORLD; y is found by probing the floor when used). Validated by game/tests/chapter10_staging_test.gd.
const DRIVER_STAND := Vector3(-27.45, 0.15, 1.45)
const TRUNK_STAND := Vector3(-31.95, 0.15, 3.9)
const CAR_WAIT := {"Eddie": Vector3(-24.0, 0.15, 0.6), "Ruth": Vector3(-23.2, 0.15, -0.9), "Sarah": Vector3(-22.4, 0.15, 1.0), "Marcus": Vector3(-24.6, 0.15, -1.8)}
const ROADBLOCK_VIEW := Vector3(-38.0, 0.15, 0.0)
const GATE_APPROACH := Vector3(-42.4, 0.15, -13.2)
const GATE_CLEAR := Vector3(-45.8, 0.15, -13.2)
const REVEAL_AREA := Vector3(-48.0, 0.15, -13.2)
const SARAH_POCKET := {"Player": Vector3(-60.5, 0.15, 1.2), "Sarah": Vector3(-62.0, 0.15, 2.5), "Ruth": Vector3(-61.2, 0.15, 2.8), "Eddie": Vector3(-63.2, 0.15, 1.2),
	"Marcus": Vector3(-62.8, 0.15, -0.2)}
const ENTRY_ORDER := ["Eddie", "Ruth", "Sarah", "Marcus"]
const DOOR_LINE_Z := 4.0                                ## house-local: past this the whole body is inside the front door
const WAKE_POS := Vector3(1.4, 0.61, 5.6)               ## house-local: where the player wakes (beside the rest spot)
const WINDOW_VIEW := Vector3(-1.3, 0.61, 4.6)           ## house-local: a short walk from the bed to the front window

## The directed moments (one owner at a time; normal travel is the player's). activation / actors / camera / input / completion / save-load:
##  PLAN        Eddie talked to at the rendezvous / the group / the talk camera / talk / the plan said -> flag ch10_plan_done (a load before it replays the talk)
##  CAR         E on the sedan after the plan / player + the companions parked at CAR_WAIT / the door, the dash, the glove box seen from OUTSIDE the car / E only (held between presses) / the necessary searches done and the group has spoken -> ch10_car_done (items granted once, flags set with the item)
##  ROADBLOCK   car done + the player at ROADBLOCK_VIEW / the player / the van, pickup and barriers, then the side-route gap / none / both looks done -> ch10_roadblock_seen
##  GATE        (not a scene: the player's) the gate opens before anyone crosses and stays open; the hound reveal waits until the companions are physically past it
##  HOUND       the player in REVEAL_AREA + every companion past x -45.8 / the player, the hound / sound, turn, silhouette, behind the block / held until the hound is gone / seen for real -> ch10_creature_seen (set at the END; a load replays it)
##  SKITTER     the hound reveal done + the player with a readable view west / the player, one skitter / the crossing / held / it has crossed -> ch10_skitter_seen
##  SARAH       skitter done + the player at CHOICE_X + Sarah within reach / all the group walks into the roadside pocket / Sarah and Ruth / the choice (a skipped dialogue never answers) / the choice resolved -> ch10_choice_made (the cost is paid once: st().help_paid)
##  OUTSKIRTS   choice made + x < OUTSKIRTS_X / none / none / a line -> ch10_building_seen
##  ENTER       the player in the main room / the companions enter in order through the open door / the room / free / all inside, at their places, stopped (MEASURED door crossings) -> the refuge talk -> ch10_refuge_talk_done
##  REST        E on the rest spot / the player / the window / E / the call has played and landed -> chapter_10_complete, then chapter 11 takes over
enum Scene { NONE, PLAN, CAR, ROADBLOCK, HOUND, SKITTER, SARAH, OUTSKIRTS, ENTER, REST }
# ---- house-local (RES_House_MillWorker: living room x -3..3, z 3.2..8.4, floor y 0.61; front door at x 0.6)
const PORCH := Vector3(0.6, 0.0, 0.4)                  # in front of the porch steps (ground)
const ROOM := [Vector3(0.0, 1.6, 6.0), Vector3(5.4, 2.0, 4.2)]
const SPOTS := {"Eddie": Vector3(-1.6, 0.61, 7.3), "Ruth": Vector3(0.0, 0.61, 7.6), "Sarah": Vector3(1.7, 0.61, 7.3),
	"Marcus": Vector3(-1.4, 0.61, 4.6)}
const REST_SPOT := [Vector3(1.4, 1.0, 6.0), Vector3(1.0, 0.9, 1.3)]
const WINDOW := Vector3(-1.4, 1.5, 3.2)                 # the front window of the living room (toward the fields)

var world: Node
var c9: Node
var c8: Node
var c6: Node
var c5: Node
var p4: Node
var player: Node3D
var hud: Node
var eddie: Node3D
var marcus: Node3D
var ruth: Node3D
var sarah: Node3D
var house: Node3D
var car: Node3D
var its := {}
var report := {"creature_runs": 0, "rest_runs": 0, "car_items": 0}
var _busy := {}
var mover: Node
var _owner: int = Scene.NONE
var _look_target: Callable = Callable()
var _look_rate := 5.0
var _car_staged := false
var _tick := 0.0
var _route_i := 2                                       ## the first two anchors lie behind the new rendezvous house (east); the way on starts at (4, -47)
var _room: Area3D
var _streams := {}
var hound: Node3D


func begin(w: Node, chapter9: Node, restoring: bool) -> void:
	world = w
	c9 = chapter9
	c8 = c9.c8
	c6 = c9.c6
	c5 = c9.c5
	p4 = c9.p4
	player = w.player
	hud = w.hud
	eddie = c9.eddie
	marcus = c9.marcus
	ruth = c9.ruth
	sarah = c9.sarah
	house = w.get_node("Residential/Houses/" + HOUSE)
	if w.has_method("clear_story_glass"):
		w.clear_story_glass(house)
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"roster": c9.roster(), "sarah": "", "choice": ""}
	_streams["call"] = Sfx._make(4.0, _call_wave)
	mover = load("res://game/world/scene_mover.gd").new()
	mover.name = "Mover"
	add_child(mover)
	mover.setup(w, w.player)
	_setup_npcs()
	_setup_car()
	_setup_roadblock()
	_setup_fence()
	_setup_house()
	Dialogue.choices_offered.connect(_on_choices)
	var fresh := not Game.has_flag("ch10_started")
	if fresh:
		Game.set_flag("ch10_started")
	_apply()
	_apply_sarah_state()
	if Game.has_flag("chapter_10_complete"):
		_start_chapter11(true)
	Game.refresh_objective()
	if fresh:
		_title.call_deferred()
		world.save_checkpoint.call_deferred("chapter11_start")    # its own file, never the player's save slot


func _title() -> void:
	await get_tree().create_timer(1.0).timeout
	await hud.chapter_start(CHAPTER)


func st() -> Dictionary:
	return Game.world_state[STATE]


func hl(p: Vector3) -> Vector3:
	return house.global_transform * p


func alive() -> bool:
	return not Game.has_flag("ch9_marcus_lost")


## The survivors who are actually here (the previous chapter's roster: Marcus only if he made it out).
func group() -> Array:
	var g := ["Eddie", "Ruth", "Sarah"]
	if alive():
		g.append("Marcus")
	return g


func _node(k: String) -> Node3D:
	return {"Eddie": eddie, "Ruth": ruth, "Sarah": sarah, "Marcus": marcus}[k]


func _floor(p: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 3.0, p.z), Vector3(p.x, p.y - 4.0, p.z), 1))
	return (hit["position"] as Vector3).y if hit else p.y


func _prop(scene: PackedScene, n: String, at: Vector3, yaw: float) -> Node3D:
	var o := scene.instantiate() as Node3D
	o.name = n
	world.add_child(o)
	o.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, _floor(at), at.z))
	return o


## Fence and gate stand on the GROUND beside them (review note #129): the floor probe starts a metre above the ground, never from above the roofs, so they cannot end up floating.
func _prop_ground(scene: PackedScene, n: String, at: Vector3, yaw: float) -> Node3D:
	var o := scene.instantiate() as Node3D
	o.name = n
	world.add_child(o)
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 1.0, at.z), Vector3(at.x, -1.5, at.z), 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	var y: float = (hit["position"] as Vector3).y if not hit.is_empty() else 0.1
	o.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, y, at.z))
	return o


func _spot(n: String, at: Vector3, size: Vector3, cb: Callable, basis := Basis()) -> Interactable:
	var s := Node3D.new()
	s.name = n
	world.add_child(s)
	s.global_transform = Transform3D(basis, at)
	var it := Interactable.attach(s, {"kind": "custom", "label": n, "prompt_text": ""})
	var cs := it.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = size
	cs.position = Vector3.ZERO
	it.used.connect(cb)
	return it


# ------------------------------------------------------------------ setup
func _setup_npcs() -> void:
	var it: Interactable = p4.its.get("npc_Eddie")
	if it:
		it.used.connect(_talk_eddie)
		its["npc_Eddie"] = it


## The abandoned sedan on the main road: the driver's side (door, then the fuel gauge, then the glove compartment,
## one press each) and the trunk. Interaction boxes stand outside the body (the cabin collision stays solid).
func _setup_car() -> void:
	car = _prop(SEDAN, "C10_AbandonedSedan", CAR_POS, CAR_YAW)
	var t := car.global_transform
	its["driver"] = _spot("C10_DriverSide", t * Vector3(-1.25, 1.0, -0.55), Vector3(0.9, 1.3, 1.6), _use_driver, t.basis)
	its["trunk"] = _spot("C10_Trunk", t * Vector3(0.0, 1.0, 2.75), Vector3(1.7, 1.2, 0.9), _use_trunk, t.basis)


## The road west, blocked: a broken-down van and a pickup wedged across it, barriers in the gaps (all with their
## own collision), from the roadside building (z -7) to the south wall (z 7).
func _setup_roadblock() -> void:
	_prop(VAN, "C10_Block_Van", Vector3(BLOCK_X, 0.15, -4.0), 0.0)
	_prop(PICKUP, "C10_Block_Pickup", Vector3(BLOCK_X - 0.3, 0.15, 3.3), 0.12)
	_prop(BARRIER, "C10_Block_Barrier_0", Vector3(BLOCK_X + 1.1, 0.15, 0.25), PI * 0.5)
	_prop(BARRIER, "C10_Block_Barrier_1", Vector3(BLOCK_X - 0.6, 0.15, 6.45), 0.0)
	_prop(BARRIER, "C10_Block_Barrier_2", Vector3(BLOCK_X + 2.6, 0.15, -2.2), PI * 0.42)
	for z in [-1.6, 2.4, 5.6]:
		_prop(CONE, "C10_Block_Cone", Vector3(BLOCK_X + 2.4, 0.15, z), randf() * TAU)


## A chain-link fence closes the ground behind the roadside building at x -44 (from the building at z -7.6 to the
## building block at z -21.35); its one gate is the way round.
func _setup_fence() -> void:
	var z := FENCE_Z0
	var yaw := PI * 0.5                                  # local +x (the panel's length) runs toward -z
	for kind in ["p", "p", "g", "p", "p", "p"]:
		var at := Vector3(FENCE_X, 0.15, z)
		if kind == "p":
			_prop_ground(CHAINLINK, "C10_Fence", at, yaw).add_to_group("c10_seethrough")
			z -= 2.5
		else:
			var g := _prop_ground(GATE, "C10_Gate", at, yaw)
			g.add_to_group("c10_seethrough")
			var leaf := g.find_child("GateLeaf", true, false) as Node3D
			var lcol := g.find_child("GateLeaf_Col", true, false) as Node3D
			if leaf and lcol and not leaf.is_ancestor_of(lcol):
				lcol.reparent(leaf, true)                   # the leaf's collision swings with it
			if leaf:
				var deg: float = world._toward_deg(leaf, 95.0, Vector3(FENCE_X - 1.5, 1.0, z - 0.6))
				var git := Interactable.attach(leaf, {"kind": "hinge", "label": "Gate", "open_deg": deg, "state_key": "ch10/gate"})
				its["gate"] = git
			z -= 1.25


func _setup_house() -> void:
	var fd := house.find_child("INT_Door_Front", true, false) as Node3D
	if fd:
		var deg: float = world._toward_deg(fd, 95.0, hl(Vector3(0.6, 1.4, 5.0)))
		var dit := Interactable.attach(fd, {"kind": "hinge", "label": "Front Door", "open_deg": deg, "hinge_axis": Vector3.UP,
			"state_key": "ch10/%s/INT_Door_Front" % HOUSE})
		dit.used.connect(func(_b): _door_used())
		its["door"] = dit
	_room = world._area("C10_MainRoom", hl(ROOM[0]), ROOM[1], 2, func(_b): pass, house.global_transform.basis)
	its["rest"] = _spot("C10_Rest", hl(REST_SPOT[0]), REST_SPOT[1], _rest, house.global_transform.basis)


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	marcus.visible = alive()
	if Game.has_flag("ch10_refuge_talk_done"):
		_place_inside()
	elif Game.has_flag("ch10_plan_done"):
		for k in group():
			c9._start_follow(k)
	else:
		for k in c9.follows:
			(c9.follows[k] as VeilCompanionFollow).stop()
		c9._place_rendezvous()
	_apply_car()
	_refresh_prompts()
	_guide()


func _apply_car() -> void:
	if Game.has_flag("ch10_car_door"):
		_open_driver_door(true)
	if Game.has_flag("ch10_car_trunk"):
		_open_trunk(true)


func _place_inside() -> void:
	for k in group():
		var n := _node(k)
		(c9.follows[k] as VeilCompanionFollow).stop()
		c5._reparent(n, world)
		n.visible = true
		var a = world.animators.get(k)
		if a:
			a.set_seated(false)
			a.turn_to_face = true
			a.set_mood("calm")
		world.place_survivor(n, hl(SPOTS[k]))
		if a:
			a.face_towards(hl(Vector3(0.0, 1.5, 6.0)))


func _refresh_prompts() -> void:
	if its.has("npc_Eddie"):
		var on := not Game.has_flag("ch10_plan_done")
		its["npc_Eddie"].prompt_text = "[E] Talk" if on else ""
		its["npc_Eddie"].collision_layer = 8 if on else 0
	if its.has("npc_Marcus") or p4.its.has("npc_Marcus"):
		var mi: Interactable = p4.its.get("npc_Marcus")
		if mi:
			mi.prompt_text = ""
			mi.collision_layer = 0
	var car_on := Game.has_flag("ch10_plan_done") and not Game.has_flag("ch10_car_done")
	var dp := ""
	if car_on:
		if not Game.has_flag("ch10_car_door"):
			dp = "[E] Open the Driver's Door"
		elif not Game.has_flag("ch10_car_fuel"):
			dp = "[E] Check the Fuel Gauge"
		elif not Game.has_flag("ch10_car_glove"):
			dp = "[E] Search the Glove Compartment"
	its["driver"].prompt_text = dp
	its["driver"].collision_layer = 8 if dp != "" else 0
	var tp := "[E] Open the Trunk" if car_on and not Game.has_flag("ch10_car_trunk") else ""
	its["trunk"].prompt_text = tp
	its["trunk"].collision_layer = 8 if tp != "" else 0
	var rest_on: bool = Game.has_flag("ch10_refuge_talk_done") and not Game.has_flag("chapter_10_complete") and not _busy.get("rest", false)
	its["rest"].prompt_text = "[E] Rest for a Few Hours" if rest_on else ""
	its["rest"].collision_layer = 8 if rest_on else 0


## Beacon-free HUD marker: the next point on the way (advanced as the player reaches each one).
func _guide() -> void:
	var t: Variant = null
	var label := ""
	var p := player.global_position
	if not Game.has_flag("ch10_plan_done"):
		t = eddie
		label = "EDDIE"
	elif not Game.has_flag("ch10_car_found"):
		while _route_i < ROUTE.size() - 1 and Vector2(p.x - ROUTE[_route_i].x, p.z - ROUTE[_route_i].z).length() < 4.0:
			_route_i += 1
		t = ROUTE[_route_i] + Vector3(0, 1.2, 0)
		label = "WAY OUT"
	elif not Game.has_flag("ch10_car_done"):
		t = its["driver"].global_position if not Game.has_flag("ch10_car_glove") else its["trunk"].global_position
		label = "VEHICLE"
	elif not Game.has_flag("ch10_roadblock_seen"):
		t = Vector3(BLOCK_X + 4.0, 1.4, 0.0)
		label = "ROAD WEST"
	elif not Game.has_flag("ch10_around_done"):
		if p.z > -6.8 and p.x > -44.0:
			t = SIDE_ROUTE[0] + Vector3(0, 1.2, 0)
			label = "SIDE ROUTE"
		else:
			t = Vector3(FENCE_X, 1.2, GATE_Z - 0.6)
			label = "GATE"
	elif not Game.has_flag("ch10_followed_done"):
		t = BACK_TO_ROAD[2] + Vector3(0, 1.2, 0)
		label = "ROAD"
	elif not Game.has_flag("ch10_building_seen") and not _busy.get("choice", false):
		t = Vector3(OUTSKIRTS_X - 4.0, 1.4, 0.0)
		label = "WEST"
	elif Game.has_flag("ch10_building_seen") and not Game.has_flag("ch10_refuge_checked"):
		t = hl(Vector3(0.6, 1.6, 3.0))
		label = "BUILDING"
	elif Game.has_flag("ch10_refuge_talk_done") and not Game.has_flag("chapter_10_complete") and not _busy.get("rest", false):
		t = its["rest"].global_position
		label = "REST"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


# ------------------------------------------------------------------ scene 1: nowhere to hide
func _talk_eddie(_b: Node) -> void:
	if Game.has_flag("ch10_plan_done") or _busy.get("talk", false) or not Game.has_flag("ch10_started"):
		return
	_busy["talk"] = true
	its["npc_Eddie"].prompt_text = ""
	var npcs: Array = [eddie, ruth, sarah]
	if alive():
		npcs.insert(1, marcus)
	await c9._talk_group("c10_plan_alive" if alive() else "c10_plan_lost", npcs)
	Game.set_flag("ch10_plan_done")
	st()["roster"] = group()
	for k in group():
		c9._start_follow(k)
	_busy["talk"] = false
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ scene 2: the abandoned vehicle
## The player stands where the door can swing and the camera stays OUTSIDE the car (the asset has no interior shot); the companions are parked clear of the door, the trunk and the player until the
## group has spoken. Each press is one directed beat with its feedback in sync (door sound with the door, the gauge when it is read, the pickup when the search is done), then the player is free.
func _stage_car_group() -> void:
	if _car_staged:
		return
	_car_staged = true
	var acts: Array = []
	for k in group():
		var f: VeilCompanionFollow = c9.follows[k]
		f.stop()
		var a := _actor(k)
		acts.append(a)
		mover.go(a, _fl(CAR_WAIT[k]), 2.6)
	var t := 0.0
	while not mover.all_done(acts) and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	for a in acts:
		if not a["ok"]:
			report["staging_failures"] = int(report.get("staging_failures", 0)) + 1
		var an = a["anim"]
		if an:
			an.face_towards(car.global_position)


func _stand_at(p: Vector3) -> void:
	var pa := _player_actor()
	var tgt := _fl(p)
	if not mover.near(pa, tgt, 0.5):
		if not await mover.move(pa, tgt, 3.2):
			report["staging_failures"] = int(report.get("staging_failures", 0)) + 1


func _use_driver(_b: Node) -> void:
	if not Game.has_flag("ch10_plan_done") or Game.has_flag("ch10_car_done") or not _acquire(Scene.CAR):
		return
	await _stage_car_group()
	await _stand_at(DRIVER_STAND)
	var door_p: Vector3 = car.global_transform * Vector3(-1.2, 0.9, -0.55)
	await _look(door_p, 6.0)
	if not Game.has_flag("ch10_car_door"):
		_open_driver_door(false)
		Sfx.play("door_open", door_p, -4.0, 0.9)                         # with the door's movement
		await get_tree().create_timer(0.7).timeout
		Game.set_flag("ch10_car_door")
	elif not Game.has_flag("ch10_car_fuel"):
		await _look(car.global_transform * Vector3(-0.7, 1.15, -0.2), 6.0)   # the dash seen through the open door, from outside
		await get_tree().create_timer(0.8).timeout
		Game.set_flag("ch10_car_fuel")
		st()["car_fuel"] = "empty"
		Dialogue.say("c10_car_fuel", false, true)
		_hint("Fuel gauge: empty. The engine won't turn over.")
	elif not Game.has_flag("ch10_car_glove"):
		await _look(car.global_transform * Vector3(-0.4, 0.95, 0.1), 6.0)
		await get_tree().create_timer(1.2).timeout                        # the search takes a moment
		Game.set_flag("ch10_car_glove")                                  # set with the item: the battery is found once
		p4._got_batteries(1)
		report["car_items"] += 1
		Sfx.play("pickup", door_p, -6.0, 0.9)
		_hint("Glove compartment: a flashlight battery.")
	_release(Scene.CAR)
	_car_check()


func _use_trunk(_b: Node) -> void:
	if not Game.has_flag("ch10_plan_done") or Game.has_flag("ch10_car_trunk") or Game.has_flag("ch10_car_done") or not _acquire(Scene.CAR):
		return
	await _stage_car_group()
	await _stand_at(TRUNK_STAND)
	var trunk_p: Vector3 = car.global_transform * Vector3(0.0, 0.9, 2.2)
	await _look(trunk_p, 6.0)
	Game.set_flag("ch10_car_trunk")
	_open_trunk(false)
	Sfx.play("door_open", trunk_p, -4.0, 0.7)
	await get_tree().create_timer(0.9).timeout
	Game.add_item("water_bottle")
	report["car_items"] += 1
	Sfx.play("pickup", trunk_p, -6.0, 0.9)
	_hint("Trunk: one bottle of water.")
	_release(Scene.CAR)
	_car_check()


func _open_driver_door(instant: bool) -> void:
	var d := car.find_child("Door_FL", true, false) as Node3D
	if d == null or d.has_meta("c10_open"):
		return
	d.set_meta("c10_open", true)
	var deg: float = world._toward_deg(d, 65.0, car.global_transform * Vector3(-2.2, 0.8, -1.2))
	var to := Transform3D(d.transform.basis * Basis(Vector3.UP, deg_to_rad(deg)), d.transform.origin)
	if instant:
		d.transform = to
	else:
		create_tween().tween_property(d, "transform", to, 0.6).set_trans(Tween.TRANS_SINE)


func _open_trunk(instant: bool) -> void:
	var tr := car.find_child("Trunk", true, false) as Node3D
	if tr == null or tr.has_meta("c10_open"):
		return
	tr.set_meta("c10_open", true)
	# whichever way about its hinge lifts the lid
	var best := tr.transform
	var best_y := -INF
	for s in [1.0, -1.0]:
		var t := Transform3D(tr.transform.basis * Basis(Vector3.RIGHT, deg_to_rad(70.0 * s)), tr.transform.origin)
		var y: float = (tr.get_parent_node_3d().global_transform * t * Interactable.aabb_of(tr).get_center()).y
		if y > best_y:
			best_y = y
			best = t
	if instant:
		tr.transform = best
	else:
		create_tween().tween_property(tr, "transform", best, 0.8).set_trans(Tween.TRANS_SINE)


func _car_check() -> void:
	_refresh_prompts()
	if Game.has_flag("ch10_car_fuel") and Game.has_flag("ch10_car_glove") and Game.has_flag("ch10_car_trunk") \
			and not Game.has_flag("ch10_car_done") and not _busy.get("car_talk", false):
		_busy["car_talk"] = true
		while Dialogue.is_busy():
			await get_tree().process_frame
		await c9._talk_group("c10_car", [eddie, ruth])
		Game.set_flag("ch10_car_done")
		_busy["car_talk"] = false
		_car_staged = false
		_resume_follow()                                                     # they walk after the player from where they stood
		_refresh_prompts()
	_guide()


# ================================================================ scene ownership, camera, staging
func _acquire(sc: int, hold := true) -> bool:
	if _owner != Scene.NONE:
		return false
	_owner = sc
	st()["scene"] = sc
	if hold:
		_hold(true)
	return true


## Only the scene that owns the moment lets go of the controls and the camera.
func _release(sc: int) -> void:
	if _owner != sc:
		return
	_owner = Scene.NONE
	_look_target = Callable()
	st()["scene"] = 0
	_hold(false)


func _look(target: Variant, rate := 5.0, wait := true) -> void:
	_look_rate = rate
	if target is Callable:
		_look_target = target
	else:
		var tp: Vector3 = target
		_look_target = func() -> Vector3: return tp
	if not wait:
		return
	var t := 0.0
	while t < 1.4 and _look_error() > 0.06:
		await get_tree().process_frame
		t += get_process_delta_time()


func _look_error() -> float:
	if not _look_target.is_valid():
		return 0.0
	var tv: Variant = _look_target.call()
	if not (tv is Vector3):
		return 0.0
	var v: Vector3 = ((tv as Vector3) - player.camera.global_position).normalized()
	return acos(clampf((-player.camera.global_transform.basis.z).dot(v), -1.0, 1.0))


func _track_camera(delta: float) -> void:
	if _owner == Scene.NONE or not _look_target.is_valid():
		return
	var tv: Variant = _look_target.call()
	if not (tv is Vector3):
		return
	var v: Vector3 = (tv as Vector3) - player.camera.global_position
	if v.length() < 0.2:
		return
	v = v.normalized()
	var k := 1.0 - exp(-_look_rate * delta)
	player.set_yaw_pitch(lerp_angle(player.rotation.y, atan2(-v.x, -v.z), k), lerpf(player.head.rotation.x, clampf(asin(clampf(v.y, -1.0, 1.0)), -0.55, 0.4), k))


func _fl(p: Vector3) -> Vector3:                      ## a marker on its real floor
	return Vector3(p.x, _floor(p), p.z)


## A house-local marker on the real floor (a raised floor, steps): probed within 0.45 m of its stated height, never a ray from above (the roof is up there).
func _hfloor(local: Vector3) -> Vector3:
	var w := hl(local)
	var fy: float = mover.floor_at(w.x, w.z, w.y)
	return Vector3(w.x, fy if fy != INF else w.y, w.z)


func _actor(k: String) -> Dictionary:
	return mover.actor(_node(k), world.animators.get(k), "person")


func _player_actor() -> Dictionary:
	return mover.actor(player, null, "player")


## Line of sight that ignores the see-through chain-link fence and the gate (their collision is solid, the mesh is not).
func _see(from_w: Vector3, to_w: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from_w, to_w, 1)
	var ex: Array[RID] = [player.get_rid()]
	for n in get_tree().get_nodes_in_group("c10_seethrough"):
		for co in (n as Node).find_children("*", "CollisionObject3D", true, false):
			ex.append((co as CollisionObject3D).get_rid())
	q.exclude = ex
	return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Sarah's condition is read from the previous chapter's record every time (a reload never relies on what an animator remembers).
func _apply_sarah_state() -> void:
	var serious := _sarah_condition() == "serious"
	var limp := 1.0 if serious else 0.7
	var choice := String(st().get("choice", ""))
	if choice == "help" and not serious:
		limp = 0.4                                       # rested: the tiredness eases, a serious wound is never erased
	elif choice == "push":
		limp = 1.0 if serious else 0.85
	var sa = world.animators.get("Sarah")
	if sa:
		sa.limp = limp
	var f: VeilCompanionFollow = c9.follows.get("Sarah")
	if f:
		f.walk_speed = 1.8 if serious else (1.7 if choice == "push" else 2.2)
		f.run_speed = 3.4 if serious else 4.2


## Hand the companions back to the follower AI where they stand (no snapping): they walk after the player on their own.
func _resume_follow() -> void:
	for k in group():
		c9._start_follow(k, false)
	_apply_sarah_state()


func _hint(t: String) -> void:
	if hud.has_method("set_hint"):
		hud.set_hint(t)
		get_tree().create_timer(3.5).timeout.connect(func():
			if is_instance_valid(hud) and hud.hint.text == t:
				hud.set_hint(""))


# ------------------------------------------------------------------ scenes 3-4: the roadblock, the side route, the follower
## A scene starts from its position AND its predecessor's completion, and only when nothing else owns the moment: one scene per update, never three at once.
func _road_tick() -> void:
	if _owner != Scene.NONE or _busy.get("choice", false) or world.conversing or Dialogue.is_busy():
		return
	var p := player.global_position
	if Game.has_flag("ch10_plan_done") and not Game.has_flag("ch10_car_found") and p.distance_to(CAR_POS) < 12.0:
		Game.set_flag("ch10_car_found")
	elif Game.has_flag("ch10_car_done") and not Game.has_flag("ch10_roadblock_seen") and p.x < BLOCK_X + 9.0 and absf(p.z) < 7.0:
		_roadblock_scene()
	elif Game.has_flag("ch10_roadblock_seen") and not Game.has_flag("ch10_around_done") and p.x < FENCE_X - 0.8 and p.z < -7.6:
		Game.set_flag("ch10_around_done")             # through the gate, behind the roadside building (the gate stays open: nobody is shut out)
	elif Game.has_flag("ch10_around_done") and not Game.has_flag("ch10_creature_seen") and p.x < FENCE_X - 3.0 and p.z < -7.6 and _group_past_gate():
		_followed()
	elif Game.has_flag("ch10_around_done") and not Game.has_flag("ch10_followed_done") and p.x < BLOCK_X - 4.0 and p.z > -6.5:
		if not Game.has_flag("ch10_creature_seen"):
			Game.set_flag("ch10_creature_seen")       # the reveal never started (the group lagged, the player went round): it is skipped, never a dead end (review note #130)
		Game.set_flag("ch10_followed_done")           # back on the road, west of the block
	elif Game.has_flag("ch10_followed_done") and not Game.has_flag("ch10_skitter_seen") and p.x < BLOCK_X - 7.0 and absf(p.z) < 8.0:
		_skitter_scene()
	elif Game.has_flag("ch10_skitter_seen") and not Game.has_flag("ch10_choice_made") and p.x < CHOICE_X and _sarah_near():
		_sarah_stops()
	elif Game.has_flag("ch10_choice_made") and not Game.has_flag("ch10_building_seen") and p.x < OUTSKIRTS_X:
		Game.set_flag("ch10_building_seen")
		Dialogue.say("c10_outskirts", false, true)
	_assist_gate()


## The gate opens when a companion is at it and shut: nobody is left on the wrong side of a closed gate (it is never closed again).
func _assist_gate() -> void:
	var g: Interactable = its.get("gate")
	if g == null or g.is_open or not Game.has_flag("ch10_roadblock_seen"):
		return
	for k in group():
		var c: Vector3 = _node(k).global_position
		if c.x > FENCE_X and c.x < FENCE_X + 3.0 and c.z < FENCE_Z0 and c.z > -14.5:
			g.set_open(true)
			return


## Every companion MEASURED past the gate (x < -45.8 on the far side), not assumed.
func _group_past_gate() -> bool:
	for k in group():
		var c: Vector3 = _node(k).global_position
		if not (c.x < GATE_CLEAR.x and c.z < FENCE_Z0):
			return false
	return true


func _sarah_near() -> bool:
	return sarah.global_position.distance_to(player.global_position) < 9.0


## The group walks faster once something has been seen (no survivor dawdles while the player runs); Sarah keeps her own pace.
func _hurry() -> void:
	for k in group():
		if k == "Sarah":
			continue
		var f: VeilCompanionFollow = c9.follows[k]
		f.walk_speed = maxf(f.walk_speed, 2.6)
		f.run_speed = maxf(f.run_speed, 4.8)


## The roadblock: the view takes in the van, the pickup and the barriers (why the road is shut), then turns to the gap in the roadside building (the way on).
func _roadblock_scene() -> void:
	if not _acquire(Scene.ROADBLOCK):
		return
	var block_mid := Vector3(BLOCK_X, 1.3, -0.3)
	await _look(block_mid, 4.5)
	var van := world.get_node_or_null("C10_Block_Van") as Node3D
	if van and not _see_prop(player.camera.global_position, van):
		report["view_failures"] = int(report.get("view_failures", 0)) + 1
	Dialogue.say("c10_roadblock", false, true)
	await get_tree().create_timer(2.6).timeout
	await _look(Vector3(SIDE_ROUTE[0].x, 1.4, SIDE_ROUTE[0].z), 4.0)          # the way on: the gap behind the roadside building
	await get_tree().create_timer(0.9).timeout
	Game.set_flag("ch10_roadblock_seen")
	_release(Scene.ROADBLOCK)
	_guide()


## A sound behind them: the view turns, a Hound's silhouette crosses the fog and is gone behind the buildings. The player is held through this short reveal.
func _followed() -> void:
	if Game.has_flag("ch10_creature_seen") or not _acquire(Scene.HOUND):
		return
	report["creature_runs"] += 1
	var ps := load(VeilMeshyNpcs.monster_scene(HOUND_PATH)) as PackedScene
	hound = ps.instantiate() as Node3D
	hound.name = "C10_Follower"
	world.add_child(hound)
	if hound is CollisionObject3D:
		(hound as CollisionObject3D).collision_layer = 0
		(hound as CollisionObject3D).collision_mask = 0
	hound.set_physics_process(false)
	var a: Vector3 = HOUND_PATH_PTS[0]
	hound.global_position = Vector3(a.x, _floor(a), a.z)
	VeilCreatureLook.apply_skitter(hound, hound.global_position.y)
	c8._bark(hound.global_position + Vector3(0, 1.0, 0))                      # the sound behind the group
	var h := hound
	await _look(func() -> Vector3: return h.global_position + Vector3(0, 0.8, 0), 5.5)
	c8._hplay(h, "Walk", 0.0)
	var seen := 0.0
	var said := false
	for i in range(1, HOUND_PATH_PTS.size()):
		if not is_instance_valid(h):
			break
		var to: Vector3 = HOUND_PATH_PTS[i]
		to.y = _floor(to)
		var d := to - h.global_position
		h.rotation.y = atan2(d.x, d.z)
		var tw := h.create_tween()
		tw.tween_property(h, "global_position", to, d.length() / 3.2)
		if i == 1 and not said:
			said = true
			Dialogue.say("c10_followed", false, true)
		while tw.is_running():
			await get_tree().process_frame
			if _hound_visible():
				seen += get_process_delta_time()
	if is_instance_valid(h):
		h.queue_free()
	hound = null
	if seen < 0.8:
		report["view_failures"] = int(report.get("view_failures", 0)) + 1            # reported: the silhouette was not seen long enough
	Game.set_flag("ch10_creature_seen")
	_release(Scene.HOUND)
	_guide()


## Can the camera see this prop? (the first thing the line hits is the prop itself, or nothing)
func _see_prop(from_w: Vector3, prop: Node3D) -> bool:
	var c: Vector3 = prop.global_transform * Interactable.aabb_of(prop).get_center()
	var q := PhysicsRayQueryParameters3D.create(from_w, c, 1)
	var ex: Array[RID] = [player.get_rid()]
	for n in get_tree().get_nodes_in_group("c10_seethrough"):
		for co in (n as Node).find_children("*", "CollisionObject3D", true, false):
			ex.append((co as CollisionObject3D).get_rid())
	q.exclude = ex
	var h: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	return h.is_empty() or prop.is_ancestor_of(h["collider"] as Node)


## A point out over the fields, seen through the window from `eye`: the first of a few near-level aims whose line really passes the opening (never a wall, frame or the porch deck).
func window_target(eye: Vector3) -> Vector3:
	var c := hl(WINDOW)
	var out_dir := (hl(Vector3(WINDOW.x, 0.0, WINDOW.z - 1.0)) - hl(Vector3(WINDOW.x, 0.0, WINDOW.z))).normalized()
	var best := eye + out_dir * 14.0
	for y in [2.0, 1.7, 1.4, 1.1, 0.8]:
		var tp: Vector3 = Vector3(c.x, eye.y - (2.25 - y) * 0.15, c.z) + out_dir * 14.0
		tp = eye + (Vector3(c.x, eye.y, c.z) + out_dir * 14.0 - eye).normalized() * 14.0 + Vector3(0, y - 1.4, 0)
		if _see(eye, tp):
			return tp
	return best


func _hound_visible() -> bool:
	if hound == null or not is_instance_valid(hound):
		return false
	var tp: Vector3 = hound.global_position + Vector3(0, 0.8, 0)
	return player.camera.is_position_in_frustum(tp) and _see(player.camera.global_position, tp)


## One skitter crosses the road ahead: a brief look, no chase; the group picks up its pace. Only after the hound reveal, and never with Sarah's conversation.
func _skitter_scene() -> void:
	if not _acquire(Scene.SKITTER):
		return
	await _look(Vector3(-70.0, 1.0, -8.0), 4.0)
	var sk: Node3D = null
	if world.expedition:
		sk = world.expedition.skitter_crossing(Vector3(-70.0, 0.2, -18.0), Vector3(-72.0, 0.2, 20.0))
	if sk != null:
		_look(func() -> Vector3: return sk.global_position + Vector3(0, 0.4, 0) if is_instance_valid(sk) else Vector3(-71.0, 0.6, 0.0), 3.5, false)
	await get_tree().create_timer(3.4).timeout
	Game.set_flag("ch10_skitter_seen")
	_hurry()
	_release(Scene.SKITTER)
	_guide()


# ------------------------------------------------------------------ scene 5: a difficult choice
func _sarah_condition() -> String:
	return "serious" if String(c8.st().get("injured_condition", "stable")) == "serious" else "stable"


func _sarah_stops() -> void:
	if not _acquire(Scene.SARAH):
		return
	_busy["choice"] = true
	st()["sarah"] = "exhausted" if _sarah_condition() == "stable" else "wound_worse"
	# the group stops in a clear roadside pocket and WALKS into its places (nobody is snapped there)
	var acts: Array = []
	for k in group():
		(c9.follows[k] as VeilCompanionFollow).stop()
		var a := _actor(k)
		acts.append(a)
		mover.go(a, _fl(SARAH_POCKET[k]), 2.4 if k == "Sarah" else 2.9)
	var pa := _player_actor()
	mover.go(pa, _fl(SARAH_POCKET["Player"]), 2.6)
	acts.append(pa)
	var t := 0.0
	while not mover.all_done(acts) and t < 12.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	for a in acts:
		if not a["ok"]:
			report["staging_failures"] = int(report.get("staging_failures", 0)) + 1
	var sa = world.animators.get("Sarah")
	var ra = world.animators.get("Ruth")
	if sa:
		sa.face_towards(ruth.global_position)
	if ra:
		ra.face_towards(sarah.global_position)                                 # Ruth attends to her
	for k in ["Eddie", "Marcus"]:
		if group().has(k) and world.animators.get(k):
			world.animators[k].face_towards(player.global_position + Vector3(-6.0, 0, 0))
	await _look(func() -> Vector3: return sarah.global_position.lerp(ruth.global_position, 0.5) + Vector3(0, 1.2, 0), 5.0)
	_look_target = Callable()                                                  # the conversation takes the camera
	await c9._talk_group("c10_sarah_" + _sarah_condition(), [sarah, ruth])
	_hold(true)                                                                # still held: the choice below is the player's
	t = 0.0
	while not Game.has_flag("ch10_choice_made") and t < 600.0:                 # a skipped dialogue never answers for the player
		await get_tree().process_frame
		t += get_process_delta_time()
	_release(Scene.SARAH)
	_resume_follow()
	_guide()


func _on_choices(id: String, choices: Array) -> void:
	if not id.begins_with("c10_sarah_") or Game.has_flag("ch10_choice_made"):
		return
	var texts: Array = []
	for c in choices:
		texts.append(c["text"])
	var i: int = await p4.choice.ask("", texts, player)
	var c: Dictionary = choices[clampi(i, 0, choices.size() - 1)]
	Game.set_flag(c["flag"])                         # mutually exclusive: only one is ever set
	var help := String(c["flag"]) == "ch10_choice_help"
	st()["choice"] = "help" if help else "push"
	await c5._say_wait(c["next"])
	var sa = world.animators.get("Sarah")
	if help:
		# an hour by the road: she rests (lying down, Ruth beside her) and drinks; it costs a water (or food) from the packs, or exposure - paid ONCE
		if sa:
			sa.set_downed("side")
		await hud.fade_to(1.0, 0.8)
		if not st().get("help_paid", false):
			st()["help_paid"] = true
			var used := ""
			for item in ["water_bottle", "canned_food", "cola_bottle", "energy_snack", "chocolate_bar"]:
				if Game.has_item(item):
					Game.remove_item(item)
					used = item
					break
			st()["help_cost"] = used if used != "" else "exposure"
			if used == "":
				Game.set_flag("ch10_exposure")
		st()["sarah"] = "rested"
		Game.set_flag("ch10_sarah_rested")
		hud.location_caption("AN HOUR LATER", 1.6)
		await get_tree().create_timer(1.6).timeout
		if sa:
			sa.set_downed("")                          # she is up again (a serious wound stays: only the tiredness eased)
		await hud.fade_to(0.0, 0.8)
	else:
		Game.set_flag("ch10_sarah_exhausted")         # recorded for later chapters; she keeps going, visibly struggling
	Game.set_flag("ch10_choice_made")
	_apply_sarah_state()
	_busy["choice"] = false
	_guide()


# ------------------------------------------------------------------ scenes 6-7: the outskirts, the refuge
func _door_used() -> void:
	if Game.has_flag("ch10_building_seen") and not Game.has_flag("ch10_entrance_checked"):
		Game.set_flag("ch10_entrance_checked")


func _house_tick() -> void:
	if not Game.has_flag("ch10_building_seen"):
		return
	if not Game.has_flag("ch10_refuge_checked") and _room.overlaps_body(player) and not _busy.get("room", false):
		_check_room()
	elif Game.has_flag("ch10_refuge_checked") and not Game.has_flag("ch10_refuge_talk_done") and not _busy.get("gather", false):
		_gather()


func _check_room() -> void:
	if not _acquire(Scene.ENTER, false):
		return
	_busy["room"] = true
	Game.set_flag("ch10_entrance_checked")
	await get_tree().create_timer(1.2).timeout
	Dialogue.say("c10_house_clear", false, true)
	Game.set_flag("ch10_refuge_checked")
	_busy["room"] = false
	_release_soft(Scene.ENTER)


func _release_soft(sc: int) -> void:
	if _owner == sc:
		_owner = Scene.NONE
		st()["scene"] = 0


## The companions come in through the open door in a set order, one through the doorway at a time, each along a route over the real floor and steps; the next starts when the last has MEASURABLY crossed
## the door line. Nothing is placed: a failure re-opens the door and re-routes, and is reported. The talk begins when everybody is inside, at their places, stopped.
func _gather() -> void:
	if not _acquire(Scene.ENTER, false):
		return
	_busy["gather"] = true
	var door: Interactable = its.get("door")
	if door and not door.is_open:
		door.set_open(true)                                                    # the door stands open for them
		await get_tree().create_timer(door.anim_time + 0.1).timeout
	var crossed := {}
	var acts := {}
	for k in ENTRY_ORDER:
		if group().has(k):
			(c9.follows[k] as VeilCompanionFollow).stop()
			acts[k] = _actor(k)
	for k in ENTRY_ORDER:                                                      # they all come in together, a short stagger apart (no queue: they pass one another, never a wall)
		if not acts.has(k):
			continue
		mover.go(acts[k], _hfloor(SPOTS[k]), 3.4 if k == "Sarah" else 4.4)
		await get_tree().create_timer(0.35).timeout
	var t := 0.0
	var retried := {}
	while t < 40.0:
		_note_crossings(acts, crossed)
		var all_in := true
		for k in acts:
			var a: Dictionary = acts[k]
			if not (a["done"] and a["ok"] and crossed.get(k, false)):
				all_in = false
			if a["done"] and not a["ok"] and retried.get(k, 0) < 3:           # could not get in: the door state and a fresh route, not a teleport
				retried[k] = retried.get(k, 0) + 1
				if door:
					door.set_open(true, true)
				mover.go(a, _hfloor(SPOTS[k]), 2.4)
				report["entry_failures"] = int(report.get("entry_failures", 0)) + 1
		if all_in:
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= 40.0:
		report["entry_failures"] = int(report.get("entry_failures", 0)) + 100        # reported loudly: the scene does NOT pretend they arrived
		for k in acts:
			if not crossed.get(k, false):
				push_warning("[chapter10] %s never crossed the front door" % k)
		_busy["gather"] = false
		_release_soft(Scene.ENTER)
		return
	for k in acts:
		var an = world.animators.get(k)
		if an:
			an.walk_to([])
			an.set_mood("calm")
			an.face_towards(hl(Vector3(0.0, 1.5, 6.0)))
	while Dialogue.is_busy():
		await get_tree().process_frame
	var npcs: Array = [ruth, eddie]
	if alive():
		npcs.append(marcus)
	await c9._talk_group("c10_refuge_alive" if alive() else "c10_refuge_lost", npcs)
	Game.set_flag("ch10_refuge_talk_done")
	_busy["gather"] = false
	_release_soft(Scene.ENTER)
	_refresh_prompts()
	_guide()


func _note_crossings(acts: Dictionary, crossed: Dictionary) -> void:
	for k in acts:
		var l := house.to_local((acts[k]["node"] as Node3D).global_position)
		if l.z > DOOR_LINE_Z and absf(l.x - 0.6) < 2.6:
			crossed[k] = true


## Inside the living room (house-local bounds; the room's trigger area only sees the player).
func inside_room(n: Node3D) -> bool:
	var l := house.to_local(n.global_position)
	var half: Vector3 = ROOM[1] * 0.5
	return absf(l.x - ROOM[0].x) <= half.x and absf(l.z - ROOM[0].z) <= half.z and l.y > 0.3


func _rest(_b: Node) -> void:
	if not Game.has_flag("ch10_refuge_talk_done") or Game.has_flag("chapter_10_complete") or not _acquire(Scene.REST):
		return
	_busy["rest"] = true
	report["rest_runs"] += 1
	_refresh_prompts()
	await hud.fade_to(1.0, 1.2)
	player.heal(30.0)
	Game.set_flag("ch10_refuge_rested")
	hud.location_caption("A FEW HOURS LATER", 2.0)
	await get_tree().create_timer(2.0).timeout
	# black screen: the waking place is a valid spot beside the rest area, eyes level, looking along the room; then a short walk to the window
	var wake := _hfloor(WAKE_POS)
	player.global_position = wake
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	var room_dir := hl(Vector3(0.0, 1.5, 6.0))
	player.set_yaw_pitch(atan2(-(room_dir.x - wake.x), -(room_dir.z - wake.z)), 0.0)
	await hud.fade_to(0.0, 1.6)
	var pa := _player_actor()
	var view := _hfloor(WINDOW_VIEW)
	await mover.move(pa, view, 1.3)                                              # a slow, groggy walk
	var out := window_target(player.camera.global_position)
	await _look(out, 3.0)
	if not _see(player.camera.global_position, out):
		report["view_failures"] = int(report.get("view_failures", 0)) + 1
	player.set_physics_process(true)
	await get_tree().create_timer(1.2).timeout
	_play_call()
	await get_tree().create_timer(3.4).timeout                                   # let it land
	Game.set_flag("chapter_10_complete")             # the next chapter is NOT started here
	st()["completed"] = {"roster": group(), "choice": st().get("choice", ""), "sarah": st().get("sarah", ""),
		"refuge": HOUSE}
	_busy["rest"] = false
	_release(Scene.REST)
	_refresh_prompts()
	_guide()
	world.save_checkpoint("chapter11_end")             # its own file, never the player's save slot
	await hud.chapter_complete(CHAPTER)
	_start_chapter11(false)                          # the farm road starts at the refuge (displayed 12)


## The next chapter (displayed CHAPTER 12 "The Farm Road", internally chapter11.gd) starts in the refuge.
var chapter11: Node
func _start_chapter11(restoring: bool) -> void:
	if chapter11 != null:
		return
	chapter11 = load("res://game/world/chapter11.gd").new()
	chapter11.name = "Chapter11"
	add_child(chapter11)
	chapter11.begin(world, self, restoring)


## A long, low call somewhere out in the fields: no source is ever shown.
func _play_call() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams["call"]
	p.volume_db = 4.0
	p.unit_size = 40.0
	add_child(p)
	p.global_position = hl(Vector3(-1.4, 3.0, -60.0))
	p.finished.connect(p.queue_free)
	p.play()


func _call_wave(t: float, i: int) -> float:
	var env := sin(PI * clampf(t / 4.0, 0.0, 1.0))
	var f := 70.0 - 18.0 * t / 4.0 + 6.0 * sin(t * 1.3)
	return (sin(TAU * f * t) * 0.55 + sin(TAU * f * 1.51 * t) * 0.18 + Sfx._noise(i) * 0.05) * env * env


# ------------------------------------------------------------------ helpers, per tick
func _hold(on: bool) -> void:
	player.set("controls_enabled", not on)
	player.velocity = Vector3.ZERO


func _process(_delta: float) -> void:
	if Game.has_flag("ch11_started"):
		return                                    # the next chapter owns the group and the marker from here on
	_track_camera(_delta)
	if _owner != Scene.NONE and _owner != Scene.ENTER:
		player.set("controls_enabled", false)    # only the scene that owns the moment gives the player back
	_tick -= _delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	_road_tick()
	_house_tick()
	_guide()
