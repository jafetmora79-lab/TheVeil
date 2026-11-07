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
const FOLLOW := preload("res://game/npc/companion_follow.gd")
const SCAV := preload("res://game/world/scavenge_house.gd")

const HOUSE := "HOUSE_04"                 # cottage straight behind the supermarket (~40 m)
const SURVIVOR_HOUSE := "HOUSE_05"        # its neighbour
const STATE := "c5"

# supermarket-local
# Staff side of the service counter, outside the front-door walking route.
const EDDIE_SHELTER := Vector3(6.2, 0.04, 4.05)
const MARCUS_SPOT := Vector3(-2.0, 0.04, 6.9)
const STASH := Vector3(6.9, 1.05, 5.0)               # customer-service counter top (was 5.8: behind it, in mid-air)
const BACKPACK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_SmallBackpack.glb")
const EXIT_SPOT := Vector3(0.0, 1.2, 3.6)             # sales side of the vestibule wall (openings at x = +-1.5)
const SURVIVOR_SPOT := Vector3(-5.2, 0.04, 7.1)
const OUTSIDE_Z := -2.0                               # local z below this = outside the front doors
const INSIDE_Z := 3.3                                 # local z above this = in the sales hall
# HOUSE_04-local (Pack 03 cottage: furnishing placement from build_residential.furnish_instances)
const RADIO_POS := Vector3(-1.5, 1.35, 8.55)                                # round dining table (moved clear of the chimney stack at x -1.2, z 9.4)
const HOUSE_RECT := [Vector2(-3.75, 2.4), Vector2(3.75, 11.4)]
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
var radio: VeilRadio
var scav: Node
var radio_runs := 0
var _static: AudioStreamPlayer3D
var _streams := {}
var _doors_open := false
var _door_tweens: Array = []
var _yard: Area3D
var _surv_lamp: OmniLight3D
var _surv_sound: AudioStreamPlayer3D
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
		hud.chapter_start(6)                        # over the wake-up fade (after "SATURDAY")
		world._atmo().set_state(3)                  # morning: the daytime Veil (Pack 09 VEIL_ACTIVE preset)
	else:
		world._atmo().set_state(3, true)
		if Game.has_flag("c5_radio_used") and not Game.has_flag("c5_radio_done"):
			Game.set_flag("c5_radio_done")          # a load mid-broadcast never replays it
	_apply()
	if Game.has_flag("c5_rested"):
		_start_chapter6(true)
	Game.refresh_objective()


## Chapter 6 continues after the night that follows Chapter 5; it is a child of this node.
var chapter6: Node
func _start_chapter6(restoring: bool) -> void:
	if chapter6 != null:
		return
	chapter6 = load("res://game/world/chapter6.gd").new()
	chapter6.name = "Chapter6"
	add_child(chapter6)
	chapter6.begin(world, self, restoring)


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
	# the supplies are one backpack lying on the counter (the inventory screen it opens holds the real items)
	var bag := BACKPACK.instantiate() as Node3D
	bag.name = "C5_Backpack"
	bag.rotation.y = 0.35
	stash.add_child(bag)
	_settle_stash.call_deferred(stash)
	its["stash"] = _spot("C5_CheckSupplies", market, STASH + Vector3(0, 0.08, 0), Vector3(1.2, 0.45, 0.6), "", _check_supplies)
	# leaving is done at the real front doors (the shut auto-door leaves), not at a box in mid-air: the interaction
	# sits on the leaves' inner face, as wide and tall as the pair
	its["exit"] = _spot("C5_HeadOut", market, _door_spot(), Vector3(2.5, 2.2, 0.3), "", _head_out)


## Market-local centre of the front door pair, just on the inside of the leaves.
func _door_spot() -> Vector3:
	var zs := 0.0
	var n := 0
	for d in world._auto_doors:
		zs += market.to_local((d[0] as Node3D).global_position).z
		n += 1
	var z := (zs / n if n > 0 else 0.1) + 0.2
	return Vector3(0.0, 1.15, z)


## Rest the stash (backpack, origin at its base) on the collider below it: the counter top.
func _settle_stash(stash: Node3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(stash.global_position + Vector3(0, 0.4, 0),
		stash.global_position - Vector3(0, 0.6, 0), 1, ex))
	if not hit.is_empty():
		stash_gap = stash.global_position.y - (hit["position"] as Vector3).y
		stash.global_position.y = (hit["position"] as Vector3).y + 0.002


var stash_gap := INF                                  ## tests: how far the stash was off the counter top


func _setup_house() -> void:
	# the cottage is an explorable house (game/data/scavenge_houses.json): real furniture, loot inside containers
	var specs: Dictionary = SCAV.load_specs()
	scav = SCAV.new()
	add_child(scav)
	scav.setup(world, house, specs.get("houses", {}).get(HOUSE, {}), specs)
	for n in scav.doors:
		its["c5/%s/%s" % [HOUSE, n]] = scav.doors[n]
	for id in scav.loot:
		its["item_" + id] = scav.loot[id]
		scav.loot[id].used.connect(_on_pickup.bind(id))
	# the survivor's house is NOT explorable: its front door only opens for the conversation, and the doorway is
	# blocked (two-storey variant with a basement stair that would trap the player)
	var fd := shouse.find_child("INT_Door_Front", true, false) as Node3D
	if fd:
		var deg := 95.0
		var into: Variant = _door_room_center(shouse, "INT_Door_Front")
		if into != null:
			deg = world._toward_deg(fd, deg, shouse.global_transform * (into as Vector3))
		var dit := Interactable.attach(fd, {"kind": "hinge", "label": "Front Door", "open_deg": deg, "hinge_axis": Vector3.UP,
			"state_key": "c5/%s/INT_Door_Front" % SURVIVOR_HOUSE})
		its["c5/%s/INT_Door_Front" % SURVIVOR_HOUSE] = dit
		# a normal front door (the player can open it and walk in). The flight up works (ground 0.6 -> upper 3.6,
		# walked both ways); only the basement flight beneath it, which drops from the foyer at z ~9.2 to a dead end,
		# is closed at its head - low enough to pass under the upper flight there.
		var block := StaticBody3D.new()
		block.name = "C5_SurvivorBasement"
		block.collision_layer = 1
		var bcs := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(1.05, 1.6, 0.6)
		bcs.shape = bb
		block.add_child(bcs)
		shouse.add_child(block)
		block.position = Vector3(0.645, 0.6 + 0.8, 9.2)
		# every interior door opens (E), as in the explorable houses: the kitchen, den, dining room and the bedrooms
		# and bathroom upstairs were behind doors that never opened
		var dh = SCAV.new()
		dh.name = "C5_SurvivorDoors"
		dh.world = world
		dh.house = shouse
		add_child(dh)
		dh._open_house_doors()
		for n in dh.doors:
			its["c5/%s/%s" % [SURVIVOR_HOUSE, n]] = dh.doors[n]
	# the radio: a reusable prop (game/props/veil_radio.gd), interacted with in place on the dining table
	var vr := VeilRadio.new()
	vr.name = "C5_Radio"
	house.add_child(vr)
	vr.position = RADIO_POS
	vr.rotation.y = PI * 0.15
	vr.setup(_streams["static_loop"])
	vr.used.connect(_use_radio)
	radio = vr
	its["radio"] = vr.interactable
	_static = vr.hiss
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
	# the whole front yard, from the fence-row gap (house-local z -6) to the porch
	var yard: Area3D = world._area("C5_SurvivorYard", shouse.global_transform * Vector3(-0.4, 1.5, -1.6), Vector3(9.0, 3.0, 9.6), 2,
		func(b): if b == player: _survivor_encounter(), shouse.global_transform.basis)
	_yard = yard
	# someone is inside: a lamp behind the front windows and muffled movement, audible from the street
	_surv_lamp = OmniLight3D.new()
	_surv_lamp.name = "C5_SurvivorLamp"
	_surv_lamp.light_color = Color(1.0, 0.72, 0.42)
	_surv_lamp.light_energy = 0.0
	_surv_lamp.omni_range = 5.0
	_surv_lamp.shadow_enabled = false
	shouse.add_child(_surv_lamp)
	_surv_lamp.position = SURVIVOR_POS + Vector3(0.3, 1.6, 0.6)
	_surv_sound = AudioStreamPlayer3D.new()
	_surv_sound.name = "C5_SurvivorSounds"
	_surv_sound.stream = _streams["movement"]
	_surv_sound.volume_db = -4.0
	_surv_sound.unit_size = 6.0
	_surv_sound.max_distance = 34.0
	shouse.add_child(_surv_sound)
	_surv_sound.position = SURVIVOR_POS + Vector3(0, 1.0, 0)


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
			world.place_survivor(eddie, EDDIE_SHELTER)
			world.animators["Eddie"].face_towards(ml(STASH))
	if marcus:
		_reparent(marcus, market)
		world.place_survivor(marcus, MARCUS_SPOT)
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
			world.place_survivor(survivor, SURVIVOR_SPOT)
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
	if done and p4.rest:
		p4.rest.get_parent().visible = true
		p4.rest.interactable.prompt_text = "[E] Sleep"


func _refresh_prompts() -> void:
	var talked := Game.has_flag("c5_talked_both")
	var k := Interactable.key_hint()
	if its.has("npc_Eddie"):
		its["npc_Eddie"].prompt_text = "" if Game.has_flag("c5_eddie_talked") else k + "TALK TO EDDIE"
	if its.has("npc_Marcus"):
		var report := Game.has_flag("c5_returned") and not Game.has_flag("c5_reported")
		its["npc_Marcus"].prompt_text = k + "TALK TO MARCUS" if (not Game.has_flag("c5_marcus_talked") or report) else ""
	its["stash"].prompt_text = k + "CHECK THE SUPPLIES" if talked and not Game.has_flag("c5_supplies_checked") else ""
	# the front doors: open once the supplies are checked; before that a short contextual note (no dialogue)
	if Game.has_flag("c5_prepared"):
		its["exit"].prompt_text = ""
	elif Game.has_flag("c5_supplies_checked"):
		its["exit"].prompt_text = k + "OPEN DOOR"
	else:
		its["exit"].prompt_text = "NOT YET - TALK TO EDDIE AND MARCUS FIRST" if not talked else "NOT YET - CHECK THE SUPPLIES FIRST"
	its["radio"].prompt_text = k + "INVESTIGATE RADIO" if Game.has_flag("c5_supplies_done") and not Game.has_flag("c5_radio_used") else ""
	_update_marker()


## The one active destination for the HUD marker (only the current objective's target; cleared when done).
func _update_marker() -> void:
	if Game.has_flag("ch6_started"):
		return                                    # Chapter 6 owns the marker from here on
	var t: Variant = null
	var label := ""
	if Game.has_flag("c5_complete"):
		t = null
	elif not Game.has_flag("c5_eddie_talked") and st().get("eddie", "") != "following":
		t = eddie
		label = "EDDIE"
	elif not Game.has_flag("c5_marcus_talked"):
		t = marcus
		label = "MARCUS"
	elif not Game.has_flag("c5_supplies_checked"):
		t = ml(STASH + Vector3(0, 0.3, 0))
		label = "SUPPLIES"
	elif not Game.has_flag("c5_prepared"):
		t = ml(_door_spot())
		label = "EXIT"
	elif not Game.has_flag("c5_left_store"):
		t = ml(Vector3(0, 1.4, -2.5))
		label = "EXIT"
	elif not Game.has_flag("c5_house_reached"):
		t = hl(Vector3(-1.6, 1.6, 3.0))
		label = "HOUSE"
	elif not Game.has_flag("c5_supplies_done"):
		t = _next_container()
		label = "SEARCH"
	elif not Game.has_flag("c5_radio_used"):
		t = radio
		label = "RADIO"
	elif not Game.has_flag("c5_returned"):
		t = ml(Vector3(0, 1.4, -1.5)) if not _in_store(market.to_local(player.global_position)) else ml(Vector3(0, 1.4, 5.0))
		label = "SUPERMARKET"
	elif not Game.has_flag("c5_reported"):
		t = marcus
		label = "MARCUS"
	hud.set_marker(t, label)
	marker_target = t


var marker_target: Variant = null      ## tests


## The nearest container that still holds loot (the drawer / cabinet itself, not the hidden item).
func _next_container() -> Variant:
	var best: Variant = null
	var bd := INF
	for id in scav.loot:
		var it: Interactable = scav.loot[id]
		if it.taken:
			continue
		var c: Interactable = scav._loot_container[id]
		var p := c.focus_point()
		var d := p.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	return best


func _reparent(n: Node3D, to: Node) -> void:
	if n.get_parent() != to:
		n.reparent(to, true)


# ------------------------------------------------------------------ scene 1: morning
func _talk_eddie(_b: Node) -> void:
	if Game.has_flag("c5_eddie_talked") or _busy.get("talk", false) or st().get("eddie", "") == "following":
		return
	_busy["talk"] = true
	its["npc_Eddie"].prompt_text = ""
	await _talk("c5_eddie_morning", eddie)
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
	await _talk("c5_marcus_morning", marcus)
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
	world.npc_walk("Eddie", Vector3(1.5, 0.04, 4.3), 1.5)       # by the right-hand opening of the vestibule wall
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


func _on_pickup(_by: Node, kind: String) -> void:
	await get_tree().process_frame                 # the pickup's story flag is set right after `used`
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
	await (radio as VeilRadio).play_broadcast("c5_radio_broadcast")
	await get_tree().create_timer(1.2).timeout      # the transmission stops: silence
	await _talk("c5_radio_eddie", eddie)
	Game.set_flag("c5_radio_done")
	world._beacon("c5", ml(Vector3(0, 3.0, -1.5)), Color(0.8, 0.9, 1.0))
	_refresh_prompts()


func _on_line(speaker: String, text: String, _d: float) -> void:
	if speaker == "Radio" and radio and is_instance_valid(radio):
		_play("static_burst" if text == "[STATIC]" else "radio_voice", radio.global_position, -6.0 if text == "[STATIC]" else -14.0)


# ------------------------------------------------------------------ scene 6: optional survivor
## While the survivor can still be found: lamp on, movement sounds. Also re-checks the yard, so standing in it
## after the house was reached (or after a load) starts the encounter.
func _survivor_cues() -> void:
	var findable := Game.has_flag("c5_house_reached") and not Game.has_flag("c5_returned") and not _survivor_met()
	_surv_lamp.light_energy = 0.9 if findable or (_survivor_met() and not Game.has_flag("c5_survivor_helped")) else 0.0
	if findable and not _surv_sound.playing:
		_surv_sound.play()
	elif not findable and _surv_sound.playing:
		_surv_sound.stop()
	if findable and _yard.overlaps_body(player):
		_survivor_encounter()


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
	_talk_start("c5_survivor", survivor)


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
		# The porch railing opens at the west steps. Join through the door and stairs in order.
		survivor_follow.start([
			shouse.to_global(Vector3(-0.3, 0.6, 4.0)),
			shouse.to_global(Vector3(-0.3, 0.58, 2.8)),
			shouse.to_global(Vector3(-3.0, 0.58, 2.8)),
			shouse.to_global(Vector3(-3.0, 0.58, 2.1)),
			shouse.to_global(Vector3(-3.0, 0.0, 0.8)),
		])
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
	_survivor_cues()
	if not Game.has_flag("c5_prepared"):
		return
	var pl := market.to_local(player.global_position)
	var el := market.to_local(eddie.global_position)
	var following := String(st().get("eddie", "")) == "following"
	# the front doors (unpowered since Chapter 3) are pulled open while someone is at them, shut when all are clear
	var near := _near_doors(pl) or _near_doors(el)
	if survivor.visible:
		near = near or _near_doors(market.to_local(survivor.global_position))
	if Game.has_flag("ch6_started") or (world.expedition != null and world.expedition.active()):
		pass                                      # Chapter 6 runs the doors from here on (a supply run: the trip does)
	elif Game.has_flag("c5_returned"):
		if _doors_open and not near:
			_set_doors(false)                         # home: pulled shut once everyone is clear of them
	elif near != _doors_open and (_near_doors(pl) or not near):
		_set_doors(near)
	if following and not Game.has_flag("c5_left_store") and _away_from_store(pl, 2.0):
		Game.set_flag("c5_left_store")
	_update_marker()
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
	return absf(l.x) < 4.0 and l.z > -5.0 and l.z < INSIDE_Z          # outside the doors or in the vestibule


func _in_house(p: Vector3) -> bool:
	var l := house.to_local(p)
	var r: Array = HOUSE_RECT
	return l.x > r[0].x and l.x < r[1].x and l.z > r[0].y and l.z < r[1].y and l.y < 3.5


func _returned() -> void:
	world._clear_beacon("c5")
	eddie_follow.stop()
	_reparent(eddie, market)
	st()["eddie"] = "shelter"
	world.npc_walk("Eddie", EDDIE_SHELTER, 1.3)
	if String(st().get("survivor", "")) == "following":
		survivor_follow.stop()
		_reparent(survivor, market)
		st()["survivor"] = "shelter"
		world.npc_walk("Survivor", SURVIVOR_SPOT, 1.2)
	Game.set_flag("c5_returned")                 # saves with everyone back in the shelter
	_refresh_prompts()


func _report() -> void:
	if Game.has_flag("c5_reported") or _busy.get("report", false):
		return
	_busy["report"] = true
	its["npc_Marcus"].prompt_text = ""
	await _talk("c5_report", marcus)
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
	await hud.chapter_complete(6)


func _on_rest(_id: String) -> void:
	# the next morning is Chapter 6 (game/world/chapter6.gd); started while the screen is still black
	var report: Dictionary = p4.record_night("c5_rested")
	Game.set_flag("c5_rested")
	_start_chapter6(false)
	if p4.flashlight:
		p4.flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	p4.show_night_report(report)
	p4.rest.interactable.prompt_text = "[E] Sleep"


# ------------------------------------------------------------------ helpers
func _set_doors(open: bool) -> void:
	if open == _doors_open:
		return
	_doors_open = open
	for tw in _door_tweens:
		if tw and tw.is_valid():
			tw.kill()                                 # never two tweens fighting over a door leaf
	_door_tweens.clear()
	for d in world._auto_doors:
		var leaf: Node3D = d[0]
		var t: Transform3D = d[1]
		if open:
			t = Transform3D(t.basis, t.origin + t.basis * d[2])
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(leaf, "transform", t, 0.8)
		_door_tweens.append(tw)
	Sfx.play("door_open" if open else "door_close", ml(Vector3(0, 1.2, 0.2)), -4.0, 0.7)


## A stationary NPC conversation: through the world's talk camera (zoom on the speaker, player held); falls
## back to plain timed lines when no talk camera is possible (in the car, an encounter, NPC not in view).
func _talk(id: String, npc: Node3D) -> void:
	var ok := false
	if npc and world.has_method("converse"):
		ok = await world.converse([id], [npc])
	var held := false
	if not ok:
		held = world.player.controls_enabled
		world.player.controls_enabled = false
		world.player.velocity = Vector3.ZERO
		Dialogue.say(id, false, true)
	await get_tree().process_frame
	while Dialogue.is_busy() or (world.get("conversing") == true):
		await get_tree().process_frame
	if held:
		world.player.controls_enabled = true


## Start a conversation that may lead into a choice (not awaited): talk camera when the NPC can be framed,
## otherwise the same lines as plain subtitles (a doorway can hide them from the camera).
func _talk_start(id: String, npc: Node3D) -> void:
	var ok := false
	if npc and world.has_method("converse") and world.get("conversing") != true:
		ok = await world.converse([id], [npc])
	if not ok:
		Dialogue.say(id, false, true)


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
	_streams["movement"] = Sfx._make(7.0, _movement_wave, true)


func _static_wave(t: float, i: int) -> float:
	return Sfx._noise(i) * 0.32 * (0.75 + 0.25 * sin(t * 5.0 + sin(t * 1.3) * 2.0))


func _burst_wave(t: float, i: int) -> float:
	return Sfx._noise(i) * 0.7 * (1.0 - t / 1.1) * (0.6 + 0.4 * sin(t * 90.0))


## muffled movement behind walls: a few soft thumps and a dragged-object scrape inside a 7 s loop
func _movement_wave(t: float, i: int) -> float:
	var out := 0.0
	for k in [0.6, 1.05, 3.9, 5.2]:
		var dt: float = t - k
		if dt >= 0.0 and dt < 0.5:
			out += sin(TAU * 62.0 * dt) * exp(-dt * 14.0) * 0.8 + Sfx._noise(i) * exp(-dt * 30.0) * 0.25
	var sc := t - 2.3
	if sc > 0.0 and sc < 1.1:
		out += Sfx._noise(i) * 0.16 * sin(PI * sc / 1.1) * (0.6 + 0.4 * sin(sc * 47.0))
	return out


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
