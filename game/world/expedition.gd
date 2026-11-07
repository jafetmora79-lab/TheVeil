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
	_streams["bark"] = Sfx._make(0.7, _bark_wave)
	_streams["skitter"] = Sfx._make(1.2, _scuttle_wave)
	var m: Node3D = world.market
	its["exit"] = _spot("EXP_PlanTrip", m.global_transform * EXIT_SPOT, Vector3(1.6, 1.6, 0.4), _use_exit, m.global_transform.basis)
	its["outside"] = _spot("EXP_OpenDoors", m.global_transform * OUTSIDE_SPOT, Vector3(3.0, 2.2, 0.6), _use_outside, m.global_transform.basis)
	_place_supply_chest(m)
	_day = _today()
	_spawn_caches()
	for c in cfg.get("vehicle_parts", []):
		_cache(c, "exp/part_" + String(c["id"]), String(c["item"]), "", String(c["model"]), float(c.get("scale", 1.0)))
	VeilRestPoint.supply_gate = sleep_gate
	# between story nights the shelter can wait out a day (supermarket era): supplies eaten, a new day in town
	VeilRestPoint.extra_night = _extra_night_ok
	VeilRestPoint.record_extra = _record_extra
	_encounter_t = float(cfg.get("encounter_cooldown_s", [999, 150])[1])   # a load never starts with an encounter
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
func emergency() -> bool:
	if Game.has_flag("ch8_attack_started") and not Game.has_flag("ch8_entrance_secured"):
		return true
	if Game.has_flag("ch9_warning_started") and not Game.has_flag("ch9_escaped"):
		return true
	if world.get("_encounter_running") == true or world.conversing:
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
	var p := _player()
	if p == null or world.hud.is_paused() or world.hud.inv_panel.visible:
		return false
	if world.conversing or world.get("_encounter_running") == true or Dialogue.confirm_mode:
		return false
	if world.in_car:
		return true
	return p.visible and p.controls_enabled and not in_store()


# ------------------------------------------------------------------ the shelter exit
func _use_exit(_b: Node) -> void:
	if active():
		if in_store():
			secure()
		return
	if not can_scavenge() or _busy_menu:
		return
	_busy_menu = true
	var p4 := _p4()
	var opts := ["Continue Story - " + String(Game.current_step().get("text", "")), "Scavenge for Supplies"]
	var ids := ["story", "scavenge"]
	if Game.has_flag("vehicle_repaired"):
		opts.append("Use the Car")
		ids.append("car")
	opts.append("Stay Inside")
	ids.append("stay")
	var i: int = await p4.choice.ask("WHERE ARE YOU HEADING?", opts, _player())
	var pick: String = ids[clampi(i, 0, ids.size() - 1)] if i >= 0 else "stay"
	if pick == "car":
		var j: int = await p4.choice.ask("What is the trip for?", ["Supplies", "The Story", "Cancel"], _player())
		pick = ["scavenge_car", "story", "stay"][clampi(j, 0, 2)] if j >= 0 else "stay"
	_busy_menu = false
	match pick:
		"story":
			# the story's own exit and objective take it from here (nothing is restarted or skipped)
			_hint("Objective: " + String(Game.current_step().get("text", "")))
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
			start("scavenge", true)


var _busy_menu := false


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
	s["went_out"] = false
	s["started_at"] = Game.play_time
	_encounter_t = float(cfg.get("encounter_cooldown_s", [999, 150])[1])
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


## The shelter supplies get a real chest (from Cline's local fix): the storage chest model where the supplies are
## kept. Visual only (no collision, no interaction of its own): the existing "[E] Shelter Supplies" point there
## opens the supplies, so nothing competes with it or blocks it.
func _place_supply_chest(market: Node3D) -> void:
	var ps := load("res://THE_VEIL_ASSETS_V2/03_Residential/Interactive_Props/RES_IP_StorageChest.glb") as PackedScene
	if ps == null:
		return
	var chest := ps.instantiate() as Node3D
	chest.name = "EXP_SupplyChest"
	market.add_child(chest)
	chest.global_position = market.global_transform * Vector3(7.8, 0.04, 6.05)
	for co in chest.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
		(co as CollisionObject3D).collision_mask = 0


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
		_hint("GET THE VEHICLE RUNNING: a battery, fuel and a fuse.")
		return true
	var missing := []
	for k in [["car_battery", "a battery"], ["fuel_can", "fuel"], ["car_fuse", "a fuse"]]:
		if not Game.has_item(k[0]):
			missing.append(k[1])
	if not missing.is_empty():
		_hint("Still needed for the car: " + ", ".join(missing) + ".")
		return true
	_repair()
	return true


func _repair() -> void:
	if Game.has_flag("vehicle_repaired") or _repairing:
		return
	_repairing = true
	var p := _player()
	p.set("controls_enabled", false)
	p.velocity = Vector3.ZERO
	var at: Vector3 = world.sedan.global_position + Vector3(0, 0.8, 0)
	for k in 3:
		Sfx.play("door_close", at, -8.0, 0.6 + 0.1 * k)
		await get_tree().create_timer(0.7).timeout
	for k in ["car_battery", "fuel_can", "car_fuse"]:
		Game.remove_item(k)
	Game.set_flag("vehicle_repaired")              # set with the parts used: never repaired (or rewarded) twice
	Dialogue.say("exp_car_running", false, true)
	_hint("The car runs again. E at the driver's door to get in.")
	p.set("controls_enabled", true)
	_repairing = false
	_refresh()


var _repairing := false


# ------------------------------------------------------------------ danger, encounters, warnings
func _followers() -> Array:
	var out := []
	for n in world.find_children("*", "Node", true, false):
		if n is VeilCompanionFollow and (n as VeilCompanionFollow).active and (n as VeilCompanionFollow).npc \
				and (n as VeilCompanionFollow).npc.is_visible_in_tree():
			out.append(n)
	return out


func _danger(delta: float) -> void:
	if not active() or not _clock_running():
		return
	var s := st()
	var scale: float = float(cfg.get("driving_time_scale", 0.6)) if world.in_car else 1.0
	s["elapsed"] = float(s["elapsed"]) + delta * scale
	var th: Array = cfg.get("danger_thresholds_s", [300, 600, 900])
	var lv := 0
	for t in th:
		if float(s["elapsed"]) >= float(t):
			lv += 1
	if lv != int(s["level"]):
		s["level"] = lv
		_on_level(lv)
	# sounds: more often, and closer, as it gets worse
	_sound_t -= delta
	if _sound_t <= 0.0:
		_sound_t = float(cfg.get("sound_interval_s", [55, 35, 22, 14])[lv]) * randf_range(0.7, 1.3)
		_distant_sound(lv)
	# encounters: a cooldown, a chance, a cap
	_encounter_t -= delta
	if _encounter_t <= 0.0 and lv >= 1:
		_encounter_t = float(cfg.get("encounter_cooldown_s", [999, 150, 90, 50])[lv])
		if randf() < float(cfg.get("encounter_chance", [0, 0.35, 0.6, 0.85])[lv]) and not world.in_car:
			encounter(lv)
	# warnings
	_warn_t -= delta


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
	_play("bark" if randf() < 0.5 else "skitter", p + Vector3(cos(a), 0.0, sin(a)) * d + Vector3(0, 1.5, 0), -16.0 + 3.0 * lv)


## One dynamic encounter: a Skitter glimpsed in the fog, or a Hound coming in from open ground (HIGH and up).
func encounter(lv: int) -> bool:
	_prune()
	if creatures.size() >= int(cfg.get("max_dynamic_creatures", 2)) or emergency():
		return false
	var hound := lv >= int(cfg.get("hound_from_level", 2)) and randf() < (0.5 if lv == 2 else 0.75)
	return _spawn_hound(lv) if hound else _spawn_skitter()


## A believable entry point: outdoors, open ground the creature can stand on and move from, out of the camera's
## view, a fair distance off, never inside the store.
func find_spawn(dmin: float, dmax: float) -> Vector3:
	var p := _player().global_position
	var cam := get_viewport().get_camera_3d()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	for i in 24:
		var a := randf() * TAU
		var d := randf_range(dmin, dmax)
		var c := p + Vector3(cos(a), 0.0, sin(a)) * d
		if cam and cam.is_position_in_frustum(c + Vector3(0, 1.0, 0)):
			continue
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 20, 0), c - Vector3(0, 10, 0), 1))
		if hit.is_empty():
			continue
		var g: Vector3 = hit["position"]
		if absf(g.y - p.y) > 1.6:
			continue                                  # a roof or a hole, not ground
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(0, 1.0, 0), g + Vector3(0, 14, 0), 1)).is_empty():
			continue                                  # under a roof: indoors
		var c5 := _c5()
		if c5 and c5._in_store(world.market.to_local(g), -1.0):
			continue
		q.transform = Transform3D(Basis(), g + Vector3(0, 1.0, 0))
		if not space.intersect_shape(q, 1).is_empty():
			continue                                  # no room to stand
		return g
	return Vector3.INF


func _spawn_hound(lv: int) -> bool:
	var at := find_spawn(float(cfg.get("spawn_distance", [34, 46])[0]), float(cfg.get("spawn_distance", [34, 46])[1]))
	if not at.is_finite():
		return false
	var h := (load(HOUND_PATH) as PackedScene).instantiate() as Node3D
	h.name = "EXP_Hound"
	world.add_child(h)
	h.global_position = at
	VeilCreatureLook.apply_skitter(h, at.y)
	var ai: Node = HOUND_AI.new()
	ai.name = "AI"
	h.add_child(ai)
	ai.leash = 70.0
	ai.setup(h, _player(), [at, at + (at - _player().global_position).normalized() * 6.0])
	# it heard something: it comes to look (and at CRITICAL it is already hunting)
	ai.set("_last_seen", _player().global_position)
	ai.state = "SUSPICIOUS"
	ai.set("awareness", 0.5 if lv < 3 else 0.95)
	creatures.append({"node": h, "ai": ai, "kind": "hound", "exit": at})
	report["spawned"] += 1
	report["hounds"] += 1
	report["max_active"] = maxi(int(report["max_active"]), creatures.size())
	_play("bark", at + Vector3(0, 1.0, 0), -6.0)
	return true


func _spawn_skitter() -> bool:
	var at := find_spawn(26.0, 36.0)
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


## Creatures leave the way they came and are removed only out of view (no pop-out in front of the player).
func _prune() -> void:
	var cam := get_viewport().get_camera_3d()
	var keep := []
	for c in creatures:
		var n: Node3D = c["node"]
		if not is_instance_valid(n):
			continue
		var gone_away := false
		if c["kind"] == "skitter":
			gone_away = n.global_position.distance_to(c["exit"]) < 0.5
		else:
			var ai = c["ai"]
			if not active() or (ai and ai.state in ["RETURN", "PATROL"] and n.global_position.distance_to(_player().global_position) > 25.0):
				if ai and ai.state != "RETURN":
					ai.state = "RETURN"
				gone_away = n.global_position.distance_to(c["exit"]) < 3.0 or n.global_position.distance_to(_player().global_position) > 45.0
		var unseen := cam == null or not cam.is_position_in_frustum(n.global_position + Vector3(0, 0.6, 0))
		if gone_away and unseen:
			report["despawned_unseen"] += 1
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
		else:
			sh.queue_free()
	houses["_done"] = null


func _process(delta: float) -> void:
	if houses.is_empty():
		_open_houses()
	_danger(delta)
	if _today() != _day:
		_day = _today()
		_spawn_caches()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_prune()
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
	var c5 := _c5()
	var e: Interactable = its.get("exit")
	if e:
		var t := ""
		if active() and in_store():
			t = "[E] Secure the Doors"
		elif can_scavenge():
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


func _play(id: String, at: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	p.unit_size = 14.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


func _bark_wave(t: float, i: int) -> float:
	var env := exp(-t * 7.0) * clampf(t * 60.0, 0.0, 1.0)
	return (sin(TAU * (220.0 - t * 160.0) * t) * 0.6 + Sfx._noise(i) * 0.35) * env


func _scuttle_wave(t: float, i: int) -> float:
	var ph := fposmod(t * 23.0 + sin(t * 7.0) * 0.6, 1.0)
	return Sfx._noise(i) * exp(-ph * 40.0) * 0.6 * (1.0 - t / 1.2)
