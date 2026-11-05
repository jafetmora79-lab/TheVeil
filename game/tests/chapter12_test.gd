extends SceneTree
## THE VEIL - displayed CHAPTER 13 "The Truth Beneath Greyhaven" (chapter12.gd) automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter12_test.gd
## From the developer entry (game/tools/dev_chapter12.gd: The Farm Road complete). The player walks (physics) from the
## mill-worker house to the maintenance station and through it: the fuse, the power, the ramp, the tunnels, the
## sealed chamber, the records, the Skitter chase (sprinting), the access door, the sound below, the supply choice,
## the walk back, the map. Then: loads (no duplicated records, no replayed encounter), and the roster without Marcus.

const DEV := preload("res://game/tools/dev_chapter12.gd")

var fails := 0
var world: Node
var game: Node
var dlg: Node
var ps: PackedScene
var c8: Node
var c9: Node
var c10: Node
var c11: Node
var c12: Node
var p4: Node
var said: Array = []


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func wait_talk(cond: Callable, max_seconds := 90.0) -> bool:
	Engine.time_scale = 6.0
	var r := await wait_until(cond, int(max_seconds * 60 / 6.0) + 60)
	Engine.time_scale = 1.0
	return r


func walk_to(target: Vector3, timeout := 30.0) -> bool:
	var player = world.player
	var t := 0.0
	var last: Vector3 = player.global_position
	var still := 0.0
	Input.action_press("move_forward")
	while t < timeout:
		var d: Vector3 = (target - player.global_position) * Vector3(1, 0, 1)
		if d.length() < 0.45:
			break
		if player.controls_enabled:
			player.set_yaw_pitch(atan2(-d.x, -d.z), 0.0)
		await process_frame
		t += 1.0 / 60.0
		if player.global_position.distance_to(last) < 0.01 and player.controls_enabled:
			still += 1.0 / 60.0
			if still > 2.0:
				break
		else:
			still = 0.0
		last = player.global_position
	Input.action_release("move_forward")
	await frames(6)
	var left: float = ((target - player.global_position) * Vector3(1, 0, 1)).length()
	if left > 0.8:
		print("  walk stuck at %s (target %s, %.1f m left)" % [world.market.to_local(player.global_position), world.market.to_local(target), left])
	return left <= 0.8


func walk_route(pts: Array) -> bool:
	for p in pts:
		if not await walk_to(world.market.global_transform * (p as Vector3)):
			return false
	return true


func walk_world(pts: Array) -> bool:
	for p in pts:
		if not await walk_to(p as Vector3):
			return false
	return true


func aim(it: Node3D, dirs: Array, dist := 1.2) -> bool:
	var player = world.player
	var c: Vector3 = it.global_position
	for cs in it.get_children():
		if cs is CollisionShape3D:
			c = (cs as CollisionShape3D).global_position
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for d in dirs:
		var dir: Vector3 = (world.market.global_transform.basis * (d as Vector3)) * Vector3(1, 0, 1)
		var feet := c + dir.normalized() * dist
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(feet.x, c.y + 0.6, feet.z), Vector3(feet.x, c.y - 3.0, feet.z), 1))
		player.global_position = Vector3(feet.x, ((hit["position"] as Vector3).y if hit else c.y - 1.0) + 0.06, feet.z)
		player.velocity = Vector3.ZERO
		await frames(3)
		var eye: Vector3 = player.camera.global_position
		var v := (c - eye).normalized()
		player.set_yaw_pitch(atan2(-v.x, -v.z), asin(clampf(v.y, -1.0, 1.0)))
		await frames(4)
		if player._focus == it:
			return true
	return false


func reload() -> void:
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(40)
	_bind()


func snapshot() -> Dictionary:
	world.save()                                         # the player's position and health go into player_state
	return {"flags": game.flags.duplicate(true), "ws": game.world_state.duplicate(true), "inv": game.inventory.duplicate(),
		"ps": game.player_state.duplicate(true)}


func restore(snap: Dictionary, mutate := Callable()) -> void:
	world.free()
	game.flags = snap["flags"].duplicate(true)
	game.world_state = snap["ws"].duplicate(true)
	game.inventory = snap["inv"].duplicate()
	game.player_state = snap["ps"].duplicate(true)
	if mutate.is_valid():
		mutate.call()
	game.save_game()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(40)
	_bind()


func _bind() -> void:
	p4 = world.phase4
	var c5 = p4.chapter5 if p4 else null
	var c6 = c5.chapter6 if c5 else null
	var c7 = c6.chapter7 if c6 else null
	c8 = c7.chapter8 if c7 else null
	c9 = c8.chapter9 if c8 else null
	c10 = c9.chapter10 if c9 else null
	c11 = c10.chapter11 if c10 else null
	c12 = c11.chapter12 if c11 else null


func _initialize() -> void:
	_run.call_deferred()
	create_timer(2400.0).timeout.connect(func():
		print("RESULT FAIL (watchdog: test did not finish)")
		quit(1))




## aim() with directions in world space (this chapter happens outside the supermarket).
func aim_w(it: Node3D, dirs: Array, dist := 1.2) -> bool:
	var player = world.player
	var c: Vector3 = it.global_position
	for cs in it.get_children():
		if cs is CollisionShape3D:
			c = (cs as CollisionShape3D).global_position
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for d in dirs:
		var dir: Vector3 = (d as Vector3) * Vector3(1, 0, 1)
		var feet := c + dir.normalized() * dist
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(feet.x, c.y + 0.6, feet.z), Vector3(feet.x, c.y - 3.0, feet.z), 1))
		player.global_position = Vector3(feet.x, ((hit["position"] as Vector3).y if hit else c.y - 1.0) + 0.06, feet.z)
		player.velocity = Vector3.ZERO
		await frames(3)
		var eye: Vector3 = player.camera.global_position
		var v := (c - eye).normalized()
		player.set_yaw_pitch(atan2(-v.x, -v.z), asin(clampf(v.y, -1.0, 1.0)))
		await frames(4)
		if player._focus == it:
			return true
	return false


func npcs_ok() -> String:
	var bodies: Array = []
	for k in ["Eddie", "Marcus", "Ruth", "Sarah"]:
		var a = world.animators.get(k)
		if a and a.root.is_visible_in_tree():
			bodies.append(a.root)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var d: float = Vector2(bodies[i].global_position.x - bodies[j].global_position.x, bodies[i].global_position.z - bodies[j].global_position.z).length()
			if d < 0.55:
				return "%s/%s %.2f m apart" % [bodies[i].name, bodies[j].name, d]
	return ""


func press_e() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var ev2 := InputEventAction.new()
	ev2.action = "interact"
	ev2.pressed = false
	Input.parse_input_event(ev2)


## A small sideways nudge (< 0.5 m) onto an exact line, e.g. the middle of a narrow staircase.
func align(local: Vector3) -> void:
	var to: Vector3 = c11.fl(local)
	if world.player.global_position.distance_to(to) < 0.8:
		world.player.global_position = to
		world.player.velocity = Vector3.ZERO
	await frames(3)


func read_item(id: String) -> bool:
	if not world.hud.inv_panel.visible:
		world.hud.toggle_inventory()
	await frames(5)
	var inv = world.hud.inv_panel
	var idx: int = inv._ids.find(id)
	if idx < 0:
		world.hud.toggle_inventory()
		return false
	inv.select(idx)
	await frames(100)
	world.hud.toggle_inventory()
	await frames(5)
	return true



func sprint_to(target: Vector3, timeout := 30.0) -> bool:
	Input.action_press("sprint")
	var r := await walk_to(target, timeout)
	Input.action_release("sprint")
	return r


func run_route(pts: Array) -> bool:
	for p in pts:
		if not await sprint_to(p as Vector3):
			return false
	return true


func use(it: Node3D, dirs := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)], dist := 1.1) -> bool:
	var r := await aim_w(it, dirs, dist)
	if r:
		it.interact(world.player)
	return r


func npc_jumps(k: String, n: int) -> float:
	var a = world.animators[k].root
	var prev: Vector3 = a.global_position
	var mx := 0.0
	for i in n:
		await process_frame
		mx = maxf(mx, a.global_position.distance_to(prev))
		prev = a.global_position
	return mx


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	dlg.auto_confirm = true
	DEV.prepare(game)
	for cp in ["chapter13_start", "chapter13_facility", "chapter13_underground", "chapter13_escaped", "chapter13_return", "chapter13_end"]:
		if FileAccess.file_exists(game.checkpoint_path(cp)):
			DirAccess.remove_absolute(game.checkpoint_path(cp))
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c12_entry", c12 != null and game.has_flag("ch12_started") and game.chapter_number() == 13, str(game.chapter_number()))
	ok("c12_previous_kept", game.has_flag("chapter_11_complete") and game.has_flag("noah_clue_farmhouse") and game.has_item("noahs_message"))
	ok("c12_title_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 13  —  THE TRUTH BENEATH GREYHAVEN", 60 * 8), world.hud.chapter_l.text)
	ok("c12_start_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter13_start")))
	ok("c12_in_house", c12.c10.inside_room(world.player) and c12._node("Marcus").visible and npcs_ok() == "", npcs_ok())
	ok("c12_step_talk", game.current_step().get("id", "") == "c12_talk", game.current_step().get("id", ""))

	# ---- scene 1: the symbol; the preparation panel
	ok("c12_eddie_prompt", c12.its["npc_Eddie"].prompt_text == "[E] Talk")
	c12.its["npc_Eddie"].interact(world.player)          # from where the opening left the player, facing Eddie
	ok("c12_talk", await wait_talk(func(): return game.has_flag("ch12_talk_done") and p4.choice.is_open(), 90.0)
		and said.has("Tell me I'm not the only one seeing that.") and said.has("Noah drew that. Or he saw it somewhere.") and game.has_item("utility_map"))
	ok("c12_prep_panel", "Flashlight spares" in p4.choice._title.text and "Painkillers" in p4.choice._title.text, p4.choice._title.text)
	p4.choice.pick(0)
	ok("c12_set_out", await wait_until(func(): return game.has_flag("ch12_set_out"), 60) and c12.c9.follows["Eddie"].active
		and not c12.c9.follows["Ruth"].active)
	ok("c12_controls_back", await wait_until(func(): return world.player.controls_enabled and root.get_viewport().get_camera_3d() == world.player.camera, 600))

	# ---- scene 2: across the road to the station (walking)
	ok("c12_walk_out", await walk_world([c12.c10.hl(Vector3(0.6, 0.7, 4.4)), c12.c10.hl(Vector3(0.6, 0.7, 2.4)), c12.c10.hl(Vector3(0.6, 0.1, 0.0))]),
		str(world.player.global_position))
	ok("c12_walk_road", await walk_world(c12.ROUTE), str(world.player.global_position))
	ok("c12_fog_talk", await wait_talk(func(): return said.has("You ever notice how the fog never seems to move with the wind?"), 20.0))
	await frames(120)
	var lag: float = c12._comp().global_position.distance_to(world.player.global_position)
	ok("c12_eddie_kept_up", lag < 8.0, "%.1f m" % lag)
	ok("c12_station_door", await use(c12.its["station"], [Vector3(0, 0, 1)], 1.2))
	ok("c12_inside", await wait_until(func(): return game.has_flag("ch12_station_reached"), 300) and world.player.global_position.y < -35.0
		and FileAccess.file_exists(game.checkpoint_path("chapter13_facility")))
	await wait_talk(func(): return not dlg.is_busy() and not world.conversing, 20.0)
	ok("c12_eddie_inside", c12._comp().global_position.distance_to(world.player.global_position) < 4.0)

	# ---- the clues, the fuse, the power
	c12._examine(null, "report")
	await frames(10)
	ok("c12_clue_report", said.has("Inspection report, water-damaged. '...lower access: vibration persists. Recommend no further entry.'"))
	c12._use_panel(null)
	ok("c12_panel_needs_fuse", not game.has_flag("ch12_power_on"))
	await wait_talk(func(): return not dlg.is_busy(), 15.0)
	ok("c12_walk_storage", await walk_world([c12.L(Vector3(0, 0.2, 7.0)), c12.L(Vector3(0, 0.2, 11.8)), c12.L(Vector3(-4.5, 0.2, 11.8))]),
		str(world.player.global_position - c12.FAC))
	ok("c12_fuse", await use(c12.its["locker"], [Vector3(1, 0, 0)], 1.2) and game.has_item("station_fuse"))
	await wait_talk(func(): return not dlg.is_busy(), 15.0)
	c12._examine(null, "log")
	ok("c12_clue_log", game.has_item("maintenance_log"))
	await wait_talk(func(): return not dlg.is_busy(), 15.0)
	ok("c12_walk_control", await walk_world([c12.L(Vector3(-2.0, 0.2, 11.8)), c12.L(Vector3(2.0, 0.2, 11.8)), c12.L(Vector3(5.0, 0.2, 12.0))]))
	ok("c12_power", await use(c12.its["panel"], [Vector3(-1, 0, 0)], 1.0) and await wait_talk(func(): return (game.has_flag("ch12_power_on")
		and world.player.controls_enabled and said.has("I don't think it was.")), 30.0) and c12.low_lights[0].light_energy > 0.3 and not game.has_item("station_fuse"))

	# ---- the access door, the ramp, the tunnels
	ok("c12_walk_access", await walk_world([c12.L(Vector3(2.0, 0.2, 11.8)), c12.L(Vector3(0, 0.2, 12.0)), c12.L(Vector3(0, 0.2, 24.5))]))
	ok("c12_access_open", await use(c12.its["access"], [Vector3(0, 0, -1)], 1.4) and await wait_until(func(): return (game.has_flag("ch12_access_open")
		and c12.access_door.global_position.y > c12.L(c12.ACCESS).y + 2.0), 300))
	ok("c12_walk_ramp", await walk_world([c12.L(Vector3(0, 0.2, 27.0)), c12.L(Vector3(0, 0.2, 31.0)), c12.L(Vector3(0, -5.8, 41.0))]),
		str(world.player.global_position - c12.FAC))
	ok("c12_descended", await wait_until(func(): return game.has_flag("ch12_descended"), 60))
	ok("c12_low_locker", await walk_world([c12.L(Vector3(0, -5.8, 47.0))]) and await use(c12.its["low_locker"], [Vector3(1, 0, 0)], 1.2)
		and game.has_flag("ch12_low_locker"))
	await wait_talk(func(): return not dlg.is_busy(), 15.0)
	ok("c12_walk_tunnel", await walk_world([c12.L(Vector3(0, -5.8, 61.0)), c12.L(Vector3(7.5, -5.8, 61.0))]), str(world.player.global_position - c12.FAC))
	ok("c12_marks", await use(c12.its["clue_marks"], [Vector3(0, 0, 1)], 1.0) and await wait_talk(func(): return said.has("I was hoping you knew."), 30.0))
	ok("c12_walk_seal", await walk_world([c12.L(Vector3(14.6, -5.8, 61.0))]))
	await frames(120)
	ok("c12_seal_open", await use(c12.its["seal"], [Vector3(-1, 0, 0)], 1.2) and await wait_talk(func(): return (game.has_flag("ch12_chamber_open")
		and said.has("I really hate that answer.")), 40.0) and FileAccess.file_exists(game.checkpoint_path("chapter13_underground")))

	# ---- the records, the Skitter, the run
	ok("c12_walk_chamber", await walk_world([c12.L(Vector3(17.5, -5.8, 61.0)), c12.L(Vector3(20.0, -5.8, 57.8))]))
	var hp0: float = world.player.health
	ok("c12_records_reach", await use(c12.its["records"], [Vector3(0, 0, 1)], 1.3))
	ok("c12_records", await wait_until(func(): return game.has_flag("ch12_records_taken") and c12.skitter != null, 60 * 20)
		and game.inventory.count("underground_records") == 1 and said.has("Not yet. I've almost got it."))
	var den: Vector3 = c12.L(c12.SKITTER_DEN)
	if c12.skitter == null:
		print("RESULT FAIL (no skitter)")
		quit(1)
		return
	ok("c12_skitter_from_vent", c12.skitter.global_position.distance_to(den) < 0.5, str(c12.skitter.global_position - c12.FAC))
	ok("c12_controls_after_records", await wait_until(func(): return world.player.controls_enabled, 120))
	var esc: bool = await run_route([c12.L(Vector3(17.5, -5.8, 61.0)), c12.L(Vector3(0, -5.8, 61.0)), c12.L(Vector3(0, -5.8, 41.0)),
		c12.L(Vector3(0, 0.2, 30.0)), c12.L(Vector3(0.6, 0.2, 25.6))])
	ok("c12_escape_run", esc, str(world.player.global_position - c12.FAC))
	ok("c12_skitter_moved", c12.skitter != null and c12.skitter.global_position.distance_to(den) > 10.0
		and float(c12.report["skitter_max_step"]) < 0.25, "%s step %.2f" % [str(c12.skitter.global_position - c12.FAC) if c12.skitter else "-", c12.report["skitter_max_step"]])
	await wait_until(func(): return (c12._comp().global_position - c12.FAC).z < 27.4, 60 * 6)
	ok("c12_secure", await use(c12.its["access"], [Vector3(0, 0, -1)], 1.4) and await wait_until(func(): return game.has_flag("ch12_door_secured"), 120)
		and c12.skitter == null, "hits %d" % c12.report["hits"])
	ok("c12_player_alive", world.player.health > 0.0, "%.0f -> %.0f" % [hp0, world.player.health])
	ok("c12_below", await wait_talk(func(): return said.has("Then what the hell was it?") and p4.choice.is_open(), 40.0) and c12.report["below_runs"] == 1)
	var pk0: int = game.inventory.count("painkillers")
	p4.choice.pick(0)
	ok("c12_took_supplies", await wait_talk(func(): return game.has_flag("ch12_supply_choice") and world.player.controls_enabled, 20.0)
		and game.has_flag("ch12_supplies_taken") and game.inventory.count("painkillers") == pk0 + 1, "%d -> %d" % [pk0, game.inventory.count("painkillers")])
	ok("c12_camera_restored", absf(world.player.camera.h_offset) < 0.001 and root.get_viewport().get_camera_3d() == world.player.camera)

	# ---- out, and back to the mill house
	ok("c12_walk_exit", await walk_world([c12.L(Vector3(0, 0.2, 21.0)), c12.L(Vector3(0, 0.2, 7.0)), c12.L(Vector3(0, 0.2, 2.0))]))
	ok("c12_leave", await use(c12.its["exit"], [Vector3(0, 0, 1)], 1.2) and await wait_until(func(): return (game.has_flag("ch12_left_station")
		and world.player.global_position.y > -1.0 and c12.hound != null), 300), "%s left %s hound %s" % [str(world.player.global_position), game.has_flag("ch12_left_station"), c12.hound])
	await frames(60)
	ok("c12_eddie_out", c12._comp().global_position.distance_to(world.player.global_position) < 5.0)
	var back: Array = c12.ROUTE.duplicate()
	back.reverse()
	ok("c12_walk_back", await run_route(back + [c12.c10.hl(Vector3(0.6, 0.1, 0.0)), c12.c10.hl(Vector3(0.6, 0.7, 2.4)), c12.c10.hl(Vector3(0.6, 0.7, 4.6))]),
		str(world.player.global_position))
	ok("c12_returned", await wait_until(func(): return game.has_flag("ch12_returned"), 120) and c12.hound == null
		and FileAccess.file_exists(game.checkpoint_path("chapter13_return")))
	ok("c12_ending", await wait_talk(func(): return game.has_flag("chapter_12_complete") and not c12._busy.get("ending", false), 90.0)
		and said.has("We need answers.") and c12.report["ending_runs"] == 1)
	ok("c12_fov_restored", c12.report.get("ending_fov_restored", false) and world.player.controls_enabled)
	ok("c12_end_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter13_end")))
	ok("c12_eddie_home", c12.c10.inside_room(c12._node("Eddie")))
	# after the card, displayed Chapter 14 begins at the mill house (chapter13.gd)
	ok("c12_next_chapter", await wait_until(func(): return game.has_flag("ch13_started") and c12.chapter13 != null, 60 * 10) and game.chapter_number() == 14)
	await wait_until(func(): return not c12.chapter13._busy.get("opening", false), 60 * 8)

	# ---- loads: nothing duplicated, nothing replayed
	await reload()
	ok("c12_load_complete", c12 != null and game.inventory.count("underground_records") == 1 and c12.skitter == null and c12.hound == null
		and c12.report["ending_runs"] == 0 and c12.report["below_runs"] == 0 and c12.map_prop != null)
	# a load from the underground checkpoint (before the records): the encounter has not happened yet
	game.load_checkpoint("chapter13_underground")
	game.save_game()
	game.load_game()
	game.load_requested = true
	world.free()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c12_load_underground", c12 != null and game.has_flag("ch12_chamber_open") and not game.has_flag("ch12_records_taken") and c12.skitter == null
		and world.player.global_position.y < -40.0 and c12.c9.follows["Eddie"].active and not game.has_item("underground_records"))
	await frames(90)
	ok("c12_eddie_near_after_load", c12._comp().global_position.distance_to(world.player.global_position) < 5.0,
		"%s / player %s" % [str(c12._comp().global_position - c12.FAC), str(world.player.global_position - c12.FAC)])

	# ---- without Marcus: the opening works, no Marcus line, he never appears
	world.free()
	said.clear()
	DEV.prepare(game, true)
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	await wait_until(func(): return not c12._busy.get("opening", false), 60 * 6)
	ok("c12_lost_roster", c12 != null and c12.group() == ["Eddie", "Ruth", "Sarah"] and not c12._node("Marcus").visible)
	ok("c12_lost_talk", await use(c12.its["npc_Eddie"], [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)], 1.3)
		and await wait_talk(func(): return game.has_flag("ch12_talk_done") and p4.choice.is_open(), 90.0)
		and not said.has("Noah drew that. Or he saw it somewhere."))
	p4.choice.pick(1)
	await frames(30)
	ok("c12_check_first", not game.has_flag("ch12_set_out"))
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
