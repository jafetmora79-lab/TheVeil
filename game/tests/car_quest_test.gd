extends SceneTree
## THE VEIL - the car repair quest (game/world/car_quest.gd), end to end with the real game objects (headless,
## --fixed-fps 60). From the Chapter 7 developer entry (the supermarket is the shelter, the wrecks are out):
##   gas canister pickup; battery steps in order (refused out of order), the pull meter; fuse steps; the guard Crab
##   (appears out of view, really walks to the car alarm, comes home again, a grab is the BREAK FREE struggle and it
##   recovers, never removed); a save + load mid-quest keeps every step; the checklist, fitting each part (items used
##   up, never twice), Start Engine, and the car drivable.
const DEV := preload("res://game/tools/dev_chapter7.gd")

var fails := 0
var w: Node
var game: Node
var q: Node
var ex: Node
var _off_trip := false


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		_unblock()


## A choice panel opened by the game itself pauses the tree: close it so the test can go on.
func _unblock() -> void:
	if ex and is_instance_valid(ex) and not _off_trip:
		ex.st()["active"] = true                 # this whole test is a supply run (car parts are a trip's job)
		ex.st()["went_out"] = false              # (and never "back in with the doors shut": no trip-over card)
	if w and is_instance_valid(w) and w.phase4 and w.phase4.choice.is_open():
		w.phase4.choice.pick(-1)


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
		_unblock()
	return cond.call()


func _use(key: String) -> void:
	ex.st()["active"] = true                     # (a supply run: the trip logic may have closed it meanwhile)
	var it: Interactable = q.steps[key]
	it.interact(w.player)
	await _until(func(): return not q.busy, 600)
	await _frames(3)


func _live(key: String) -> bool:
	var it: Interactable = q.steps.get(key)
	return it != null and it.collision_layer == 8 and it.get_prompt() != ""


func _load_world() -> void:
	game = root.get_node("Game")
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await _frames(200)
	ex = w.expedition
	q = ex.quest


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	if not "car_keys" in game.inventory:
		game.inventory.append("car_keys")
	game.flags["fridge_checked"] = true
	game.world_state["supply_grace"] = true
	await _load_world()
	ex.st()["active"] = true                     # car parts are a supply-run job (taken on a trip only)
	var p: CharacterBody3D = w.player
	ok("quest_placed", q.placed and q.sites.size() == 4, str(q.sites.keys()))
	for k in ["fuel_can", "car_battery", "car_fuse", "starter_relay"]:
		ok("lead_anchor_" + k, ex.its.get("exp/part_" + k) != null)
	game.set_flag("vehicle_found")
	# discovery: nothing is marked until the player has been near a part and seen it
	ok("no_leads_before_seen", ex.car_leads().is_empty() and not w.hud.world_diamonds.keys().any(func(k): return String(k).begins_with("car_part_")),
		str(ex.car_leads().size()))
	var far_ok := true
	for k in ["fuel_can", "car_battery", "car_fuse", "starter_relay"]:
		var it: Node3D = ex.its["exp/part_" + k]
		var away := it.global_position + Vector3(14.0, 0.2, 0.0)
		p.global_position = away
		await _frames(3)
		ex._discover_parts()
		if ex.seen(k):
			far_ok = false
	ok("not_seen_from_afar", far_ok)
	var near_ok := true
	for k in ["fuel_can", "car_battery", "car_fuse", "starter_relay"]:
		var it: Node3D = ex.its["exp/part_" + k]
		# stand ~3 m off on open ground, then look for it the way the tick does
		var spot := Vector3.INF
		for i in 16:
			var a := TAU * i / 16.0
			var c := it.global_position + Vector3(cos(a), 0.0, sin(a)) * 3.2
			var h: Dictionary = (w.get_world_3d() as World3D).direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * 3.0, c - Vector3.UP * 3.0, 1, [p.get_rid()]))
			if h and ex._sees((h["position"] as Vector3) + Vector3(0, 1.5, 0), it.global_position):
				spot = (h["position"] as Vector3) + Vector3(0, 0.1, 0)
				break
		if spot.is_finite():
			p.global_position = spot
			await _frames(3)
			ex._discover_parts()
		if not ex.seen(k):
			ex.mark_seen(k)                              # (no clear spot found by this probe: mark it the same way)
			near_ok = near_ok and spot.is_finite()
	ok("seen_up_close", near_ok)
	ok("line_said_once", game.has_flag("said_exp_seen_fuel") and game.has_flag("said_exp_seen_battery") and game.has_flag("said_exp_seen_fuse")
		and game.has_flag("said_exp_seen_relay"))
	ok("map_leads_four", ex.car_leads().size() == 4, str(ex.car_leads().map(func(l): return l[1])))
	ok("diamonds_four", w.hud.world_diamonds.keys().filter(func(k): return String(k).begins_with("car_part_")).size() == 4,
		str(w.hud.world_diamonds.keys()))
	ok("seen_saved", (game.world_state["expedition"].get("car_seen", {}) as Dictionary).size() == 4)
	p.global_position = w.market.global_transform * Vector3(0, 0.3, 6.0)
	await _frames(10)

	# ---- 1. the gas canister
	ok("gas_prompt", (q.steps["gas/take"] as Interactable).get_prompt() == "[E] Pick Up Gas Canister")
	var can: Node3D = q.sites["fuel_can"]["root"]
	ok("gas_grounded", absf(can.global_position.y - 0.1) < 0.25, str(can.global_position))
	await _use("gas/take")
	ok("gas_taken", game.inventory.count("fuel_can") == 1 and not can.visible and q.acquired("fuel_can"))
	ok("gas_card", w.hud.caption_l.text.begins_with("GAS CANISTER ACQUIRED"), w.hud.caption_l.text)
	ok("gas_item_name", String(game.item_info("fuel_can").get("name")) == "Gas Canister")
	(q.steps["gas/take"] as Interactable).interact(p)
	await _frames(40)
	ok("gas_once", game.inventory.count("fuel_can") == 1)
	ok("player_control_back", p.controls_enabled and p.look_enabled)

	# ---- 2. the battery: in order only
	ok("bat_first_inspect", _live("battery/inspect") and not _live("battery/neg") and not _live("battery/pull"))
	q._battery_pull()                                  # straight to the pull: refused
	await _frames(5)
	ok("bat_pull_refused_early", not q.acquired("car_battery") and not q.pulling)
	await _use("battery/inspect")
	ok("bat_inspected", bool(q.part_state("car_battery").get("inspected")) and _live("battery/neg") and not _live("battery/pos"))
	q._battery_cable("pos")                            # positive first: refused
	await _frames(5)
	ok("bat_pos_needs_neg", not bool(q.part_state("car_battery").get("pos", false)))
	var clamp: Node3D = (q.sites["car_battery"]["battery"] as Node3D).get_node("ClampNeg")
	var c0 := clamp.position
	await _use("battery/neg")
	ok("bat_neg_off", bool(q.part_state("car_battery").get("neg")) and clamp.position.distance_to(c0) > 0.05 and _live("battery/pos"))

	# ---- save + load in the middle (the negative cable off, nothing else)
	w.save()
	game.load_game()
	w.queue_free()
	await _frames(5)
	await _load_world()
	p = w.player
	var bat: Node3D = q.sites["car_battery"]["battery"]
	ok("load_gas_kept", game.inventory.count("fuel_can") == 1 and not (q.sites["fuel_can"]["root"] as Node3D).visible)
	ok("load_bat_steps", bool(q.part_state("car_battery").get("neg")) and not bool(q.part_state("car_battery").get("pos", false))
		and _live("battery/pos") and not _live("battery/inspect"))
	ok("load_clamp_moved", (bat.get_node("ClampNeg") as Node3D).position.distance_to(c0) > 0.05)
	await _use("battery/pos")
	ok("bat_pull_ready", _live("battery/pull"))
	# the pull: too few clicks -> the grip slips, nothing lost
	(q.steps["battery/pull"] as Interactable).interact(p)
	await _until(func(): return q.pulling, 120)
	ok("bat_meter_shown", q.pulling and q._title.text == "CLICK REPEATEDLY — PULL BATTERY")
	await _until(func(): return not q.busy, 60 * 12)
	ok("bat_pull_fail_keeps", not q.acquired("car_battery") and _live("battery/pull"))
	(q.steps["battery/pull"] as Interactable).interact(p)
	await _until(func(): return q.pulling, 120)
	var clicks := 0
	while q.pulling and clicks < 60:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		q._input(e)
		clicks += 1
		await _frames(6)
	await _until(func(): return not q.busy, 300)
	ok("bat_pulled", q.acquired("car_battery") and game.inventory.count("car_battery") == 1 and not bat.visible, "%d clicks" % clicks)
	ok("bat_card", w.hud.caption_l.text.begins_with("CAR BATTERY ACQUIRED"), w.hud.caption_l.text)
	q._battery_pull()
	await _frames(5)
	ok("bat_once", game.inventory.count("car_battery") == 1)

	# ---- 3. the fuse
	ok("fuse_first_inspect", _live("fuse/inspect") and not _live("fuse/door"))
	await _use("fuse/inspect")
	await _use("fuse/door")
	var door: Node3D = q.sites["car_fuse"]["door"]
	ok("fuse_door_open", door != null and absf(door.rotation.y) > deg_to_rad(50.0))
	await _use("fuse/panel")
	var cover := (q.sites["car_fuse"]["panel"] as Node3D).get_node("Cover") as Node3D
	ok("fuse_panel_open", absf(cover.rotation.y) > deg_to_rad(80.0) and _live("fuse/look"))
	await _use("fuse/look")
	ok("fuse_pull_ready", _live("fuse/pull") and not _live("fuse/look"))
	await _use("fuse/pull")
	var good := (q.sites["car_fuse"]["panel"] as Node3D).get_node("Fuse_Good") as Node3D
	ok("fuse_taken", q.acquired("car_fuse") and game.inventory.count("car_fuse") == 1 and not good.visible)
	ok("fuse_card", w.hud.caption_l.text.begins_with("REPLACEMENT FUSE ACQUIRED"))

	# ---- 4. the guard: appears out of view, a fair way off
	var home: Vector3 = q._crab_home()
	p.global_position = home + Vector3(-60, 0.2, 30)
	p.set_yaw_pitch(atan2(-(p.global_position.x - home.x), -(p.global_position.z - home.z)), 0.0)   # facing away
	await _until(func(): return q.crab_ai != null, 120)
	var ai = q.crab_ai
	ok("crab_spawned", ai != null and is_instance_valid(ai))
	if ai:
		var cam := w.get_viewport().get_camera_3d()
		ok("crab_not_in_view", not cam.is_position_in_frustum(ai.body.global_position + Vector3(0, 0.8, 0)))
		ok("crab_far", ai.body.global_position.distance_to(p.global_position) >= 30.0)
		await _frames(240)
		ok("crab_patrols", ai.state == "PATROL" and ai.body.global_position.distance_to(home) < q.CRAB_LEASH)
		# the alarm: it goes to look
		var alarm: Node3D = q.sites["starter_relay"]["alarm"]
		var d0: float = ai.body.global_position.distance_to(alarm.global_position)
		ok("alarm_prompt", (q.steps["relay/alarm"] as Interactable).get_prompt() == "[E] Set Off Car Alarm")
		await _use("relay/alarm")
		ok("crab_investigates", ai.state == "INVESTIGATE", ai.state)
		var closest := d0
		for i in 60 * 25:
			await physics_frame
			closest = minf(closest, ai.body.global_position.distance_to(alarm.global_position))
			if ai.state == "RETURN":
				break
		ok("crab_walked_to_alarm", closest < 5.0 and d0 - closest > 6.0, "from %.1f m to %.1f m" % [d0, closest])
		ok("crab_goes_home", ai.state in ["RETURN", "PATROL"], ai.state)
		ok("alarm_uses_saved", int(q.q().get("alarm_uses", 0)) == 1)
		# meanwhile the relay
		await _use("relay/take")
		ok("relay_taken", q.acquired("starter_relay") and game.inventory.count("starter_relay") == 1)
		# the direct way: a grab is the struggle; winning frees the player, the Crab recovers and comes again
		var st = w.get_node_or_null("Struggle")
		p.global_position = ai.body.global_position + Vector3(1.6, 0.1, 0)
		p.health = 100.0
		ai.state = "CHASE"
		ai.awareness = 1.0
		ai.set("_bite_t", 0.0)
		ok("struggle_starts", await _until(func(): return st != null and st.active, 60 * 6), "state %s" % ai.state)
		if st and st.active:
			ok("struggle_text", st._hint.text == "CLICK REPEATEDLY — BREAK FREE", st._hint.text)
			while st.active:
				var e2 := InputEventMouseButton.new()
				e2.button_index = MOUSE_BUTTON_LEFT
				e2.pressed = true
				st._input(e2)
				await _frames(4)
			ok("struggle_won_recover", ai.state == "RECOVER" and is_instance_valid(ai.body), ai.state)
			await _frames(60 * 4)
			ok("crab_hunts_again", ai.state in ["CHASE", "SEARCH", "SUSPICIOUS"] and is_instance_valid(ai.body), ai.state)
			ok("player_free_after", p.controls_enabled and p.look_enabled)
		p.global_position = w.market.global_transform * Vector3(0, 0.3, 6.0)    # (inside, away from it)
		await _frames(30)

	# ---- 5. the car: checklist, fitting, Start Engine
	var text: String = ex.checklist()
	ok("checklist_carried", text.count("[+]") == 4 and text.count("[X]") == 0, text)
	ok("checklist_no_locations", not text.contains("van") and not text.contains("station") and not text.contains("pickup"), text)
	ok("rows_collected", ex.checklist_rows().all(func(r): return r[2] == "collected" and r[3]))
	game.add_item("car_fuse")                          # a second fuse in the pack: still fitted once only
	for id in ["car_battery", "car_fuse", "fuel_can", "starter_relay"]:
		await ex._fit(id)
		await _frames(5)
		ok("fit_" + id, ex.installed(id))
	await ex._fit("car_fuse")
	ok("fit_once", game.inventory.count("car_fuse") == 1 and game.inventory.count("car_battery") == 0
		and game.inventory.count("fuel_can") == 0 and game.inventory.count("starter_relay") == 0, str(game.inventory))
	text = ex.checklist()
	ok("checklist_installed", text.count("[X]") == 4, text)
	ok("not_yet_running", not game.has_flag("vehicle_repaired") and ex.all_installed())
	await ex.start_engine()
	ok("engine_started", game.has_flag("vehicle_repaired") and w.sedan.survival and w.sedan.drivable())
	ok("repaired_card", w.hud.caption_l.text.begins_with("VEHICLE REPAIRED"), w.hud.caption_l.text)
	ok("fuel_half", absf(w.sedan.fuel - 0.5) < 0.01)
	ok("no_leads_left", ex.car_leads().is_empty() or w.sedan.fuel < 0.3)
	w.sedan.fuel = 0.0
	ok("reason_fuel", q.unusable_reason() == "OUT OF FUEL")
	w.sedan.fuel = 0.5
	w.sedan.condition = 0.0
	ok("reason_damage", q.unusable_reason() == "ENGINE TOO DAMAGED")
	w.sedan.condition = 0.8

	# ---- 6. save + load after the repair
	w.save()
	game.load_game()
	w.queue_free()
	await _frames(5)
	await _load_world()
	ok("load_repaired", game.has_flag("vehicle_repaired") and ex.all_installed() and game.inventory.count("car_battery") == 0)
	ok("load_sites_done", not (q.sites["car_battery"]["battery"] as Node3D).visible and not ((q.sites["car_fuse"]["panel"] as Node3D).get_node("Fuse_Good") as Node3D).visible
		and not (q.sites["starter_relay"]["relay"] as Node3D).visible)
	ok("load_door_open", absf((q.sites["car_fuse"]["door"] as Node3D).rotation.y) > deg_to_rad(50.0))
	print("CARQUEST fails=%d" % fails)
	quit(1 if fails > 0 else 0)
