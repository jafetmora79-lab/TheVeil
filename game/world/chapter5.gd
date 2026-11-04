extends Node
class_name VeilChapter5
## THE VEIL - Chapter 5 "The First Search" (Act II). Starts after Chapter 4's sleep (flag p4_slept); created by
## phase4.gd (no extra hook in world.gd). All state lives in story flags + Game.world_state["c5"], so a load
## rebuilds the chapter without replaying finished events.
##
## Morning in the supermarket (talk to Eddie + Marcus) -> check the supplies, confirm at the doors -> Eddie
## follows (VeilCompanionFollow) round the store to the cottage behind it (HOUSE_04) -> search kitchen /
## nightstand / bathroom cabinet (real pickups) -> the radio -> optional survivor next door (HOUSE_05, three
## choices) -> back inside -> report to Marcus -> "CHAPTER 5 COMPLETE". Chapter 6 is not started.
## Dialogue is the approved Chapter 5 script (game/data/dialogue.json, ids c5_*).

const CAN := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_CannedFood.glb")
const WATER := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_WaterBottle.glb")
const BATTERY_PACK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_SpareBatteries.glb")
const MEDKIT := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Medical/INV_FirstAidKit.glb")
const RADIO := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Radio.glb")
const FOLLOW := preload("res://game/npc/companion_follow.gd")

const HOUSE := "HOUSE_04"                 # cottage straight behind the supermarket (~40 m)
const SURVIVOR_HOUSE := "HOUSE_05"        # its neighbour
const STATE := "c5"

# supermarket-local
const EDDIE_SHELTER := Vector3(6.2, 0.04, 4.9)        # customer side of the service counter (the supply stash)
const MARCUS_SPOT := Vector3(1.1, 0.04, 4.7)          # by the checkout counters
const STASH := Vector3(6.0, 1.09, 5.8)               # customer-service counter top
const EXIT_SPOT := Vector3(0.0, 1.2, 3.6)             # sales side of the vestibule wall (openings at x = +-1.5)
const SURVIVOR_SPOT := Vector3(-1.0, 0.04, 4.3)
const OUTSIDE_Z := -2.0                               # local z below this = outside the front doors
const INSIDE_Z := 3.3                                 # local z above this = in the sales hall
# HOUSE_04-local (Pack 03 cottage: furnishing placement from build_residential.furnish_instances)
const KITCHEN_SPOT := [Vector3(-1.8, 1.0, 10.55), Vector3(1.3, 0.9, 0.45)]   # sink counter cabinets (back wall)
const KITCHEN_ITEM := Vector3(-2.15, 1.52, 10.95)
const NIGHTSTAND_SPOT := [Vector3(3.3, 0.9, 2.9), Vector3(0.55, 0.6, 0.6)]   # bedroom nightstand
const NIGHTSTAND_ITEM := Vector3(3.43, 1.18, 2.95)
const BATH_SPOT := [Vector3(0.4, 2.0, 7.12), Vector3(0.6, 0.6, 0.3)]        # wall cabinet above the pedestal sink
const BATH_ITEM := Vector3(0.4, 1.46, 7.32)
const RADIO_POS := Vector3(-1.55, 1.35, 9.3)                                 # round dining table
const HOUSE_RECT := [Vector2(-3.75, 2.4), Vector2(3.75, 11.4)]
const SEARCH := {"food": ["search_kitchen", "[E] Search the Kitchen Cabinets"], "batteries": ["search_nightstand", "[E] Search the Nightstand"],
	"medical": ["search_bath", "[E] Search the Bathroom Cabinet"]}
# HOUSE_05-local
const SURVIVOR_POS := Vector3(-0.3, 0.6, 4.7)                                # foyer, behind the front door

var world: Node
var p4: Node
var market: Node3D
var player: Node3D
var hud: Node
var house: Node3D
var shouse: Node3D
var eddie: Node3D
var marcus: Node3D
var survivor: Node3D
var eddie_follow: VeilCompanionFollow
var survivor_follow: VeilCompanionFollow
var its := {}
var radio: Node3D
var radio_runs := 0
var _static: AudioStreamPlayer3D
var _streams := {}
var _doors_open := false
var _busy := {}
var _tick := 0.0


func begin(w: Node, phase4: Node, restoring: bool) -> void:
	world = w
	p4 = phase4
	market = w.market
	player = w.player
	hud = w.hud
	house = w.get_node("Residential/Houses/" + HOUSE)
	shouse = w.get_node("Residential/Houses/" + SURVIVOR_HOUSE)
	eddie = w.eddie
	marcus = w.marcus
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"eddie": "shelter", "survivor": "house"}
	_make_sounds()
	_setup_npcs()
	_setup_market()
	_setup_house()
	_setup_survivor()
	_setup_rest()
	Dialogue.choices_offered.connect(_on_choices)
	Dialogue.line_started.connect(_on_line)
	if not Game.has_flag("c5_started"):
		Game.set_flag("c5_started")
		world._atmo().set_state(3)                  # morning: the daytime Veil (Pack 09 VEIL_ACTIVE preset)
	else:
		world._atmo().set_state(3, true)
		if Game.has_flag("c5_radio_used") and not Game.has_flag("c5_radio_done"):
			Game.set_flag("c5_radio_done")          # a load mid-broadcast never replays it
	_apply()
	Game.refresh_objective()


func ml(p: Vector3) -> Vector3:
	return market.global_transform * p


func hl(p: Vector3) -> Vector3:
	return house.global_transform * p


func st() -> Dictionary:
	return Game.world_state[STATE]


# ------------------------------------------------------------------ setup
func _setup_npcs() -> void:
	for pair in [["npc_Eddie", _talk_eddie], ["npc_Marcus", _talk_marcus]]:
		var it: Interactable = p4.its.get(pair[0])
		if it:
			it.used.connect(pair[1])
			its[pair[0]] = it
	eddie_follow = FOLLOW.new()
	eddie_follow.name = "Follow"
	eddie.add_child(eddie_follow)
	eddie_follow.setup(eddie, player)


func _spot(n: String, parent: Node3D, pos: Vector3, size: Vector3, prompt: String, cb: Callable) -> Interactable:
	var holder := Node3D.new()
	holder.name = n
	parent.add_child(holder)
	holder.position = pos
	var it := Interactable.new()
	it.name = "Interact"
	it.kind = "custom"
	it.label = n
	it.prompt_text = prompt
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	it.add_child(cs)
	holder.add_child(it)
	it.used.connect(cb)
	return it


func _setup_market() -> void:
	var stash := Node3D.new()
	stash.name = "C5_Stash"
	market.add_child(stash)
	stash.position = STASH
	for m in [[CAN, Vector3(-0.35, 0, 0.05)], [WATER, Vector3(0.0, 0, -0.05)], [BATTERY_PACK, Vector3(0.35, 0, 0.0)]]:
		var n := (m[0] as PackedScene).instantiate() as Node3D
		n.position = m[1]
		stash.add_child(n)
	its["stash"] = _spot("C5_CheckSupplies", market, STASH + Vector3(0, 0.08, 0), Vector3(1.2, 0.45, 0.6), "", _check_supplies)
	its["exit"] = _spot("C5_HeadOut", market, EXIT_SPOT, Vector3(3.2, 2.2, 0.5), "", _head_out)


func _setup_house() -> void:
	for h in [house, shouse]:
		for e in h.get_meta("veil_interactables", []):
			var n := String(e.get("node", ""))
			if e.get("veil_interact", "") != "hinge" or not n.begins_with("INT_Door_"):
				continue
			if h == shouse and n != "INT_Door_Front":
				continue
			var d := h.find_child(n, true, false) as Node3D
			if d == null or d.get_node_or_null("Interact"):
				continue
			var key := "c5/%s/%s" % [h.name, n]
			var deg := float(e.get("open_deg", 90.0))
			var into: Variant = _door_room_center(h, n)      # swing into the smaller room (bath, bedroom, hall) / inward at the front
			if into != null:
				deg = world._toward_deg(d, deg, h.global_transform * (into as Vector3))
			var it := Interactable.attach(d, {"kind": "hinge", "label": world._label_for(n), "open_deg": deg,
				"hinge_axis": Vector3.UP, "state_key": key})
			its[key] = it
	its["search_kitchen"] = _spot("C5_SearchKitchen", house, KITCHEN_SPOT[0], KITCHEN_SPOT[1], "", func(_b): _search("food"))
	its["search_nightstand"] = _spot("C5_SearchNightstand", house, NIGHTSTAND_SPOT[0], NIGHTSTAND_SPOT[1], "", func(_b): _search("batteries"))
	its["search_bath"] = _spot("C5_SearchBathroom", house, BATH_SPOT[0], BATH_SPOT[1], "", func(_b): _search("medical"))
	for spec in [["food", CAN, KITCHEN_ITEM, "canned_food", "Canned Food", "c5_got_food"],
			["batteries", BATTERY_PACK, NIGHTSTAND_ITEM, "batteries", "Batteries", "c5_got_batteries"],
			["medical", MEDKIT, BATH_ITEM, "first_aid_kit", "First Aid Kit", "c5_got_medical"]]:
		var item := (spec[1] as PackedScene).instantiate() as Node3D
		item.name = "C5_Item_" + spec[0]
		house.add_child(item)
		item.position = spec[2]
		item.visible = false
		var it := Interactable.attach(item, {"kind": "pickup", "label": spec[4], "item_id": spec[3], "story_flag": spec[5],
			"state_key": "c5/item_" + spec[0]})
		it.used.connect(_on_pickup.bind(spec[0]))
		its["item_" + spec[0]] = it
	radio = RADIO.instantiate() as Node3D
	radio.name = "C5_Radio"
	house.add_child(radio)
	radio.position = RADIO_POS
	radio.rotation.y = PI * 0.15
	var rit := Interactable.attach(radio, {"kind": "custom", "label": "Radio", "prompt_text": ""})
	rit.used.connect(_use_radio)
	its["radio"] = rit
	_static = AudioStreamPlayer3D.new()
	_static.name = "Static"
	_static.stream = _streams["static_loop"]
	_static.volume_db = -16.0
	_static.unit_size = 3.0
	_static.max_distance = 22.0
	radio.add_child(_static)
	var rect: Array = HOUSE_RECT
	var c := Vector3((rect[0].x + rect[1].x) * 0.5, 1.8, (rect[0].y + rect[1].y) * 0.5)
	world._area("C5_HouseInside", hl(c), Vector3(rect[1].x - rect[0].x, 2.4, rect[1].y - rect[0].y), 2,
		func(b): if b == player: _entered_house(), house.global_transform.basis)


## Pack 03 house metadata: centre (house-local) of the room a door should open into, or null.
func _door_room_center(h: Node3D, door: String):
	var info: Dictionary = h.get_meta("veil_house", {})
	var rooms := {}
	for r in info.get("rooms", []):
		var rc: Array = r["rect"]
		rooms[r["id"]] = Vector3((rc[0] + rc[2]) * 0.5, float(r.get("floor_y", 0.6)) + 1.0, (rc[1] + rc[3]) * 0.5)
	for dd in info.get("doors", []):
		if dd.get("name", "") != door:
			continue
		var pair: Array = dd.get("rooms", [])
		var want := String(pair[1]) if pair.size() > 1 and pair[0] == "OUT" else String(pair[0]) if pair.size() > 0 else ""
		return rooms.get(want)
	return null


func _setup_survivor() -> void:
	survivor = world._spawn_npc(world.CASHIER, world.CASHIER_FACE, shouse, SURVIVOR_POS, 0.0, "Survivor")
	survivor.visible = false
	survivor_follow = FOLLOW.new()
	survivor_follow.name = "Follow"
	survivor_follow.gap = 4.2
	survivor.add_child(survivor_follow)
	survivor_follow.setup(survivor, player)
	world._area("C5_SurvivorYard", shouse.global_transform * Vector3(-0.4, 1.5, 1.4), Vector3(6.0, 3.0, 3.6), 2,
		func(b): if b == player: _survivor_encounter(), shouse.global_transform.basis)


func _setup_rest() -> void:
	var r: VeilRestPoint = p4.rest
	if r == null:
		return
	if r.slept.is_connected(p4._on_slept):
		r.slept.disconnect(p4._on_slept)
	r.can_rest = func() -> bool: return Game.has_flag("c5_complete")
	r.slept.connect(_on_rest)


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	var s := st()
	var done := Game.has_flag("c5_complete")
	# Eddie
	match String(s.get("eddie", "shelter")):
		"following":
			_reparent(eddie, world)
			eddie_follow.recover_behind(2.4)               # a load: screen is black, he is put behind the player
			eddie_follow.start()
		_:
			_reparent(eddie, market)
			eddie.position = EDDIE_SHELTER
			world.animators["Eddie"].face_towards(ml(STASH))
	if marcus:
		_reparent(marcus, market)
		marcus.position = MARCUS_SPOT
		world.animators["Marcus"].face_towards(ml(Vector3(-4.1, 1.1, 4.0)))
	# survivor
	match String(s.get("survivor", "house")):
		"following":
			_reparent(survivor, world)
			survivor.visible = true
			survivor_follow.recover_behind(4.0)
			survivor_follow.start()
		"shelter":
			_reparent(survivor, market)
			survivor.position = SURVIVOR_SPOT
			survivor.visible = true
		_:
			survivor.visible = _survivor_met() and not Game.has_flag("c5_survivor_helped")
	_refresh_prompts()
	if Game.has_flag("c5_prepared") and not Game.has_flag("c5_house_reached"):
		world._beacon("c5", hl(Vector3(-1.6, 2.8, 3.0)), Color(0.8, 0.9, 1.0))
	if Game.has_flag("c5_radio_done") and not Game.has_flag("c5_returned"):
		world._beacon("c5", ml(Vector3(0, 3.0, -1.5)), Color(0.8, 0.9, 1.0))
	if not Game.has_flag("c5_radio_used"):
		_static.play()
	for k in ["food", "batteries", "medical"]:
		var it: Interactable = its["item_" + k]
		it.target.visible = bool(s.get("found_" + k, false)) and not it.taken
	if done and p4.rest:
		p4.rest.get_parent().visible = true
		p4.rest.interactable.prompt_text = "[E] Sleep"


func _refresh_prompts() -> void:
	var talked := Game.has_flag("c5_talked_both")
	if its.has("npc_Eddie"):
		its["npc_Eddie"].prompt_text = "" if Game.has_flag("c5_eddie_talked") else "[E] Talk"
	if its.has("npc_Marcus"):
		var report := Game.has_flag("c5_returned") and not Game.has_flag("c5_reported")
		its["npc_Marcus"].prompt_text = "[E] Talk" if (not Game.has_flag("c5_marcus_talked") or report) else ""
	its["stash"].prompt_text = "[E] Check the Supplies" if talked and not Game.has_flag("c5_supplies_checked") else ""
	its["exit"].prompt_text = "[E] Head Out with Eddie" if Game.has_flag("c5_supplies_checked") and not Game.has_flag("c5_prepared") else ""
	var s := st()
	for k in SEARCH:
		its[SEARCH[k][0]].prompt_text = "" if s.get("found_" + k, false) or not Game.has_flag("c5_prepared") else SEARCH[k][1]
		var item: Interactable = its["item_" + k]
		item.collision_layer = 8 if s.get("found_" + k, false) and not item.taken else 0     # no prompt for a hidden item
	its["radio"].prompt_text = "[E] Use the Radio" if Game.has_flag("c5_supplies_done") and not Game.has_flag("c5_radio_used") else ""


func _reparent(n: Node3D, to: Node) -> void:
	if n.get_parent() != to:
		n.reparent(to, true)


# ------------------------------------------------------------------ scene 1: morning
func _talk_eddie(_b: Node) -> void:
	if Game.has_flag("c5_eddie_talked") or _busy.get("talk", false) or st().get("eddie", "") == "following":
		return
	_busy["talk"] = true
	its["npc_Eddie"].prompt_text = ""
	await _say_wait("c5_eddie_morning")
	Game.set_flag("c5_eddie_talked")
	_busy["talk"] = false
	_after_talk()


func _talk_marcus(_b: Node) -> void:
	if _busy.get("talk", false):
		return
	if Game.has_flag("c5_returned") and not Game.has_flag("c5_reported"):
		_report()
		return
	if Game.has_flag("c5_marcus_talked"):
		return
	_busy["talk"] = true
	its["npc_Marcus"].prompt_text = ""
	await _say_wait("c5_marcus_morning")
	Game.set_flag("c5_marcus_talked")
	_busy["talk"] = false
	_after_talk()


func _after_talk() -> void:
	if Game.has_flag("c5_eddie_talked") and Game.has_flag("c5_marcus_talked"):
		Game.set_flag("c5_talked_both")
	_refresh_prompts()


# ------------------------------------------------------------------ scene 2: prepare (closest existing storage UI: the inventory panel)
func _check_supplies(_b: Node) -> void:
	if not Game.has_flag("c5_talked_both") or Game.has_flag("c5_supplies_checked"):
		return
	if not hud.inv_panel.visible:
		hud.toggle_inventory()
	Sfx.play("pickup", ml(STASH), -12.0, 0.7)
	Game.set_flag("c5_supplies_checked")
	_refresh_prompts()


func _head_out(_b: Node) -> void:
	if not Game.has_flag("c5_supplies_checked") or Game.has_flag("c5_prepared") or _busy.get("out", false):
		return
	_busy["out"] = true
	var i: int = await p4.choice.ask("Head out with Eddie now?", ["Let's go", "Not yet"], player)
	if i != 0:
		_busy["out"] = false
		return
	if hud.inv_panel.visible:
		hud.toggle_inventory()
	its["exit"].prompt_text = ""
	_set_doors(true)                              # pulled open first, so nobody walks into a moving door
	var a: Node = world.animators["Eddie"]
	a.walk_to([Vector3(1.5, 0.04, 4.3)], 1.5)       # by the right-hand opening of the vestibule wall
	Dialogue.say("c5_eddie_exit", false, true)
	await _wait_for(func(): return not a.is_walking(), 8.0)
	while Dialogue.is_busy():
		await get_tree().process_frame
	_set_doors(true)
	st()["eddie"] = "following"
	_reparent(eddie, world)
	eddie_follow.start()
	Game.set_flag("c5_prepared")                 # saves (flags auto-save) with Eddie following
	world._beacon("c5", hl(Vector3(-1.6, 2.8, 3.0)), Color(0.8, 0.9, 1.0))
	_busy["out"] = false
	_refresh_prompts()


# ------------------------------------------------------------------ scenes 3-4: street, house, supplies
func _entered_house() -> void:
	if not Game.has_flag("c5_prepared") or Game.has_flag("c5_house_reached"):
		return
	world._clear_beacon("c5")
	Game.set_flag("c5_house_reached")
	Dialogue.say("c5_house_enter", false, true)
	_refresh_prompts()


func _search(kind: String) -> void:
	if not Game.has_flag("c5_prepared") or st().get("found_" + kind, false):
		return
	st()["found_" + kind] = true
	var it: Interactable = its["item_" + kind]
	it.target.visible = true
	it.target.scale = Vector3.ONE * 0.01
	it.target.create_tween().tween_property(it.target, "scale", Vector3.ONE, 0.25)
	it.collision_layer = 8
	Sfx.play("door_open", it.global_position, -6.0, 1.3)
	_refresh_prompts()


func _on_pickup(_by: Node, kind: String) -> void:
	if kind == "batteries" and p4.flashlight:
		p4.flashlight.add_spares(2)                 # the pack really refills the flashlight's spare count
	if not Game.has_flag("c5_found_said"):
		Game.set_flag("c5_found_said")
		Dialogue.say("c5_found_supplies", false, true)
	if Game.has_flag("c5_got_food") and Game.has_flag("c5_got_batteries") and Game.has_flag("c5_got_medical"):
		Game.set_flag("c5_supplies_done")
	_refresh_prompts()


# ------------------------------------------------------------------ scene 5: the radio (once)
func _use_radio(_b: Node) -> void:
	if not Game.has_flag("c5_supplies_done") or Game.has_flag("c5_radio_used"):
		return
	radio_runs += 1
	Game.set_flag("c5_radio_used")
	its["radio"].prompt_text = ""
	_static.stop()
	await _say_wait("c5_radio_broadcast")
	await get_tree().create_timer(1.2).timeout      # the transmission stops: silence
	await _say_wait("c5_radio_eddie")
	Game.set_flag("c5_radio_done")
	world._beacon("c5", ml(Vector3(0, 3.0, -1.5)), Color(0.8, 0.9, 1.0))
	_refresh_prompts()


func _on_line(speaker: String, text: String, _d: float) -> void:
	if speaker == "Radio" and radio and is_instance_valid(radio):
		_play("static_burst" if text == "[STATIC]" else "radio_voice", radio.global_position, -6.0 if text == "[STATIC]" else -14.0)


# ------------------------------------------------------------------ scene 6: optional survivor
func _survivor_met() -> bool:
	return Game.has_flag("c5_survivor_helped") or Game.has_flag("c5_survivor_informed") or Game.has_flag("c5_survivor_left")


func _survivor_encounter() -> void:
	if not Game.has_flag("c5_house_reached") or Game.has_flag("c5_returned") or _survivor_met() or _busy.get("survivor", false):
		return
	_busy["survivor"] = true                       # runtime only: a load before the choice offers it again
	if Dialogue.is_busy():
		await _wait_for(func(): return not Dialogue.is_busy(), 20.0)
	Sfx.play("door_close", shouse.global_transform * Vector3(-0.3, 1.2, 5.0), -10.0, 0.6)   # someone moves inside
	await get_tree().create_timer(1.2).timeout
	var door: Interactable = its.get("c5/%s/INT_Door_Front" % SURVIVOR_HOUSE)
	survivor.visible = true
	if door and not door.is_open:
		door.set_open(true)
	Dialogue.say("c5_survivor", false, true)


func _on_choices(id: String, choices: Array) -> void:
	if id != "c5_survivor" or _survivor_met():
		return
	var texts: Array = []
	for c in choices:
		texts.append(c["text"])
	var i: int = await p4.choice.ask("", texts, player)
	var c: Dictionary = choices[clampi(i, 0, choices.size() - 1)]
	Game.set_flag(c["flag"])
	await _say_wait(c["next"])
	var door: Interactable = its.get("c5/%s/INT_Door_Front" % SURVIVOR_HOUSE)
	if c["flag"] == "c5_survivor_helped":
		st()["survivor"] = "following"
		_reparent(survivor, world)
		survivor_follow.start()
		Game.set_flag("c5_survivor_following")
	elif door and door.is_open:
		await get_tree().create_timer(1.0).timeout
		door.set_open(false)


# ------------------------------------------------------------------ scenes 7-8: return and report
func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	if not Game.has_flag("c5_prepared"):
		return
	var pl := market.to_local(player.global_position)
	var el := market.to_local(eddie.global_position)
	var following := String(st().get("eddie", "")) == "following"
	# the front doors (unpowered since Chapter 3) are pulled open while someone is at them, shut when all are clear
	var near := _near_doors(pl) or _near_doors(el)
	if survivor.visible:
		near = near or _near_doors(market.to_local(survivor.global_position))
	if Game.has_flag("c5_returned"):
		if _doors_open and not near:
			_set_doors(false)                         # home: pulled shut once everyone is clear of them
	elif near != _doors_open and (_near_doors(pl) or not near):
		_set_doors(near)
	if following and not Game.has_flag("c5_street_said") and _away_from_store(pl, 10.0) and not Dialogue.is_busy():
		Game.set_flag("c5_street_said")
		Dialogue.say("c5_street", false, true)
	if Game.has_flag("c5_radio_done") and not Game.has_flag("c5_return_said") and not _in_house(player.global_position) \
			and player.global_position.distance_to(hl(Vector3(-1.6, 0.6, 3.4))) > 5.0 and not Dialogue.is_busy():
		Game.set_flag("c5_return_said")
		Dialogue.say("c5_return", false, true)
	if Game.has_flag("c5_radio_done") and not Game.has_flag("c5_returned"):
		var surv_following := String(st().get("survivor", "")) == "following"
		var player_in := _in_store(pl)
		# once the player is in the sales hall the companions close up, so nobody stops in the vestibule
		eddie_follow.gap = 1.0 if player_in else 2.4
		survivor_follow.gap = 1.6 if player_in else 4.2
		var surv_ok := not surv_following or _in_store(market.to_local(survivor.global_position), 0.1)
		if player_in and _in_store(el, 0.1) and surv_ok:
			_returned()


## market-local point inside the sales hall / back rooms (past the vestibule wall), with an optional margin
func _in_store(l: Vector3, margin := 0.0) -> bool:
	return l.z > INSIDE_Z + margin and l.z < 17.6 and absf(l.x) < 20.0


## market-local point outside the building footprint (x -20..20, z 0..17.6) by at least `m` metres
func _away_from_store(l: Vector3, m: float) -> bool:
	var dx := maxf(absf(l.x) - 20.0, 0.0)
	var dz := maxf(maxf(-l.z, l.z - 17.6), 0.0)
	return Vector2(dx, dz).length() > m


func _near_doors(l: Vector3) -> bool:
	return absf(l.x) < 4.0 and l.z > -5.0 and l.z < 4.6


func _in_house(p: Vector3) -> bool:
	var l := house.to_local(p)
	var r: Array = HOUSE_RECT
	return l.x > r[0].x and l.x < r[1].x and l.z > r[0].y and l.z < r[1].y and l.y < 3.5


func _returned() -> void:
	world._clear_beacon("c5")
	eddie_follow.stop()
	_reparent(eddie, market)
	st()["eddie"] = "shelter"
	world.animators["Eddie"].walk_to([EDDIE_SHELTER], 1.3)
	if String(st().get("survivor", "")) == "following":
		survivor_follow.stop()
		_reparent(survivor, market)
		st()["survivor"] = "shelter"
		world.animators["Survivor"].walk_to([SURVIVOR_SPOT], 1.2)
	Game.set_flag("c5_returned")                 # saves with everyone back in the shelter
	_refresh_prompts()


func _report() -> void:
	if Game.has_flag("c5_reported") or _busy.get("report", false):
		return
	_busy["report"] = true
	its["npc_Marcus"].prompt_text = ""
	await _say_wait("c5_report")
	if Game.has_flag("c5_survivor_helped"):
		await _say_wait("c5_report_survivor")
	Game.set_flag("c5_reported")
	_busy["report"] = false
	_complete()


func _complete() -> void:
	if Game.has_flag("c5_complete"):
		return
	Game.set_flag("c5_complete")                 # Chapter 6 is NOT started here
	_refresh_prompts()
	if p4.rest:
		p4.rest.get_parent().visible = true
		p4.rest.interactable.prompt_text = "[E] Sleep"
	await hud.title_card("CHAPTER 5 COMPLETE  -  THE FIRST SEARCH", 3.2)


func _on_rest(_id: String) -> void:
	# sleep stays available after the chapter; it only passes time (no day counter or Chapter 6 yet)
	Game.set_flag("c5_rested")
	if p4.flashlight:
		p4.flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	p4.rest.interactable.prompt_text = "[E] Sleep"


# ------------------------------------------------------------------ helpers
func _set_doors(open: bool) -> void:
	if open == _doors_open:
		return
	_doors_open = open
	for d in world._auto_doors:
		var leaf: Node3D = d[0]
		var t: Transform3D = d[1]
		if open:
			t = Transform3D(t.basis, t.origin + t.basis * d[2])
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(leaf, "transform", t, 0.8)
	Sfx.play("door_open" if open else "door_close", ml(Vector3(0, 1.2, 0.2)), -4.0, 0.7)


func _say_wait(id: String) -> void:
	Dialogue.say(id, false, true)
	await get_tree().process_frame
	while Dialogue.is_busy():
		await get_tree().process_frame


func _wait_for(cond: Callable, seconds: float) -> void:
	var t := 0.0
	while not cond.call() and t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _make_sounds() -> void:
	_streams["static_loop"] = Sfx._make(2.0, _static_wave, true)
	_streams["static_burst"] = Sfx._make(1.1, _burst_wave)
	_streams["radio_voice"] = Sfx._make(2.4, _voice_wave)


func _static_wave(t: float, i: int) -> float:
	return Sfx._noise(i) * 0.32 * (0.75 + 0.25 * sin(t * 5.0 + sin(t * 1.3) * 2.0))


func _burst_wave(t: float, i: int) -> float:
	return Sfx._noise(i) * 0.7 * (1.0 - t / 1.1) * (0.6 + 0.4 * sin(t * 90.0))


## a band-limited murmur under the radio subtitles (no recorded voice): two wavering tones + hiss
func _voice_wave(t: float, i: int) -> float:
	var env := clampf(t * 4.0, 0.0, 1.0) * clampf((2.4 - t) * 4.0, 0.0, 1.0) * (0.55 + 0.45 * sin(t * 11.0))
	return (sin(TAU * 180.0 * t) * 0.25 + sin(TAU * 410.0 * t + sin(t * 7.0)) * 0.12) * env + Sfx._noise(i) * 0.08


func _play(id: String, at: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	p.unit_size = 4.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
