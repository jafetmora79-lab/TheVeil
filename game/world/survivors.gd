extends Node
## THE VEIL - survivor relationships & consequences (built on the survival expansion, game/world/expedition.gd).
##   trust 0..100 per survivor, group morale 0..100, survivor health (healthy / injured / seriously injured /
##   recovering), deterministic shelter activities, a companion for scavenging trips, short overnight events and
##   remembered consequences. Everything lives in Game.world_state["survivors"] (saved with the game).
## Rules: every change is keyed and applied once (no farming); nothing here sets a story flag, kills, revives,
## duplicates or teleports a survivor in view; trust and morale only change dialogue, never block the story.
## Hooks for story chapters: trust(), morale(), health(), remember(), memory(), award(), set_health(), alive().
## Tuning: game/data/survivors.json.

const CFG := "res://game/data/survivors.json"
const NAMES := ["Eddie", "Marcus", "Ruth", "Sarah"]
const HEALTH_TEXT := {"healthy": "Healthy", "injured": "Injured", "serious": "Seriously injured", "recovering": "Recovering"}
## deterministic shelter activities (market-local floor spots); the schedule turns with each night and trip
const SPOTS := {"check_shelves": Vector3(8.6, 0.04, 6.8), "watch_entrance": Vector3(1.2, 0.04, 5.4),
	"examine_equipment": Vector3(6.2, 0.04, 4.9)}
const SCHEDULE := {"Eddie": ["examine_equipment", "watch_entrance", "talk", "rest"],
	"Ruth": ["check_shelves", "rest", "check_shelves", "talk"],
	"Sarah": ["rest", "talk", "watch_entrance", "rest"],
	"Marcus": ["watch_entrance", "rest", "examine_equipment", "watch_entrance"]}

var world: Node
var cfg := {}
var follow: VeilCompanionFollow           # the scavenging companion's follow (null when none)
var _act_t := 2.0
var _event_t := 0.0
var _hint_t := 0.0
var _early := {}
var _busy := false
var _recovered := false                   # one out-of-sight recovery per trip; a second separation is abandonment
var report := {"walks": 0, "events": [], "talks": 0, "recoveries": 0}   ## tests


func setup(w: Node) -> void:
	world = w
	var f := FileAccess.open(CFG, FileAccess.READ)
	cfg = JSON.parse_string(f.get_as_text()) if f else {}
	var s := st()
	# JSON loads numbers as floats: keep trust / morale / nights whole numbers
	for n in s["trust"]:
		s["trust"][n] = int(s["trust"][n])
	s["morale"] = int(s["morale"])
	s["nights"] = int(s["nights"])
	s["empty_trips"] = int(s["empty_trips"])
	# an older save: story flags already set count once (silently); past nights are not replayed
	for flag in Game.flags:
		_apply_flag(String(flag), true)
	Game.flag_set.connect(_on_flag)
	# a save made mid-trip with a companion: they are behind the player again (the load is faded in)
	if String(s["companion"]) != "":
		if world.expedition and world.expedition.active() and _available(String(s["companion"]), true):
			_start_follow(String(s["companion"]), true)
			if world.in_car:
				board_car.call_deferred(true)            # saved while driving: back in the passenger seat
		else:
			s["companion"] = ""


func st() -> Dictionary:
	if not Game.world_state.has("survivors"):
		var trust := {}
		var health := {}
		for n in NAMES:
			trust[n] = int(cfg.get("start_trust", 50))
			health[n] = "healthy"
		Game.world_state["survivors"] = {"trust": trust, "morale": int(cfg.get("start_morale", 50)), "health": health,
			"treated_since_night": {}, "memory": {}, "applied": {}, "events": [], "pending_event": "", "nights": 0,
			"companion": "", "activities": {}, "free": false, "empty_trips": 0, "good_trip": false, "requests": {}}
	return Game.world_state["survivors"]


# ------------------------------------------------------------------ public hooks
func alive(n: String) -> bool:
	if n == "Marcus" and Game.has_flag("ch9_marcus_lost"):
		return false
	return n in NAMES


func trust(n: String) -> int:
	return int(st()["trust"].get(n, 50))


func morale() -> int:
	return int(st()["morale"])


func health(n: String) -> String:
	return String(st()["health"].get(n, "healthy"))


func memory(n: String) -> Array:
	return st()["memory"].get(n, [])


func remember(n: String, what: String) -> void:
	var m: Array = st()["memory"].get(n, [])
	if what not in m:
		m.append(what)
	st()["memory"][n] = m


## Applied once per key (a second call with the same key does nothing): the anti-farming rule.
func award(key: String, who: Dictionary, morale_delta := 0) -> bool:
	var s := st()
	if s["applied"].has(key):
		return false
	s["applied"][key] = true
	for n in who:
		if alive(String(n)):
			s["trust"][n] = clampi(trust(String(n)) + int(who[n]), 0, 100)
	s["morale"] = clampi(morale() + morale_delta, 0, 100)
	return true


func set_health(n: String, h: String) -> void:
	if alive(n) and h in HEALTH_TEXT:
		st()["health"][n] = h


## Present in the shelter right now (alive, visible in the store).
func _available(n: String, ignore_roster := false) -> bool:
	if not alive(n):
		return false
	return ignore_roster or n in world.shelter_roster()


func trust_text(n: String) -> String:
	var t := trust(n)
	return "trusts you" if t >= 70 else ("warming to you" if t >= 55 else ("wary of you" if t >= 35 else "doesn't trust you"))


func morale_text() -> String:
	var m := morale()
	return "Hopeful" if m >= 65 else ("Holding together" if m >= 40 else ("Strained" if m >= 20 else "Close to breaking"))


# ------------------------------------------------------------------ story flags -> consequences
func _on_flag(f: String) -> void:
	_apply_flag(f, false)
	if f in cfg.get("night_flags", []):
		_night(f)
	elif not (f.begins_with("exp") or f.begins_with("sv_") or f.begins_with("chapter_card")):
		_end_free_time()                                    # the story moves: everyone goes back to their place


func _apply_flag(f: String, silent: bool) -> void:
	var s := st()
	if f in cfg.get("night_flags", []):
		if silent:
			s["applied"]["night:" + f] = true
		return
	match f:
		"ch8_sarah_injured":
			if not s["applied"].has("health:" + f):
				s["applied"]["health:" + f] = true
				set_health("Sarah", "injured")
		"ch8_sarah_treated":
			s["applied"]["health:ch8_sarah_injured"] = true
			if not s["applied"].has("health:" + f):
				s["applied"]["health:" + f] = true
				set_health("Sarah", "recovering")
				s["treated_since_night"]["Sarah"] = true
		"ch8_sarah_untreated":
			if not s["applied"].has("health:" + f):
				s["applied"]["health:" + f] = true
				set_health("Sarah", "serious")
	var eff: Dictionary = cfg.get("flag_effects", {}).get(f, {})
	if eff.is_empty():
		return
	if award("flag:" + f, eff.get("trust", {}), int(eff.get("morale", 0))):
		var mem: Dictionary = eff.get("memory", {})
		for n in mem:
			remember(String(n), String(mem[n]))


# ------------------------------------------------------------------ nights
func _night(f: String) -> void:
	var s := st()
	if s["applied"].has("night:" + f):
		return
	s["applied"]["night:" + f] = true
	s["nights"] = int(s["nights"]) + 1
	var aw: Dictionary = cfg.get("awards", {})
	# untreated injuries get worse; treated ones heal (nobody dies of it)
	for n in NAMES:
		if not alive(n):
			continue
		var h := health(n)
		var treated: bool = s["treated_since_night"].get(n, false)
		if h == "recovering":
			set_health(n, "healthy")
		elif h == "injured" and not treated:
			set_health(n, "serious")
			remember(n, "worsened")
	# a medicine request that went unanswered for a whole night
	for req in s["requests"].keys():
		var r: Dictionary = s["requests"][req]
		if health(String(r["patient"])) in ["injured", "serious"] and int(r["night"]) < int(s["nights"]):
			award("ignored:" + String(req), {String(r["by"]): int(aw.get("ignored", -5))})
	s["treated_since_night"] = {}
	# morale: was there enough to eat, did anyone get hurt, was the last trip any good
	var rep: Dictionary = Game.world_state.get("shelter_latest_report", {})
	var short: bool = not rep.is_empty() and (int(rep.get("food_used", 0)) < int(rep.get("food_needed", 0))
		or int(rep.get("water_used", 0)) < int(rep.get("water_needed", 0)))
	var md := int(aw.get("short_night_morale", -8)) if short else int(aw.get("safe_night_morale", 3))
	for n in NAMES:
		if alive(n) and health(n) == "serious":
			md -= 3
	award("night_morale:" + f, {}, md)
	s["pending_event"] = _pick_event()
	_event_t = 4.0
	s["free"] = true
	_act_t = 1.0


## One short overnight event, chosen by the group's situation; each is used once (never repeated).
func _pick_event() -> String:
	var s := st()
	var used: Array = s["events"]
	var need: Dictionary = world.expedition.supply_need() if world.expedition else {"need": 0, "food": 99, "water": 99}
	var hurt := ""
	for n in NAMES:
		if alive(n) and health(n) in ["injured", "serious"]:
			hurt = n
	var c := []
	if hurt != "":
		c.append("sv_night_medicine" if _available("Ruth", true) and hurt != "Ruth" else "sv_night_medicine_eddie")
	if int(need["food"]) < int(need["need"]) or int(need["water"]) < int(need["need"]):
		c.append("sv_night_food")
	if morale() < 35:
		c.append("sv_night_argue")
	if bool(s["good_trip"]):
		c.append("sv_night_thanks")
		c.append("sv_night_thanks_ruth")
	for id in c:
		if id not in used and _speakers_ok(id):
			if id.begins_with("sv_night_medicine"):
				s["requests"][id] = {"by": "Ruth" if id == "sv_night_medicine" else "Eddie", "patient": hurt, "night": int(s["nights"])}
			s["good_trip"] = false if id.begins_with("sv_night_thanks") else s["good_trip"]
			return id
	return ""


func _speakers_ok(id: String) -> bool:
	var entry: Dictionary = Dialogue.data.get(id, {})
	for l in entry.get("lines", []):
		var sp := String(l.get("speaker", ""))
		if sp != "" and not _available(sp, true):
			return false
	if id == "sv_night_medicine_eddie" and not _available("Eddie", true):
		return false
	return true


## The overnight event plays once the player is up and nothing else is happening (never in an emergency).
func _deliver_event(delta: float) -> void:
	var s := st()
	var id := String(s["pending_event"])
	if id == "":
		return
	if world.expedition == null or world.expedition.shelter() == "":
		s["pending_event"] = ""                               # the shelter is gone: the moment passed
		return
	_event_t -= delta
	if _event_t > 0.0 or not _quiet():
		return
	s["pending_event"] = ""
	if id in s["events"]:
		return
	s["events"].append(id)
	report["events"].append(id)
	Dialogue.say(id, false, true)


## No cinematic, talk, encounter, emergency, menu or dialogue in progress.
func _quiet() -> bool:
	if world.conversing or world.get("_encounter_running") == true or Dialogue.is_busy() or world._choice_open():
		return false
	if world._cine and is_instance_valid(world._cine):
		return false
	if world.hud.is_paused() or not world.player.visible or not world.player.controls_enabled:
		return false
	return world.expedition != null and not world.expedition.emergency()


# ------------------------------------------------------------------ treatment
func can_treat(n: String) -> String:
	if not alive(n) or not (health(n) in ["injured", "serious"]):
		return ""
	var cost := treat_cost(n)
	if int(Game.shelter_stock().get("medical", 0)) + Game.inventory.count("painkillers") < cost:
		return ""
	return "Treat %s (%d medicine)" % [n, cost]


func treat_cost(n: String) -> int:
	return 2 if health(n) == "serious" else 1


## Uses the shelter's medicine first, then carried painkillers. serious -> injured, injured -> recovering.
func treat(n: String) -> bool:
	if can_treat(n) == "":
		return false
	var cost := treat_cost(n)
	var stock := Game.shelter_stock()
	for i in cost:
		if int(stock.get("medical", 0)) > 0:
			stock["medical"] = int(stock["medical"]) - 1
		else:
			Game.remove_item("painkillers")
	Game.world_state["shelter_stock"] = stock
	var s := st()
	set_health(n, "recovering" if health(n) == "injured" else "injured")
	s["treated_since_night"][n] = true
	award("treated:%s:%d:%s" % [n, int(s["nights"]), health(n)], {n: int(cfg.get("awards", {}).get("treated", 5))})
	for req in s["requests"].keys():
		if String(s["requests"][req]["patient"]) == n and health(n) == "recovering":
			s["applied"]["ignored:" + String(req)] = true          # answered in time
	return true


# ------------------------------------------------------------------ the shelter status panel
func status_text() -> String:
	var t := "THE GROUP  -  morale: %s" % morale_text()
	for n in NAMES:
		if not alive(n) or not (n in world.shelter_roster() or String(st()["companion"]) == n):
			continue
		var where := "with you" if String(st()["companion"]) == n else "in the shelter"
		var h := health(n)
		var warn := ""
		if h == "injured" and not st()["treated_since_night"].get(n, false):
			warn = " (getting worse without medicine)"
		t += "\n%s  -  %s%s  -  %s  -  %s" % [n, HEALTH_TEXT[h], warn, where, trust_text(n)]
	return t


func open_panel(choice: Node) -> void:
	if _busy:
		return
	_busy = true
	while is_inside_tree():
		var opts := []
		var acts := []
		for n in NAMES:
			var tr := can_treat(n) if _available(n) else ""
			if tr != "":
				opts.append(tr)
				acts.append(["treat", n])
		for n in NAMES:
			if _available(n):
				opts.append("Talk to " + n)
				acts.append(["talk", n])
		opts.append("Back")
		var i: int = await choice.ask(status_text(), opts, world.player)
		if i < 0 or i >= acts.size():
			break
		if acts[i][0] == "treat":
			if treat(acts[i][1]):
				Sfx.play("pickup", world.player.global_position, -8.0, 0.8)
		else:
			_busy = false
			await talk(acts[i][1])
			return
	_busy = false


## One remark that fits this survivor right now: a remembered consequence first, then health, then trust.
func remark_for(n: String) -> String:
	var s := st()
	var m := memory(n)
	if n == "Marcus" and "rescued" in m and not s["applied"].has("said:mem_rescued"):
		return "sv_mem_rescued_Marcus"
	if n == "Ruth" and int(s["empty_trips"]) >= 2 and not s["applied"].has("said:ruth_empty"):
		return "sv_ruth_empty_trips"
	if n == "Ruth" and world.expedition:
		var need: Dictionary = world.expedition.supply_need()
		if int(need["food"]) < int(need["need"]) or int(need["water"]) < int(need["need"]):
			return "sv_Ruth_supplies"
	if n == "Sarah" and health(n) in ["injured", "serious"]:
		return "sv_Sarah_hurt"
	if n == "Sarah" and "saw_death" in m and trust(n) < 60:
		return "sv_Sarah_low"
	if n == "Eddie" and world.expedition and world.expedition.level() >= 2:
		return "sv_Eddie_danger"
	return "sv_%s_%s" % [n, "high" if trust(n) >= 55 else "low"]


func talk(n: String) -> void:
	var id := remark_for(n)
	if id == "sv_mem_rescued_Marcus":
		st()["applied"]["said:mem_rescued"] = true
	elif id == "sv_ruth_empty_trips":
		st()["applied"]["said:ruth_empty"] = true
	report["talks"] += 1
	var body: Node3D = world.animators[n].root if world.animators.has(n) else null
	if body == null or not await world.converse([id], [body]):
		Dialogue.say(id, false, true)


# ------------------------------------------------------------------ scavenging companions
func companion_options() -> Array:
	var out := []
	for n in NAMES:
		if _available(n) and health(n) != "serious":
			out.append(n)
	return out


## Asked after "Scavenge for Supplies" (on foot). Returns "" for going alone.
func pick_companion(choice: Node) -> String:
	var names := companion_options()
	if names.is_empty():
		return ""
	var opts := ["Go alone"]
	for n in names:
		opts.append("Take %s (%s)" % [n, {"Eddie": "carries more", "Ruth": "spots supplies", "Sarah": "hears danger early",
			"Marcus": "looks for signs of Noah"}[n]])
	var i: int = await choice.ask("WHO COMES ALONG?", opts, world.player)
	return names[i - 1] if i >= 1 and i <= names.size() else ""


func begin_trip(n: String) -> void:
	var s := st()
	s["companion"] = n
	_early = {}
	_recovered = false
	_hint_t = 3.0
	if n == "":
		return
	_end_free_time()
	_start_follow(n, false)
	Dialogue.say("sv_companion_" + n if trust(n) >= 35 else "sv_companion_reluctant", false, true)


func _start_follow(n: String, recover: bool) -> void:
	var body: Node3D = world.animators[n].root
	follow = body.get_node_or_null("SV_Follow") as VeilCompanionFollow
	if follow == null:
		follow = VeilCompanionFollow.new()
		follow.name = "SV_Follow"
		follow.set_meta("sv_companion", true)
		body.add_child(follow)
	follow.setup(body, world.player)
	follow.gap = 2.6
	follow.start()
	_add_helper(n)
	if recover:
		follow.recover_behind.call_deferred(3.0)


## Trip over (expedition.secure()): rewards, bonuses and, if the companion was left far behind, the cost of that.
func end_trip(got: Dictionary) -> void:
	var s := st()
	var trip := int(world.expedition.st().get("trips", 0))
	var n := String(s["companion"])
	var aw: Dictionary = cfg.get("awards", {})
	var total := 0
	for k in got:
		if k in ["canned_food", "water_bottle", "energy_snack", "chocolate_bar", "cola_bottle", "painkillers", "batteries"]:
			total += int(got[k])
	_remove_helper()
	leave_car()
	if n != "" and follow:
		var far: bool = follow.lag() > float(cfg.get("abandon_distance", 35))
		follow.stop()
		follow = null
		if far:
			award("abandoned:%d" % trip, {n: int(aw.get("abandoned", -15))}, -5)
			remember(n, "abandoned")
			_send_home(n)                                    # they make their own way back (out of sight)
		else:
			if total > 0:
				award("together:%d" % trip, {n: int(aw.get("trip_together", 2))})
			if n == "Eddie":
				_unload_pack()                               # back inside together: what he carried goes to the player
			_send_home(n)
	s["companion"] = ""
	if total > 0:
		s["empty_trips"] = 0
		s["good_trip"] = true
		award("trip:%d" % trip, cfg.get("awards", {}).get("supplies_brought", {}), int(aw.get("good_trip_morale", 4)))
	else:
		s["empty_trips"] = int(s["empty_trips"]) + 1
		award("trip:%d" % trip, {}, int(aw.get("empty_trip_morale", -4)))
	s["free"] = true
	_act_t = 2.0


func _send_home(n: String) -> void:
	var body: Node3D = world.animators[n].root
	if not body.has_meta("shelter_feet"):
		return
	var home := _home(body)
	var c5: Node = world.expedition._c5()
	if body.get_parent() == world.market and c5 and c5._in_store(body.position):
		world.npc_walk(n, home, 1.4)
	else:
		world._place_unseen(body, home)


## While a companion is out: keep them close (never a visible jump) and apply their modest bonus.
func _companion_tick(delta: float) -> void:
	var n := String(st()["companion"])
	if n == "" or follow == null or not is_instance_valid(follow):
		return
	if not world.expedition.active():
		return
	var cam := world.get_viewport().get_camera_3d()
	var seen: bool = cam != null and cam.is_position_in_frustum(follow.npc.global_position + Vector3(0, 1, 0))
	if follow.lag() > 22.0 and not seen and not world.in_car and passenger == "" and not _recovered:
		_recovered = true
		follow.recover_behind(3.0)                           # separated (stuck or lost): back on the trail, unseen
		report["recoveries"] += 1
	_hint_t -= delta
	if _hint_t <= 0.0 and not Dialogue.is_busy():
		_hint_t = 45.0
		if n == "Ruth":
			var c := _nearest_cache()
			var loot := _search_target(world.player.global_position, 25.0, false)
			if loot != null and (c == Vector3.INF or world.player.global_position.distance_to(loot.global_position) < world.player.global_position.distance_to(c)):
				c = loot.global_position
			if c != Vector3.INF:
				world.expedition._hint("Ruth: \"Over there - %s, maybe %d metres.\"" % [_dir_word(c), int(world.player.global_position.distance_to(c))])
				_mark("sv_ruth", c, 20.0)
		elif n == "Marcus":
			var clue := _nearest_clue()
			if clue != Vector3.INF:
				world.expedition._hint("Marcus: \"Wait - %s. Could be something of Noah's.\"" % _dir_word(clue))
				_mark("sv_marcus", clue, 20.0)
	# Sarah hears it coming: a creature that is really out there (this trip's), close but not yet in view
	if n == "Sarah":
		for c in world.expedition.creatures:
			var node: Node3D = c.get("node") as Node3D
			if node == null or not is_instance_valid(node) or not node.is_inside_tree() or _warned.has(node.get_instance_id()):
				continue
			var d: float = world.player.global_position.distance_to(node.global_position)
			var in_view: bool = cam != null and d < 22.0 and cam.is_position_in_frustum(node.global_position + Vector3(0, 0.8, 0))
			if d < 38.0 and not in_view:
				_warned[node.get_instance_id()] = true
				world.expedition._hint("Sarah: \"Shh - something's moving, %s.\"" % _dir_word(node.global_position))
				if not Dialogue.is_busy():
					Dialogue.say("sv_sarah_early", false, false)
				break


# ------------------------------------------------------------------ riding in the repaired car
var passenger := ""                         ## the trip companion sitting in the car
var _rider_parent: Node3D = null


## The player got in: the trip companion (alive, with them, not far off) walks to the passenger door and takes the
## seat; the car is not driven off until they are in (at most a few seconds). instant: a load inside the car.
func board_car(instant := false) -> void:
	var n := String(st()["companion"])
	if n == "" or passenger != "" or follow == null or not is_instance_valid(follow) or not alive(n):
		return
	var body := world.animators[n].root as Node3D
	var car: Node3D = world.sedan
	var seat := car.find_child("Marker_Seat_Passenger", true, false) as Node3D
	if seat == null or body.global_position.distance_to(car.global_position) > 25.0:
		return
	follow.stop()
	if not instant:
		var door: Vector3 = car.global_transform * Vector3(1.6, 0.0, -0.3)
		door.y = body.global_position.y
		world.npc_walk(n, body.get_parent_node_3d().to_local(door), 2.2)
		var t := 0.0
		while t < 8.0 and Vector2(body.global_position.x - door.x, body.global_position.z - door.z).length() > 0.7:
			await get_tree().process_frame
			t += get_process_delta_time()
	passenger = n
	_rider_parent = body.get_parent_node_3d()
	body.collision_layer = 0
	body.collision_mask = 0
	body.reparent(seat, false)
	# on the seat, facing the way the car drives: the car runs along its -Z, an NPC's model faces its +Z
	body.global_transform = Transform3D(Basis(Vector3.UP, car.global_rotation.y + PI), seat.global_position - Vector3(0, 0.45, 0))
	var an = world.animators.get(n)
	if an:
		an.walk_to([])
		an.set_seated(true, 0.45)


## The player got out: the passenger gets out on their side, onto clear ground, and follows again.
func leave_car() -> void:
	if passenger == "":
		return
	var n := passenger
	passenger = ""
	var body := world.animators[n].root as Node3D
	var car: Node3D = world.sedan
	var parent := _rider_parent if _rider_parent and is_instance_valid(_rider_parent) else world as Node3D
	body.reparent(parent, true)
	var out: Vector3 = car.global_transform * Vector3(1.6, 0.0, -0.3)
	var vb := body as VeilSurvivorBody
	if vb:
		var safe := vb.nearest_safe(out, 2.0)
		body.global_transform = Transform3D(Basis(Vector3.UP, car.global_rotation.y), safe if safe.is_finite() else out)
		body.collision_layer = VeilSurvivorBody.LAYER
		body.collision_mask = VeilSurvivorBody.SOLIDS
	var an = world.animators.get(n)
	if an:
		an.set_seated(false)
	if follow and is_instance_valid(follow):
		follow.start()


# ------------------------------------------------------------------ companion help on a trip
## Eddie's pack: real items moved out of the player's inventory (food, water, medicine), up to PACK_CAP_KG by the
## items' own weights; saved in Game.world_state, so it survives a load whether or not Eddie is out.
const PACK_KEY := "eddie_pack"
const PACK_CAP_KG := 6.0
const SEARCH_RANGE := 9.0
var _helper: Interactable = null
var _searching := false
var _warned := {}


func pack() -> Array:
	return Game.world_state.get(PACK_KEY, [])


func pack_weight() -> float:
	var w := 0.0
	for id in pack():
		w += float(Game.item_info(String(id)).get("weight", 0.0))
	return w


func _pack_fits(id: String) -> bool:
	return pack_weight() + float(Game.item_info(id).get("weight", 0.0)) <= PACK_CAP_KG + 0.001


static func _packable(id: String) -> bool:
	return Game.shelter_resource(id) in ["food", "water", "medical"]


func _give_eddie(id: String) -> bool:
	if not Game.has_item(id) or not _packable(id) or not _pack_fits(id):
		return false
	Game.remove_item(id)
	var a := pack().duplicate()
	a.append(id)
	Game.world_state[PACK_KEY] = a
	Game.inventory_changed.emit()
	return true


func _take_back(id: String) -> bool:
	var a := pack().duplicate()
	if not (id in a):
		return false
	a.erase(id)
	Game.world_state[PACK_KEY] = a
	Game.add_item(id)
	return true


func _pack_text() -> String:
	var counts := {}
	for id in pack():
		counts[id] = int(counts.get(id, 0)) + 1
	var parts: Array = []
	for id in counts:
		parts.append("%s x%d" % [Game.item_info(String(id)).get("name", id), counts[id]])
	return "PACK  %.1f / %.1f kg    %s" % [pack_weight(), PACK_CAP_KG, ", ".join(parts) if not parts.is_empty() else "empty"]


## Back inside with Eddie: everything he carried is handed to the player (to store or keep).
func _unload_pack() -> void:
	var a := pack().duplicate()
	if a.is_empty():
		return
	Game.world_state[PACK_KEY] = []
	for id in a:
		Game.add_item(String(id))
	world.expedition._hint("Eddie hands over what he carried (%d items)." % a.size())


func _add_helper(n: String) -> void:
	_remove_helper()
	var body: Node3D = world.animators[n].root
	_helper = Interactable.attach(body, {"kind": "custom", "label": n,
		"prompt_text": Interactable.key_hint() + ("Eddie: Supplies / Search Nearby" if n == "Eddie" else "%s: Search Nearby" % n)})
	_helper.name = "SV_Help"
	_helper.used.connect(func(_b): _help_menu(n))


func _remove_helper() -> void:
	if _helper and is_instance_valid(_helper):
		_helper.queue_free()
	_helper = null


## The nearest unlooted food / water / medicine pickup (inside an unlocked container or loose) on the same floor.
func _search_target(from: Vector3, rng: float, same_floor := true) -> Interactable:
	var best: Interactable = null
	for n in get_tree().get_nodes_in_group("veil_pickup"):
		var it := n as Interactable
		if it == null or it.taken or not it.is_visible_in_tree() or not _packable(it.item_id):
			continue
		if same_floor and absf(it.global_position.y - from.y) > 1.6:
			continue
		var c := it.container
		if c and c.lock_check.is_valid() and String(c.lock_check.call()) != "":
			continue
		var d := from.distance_to(it.global_position)
		if d <= rng and (best == null or d < from.distance_to(best.global_position)):
			best = it
	return best


func _help_menu(n: String) -> void:
	var choice: Node = world.phase4.choice if world.phase4 else null
	if choice == null or choice.is_open() or _searching or String(st()["companion"]) != n:
		return
	var body: Node3D = world.animators[n].root
	while true:
		var title := n.to_upper()
		var opts: Array = []
		var acts: Array = []
		var target := _search_target(body.global_position, SEARCH_RANGE)
		if target:
			opts.append("Search that %s" % (String(target.container.label).to_lower() if target.container else "spot"))
			acts.append(["search", target])
		if n == "Eddie":
			title += "\n" + _pack_text()
			var seen: Array = []
			for id in Game.inventory:
				if _packable(String(id)) and not (id in seen):
					seen.append(id)
					var nm: String = Game.item_info(String(id)).get("name", id)
					if _pack_fits(String(id)):
						opts.append("Give Eddie: %s (%d carried)" % [nm, Game.inventory.count(id)])
						acts.append(["give", id])
			seen.clear()
			for id in pack():
				if not (id in seen):
					seen.append(id)
					opts.append("Take back: %s (x%d)" % [Game.item_info(String(id)).get("name", id), pack().count(id)])
					acts.append(["take", id])
		if acts.is_empty():
			opts.append("Nothing to search here")
			acts.append(["close", null])
		opts.append("Close")
		acts.append(["close", null])
		var i: int = await choice.ask(title, opts, world.player)
		var act: Array = acts[clampi(i, 0, acts.size() - 1)] if i >= 0 else ["close", null]
		match String(act[0]):
			"give":
				_give_eddie(String(act[1]))
			"take":
				_take_back(String(act[1]))
			"search":
				_search(n, act[1] as Interactable)
				return
			_:
				return


## The companion walks to the container, opens it and takes what is there (Eddie into his pack when it fits,
## otherwise to the player). Nothing is found that the container does not hold; an unreachable one is left.
func _search(n: String, it: Interactable) -> void:
	_searching = true
	var body := world.animators[n].root as Node3D
	var f := follow
	if f:
		f.stop()
	var spot := Vector3(it.global_position.x, body.global_position.y, it.global_position.z)
	var vb := body as VeilSurvivorBody
	if vb:
		var safe := vb.nearest_safe(spot, 1.6)
		if safe.is_finite():
			spot = safe
	world.npc_walk(n, body.get_parent_node_3d().to_local(spot), 1.4)
	var t := 0.0
	while t < 9.0 and is_instance_valid(it) and not it.taken and Vector2(body.global_position.x - it.global_position.x,
			body.global_position.z - it.global_position.z).length() > 1.25:
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(it) and not it.taken and t < 9.0:
		if it.container and not it.container.is_open:
			it.container.set_open(true)
			Sfx.play("door_open", it.container.global_position, -6.0, 1.3)
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(it) and not it.taken:
			var id := it.item_id
			var nm: String = Game.item_info(id).get("name", id)
			it.interact(body)                                  # the container's own pickup: taken, saved, added
			if n == "Eddie" and _give_eddie(id):
				world.expedition._hint("Eddie: \"%s. It's in my pack.\"" % nm)
			else:
				world.expedition._hint("%s: \"Found %s - here.\"" % [n, nm])
	else:
		world.expedition._hint("%s: \"Can't get to it.\"" % n)
	_searching = false
	if f and is_instance_valid(f) and f == follow:
		f.start()


## A small diamond over what the companion pointed at, for a while (the HUD's own world markers).
func _mark(key: String, at: Vector3, seconds: float) -> void:
	var old := world.get_node_or_null(key) as Node3D
	if old:
		old.queue_free()
	var m := Node3D.new()
	m.name = key
	world.add_child(m)
	m.global_position = at
	world.hud.world_diamond(key, m)
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(m):
			m.queue_free())


func _nearest_cache() -> Vector3:
	var best := Vector3.INF
	var p: Vector3 = world.player.global_position
	for k in world.expedition.its:
		if String(k).begins_with("exp/") and is_instance_valid(world.expedition.its[k]):
			var it: Node3D = world.expedition.its[k]
			if it.is_visible_in_tree() and (best == Vector3.INF or p.distance_to(it.global_position) < p.distance_to(best)):
				best = it.global_position
	return best


func _nearest_clue() -> Vector3:
	var p: Vector3 = world.player.global_position
	var best := Vector3.INF
	for it in world.find_children("*", "Interactable", true, false):
		var l := String(it.get("label")).to_lower() + " " + String(it.get("prompt_text")).to_lower()
		if it.is_visible_in_tree() and String(it.get("prompt_text")) != "" and ("noah" in l or "backpack" in l or "note" in l) \
				and p.distance_to(it.global_position) < 30.0:
			if best == Vector3.INF or p.distance_to(it.global_position) < p.distance_to(best):
				best = it.global_position
	return best


func _dir_word(at: Vector3) -> String:
	var to: Vector3 = at - world.player.global_position
	var fwd: Vector3 = -world.player.global_transform.basis.z
	var a := rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))
	return "straight ahead" if absf(a) < 35 else ("behind us" if absf(a) > 135 else ("to the right" if a > 0 else "to the left"))


# ------------------------------------------------------------------ shelter activities (free time only)
func activity(n: String) -> String:
	var s := st()
	if not alive(n):
		return ""
	if health(n) in ["injured", "serious"]:
		return "rest"
	for m in NAMES:
		if n == "Ruth" and m != n and alive(m) and health(m) in ["injured", "serious"]:
			return "tend:" + m
	var sched: Array = SCHEDULE[n]
	return String(sched[(int(s["nights"]) + int(world.expedition.st().get("trips", 0)) if world.expedition else 0) % sched.size()])


func _activity_target(n: String, act: String, body: Node3D) -> Vector3:
	if act == "rest" or not body.has_meta("shelter_feet"):
		return _home(body)
	if act.begins_with("tend:") or act == "talk":
		var other := act.get_slice(":", 1) if act.begins_with("tend:") else ("Ruth" if n == "Eddie" else "Eddie")
		if not _available(other):
			return _home(body)
		var ob: Node3D = world.animators[other].root
		var off := Vector3(0.9, 0, 0.3) if n < other else Vector3(-0.9, 0, -0.3)
		return ob.position + off
	return SPOTS.get(act, Vector3.INF)


func _activities(delta: float) -> void:
	_act_t -= delta
	if _act_t > 0.0:
		return
	_act_t = 3.0
	var s := st()
	if not bool(s["free"]) or world.expedition == null or world.expedition.shelter() == "" or not _quiet():
		return
	for n in NAMES:
		if not _available(n) or String(s["companion"]) == n:
			continue
		var an = world.animators.get(n)
		var body: Node3D = an.root
		if an.is_walking() or body.get_node_or_null("Follow") and (body.get_node("Follow") as VeilCompanionFollow).active:
			continue
		var act := activity(n)
		var to := _activity_target(n, act, body)
		s["activities"][n] = act
		if to.is_finite() and body.position.distance_to(to) > 1.2:
			world.npc_walk(n, to, 1.2)
			report["walks"] += 1


## The story needs everyone where it left them: walk back (never placed in view).
func _end_free_time() -> void:
	var s := st()
	if not bool(s["free"]):
		return
	s["free"] = false
	s["activities"] = {}
	for n in NAMES:
		if not _available(n) or String(s["companion"]) == n:
			continue
		var body: Node3D = world.animators[n].root
		var home := _home(body)
		if home.is_finite() and body.position.distance_to(home) > 0.6:
			world.npc_walk(n, home, 1.4)


## The story's own spot for this survivor (market-local), where the chapter last placed them.
func _home(body: Node3D) -> Vector3:
	if not body.has_meta("shelter_feet") or body.get_parent() != world.market:
		return Vector3.INF
	return world.market.to_local(body.get_meta("shelter_feet"))


func _process(delta: float) -> void:
	if world == null or not Game.world_state.has("survivors"):
		return
	_deliver_event(delta)
	_companion_tick(delta)
	_activities(delta)
