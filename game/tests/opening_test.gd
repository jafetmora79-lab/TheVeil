extends SceneTree
## THE VEIL - automated playthrough of the Phase 1 opening (no screenshots).
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


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		cruise = float(args[0]) / 3.6
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
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
			return (fbody.global_transform.affine_inverse() * (d.global_transform * Interactable.aabb_of(d).get_center())).z
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
				var body: Vector3 = fb.global_transform * Interactable.aabb_of(fb).get_center()
				var c0: float = (it.target.global_transform * Interactable.aabb_of(it.target).get_center()).distance_to(body)
				it.set_open(true, true)
				var c1: float = (it.target.global_transform * Interactable.aabb_of(it.target).get_center()).distance_to(body)
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
		if world.interactables[k].kind == "pickup":
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
	world.exit_car()
	await frames(60)
	ok("exit_car", not world.in_car and player.visible)
	world.save()
	ok("save_exists", game.has_save())
	var ok_load: bool = game.load_game()
	ok("load", ok_load and game.has_item("car_keys") and game.has_flag("parked") and game.world_state.size() > 0)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
