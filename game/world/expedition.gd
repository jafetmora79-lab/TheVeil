extends Node
class_name VeilExpedition
## THE VEIL - the shared expedition controller (survival expansion). One instance, a child of the world.
##
## Shelter exit: an "[E] Plan a Trip" point on the inside of the supermarket's vestibule wall (next to the front
## doors; the doors' own story interactions are untouched) asks WHERE ARE YOU HEADING? - Continue Story (the current
## objective), Scavenge for Supplies, Use the Car (once repaired; then: for supplies or for the story).
## A trip is one state in Game.world_state["expedition"] (saved with the game): type, shelter, active time outside,
## danger level, items picked up, vehicle use, returned. Only ACTIVE time outside counts (not menus, dialogue,
## cinematics, or while inside the store); driving counts at a reduced rate.
## Danger (game/data/expedition.json): LOW -> RISING -> HIGH -> CRITICAL. Distant sounds grow closer and more
## frequent; Skitters are glimpsed crossing the fog; Hounds (the Chapter 7 Hound AI: collisions, non-lethal bites,
## a leash) come in from open ground outside the camera's view and approach; capped in number, with cooldowns,
## never inside the store, never during story scenes; they leave the way they came and are removed only out of view.
## Companions who are actually following warn the player (cooldowns, only the living and present) and walk faster.
## Returning: inside the store, "[E] Secure the Doors" shuts them and ends the trip (a summary of what was found);
## deposits go to the existing shelter supplies; sleeping needs one food and one water per person (protagonist
## included) from the story's first scavenging day on. One-time supply caches (never refilled) and the three car
## parts lie around town; the protagonist's own car (dead since the mist) can be repaired and driven again.

const CFG := "res://game/data/expedition.json"
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const SKITTER_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const HOUND_AI := preload("res://game/enemies/hound_ai.gd")
const CRAB_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Shellcrawler.tscn"
const STRUGGLE := preload("res://game/encounters/struggle.gd")
const CAR_QUEST := preload("res://game/world/car_quest.gd")
const EXIT_SPOT := Vector3(0.0, 1.4, 0.2)              # market-local: at the front doors themselves (from Cline)
const OUTSIDE_SPOT := Vector3(0.0, 1.3, -0.9)          # market-local: just outside the front doors
const SUPPLY_ITEMS := ["canned_food", "water_bottle", "energy_snack", "chocolate_bar", "cola_bottle", "painkillers", "batteries"]

var world: Node
var cfg := {}
var its := {}
var creatures: Array = []                # {"node", "ai", "kind", "exit"}
var report := {"spawned": 0, "hounds": 0, "skitters": 0, "warnings": 0, "despawned_unseen": 0, "max_active": 0}
var _tick := 0.0
var _encounter_t := 0.0
var _sound_t := 0.0
var _warn_t := 0.0
var _closed_t := 0.0
var _streams := {}


func setup(w: Node) -> void:
	world = w
	var f := FileAccess.open(CFG, FileAccess.READ)
	cfg = JSON.parse_string(f.get_as_text()) if f else {}
	_streams["bark"] = Sfx.bank("hound_distant")
	_streams["skitter"] = Sfx.bank("sk_stalk")
	_streams["crab"] = Sfx.bank("cr_threat")
	for k in ["ev_roof", "ev_metal", "ev_window", "ev_unknown", "co_distant"]:
		_streams[k] = Sfx.bank(k)
	var m: Node3D = world.market
	# the exit point on the store's own entrance marker (just inside the front doors), not a guessed spot
	var din := m.get_node_or_null("Doorways/Entrance_Inside") as Node3D
	var exit_at: Vector3 = (din.global_position + Vector3(0, 1.2, 0)) if din else m.global_transform * EXIT_SPOT
	its["exit"] = _spot("EXP_PlanTrip", exit_at, Vector3(2.4, 2.0, 0.8), _use_exit, m.global_transform.basis)
	its["outside"] = _spot("EXP_OpenDoors", m.global_transform * OUTSIDE_SPOT, Vector3(3.0, 2.2, 0.6), _use_outside, m.global_transform.basis)
	_place_supply_chest(m)
	_day = _today()
	_spawn_caches()
	# the car parts: real places with their own interactions (game/world/car_quest.gd), set out with the wrecks
	quest = CAR_QUEST.new()
	add_child(quest)
	quest.setup(self)
	VeilRestPoint.supply_gate = sleep_gate
	HOUND_AI.chase_gate = _may_chase                 # one hunter at a time, at the moment a chase would start
	# between story nights the shelter can wait out a day (supermarket era): supplies eaten, a new day in town
	VeilRestPoint.extra_night = _extra_night_ok
	VeilRestPoint.record_extra = _record_extra
	_encounter_t = float(cfg.get("encounter_cooldown_s", [999, 150])[1])
	_reset_director.call_deferred(float(st().get("elapsed", 0.0)))   # a load: the schedule resumes from the saved time
	Game.inventory_changed.connect(_part_markers)       # a part picked up: its diamond goes
	_refresh()


func st() -> Dictionary:
	if not Game.world_state.has("expedition"):
		Game.world_state["expedition"] = {"active": false, "type": "", "shelter": "", "elapsed": 0.0, "level": 0, "vehicle": false,
			"start_inv": {}, "collected": {}, "returned": true, "trips": 0}
	return Game.world_state["expedition"]


func active() -> bool:
	return bool(st().get("active", false))


func level() -> int:
	return int(st().get("level", 0))


# ------------------------------------------------------------------ context
func _p4() -> Node:
	return world.phase4 if world.phase4 and is_instance_valid(world.phase4) else null


func _c5() -> Node:
	var p := _p4()
	return p.chapter5 if p and p.chapter5 and is_instance_valid(p.chapter5) else null


## The shelter the group lives in right now ("" when there is none: the supermarket fell, the road).
func shelter() -> String:
	if Game.has_flag("ch9_supermarket_lost"):
		return ""
	if Game.has_flag("c5_started"):
		return "supermarket"
	return ""


func _player() -> Node3D:
	return world.player


func in_store() -> bool:
	var c5 := _c5()
	if c5 == null:
		return false
	return c5._in_store(world.market.to_local(_player().global_position))


## Story scenes that a supply run must never interrupt or run alongside.
func emergency(talk := true) -> bool:
	if Game.has_flag("ch8_attack_started") and not Game.has_flag("ch8_entrance_secured"):
		return true
	if Game.has_flag("ch9_warning_started") and not Game.has_flag("ch9_escaped"):
		return true
	if world.get("_encounter_running") == true or (talk and world.conversing):
		return true
	# a story trip with companions is under way (Chapters 6-8 followers)
	for f in _followers():
		if not f.has_meta("sv_companion"):              # a scavenging companion is not a story trip
			return true
	return false


func can_scavenge() -> bool:
	return shelter() != "" and not active() and not emergency() and _c5() != null


## Things that make "active time outside" stop counting: not outside, menus, dialogue, cinematics.
func _clock_running() -> bool:
	# (the inventory, searching furniture, a word with a companion, waiting in a house, driving: all count)
	var p := _player()
	if p == null or world.hud.is_paused() or get_tree().paused:
		return false
	if world.get("_encounter_running") == true or emergency(false):
		return false
	var cine = world.get("_cine")
	if cine and is_instance_valid(cine):
		return false
	if world.in_car:
		return true
	return p.visible and not in_store()


# ------------------------------------------------------------------ the shelter exit
func _use_exit(_b: Node) -> void:
	if active():
		if in_store():
			secure()
		return
	if not can_scavenge() or _busy_menu or not _menu_allowed():
		return
	var p4 := _p4()
	var sa = world.get("sidearm")
	if sa and sa.handover_pending():
		_busy_menu = true                            # "before you go back out there": the handgun first
		await sa.handover(p4.choice)
		_busy_menu = false
		return
	_busy_menu = true
	var m := menu_options()
	var opts: Array = m["labels"]
	var ids: Array = m["ids"]
	last_menu = ids.duplicate()
	var i: int = await p4.choice.ask("LEAVE THE SHELTER", opts, _player())
	var pick: String = ids[clampi(i, 0, ids.size() - 1)] if i >= 0 else "stay"
	if pick == "car":
		var j: int = await p4.choice.ask("What is the trip for?", ["Supplies", "The Story", "Cancel"], _player())
		pick = ["scavenge_car", "story", "stay"][clampi(j, 0, 2)] if j >= 0 else "stay"
		if pick == "scavenge_car" and not scavenge_available():
			pick = "stay"
	_busy_menu = false
	match pick:
		"story":
			continue_story()
		"sleep":
			var rest = p4.get("rest") if p4 else null
			if rest:
				rest.request()
		"scavenge":
			var who := ""
			if world.survivors:
				_busy_menu = true
				who = await world.survivors.pick_companion(p4.choice)
				_busy_menu = false
			start("scavenge", false)
			if world.survivors and active():
				world.survivors.begin_trip(who)
		"scavenge_car":
			var rider := ""
			if world.survivors:
				_busy_menu = true
				rider = await world.survivors.pick_companion(p4.choice)
				_busy_menu = false
			start("scavenge", true)
			if world.survivors and active():
				world.survivors.begin_trip(rider)          # they come along and ride in the passenger seat


var _busy_menu := false
var last_menu: Array = []                   ## (tests) the ids the last shelter menu offered


## The shelter exit's choices right now, in order: {"labels", "ids"}. One menu for every chapter.
func menu_options() -> Dictionary:
	var labels: Array = []
	var ids: Array = []
	var sd := story_door()
	var blocked := sd != null and String(sd.own_prompt()).begins_with("NOT YET")
	var step := String(Game.current_step().get("text", ""))
	labels.append("Continue Story" + (" - " + step if step != "" else "") + (" (not yet)" if blocked else ""))
	ids.append("story")
	if scavenge_available():
		labels.append("Go Scavenging")
		ids.append("scavenge")
		if Game.has_flag("vehicle_repaired"):
			labels.append("Use the Car")
			ids.append("car")
	if sleep_available():
		labels.append("Sleep / End Day")
		ids.append("sleep")
	labels.append("Stay Inside")
	ids.append("stay")
	return {"labels": labels, "ids": ids}


## One supply run per in-game day (a day = one shelter night; saved in the trip state).
func scavenge_available() -> bool:
	return can_scavenge() and int(st().get("scavenged_day", -1)) != _today()


## The office bed, offered from the exit too: a story night (the chapter's own rest prompt is up) or a survival
## night between story nights. The rest point itself still applies the story gate and the supply rule.
func sleep_available() -> bool:
	var p4 := _p4()
	var rest = p4.get("rest") if p4 else null
	if rest == null or rest.get("_busy") == true:
		return false
	if rest.interactable and rest.interactable.prompt_text != "":
		return true
	return _extra_night_ok()


## Not during a cinematic, a struggle, a conversation or any other scene that holds the player.
func _menu_allowed() -> bool:
	var p := _player()
	if p == null or not p.visible or p.get("controls_enabled") == false:
		return false
	if world.get("_encounter_running") == true or world.conversing:
		return false
	var cine = world.get("_cine")
	return not (cine and is_instance_valid(cine))


## The chapter's own story interaction on the shelter doors that has something to say right now (or null).
func story_door() -> Interactable:
	for d in _story_doors():
		if d.own_prompt() != "":
			return d
	return null


func _story_doors() -> Array:
	var out := []
	var c5 := _c5()
	if c5 and c5.its.has("exit") and is_instance_valid(c5.its["exit"]):
		out.append(c5.its["exit"])
	var ds = world.interactables.get("market/doors_shut")
	if ds and is_instance_valid(ds):
		out.append(ds)
	return out


## While the shelter menu is on offer every story door shows that menu instead (Interactable.redirect); during a
## supply run they are the trip's own doors ("Secure the Doors" inside, "Open the Doors" outside), never the story's.
func _door_redirect(_d: Interactable) -> Interactable:
	var e: Interactable = its.get("exit")
	if e and e.prompt_text != "":
		return e
	if active():
		return its.get("outside")
	return null


## "Continue Story": the chapter's own door action when it has one (so its scene runs exactly as written), a "not
## yet" reason when the chapter still needs something first, otherwise the doors open for the current objective.
func continue_story() -> void:
	var sd := story_door()
	if sd:
		var why := String(sd.own_prompt())
		if why.begins_with("NOT YET"):
			_hint(why)
			return
		story_departure = true
		_story_out = false
		sd.used.emit(_player())
		return
	story_departure = true
	_story_out = false
	var c5d := _c5()
	if c5d:
		c5d._set_doors(true)
	_hint("Objective: " + String(Game.current_step().get("text", "")))
var _quiet_t := 0.0                         ## active time outside with nothing about
var story_departure := false            ## "Continue Story" was chosen: the doors may open until the player is back in
var _story_out := false


## Normal shelter time with the player inside: the front doors only open through "[E] Leave Shelter" (a choice in
## the menu), never because the player or a companion walks up to them. Whenever this holds, that prompt is offered
## (same condition), so nobody is shut in; coming back from outside always opens them.
func doors_held() -> bool:
	return can_scavenge() and not story_departure and not _busy_menu and in_store()


func start(kind: String, vehicle: bool) -> void:
	if active():
		return                                       # one trip at a time
	var s := st()
	s["active"] = true
	s["type"] = kind
	s["shelter"] = shelter()
	s["elapsed"] = 0.0
	s["level"] = 0
	s["vehicle"] = vehicle
	s["start_inv"] = _inv_counts()
	s["collected"] = {}
	s["returned"] = false
	s["trips"] = int(s.get("trips", 0)) + 1
	if kind == "scavenge":
		s["scavenged_day"] = _today()                # the next one waits for tomorrow
	s["went_out"] = false
	s["started_at"] = Game.play_time
	_encounter_t = 60.0
	_reset_director(0.0)
	_sound_t = 20.0
	_warn_t = 0.0
	var c5 := _c5()
	if c5:
		c5._set_doors(true)
	var need := supply_need()
	_hint("Supply run. Tonight the group needs %d food and %d water (stored: %d / %d)." % [need["need"], need["need"], need["food"], need["water"]]
		+ (" The car is in the lot." if vehicle else ""))
	world.save()
	_refresh()


## Inside again: the doors are shut, the trip is over (whatever followed stops at the glass).
func secure() -> void:
	if not active():
		return
	var c5 := _c5()
	if c5:
		c5._set_doors(false)
	var s := st()
	var now := _inv_counts()
	var got := {}
	for k in now:
		var d: int = int(now[k]) - int(s.get("start_inv", {}).get(k, 0))
		if d > 0:
			got[k] = d
	s["collected"] = got
	s["active"] = false
	if world.survivors:
		world.survivors.end_trip(got)
	s["returned"] = true
	s["level"] = 0
	for c in creatures:
		if c["ai"] and is_instance_valid(c["ai"]):
			c["ai"].state = "RETURN"
	var parts := []
	for k in got:
		parts.append("%s +%d" % [Game.item_info(k).get("name", k), got[k]])
	world.hud.location_caption("TRIP OVER  -  " + (", ".join(parts) if not parts.is_empty() else "nothing found"), 3.0)
	Dialogue.say("exp_secured", false, true)
	var need := supply_need()
	_hint("Deposit what you found at the shelter supplies. Tonight: %d food, %d water needed (stored %d / %d)." % [need["need"], need["need"], need["food"], need["water"]])
	world.save()
	_refresh()


func _use_outside(_b: Node) -> void:
	var c5 := _c5()
	if active() and c5 and not c5._doors_open:
		c5._set_doors(true)
		_refresh()


func _inv_counts() -> Dictionary:
	var out := {}
	for k in SUPPLY_ITEMS + ["car_battery", "fuel_can", "car_fuse"]:
		out[k] = Game.inventory.count(k)
	return out


# ------------------------------------------------------------------ sleep needs (one food + one water per person)
## The supermarket's own stores: once, when the supply rule starts, the shelter holds enough food and water for two
## nights of the group as it actually is (survivors + the protagonist); after that it is scavenging. Saved
## (world_state "supply_grace"): never given twice, never after the first two nights of an older save.
func _grace_stock() -> void:
	if Game.world_state.get("supply_grace", false):
		return
	Game.world_state["supply_grace"] = true
	if (Game.world_state.get("shelter_nights", {}) as Dictionary).size() >= 2:
		return
	var n: int = world.shelter_roster().size() + 1
	var stock := Game.shelter_stock()
	for k in ["food", "water"]:
		stock[k] = maxi(int(stock.get(k, 0)), 2 * n)
	Game.world_state["shelter_stock"] = stock


func supply_need() -> Dictionary:
	if shelter() == "supermarket":
		_grace_stock()
	var stock := Game.shelter_stock()
	var n: int = world.shelter_roster().size() + 1
	return {"need": n, "food": int(stock.get("food", 0)), "water": int(stock.get("water", 0))}


func _extra_night_ok() -> bool:
	return shelter() == "supermarket" and not active() and not emergency() and Game.has_flag("c5_started")


func _record_extra(t: String) -> void:
	var p4 := _p4()
	if p4:
		p4.record_night(t)


func _exit_tree() -> void:
	VeilRestPoint.extra_night = Callable()             # (never a call into a freed controller)
	VeilRestPoint.record_extra = Callable()
	VeilRestPoint.supply_gate = Callable()
	HOUND_AI.chase_gate = Callable()


## VeilRestPoint.supply_gate: "" = sleep allowed; otherwise the reason it is not.
func sleep_gate() -> String:
	var from := String(cfg.get("sleep_requires_supplies_from_flag", ""))
	if from == "" or not Game.has_flag(from) or shelter() == "":
		return ""
	if active() and in_store():
		secure()
	var n := supply_need()
	if n["food"] < n["need"] or n["water"] < n["need"]:
		var carried := 0
		for id in Game.inventory:
			if Game.shelter_resource(id) in ["food", "water"]:
				carried += 1
		var m: Node3D = world.market
		if carried > 0:
			world._beacon("supplies_hint", m.global_transform * Vector3(7.8, 1.4, 6.05), Color(0.6, 1.0, 0.7))
			return "Not enough food and water for everyone tonight (food %d / %d, water %d / %d). You are carrying %d - put them in the SHELTER SUPPLIES by the service desk (lit), or go out for more." % [n["food"], n["need"], n["water"], n["need"], carried]
		world._beacon("supplies_hint", m.global_transform * EXIT_SPOT, Color(0.6, 1.0, 0.7))
		return "Not enough food and water for everyone tonight (food %d / %d, water %d / %d). Plan a supply run at the front doors (lit): food and water lie around the lot and the houses behind the store." % [n["food"], n["need"], n["water"], n["need"]]
	world._clear_beacon("supplies_hint")
	return ""


# ------------------------------------------------------------------ one-time caches and car parts
## Supply finds restock every new day (each one-time per day): the shelter needs food and water every night, and a
## town picked clean by the second night would leave no way to keep going.
var _day := -1
var _cache_nodes: Array = []


func _today() -> int:
	return (Game.world_state.get("shelter_nights", {}) as Dictionary).size()


func _spawn_caches() -> void:
	for n in _cache_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_cache_nodes.clear()
	var idx := -1
	for c in cfg.get("caches", []):
		idx += 1
		var once := Game.item_info(String(c["item"])).has("rounds")    # handgun rounds: one-time finds, never restocked
		if not once and _day > 0 and (idx + _day) % 2 == 1:
			continue                                     # each new day only about half the spots have something
		if String(c["item"]) == "fuel_can" and not Game.has_flag("vehicle_repaired"):
			continue                                     # until the car runs the only can is the repair quest's own
		var key := "exp/cache_" + String(c["id"]) + ("" if _day == 0 or once else "_d%d" % _day)
		_cache(c, key, String(c["item"]), String(c.get("label", "")), "", 1.0)
		if its.has(key) and is_instance_valid(its[key]):
			_cache_nodes.append((its[key] as Node).get_parent())


func _cache(c: Dictionary, key: String, item: String, _label: String, model: String, scale: float) -> void:
	var path := model if model != "" else String(Game.item_info(item).get("model", ""))
	var ps := load(path) as PackedScene if path != "" else null
	if ps == null:
		return
	var n := ps.instantiate() as Node3D
	n.name = "EXP_" + key.get_file()
	world.add_child(n)
	var p: Array = c["pos"]
	n.global_position = Vector3(p[0], p[1], p[2])
	n.scale = Vector3.ONE * scale
	var it := Interactable.attach(n, {"kind": "pickup", "label": Game.item_info(item).get("name", item), "item_id": item, "state_key": key})
	var cs := it.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = (cs.shape as BoxShape3D).size.max(Vector3(0.6, 0.5, 0.6) / scale)
	its[key] = it
	_settle.call_deferred(n)


func _settle(n: Node3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(n):
		return
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = [_player().get_rid()]
	for co in n.find_children("*", "CollisionObject3D", true, false):
		ex.append((co as CollisionObject3D).get_rid())
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(n.global_position + Vector3.UP * 1.5,
		n.global_position - Vector3.UP * 3.0, 1, ex))
	if hit:
		n.global_position.y = (hit["position"] as Vector3).y + 0.002
		var it := n.get_node_or_null("Interact") as Interactable
		if it:
			it._base = n.transform


## The shelter supplies chest: the storage chest by the service desk IS the supplies point - "[E] Shelter
## Supplies" on the chest itself opens the existing supplies screen (deposit, stock, tonight's need, shortages; the
## same shelter stock and roster). A small diamond over it while the player carries food or water. The old
## invisible point there is switched off, so the chest is the only one. First use: a word on what it is for.
var supply_chest: Interactable


func _place_supply_chest(market: Node3D) -> void:
	var ps := load("res://THE_VEIL_ASSETS_V2/03_Residential/Interactive_Props/RES_IP_StorageChest.glb") as PackedScene
	if ps == null:
		return
	var chest := ps.instantiate() as Node3D
	chest.name = "EXP_SupplyChest"
	market.add_child(chest)
	chest.global_position = market.global_transform * Vector3(7.8, 0.04, 6.05)
	for co in chest.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0           # (never blocks a path: the interaction box covers it)
		(co as CollisionObject3D).collision_mask = 0
	supply_chest = Interactable.attach(chest, {"kind": "custom", "label": "Shelter Supplies", "prompt_text": "[E] Shelter Supplies"})
	var cs := supply_chest.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = (cs.shape as BoxShape3D).size.max(Vector3(1.0, 1.0, 0.9))
	supply_chest.used.connect(_use_supply_chest)
	_retire_old_supplies_spot.call_deferred()


func _retire_old_supplies_spot() -> void:
	var p4 := _p4()
	if p4 == null:
		return
	for n in p4.find_children("*", "Interactable", true, false):
		if n != supply_chest and String((n as Interactable).prompt_text) == "[E] Shelter Supplies":
			(n as Interactable).collision_layer = 0
			(n as Interactable).prompt_text = ""


## Chapter 5's "check the supplies" step, done at this crate (the one supplies spot in the shelter).
func c5_check_pending() -> bool:
	var c5 := _c5()
	return c5 != null and Game.has_flag("c5_talked_both") and not Game.has_flag("c5_supplies_checked")


## Chapter 6's "Prepare for the search" supplies check: the same crate (the old stash by the service desk is gone).
func c6_check_pending() -> bool:
	var c6 := _c6()
	return c6 != null and Game.has_flag("ch6_eddie_talked") and not Game.has_flag("ch6_eddie_ready")


func _c6() -> Node:
	var c5 := _c5()
	var c6 = c5.get("chapter6") if c5 else null
	return c6 if c6 != null and is_instance_valid(c6) else null


func _use_supply_chest(_b: Node) -> void:
	if c5_check_pending():
		_c5()._check_supplies(null)
		return
	if c6_check_pending():
		_c6()._check_supplies(null)
		return
	var p4 := _p4()
	if p4 == null or shelter() != "supermarket":
		return
	if not Game.has_flag("supply_chest_tutorial"):
		Game.set_flag("supply_chest_tutorial")
		_hint("Store supplies here. We'll need food and water to survive another night.")
	p4._open_supplies()


func _supply_chest_marker() -> void:
	if supply_chest == null:
		return
	var carrying := Game.inventory.any(func(i): return Game.shelter_resource(String(i)) in ["food", "water"])
	var on: bool = shelter() == "supermarket" and carrying and in_store()
	world.hud.world_diamond("supply_chest", supply_chest if on else null)
	var pending := c5_check_pending() or c6_check_pending()
	supply_chest.prompt_text = "[E] Check the Supplies" if pending else "[E] Shelter Supplies"
	supply_chest.collision_layer = 8 if shelter() == "supermarket" or pending else 0


# ------------------------------------------------------------------ the car (the protagonist's own sedan)
## Called by world.enter_car() while the car is dead. Returns true when this handled the press.
func dead_car() -> bool:
	if not Game.has_flag("c5_started") or shelter() == "":
		return false
	if not Game.has_flag("vehicle_found"):
		Game.set_flag("vehicle_found")
		Dialogue.say("exp_car_inspect", false, true)
		for f in _followers():
			if String(f.npc.name) == "Eddie":
				Dialogue.say("exp_car_eddie", false, false)
		Dialogue.say("cq_clues", true, false)            # where the parts might be (said once; leads go on the map)
	_inspect_car()
	return true


## The abandoned vehicle a part comes from (expedition.json "prop"): only once the town is lost, never in the normal
## opening; its own convex collision, standing on the ground.
func _part_prop(c: Dictionary) -> void:
	var pr: Dictionary = c.get("prop", {})
	if pr.is_empty():
		return
	var ps := load(String(pr["scene"])) as PackedScene
	if ps == null:
		return
	var o := ps.instantiate() as Node3D
	o.name = "EXP_Wreck_" + String(c["id"])
	world.add_child(o)
	var p: Array = pr["pos"]
	o.global_transform = Transform3D(Basis(Vector3.UP, float(pr.get("yaw", 0.0))), Vector3(p[0], p[1], p[2]))
	_settle.call_deferred(o)


## Search leads for the town map: [key, short label, world position]. Before the repair: each part still out there,
## once the car has been inspected. After it: a fuel can when the tank runs low, duct tape when the car is knocked
## about (real finds, today's).
const LEAD_NAMES := {"car_battery": "POSSIBLE CAR BATTERY", "fuel_can": "POSSIBLE GAS CANISTER", "car_fuse": "POSSIBLE CAR FUSE",
	"starter_relay": "POSSIBLE STARTER RELAY", "duct_tape": "POSSIBLE DUCT TAPE"}


func car_leads() -> Array:
	var out: Array = []
	if not Game.has_flag("vehicle_found") or shelter() == "":
		return out
	if not Game.has_flag("vehicle_repaired"):
		for c in cfg.get("vehicle_parts", []):
			var item := String(c["item"])
			var pt = its.get("exp/part_" + String(c["id"]))
			if pt != null and is_instance_valid(pt) and not pt.taken and not installed(item) and not Game.has_item(item) \
					and seen(String(c["id"])):
				out.append(["part:" + String(c["id"]), String(LEAD_NAMES.get(item, "POSSIBLE CAR PART")), (pt as Node3D).global_position])
		return out
	var want: Array = []
	if world.sedan.fuel < 0.3 and not Game.has_item("fuel_can"):
		want.append("fuel_can")
	if world.sedan.condition < 0.4 and not Game.has_item("duct_tape"):
		want.append("duct_tape")
	for key in its:
		var it = its[key]
		if not String(key).begins_with("exp/cache_") or not is_instance_valid(it) or it.taken or String(it.item_id) not in want:
			continue
		out.append(["part:" + String(key), String(LEAD_NAMES[String(it.item_id)]), (it as Node3D).global_position])
	return out


## The car's four faults, what fixes each and where that part lies (fixed finds, not random loot: car_quest.gd).
## [item, checklist name, missing text, where to look]
const CAR_PARTS := [["fuel_can", "Fuel canister", "missing", ""], ["car_battery", "Battery", "missing", ""],
	["car_fuse", "Fuse", "missing", ""], ["starter_relay", "Starter relay", "missing", ""]]
const FIT_VERB := {"car_battery": "Install the battery", "car_fuse": "Insert the fuse", "fuel_can": "Pour in the gas canister",
	"starter_relay": "Fit the starter relay"}


func installed(id: String) -> bool:
	return Game.has_flag("vehicle_repaired") or bool((st().get("car_parts", {}) as Dictionary).get(id, false))


func all_installed() -> bool:
	return CAR_PARTS.all(func(c): return installed(String(c[0])))


## The checklist as it really stands (each line from the saved state and the inventory).
func checklist() -> String:
	var text := "VEHICLE CHECKLIST"
	for c in CAR_PARTS:
		var id := String(c[0])
		var mark := "[X]" if installed(id) else ("[+]" if Game.has_item(id) else "[  ]")
		var state := "installed" if installed(id) else ("collected" if Game.has_item(id) else String(c[2]))
		text += "\n%s %s - %s" % [mark, c[1], state]
	return text


## The same, as rows for the compact checklist panel: [done, name, status, carried].
func checklist_rows() -> Array:
	var out: Array = []
	for c in CAR_PARTS:
		var id := String(c[0])
		var done := installed(id)
		var carried := not done and Game.has_item(id)
		out.append([done, String(c[1]), "installed" if done else ("collected" if carried else "missing"), carried])
	return out


## [E] Inspect Car: the checklist; a carried part is fitted from here (progress is kept); Start Engine at the end.
func _inspect_car() -> void:
	var p4 := _p4()
	if p4 == null or p4.choice.is_open() or _repairing:
		return
	if not active() and CAR_PARTS.any(func(c): return Game.has_item(String(c[0])) and not installed(String(c[0]))):
		_hint("I'll work on the car on a supply run, once I'm done with what I'm doing.")
	while not Game.has_flag("vehicle_repaired"):
		var rows := checklist_rows()
		var opts: Array = []
		var ids: Array = []
		for c in CAR_PARTS:
			if not installed(c[0]) and Game.has_item(c[0]) and active():     # fitting: only on a supply run
				opts.append(String(FIT_VERB[c[0]]))
				ids.append(c[0])
		if all_installed() and active():
			opts.append("Start Engine")
			ids.append("_start")
		elif not active():
			rows.append("I'll work on the car on a supply run, once I'm done with what I'm doing.")
		elif ids.is_empty():
			rows.append("Nothing to fit yet. The parts must be out in town - look around the wrecks and the gas station.")
		opts.append("Close")
		var i: int = await p4.choice.ask("CAR REPAIR", opts, _player(), rows)
		if i < 0 or i >= ids.size():
			break
		if ids[i] == "_start":
			await start_engine()
		else:
			await _fit(String(ids[i]))
	_part_markers()


func _fit(id: String) -> void:
	if installed(id) or not Game.has_item(id):
		return                                         # never twice, never without the part
	_repairing = true
	var p := _player()
	p.set("controls_enabled", false)
	p.set("velocity", Vector3.ZERO)
	await quest.install(id)
	Game.remove_item(id)
	if id == "fuel_can":
		world.sedan.fuel = PlayerSedan.FUEL_PER_CAN        # one can in an empty tank
	var parts: Dictionary = st().get("car_parts", {})
	parts[id] = true
	st()["car_parts"] = parts
	p.set("controls_enabled", true)
	p.set("look_enabled", true)
	_repairing = false
	world.save()
	_refresh()


## Everything is in: the starter, the engine catching, the car running (set once, never twice).
func start_engine() -> void:
	if Game.has_flag("vehicle_repaired") or not all_installed():
		return
	_repairing = true
	await quest.start_engine()
	Game.set_flag("vehicle_repaired")
	_spawn_caches()                                    # the refuel cans (none while the car was dead)
	world.sedan.survival = true
	Dialogue.say("exp_car_running", false, true)
	_hint("The car runs again. E at the driver's door to get in.")
	_player().set("controls_enabled", true)
	_player().set("look_enabled", true)
	_repairing = false
	world.save()
	_refresh()


## The repaired car, before getting in: its fuel and condition; a carried fuel can fills it, duct tape patches it
## (each item used up - nothing is fixed without the part). Returns true when the player is NOT getting in now.
func car_menu() -> bool:
	var car = world.sedan
	if not Game.has_flag("vehicle_repaired") or not car.get("survival"):
		return false
	var can_fuel: bool = Game.has_item("fuel_can") and car.fuel < 0.95
	var can_patch: bool = Game.has_item("duct_tape") and car.condition < 0.95
	if car.drivable() and not can_fuel and not can_patch:
		return false                                  # nothing to do here: straight in
	var p4 := _p4()
	if p4 == null or p4.choice.is_open():
		return true
	while true:
		var text := "VEHICLE CONDITION\n" + String(car.status_text())
		var why: String = quest.unusable_reason()
		if why != "":
			text = why + "\n" + text
		if car.fuel <= 0.0:
			text += "\nThe tank is empty - it needs a gas canister (gas station, abandoned vehicles; see the town map)."
		if car.condition <= 0.0:
			text += "\nIt won't run like this - it needs patching up with duct tape (see the town map)."
		var opts: Array = []
		var acts: Array = []
		if Game.has_item("fuel_can") and car.fuel < 0.95:
			opts.append("Pour in the gas canister")
			acts.append("fuel")
		if Game.has_item("duct_tape") and car.condition < 0.95:
			opts.append("Patch it up (duct tape)")
			acts.append("patch")
		if car.drivable():
			opts.append("Get in")
			acts.append("in")
		opts.append("Close")
		acts.append("close")
		var i: int = await p4.choice.ask(text, opts, _player())
		var a: String = acts[clampi(i, 0, acts.size() - 1)] if i >= 0 else "close"
		match a:
			"fuel":
				await quest.install("fuel_can")
				Game.remove_item("fuel_can")
				car.fuel = minf(car.fuel + PlayerSedan.FUEL_PER_CAN, 1.0)
				Sfx.play("pickup", car.global_position + Vector3(0, 0.8, 0), -6.0, 0.6)
				world.save()
			"patch":
				Game.remove_item("duct_tape")
				car.condition = minf(car.condition + 0.6, 1.0)
				Sfx.play("door_close", car.global_position + Vector3(0, 0.8, 0), -8.0, 0.7)
				world.save()
			"in":
				return false
			_:
				return true
	return true


## Yellow diamonds on the parts still out there, once the car has been looked at (until it runs).
func _part_markers() -> void:
	for c in cfg.get("vehicle_parts", []):
		var key := "exp/part_" + String(c["id"])
		var it: Interactable = its.get(key)
		var on: bool = shelter() != "" and Game.has_flag("vehicle_found") and not Game.has_flag("vehicle_repaired") and it != null \
			and is_instance_valid(it) and not it.taken and not installed(String(c["item"])) and seen(String(c["id"]))
		world.hud.world_diamond("car_part_" + String(c["id"]), it if on else null)


# ------------------------------------------------------------------ car parts: found by looking, not handed out
## A part is only marked (yellow diamond, map lead) once the player has come close to it (DISCOVER_M, with a
## line of sight - never through a building or from across town); the first time, one short observation.
## Saved in the expedition state ("car_seen"), so a load keeps what was found and never repeats the line.
const DISCOVER_M := 5.5
const SEEN_LINE := {"fuel_can": "exp_seen_fuel", "car_battery": "exp_seen_battery", "car_fuse": "exp_seen_fuse",
	"starter_relay": "exp_seen_relay"}


func seen(id: String) -> bool:
	return bool((st().get("car_seen", {}) as Dictionary).get(id, false))


func _discover_parts() -> void:
	if Game.has_flag("vehicle_repaired") or not Game.has_flag("vehicle_found") or shelter() == "":
		return
	var p := _player()
	if p == null or not p.visible:
		return
	var eye := p.global_position + Vector3(0, 1.5, 0)
	for c in cfg.get("vehicle_parts", []):
		var id := String(c["id"])
		if seen(id):
			continue
		var it: Interactable = its.get("exp/part_" + id)
		if it == null or not is_instance_valid(it) or it.taken or installed(String(c["item"])):
			continue
		var at := (it as Node3D).global_position
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() > DISCOVER_M:
			continue
		if _sees(eye, at):
			mark_seen(id)


func mark_seen(id: String) -> void:
	if seen(id):
		return
	var d: Dictionary = st().get("car_seen", {})
	d[id] = true
	st()["car_seen"] = d
	if SEEN_LINE.has(id):
		Dialogue.say(String(SEEN_LINE[id]), true)
	_part_markers()


## A clear line from the eye to the part (or the first thing hit lies right by it: the wreck holding it).
func _sees(eye: Vector3, at: Vector3) -> bool:
	var target := at + Vector3(0, 0.25, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1)
	var p := _player()
	if p is CollisionObject3D:
		q.exclude = [(p as CollisionObject3D).get_rid()]
	var hit: Dictionary = (world.get_world_3d() as World3D).direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 1.6


func _repair() -> void:
	for c in CAR_PARTS:
		if Game.has_item(c[0]) and not installed(c[0]):
			await _fit(String(c[0]))


var _repairing := false
var _props_placed := false
var quest: Node                          ## VeilCarQuest


# ------------------------------------------------------------------ danger, encounters, warnings
func _followers() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("veil_companion_follow"):
		if n is VeilCompanionFollow and world.is_ancestor_of(n) and (n as VeilCompanionFollow).active \
				and (n as VeilCompanionFollow).npc and (n as VeilCompanionFollow).npc.is_visible_in_tree():
			out.append(n)
	return out


func _danger(delta: float) -> void:
	if not active() or not _clock_running():
		return
	var s := st()
	var scale: float = float(cfg.get("driving_time_scale", 1.0)) if world.in_car else 1.0
	s["elapsed"] = float(s["elapsed"]) + delta * scale
	var th: Array = cfg.get("danger_thresholds_s", [45, 90, 150, 240])
	var lv := 0
	for t in th:
		if float(s["elapsed"]) >= float(t):
			lv += 1
	if lv != int(s["level"]):
		s["level"] = lv
		_on_level(lv)
		_dbg("danger -> %s" % _lv_name(lv))
	# sounds: more often, and closer, as it gets worse
	_sound_t -= delta
	if _sound_t <= 0.0:
		var si: Array = cfg.get("sound_interval_s", [28, 20, 14, 10, 7])
		_sound_t = float(si[mini(lv, si.size() - 1)]) * randf_range(0.7, 1.3)
		_distant_sound(mini(lv, 3))
	_one_hunter()
	_dir_t -= delta
	if _dir_t <= 0.0:
		_dir_t = 1.0
		_direct(lv)
	_warn_t -= delta


## The director's schedule from expedition time `el` (a new trip: 0; a load mid-trip: the saved time - the first
## hunter still comes at about a minute, or 25 s after a load late in a trip, never at once).
func _reset_director(el: float) -> void:
	_next_hunt = maxf(60.0, el + 25.0)
	_next_roam = maxf(20.0, el + 12.0)
	_next_tent = maxf(160.0, el + 45.0)
	_dir_t = 1.0


func _lv_name(lv: int) -> String:
	var n: Array = cfg.get("level_names", ["UNEASY", "RISING", "HIGH", "CRITICAL", "EXTREME"])
	return String(n[clampi(lv, 0, n.size() - 1)])


func _lvv(key: String, lv: int, fallback: Array) -> float:
	var a: Array = cfg.get(key, fallback)
	return float(a[clampi(lv, 0, a.size() - 1)])


# ------------------------------------------------------------------ the threat director
## Runs once a second of active time outside. Roles:
##   roamer - patrols open ground near where the player is (fog: often heard or glimpsed first); it hunts only if it
##            actually sees or hears them. Moves on after a while.
##   hunter - (at most one) tracks the player: it keeps heading for where they are (their last spot outdoors while
##            they are in a house: it waits in the yard), until it finds them (the AI's own chase, bites, struggles)
##            or loses them for good; then it leaves.
##   leaving - walking away; removed only once far off and out of view.
## Plus, CRITICAL and up, one dynamic Tentacle at a time bursting through the ground near the player.
var _dir_t := 1.0
var _next_hunt := 60.0           ## expedition seconds: the next hunter may come from then on
var _next_roam := 20.0
var _next_tent := 160.0
var _tentacle: Node3D = null
var _last_out := Vector3.INF     ## the player's last position outdoors (on foot or in the car)
const DEBUG_ARG := "--veil-threat-log"


func _dbg(msg: String) -> void:
	if OS.is_debug_build() or DEBUG_ARG in OS.get_cmdline_user_args():
		print("[Threat] t=%.0fs %s | %s" % [float(st().get("elapsed", 0.0)), _lv_name(level()), msg])


## Where the threat aims: the car while driving, the player outdoors, else the last spot they were outdoors.
func threat_target() -> Vector3:
	if world.in_car:
		return world.sedan.global_position
	var p := _player().global_position
	if _outdoors_at(p):
		_last_out = p
		return p
	return _last_out if _last_out.is_finite() else p


## Open sky above (not in a house, the store, a garage).
func _outdoors_at(p: Vector3, skip: Node = null) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = [_player().get_rid()]
	if skip is CollisionObject3D:
		ex.append((skip as CollisionObject3D).get_rid())
	var c5 := _c5()
	if c5 and c5._in_store(world.market.to_local(p), -1.0):
		return false
	if in_house(p):
		return false                                     # (house roofs have no collision: the rooms say it)
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, 14, 0), 1, ex)).is_empty()


var _house_nodes: Array = []


## Inside one of the town's houses (its rooms' floor plans, any storey), with a small margin for the walls.
func in_house(p: Vector3, margin := 0.4) -> bool:
	if _house_nodes.is_empty():
		var hs := world.get_node_or_null("Residential/Houses")
		if hs:
			_house_nodes = hs.get_children().filter(func(h): return h is Node3D and (h.get_meta("veil_house", {}) as Dictionary).has("rooms"))
	for h in _house_nodes:
		var hn := h as Node3D
		if not is_instance_valid(hn) or hn.global_position.distance_to(p) > 30.0:
			continue
		var lp := hn.to_local(p)
		for r in (hn.get_meta("veil_house") as Dictionary)["rooms"]:
			var rc: Array = r["rect"]
			if lp.x > float(rc[0]) - margin and lp.x < float(rc[2]) + margin and lp.z > float(rc[1]) - margin and lp.z < float(rc[3]) + margin:
				return true
	return false


## Inside the supermarket while it is the shelter (the vestibule included).
func _in_shelter(p: Vector3) -> bool:
	if shelter() != "supermarket" or world.market == null:
		return false
	var l: Vector3 = world.market.to_local(p)
	return l.z > 0.4 and l.z < 17.6 and absf(l.x) < 20.0


## The shelter's ward: within SAFE_R of the current shelter (the supermarket, the Mill House, the refuge - the town
## map's own record of it) the player is safe from the trip's creatures. A hunt ends the moment the player is back
## in reach of it, and no trip creature comes nearer than that: it turns and goes off past the edge of the ward.
## Story creatures (not in `creatures`) are never held back.
const SAFE_R := 30.0


func shelter_spot() -> Vector3:
	var nm = world.get("nav")
	var sh: Array = nm.shelter() if nm and nm.has_method("shelter") else []
	return sh[0] if not sh.is_empty() else Vector3.INF


func shelter_safe(p: Vector3) -> bool:
	if _in_shelter(p):
		return true
	var c := shelter_spot()
	return c.is_finite() and Vector2(p.x - c.x, p.z - c.z).length() < SAFE_R


func _shelter_ward() -> void:
	var c := shelter_spot()
	if not c.is_finite() or creatures.is_empty():
		return
	var player_safe := shelter_safe(_player().global_position)
	for cr in creatures:
		var ai = cr.get("ai")
		var n: Node3D = cr["node"]
		if ai == null or not is_instance_valid(n) or not is_instance_valid(ai):
			continue
		var near := Vector2(n.global_position.x - c.x, n.global_position.z - c.z).length() < SAFE_R + 6.0
		var hunting := String(ai.state) in ["CHASE", "SUSPICIOUS", "SEARCH"]
		if (player_safe and hunting) or near:
			if String(cr.get("role", "")) == "leaving" and not near:
				continue
			_leave(cr, "the shelter's ward")
			var away := (n.global_position - c) * Vector3(1, 0, 1)
			away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			ai.home = c + away * (SAFE_R + 40.0)               # out past the ward, never towards the doors
			ai.leash = 999.0
			ai.state = "RETURN"


## At the doors with the player inside: a chase ends there (it does not follow into the shelter).
func _guard_doors() -> void:
	if shelter() != "supermarket" or world.market == null or not _in_shelter(_player().global_position):
		return
	for c in creatures:
		var ai = c.get("ai")
		var n: Node3D = c["node"]
		if ai == null or not is_instance_valid(n):
			continue
		var l: Vector3 = world.market.to_local(n.global_position)
		if l.z > -4.0 and String(ai.state) in ["CHASE", "SUSPICIOUS", "SEARCH"]:
			_leave(c, "the player is inside the shelter")


func _role_count(role: String) -> int:
	var n := 0
	for c in creatures:
		if String(c.get("role", "")) == role and is_instance_valid(c["node"]):
			n += 1
	return n


## The player in one of the town's houses: the creatures stay outside and keep at it - the hunter walks the yard
## and the street in front (its give-up clock waits), roamers keep patrolling. The moment the player is out again,
## whatever is still about and near hears the door and comes to look (its own sight and hearing do the rest).
var _was_in_house := false
var _yard_t := 0.0
var house_report := {"entered": 0, "exited": 0, "alerted_on_exit": 0}


func _house_state(el: float) -> void:
	var p := _player().global_position
	var inside: bool = not world.in_car and in_house(p)
	if inside and not _was_in_house:
		house_report["entered"] += 1
		_dbg("player went into a house: the creatures wait outside")
	elif _was_in_house and not inside and not world.in_car:
		house_report["exited"] += 1
		for c in creatures:
			var ai = c.get("ai")
			var b: Node3D = c["node"]
			if ai == null or not is_instance_valid(ai) or not is_instance_valid(b) or String(c.get("role", "")) == "leaving":
				continue
			if b.global_position.distance_to(p) < 40.0 and String(ai.state) in ["PATROL", "SUSPICIOUS", "SEARCH", "RETURN"]:
				ai.home = b.global_position
				ai.set("_last_seen", p)
				ai.state = "SUSPICIOUS"
				ai.set("awareness", maxf(float(ai.get("awareness")), 0.75))
				c["born_el"] = el                             # a fresh start on the hunt
				house_report["alerted_on_exit"] += 1
				_dbg("%s heard the player come out (%.1f m)" % [c["kind"], b.global_position.distance_to(p)])
	_was_in_house = inside
	if not inside:
		return
	# inside: nobody gives up while the player hides; the hunter walks the yard (a new spot every few seconds)
	_yard_t -= 1.0
	for c in creatures:
		var ai = c.get("ai")
		if ai == null or not is_instance_valid(ai) or String(c.get("role", "")) == "leaving":
			continue
		c["born_el"] = float(c.get("born_el", el)) + 1.0
		if String(c.get("role", "")) == "hunter" and _yard_t <= 0.0 and _last_out.is_finite() \
				and String(ai.state) in ["SUSPICIOUS", "SEARCH"]:
			var spot := _yard_spot(_last_out)
			if spot.is_finite():
				ai.set("_last_seen", spot)
	if _yard_t <= 0.0:
		_yard_t = 5.0


## A point on open ground 3-7 m from where the player went in (the yard, the path, the street), never indoors.
func _yard_spot(around: Vector3) -> Vector3:
	for i in 8:
		var a := randf() * TAU
		var c := around + Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, 7.0)
		if _outdoors_at(c) and not in_house(c, 1.0):
			return c
	return around


func _direct(lv: int) -> void:
	_prune()
	var el := float(st().get("elapsed", 0.0))
	var tgt := threat_target()
	if emergency():
		return
	_house_state(el)
	# the hunter keeps coming: refresh where it thinks the player is (never while it is chasing, recovering or
	# already going home - a handgun shot or a lost trail sends it off for good)
	var chasing := 0
	for c in creatures:
		var ai = c.get("ai")
		if ai == null or not is_instance_valid(ai):
			continue
		var b: Node3D = c["node"]
		var st_s := String(ai.state)
		if st_s == "CHASE":
			chasing += 1
		match String(c.get("role", "")):
			"hunter":
				if st_s in ["PATROL", "SUSPICIOUS", "SEARCH"]:
					ai.home = b.global_position              # it is hunting: no leash back to where it came in
					ai.set("_last_seen", tgt)
					if st_s != "SUSPICIOUS":
						ai.state = "SUSPICIOUS"
					ai.set("awareness", maxf(float(ai.get("awareness")), 0.6))
				elif st_s == "RETURN":
					_leave(c, "hunter lost the trail or was driven off")
				elif st_s == "CHASE" and not c.get("engaged", false):
					c["engaged"] = true
					report["engaged"] = int(report.get("engaged", 0)) + 1
					_dbg("ENGAGED %s at %s, %.1f m from the player" % [c["kind"], _v(b.global_position), b.global_position.distance_to(tgt)])
				if el - float(c.get("born_el", el)) > 150.0 and st_s != "CHASE":
					_leave(c, "hunter gave up after 150 s")
			"roamer":
				if st_s == "CHASE" and _role_count("hunter") == 0:
					c["role"] = "hunter"                   # it found them by itself: this is the hunt now
					c["born_el"] = el
					_dbg("roamer %s took up the hunt" % c["kind"])
				elif el - float(c.get("born_el", el)) > 120.0 and st_s in ["PATROL", "RETURN"]:
					_leave(c, "roamer moved on after 120 s")
	# new arrivals (two out at most, one hunter at most)
	var live := 0
	for c in creatures:
		if c.get("ai") != null:                       # (one walking away still counts until it is gone)
			live += 1
	var cap := int(cfg.get("max_dynamic_creatures", 2))
	if _role_count("hunter") == 0 and lv >= 1 and el >= _next_hunt and live < cap:
		if not _promote_roamer(tgt):
			var kind := _pick_kind(lv)
			if _spawn_creature(kind, "hunter", tgt):
				_next_hunt = el + _lvv("encounter_cooldown_s", lv, [60, 50, 40, 30, 22])
			else:
				_next_hunt = el + 3.0                     # no good spot this second: try again shortly
	elif live < cap and el >= _next_roam and _role_count("roamer") == 0 and (lv >= 1 or el >= 20.0):
		if _spawn_creature("hound" if lv <= 1 else _pick_kind(lv), "roamer", tgt):   # (HIGH on: Skitters, then Crabs too)
			_next_roam = el + _lvv("roam_cooldown_s", lv, [70, 55, 45, 40, 35])
		else:
			_next_roam = el + 4.0
	# CRITICAL and up: the ground itself
	if lv >= 3 and el >= _next_tent and (_tentacle == null or not is_instance_valid(_tentacle)) and not world.in_car:
		if _spawn_tentacle():
			_next_tent = el + _lvv("tentacle_cooldown_s", lv, [999, 999, 999, 55, 40])
		else:
			_next_tent = el + 5.0


## The chase gate: a trip creature may start hunting only if no other one is (otherwise it turns away and leaves).
## Story creatures (not in `creatures`) are never held back.
func _may_chase(ai: Node) -> bool:
	var mine = null
	for c in creatures:
		if c.get("ai") == ai:
			mine = c
	if mine == null:
		return true
	if shelter_safe(_player().global_position):
		_leave(mine, "the player is by the shelter")
		return false
	for c in creatures:
		var o = c.get("ai")
		if c != mine and o and is_instance_valid(o) and String(o.state) == "CHASE":
			_leave(mine, "a second creature found the player: only one hunts at a time")
			return false
	return true


## Only one creature hunts the player at a time (checked every frame): a roamer that spots them while another is
## already after them turns away (it leaves - beyond its new home's leash it ignores the player).
func _one_hunter() -> void:
	var chasing: Array = []
	for c in creatures:
		var ai = c.get("ai")
		if ai and is_instance_valid(ai) and String(ai.state) == "CHASE":
			chasing.append(c)
	if chasing.size() < 2:
		return
	chasing.sort_custom(func(a, b): return String(a.get("role", "")) == "hunter" and String(b.get("role", "")) != "hunter")
	for i in range(1, chasing.size()):
		_leave(chasing[i], "a second creature found the player: only one hunts at a time")


func _pick_kind(lv: int) -> String:
	var r := randf()
	match lv:
		1:
			return "hound"
		2:
			return "skitter" if r < 0.45 else "hound"
	if r < 0.35:
		return "crab"
	return "skitter" if r < 0.7 else "hound"


## A roamer already about becomes the hunter (closer, and the player may have glimpsed it already).
func _promote_roamer(tgt: Vector3) -> bool:
	for c in creatures:
		if String(c.get("role", "")) == "roamer" and c.get("ai") and is_instance_valid(c["ai"]) \
				and (c["node"] as Node3D).global_position.distance_to(tgt) < 70.0:
			c["role"] = "hunter"
			c["born_el"] = float(st().get("elapsed", 0.0))
			_dbg("roamer %s promoted to hunter (%.1f m off)" % [c["kind"], (c["node"] as Node3D).global_position.distance_to(tgt)])
			return true
	return false


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


## Kept for older callers / tests: one encounter now (a hunter at this level).
func encounter(lv: int) -> bool:
	_prune()
	if lv <= 0 or creatures.size() >= int(cfg.get("max_dynamic_creatures", 2)) or emergency():
		return false
	if _role_count("hunter") > 0:
		return _spawn_creature("hound", "roamer", threat_target())
	return _spawn_creature(_pick_kind(lv), "hunter", threat_target())


## A believable entry point: outdoors, open ground the creature can stand and move on, out of the camera's view,
## dmin..dmax from `around` (the threat target), never inside the store or a house, never boxed in. The ground
## must be street level: compared with the lowest open ground near `around` (the player may be upstairs).
func find_spawn(dmin: float, dmax: float, around := Vector3.INF) -> Vector3:
	var p: Vector3 = around if around.is_finite() else threat_target()
	var cam := get_viewport().get_camera_3d()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var exl: Array[RID] = [_player().get_rid()]
	if world.sedan:
		exl.append(world.sedan.get_rid())
	var ref := p.y
	for a in [0.0, 1.57, 3.14, 4.71]:
		var s := p + Vector3(cos(a), 0, sin(a)) * 12.0
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(s + Vector3(0, 20, 0), s - Vector3(0, 10, 0), 1, exl))
		if h:
			ref = minf(ref, (h["position"] as Vector3).y)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	var why := {}
	for i in 32:
		var a := randf() * TAU
		var d := randf_range(dmin, dmax)
		var c := p + Vector3(cos(a), 0.0, sin(a)) * d
		if cam and cam.is_position_in_frustum(c + Vector3(0, 1.0, 0)) and c.distance_to(cam.global_position) < 60.0:
			why["in_view"] = int(why.get("in_view", 0)) + 1
			continue
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 20, 0), c - Vector3(0, 10, 0), 1, exl))
		if hit.is_empty():
			why["no_ground"] = int(why.get("no_ground", 0)) + 1
			continue
		var g: Vector3 = hit["position"]
		if absf(g.y - ref) > 1.2:
			why["not_street_level"] = int(why.get("not_street_level", 0)) + 1
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(0, 1.0, 0), g + Vector3(0, 14, 0), 1, exl)).is_empty():
			why["under_roof"] = int(why.get("under_roof", 0)) + 1
			continue
		var c5 := _c5()
		if c5 and c5._in_store(world.market.to_local(g), -1.0):
			why["in_store"] = int(why.get("in_store", 0)) + 1
			continue
		q.transform = Transform3D(Basis(), g + Vector3(0, 1.0, 0))
		if not space.intersect_shape(q, 1).is_empty():
			why["no_room"] = int(why.get("no_room", 0)) + 1
			continue
		# not boxed in (a yard behind fences, between parked cars): at least three ways out of four are open
		var open := 0
		for k in 4:
			var dir := Vector3(cos(k * PI * 0.5), 0, sin(k * PI * 0.5))
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(0, 0.8, 0), g + Vector3(0, 0.8, 0) + dir * 4.0, 1, exl)).is_empty():
				open += 1
		if open < 3:
			why["boxed_in"] = int(why.get("boxed_in", 0)) + 1
			continue
		return g
	_dbg("spawn rejected (32 tries around %s, %.0f-%.0f m): %s" % [_v(p), dmin, dmax, str(why)])
	return Vector3.INF


## One creature of `kind` ("hound", "skitter", "crab") with a role, at a valid spot round `tgt`.
func _spawn_creature(kind: String, role: String, tgt: Vector3) -> bool:
	var sd: Array = cfg.get("spawn_distance", [26, 40])
	var at := find_spawn(float(sd[0]), float(sd[1]), tgt)
	if not at.is_finite():
		return false
	var ai: Node
	if kind == "hound":
		var h := (load(HOUND_PATH) as PackedScene).instantiate() as CharacterBody3D
		h.name = "EXP_Hound"
		world.add_child(h)
		h.global_position = at
		VeilCreatureLook.apply_skitter(h, at.y)
		ai = HOUND_AI.new()
		ai.name = "AI"
		h.add_child(ai)
		ai.leash = 70.0
		ai.setup(h, _player(), [at])
		_hook_struggle(ai, "hound")
		report["hounds"] += 1
	else:
		ai = make_hunter(kind, at, [at], 70.0)
		if ai == null:
			return false
		if kind == "skitter":
			report["skitters"] += 1
	var body: Node3D = ai.body
	var el := float(st().get("elapsed", 0.0))
	if role == "roamer":
		# it crosses open ground between the player's area and where it came in (often seen or heard in the fog)
		var mid := at.lerp(tgt, 0.45)
		var side := (tgt - at).normalized().cross(Vector3.UP) * 9.0
		ai.patrol = [at, mid + side, mid - side]
		ai.home = mid
		ai.leash = 40.0
		ai.state = "PATROL"
		ai.set("_target", mid + side)
	else:
		ai.set("_last_seen", tgt)
		ai.state = "SUSPICIOUS"
		ai.set("awareness", 0.6)
	creatures.append({"node": body, "ai": ai, "kind": kind, "role": role, "exit": at, "born_el": el, "born": Game.play_time,
		"ref": body.global_position, "ref_t": 0.0})
	report["spawned"] += 1
	report["max_active"] = maxi(int(report["max_active"]), creatures.size())
	_play("bark" if kind == "hound" else kind, at + Vector3(0, 0.8, 0), -6.0)
	_dbg("SPAWN %s as %s at %s, %.1f m from the target %s" % [kind, role, _v(at), at.distance_to(tgt), _v(tgt)])
	return true


## Off it goes: towards a point well away from the player, removed once far off and out of view.
func _leave(c: Dictionary, why: String) -> void:
	if String(c.get("role", "")) == "leaving":
		return
	c["role"] = "leaving"
	c["leave_why"] = why
	var ai = c.get("ai")
	var b: Node3D = c["node"]
	if ai and is_instance_valid(ai) and is_instance_valid(b):
		var away := (b.global_position - threat_target()) * Vector3(1, 0, 1)
		away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		ai.home = b.global_position + away * 40.0
		ai.leash = 999.0
		ai.state = "RETURN"
		ai.set("awareness", 0.0)
	if why.begins_with("hunter"):                          # a breather before the next one comes
		_next_hunt = maxf(_next_hunt, float(st().get("elapsed", 0.0)) + _lvv("encounter_cooldown_s", level(), [60, 50, 40, 30, 22]) * 0.5)
	_dbg("LEAVING %s: %s" % [c["kind"], why])


# ------------------------------------------------------------------ the dynamic Tentacle
## CRITICAL and up: a rumble, the ground cracks a few metres off (in sight: it is meant to be seen and avoided),
## the tentacle bursts up, lashes once or twice (the existing Tentacle AI: a readable coil, a locked strike), then
## sinks back. Never during story scenes, never in the car, never in a house or the store; one at a time.
func _spawn_tentacle() -> bool:
	var p := _player().global_position
	if not _outdoors_at(p) or world.get("_tentacles") is Array and not (world.get("_tentacles") as Array).is_empty():
		return false
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var fwd := -_player().global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := Vector3.INF
	for i in 16:
		var c := p + fwd.rotated(Vector3.UP, randf_range(-1.0, 1.0)) * randf_range(6.5, 9.5)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 6, 0), c - Vector3(0, 6, 0), 1, [_player().get_rid()]))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - p.y) > 0.6 or (hit["normal"] as Vector3).y < 0.9:
			continue
		var g: Vector3 = hit["position"]
		if not _outdoors_at(g):
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var cs := CapsuleShape3D.new()
		cs.radius = 1.0
		cs.height = 3.0
		q.shape = cs
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), g + Vector3(0, 1.7, 0))
		if not space.intersect_shape(q, 1).is_empty():
			continue
		at = g
		break
	if not at.is_finite():
		_dbg("tentacle: no clear ground ahead of the player")
		return false
	_tentacle = Node3D.new()                              # (holds the slot while it rumbles)
	_tentacle.name = "EXP_TentacleSlot"
	world.add_child(_tentacle)
	_tentacle_rise(at)
	return true


func _tentacle_rise(at: Vector3) -> void:
	var slot := _tentacle
	Sfx.play("veil_rumble", at + Vector3(0, 0.3, 0), 2.0, 1.2)
	_dbg("TENTACLE rumble at %s" % _v(at))
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(slot) or emergency() or not active():
		if is_instance_valid(slot):
			slot.queue_free()
		return
	if world.has_method("_ground_burst"):
		world._ground_burst(at)
	var t := (load(world.TENTACLE_PATH) as PackedScene).instantiate() as Node3D
	t.name = "EXP_Tentacle"
	world.add_child(t)
	t.global_position = at
	t.rotation.y = atan2(_player().global_position.x - at.x, _player().global_position.z - at.z)
	var ai: Node = world.TENTACLE_AI.new()
	ai.name = "AI"
	t.add_child(ai)
	ai.target = _player()
	ai.detect_range = 6.5
	ai.lose_range = 99.0                                  # (it never goes on its own: it sinks when its time is up)
	ai.struck.connect(func(tn: Node3D, dmg: float) -> void:
		var hp := float(_player().get("health"))
		_player().damage(minf(dmg, maxf(hp - 5.0, 0.0)), tn.global_position)
		Sfx.play("tentacle_hiss", tn.global_position + Vector3(0, 1, 0), 0.0))
	if t.has_method("emerge"):
		t.emerge()
	slot.queue_free()
	_tentacle = t
	report["tentacles"] = int(report.get("tentacles", 0)) + 1
	_dbg("TENTACLE up at %s, %.1f m from the player" % [_v(at), at.distance_to(_player().global_position)])
	await get_tree().create_timer(9.0).timeout
	if not is_instance_valid(t):
		return
	ai.state = "hidden"
	ai.emerge_range = -1.0
	ai._play("Retract")
	Sfx.bank_at("te_retreat", at + Vector3(0, 1.0, 0), -4.0, 6.0)
	_dbg("TENTACLE retreats")
	await get_tree().create_timer(2.2).timeout
	if is_instance_valid(t):
		t.queue_free()
	_tentacle = null


func _on_level(lv: int) -> void:
	report["level_%d" % lv] = true
	var hurry: Array = cfg.get("follower_hurry", [1.0, 1.1, 1.25, 1.4])
	for f in _followers():
		var fol := f as VeilCompanionFollow
		if not fol.has_meta("exp_walk"):
			fol.set_meta("exp_walk", fol.walk_speed)
		fol.walk_speed = float(fol.get_meta("exp_walk")) * float(hurry[lv])
	if lv >= 1:
		warn(lv)
	if lv >= 2:
		world.hud.location_caption("DANGER: " + String(cfg.get("level_names", ["", "", "HIGH", "CRITICAL"])[lv]) + "  -  get back to the shelter", 2.5)


## A short warning from someone actually walking with the player (or the protagonist alone); never during talks.
func warn(lv: int) -> void:
	if _warn_t > 0.0 or Dialogue.is_busy() or world.conversing:
		return
	var present := []
	for f in _followers():
		present.append(String(f.npc.name))
	var id := ""
	match lv:
		1:
			for k in ["Eddie", "Ruth"]:
				if k in present:
					id = "exp_warn1_" + k
					break
		2:
			for k in ["Marcus", "Sarah"]:
				if k in present:
					id = "exp_warn2_" + k
					break
			if id == "":
				id = "exp_warn2_alone"
		_:
			id = "exp_warn3_Eddie" if "Eddie" in present else "exp_warn3_alone"
	if id != "":
		_warn_t = float(cfg.get("warning_cooldown_s", 75))      # the cooldown starts only when someone spoke
		report["warnings"] += 1
		report["last_warning"] = id
		Dialogue.say(id, false, false)


func _distant_sound(lv: int) -> void:
	var p := _player().global_position
	var d := lerpf(60.0, 22.0, float(lv) / 3.0)
	var a := randf() * TAU
	var pool := ["bark", "bark", "ev_metal", "ev_window", "ev_roof"]
	if lv >= 1:
		pool += ["skitter", "ev_unknown"]
	if lv >= 2:
		pool += ["co_distant", "ev_unknown"]
	_play(String(pool[randi() % pool.size()]), p + Vector3(cos(a), 0.0, sin(a)) * d + Vector3(0, 1.5, 0), -6.0 + 2.0 * lv, 40.0)


## A hunting Skitter or Shellcrawler: the Hound's AI with the creature's own clips and pace (the Shellcrawler
## crawls sideways, slower, harder hitting). Out of view, on open ground, a fair way off.
func _spawn_hunter(kind: String) -> bool:
	return _spawn_creature(kind, "hunter", threat_target())


## (older callers / tests) a Hound: level 0 a roamer, otherwise the hunter.
func _spawn_hound(lv: int) -> bool:
	return _spawn_creature("hound", "roamer" if lv <= 0 else "hunter", threat_target())


## A Skitter or Shellcrawler with the Hound's AI, its own clips and pace, at `at` with a patrol and a leash (the
## dynamic hunters above; the car-part guard in car_quest.gd). Returns the AI (its .body is the creature) or null.
func make_hunter(kind: String, at: Vector3, points: Array, leash: float) -> Node:
	var ps := load(SKITTER_PATH if kind == "skitter" else CRAB_PATH) as PackedScene
	if ps == null:
		return null
	var c := ps.instantiate() as CharacterBody3D
	if c == null:
		return null
	c.name = "EXP_" + kind.capitalize()
	world.add_child(c)
	c.global_position = at
	if kind == "skitter":
		VeilCreatureLook.apply_skitter(c, at.y)
	else:
		VeilCreatureLook.apply_ground(c, at.y)
	var ai: Node = HOUND_AI.new()
	ai.name = "AI"
	c.add_child(ai)
	ai.sound_kind = kind
	if kind == "skitter":
		ai.clip_map = {"Walk": "Crawl", "Run": "Scuttle_Fast", "Alert": "Alert", "Attack_Bite": "Attack_Lunge"}
		ai.native = {"Crawl": 1.2, "Scuttle_Fast": 5.0}
		ai.walk_speed = 1.8
		ai.chase_speed = 4.0
		ai.bite_damage = 12.0
		ai.sight_range = 13.0
		ai.jaw_offset = 0.45
		ai.bite_range = 1.5
	else:
		ai.clip_map = {"Walk": "Crawl_Sideways", "Run": "Crawl_Sideways", "Forward": "Crawl_Forward", "Alert": "Defend", "Attack_Bite": "Attack_Grasp"}
		# the clips' real stride speeds (CRT_Shellcrawler metadata): the legs keep up with the ground
		ai.native = {"Crawl_Sideways": 0.536, "Crawl_Forward": 0.363}
		ai.clip_cap = 7.0
		ai.walk_speed = 1.0
		ai.chase_speed = 2.4
		ai.steer_around = true
		ai.body_half_width = 0.9
		ai.bite_damage = 26.0
		ai.bite_cooldown = 2.6
		ai.sight_range = 12.0
		ai.jaw_offset = 0.0
		ai.bite_range = 2.1
		ai.face_offset = PI * 0.5
		ai.turn_rate = 0.07
		ai.burst = true
	ai.leash = leash
	ai.setup(c, _player(), points)
	if kind == "crab":
		var shape := c.get_node_or_null("AIShape") as CollisionShape3D
		if shape and shape.shape is CapsuleShape3D:
			(shape.shape as CapsuleShape3D).radius = 0.95      # its real width: the legs stay out of the walls
			(shape.shape as CapsuleShape3D).height = 1.9
			shape.position = Vector3(0, 1.05, 0)
	if ai.anim:
		for clip in ai.clip_map.values():
			if ai.anim.has_animation(clip) and clip != "Attack_Lunge" and clip != "Attack_Grasp" and clip != "Defend":
				ai.anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_hook_struggle(ai, kind)
	return ai


## One shared struggle controller (game/encounters/struggle.gd): a creature's attack may become a struggle.
func _hook_struggle(ai: Node, kind: String) -> void:
	var s := world.get_node_or_null("Struggle")
	if s == null:
		s = STRUGGLE.new()
		s.name = "Struggle"
		world.add_child(s)
		s.setup(world)
	ai.set_meta("struggle_kind", kind)
	ai.on_attack = Callable(s, "try_start")


func _spawn_skitter() -> bool:
	var at := find_spawn(22.0, 34.0)
	if not at.is_finite():
		return false
	var ps := load(SKITTER_PATH) as PackedScene
	if ps == null:
		return false
	var sk := ps.instantiate() as Node3D
	sk.name = "EXP_Skitter"
	world.add_child(sk)
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
		(sk as CollisionObject3D).collision_mask = 0
	sk.set_physics_process(false)
	sk.global_position = at
	VeilCreatureLook.apply_skitter(sk, at.y)
	# it scuttles across, at a distance, then away (a sighting; it does not attack)
	var to_p := (_player().global_position - at) * Vector3(1, 0, 1)
	var side := to_p.normalized().cross(Vector3.UP)
	var end := at + side * randf_range(18.0, 26.0) * (1.0 if randf() < 0.5 else -1.0) - to_p.normalized() * 6.0
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(end + Vector3(0, 20, 0), end - Vector3(0, 10, 0), 1))
	if hit:
		end.y = (hit["position"] as Vector3).y
	sk.rotation.y = atan2(end.x - at.x, end.z - at.z)
	VeilCreatureLook.skitter_anim(sk, "scuttle", 7.0)
	var tw := sk.create_tween()
	tw.tween_property(sk, "global_position", end, at.distance_to(end) / 7.0)
	creatures.append({"node": sk, "ai": null, "kind": "skitter", "exit": end})
	report["spawned"] += 1
	report["skitters"] += 1
	report["max_active"] = maxi(int(report["max_active"]), creatures.size())
	_play("skitter", at + Vector3(0, 0.5, 0), -4.0)
	return true


## A scripted sighting for the story chapters: a Skitter scuttles from `from` to `to` (world, ground) and is
## removed only once out of view. Not counted against the dynamic budget (story encounters take priority).
func skitter_crossing(from: Vector3, to: Vector3, speed := 7.5) -> Node3D:
	var ps := load(SKITTER_PATH) as PackedScene
	if ps == null:
		return null
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var h1: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3(0, 20, 0), from - Vector3(0, 10, 0), 1))
	if h1:
		from.y = (h1["position"] as Vector3).y
	var h2: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3(0, 20, 0), to - Vector3(0, 10, 0), 1))
	if h2:
		to.y = (h2["position"] as Vector3).y
	var sk := ps.instantiate() as Node3D
	sk.name = "Story_Skitter"
	world.add_child(sk)
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
		(sk as CollisionObject3D).collision_mask = 0
	sk.set_physics_process(false)
	sk.global_position = from
	VeilCreatureLook.apply_skitter(sk, from.y)
	sk.rotation.y = atan2(to.x - from.x, to.z - from.z)
	VeilCreatureLook.skitter_anim(sk, "scuttle", speed)
	_play("skitter", from + Vector3(0, 0.5, 0), -2.0)
	var tw := sk.create_tween()
	tw.tween_property(sk, "global_position", to, from.distance_to(to) / speed)
	tw.tween_callback(func(): creatures.append({"node": sk, "ai": null, "kind": "skitter", "exit": to}))
	return sk


## Creatures are removed only when they are really gone: leaving (moved on, gave up, driven off, the trip over) AND
## far from the player AND out of view; or stuck where they cannot reach anyone (no progress for 12 s while trying
## to move, out of view); or fallen out of the world. Every removal is logged with its reason.
func _prune() -> void:
	var cam := get_viewport().get_camera_3d()
	var tgt := threat_target()
	var keep := []
	for c in creatures:
		var n: Node3D = c["node"]
		if not is_instance_valid(n):
			continue
		var ai = c.get("ai")
		var unseen := cam == null or not cam.is_position_in_frustum(n.global_position + Vector3(0, 0.6, 0))
		var d := n.global_position.distance_to(tgt)
		var why := ""
		if ai == null:
			# a scripted sighting (skitter_crossing / glimpse): gone once at its end point and out of view
			if n.global_position.distance_to(c["exit"]) < 0.5 and unseen:
				why = "sighting finished"
		else:
			if not active() and String(c.get("role", "")) != "leaving":
				_leave(c, "trip over")
			if n.global_position.y < -20.0:
				why = "fell out of the world"
			elif String(c.get("role", "")) == "leaving" and d > 32.0 and unseen:
				why = "left: " + String(c.get("leave_why", ""))
			elif d > 160.0 and unseen:
				why = "far behind (player drove off)"
			else:
				# progress check: trying to move but not getting anywhere = stuck
				var moving: bool = String(ai.state) in ["SUSPICIOUS", "CHASE", "RETURN", "SEARCH", "INVESTIGATE"] \
					and Vector2(n.global_position.x - Vector3(ai.get("_last_seen")).x, n.global_position.z - Vector3(ai.get("_last_seen")).z).length() > 3.0
				c["ref_t"] = float(c.get("ref_t", 0.0)) + 0.25
				if c["ref_t"] >= 12.0:
					var progressed: bool = n.global_position.distance_to(c.get("ref", n.global_position)) > 1.0
					c["ref"] = n.global_position
					c["ref_t"] = 0.0
					if moving and not progressed and unseen and d > 10.0:
						why = "stuck (no progress in 12 s)"
		if why == "" and ai != null and _in_shelter(n.global_position):
			# never inside the shelter: it turns back out of the doors; if out of sight in there, it is simply gone
			if unseen:
				why = "got into the shelter (removed unseen)"
			elif String(ai.state) != "RETURN":
				ai.state = "RETURN"
				ai.home = world.market.global_transform * Vector3(0.0, 0.0, -8.0)
				ai.leash = 999.0
				report["turned_out_of_shelter"] = int(report.get("turned_out_of_shelter", 0)) + 1
		if why != "":
			report["despawned_unseen"] += 1
			_dbg("REMOVED %s (%s): %s at %s, %.1f m from the player" % [c["kind"], c.get("role", "-"), why, _v(n.global_position), d])
			n.queue_free()
			continue
		keep.append(c)
	creatures = keep


# ------------------------------------------------------------------ per tick
## The other explorable houses (game/data/scavenge_houses.json, "daily"): opened once the supply rule starts,
## real furniture with supplies inside its cabinets / fridge / drawers, refilled each new day (game/world/
## scavenge_house.gd). The cottage (HOUSE_04) stays Chapter 5's own.
const SCAV_HOUSE := preload("res://game/world/scavenge_house.gd")
var houses: Dictionary = {}


func _open_houses() -> void:
	if not houses.is_empty() or not Game.has_flag("c5_started"):
		return
	var specs: Dictionary = SCAV_HOUSE.load_specs()
	for z in specs.get("houses", {}):
		var sp: Dictionary = specs["houses"][z]
		if not sp.get("daily", false):
			continue
		var h := world.find_child(String(z), true, false) as Node3D
		if h == null:
			continue
		var sh = SCAV_HOUSE.new()
		add_child(sh)
		if sh.setup(world, h, sp, specs):
			houses[z] = sh
			_near_only(h, 45.0)
		else:
			sh.queue_free()
	houses["_done"] = null


func _process(delta: float) -> void:
	if world.sedan:
		world.sedan.survival = Game.has_flag("vehicle_repaired")   # fuel and wear only once it runs again
	if story_departure:
		if not in_store():
			_story_out = true
		elif _story_out:
			story_departure = false              # back inside after the story trip: the doors are held again
	if houses.is_empty():
		_open_houses()
	_danger(delta)
	var indoors: bool = shelter() == "supermarket" and in_store()
	Sfx.set_ambience_area(indoors)
	Sfx.danger_level = level() if active() and not indoors else 0
	if _today() != _day:
		_day = _today()
		_spawn_caches()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	if not _props_placed and Game.has_flag("c5_started"):
		_props_placed = true                             # (the wrecks: not in the ordinary town of the opening)
		if not Game.has_flag("ch9_supermarket_lost"):
			quest.place()
	_prune()
	_guard_doors()
	_shelter_ward()
	_supply_chest_marker()
	if active():
		if _warn_t <= 0.0 and level() >= 1 and _clock_running():
			warn(level())
		# back inside with the doors shut by anyone (the story, an old save): the trip is over
		var c5 := _c5()
		if not in_store():
			st()["went_out"] = true
		if c5 and bool(st().get("went_out", false)) and in_store() and not c5._doors_open:
			_closed_t += 0.25
			if _closed_t > 3.0:
				secure()
		else:
			_closed_t = 0.0
	_refresh()


func _refresh() -> void:
	_discover_parts()
	_part_markers()
	if world.sedan and world.sedan.get("entry_area"):
		var dead: bool = Game.has_flag("c5_started") and shelter() != "" and Game.has_flag("groceries_done") \
			and Game.has_flag("game_bought") and not Game.has_flag("vehicle_repaired")
		var stopped: bool = Game.has_flag("vehicle_repaired") and world.sedan.survival and not world.sedan.drivable()
		world.sedan.entry_area.prompt_text = "[E] Inspect Vehicle" if dead or stopped else "[E] Enter Vehicle"
	var c5 := _c5()
	for d in _story_doors():
		if not (d as Interactable).redirect.is_valid():
			(d as Interactable).redirect = _door_redirect
	var e: Interactable = its.get("exit")
	if e:
		var t := ""
		if active() and in_store():
			t = "[E] Secure the Doors"
		elif can_scavenge() and not story_departure and _menu_allowed():
			t = "[E] Leave Shelter"
		e.prompt_text = t
		e.collision_layer = 8 if t != "" else 0
	var o: Interactable = its.get("outside")
	if o:
		var on: bool = active() and c5 != null and not c5._doors_open
		o.prompt_text = "[E] Open the Doors" if on else ""
		o.collision_layer = 8 if on else 0


func _hint(t: String) -> void:
	if world.hud.has_method("set_hint"):
		world.hud.set_hint(t)
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(world) and world.hud.hint.text == t:
				world.hud.set_hint(""))


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


func _play(id: String, at: Vector3, db := 0.0, unit := 14.0) -> void:
	if _streams.get(id) == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	p.unit_size = unit
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()



## The furniture, fittings and finds inside an explorable house are only drawn near it (the walls hide them anyway):
## two dozen furnished houses otherwise added ~1,100 draw calls to every frame after the first night.
static func _near_only(h: Node3D, metres: float) -> void:
	for g in h.find_children("*", "GeometryInstance3D", true, false):
		var nm := String(g.name)
		if nm.contains("Exterior") or nm.begins_with("INT_Door") or nm.begins_with("INT_GarageDoor") or nm.contains("Roof"):
			continue
		var gi := g as GeometryInstance3D
		if gi.visibility_range_end <= 0.0 or gi.visibility_range_end > metres:
			gi.visibility_range_end = metres
			gi.visibility_range_end_margin = 4.0
