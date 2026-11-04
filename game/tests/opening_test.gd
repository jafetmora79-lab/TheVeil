extends SceneTree
## THE VEIL - automated playthrough of the opening (Phase 1) and the town errands (Phase 2) (no screenshots).
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/opening_test.gd -- [cruise_kmh]
## Runs the real World scene and the real player / vehicle controllers. The car is driven by a simple
## pure-pursuit autopilot along the road centreline (world_data.json route) at a capped "normal" speed,
## slowing for bends, so the measured drive time comes from actual road distance and vehicle physics.
## Prints "TEST <name> PASS|FAIL detail" lines and a final "RESULT".

var world: Node
var fails := 0
var cruise := 13.0      # m/s


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func press_interact() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	root.push_input(event)


## Stand `dist` m from the interactable (horizontal, along `from_dir`) and look at it through the real player ray.
func aim_at(player, it: Node3D, from_dir: Vector3, dist := 1.3) -> bool:
	var c: Vector3 = it.global_transform * (it.get_child(0) as Node3D).position
	var feet := c + from_dir.normalized() * dist
	player.global_position = Vector3(feet.x, it.get_parent_node_3d().get_parent_node_3d().global_position.y + 0.06, feet.z)
	player.velocity = Vector3.ZERO
	await frames(3)
	var eye: Vector3 = player.camera.global_position
	var d := (c - eye).normalized()
	player.set_yaw_pitch(atan2(-d.x, -d.z), asin(clampf(d.y, -1.0, 1.0)))
	await frames(4)
	return player._focus == it


## Really walk (move_forward held) from `a` toward `b`; returns how far past `a` the player got along a->b.
func walk(player, a: Vector3, b: Vector3, seconds := 2.0) -> float:
	player.global_position = a
	player.velocity = Vector3.ZERO
	var d := (b - a) * Vector3(1, 0, 1)
	player.set_yaw_pitch(atan2(-d.x, -d.z), 0.0)
	await frames(2)
	Input.action_press("move_forward")
	await frames(int(seconds * 60))
	Input.action_release("move_forward")
	await frames(10)
	return (player.global_position - a).dot(d.normalized())


## Try a few approach directions (market-local) until the player's ray lands on `it`.
func aim_any(player, it: Node3D, mk: Node3D, dirs: Array, dist := 1.2) -> bool:
	for d in dirs:
		if await aim_at(player, it, mk.global_transform.basis * d, dist):
			return true
	return false


func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


## Phase 4 (Act I, first night): every step, the flashlight, the choice, the threat (once), sleep, save / load.
func phase4_tests(game, ps: PackedScene) -> void:
	var mk: Node3D = world.market
	var player = world.player
	var p4 = world.phase4
	ok("p4_started", p4 != null and game.has_flag("p4_started") and game.current_step().get("id", "") == "p4_flashlight",
		game.current_step().get("id", ""))
	var lit := 0
	for l in mk.get_node("Lights").get_children():
		if l is Light3D and l.visible:
			lit += 1
	ok("p4_power_out", lit == 0, "lit=%d" % lit)
	ok("p4_hound_in_build", ResourceLoader.exists(p4.HOUND_PATH))
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	# flashlight + batteries at customer service
	var fl: Interactable = p4.its["flashlight"]
	ok("p4_flashlight_reach", await aim_any(player, fl, mk, [Z, -Z, X, -X], 0.9))
	fl.interact(player)
	await frames(20)
	ok("p4_flashlight", game.has_flag("p4_flashlight") and game.has_item("flashlight") and p4.flashlight != null
		and p4.flashlight.on and p4.flashlight.spot.visible)
	var bp: Interactable = p4.its["batteries"]
	ok("p4_batteries_reach", await aim_any(player, bp, mk, [Z, -Z, X, -X], 0.9))
	bp.interact(player)
	await frames(10)
	ok("p4_batteries", p4.flashlight.spares == 2, "spares=%d" % p4.flashlight.spares)
	var c0: float = p4.flashlight.charge
	await frames(240)
	var c1: float = p4.flashlight.charge
	ok("p4_battery_drains", c1 < c0 and c1 > 0.95, "%.4f -> %.4f" % [c0, c1])
	p4.flashlight.set_on(false)
	await frames(120)
	ok("p4_no_drain_when_off", absf(p4.flashlight.charge - c1) < 1e-6 and not p4.flashlight.spot.visible)
	p4.flashlight.charge = 0.05
	ok("p4_battery_swap", p4.flashlight.reload() and p4.flashlight.charge == 1.0 and p4.flashlight.spares == 1)
	p4.flashlight.set_on(true)
	ok("p4_flashlight_saved", game.world_state.get("flashlight", {}).get("spares", -1) == 1)
	# staff door into the back room
	var staff: Interactable = p4.its["INT_Door_Staff"]
	ok("p4_staff_door_reach", await aim_any(player, staff, mk, [-Z], 1.3))
	staff.interact(player)
	await frames(40)
	ok("p4_staff_door_opens", staff.is_open)
	# breaker
	var br: Interactable = p4.its["breaker"]
	ok("p4_breaker_reach", await aim_any(player, br, mk, [-X], 1.1))
	br.interact(player)
	await frames(60 * 4)
	var em := 0
	var flick := 0
	for l in mk.get_node("Lights").get_children():
		if l is Light3D and l.visible:
			em += 1
			if l.light_energy < p4._base[l.name] * 0.5:
				flick += 0
			for c in l.get_children():
				if c.get_script() == p4.FLICKER:
					flick += 1
	ok("p4_breaker", game.has_flag("p4_breaker") and em >= 6 and flick >= 2, "lit=%d flicker=%d" % [em, flick])
	ok("p4_still_dim", mk.get_node("Lights/Light_SALES_00").light_energy < 0.4)
	# loading bay: pull the door down, then the pallets
	var lh: Interactable = p4.its["loading"]
	ok("p4_loading_reach", await aim_any(player, lh, mk, [-X], 1.0))
	lh.interact(player)
	await frames(120)
	ok("p4_loading_down", game.has_flag("p4_loading_down"))
	var lp: Interactable = p4.its["pallet_loading"]
	ok("p4_loading_pallet_reach", await aim_any(player, lp, mk, [-X, -Z], 1.4))
	lp.interact(player)
	await frames(120)
	ok("p4_loading_secured", game.has_flag("p4_loading_secured"))
	# rear exit: pallets refuse until the door is closed
	var bpal: Interactable = p4.its["pallet_back"]
	ok("p4_back_pallet_reach", await aim_any(player, bpal, mk, [-Z, X], 1.4))
	bpal.interact(player)
	await frames(10)
	ok("p4_needs_door_closed_first", not game.has_flag("p4_backexit_secured"))
	var bd: Interactable = p4.its["backdoor"]
	ok("p4_backdoor_reach", await aim_any(player, bd, mk, [-Z], 1.2))
	bd.interact(player)
	await frames(60)
	bpal.interact(player)
	await frames(120)
	ok("p4_exits_secured", game.has_flag("p4_backexit_secured") and game.has_flag("p4_exits_secured")
		and game.current_step().get("id", "") == "p4_talk", game.current_step().get("id", ""))
	# save / load mid-chapter: state rebuilt from flags, nothing replayed
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(40)
	p4 = world.phase4
	mk = world.market
	player = world.player
	ok("p4_load_mid", p4 != null and p4.flashlight != null and p4.flashlight.spares == 1 and p4.threat_runs == 0
		and mk.get_node("Lights/Light_SALES_00").visible and p4._pallets["back"].position.distance_to(p4.BACK_PALLET[1]) < 0.01
		and p4.its["fl" + "ashlight"].taken)
	var veil: Node = world.atmos.get_node_or_null("Atmosphere") if world.atmos else null
	ok("p4_load_keeps_veil", veil != null and int(veil.get("state")) == 3, "state=%s" % (str(veil.get("state")) if veil else "none"))
	ok("p4_old_talk_prompts_gone", not world.interactables.has("shop/eddie") and not world.interactables.has("p3/marcus"))
	# the argument: choose Noah
	var ed: Interactable = p4.its["npc_Eddie"]
	ok("p4_eddie_reach", await aim_any(player, ed, mk, [Z, -Z, X], 1.4))
	ed.interact(player)
	ok("p4_choice_offered", await wait_until(func(): return p4.choice.is_open(), 60 * 40))
	p4.choice.pick(1)
	ok("p4_choice_recorded", await wait_until(func(): return game.has_flag("p4_talk_done"), 60 * 20)
		and game.has_flag("p4_choice_noah") and not game.has_flag("p4_choice_wait"))
	# something outside, once
	ok("p4_threat_starts", await wait_until(func(): return p4.threat_runs == 1, 60 * 10))
	ok("p4_hound_silhouette", p4.hound != null and is_instance_valid(p4.hound))
	# it must walk the way it faces (the model's front is +Z), not backwards
	var h0: Vector3 = p4.hound.position
	await frames(30)
	var hmove: Vector3 = (p4.hound.position - h0) * Vector3(1, 0, 1)
	var hface: Vector3 = p4.hound.transform.basis.z.normalized()
	ok("p4_hound_walks_forward", hmove.length() > 0.2 and hmove.normalized().dot(hface) > 0.9,
		"move=%s face=%s" % [hmove, hface])
	ok("p4_threat_done", await wait_until(func(): return game.has_flag("p4_threat_done"), 60 * 40))
	p4._run_threat()
	await frames(5)
	ok("p4_threat_once", p4.threat_runs == 1)
	# sleep in the office
	var od: Interactable = p4.its["INT_Door_Office"]
	ok("p4_office_door_reach", await aim_any(player, od, mk, [-Z], 1.3))
	od.interact(player)
	await frames(40)
	var rp: Interactable = p4.rest.interactable
	ok("p4_rest_reach", await aim_any(player, rp, mk, [X, -X], 1.2))
	rp.interact(player)
	ok("p4_rest_confirm", await wait_until(func(): return p4.choice.is_open(), 60))
	p4.choice.pick(0)
	ok("p4_slept", await wait_until(func(): return game.has_flag("p4_slept"), 60 * 6) and game.world_state.get("day", "") == "saturday")
	ok("p4_end_card", await wait_until(func(): return world.hud.end_panel.visible, 60 * 15))
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(40)
	ok("p4_load_end", world.phase4 != null and world.phase4.threat_runs == 0 and game.has_flag("p4_slept")
		and world.phase4.rest.interactable.prompt_text == "" and game.has_flag("p4_choice_noah"))


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		cruise = float(args[0]) / 3.6
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	var interaction: Script = load("res://game/interaction/interactable.gd")
	game.new_game()
	game.delete_save()
	var ps: PackedScene = load("res://game/scenes/World.tscn")
	ok("world_loads", ps != null)
	world = ps.instantiate()
	root.add_child(world)
	await frames(10)
	var home: Node3D = world.home
	var player = world.player
	var sedan = world.sedan
	# ---- assets present (real models, not primitives)
	var houses: Node = world.get_node("Residential/Houses")
	ok("houses", houses.get_child_count() >= 60, "count=%d" % houses.get_child_count())
	ok("home_furniture", home.get_node("Furniture").get_child_count() >= 40, "pieces=%d" % home.get_node("Furniture").get_child_count())
	var meshes := world.find_children("*", "MeshInstance3D", true, false).size()
	ok("mesh_instances", meshes > 1500, "count=%d" % meshes)
	var mm := world.get_node("Scatter").get_child_count()
	ok("woods_multimesh", mm > 10, "nodes=%d" % mm)
	ok("sedan_model", sedan._wheels.size() == 4 and sedan._sw != null and sedan._door != null)
	ok("interactables", world.interactables.size() >= 10, "count=%d" % world.interactables.size())
	# ---- wake up in the bedroom (wait for the sequence)
	await frames(60 * 9)
	ok("player_in_bedroom", player.global_position.distance_to((home.get_node("Markers/Spawn_WakeUp") as Node3D).global_position) < 0.6)
	ok("controls_after_wake", player.controls_enabled)
	ok("objective_kitchen", game.current_step().get("id", "") == "check_kitchen")
	# ---- collision: a closed bedroom door blocks the player
	var bd = world.interactables.get("home/INT_Door_Bedroom")
	ok("bedroom_door", bd != null)
	if bd:
		var door := bd.target as Node3D
		var p_in := door.global_transform * Vector3(0.45, 0.0, 0.9)
		var p_out := door.global_transform * Vector3(0.45, 0.0, -0.9)
		var side_in := p_in if p_in.distance_to(player.global_position) < p_out.distance_to(player.global_position) else p_out
		var side_out := p_out if side_in == p_in else p_in
		player.global_position = Vector3(side_in.x, player.global_position.y, side_in.z)
		await frames(2)
		var col: KinematicCollision3D = player.move_and_collide(Vector3(side_out.x - side_in.x, 0, side_out.z - side_in.z), true)
		ok("closed_door_blocks", col != null)
		bd.interact(player)
		await frames(40)
		ok("door_opens", bd.is_open and absf((door.transform.basis.get_euler().y - bd._base.basis.get_euler().y)) > 1.0)
		col = player.move_and_collide(Vector3(side_out.x - side_in.x, 0, side_out.z - side_in.z), true)
		ok("open_door_passable", col == null or col.get_travel().length() > 1.2)
	# ---- walls: walk into an exterior wall for 2 s, must stay inside the house footprint
	# ---- car refuses without keys / kitchen
	world.enter_car()
	await frames(5)
	ok("car_needs_keys", not world.in_car)
	# ---- refrigerator
	var fr = null
	for k in world.interactables:
		if world.interactables[k].label == "Refrigerator":
			fr = world.interactables[k]
	ok("fridge_found", fr != null)
	if fr:
		player.global_position = fr.global_position + (fr.global_transform.basis.z * 1.2)
		var fbody := home.find_child("Fridge_Retro_01", true, false) as Node3D
		var door_c := func() -> float:
			var d := fr.target as Node3D
			return (fbody.global_transform.affine_inverse() * (d.global_transform * interaction.aabb_of(d).get_center())).z
		var z_closed: float = door_c.call()
		fr.interact(player)
		await frames(40)
		ok("fridge_opens", fr.is_open)
		ok("fridge_swings_outward", door_c.call() > z_closed + 0.1, "front z %.2f -> %.2f" % [z_closed, door_c.call()])
		var swung_in := 0
		var names := []
		for k in world.interactables:
			var it = world.interactables[k]
			if it.kind == "hinge" and k.contains("Furniture/"):
				var fb := it.target as Node3D
				while fb.get_parent().name != "Furniture":
					fb = fb.get_parent()
				var body: Vector3 = fb.global_transform * interaction.aabb_of(fb).get_center()
				var c0: float = (it.target.global_transform * interaction.aabb_of(it.target).get_center()).distance_to(body)
				it.set_open(true, true)
				var c1: float = (it.target.global_transform * interaction.aabb_of(it.target).get_center()).distance_to(body)
				it.set_open(k.contains("Fridge"), true)
				if c1 < c0 - 0.01:
					swung_in += 1
					names.append(k.get_file())
		ok("furniture_doors_swing_outward", swung_in == 0, "inward=%d %s" % [swung_in, names])
		ok("fridge_flag", game.has_flag("fridge_checked"))
		ok("objective_keys", game.current_step().get("id", "") == "find_keys", game.current_step().get("text", ""))
		var fridge_body := home.find_child("Fridge_Retro_01", true, false) as Node3D
		var inside := fridge_body.find_children("*", "MeshInstance3D", true, false).size()
		ok("fridge_contents", inside >= 3, "meshes=%d" % inside)
	# ---- keys
	var keys = null
	for k in world.interactables:
		if world.interactables[k].item_id == "car_keys":
			keys = world.interactables[k]
	ok("keys_found", keys != null)
	if keys:
		keys.interact(player)
		await frames(20)
		ok("keys_in_inventory", game.has_item("car_keys"))
		ok("objective_leave", game.current_step().get("id", "") == "leave_house")
	# ---- front door + leaving
	var fd = world.interactables.get("home/INT_Door_Front")
	ok("front_door", fd != null)
	if fd:
		fd.interact(player)
		await frames(40)
		ok("front_door_opens", fd.is_open)
	var trig := world.get_node("Trigger_LeftHouse") as Area3D
	player.global_position = trig.global_position + Vector3(0, -0.6, 0)
	await frames(10)
	ok("left_house", game.has_flag("left_house"))
	ok("objective_car", game.current_step().get("id", "") == "enter_car")
	# ---- enter the sedan
	player.global_position = sedan.global_transform * Vector3(-1.6, 0.1, -0.3)
	await frames(5)
	world.enter_car()
	await frames(60)
	ok("in_car", world.in_car and sedan.driven and sedan.driver_cam.current)
	ok("objective_drive", game.current_step().get("id", "") == "drive")
	press_interact()
	await frames(45)
	ok("exit_driveway", not world.in_car and player.is_on_floor())
	world.enter_car()
	await frames(45)
	ok("reenter_driveway", world.in_car and sedan.driven)
	# ---- drive the route
	var route: Array = world.data["route"]
	var st := {"idx": 0}
	var stuck := 0.0
	var last_pos: Vector3 = sedan.global_position
	var t := 0.0
	var max_kmh := 0.0
	var min_clear := 99.0
	sedan.autopilot = func(delta: float) -> Vector3:
		var p: Vector3 = sedan.global_position
		var p2 := Vector2(p.x, p.z)
		var idx: int = st["idx"]
		while idx < route.size() - 1 and p2.distance_to(Vector2(route[idx][0], route[idx][1])) < 9.0:
			idx += 1
		st["idx"] = idx
		var tgt := Vector2(route[idx][0], route[idx][1])
		var local: Vector3 = sedan.global_transform.affine_inverse() * Vector3(tgt.x, p.y, tgt.y)
		var ang := atan2(-local.x, -local.z)
		var steer_in := clampf(ang * 2.2, -1.0, 1.0)
		# look ahead ~30 m for bends: slow down so lateral acceleration stays below ~2.5 m/s^2
		var turn := 0.0
		var acc_len := 0.0
		for j in range(idx, mini(idx + 30, route.size() - 1)):
			var a := Vector2(route[j + 1][0] - route[j][0], route[j + 1][1] - route[j][1])
			var b := Vector2(route[mini(j + 2, route.size() - 1)][0] - route[j + 1][0], route[mini(j + 2, route.size() - 1)][1] - route[j + 1][1])
			acc_len += a.length()
			if acc_len > 30.0:
				break
			if b.length() > 0.01:
				turn = maxf(turn, absf(a.angle_to(b)) / maxf(acc_len, 6.0) * 10.0)
		var want := cruise
		if turn > 0.08:
			want = minf(want, clampf(7.5 / (turn * 1.4), 4.0, cruise))
		if idx >= route.size() - 3:
			var dist_end := p2.distance_to(Vector2(route[-1][0], route[-1][1]))
			want = minf(want, dist_end * 0.6)
			if dist_end < 2.5:
				want = 0.0
		var thr := clampf((want - sedan.speed) * 0.8, 0.0, 1.0)
		var brk := clampf((sedan.speed - want) * 0.6, 0.0, 1.0)
		return Vector3(thr, brk, steer_in)
	while t < 240.0 and not game.has_flag("parked"):
		await physics_frame
		t += 1.0 / 60.0
		max_kmh = maxf(max_kmh, sedan.speed * 3.6)
		if fmod(t, 1.0) < 1.0 / 60.0:
			if sedan.global_position.distance_to(last_pos) < 0.3 and st["idx"] < route.size() - 3:
				stuck += 1.0
			else:
				stuck = 0.0
			last_pos = sedan.global_position
			if stuck > 4.0:
				print("STUCK at ", sedan.global_position, " idx ", st["idx"])
				break
	ok("reached_town", game.has_flag("reached_town"))
	ok("parked", game.has_flag("parked"), "drive_time=%.1f s, autopilot_time=%.1f s, max=%.0f km/h, cruise=%.0f km/h, route_idx=%d/%d" % [world.drive_time, t, max_kmh, cruise * 3.6, st["idx"], route.size()])
	ok("drive_over_60s", world.drive_time >= 60.0, "%.1f s" % world.drive_time)
	print("DRIVE_TIME %.2f CRUISE_KMH %.1f ROUTE_M %.1f" % [world.drive_time, cruise * 3.6, world.data["route_length_m"]])
	# ---- exit + save / load
	sedan.autopilot = Callable()
	await frames(30)
	press_interact()
	await frames(60)
	ok("exit_car", not world.in_car and player.visible and player.controls_enabled and player.camera.current)
	world.enter_car()
	await frames(45)
	ok("reenter_car", world.in_car and sedan.driven and sedan.driver_cam.current)
	var obstacle := StaticBody3D.new()
	var obstacle_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.5, 0.7)
	obstacle_shape.shape = box
	obstacle.add_child(obstacle_shape)
	world.add_child(obstacle)
	obstacle.global_position = sedan.global_transform * Vector3(-1.6, 0.75, -0.3)
	await frames(4)
	press_interact()
	await frames(60)
	ok("exit_fallback", not world.in_car and sedan.to_local(player.global_position).x > 0.0)
	obstacle.queue_free()
	# ---- save / load, and a reload while sitting in the car (before the errands)
	world.save()
	ok("save_exists", game.has_save())
	var ok_load: bool = game.load_game()
	ok("load", ok_load and game.has_item("car_keys") and game.has_flag("parked") and game.world_state.size() > 0)
	world.enter_car()
	await frames(45)
	world.save()
	var saved_in_car: bool = game.load_game() and game.player_state.get("in_vehicle", false)
	ok("saved_in_car", saved_in_car)
	if saved_in_car:
		world.free()
		game.load_requested = true
		world = ps.instantiate()
		root.add_child(world)
		await frames(15)
		ok("restored_in_car", world.in_car and world.sedan.driven)
		press_interact()
		await frames(60)
		ok("exit_after_reload", not world.in_car and world.player.camera.current and world.player.is_on_floor())
	player = world.player
	sedan = world.sedan
	home = world.home
	# ---- Phase 2: the errands (either order; this run does the game shop first)
	await frames(10)
	var mk: Node3D = world.market
	var gs: Node3D = world.game_shop
	ok("objective_errands", game.current_step().get("id", "") == "buy_groceries", game.current_step().get("text", ""))
	# game shop entrance door: closed blocks, opens inward, then passable
	var sd = world.interactables.get("shop/entrance")
	ok("shop_door", sd != null)
	var s_out: Vector3 = (gs.get_node("Doorways/Entrance_Outside") as Node3D).global_position + Vector3(0, 0.1, 0)
	var s_in: Vector3 = (gs.get_node("Doorways/Entrance_Inside") as Node3D).global_position + Vector3(0, 0.1, 0)
	player.global_position = s_out
	await frames(3)
	var hit: KinematicCollision3D = player.move_and_collide(s_in - s_out, true)
	ok("shop_door_closed_blocks", hit != null)
	if sd:
		sd.interact(player)
		await frames(45)
		var dc: Vector3 = sd.target.global_transform * interaction.aabb_of(sd.target).get_center()
		ok("shop_door_opens_inward", sd.is_open and gs.to_local(dc).z > 0.6, "door centre local z=%.2f" % gs.to_local(dc).z)
	player.global_position = s_out
	await frames(3)
	var shop_walk: float = await walk(player, s_out, s_in)
	ok("shop_door_passable", shop_walk > (s_in - s_out).length() - 0.1, "walked %.2f of %.2f m" % [shop_walk, (s_in - s_out).length()])
	var eddie_it = world.interactables.get("shop/eddie")
	ok("eddie_present", world.eddie != null and world.eddie.find_children("*", "Skeleton3D", true, false).size() == 1)
	var ea = world.animators["Eddie"]
	await frames(5)
	ok("eddie_arms_down", ea.arm_angle_from_down("Left") < 25.0 and ea.arm_angle_from_down("Right") < 25.0,
		"L %.0f R %.0f deg from straight down" % [ea.arm_angle_from_down("Left"), ea.arm_angle_from_down("Right")])
	ok("eddie_faces_customers", ea.world_forward().dot(-gs.global_transform.basis.z) > 0.9, str(ea.world_forward()))
	# look-at: stand off to Eddie's side, his head turns toward the camera
	player.global_position = world.eddie.global_position + gs.global_transform.basis * Vector3(-1.8, 0.0, -1.2)
	await frames(60)
	var gaze: Vector3 = ea.world_forward().rotated(Vector3.UP, ea._look.x)
	var to_p: Vector3 = (player.global_position - world.eddie.global_position) * Vector3(1, 0, 1)
	ok("eddie_looks_at_player", rad_to_deg(gaze.angle_to(to_p.normalized())) < 25.0,
		"gaze off by %.0f deg (head yaw %.2f, body turned %s)" % [rad_to_deg(gaze.angle_to(to_p.normalized())), ea._look.x, ea.world_forward()])
	ok("eddie_face", world.eddie_face != null and world.eddie_face._mat != null)
	ok("eddie_talk_reach", await aim_at(player, eddie_it, -gs.global_transform.basis.z, 1.75))
	var game_it = world.interactables.get("shop/horror_game")
	ok("game_rack_reach", await aim_at(player, game_it, gs.global_transform.basis.x, 0.9))
	eddie_it.interact(player)
	await frames(10)
	ok("eddie_needs_game", not game.has_flag("game_bought"))
	game_it.interact(player)
	await frames(10)
	ok("game_picked", game.has_item("horror_game"))
	eddie_it.interact(player)
	var max_fore := 0.0
	for i in 40:
		await frames(3)
		var sk: Skeleton3D = ea.skel
		for side in ["Left", "Right"]:
			var d: Vector3 = (sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin - sk.get_bone_global_pose(sk.find_bone(side + "LowerArm")).origin).normalized()
			max_fore = maxf(max_fore, rad_to_deg(d.angle_to(-ea.U)))
	ok("eddie_gestures_while_talking", max_fore > 30.0, "forearm up to %.0f deg" % max_fore)
	ok("game_bought", game.has_flag("game_bought"))
	ok("eddie_talks", world.eddie_face._talk_left > 0.0)
	ok("objective_still_groceries", game.current_step().get("id", "") == "buy_groceries")
	# supermarket: auto doors
	var leaf := mk.get_node("Building").find_child("INT_AutoDoor_Entrance_L", true, false) as Node3D
	var leaf0 := leaf.position
	var m_out: Vector3 = (mk.get_node("Doorways/Entrance_Outside") as Node3D).global_position + Vector3(0, 0.1, 0)
	var m_in: Vector3 = (mk.get_node("Doorways/Entrance_Inside") as Node3D).global_position + Vector3(0, 0.1, 0)
	player.global_position = m_out + (m_out - m_in).normalized() * 3.0
	await frames(30)
	ok("auto_doors_closed_far", leaf.position.distance_to(leaf0) < 0.01)
	player.global_position = m_out
	await frames(60)
	ok("auto_doors_open", leaf.position.distance_to(leaf0) > 1.0, "leaf moved %.2f m" % leaf.position.distance_to(leaf0))
	var market_walk: float = await walk(player, m_out, m_in)
	ok("market_entrance_passable", market_walk > (m_in - m_out).length() - 0.1, "walked %.2f of %.2f m" % [market_walk, (m_in - m_out).length()])
	player.global_position = m_out + (m_out - m_in).normalized() * 6.0
	await frames(40)
	var lot: Vector3 = player.global_position
	var lot_walk: float = await walk(player, lot, m_in, 4.0)
	ok("market_walk_from_lot_over_curb", lot_walk > (m_in - lot).length() - 0.1, "walked %.2f of %.2f m, end y %.2f" % [lot_walk, (m_in - lot).length(), player.global_position.y])
	# checkout refuses an empty basket
	var pay = world.interactables.get("market/cashier")
	ok("cashier_faces_aisle", world.animators["Cashier"].world_forward().dot(mk.global_transform.basis.x) > 0.9)
	ok("cashier_present", world.cashier != null and world.cashier.visible and world.faces.has("Cashier") and world.faces["Cashier"]._mat != null)
	ok("cashier_reach", await aim_at(player, pay, ((mk.get_node("NavTargets/Checkout_4") as Node3D).global_position - pay.global_position) * Vector3(1, 0, 1), 1.6))
	pay.interact(player)
	await frames(5)
	ok("checkout_needs_items", not game.has_flag("groceries_done"))
	var reach_fail := []
	for id in ["canned_food", "energy_snack", "water_bottle"]:
		var gi = world.interactables["market/" + id]
		var lp: Vector3 = mk.to_local(gi.global_position)
		var gx := -11.5 + 3.0 * roundf((lp.x + 11.5) / 3.0)
		var outward: Vector3 = mk.global_transform.basis * Vector3(signf(lp.x - gx), 0, 0)
		if not await aim_at(player, gi, outward, 0.95):
			reach_fail.append(id)
		ok("grocery_glow_" + id, gi.target.find_children("*", "GeometryInstance3D", true, false)[0].material_overlay != null)
		gi.interact(player)
		await frames(15)
	ok("groceries_reachable", reach_fail.is_empty(), str(reach_fail))
	ok("groceries_picked", game.has_item("canned_food") and game.has_item("water_bottle") and game.has_item("energy_snack"))
	pay.interact(player)
	await frames(10)
	ok("checkout", game.has_flag("groceries_done") and game.has_item("groceries") and not game.has_item("canned_food"))
	ok("objective_go_home", game.current_step().get("id", "") == "go_home")
	# ---- Phase 3: the Veil arrives (still inside the supermarket after paying: nothing yet)
	await frames(20)
	ok("p3_waits_indoors", not game.has_flag("p3_mist"))
	player.global_position = m_out + (m_out - m_in).normalized() * 4.0
	await frames(20)
	ok("p3_mist_starts_outdoors", game.has_flag("p3_mist") and world.atmos != null)
	ok("p3_cashier_gone", not world.cashier.visible)
	await frames(60 * 7)
	ok("p3_colossus_glimpse", world.get_node_or_null("Colossus_Glimpse") != null and world._cine != null)
	await frames(60 * 9)
	ok("p3_tentacles", world._tentacles.size() == 3)
	ok("p3_view_returned", world._cine == null and player.camera.current and player.controls_enabled)
	var t0: Node3D = world._tentacles[0]
	player.global_position = t0.global_position + Vector3(1.0, 0.1, 0.0)
	await frames(30)
	var kd: float = Vector2(player.global_position.x - t0.global_position.x, player.global_position.z - t0.global_position.z).length()
	ok("p3_tentacle_knockback", kd > 1.6, "%.2f m" % kd)
	player.global_position = sedan.global_transform * Vector3(-1.6, 0.1, -0.3)
	await frames(10)
	world.enter_car()
	await frames(30)
	ok("p3_car_dead", not world.in_car and game.has_flag("phase2_done") and game.current_step().get("id", "") == "mist_shop", game.current_step().get("id", ""))
	ok("p3_marcus_in_shop", world.marcus != null and world.marcus.get_parent() == gs and world.faces["Marcus"]._mat != null)
	ok("p3_shop_door_held", sd.is_open)
	ok("p3_npcs_scared", world.animators["Eddie"].mood == "scared" and world.animators["Marcus"].mood == "scared")
	var leg_min := 999.0
	var leg_max := -999.0
	for i in 24:
		await frames(15)
		var es: Skeleton3D = world.animators["Eddie"].skel
		var ld: Vector3 = (es.get_bone_global_pose(es.find_bone("LeftLowerLeg")).origin - es.get_bone_global_pose(es.find_bone("LeftUpperLeg")).origin).normalized()
		var a: float = rad_to_deg(ld.signed_angle_to(-world.animators["Eddie"].U, world.animators["Eddie"].R))
		leg_min = minf(leg_min, a)
		leg_max = maxf(leg_max, a)
	var e_end: Vector3 = world.eddie.position
	ok("p3_eddie_walks_to_door", e_end.distance_to(Vector3(-2.2, 0.04, 1.3)) < 0.3, str(e_end))
	ok("p3_walk_cycle_legs", leg_max - leg_min > 20.0, "thigh swing %.0f deg" % (leg_max - leg_min))
	player.global_position = s_in + gs.global_transform.basis.z * 1.5
	await frames(20)
	ok("p3_in_shop", game.has_flag("p3_in_shop"))
	await frames(60 * 27)
	ok("p3_shop_talk_done", world._p3_shop_talked)
	player.global_position = s_out + (s_out - s_in).normalized() * 3.0
	await frames(10)
	ok("p3_npcs_to_market", world.eddie.get_parent() == mk and world.marcus.get_parent() == mk)
	player.global_position = mk.global_transform * Vector3(0, 0.2, 5.5)
	await frames(60)
	ok("p3_in_market", game.has_flag("p3_in_market") and leaf.position.distance_to(leaf0) > 1.0 and game.current_step().get("id", "") == "mist_doors")
	var shut = world.interactables["market/doors_shut"]
	ok("p3_doors_reach", await aim_at(player, shut, mk.global_transform.basis.z, 1.6))
	shut.interact(player)
	await frames(60 * 7)
	ok("p3_end", game.has_flag("p3_doors_shut") and leaf.position.distance_to(leaf0) < 0.05)
	await phase4_tests(game, ps)
	world.save()
	world.free()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(30)
	ok("p3_restored", world.atmos != null and world.marcus != null and world.marcus.get_parent() == world.market and not world.cashier.visible)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
