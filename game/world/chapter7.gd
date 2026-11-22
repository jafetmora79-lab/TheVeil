extends Node
class_name VeilChapter7
## THE VEIL - Chapter 7 "A Trace of Noah" (Act II). Starts when the player sleeps after Chapter 6 (flag
## ch6_rested); created by chapter6.gd. State: story flags + Game.world_state["ch7"]; loads rebuild the chapter
## without replaying finished events.
##
## Marcus has a lead -> Eddie's warning (Marcus then walks with the player: VeilCompanionFollow) -> out through the
## real front doors (the doors' own interaction, world "market/doors_shut") -> west along the main road to an
## abandoned sedan where the asphalt ends -> E: examine the backpack (key items: the backpack + Noah's note) ->
## read the note in the inventory screen -> the old service road (gravel, barriers, dead-end sign) -> Marcus's
## choice (marcus_trust_search / marcus_cautious_search) -> back through the doors -> report to Eddie ->
## "CHAPTER 7 COMPLETE". No combat, no Hound, no Colossus. Chapter 8 starts only after the next sleep.
## Every travel objective completes only when the PLAYER's own body is inside the destination area.

const FOLLOW := preload("res://game/npc/companion_follow.gd")
const SEDAN := preload("res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Sedan_Damaged.glb")
const BACKPACK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_SmallBackpack.glb")
const NOTEBOOK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_Notebook.glb")
const BARRIER := preload("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_RoadBarrier.glb")
const CONE := preload("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_TrafficCone.glb")
const DEAD_END := preload("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_Sign_DeadEnd.glb")
const STATE := "ch7"

# supermarket-local
const MARCUS_NOTES := Vector3(-2.0, 0.04, 6.9)
const NOTES_ON_COUNTER := Vector3(-2.9, 1.03, 5.4)
const EDDIE_NEARBY := Vector3(6.2, 0.04, 4.05)
# world (collision-mapped: open main road along z -2..2 from the store front to x -150; gravel west of x -68)
const CAR_POS := Vector3(-58.0, 0.15, 4.2)
const CAR_YAW := 1.71                                   # broadside to the road, rear doors facing the traffic lane
const CAR_AREA := [Vector3(-58.0, 1.5, 1.5), Vector3(12.0, 3.0, 9.0)]
const ROAD_AREA := [Vector3(-100.0, 1.5, 0.0), Vector3(8.0, 3.0, 16.0)]
const BARRIER_X := -112.0

var world: Node
var c6: Node
var c5: Node
var p4: Node
var market: Node3D
var player: Node3D
var hud: Node
var eddie: Node3D
var marcus: Node3D
var marcus_follow: VeilCompanionFollow
var doors: Interactable
var car: Node3D
var backpack: Node3D
var its := {}
var _car_area: Area3D
var _road_area: Area3D
var _busy := {}
var _tick := 0.0
var _note_view_t := 0.0


func begin(w: Node, chapter6: Node, restoring: bool) -> void:
	world = w
	c6 = chapter6
	c5 = c6.c5
	p4 = c6.p4
	market = w.market
	player = w.player
	hud = w.hud
	eddie = w.eddie
	marcus = w.marcus
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"marcus": "shelter"}
	_setup_npcs()
	_setup_doors()
	_setup_route()
	_setup_distraction()
	_setup_rest()
	Dialogue.choices_offered.connect(_on_choices)
	var fresh := not Game.has_flag("ch7_started")
	if fresh:
		Game.set_flag("ch7_started")
	_apply(restoring)
	if Game.has_flag("ch7_rested"):
		_start_chapter8(true)
	Game.refresh_objective()
	if fresh:
		_title.call_deferred()


## Chapter 8 continues after the night that follows Chapter 7; it is a child of this node.
var chapter8: Node
func _start_chapter8(restoring: bool) -> void:
	if chapter8 != null:
		return
	chapter8 = load("res://game/world/chapter8.gd").new()
	chapter8.name = "Chapter8"
	add_child(chapter8)
	chapter8.begin(world, self, restoring)


func _title() -> void:
	await get_tree().create_timer(2.6).timeout       # after the wake-up fade
	await hud.chapter_start(8)


func st() -> Dictionary:
	return Game.world_state[STATE]


# ------------------------------------------------------------------ setup
func _setup_npcs() -> void:
	for pair in [["npc_Marcus", _talk_marcus], ["npc_Eddie", _talk_eddie]]:
		var it: Interactable = p4.its.get(pair[0])
		if it:
			it.used.connect(pair[1])
			its[pair[0]] = it
	marcus_follow = FOLLOW.new()
	marcus_follow.name = "Follow"
	marcus_follow.run_speed = 4.6
	marcus.add_child(marcus_follow)
	marcus_follow.setup(marcus, player)
	var notes := NOTEBOOK.instantiate() as Node3D
	notes.name = "C7_MarcusNotes"
	market.add_child(notes)
	notes.position = NOTES_ON_COUNTER
	notes.rotation.y = 0.4


## The supermarket's real front doors: their own interaction (world "market/doors_shut", the box over both leaves).
func _setup_doors() -> void:
	doors = world.interactables.get("market/doors_shut")
	if doors:
		doors.used.connect(_use_doors)
	# Chapter 5/6's exit spot sits on the leaves' inner face; Chapter 7 uses the doors' own box instead,
	# so the old spot must not catch the player's aim
	if c5 and c5.its.has("exit"):
		var ex: Interactable = c5.its["exit"]
		ex.prompt_text = ""
		ex.collision_layer = 0


func _setup_route() -> void:
	car = SEDAN.instantiate() as Node3D
	car.name = "C7_AbandonedSedan"
	world.add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, CAR_YAW), CAR_POS)
	# rear door on the road side stands open; the backpack sits on that rear seat, seen through the opening
	var seat := car.find_child("Marker_Seat_Rear_R", true, false) as Node3D
	var door := car.find_child("Door_RR", true, false) as Node3D
	if seat == null:
		seat = car.find_child("Marker_Seat_Passenger", true, false) as Node3D
	if door:
		var best := 0.0
		var best_d := -INF
		for deg in [70.0, -70.0]:
			var t := Transform3D(door.transform.basis * Basis(Vector3.UP, deg_to_rad(deg)), door.transform.origin)
			var c := (door.get_parent_node_3d().global_transform * t) * Interactable.aabb_of(door).get_center()
			var d := Vector2(c.x - CAR_POS.x, c.z - CAR_POS.z).length()
			if d > best_d:
				best_d = d
				best = deg
		door.transform = Transform3D(door.transform.basis * Basis(Vector3.UP, deg_to_rad(best)), door.transform.origin)
	backpack = BACKPACK.instantiate() as Node3D
	backpack.name = "C7_NoahsBackpack"
	world.add_child(backpack)
	var seat_pos: Vector3 = seat.global_position if seat else CAR_POS + Vector3(0, 0.6, 0)
	backpack.global_position = seat_pos + Vector3(0, 0.02, 0)
	backpack.rotation.y = CAR_YAW + 0.3
	# a generous interaction box: from the seat out through the open door, so the player's ray meets it before
	# the cabin collision (no pixel hunting)
	var it := Interactable.new()
	it.name = "Interact"
	it.kind = "custom"
	it.label = "Backpack"
	it.prompt_text = ""
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var out := Vector2(seat_pos.x - CAR_POS.x, seat_pos.z - CAR_POS.z).normalized()
	var outward := Vector3(out.x, 0, out.y)
	bs.size = Vector3(2.6, 1.8, 2.6)                  # review note #115: aiming at the backpack or the open door is enough, from anywhere within reach
	cs.shape = bs
	it.add_child(cs)
	world.add_child(it)
	it.global_position = seat_pos + outward * 0.9 + Vector3(0, 0.5, 0)
	it.used.connect(_examine_backpack)
	its["backpack"] = it
	# review note #118: the cabin's collision sits between the eye and the backpack: the player's aim assist (a pickup near the crosshair, within reach) sees through the car's own colliders
	it.add_to_group("veil_pickup")
	for co in car.find_children("*", "CollisionObject3D", true, false):
		it.los_ignore.append((co as CollisionObject3D).get_rid())
	if Game.has_flag("ch7_backpack_found"):           # already taken (continue / load): gone from the seat
		backpack.visible = false
		it.collision_layer = 0
	_car_area = world._area("C7_CarArea", CAR_AREA[0], CAR_AREA[1], 2, func(_b): pass)
	_road_area = world._area("C7_ServiceRoadArea", ROAD_AREA[0], ROAD_AREA[1], 2, func(_b): pass)
	# the old service road: the gravel runs on into the fog, closed by barriers, cones and a dead-end sign
	var road := Node3D.new()
	road.name = "C7_ServiceRoadClosure"
	world.add_child(road)
	for i in 7:
		var b := BARRIER.instantiate() as Node3D
		road.add_child(b)
		b.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5 + (0.12 if i % 2 == 0 else -0.08)), Vector3(BARRIER_X, 0.15, -6.0 + i * 2.0))
	for z in [-7.4, -3.2, 3.1, 7.3]:
		var c := CONE.instantiate() as Node3D
		road.add_child(c)
		c.global_position = Vector3(BARRIER_X + 1.6, 0.15, z)
	var sign := DEAD_END.instantiate() as Node3D
	road.add_child(sign)
	sign.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5).rotated(Vector3(0, 0, 1), 0.18), Vector3(BARRIER_X + 0.8, 0.15, 8.6))


func _setup_rest() -> void:
	var r: VeilRestPoint = p4.rest
	if r == null:
		return
	if r.slept.is_connected(c6._on_rest):
		r.slept.disconnect(c6._on_rest)
	r.can_rest = func() -> bool: return Game.has_flag("chapter_7_complete")
	r.slept.connect(_on_rest)


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply(_restoring: bool) -> void:
	# Eddie stays at the supermarket throughout
	c5._reparent(eddie, market)
	world.place_survivor(eddie, EDDIE_NEARBY)
	world.animators["Eddie"].face_towards(c5.ml(Vector3(2.0, 1.5, 0.0)))
	if String(st().get("marcus", "shelter")) == "following":
		c5._reparent(marcus, world)
		marcus_follow.recover_behind(2.4)
		marcus_follow.start()
	else:
		c5._reparent(marcus, market)
		world.place_survivor(marcus, MARCUS_NOTES)
		world.animators["Marcus"].face_towards(c5.ml(NOTES_ON_COUNTER))
	var taken := Game.has_flag("ch7_backpack_found")
	backpack.visible = not taken
	if taken:
		its["backpack"].collision_layer = 0
	_refresh_prompts()
	_guide()


func _refresh_prompts() -> void:
	if its.has("npc_Marcus"):
		its["npc_Marcus"].prompt_text = "[E] Talk" if not Game.has_flag("ch7_marcus_briefing_complete") else ""
	if its.has("npc_Eddie"):
		var eddie_talk := (Game.has_flag("ch7_marcus_briefing_complete") and not Game.has_flag("ch7_eddie_warning_complete")) \
			or (Game.has_flag("ch7_returned_to_supermarket") and not Game.has_flag("ch7_report_complete"))
		its["npc_Eddie"].prompt_text = "[E] Talk" if eddie_talk else ""
	its["backpack"].prompt_text = "E - EXAMINE BACKPACK" if Game.has_flag("ch7_vehicle_reached") and _skitters_done() \
		and not Game.has_flag("ch7_backpack_found") else ""
	if its.has("alarm"):
		var on: bool = _alarm_ready() and not _skitters_done() and not _busy.get("alarm", false)
		its["alarm"].prompt_text = "[E] Pick Up the Bottle" if on else ""
		its["alarm"].collision_layer = 8 if on else 0
	if doors:
		doors.prompt_text = "[E] Open the Doors" if _doors_wanted() and not c5._doors_open else ""


func _doors_wanted() -> bool:
	if Game.has_flag("ch7_eddie_warning_complete") and not Game.has_flag("ch7_departure_complete"):
		return true
	return Game.has_flag("ch7_road_investigation_complete") and not Game.has_flag("ch7_returned_to_supermarket")


## Beacon + HUD marker: only the current destination, cleared on arrival.
var _beacon_at: Variant = null


func _beacon(pos: Variant) -> void:
	if pos == _beacon_at:
		return
	_beacon_at = pos
	world._clear_beacon("c7")
	if pos != null:
		world._beacon("c7", pos, Color(0.8, 0.9, 1.0))


func _guide() -> void:
	var beacon: Variant = null
	var t: Variant = null
	var label := ""
	if not Game.has_flag("ch7_marcus_briefing_complete"):
		t = marcus
		label = "MARCUS"
	elif not Game.has_flag("ch7_eddie_warning_complete"):
		t = eddie
		label = "EDDIE"
	elif not Game.has_flag("ch7_departure_complete"):
		t = c5.ml(Vector3(0, 1.4, 0.4))
		label = "DOORS"
	elif not Game.has_flag("ch7_vehicle_reached") and not Game.has_flag("ch7_skitters_seen"):
		t = CAR_POS + Vector3(0, 1.8, 0)
		label = "VEHICLE"
		beacon = CAR_POS + Vector3(0, 3.0, 0)
	elif not _skitters_done():
		t = THROW_POS + Vector3(0, 1.6, 0)             # (QA-008) the noise first; the backpack only once they are gone
		label = "THROW SPOT"
	elif not Game.has_flag("ch7_backpack_found"):
		t = its["backpack"].global_position
		label = "BACKPACK"
	elif not Game.has_flag("noah_clue_backpack"):
		t = null
	elif not Game.has_flag("ch7_road_investigation_complete"):
		t = ROAD_AREA[0] + Vector3(0, 0.3, 0)
		label = "SERVICE ROAD"
		if not Game.has_flag("ch7_road_reached"):
			beacon = ROAD_AREA[0] + Vector3(0, 1.5, 0)
	elif not Game.has_flag("ch7_returned_to_supermarket"):
		t = c5.ml(Vector3(0, 1.4, -1.5)) if not c5._in_store(market.to_local(player.global_position)) else c5.ml(Vector3(0, 1.4, 5.0))
		label = "SUPERMARKET"
	elif not Game.has_flag("ch7_report_complete"):
		t = eddie
		label = "EDDIE"
	_beacon(beacon)
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


# ------------------------------------------------------------------ scenes 1-3: Marcus, Eddie, departure
func _talk_marcus(_b: Node) -> void:
	if Game.has_flag("ch7_marcus_briefing_complete") or _busy.get("talk", false):
		return
	_busy["talk"] = true
	its["npc_Marcus"].prompt_text = ""
	await c5._talk("c7_marcus", marcus)
	Game.set_flag("ch7_marcus_briefing_complete")
	_busy["talk"] = false
	_refresh_prompts()


func _talk_eddie(_b: Node) -> void:
	if _busy.get("talk", false):
		return
	if Game.has_flag("ch7_returned_to_supermarket") and not Game.has_flag("ch7_report_complete"):
		_report()
		return
	if not Game.has_flag("ch7_marcus_briefing_complete") or Game.has_flag("ch7_eddie_warning_complete"):
		return
	_busy["talk"] = true
	its["npc_Eddie"].prompt_text = ""
	await c5._talk("c7_eddie", eddie)
	# Marcus is ready: he walks with the player from here (to the doors and out)
	st()["marcus"] = "following"
	c5._reparent(marcus, world)
	marcus_follow.start()
	Game.set_flag("ch7_eddie_warning_complete")
	_busy["talk"] = false
	_refresh_prompts()


func _use_doors(_b: Node) -> void:
	if not _doors_wanted() or c5._doors_open:
		return
	c5._set_doors(true)
	_refresh_prompts()


# ------------------------------------------------------------------ scenes 5-6: the vehicle, the backpack, the note
func _examine_backpack(_b: Node) -> void:
	if not Game.has_flag("ch7_vehicle_reached") or not _skitters_done() or Game.has_flag("ch7_backpack_found") \
			or _busy.get("bag", false):
		return
	_busy["bag"] = true
	its["backpack"].prompt_text = ""
	await c5._talk("c7_backpack", marcus)
	# a key item, through the normal inventory (no new interface); the note inside is its own document
	Game.add_item("noahs_backpack")
	Sfx.play("pickup", backpack.global_position, -6.0, 0.9)
	backpack.visible = false
	its["backpack"].collision_layer = 0
	Game.set_flag("ch7_backpack_found")
	if hud.has_method("set_hint"):
		hud.set_hint("TAB  -  INVENTORY: select Noah's backpack and OPEN it")
	_busy["bag"] = false
	_refresh_prompts()


## The note counts as examined only when it has been on screen in the inventory's detail view for a moment.
func _note_tick(delta: float) -> void:
	if not Game.has_flag("ch7_backpack_found") or Game.has_flag("noah_clue_backpack"):
		return
	var inv = hud.get("inv_panel")
	if not Game.has_flag("ch7_note_read"):
		var showing := false
		if inv and inv.visible:
			var ids: Array = inv.get("_ids")
			var sel: int = inv.get("_sel")
			showing = sel >= 0 and sel < ids.size() and ids[sel] == "noahs_note"
		_note_view_t = _note_view_t + delta if showing else 0.0
		if _note_view_t > 1.2:
			Game.set_flag("ch7_note_read")
	elif not (inv and inv.visible) and not _busy.get("note", false) and not Dialogue.is_busy():
		_after_note()


func _after_note() -> void:
	_busy["note"] = true
	if hud.has_method("set_hint"):
		hud.set_hint("")
	await c5._talk("c7_note", marcus)
	Game.set_flag("noah_clue_backpack")
	Game.remove_item("noahs_note")                    # read and done: neither the backpack nor its note stays in the inventory (review note #107)
	Game.remove_item("noahs_backpack")
	_busy["note"] = false
	_guide()


# ------------------------------------------------------------------ scene 7: the old service road
func _road() -> void:
	if Game.has_flag("ch7_road_reached") or not Game.has_flag("noah_clue_backpack"):
		return
	Game.set_flag("ch7_road_reached")
	c5._talk_start("c7_road", marcus)


func _on_choices(id: String, choices: Array) -> void:
	if id != "c7_road" or Game.has_flag("ch7_road_investigation_complete") or _busy.get("choice", false):
		return
	_busy["choice"] = true
	var texts: Array = []
	for c in choices:
		texts.append(c["text"])
	var i: int = await p4.choice.ask("", texts, player)
	var c: Dictionary = choices[clampi(i, 0, choices.size() - 1)]
	st()["marcus_choice"] = "trust" if c["flag"] == "marcus_trust_search" else "cautious"
	Game.set_flag(c["flag"])                         # mutually exclusive: only one of the two is ever set
	await c5._say_wait(c["next"])
	Game.set_flag("ch7_road_investigation_complete")
	_busy["choice"] = false
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ per tick
func _process(delta: float) -> void:
	if Game.has_flag("ch8_started"):
		return                                    # Chapter 8 owns the NPCs, the doors and the marker from here on
	_note_tick(delta)
	_pack_tick(delta)
	if not _busy.get("fleeing", false):
		_patrol_tick(delta)
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	_guide()
	_refresh_prompts()
	var pl: Vector3 = market.to_local(player.global_position)
	var ml_: Vector3 = market.to_local(marcus.global_position)
	var following := String(st().get("marcus", "")) == "following"
	# the front doors close by themselves once nobody of the group is at them (they are opened by hand)
	var on_trip: bool = world.expedition != null and world.expedition.active()     # a supply run keeps them open
	if c5._doors_open and not on_trip and not _pack_on and not c5._near_doors(pl) and not (following and c5._near_doors(ml_)) and not c5._followers_near_doors():
		c5._set_doors(false)
	if following and not Game.has_flag("ch7_departure_complete") and c5._away_from_store(pl, 3.0):
		Game.set_flag("ch7_departure_complete")
	if following and Game.has_flag("ch7_departure_complete") and not Game.has_flag("ch7_walk_said") \
			and c5._away_from_store(pl, 12.0) and not Dialogue.is_busy():
		Game.set_flag("ch7_walk_said")
		Dialogue.say("c7_walk", false, true)
	if Game.has_flag("ch7_departure_complete") and skitters.is_empty() and not _skitters_done():
		_spawn_car_skitters()                      # (QA-004) already at the car, well before the player gets there
	if not skitters.is_empty() and not Game.has_flag("ch7_skitters_seen") and not Game.has_flag("ch7_vehicle_reached") \
			and not _busy.get("intro", false) and not Dialogue.is_busy() and not world.conversing and player.controls_enabled \
			and Vector2(player.global_position.x - CAR_POS.x, player.global_position.z - CAR_POS.z).length() < INTRO_DIST:
		_skitter_intro()
	if Game.has_flag("ch7_departure_complete") and not Game.has_flag("ch7_vehicle_reached") and _car_area.overlaps_body(player):
		Game.set_flag("ch7_vehicle_reached")
		_spawn_car_skitters()
		_refresh_prompts()
	_skitter_guard()
	if Game.has_flag("noah_clue_backpack") and not Game.has_flag("ch7_road_reached") and _road_area.overlaps_body(player):
		_road()
	# a load between reaching the road and the choice: Marcus's lines and the choice come again
	if Game.has_flag("ch7_road_reached") and not Game.has_flag("ch7_road_investigation_complete") and not _busy.get("choice", false) \
			and not _busy.get("road_reoffer", false) and not Dialogue.is_busy() and not p4.choice.is_open():
		_busy["road_reoffer"] = true
		Dialogue.say("c7_road", false, true)
	if Game.has_flag("ch7_road_investigation_complete") and not Game.has_flag("ch7_returned_to_supermarket"):
		var player_in: bool = c5._in_store(pl)
		marcus_follow.gap = 1.0 if player_in else 2.4
		if player_in and c5._in_store(ml_, 0.1):
			_returned()


# ------------------------------------------------------------------ the pack comes back (review note #98)
## Halfway home from the service road the screen turns: the skitters that were drawn off are back, out of the fog behind the player, and give chase. The player must run for the store (control is theirs
## again after the look). They stop at the glass; a bite (never fatal) if one catches up.
var _pack: Array = []
var _pack_on := false


func _pack_tick(delta: float) -> void:
	if _pack_on:
		_pack_run(delta)
		return
	if not Game.has_flag("ch7_road_investigation_complete") or Game.has_flag("ch7_returned_to_supermarket") or Game.has_flag("ch7_pack_chase") 			or _busy.get("pack", false) or player == null:
		return
	if player.global_position.x < -42.0 or c5._in_store(market.to_local(player.global_position)) or not player.controls_enabled or Dialogue.is_busy() or world.conversing:
		return
	_pack_cinematic()


func _pack_cinematic() -> void:
	_busy["pack"] = true
	Game.set_flag("ch7_pack_chase")
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	var ps := load(VeilMeshyNpcs.monster_scene(SKITTER_PATH)) as PackedScene
	var back := Vector3(-1, 0, 0)                      # the road they came along: west
	var cam: Camera3D = player.camera
	var yaw0: float = player.rotation.y
	var pitch0: float = player.head.rotation.x
	var p0 := player.global_position
	var yaw1 := atan2(1.0, 0.0)                         # facing -X (west): rotation.y = +90 degrees looks along -X
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): player.set_yaw_pitch(lerp_angle(yaw0, yaw1, k), lerpf(pitch0, 0.0, k)), 0.0, 1.0, 0.9)
	await tw.finished
	Sfx.play("colossus_call", p0 + Vector3(-30, 6, 0), 2.0, 1.9)
	if ps:
		for i in 3:
			var sk := ps.instantiate() as Node3D
			sk.name = "C7_PackSkitter_%d" % i
			world.add_child(sk)
			if sk is CollisionObject3D:
				(sk as CollisionObject3D).collision_layer = 0
				(sk as CollisionObject3D).collision_mask = 0
			sk.set_physics_process(false)
			var at := Vector3(p0.x - 28.0 - i * 4.0, 0.15, p0.z + (i - 1) * 4.5)
			sk.global_position = at
			sk.rotation.y = atan2(1.0, 0.0)             # facing east, at the player
			VeilCreatureLook.apply_skitter(sk, at.y)
			VeilCreatureLook.skitter_anim(sk, "scuttle", 12.0)
			_pack.append(sk)
	var fov0 := cam.fov
	var zt := create_tween()
	zt.tween_property(cam, "fov", fov0 * 0.8, 1.6)
	await get_tree().create_timer(1.8).timeout          # they pour out of the mist, coming
	var z2 := create_tween()
	z2.tween_property(cam, "fov", fov0, 0.4)
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_method(func(k: float): player.set_yaw_pitch(lerp_angle(yaw1, yaw0, k), 0.0), 0.0, 1.0, 0.6)
	await turn.finished
	cam.fov = fov0
	_pack_on = true
	_busy["pack"] = false
	_eddie_holds_door()
	_pack_run_struggle()                              # click to run the set path to the doors (review note #120)


var _pack_bite_t := 0.0


## One chase step for a skitter: toward the player, but never through the glass line of the front doors.
func _pack_step(sk: Node3D, d: Vector3, speed: float, delta: float) -> void:
	var dz: float = c5._door_spot().z
	var np: Vector3 = sk.global_position + d.normalized() * speed * delta
	var l: Vector3 = market.to_local(np)
	if l.z > dz - 0.6 and absf(l.x) < 9.0:
		return
	sk.global_position = np


var _eddie_prev := Vector3.ZERO
var _pack_cine := false


## Eddie hears it: he is at the doors, holding them open, when the player arrives (placed while the player is still far away in the mist).
func _eddie_holds_door() -> void:
	c5._set_doors(true)
	var ea = world.animators.get("Eddie")
	if ea and eddie and is_instance_valid(eddie):
		var dz: float = c5._door_spot().z
		c5._reparent(eddie, market)
		_eddie_prev = eddie.position
		eddie.position = Vector3(-1.9, 0.04, dz + 0.9)             # inside the vestibule, left of the way in (the way in is on the right)
		ea.face_towards(market.to_global(Vector3(0, 0, dz - 6.0)))
		Dialogue.say("c7_pack_eddie", false, true)


## The run for the store (review note #120): click to run along a set path to the doors and in; the skitters run it behind. Fail = caught and dragged off into the veil.
func _pack_run_struggle() -> void:
	_pack_cine = true
	var dz: float = c5._door_spot().z
	var p0: Vector3 = player.global_position
	var l0: Vector3 = market.to_local(p0)
	var gy: float = p0.y
	var iy: float = market.to_global(Vector3(0, 0.04, 0)).y
	var w := func(x: float, z: float, y: float) -> Vector3:
		var g: Vector3 = market.to_global(Vector3(x, 0.0, z))
		return Vector3(g.x, y, g.z)
	var pts: Array = [p0, w.call(clampf(l0.x, -30.0, 30.0), dz - 8.0, gy), w.call(0.0, dz - 8.0, gy), w.call(0.0, dz - 1.5, gy)]
	var door_i := pts.size()
	pts.append(w.call(0.0, dz, iy))
	pts.append(w.call(1.1, 1.4, iy))                       # the way through the vestibule wall is on the right
	pts.append(w.call(1.5, 3.0, iy))
	pts.append(w.call(1.8, 6.5, iy))
	var rs = load("res://game/encounters/run_struggle.gd").new()
	add_child(rs)
	var r: Dictionary = await rs.run(world, pts, _pack, {"from_dir": Vector3(-1, 0, 0), "lead": 34.0, "chase_speed": 5.0, "spacing": 3.0, "seconds": 12.0,
		"title": "RUN!  CLICK RAPIDLY", "hint": "LEFT CLICK, AGAIN AND AGAIN  -  GET TO THE STORE", "cap_index": door_i, "cap_gap": 0.9})
	rs.queue_free()
	if bool(r.get("won", false)):
		await _pack_door_finish(dz)
	else:
		await _pack_caught()


## They catch up: they pile on, drag the player back into the mist, black, YOU DIED.
func _pack_caught() -> void:
	var pp: Vector3 = player.global_position
	var cam: Camera3D = get_viewport().get_camera_3d()
	Sfx.play("hurt", pp, 4.0)
	var k := 0
	for sk in _pack:
		if is_instance_valid(sk):
			var off := Vector3(-1.1 - k * 0.3, 0.0, (k - 1) * 0.9)
			sk.global_position = Vector3(pp.x + off.x, sk.global_position.y, pp.z + off.z)
			sk.rotation.y = atan2(pp.x - sk.global_position.x, pp.z - sk.global_position.z)
			VeilCreatureLook.skitter_anim(sk, "attack", 0.0, 0.05)
		k += 1
	var away := pp + Vector3(-16.0, 0.0, 3.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "global_position", away, 2.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(f: float): player.set_yaw_pitch(player.rotation.y, lerpf(player.head.rotation.x, -0.9, f)), 0.0, 1.0, 1.6)
	var follow := true
	var tf := create_tween()
	tf.tween_method(func(_v: float):
		if follow:
			var j := 0
			for sk in _pack:
				if is_instance_valid(sk):
					sk.global_position = Vector3(player.global_position.x + 1.0 + j * 0.4, sk.global_position.y, player.global_position.z + (j - 1) * 0.8)
				j += 1, 0.0, 1.0, 2.8)
	for i in 5:
		world._shake(cam, 0.4, 0.05)
		Sfx.play("colossus_call", player.global_position, 1.0, 1.9)
		await get_tree().create_timer(0.5).timeout
	await hud.fade_to(1.0, 0.6)
	follow = false
	for sk in _pack:
		if is_instance_valid(sk):
			sk.queue_free()
	_pack.clear()
	_pack_on = false
	_pack_cine = false
	player.set_physics_process(true)
	player.damage(9999.0, away)                        # the death scene: YOU DIED, RETRY


## Inside: the player turns, Eddie shoves the doors shut, the skitters hit the glass three times, then run back the way they came.
func _pack_door_finish(dz: float) -> void:
	var door_w: Vector3 = market.to_global(Vector3(0, 0, dz))
	player.set_physics_process(true)
	player.velocity = Vector3.ZERO
	var y0: float = player.rotation.y
	var dback: Vector3 = door_w - player.global_position
	dback.y = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): player.set_yaw_pitch(lerp_angle(y0, atan2(-dback.x, -dback.z), k), lerpf(player.head.rotation.x, 0.0, k)), 0.0, 1.0, 0.45)
	var ea = world.animators.get("Eddie")
	if ea:
		ea.face_towards(door_w)
		ea.talk(2.0)
	Dialogue.say("c7_pack_door", false, true)
	await get_tree().create_timer(0.5).timeout
	c5._set_doors(false)                         # Eddie shoves the doors shut
	for i in 3:                                  # the slams
		for sk in _pack:
			if is_instance_valid(sk):
				sk.rotation.y = atan2(0.0, 1.0)
				VeilCreatureLook.skitter_anim(sk, "attack", 0.0, 0.05)
		Sfx.play("impact", door_w + Vector3(0, 1.0, 0), 4.0, 0.8 + i * 0.1)
		world._shake(get_viewport().get_camera_3d(), 0.3, 0.04)
		await get_tree().create_timer(0.45).timeout
	# they give up and run back west, the way they came
	var k := 0
	for sk in _pack:
		if is_instance_valid(sk):
			var away: Vector3 = sk.global_position + Vector3(-50.0, 0.0, (k - 1) * 10.0)
			sk.rotation.y = atan2(away.x - sk.global_position.x, away.z - sk.global_position.z)
			VeilCreatureLook.skitter_anim(sk, "scuttle", 12.0)
			var mv: Tween = sk.create_tween()
			mv.tween_property(sk, "global_position", away, 5.0)
			mv.tween_callback(_leave_unseen.bind(sk))
		k += 1
	_pack.clear()
	await get_tree().create_timer(0.8).timeout
	player.controls_enabled = true
	if hud.has_method("set_hint"):
		hud.set_hint("")
	# Eddie goes back to where he was
	if ea and eddie and is_instance_valid(eddie):
		ea.walk_to([Vector3(1.1, 0.04, 1.4), Vector3(1.5, 0.04, 3.0), _eddie_prev], 1.6)
	_pack_on = false
	_pack_cine = false


func _pack_run(delta: float) -> void:
	if _pack_cine:
		return
	_pack_bite_t = maxf(_pack_bite_t - delta, 0.0)
	var done: bool = c5._in_store(market.to_local(player.global_position)) or Game.has_flag("ch7_returned_to_supermarket")
	var alive := 0
	for sk in _pack:
		if not is_instance_valid(sk):
			continue
		alive += 1
		var d: Vector3 = player.global_position - sk.global_position
		d.y = 0.0
		var dist := d.length()
		if done:
			# they stop at the glass and are gone once nobody looks
			if dist < 14.0 or dist > 60.0:
				_pack.erase(sk)
				_leave_unseen(sk)
			else:
				VeilCreatureLook.skitter_anim(sk, "scuttle", 12.0)
				sk.rotation.y = atan2(-d.x, -d.z)
				sk.global_position -= d.normalized() * 10.0 * delta
			continue
		sk.rotation.y = atan2(d.x, d.z)
		if dist > 1.9:
			_pack_step(sk, d, 5.2, delta)           # just faster than the sprint (4.3 m/s): they only catch the player who dawdles or stops
		elif _pack_bite_t <= 0.0:
			_pack_bite_t = 2.0
			VeilCreatureLook.skitter_anim(sk, "attack", 0.0, 0.05)
			var hp = player.get("health")
			if player.has_method("damage") and hp != null:
				player.damage(minf(10.0, maxf(float(hp) - 5.0, 0.0)), sk.global_position)
	if done and _pack.is_empty():
		_pack_on = false
		if hud.has_method("set_hint"):
			hud.set_hint("")
	elif not done and alive == 0:
		_pack_on = false


func _returned() -> void:
	marcus_follow.stop()
	c5._reparent(marcus, market)
	st()["marcus"] = "shelter"
	world.npc_walk("Marcus", MARCUS_NOTES, 1.2)
	Game.set_flag("ch7_returned_to_supermarket")
	_refresh_prompts()


# ------------------------------------------------------------------ scene 9: report, completion
func _report() -> void:
	if Game.has_flag("ch7_report_complete") or _busy.get("report", false):
		return
	_busy["report"] = true
	its["npc_Eddie"].prompt_text = ""
	await c5._talk("c7_report", eddie)
	Game.set_flag("ch7_report_complete")
	Game.set_flag("chapter_7_complete")              # Chapter 8 is NOT started here
	_busy["report"] = false
	_refresh_prompts()
	if p4.rest:
		p4.rest.get_parent().visible = true
		p4.rest.interactable.prompt_text = "[E] Sleep"
	await hud.chapter_complete(8)


func _on_rest(_id: String) -> void:
	# the next morning is Chapter 8 (game/world/chapter8.gd); started while the screen is still black
	var report: Dictionary = p4.record_night("ch7_rested")
	Game.set_flag("ch7_rested")
	_start_chapter8(false)
	if p4.flashlight:
		p4.flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	p4.show_night_report(report)
	p4.rest.interactable.prompt_text = "[E] Sleep"


# ------------------------------------------------------------------ Skitters at the car, the noise distraction
## Gone once drawn off - or once the backpack was found (saves from before this puzzle existed have no flag for it,
## and must not get Skitters back at the car in later chapters).
func _skitters_done() -> bool:
	return Game.has_flag("ch7_skitters_gone") or Game.has_flag("ch7_backpack_found")


## Two Skitters crouch around the car (survival expansion): the backpack cannot be reached while they are there.
## A parked car back down the road has an alarm: set it off and they scuttle to the noise and away into the fog.
## Getting too close first is answered by a lunge (a non-lethal bite and a shove): the encounter stays recoverable.
const SKITTER_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const ALARM_CAR := preload("res://THE_VEIL_ASSETS_V2/05_Vehicles/Traffic_Variants/VEH_Sedan_Traffic_Beige.glb")
const ALARM_POS := Vector3(-40.0, 0.15, 4.0)
const SKITTER_SPOTS := [Vector3(-56.0, 0.15, 2.2), Vector3(-60.0, 0.15, 1.8)]
const SKITTER_EXIT := [Vector3(-84.0, 0.15, 24.0), Vector3(-88.0, 0.15, -20.0)]    ## they go off WEST, away from the player (review note #97)
const THROW_POS := Vector3(-24.0, 0.15, 3.0)       ## where the bottle is thrown from: 30 m from the wreck, 16 m from the alarm car - never near them
var skitters: Array = []
var _lunge_t := 0.0
var _alarm_stream: AudioStream


func _setup_distraction() -> void:
	var c := ALARM_CAR.instantiate() as Node3D
	c.name = "C7_AlarmCar"
	world.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), ALARM_POS)
	var s := Node3D.new()
	s.name = "C7_Alarm"
	world.add_child(s)
	s.global_position = THROW_POS + Vector3(0.0, 0.6, 0.0)
	_bottle_prop = _make_bottle()
	world.add_child(_bottle_prop)
	_bottle_prop.global_position = THROW_POS + Vector3(0.0, 0.05, 0.0)
	_bottle_prop.rotation = Vector3(0.0, 0.6, PI * 0.5)       # lying on the road
	_bottle_prop.visible = not _skitters_done()
	_alarm_lights = _make_alarm_lights(c)
	var it := Interactable.attach(s, {"kind": "custom", "label": "Car", "prompt_text": ""})
	var cs := it.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = Vector3(3.0, 1.6, 3.0)
	cs.position = Vector3.ZERO
	(cs.shape as BoxShape3D).size = Vector3(3.0, 1.4, 3.0)
	it.used.connect(_set_off_alarm)
	its["alarm"] = it
	_alarm_stream = Sfx._make(0.5, func(t: float, _i: int) -> float: return sin(TAU * (880.0 if t < 0.25 else 660.0) * t) * 0.35, true)
	if (Game.has_flag("ch7_departure_complete") or Game.has_flag("ch7_vehicle_reached")) and not _skitters_done():
		_spawn_car_skitters.call_deferred()


func _spawn_car_skitters() -> void:
	if not skitters.is_empty() or _skitters_done():
		return
	var ps := load(VeilMeshyNpcs.monster_scene(SKITTER_PATH)) as PackedScene
	if ps == null:
		Game.set_flag("ch7_skitters_gone")
		return
	for i in SKITTER_SPOTS.size():
		var sk := ps.instantiate() as Node3D
		sk.name = "C7_CarSkitter_%d" % i
		world.add_child(sk)
		if sk is CollisionObject3D:
			(sk as CollisionObject3D).collision_layer = 0
			(sk as CollisionObject3D).collision_mask = 0
		sk.set_physics_process(false)
		sk.global_position = SKITTER_SPOTS[i]
		sk.rotation.y = atan2(SKITTER_SPOTS[i].x - CAR_POS.x, SKITTER_SPOTS[i].z - CAR_POS.z)
		VeilCreatureLook.apply_skitter(sk, SKITTER_SPOTS[i].y)
		VeilCreatureLook.skitter_anim(sk, "idle")
		skitters.append(sk)
		_patrol[sk] = {"a": atan2(SKITTER_SPOTS[i].z - CAR_POS.z, SKITTER_SPOTS[i].x - CAR_POS.x), "dir": 1.0 if i == 0 else -1.0,
			"pause": randf_range(0.5, 2.0), "busy": 0.0, "walk": 3.0}


## (QA-004) Around the car until drawn off: a slow crawl along a ring about the car, stopping now and then to
## twitch, the odd change of direction. Never far from it.
const PATROL_R := 3.4
const PATROL_SPEED := 0.9
const INTRO_DIST := 24.0
var _patrol := {}


func _patrol_tick(delta: float) -> void:
	for sk in _patrol.keys():
		if not is_instance_valid(sk):
			_patrol.erase(sk)
			continue
		var pt: Dictionary = _patrol[sk]
		var n := sk as Node3D
		if float(pt["busy"]) > 0.0:                    # mid-lunge
			pt["busy"] = maxf(float(pt["busy"]) - delta, 0.0)
			continue
		if float(pt["pause"]) > 0.0:
			pt["pause"] = float(pt["pause"]) - delta
			VeilCreatureLook.skitter_anim(n, "idle")
			if float(pt["pause"]) <= 0.0:
				pt["walk"] = randf_range(2.5, 6.0)
				if randf() < 0.3:
					pt["dir"] = -float(pt["dir"])
			continue
		pt["a"] = float(pt["a"]) + float(pt["dir"]) * PATROL_SPEED / PATROL_R * delta
		var to := CAR_POS + Vector3(cos(float(pt["a"])) * PATROL_R, 0.0, sin(float(pt["a"])) * PATROL_R)
		var d: Vector3 = to - n.global_position
		d.y = 0.0
		if d.length() > 0.001:
			n.rotation.y = atan2(d.x, d.z)
		n.global_position = Vector3(to.x, n.global_position.y, to.z)
		VeilCreatureLook.skitter_anim(n, "crawl", PATROL_SPEED)
		pt["walk"] = float(pt["walk"]) - delta
		if float(pt["walk"]) <= 0.0:
			pt["pause"] = randf_range(1.0, 2.5)


## (QA-008) The first sight of them: a short first-person look (turn to the car, a slight zoom), then the talk.
func _skitter_intro() -> void:
	_busy["intro"] = true
	Game.set_flag("ch7_skitters_seen")
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	var v: Vector3 = (CAR_POS + Vector3(0, 0.5, 0)) - cam.global_position
	var yaw0: float = player.rotation.y
	var pitch0: float = player.head.rotation.x
	var yaw1 := atan2(-v.x, -v.z)
	var pitch1 := asin(clampf(v.normalized().y, -1.0, 1.0))
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): player.set_yaw_pitch(lerp_angle(yaw0, yaw1, k), lerpf(pitch0, pitch1, k)), 0.0, 1.0, 1.2)
	tw.parallel().tween_property(cam, "fov", fov0 * 0.75, 1.4)
	await tw.finished
	qa_report["intro_facing"] = (-cam.global_transform.basis.z).dot(v.normalized())
	await get_tree().create_timer(2.0).timeout         # they keep moving around the car, in view
	var back := create_tween()
	back.tween_property(cam, "fov", fov0, 0.6)
	await back.finished
	cam.fov = fov0
	await c5._talk("c7_skitters_intro", marcus)
	player.controls_enabled = true
	Game.set_flag("ch7_vehicle_reached")             # the car is found; the way to it now goes through the noise
	if hud.has_method("set_hint"):
		hud.set_hint("Skitters at the car. Stay back: throw something at the parked car up the road from where they cannot see you.")
	_busy["intro"] = false
	_refresh_prompts()
	_guide()


func _alarm_ready() -> bool:
	return Game.has_flag("ch7_vehicle_reached") or Game.has_flag("ch7_skitters_seen")


## Too close while they are at the car: one of them turns, lunges (Attack_Lunge) and bites at the contact moment
## (never a killing bite); the player is pushed back. (QA-006)
func _skitter_guard() -> void:
	_lunge_t = maxf(_lunge_t - 0.2, 0.0)
	if skitters.is_empty() or _skitters_done() or _lunge_t > 0.0 or _busy.get("fleeing", false):
		return
	for sk in skitters:
		if is_instance_valid(sk) and (sk as Node3D).global_position.distance_to(player.global_position) < 7.5:
			_lunge_t = 3.0
			_lunge(sk)
			break


func _lunge(sk: Node3D) -> void:
	# review note #45: the Skitter RUNS at the player (a fast scuttle), springs the last stretch (the lunge clip over a hop), bites at the contact, and is back at its place at once
	var home: Vector3 = sk.global_position
	var d := player.global_position - sk.global_position
	d.y = 0.0
	var dist := d.length()
	sk.rotation.y = atan2(d.x, d.z)
	var dir := d.normalized() if dist > 0.01 else Vector3.FORWARD
	var stop: Vector3 = player.global_position - dir * 1.6
	stop.y = home.y
	var ap_run := VeilCreatureLook.skitter_anim(sk, "scuttle", 16.0)
	var ap := ap_run
	var dur := 0.7
	qa_report["lunge_anim"] = false
	if _patrol.has(sk):
		_patrol[sk]["busy"] = 6.0
	Sfx.play("door_close", sk.global_position, -6.0, 1.8)
	var run_len := maxf(sk.global_position.distance_to(stop) - 3.2, 0.0)
	if run_len > 0.2:
		var mid: Vector3 = home + dir * run_len
		var tr := sk.create_tween()
		tr.tween_property(sk, "global_position", mid, run_len / 16.0)
		await tr.finished
	if not is_instance_valid(sk) or _skitters_done():
		return
	d = player.global_position - sk.global_position
	d.y = 0.0
	sk.rotation.y = atan2(d.x, d.z)
	ap = VeilCreatureLook.skitter_anim(sk, "attack", 0.0, 0.05)
	if ap and ap.has_animation("Attack_Lunge"):
		dur = clampf(ap.get_animation("Attack_Lunge").length, 0.35, 0.8)
	qa_report["lunge_anim"] = ap != null and ap.current_animation == "Attack_Lunge"
	var from: Vector3 = sk.global_position
	var to: Vector3 = player.global_position - d.normalized() * 1.1
	to.y = from.y
	var hop := sk.create_tween()
	hop.tween_method(func(k: float):
		sk.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.7, 0), 0.0, 1.0, dur * 0.55)
	await get_tree().create_timer(dur * 0.5).timeout   # the contact moment of the lunge
	if not is_instance_valid(sk) or _skitters_done():
		return
	if sk.global_position.distance_to(player.global_position) < 5.5:
		var hp = player.get("health")
		if player.has_method("damage") and hp != null:
			player.damage(minf(10.0, maxf(float(hp) - 5.0, 0.0)), sk.global_position)
		report_lunges += 1
	await get_tree().create_timer(dur * 0.4).timeout
	if not is_instance_valid(sk) or _skitters_done():
		return
	VeilCreatureLook.skitter_anim(sk, "scuttle", 9.0)                      # and scuttles straight back to its place
	sk.rotation.y = atan2(home.x - sk.global_position.x, home.z - sk.global_position.z)
	var back := sk.create_tween()
	back.tween_property(sk, "global_position", home, maxf(sk.global_position.distance_to(home) / 9.0, 0.2))
	await back.finished
	if is_instance_valid(sk) and _patrol.has(sk):
		_patrol[sk]["busy"] = 0.3


var report_lunges := 0
var qa_report := {}


var _bottle_prop: Node3D
var _alarm_lights: Array = []


func _make_bottle() -> Node3D:
	var b := Node3D.new()
	b.name = "C7_Bottle"
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.42, 0.3, 0.9)
	m.roughness = 0.2
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 0.2
	cm.material = m
	body.mesh = cm
	b.add_child(body)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.016
	nm.bottom_radius = 0.035
	nm.height = 0.1
	nm.material = m
	neck.mesh = nm
	neck.position = Vector3(0, 0.15, 0)
	b.add_child(neck)
	return b


## Four amber lights at the corners of the alarm car (off until the alarm goes).
func _make_alarm_lights(car: Node3D) -> Array:
	var out: Array = []
	for sx in [-0.8, 0.8]:
		for sz in [-2.1, 2.1]:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.62, 0.15)
			l.light_energy = 3.0
			l.omni_range = 5.0
			l.visible = false
			car.add_child(l)
			l.position = Vector3(sx, 0.75, sz)
			var e := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.25, 0.14, 0.06)
			var em := StandardMaterial3D.new()
			em.albedo_color = Color(1.0, 0.7, 0.2)
			em.emission_enabled = true
			em.emission = Color(1.0, 0.6, 0.1)
			em.emission_energy_multiplier = 4.0
			bm.material = em
			e.mesh = bm
			e.visible = false
			l.add_child(e)
			out.append(l)
	return out


func _blink_alarm_lights(seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_inside_tree():
		var on := int(t / 0.35) % 2 == 0
		for l in _alarm_lights:
			if is_instance_valid(l):
				l.visible = on
				(l.get_child(0) as Node3D).visible = on
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	for l in _alarm_lights:
		if is_instance_valid(l):
			l.visible = false
			(l.get_child(0) as Node3D).visible = false


## The throw: Marcus points out the car, the bottle is picked up off the road, lifted, thrown in an arc with a spin and shatters on the car.
func _throw_bottle() -> void:
	var to: Vector3 = ALARM_POS + Vector3(0, 1.1, 0)
	var b: Node3D = _bottle_prop
	if b == null or not is_instance_valid(b):
		return
	# pick up: it rises from the road into the hand (in front of the camera)
	var hand := func() -> Vector3: return player.camera.global_position + player.camera.global_transform.basis * Vector3(0.22, -0.25, -0.55)
	var from0: Vector3 = b.global_position
	var rise := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_method(func(k: float):
		b.global_position = from0.lerp(hand.call(), k)
		b.rotation = b.rotation.lerp(Vector3(0, b.rotation.y, 0), k), 0.0, 1.0, 0.6)
	Sfx.play("pickup", from0, -6.0, 1.1)
	await rise.finished
	# the wind-up: the hand draws back, then the throw
	var wind := create_tween()
	wind.tween_method(func(k: float): b.global_position = hand.call() + player.camera.global_transform.basis * Vector3(0.1, 0.12, 0.2) * k, 0.0, 1.0, 0.3)
	await wind.finished
	var from: Vector3 = b.global_position
	var tw := create_tween()
	tw.tween_method(func(k: float):
		b.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 3.0, 0)
		b.rotation.x = k * 16.0, 0.0, 1.0, 0.85)
	await tw.finished
	Sfx.play("impact", to, 3.0, 2.2)
	Sfx.play("impact", to, 0.0, 1.5)
	b.visible = false
	if _bottle_prop and is_instance_valid(_bottle_prop):
		_bottle_prop.queue_free()
	_bottle_prop = null


func _set_off_alarm(_b: Node) -> void:
	if _skitters_done() or not _alarm_ready() or _busy.get("alarm", false):
		return
	_busy["alarm"] = true
	its["alarm"].prompt_text = ""
	player.controls_enabled = false
	# Marcus points at the sedan up the road
	var ma = world.animators.get("Marcus")
	if ma:
		ma.face_towards(ALARM_POS)
		ma.talk(5.0)
	Dialogue.say("c7_throw", false, true)
	await get_tree().create_timer(0.6).timeout
	var cam_yaw0: float = player.rotation.y
	var d: Vector3 = ALARM_POS - player.global_position
	d.y = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): player.set_yaw_pitch(lerp_angle(cam_yaw0, atan2(-d.x, -d.z), k), lerpf(player.head.rotation.x, -0.08, k)), 0.0, 1.0, 0.8)
	await tw.finished
	while Dialogue.is_busy():
		await get_tree().process_frame
	await _throw_bottle()                            # picked up, wound up, thrown: glass on the car, then the alarm (review notes #97, #116)
	player.controls_enabled = true
	var a := AudioStreamPlayer3D.new()
	a.stream = _alarm_stream
	a.unit_size = 30.0
	a.volume_db = 2.0
	world.add_child(a)
	a.global_position = ALARM_POS + Vector3(0, 1.2, 0)
	a.play()
	get_tree().create_timer(8.0).timeout.connect(a.queue_free)
	_blink_alarm_lights(8.0)                         # the car flashes its lights like any alarm
	_busy["fleeing"] = true                           # (QA-008) the car is clear only once they have gone to the noise
	if hud.has_method("set_hint"):
		hud.set_hint("")
	_refresh_prompts()
	# they scuttle toward the noise (past it, away from the player's side of the road), then off into the fog
	for i in skitters.size():
		var sk: Node3D = skitters[i]
		if not is_instance_valid(sk):
			continue
		_patrol.erase(sk)
		VeilCreatureLook.skitter_anim(sk, "scuttle", 7.0)
		var mid := ALARM_POS + Vector3(-2.0 + i * 1.5, 0.0, 1.0)
		var out: Vector3 = SKITTER_EXIT[i % SKITTER_EXIT.size()]
		var tw2 := sk.create_tween()
		sk.rotation.y = atan2(mid.x - sk.global_position.x, mid.z - sk.global_position.z)
		tw2.tween_property(sk, "global_position", mid, sk.global_position.distance_to(mid) / 7.0)
		tw2.tween_callback(func():
			_drawn_off()
			if is_instance_valid(sk):
				sk.rotation.y = atan2(out.x - mid.x, out.z - mid.z))
		tw2.tween_property(sk, "global_position", out, mid.distance_to(out) / 7.0)
		tw2.tween_callback(_leave_unseen.bind(sk))
	if skitters.is_empty():
		_drawn_off()


## They reached the noise: drawn off for good (saved) - now the backpack.
func _drawn_off() -> void:
	if Game.has_flag("ch7_skitters_gone"):
		return
	Game.set_flag("ch7_skitters_gone")
	_busy["alarm"] = false
	_busy["fleeing"] = false
	if hud.has_method("set_hint"):
		hud.set_hint("")
	_refresh_prompts()
	_guide()


## Removed only once nobody is looking at it (no pop-out in front of the player).
func _leave_unseen(sk: Node3D) -> void:
	for i in 300:
		if not is_instance_valid(sk):
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null or not cam.is_position_in_frustum(sk.global_position + Vector3(0, 0.5, 0)):
			break
		await get_tree().create_timer(0.2).timeout
	if is_instance_valid(sk):
		skitters.erase(sk)
		sk.queue_free()
