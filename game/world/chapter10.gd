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
var _tick := 0.0
var _route_i := 0
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
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"roster": c9.roster(), "sarah": "", "choice": ""}
	_streams["call"] = Sfx._make(4.0, _call_wave)
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
			_prop(CHAINLINK, "C10_Fence", at, yaw)
			z -= 2.5
		else:
			var g := _prop(GATE, "C10_Gate", at, yaw)
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
func _use_driver(_b: Node) -> void:
	if not Game.has_flag("ch10_plan_done") or _busy.get("car", false):
		return
	_busy["car"] = true
	if not Game.has_flag("ch10_car_door"):
		_open_driver_door(false)
		Sfx.play("door_open", its["driver"].global_position, -4.0, 0.9)
		Game.set_flag("ch10_car_door")
	elif not Game.has_flag("ch10_car_fuel"):
		Game.set_flag("ch10_car_fuel")
		st()["car_fuel"] = "empty"
		Dialogue.say("c10_car_fuel", false, true)
		_hint("Fuel gauge: empty. The engine won't turn over.")
	elif not Game.has_flag("ch10_car_glove"):
		Game.set_flag("ch10_car_glove")             # set with the item: the battery is found once
		p4._got_batteries(1)
		report["car_items"] += 1
		Sfx.play("pickup", its["driver"].global_position, -6.0, 0.9)
		_hint("Glove compartment: a flashlight battery.")
	_busy["car"] = false
	_car_check()


func _use_trunk(_b: Node) -> void:
	if not Game.has_flag("ch10_plan_done") or Game.has_flag("ch10_car_trunk") or _busy.get("car", false):
		return
	Game.set_flag("ch10_car_trunk")
	_open_trunk(false)
	Game.add_item("water_bottle")
	report["car_items"] += 1
	Sfx.play("pickup", its["trunk"].global_position, -6.0, 0.9)
	_hint("Trunk: one bottle of water.")
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
		_refresh_prompts()
	_guide()


func _hint(t: String) -> void:
	if hud.has_method("set_hint"):
		hud.set_hint(t)
		get_tree().create_timer(3.5).timeout.connect(func():
			if is_instance_valid(hud) and hud.hint.text == t:
				hud.set_hint(""))


# ------------------------------------------------------------------ scenes 3-4: the roadblock, the side route, the follower
func _road_tick() -> void:
	var p := player.global_position
	if Game.has_flag("ch10_plan_done") and not Game.has_flag("ch10_car_found") \
			and p.distance_to(CAR_POS) < 12.0:
		Game.set_flag("ch10_car_found")
	if Game.has_flag("ch10_car_done") and not Game.has_flag("ch10_roadblock_seen") and p.x < BLOCK_X + 9.0 and absf(p.z) < 7.0:
		Game.set_flag("ch10_roadblock_seen")
		Dialogue.say("c10_roadblock", false, true)
	if Game.has_flag("ch10_roadblock_seen") and not Game.has_flag("ch10_around_done") and p.x < FENCE_X - 0.8 and p.z < -7.6:
		Game.set_flag("ch10_around_done")             # through the gate, behind the roadside building
		_followed()
	if Game.has_flag("ch10_around_done") and not Game.has_flag("ch10_followed_done") and not _busy.get("creature", false) \
			and p.x < BLOCK_X - 4.0 and p.z > -6.5:
		Game.set_flag("ch10_followed_done")           # back on the road, west of the block
	if Game.has_flag("ch10_followed_done") and not Game.has_flag("ch10_choice_made") and not _busy.get("choice", false) \
			and p.x < CHOICE_X and not world.conversing and not Dialogue.is_busy():
		_sarah_stops()
	if Game.has_flag("ch10_choice_made") and not Game.has_flag("ch10_building_seen") and p.x < OUTSKIRTS_X and not Dialogue.is_busy() \
			and not _busy.get("choice", false):
		Game.set_flag("ch10_building_seen")
		Dialogue.say("c10_outskirts", false, true)


## A sound behind them: the view turns, a Hound's silhouette crosses the fog and is gone behind the buildings.
func _followed() -> void:
	if Game.has_flag("ch10_creature_seen") or _busy.get("creature", false):
		return
	_busy["creature"] = true
	report["creature_runs"] += 1
	Game.set_flag("ch10_creature_seen")
	await get_tree().create_timer(0.8).timeout
	var ps := load(HOUND_PATH) as PackedScene
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
	c8._bark(hound.global_position + Vector3(0, 1.0, 0))
	_hold(true)
	await c8._turn_to(hound.global_position + Vector3(0, 0.8, 0), 0.7)
	c8._hplay(hound, "Walk", 0.0)
	var h := hound
	for i in range(1, HOUND_PATH_PTS.size()):
		if not is_instance_valid(h):
			break
		var to: Vector3 = HOUND_PATH_PTS[i]
		to.y = _floor(to)
		var d := to - h.global_position
		h.rotation.y = atan2(d.x, d.z)
		var tw := h.create_tween()
		tw.tween_property(h, "global_position", to, d.length() / 3.2)
		if i == 1:
			_hold(false)
			Dialogue.say("c10_followed", false, true)
		await tw.finished
	if is_instance_valid(h):
		h.queue_free()
	hound = null
	_busy["creature"] = false
	_guide()


# ------------------------------------------------------------------ scene 5: a difficult choice
func _sarah_condition() -> String:
	return "serious" if String(c8.st().get("injured_condition", "stable")) == "serious" else "stable"


func _sarah_stops() -> void:
	_busy["choice"] = true
	var id := "c10_sarah_" + _sarah_condition()
	st()["sarah"] = "exhausted" if _sarah_condition() == "stable" else "wound_worse"
	await c9._talk_group(id, [sarah, ruth])


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
	if help:
		# an hour by the road: she rests and drinks; it costs a water (or food) from the packs, or exposure
		_hold(true)
		await hud.fade_to(1.0, 0.8)
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
		await hud.fade_to(0.0, 0.8)
		_hold(false)
	else:
		Game.set_flag("ch10_sarah_exhausted")         # recorded for later chapters; she keeps going
	Game.set_flag("ch10_choice_made")
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
	_busy["room"] = true
	Game.set_flag("ch10_entrance_checked")
	await get_tree().create_timer(1.5).timeout
	Dialogue.say("c10_house_clear", false, true)
	Game.set_flag("ch10_refuge_checked")
	_busy["room"] = false


## Everyone comes in after the player (the followers use the open door), then stands in the living room.
func _gather() -> void:
	_busy["gather"] = true
	var t := 0.0
	while t < 14.0:
		var inside := 0
		for k in group():
			if inside_room(_node(k)):
				inside += 1
		if inside == group().size():
			break
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	while Dialogue.is_busy():
		await get_tree().process_frame
	_place_inside()
	var npcs: Array = [ruth, eddie]
	if alive():
		npcs.append(marcus)
	await c9._talk_group("c10_refuge_alive" if alive() else "c10_refuge_lost", npcs)
	Game.set_flag("ch10_refuge_talk_done")
	_busy["gather"] = false
	_refresh_prompts()
	_guide()


## Inside the living room (house-local bounds; the room's trigger area only sees the player).
func inside_room(n: Node3D) -> bool:
	var l := house.to_local(n.global_position)
	var half: Vector3 = ROOM[1] * 0.5
	return absf(l.x - ROOM[0].x) <= half.x and absf(l.z - ROOM[0].z) <= half.z and l.y > 0.3


func _rest(_b: Node) -> void:
	if not Game.has_flag("ch10_refuge_talk_done") or Game.has_flag("chapter_10_complete") or _busy.get("rest", false):
		return
	_busy["rest"] = true
	report["rest_runs"] += 1
	_refresh_prompts()
	_hold(true)
	await hud.fade_to(1.0, 1.2)
	player.heal(30.0)
	Game.set_flag("ch10_refuge_rested")
	hud.location_caption("A FEW HOURS LATER", 2.0)
	await get_tree().create_timer(2.0).timeout
	# the window: the fields barely there beyond the fog; something far off, unexplained
	player.global_position = hl(Vector3(-1.2, 0.7, 5.0))
	player.velocity = Vector3.ZERO
	await hud.fade_to(0.0, 1.4)
	await c8._turn_to(hl(WINDOW), 1.2)
	await get_tree().create_timer(1.2).timeout
	_play_call()
	await get_tree().create_timer(3.0).timeout
	Game.set_flag("chapter_10_complete")             # the next chapter is NOT started here
	st()["completed"] = {"roster": group(), "choice": st().get("choice", ""), "sarah": st().get("sarah", ""),
		"refuge": HOUSE}
	_hold(false)
	_busy["rest"] = false
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
	_tick -= _delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	_road_tick()
	_house_tick()
	_guide()
