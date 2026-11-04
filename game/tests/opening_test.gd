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
## Colossus encounter facts shared by both stagings.
func market_hounds(mk: Node3D) -> int:
	return mk.find_children("P4_Hound*", "", true, false).filter(func(n): return not n.is_queued_for_deletion()).size()


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
	await frames(4)
	var pl: Dictionary = p4.placement
	ok("p4_items_rest_on_surfaces", pl.size() == 3 and pl.values().all(func(v): return v != INF and absf(v) < 0.3), str(pl))
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
	ok("p4_breaker_not_through_wall", not await aim_any(player, br, mk, [Z], 1.0))
	ok("p4_breaker_reach", await aim_any(player, br, mk, [-Z], 1.1))
	var wall_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		mk.global_transform * Vector3(16.9, 1.24, 16.4), mk.global_transform * Vector3(16.9, 1.24, 18.4), 1, [player.get_rid()]))
	ok("p4_breaker_on_wall", not wall_hit.is_empty() and mk.to_local(wall_hit.position).z > 17.2 and mk.to_local(wall_hit.position).z < 17.7,
		"panel / wall at z %.2f" % (mk.to_local(wall_hit.position).z if not wall_hit.is_empty() else -1.0))
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
	await frames(200)
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
	await frames(200)
	ok("p4_pallets_flush", p4._pallets["loading"].position.distance_to(p4.LOADING_PALLET[1]) < 0.005
		and p4._pallets["back"].position.distance_to(p4.BACK_PALLET[1]) < 0.005 and absf(p4._pallets["back"].rotation.y - p4.BACK_PALLET[2]) < 0.001)
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
	var vcur = veil.get("current") if veil else null
	var vname := str(vcur.get("preset_name")) if vcur else "none"
	ok("p4_load_keeps_veil", vcur != null and vcur.get("fog_enabled") and (vname == "NIGHT_ACTIVE" or int(veil.get("state")) == 3), vname)
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
	# ACCEPT ("we can't leave Noah"): they step outside, a Hound charges, slams the shut doors, runs off
	ok("p4_charge_hound", await wait_until(func(): return p4.charge_report.get("spawned", false), 60 * 12))
	ok("p4_threat_done", await wait_until(func(): return game.has_flag("p4_threat_done"), 60 * 40))
	var cr: Dictionary = p4.charge_report
	ok("p4_charge_slam_and_gone", cr.get("slam", false) and cr.get("gone", false) and player.controls_enabled, str(cr))
	await frames(20)
	ok("p4_charge_hound_freed", market_hounds(mk) == 0)
	ok("p4_charge_is_skitter", cr.get("creature", "") == "Skitter" and cr.get("dark_surfaces", 0) > 0
		and cr.get("spawn_distance_m", 0.0) > 35.0, str(cr))
	ok("p4_skitter_hits_shut_doors", cr.get("closed_before_hit", false) and cr.get("inside_at_hit", false)
		and absf(cr.get("hit_gap_m", 9.0)) < 0.25, str(cr))
	ok("p4_skitter_runs_off", cr.get("left_into_fog", false) and world.find_children("P4_Skitter_Charge", "", true, false).is_empty())
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
	# Chapter 5 takes over after the night (no Act I end card any more)
	ok("c5_starts_after_ch4", await wait_until(func(): return game.has_flag("c5_started") and p4.chapter5 != null, 60 * 15)
		and not world.hud.end_panel.visible and game.current_step().get("id", "") == "c5_talk", game.current_step().get("id", ""))
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(40)
	ok("p4_load_end", world.phase4 != null and world.phase4.threat_runs == 0 and game.has_flag("p4_slept")
		and world.phase4.rest.interactable.prompt_text == "" and game.has_flag("p4_choice_noah")
		and world.phase4.chapter5 != null and world.find_children("Eddie", "", true, false).size() == 1)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		cruise = float(args[0]) / 3.6
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	var dlg = root.get_node("Dialogue")
	var interaction: Script = load("res://game/interaction/interactable.gd")
	dlg.auto_confirm = true                      # the "player" confirms each conversation line when its time is up
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
	# light budget: every omni / spot light fades with distance and no spot in town has more lights in range than
	# the renderer draws per frame (otherwise lights are dropped depending on the camera)
	var lights: Array = world.find_children("*", "Light3D", true, false)
	var unfaded: int = lights.filter(func(l): return not (l is DirectionalLight3D) and not l.distance_fade_enabled).size()
	var cap: int = ProjectSettings.get_setting("rendering/limits/opengl/max_renderable_lights")
	var worst := 0
	for p in [home.global_position, world.market.global_transform * Vector3(0, 1.6, -27), world.market.global_transform * Vector3(0, 1.6, 8),
			world.game_shop.global_transform * Vector3(-3.2, 1.6, -2), Vector3(184, 1.6, 36)]:
		var n := 0
		for l in lights:
			if not (l is DirectionalLight3D) and l.is_visible_in_tree() and l.global_position.distance_to(p) < l.distance_fade_begin + l.distance_fade_length:
				n += 1
		worst = maxi(worst, n)
	ok("ground_below_lots", world.ground_dropped)
	ok("light_budget", unfaded == 0 and worst < cap and ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object") >= 16,
		"%d lights, %d without fade, worst spot %d in range (cap %d)" % [lights.size(), unfaded, worst, cap])
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
		# real interaction path: look at the fridge door, the prompt appears, press E
		var f_fwd: Vector3 = (fbody.global_transform.basis * Vector3(0, 0, 1)) * Vector3(1, 0, 1)
		ok("fridge_prompt", await aim_at(player, fr, f_fwd, 1.1) and fr.get_prompt().begins_with("[E] Open"), fr.get_prompt())
		var lamp := fbody.get_node("Fridge_Light") as OmniLight3D
		ok("fridge_light_off_closed", not lamp.visible)
		press_interact()
		await frames(40)
		ok("fridge_opens", fr.is_open)
		ok("fridge_light_on_open", lamp.visible)
		# the few contents sit on the wire shelves inside the cavity (fridge-local), not inside solid geometry
		var can := fbody.get_node("Fridge_Can") as Node3D
		var water := fbody.get_node("Fridge_Water") as Node3D
		var in_cavity := func(p: Vector3) -> bool: return absf(p.x) < 0.33 and p.y > 0.14 and p.y < 1.6 and p.z > -0.315 and p.z < 0.18
		ok("fridge_items_on_shelves", in_cavity.call(can.position) and in_cavity.call(water.position) and absf(can.position.y - 0.78) < 0.01 and absf(water.position.y - 1.18) < 0.01)
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
		# close and reopen repeatedly through E: no stuck tween, light follows the door, back to the original pose
		var cycles_ok := true
		for c in 3:
			press_interact()
			await frames(40)
			cycles_ok = cycles_ok and not fr.is_open and not lamp.visible
			press_interact()
			await frames(40)
			cycles_ok = cycles_ok and fr.is_open and lamp.visible
		ok("fridge_open_close_cycles", cycles_ok)
		press_interact()
		await frames(40)
		ok("fridge_closes_to_rest", not fr.is_open and (fr.target as Node3D).transform.is_equal_approx(fr._base))
		press_interact()
		await frames(40)
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
		# the keys are their own mesh hanging on the rack's last hook (not merged into the rack)
		var key_meshes: Array = keys.target.find_children("*", "MeshInstance3D", true, false)
		if keys.target is MeshInstance3D:
			key_meshes.push_front(keys.target)
		var rack := keys.target.get_parent() as Node3D
		var hook_tip: Vector3 = rack.global_transform * Vector3(0.3, 0.03, 0.07)
		ok("keys_own_mesh_on_hook", key_meshes.size() > 0 and keys.target.global_position.distance_to(hook_tip) < 0.03,
			"%d meshes, %.3f m from the hook tip" % [key_meshes.size(), keys.target.global_position.distance_to(hook_tip)])
		keys.set_focus(true)
		ok("keys_highlight", (key_meshes[0] as GeometryInstance3D).material_overlay != null if key_meshes.size() > 0 else false)
		keys.interact(player)
		await frames(20)
		ok("keys_in_inventory", game.has_item("car_keys"))
		var shapes_off: bool = keys.get_children().all(func(c): return not (c is CollisionShape3D) or c.disabled)
		ok("keys_hidden_after_pickup", not keys.target.visible and keys.taken and shapes_off and keys.get_prompt() == "")
		keys.interact(player)
		await frames(2)
		ok("keys_not_collected_twice", game.inventory.count("car_keys") == 1)
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
	var arrival_min_kmh := 999.0
	var arrival_flag_before_park := false
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
		var sf: Vector3 = world.market.to_local(sedan.global_position)
		if game.has_flag("arrival_shot") and not game.has_flag("parked"):
			arrival_flag_before_park = true
			if absf(sf.z + 27.0) < 6.0 and sf.x > -16.0 and sf.x < 6.0:      # on Main St right in front of the store
				arrival_min_kmh = minf(arrival_min_kmh, sedan.speed * 3.6)
		if fmod(t, 1.0) < 1.0 / 60.0:
			if sedan.global_position.distance_to(last_pos) < 0.3 and st["idx"] < route.size() - 3:
				stuck += 1.0
			else:
				stuck = 0.0
			last_pos = sedan.global_position
			if stuck > 4.0:
				print("STUCK at ", sedan.global_position, " idx ", st["idx"])
				break
	ok("arrival_shot_while_driving", game.has_flag("arrival_shot") and arrival_min_kmh < 7.0 and arrival_min_kmh > 1.0 and arrival_flag_before_park,
		"slowest in front of the store %.1f km/h (target 5)" % arrival_min_kmh)
	var pr: Dictionary = world.park_report
	ok("auto_reverse_park", game.has_flag("auto_parked") and pr.get("ok", false) and pr.get("pos_err", 9.0) < 0.35
		and pr.get("yaw_err_deg", 99.0) < 6.0 and pr.get("max_dev", 9.0) < 0.6, str(pr))
	ok("auto_park_camera_clear", pr.get("cam_blocked_frames", 1) == 0)
	ok("parking_brake_on", sedan.parking_brake and absf(sedan.speed) < 0.01)
	ok("arrival_caption_not_title", world.hud.title.modulate.a < 0.05)
	ok("arrival_view_restored", sedan.driver_cam.current and world._cine == null and sedan.speed_cap < 0.0)
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
	ok("eddie_talks", world.eddie_face._talk_left > 0.0)
	ok("talk_camera_frames_eddie", root.get_viewport().get_camera_3d().name == "TalkCam" and not player.controls_enabled)
	ok("conversation_confirm_mode", dlg.confirm_mode and world.conversing)
	ok("speaker_name_shown", world.hud.speaker_l.text == "EDDIE" or world.hud.speaker_l.text == "PROTAGONIST", world.hud.speaker_l.text)
	ok("continue_prompt_shown", world.hud.confirm_l.visible and world.hud.confirm_l.text.contains("CONTINUE") and world.hud.confirm_l.text.contains("SKIP"))
	await frames(60 * 7)
	ok("talk_camera_restores", player.camera.current and player.controls_enabled and world._talk_cam == null and not dlg.confirm_mode)
	ok("game_bought", game.has_flag("game_bought"))
	ok("objective_still_groceries", game.current_step().get("id", "") == "buy_groceries")
	ok("talk_camera_clear_of_geometry", world.talk_report["cam_hits"] == 0 and world.talk_report["min_face_dist"] > 0.9,
		str(world.talk_report))
	# a conversation line waits for the player's confirmation (no auto-confirm)
	dlg.auto_confirm = false
	world.converse(["eddie_after"], [world.eddie])
	await frames(60 * 6)
	ok("line_waits_for_confirm", dlg.is_busy() and dlg.is_waiting() and world._talk_cam != null)
	var conf0: int = dlg.confirms
	press_interact()
	await frames(60)
	ok("confirm_advances", dlg.confirms == conf0 + 1 and not world.conversing and player.controls_enabled)
	dlg.auto_confirm = true
	# no conversation through a window: stand outside the shop glass and try to talk
	var glass_spot: Vector3 = gs.global_transform * Vector3(1.5, 0.1, -1.2)
	player.global_position = glass_spot
	await frames(5)
	ok("glass_colliders", world.glass_panes > 20, "%d panes" % world.glass_panes)
	ok("no_talk_through_glass", not world.can_talk(world.eddie))
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
	ok("cashier_conversation", world.conversing and root.get_viewport().get_camera_3d().name == "TalkCam")
	while world.conversing:
		await frames(5)
	var reach_fail := []
	var mmc: Node = world.market_merch
	var decor_its := mmc.find_children("*", "Interactable", true, false).size()
	ok("merch_decor_not_interactive", decor_its == mmc.groups.size() and mmc.instance_count > 2000,
		"%d products, %d multimeshes, %d interactables" % [mmc.instance_count, mmc.mmi_count, decor_its])
	for id in ["canned_food", "energy_snack", "water_bottle"]:
		var gi = world.interactables["market/" + id]
		ok("grocery_glow_" + id, mmc.groups[id]["mmi"].material_overlay != null)
		var outward: Vector3 = mk.global_transform.basis * mmc.groups[id]["normal"]
		if id == "water_bottle":
			# the water is behind the glass: the closed door blocks it, then "[E] Open Fridge" opens it
			var door = null
			for k in world.interactables:
				if k.begins_with("market/Cooler") and (door == null or world.interactables[k].global_position.distance_to(gi.global_position) < door.global_position.distance_to(gi.global_position)):
					door = world.interactables[k]
			ok("cooler_blocked_when_closed", not await aim_at(player, gi, outward, 1.0))
			ok("cooler_prompt", await aim_at(player, door, outward, 1.1) and door.get_prompt() == "[E] Open Fridge", door.get_prompt())
			var lamp = door.get_parent().get_parent()
			while lamp and not lamp.has_node("CoolerLight"):
				lamp = lamp.get_parent()
			press_interact()
			await frames(45)
			ok("cooler_door_opens", door.is_open and lamp.get_node("CoolerLight").visible)
			var before: int = mmc.remaining(id)
			if not await aim_at(player, gi, outward, 0.95):
				reach_fail.append(id)
			press_interact()
			await frames(15)
			ok("cooler_one_bottle_taken", game.has_item("water_bottle") and mmc.remaining(id) == before - 1, "%d -> %d" % [before, mmc.remaining(id)])
			press_interact()
			await frames(10)
			ok("cooler_no_duplicate", mmc.remaining(id) == before - 1)
			await aim_at(player, door, outward, 1.1)
			press_interact()
			await frames(45)
			ok("cooler_door_closes", not door.is_open and not lamp.get_node("CoolerLight").visible)
			continue
		var before2: int = mmc.remaining(id)
		if not await aim_at(player, gi, outward, 0.95):
			reach_fail.append(id)
		press_interact()
		await frames(15)
		ok("take_one_" + id, game.has_item(id) and mmc.remaining(id) == before2 - 1, "%d -> %d" % [before2, mmc.remaining(id)])
	ok("groceries_reachable", reach_fail.is_empty(), str(reach_fail))
	ok("groceries_picked", game.has_item("canned_food") and game.has_item("water_bottle") and game.has_item("energy_snack"))
	await aim_at(player, pay, ((mk.get_node("NavTargets/Checkout_4") as Node3D).global_position - pay.global_position) * Vector3(1, 0, 1), 1.6)
	pay.interact(player)
	await frames(10)
	ok("checkout", game.has_flag("groceries_done") and game.has_item("groceries") and not game.has_item("canned_food"))
	ok("mist_waits_for_conversation", world.conversing and not game.has_flag("p3_mist"))
	while world.conversing:
		await frames(5)
	ok("objective_after_errands", game.current_step().get("id", "") == "p3_look", game.current_step().get("id", ""))
	# ---- Phase 3: the Veil arrives while the player is still inside the supermarket (last errand done)
	await frames(20)
	ok("p3_mist_starts_inside", game.has_flag("p3_mist") and game.has_flag("phase2_done") and world.atmos != null and not world._outdoors())
	ok("p3_cashier_gone", not world.cashier.visible)
	ok("p3_marcus_before_colossus", world.marcus != null and world.marcus.is_visible_in_tree() and world.marcus.get_parent() == world.game_shop)
	ok("p3_objective_look", game.current_step().get("id", "") == "p3_look", game.current_step().get("id", ""))
	ok("survival_hidden_before", not world.hud.surv.visible and not player.survival_active)
	await frames(60 * 6)
	player.global_position = m_out + (m_out - m_in).normalized() * 2.0
	await frames(10)
	var cam_now: Camera3D = root.get_viewport().get_camera_3d()
	ok("encounter_starts_outside", world._encounter_running and not player.controls_enabled and cam_now.name == "EncounterCam")
	await wait_until(func(): return world.enc_report.has("foot_error_m"), 60 * 40)
	await frames(60 * 15)                    # the rest of the encounter after the touch-down (as before)
	var r: Dictionary = world.enc_report

	ok("colossus_foot_lands_in_front", r.get("foot_error_m", 99.0) < 0.6 and r.get("leg_distance_m", 0.0) > 12.0 and r.get("leg_distance_m", 0.0) < 18.0,
		"foot error %.2f m, %.1f m in front" % [r.get("foot_error_m", -1.0), r.get("leg_distance_m", -1.0)])
	ok("colossus_walks_in_from_out_of_frame", r.get("walk_in_m", 0.0) > 8.0, "%.1f m" % r.get("walk_in_m", -1.0))
	ok("colossus_leg_descends_from_mist", r.get("apex_height_m", 0.0) > 9.0, "%.1f m" % r.get("apex_height_m", -1.0))
	ok("colossus_other_feet_clear", r.get("other_feet_min_out_m", 0.0) > r.get("leg_distance_m", 99.0), "%.1f m out" % r.get("other_feet_min_out_m", -1.0))
	ok("colossus_body_hidden_in_mist", r.get("body_height_m", 0.0) > r.get("ceiling_m", 99.0) + 3.0,
		"body at %.1f m, mist ceiling from %.1f m" % [r.get("body_height_m", -1.0), r.get("ceiling_m", -1.0)])
	ok("encounter_face_shot", r.get("face_cam_distance_m", 0.0) > 0.6 and r.get("face_cam_distance_m", 9.0) < 1.6)
	ok("encounter_looks_up", r.get("max_look_up_deg", 0.0) > 55.0, "%.0f deg" % r.get("max_look_up_deg", -1.0))
	ok("colossus_veil_material", r.get("veil_surfaces", 0) >= 3, str(r.get("veil_surfaces", 0)))
	ok("colossus_claws_on_road", absf(r.get("foot_height_m", 9.0) - 0.02) < 0.1, "%.3f m" % r.get("foot_height_m", -1.0))
	ok("colossus_foot_planted", r.get("foot_planted_drift_m", 9.0) < 0.05, "%.3f m" % r.get("foot_planted_drift_m", -1.0))
	ok("colossus_audio_cleared", world._enc_sounds.is_empty())
	ok("encounter_control_restored", not world._encounter_running and player.controls_enabled and player.camera.current)
	ok("p3_objective_back", game.current_step().get("id", "") == "p3_back", game.current_step().get("text", ""))
	ok("survival_on", player.survival_active and world.hud.surv.visible)
	ok("p3_tentacles", world._tentacles.size() == 3 and world._tentacles[0].has_node("AI"))
	# stamina: sprinting drains, resting recovers
	player.global_position = m_out + (m_out - m_in).normalized() * 3.0
	player.set_yaw_pitch(atan2(-(m_in - m_out).x, -(m_in - m_out).z) + PI, 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(210)                    # 3.5 s of sprinting (drain 8.5/s, ~12 s from full)
	var st_run: float = player.stamina
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await frames(150)
	ok("stamina_drains_and_recovers", st_run < 75.0 and player.stamina > st_run + 10.0, "%.0f -> %.0f" % [st_run, player.stamina])
	# tentacle: wind-up, then damage exactly at the strike's contact frame, not before
	var t0: Node3D = world._tentacles[0]
	var ai = t0.get_node("AI")
	var tdir: Vector3 = (player.global_position - t0.global_position) * Vector3(1, 0, 1)
	player.global_position = t0.global_position + tdir.normalized() * minf(ai.reach * 0.7, 3.0) + Vector3(0, 0.1, 0)
	var h0: float = player.health
	var saw_windup := false
	var strike_t := -1.0
	var hit_after := -1.0
	var tt := 0.0
	for i in 60 * 6:
		await physics_frame
		tt += 1.0 / 60.0
		if ai.state == "windup":
			saw_windup = true
		if ai.state == "strike" and strike_t < 0.0:
			strike_t = tt
		if player.health < h0 and hit_after < 0.0:
			hit_after = tt - strike_t
			break
	ok("tentacle_windup_then_strike", saw_windup and strike_t > 0.0)
	ok("tentacle_damage_at_contact", player.health < h0 and absf(hit_after - ai.contact_time) < 0.1,
		"hit %.2f s into the strike, contact frame %.2f s, reach %.1f m, health %.0f" % [hit_after, ai.contact_time, ai.reach, player.health])
	# dodge: step out of reach during the next wind-up -> no damage
	await frames(90)
	for i in 60 * 4:
		await physics_frame
		if ai.state == "windup":
			break
	var h1: float = player.health
	player.global_position = t0.global_position + tdir.normalized() * (ai.reach + 3.0) + Vector3(0, 0.1, 0)
	await frames(90)
	ok("tentacle_dodge_no_damage", player.health == h1, "%.0f -> %.0f" % [h1, player.health])
	# back inside the supermarket -> Eddie calls everyone to the game shop
	player.global_position = mk.global_transform * Vector3(0, 0.2, 5.5)
	await frames(20)
	ok("p3_back_inside", game.has_flag("p3_back_inside") and game.current_step().get("id", "") == "mist_shop", game.current_step().get("id", ""))
	ok("p3_marcus_in_shop", world.marcus != null and world.marcus.get_parent() == gs and world.faces.has("Marcus") and world.faces["Marcus"]._mat != null,
		"marcus=%s parent=%s faces=%s" % [world.marcus, world.marcus.get_parent().name if world.marcus else "-", world.faces.keys()])
	ok("p3_npcs_scared", world.animators["Eddie"].mood == "scared" and world.animators["Marcus"].mood == "scared")
	ok("p3_eddie_walks_to_door", world.eddie.position.distance_to(Vector3(-2.2, 0.04, 1.3)) < 0.3, str(world.eddie.position))
	player.global_position = s_in + gs.global_transform.basis.z * 1.5
	await frames(20)
	ok("p3_in_shop", game.has_flag("p3_in_shop"))
	var wt := 0
	while not world._p3_shop_talked and wt < 60 * 180:
		await frames(10)
		wt += 10
	ok("p3_shop_talk_finished", world._p3_shop_talked)
	var sr2: Dictionary = world.seated_report
	ok("p3_seated_talk", sr2.get("seated", false) and sr2.get("time_skip", false) and sr2.get("lights_talk", false)
		and game.has_flag("p3_two_hours_later") and player.visible and player.controls_enabled, str(sr2))
	ok("p3_stock_room_retreat", sr2.get("fp_retreat", false) and sr2.get("door_open", false) and sr2.get("door_closed", false)
		and sr2.get("spawned_seats", -1) == 0 and sr2.get("third_anchor", false), str(sr2))
	ok("p3_no_seat_props", world.game_shop.find_children("Seat_*", "", true, false).is_empty())
	ok("p3_market_looted", world.market_merch.looted)
	ok("p3_objective_reach_market", game.current_step().get("text", "") == "Reach the supermarket", game.current_step().get("text", ""))
	# the protagonist steps outside: Eddie and Marcus come with him (sample Eddie's stride while he follows)
	for k in range(1, 13):                       # out of the door in steps (a trail to follow, like walking)
		player.global_position = s_out + (s_out - s_in).normalized() * float(k)
		await frames(6)
	ok("p3_flee_together", world._p3_followers.size() == 2 and world._p3_followers.all(func(f): return f.active))
	var leg_min := 999.0
	var leg_max := -999.0
	for i in 12:
		await frames(10)
		var ea2 = world.animators["Eddie"]
		var es: Skeleton3D = ea2.skel
		var ld: Vector3 = (es.get_bone_global_pose(es.find_bone("LeftLowerLeg")).origin - es.get_bone_global_pose(es.find_bone("LeftUpperLeg")).origin).normalized()
		var la: float = rad_to_deg(ld.signed_angle_to(-ea2.U, ea2.R))
		leg_min = minf(leg_min, la)
		leg_max = maxf(leg_max, la)
	ok("npc_walk_cycle_legs", leg_max - leg_min > 20.0, "thigh swing %.0f deg" % (leg_max - leg_min))
	player.global_position = s_out + (s_out - s_in).normalized() * 3.0
	await frames(60 * 4)
	ok("p3_shop_talk_done", world._p3_shop_talked and player.controls_enabled and player.camera.current)
	await frames(10)
	player.global_position = mk.global_transform * Vector3(0, 0.2, 5.5)
	await frames(60)
	ok("p3_npcs_to_market", world.eddie.get_parent() == mk and world.marcus.get_parent() == mk and world._p3_followers.is_empty())
	# the regroup walk from the entrance goes round the vestibule wall / carts, never through them
	var nroute: Array = world.npc_route(mk, Vector3(0, 0.04, -0.5), Vector3(1.1, 0.04, 4.7))
	var clear := nroute.size() >= 2
	var prev := Vector3(0, 0.04, -0.5)
	var sp := SphereShape3D.new()
	sp.radius = 0.22
	var qq := PhysicsShapeQueryParameters3D.new()
	qq.shape = sp
	qq.collision_mask = 1
	for wp in nroute:
		qq.transform = Transform3D(Basis(), mk.global_transform * (prev + Vector3(0, 0.8, 0)))
		qq.motion = mk.global_transform.basis * ((wp as Vector3) - prev)
		var cm: PackedFloat32Array = world.get_world_3d().direct_space_state.cast_motion(qq)
		if cm.size() == 0 or cm[0] < 1.0:
			clear = false
		prev = wp
	ok("npc_route_around_obstacles", clear, str(nroute))
	ok("p3_in_market", game.has_flag("p3_in_market") and leaf.position.distance_to(leaf0) > 1.0 and game.current_step().get("id", "") == "mist_doors")
	await frames(60 * 10)                        # the arrival conversation (talk camera) ends first
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
