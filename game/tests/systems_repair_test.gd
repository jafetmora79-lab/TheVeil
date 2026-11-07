extends SceneTree
## THE VEIL - in-engine checks for the screenshot-referenced repair (Chapter 7 state, headless, --fixed-fps 60):
##   D menus: Esc never opens Pause over a decision panel / the inventory; Esc closes the inventory; Pause still works
##   H shelter exit: the doors stay shut when walked up to; "Leave Shelter" -> Go Scavenging opens them
##   I threat: a long simulated trip - when each creature first comes, caps hold (<= 2 out, <= 1 hunting)
##   J struggle: one starts on an attack, clicks free the player, control comes back
##   K car: fuel by distance, a knock wears it, empty / wrecked = undrivable, state survives save
##   L parking: the automatic parking from four approaches - on tarmac the whole way, in the stall, time taken
##   O props: boxes / cartons in the store that float above whatever is under them
const DEV := preload("res://game/tools/dev_chapter7.gd")

var w: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		_unblock()
		await process_frame


## A decision panel that opened by itself (a survivor event, a trip summary) pauses the game until answered: the
## test answers it (first option) so it never waits on a paused world.
func _unblock() -> void:
	for c in get_nodes_in_group("veil_choice_panel"):
		if c.has_method("is_open") and c.is_open() and not _testing_choice:
			print("  (answered a panel that opened by itself)")
			c.pick(0)


var _testing_choice := false


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await process_frame
	await process_frame


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await _frames(150)
	var p = w.player
	var hud = w.hud
	var ex = w.expedition
	var choice = w.phase4.choice
	p.controls_enabled = true
	# ---------------- D: menus
	_testing_choice = true
	choice.ask("TEST CHOICE", ["A", "B"], p)
	await _frames(2)
	await _press("pause")
	ok("D_esc_over_choice_no_pause", not hud.is_paused() and choice.is_open(), "paused=%s open=%s" % [hud.is_paused(), choice.is_open()])
	choice.pick(0)
	_testing_choice = false
	await _frames(2)
	ok("D_choice_unpauses", not paused)
	hud.toggle_inventory()
	await _frames(2)
	await _press("pause")
	ok("D_esc_closes_inventory_no_pause", not hud.inv_panel.visible and not hud.is_paused(), "inv=%s paused=%s" % [hud.inv_panel.visible, hud.is_paused()])
	await _press("pause")
	ok("D_pause_opens", hud.is_paused())
	await _press("pause")
	ok("D_pause_closes", not hud.is_paused() and not paused)
	# ---------------- H: shelter doors
	var c5 = w.phase4.chapter5
	var din: Vector3 = w.market.get_node("Doorways/Entrance_Inside").global_position
	p.global_position = din + w.market.global_basis * Vector3(0, 0.1, 2.5)
	await _frames(30)
	p.global_position = din + Vector3(0, 0.1, 0)
	await _frames(90)
	ok("H_doors_stay_shut_on_approach", not c5._doors_open, "doors_open=%s held=%s" % [c5._doors_open, ex.doors_held()])
	_testing_choice = true
	ex._use_exit(null)
	await _frames(3)
	ok("H_leave_menu_opens", choice.is_open())
	choice.pick(1)                                        # Go Scavenging
	await _frames(3)
	if choice.is_open():
		choice.pick(0)                                    # who comes along: alone
	await _frames(30)
	_testing_choice = false
	ok("H_scavenge_opens_doors", c5._doors_open and ex.active(), "doors_open=%s active=%s" % [c5._doors_open, ex.active()])
	# ---------------- I: threat over a long trip (out on the lot)
	p.global_position = w.market.global_transform * Vector3(0, 0.3, -18.0)
	await _frames(10)
	var first := {}
	var max_out := 0
	var max_hunt := 0
	var spawned_kinds := {}
	var seen_ids := {}
	for sec in 1260:                                       # 21 minutes of trip time, one second a frame
		ex._danger(1.0)
		game.play_time += 1.0                            # the play clock keeps pace with the simulated trip
		_unblock()
		await physics_frame
		var hunting := 0
		for c in ex.creatures:
			var n = c.get("node")
			if n == null or not is_instance_valid(n):
				continue
			var id: int = n.get_instance_id()
			if not seen_ids.has(id):
				seen_ids[id] = true
				var k := String(c.get("kind"))
				spawned_kinds[k] = int(spawned_kinds.get(k, 0)) + 1
				if not first.has(k):
					first[k] = sec
			var ai = c.get("ai")
			if ai and is_instance_valid(ai) and String(ai.get("state")) in ["CHASE"]:
				hunting += 1
		max_out = maxi(max_out, ex.creatures.size())
		max_hunt = maxi(max_hunt, hunting)
		if sec % 60 == 59:                                 # keep the player out of reach: the test watches the director
			p.global_position = w.market.global_transform * Vector3(randf_range(-8, 8), 0.3, -18.0)
	print("  threat: first appearance (s) %s, spawned %s, max out %d, max hunting %d" % [str(first), str(spawned_kinds), max_out, max_hunt])
	ok("I_quiet_first_5_min", first.values().all(func(v): return int(v) >= 290) if not first.is_empty() else false, str(first) + " (the game's own clock adds a little)")
	ok("I_encounters_happen", seen_ids.size() >= 2, "%d creatures over 21 min" % seen_ids.size())
	ok("I_cap_two_out", max_out <= 2, str(max_out))
	ok("I_one_hunting", max_hunt <= 1, str(max_hunt))
	ok("I_crab_not_before_15_min", not first.has("crab_hunter") or int(first["crab_hunter"]) >= 900, str(first.get("crab_hunter", "none")))
	# ---------------- J: a struggle
	var st_node = w.get_node_or_null("Struggle")
	var hunter = null
	for c in ex.creatures:
		if c.get("ai") and is_instance_valid(c["ai"]):
			hunter = c["ai"]
			break
	if st_node and hunter:
		p.health = 100.0
		p.controls_enabled = true
		for i in 600:
			if not root.get_node("Dialogue").is_busy():
				break
			_unblock()
			await process_frame
		var started := false
		for i in 60:
			st_node._cool = 0.0
			if st_node.try_start(hunter):
				started = true
				break
		ok("J_struggle_starts", started)
		if started:
			ok("J_control_held", not p.controls_enabled)
			for i in 30:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT
				mb.pressed = true
				st_node._input(mb)                        # (headless: the click straight to the struggle's handler)
				await _frames(3)
				var mr := InputEventMouseButton.new()
				mr.button_index = MOUSE_BUTTON_LEFT
				mr.pressed = false
				st_node._input(mr)
				await _frames(3)
				if not st_node.active:
					break
			await _frames(150)                             # (after a win the view eases back before control returns)
			ok("J_struggle_won_control_back", not st_node.active and p.controls_enabled and p.look_enabled, "active=%s controls=%s" % [st_node.active, p.controls_enabled])
			ok("J_creature_released", hunter.hold == false and String(hunter.state) == "RECOVER", String(hunter.state))
	else:
		ok("J_struggle_available", false, "no struggle controller / hunter (struggle=%s hunter=%s)" % [st_node, hunter])
	# ---------------- K: car fuel and wear
	var car = w.sedan
	game.flags["vehicle_repaired"] = true
	await _frames(3)
	ok("K_survival_on", car.survival)
	var fuel0: float = car.fuel
	w.in_car = true
	p.activate(false)
	car.set_driven(true)
	car.autopilot = func(_dt): return Vector3(1.0, 0.0, 0.0)      # the driver's throttle (not a scripted drive)
	await _frames(240)
	car.autopilot = Callable()
	ok("K_fuel_used_by_distance", car.fuel < fuel0, "%.3f -> %.3f" % [fuel0, car.fuel])
	car.fuel = 0.0
	ok("K_empty_undrivable", not car.drivable())
	car.fuel = 0.5
	car.condition = 0.0
	ok("K_wrecked_undrivable", not car.drivable())
	car.condition = 0.7
	var sstate: Dictionary = car.state()
	car.fuel = 1.0
	car.condition = 1.0
	car.restore(sstate)
	ok("K_state_saved", absf(car.fuel - 0.5) < 0.01 and absf(car.condition - 0.7) < 0.01)
	car.set_driven(false)
	w.in_car = false
	p.activate(true)
	game.flags.erase("vehicle_repaired")
	await _frames(3)
	# ---------------- L: automatic parking from four approaches
	var L: Transform3D = w._park_lot_xf()
	var approaches := [["from the west driveway, slow", Vector3(20.0, 0, 8.0), Vector3(-1, 0, 0), 4.0],
		["from the west, fast", Vector3(22.0, 0, 9.5), Vector3(-1, 0, 0), 11.0],
		["from Main St, turning in", Vector3(6.0, 0, 6.0), Vector3(-0.5, 0, 1), 6.0],
		["from the east", Vector3(-12.0, 0, 9.0), Vector3(1, 0, 0), 5.0]]
	for a in approaches:
		game.flags.erase("auto_parked")
		game.flags.erase("parked")
		game.flags["entered_car"] = true
		var pos: Vector3 = L * (a[1] as Vector3)
		var gh = w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 5, 0), pos - Vector3(0, 5, 0), 1, [car.get_rid()]))
		pos.y = ((gh["position"] as Vector3).y if gh else 0.15) + 0.05
		var fwd: Vector3 = (L.basis * (a[2] as Vector3)).normalized()
		car.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
		car.velocity = Vector3.ZERO
		car.parking_brake = false
		w.in_car = true
		p.activate(false)
		car.set_driven(true)
		car.speed = float(a[3])
		await _frames(2)
		var t0 := Time.get_ticks_msec()
		w._auto_park()
		var off := 0
		var frames := 0
		while w._auto_parking and frames < 60 * 50:
			_unblock()
			await physics_frame
			frames += 1
			if not w.car_on_asphalt():
				off += 1
		await _frames(150)
		var endp: Vector3 = w.park_paths()["reverse"][-1]
		var err := Vector2(car.global_position.x - endp.x, car.global_position.z - endp.z).length()
		ok("L_park_" + String(a[0]).replace(" ", "_").replace(",", ""), err < 0.6 and w.park_report.get("placed", false) == false and off == 0,
			"%.1f s, %d frames off tarmac, end %.2f m from the stall, faded=%s report=%s" % [frames / 60.0, off, err, str(w.park_report.get("placed", false)), str(w.park_report)])
		if w.in_car:
			w.exit_car()
		await _frames(5)
	# ---------------- O: floating boxes / cartons in the store
	var space = w.get_world_3d().direct_space_state
	var floaters: Array = []
	for mi in w.market.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name).to_lower()
		if not (nm.contains("box") or nm.contains("carton") or nm.contains("crate")):
			continue
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		var base := Vector3(a.get_center().x, a.position.y, a.get_center().z)
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.05, 0), base - Vector3(0, 3.0, 0), 1))
		var gap: float = (base.y - (hit["position"] as Vector3).y) if hit else 9.0
		if gap > 0.05:
			floaters.append("%s %.2fm" % [mi.name, gap])
	print("  floating box-like meshes: %d %s" % [floaters.size(), str(floaters.slice(0, 12))])
	print("SYSTEMS fails=%d" % fails)
	quit(1 if fails > 0 else 0)
