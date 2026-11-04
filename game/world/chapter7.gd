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
## "CHAPTER 7 COMPLETE". No combat, no Hound, no Colossus. Chapter 8 is not started.
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
const MARCUS_NOTES := Vector3(5.1, 0.04, 4.9)          # at the service counter, over his notes
const NOTES_ON_COUNTER := Vector3(5.1, 1.09, 5.75)
const EDDIE_NEARBY := Vector3(3.0, 0.04, 4.5)
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
	_setup_rest()
	Dialogue.choices_offered.connect(_on_choices)
	var fresh := not Game.has_flag("ch7_started")
	if fresh:
		Game.set_flag("ch7_started")
	_apply(restoring)
	Game.refresh_objective()
	if fresh:
		_title.call_deferred()


func _title() -> void:
	await get_tree().create_timer(2.6).timeout       # after the wake-up fade
	await hud.title_card("CHAPTER 7  -  A TRACE OF NOAH", 2.6)


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
	bs.size = Vector3(1.1, 0.9, 1.1)
	cs.shape = bs
	it.add_child(cs)
	world.add_child(it)
	it.global_position = seat_pos + outward * 0.75 + Vector3(0, 0.3, 0)
	it.used.connect(_examine_backpack)
	its["backpack"] = it
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
	eddie.position = EDDIE_NEARBY
	world.animators["Eddie"].face_towards(c5.ml(Vector3(2.0, 1.5, 0.0)))
	if String(st().get("marcus", "shelter")) == "following":
		c5._reparent(marcus, world)
		marcus_follow.recover_behind(2.4)
		marcus_follow.start()
	else:
		c5._reparent(marcus, market)
		marcus.position = MARCUS_NOTES
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
	its["backpack"].prompt_text = "E - EXAMINE BACKPACK" if Game.has_flag("ch7_vehicle_reached") and not Game.has_flag("ch7_backpack_found") else ""
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
	elif not Game.has_flag("ch7_vehicle_reached"):
		t = CAR_POS + Vector3(0, 1.8, 0)
		label = "VEHICLE"
		beacon = CAR_POS + Vector3(0, 3.0, 0)
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
	if not Game.has_flag("ch7_vehicle_reached") or Game.has_flag("ch7_backpack_found") or _busy.get("bag", false):
		return
	_busy["bag"] = true
	its["backpack"].prompt_text = ""
	await c5._talk("c7_backpack", marcus)
	# a key item, through the normal inventory (no new interface); the note inside is its own document
	Game.add_item("noahs_backpack")
	Game.add_item("noahs_note")
	Sfx.play("pickup", backpack.global_position, -6.0, 0.9)
	backpack.visible = false
	its["backpack"].collision_layer = 0
	Game.set_flag("ch7_backpack_found")
	if hud.has_method("set_hint"):
		hud.set_hint("TAB  -  INVENTORY: read Noah's note")
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
	_note_tick(delta)
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
	if c5._doors_open and not c5._near_doors(pl) and not (following and c5._near_doors(ml_)):
		c5._set_doors(false)
	if following and not Game.has_flag("ch7_departure_complete") and c5._away_from_store(pl, 3.0):
		Game.set_flag("ch7_departure_complete")
	if following and Game.has_flag("ch7_departure_complete") and not Game.has_flag("ch7_walk_said") \
			and c5._away_from_store(pl, 12.0) and not Dialogue.is_busy():
		Game.set_flag("ch7_walk_said")
		Dialogue.say("c7_walk", false, true)
	if Game.has_flag("ch7_departure_complete") and not Game.has_flag("ch7_vehicle_reached") and _car_area.overlaps_body(player):
		Game.set_flag("ch7_vehicle_reached")
		_refresh_prompts()
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


func _returned() -> void:
	marcus_follow.stop()
	c5._reparent(marcus, market)
	st()["marcus"] = "shelter"
	world.animators["Marcus"].walk_to([MARCUS_NOTES], 1.2)
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
	await hud.title_card("CHAPTER 7 COMPLETE  -  A TRACE OF NOAH", 3.2)


func _on_rest(_id: String) -> void:
	Game.set_flag("ch7_rested")                      # the Chapter 8 checkpoint; nothing starts yet
	if p4.flashlight:
		p4.flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	p4.rest.interactable.prompt_text = "[E] Sleep"
