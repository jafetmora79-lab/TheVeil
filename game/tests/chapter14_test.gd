extends SceneTree
## THE VEIL - displayed CHAPTER 15 "The Last Shelter" (chapter14.gd) automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter14_test.gd
## From the developer entry (game/chapters/setups/dev_chapter14.gd: Chapter 14 complete, the evidence secured, Eddie hurt).
## Wake, the window, the meeting; treat Eddie and pack; the emergency run (a find, the Hound from the fog, back
## inside); barricade the front door and the window (not the back); the back way; a talk; the siege: the window
## braced, the Hounds at the back door, the table shoved in time; the Shellcrawler at the front; out the back on foot,
## Marcus left behind at the fence; the field; the shelter gone. Loads; the failed rescue and going back for Marcus
## from their checkpoints; the roster without Marcus.

const DEV := preload("res://game/chapters/setups/dev_chapter14.gd")

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
var c13: Node
var c14: Node
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
	c13 = c12.chapter13 if c12 else null
	c14 = c13.chapter14 if c13 else null


func _initialize() -> void:
	_run.call_deferred()
	create_timer(3000.0).timeout.connect(func():
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




func hl(p: Vector3) -> Vector3:
	return c14.hl(p)


func boot_checkpoint(cp: String) -> void:
	game.load_checkpoint(cp)
	game.save_game()
	game.load_game()
	game.load_requested = true
	world.free()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()


func walk_out_back() -> bool:
	# round the living-room table on its window side, along the kitchen wall, through the kitchen to the back door
	return await walk_world([hl(Vector3(-0.6, 0.7, 5.0)), hl(Vector3(-0.2, 0.7, 5.8)), hl(Vector3(-0.2, 0.7, 7.6)), hl(Vector3(-1.25, 0.7, 7.6)),
		hl(Vector3(-1.25, 0.7, 9.4)), hl(Vector3(-1.6, 0.7, 10.4)), hl(Vector3(-2.25, 0.7, 11.0)), hl(Vector3(-2.25, 0.1, 12.8)), c14.ESCAPE[0]])


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	dlg.auto_confirm = true
	DEV.prepare(game)
	for cp in ["chapter15_start", "chapter15_prepared", "chapter15_siege", "chapter15_evacuation", "chapter15_safe", "chapter15_end"]:
		if FileAccess.file_exists(game.checkpoint_path(cp)):
			DirAccess.remove_absolute(game.checkpoint_path(cp))
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c14_entry", c14 != null and game.has_flag("ch14_started") and game.chapter_number() == 15, str(game.chapter_number()))
	ok("c14_previous_kept", game.has_flag("chapter_13_complete") and game.has_item("ancient_rubbing") and game.has_item("underground_records"))
	ok("c14_title_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 15  —  THE LAST SHELTER", 60 * 12), world.hud.chapter_l.text)
	ok("c14_start_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter15_start")))
	ok("c14_shelter", c14.house == c14.c10.house and c14.present() == ["Eddie", "Ruth", "Sarah", "Marcus"]
		and c14.present().all(func(k): return c14.c10.inside_room(c14._node(k))) and c14._node("Marcus").visible)
	ok("c14_woke", said.has("You need to see this.") and world.player.controls_enabled)
	world.survivors.set_health("Eddie", "injured")      # Chapter 14's choice: the evidence first (Eddie hurt)
	game.add_item("painkillers")

	# ---- the window, the meeting
	ok("c14_walk_window", await walk_world([hl(Vector3(0.0, 0.7, 5.6)), hl(Vector3(-1.2, 0.7, 4.4))]))
	ok("c14_window", await wait_talk(func(): return game.has_flag("ch14_meeting_done"), 60.0) and said.has("It's coming this way.")
		and said.has("Whatever comes through that fog.") and said.has("Prepare for what?") and said.has("And this time, we all come back. Together. Right?"))

	# ---- the supplies: treat Eddie, pack
	ok("c14_supplies_reach", await use(c14.its["supplies"], [Vector3(-1, 0, 0), Vector3(0, 0, -1)], 1.2) and await wait_until(func(): return p4.choice.is_open(), 60))
	ok("c14_supplies_panel", "WHAT WE HAVE" in p4.choice._title.text and "Eddie  -  Injured" in p4.choice._title.text, p4.choice._title.text)
	var pk: int = game.inventory.count("painkillers")
	p4.choice.pick(0)
	await frames(10)
	ok("c14_treated", world.survivors.health("Eddie") == "recovering" and game.inventory.count("painkillers") == pk - 1 and p4.choice.is_open())
	var labels: Array = []
	for b in p4.choice._box.get_children():
		if b is Button:
			labels.append((b as Button).text)
	p4.choice.pick(labels.find(labels.filter(func(t): return "Pack" in t)[0]))
	ok("c14_packed", await wait_until(func(): return game.has_flag("ch14_supplies_checked"), 60) and String(c14.st()["provisions"]) != "")

	# ---- the emergency run (optional): a find, a Hound from the fog, back inside
	c14._check_supplies(null)
	await wait_until(func(): return p4.choice.is_open(), 60)
	labels.clear()
	for b in p4.choice._box.get_children():
		if b is Button:
			labels.append((b as Button).text)
	p4.choice.pick(labels.find(labels.filter(func(t): return "emergency supplies" in t)[0]))
	ok("c14_run_started", await wait_until(func(): return game.has_flag("ch14_run_started"), 60) and c14.props["find0"].visible)
	ok("c14_run_out", await walk_world([hl(Vector3(0.6, 0.7, 4.4)), hl(Vector3(0.6, 0.7, 2.4)), hl(Vector3(0.6, 0.1, 0.0)), Vector3(-86.0, 0.2, 1.0), Vector3(-84.0, 0.2, -2.6)]),
		str(world.player.global_position))
	var food0: int = game.inventory.count("canned_food")
	var find0: Node3D = c14.props["find0"]
	ok("c14_find", await use(find0.get_node("Interact"), [Vector3(0, 0, 1)], 1.0) and game.inventory.count("canned_food") == food0 + 1)
	ok("c14_run_hound", await wait_talk(func(): return c14.run_hound != null and said.has("That's what people say right before something terrible happens."), 40.0))
	ok("c14_run_back", await run_route([Vector3(-86.0, 0.2, 1.0), hl(Vector3(0.6, 0.1, 0.0)), hl(Vector3(0.6, 0.7, 2.4)), hl(Vector3(0.6, 0.7, 4.8))]),
		str(world.player.global_position))
	ok("c14_run_done", await wait_until(func(): return game.has_flag("ch14_run_done"), 120) and c14.run_hound == null and world.player.health > 0.0)

	# ---- defences (front door and window; the back left), the back way
	ok("c14_window_boards", await use(c14.its["window"], [Vector3(0, 0, 1)], 1.0) and await wait_until(func(): return c14.st()["defenses"].has("window"), 120))
	await wait_until(func(): return not c14._busy.get("defend", false) and world.player.controls_enabled, 120)
	c14._defend(null, "front")
	await wait_until(func(): return c14.st()["defenses"].has("front") and world.player.controls_enabled, 120)
	c14._check_escape(null)
	ok("c14_escape", await wait_talk(func(): return game.has_flag("ch14_escape_ready") and said.has("Then we improvise."), 30.0)
		and String(c14.st()["escape"]) == "on_foot" and c14.its["INT_Door_Kitchen"].is_open)
	await wait_talk(func(): return not dlg.is_busy() and not world.conversing, 20.0)
	ok("c14_prepared", await wait_until(func(): return game.has_flag("ch14_prepared"), 600) and FileAccess.file_exists(game.checkpoint_path("chapter15_prepared")))
	c14.its["talk_Ruth"].interact(world.player)
	ok("c14_calm_talk", await wait_talk(func(): return said.has("I know. That's what worries me."), 30.0))
	await wait_talk(func(): return not dlg.is_busy() and not world.conversing, 10.0)

	# ---- the siege: Skitters at the window
	ok("c14_watch", c14.its["watch"].prompt_text != "")
	c14._keep_watch(null)
	ok("c14_siege_checkpoint", game.has_flag("ch14_siege_started") and FileAccess.file_exists(game.checkpoint_path("chapter15_siege")))
	ok("c14_skitter_window", await wait_talk(func(): return c14._busy.get("brace_open", false) and said.has("There's something outside!") and world.player.controls_enabled, 40.0))
	ok("c14_brace", await use(c14.its["brace"], [Vector3(0, 0, 1)], 1.0) and await wait_until(func(): return game.has_flag("ch14_skitters_done"), 60 * 10)
		and String(c14.st()["window"]) == "held")
	# ---- the Hounds at the weak (back) door; ten seconds from control
	ok("c14_weak_door", c14.weak_door() == "back")
	var trust0: int = world.survivors.trust("Sarah")
	ok("c14_rescue_starts", await wait_talk(func(): return c14._rescue_left > 0.0, 60.0) and world.player.controls_enabled and c14._rescue_left > 9.0,
		"%.1f" % c14._rescue_left)
	ok("c14_shove", await use(c14.its["shove"], [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)], 1.0))
	ok("c14_rescued", await wait_talk(func(): return game.has_flag("ch14_hounds_done"), 40.0) and String(c14.st()["rescue"]) == "saved"
		and world.survivors.trust("Sarah") >= mini(trust0 + 10, 100) and world.survivors.health("Sarah") != "serious")
	# ---- the Shellcrawler; out the back
	ok("c14_crab", await wait_talk(func(): return game.has_flag("ch14_evac_started") and said.has("We can't stay here.") and world.player.controls_enabled, 60.0)
		and c14.crab != null and FileAccess.file_exists(game.checkpoint_path("chapter15_evacuation")))
	ok("c14_followers", c14.present().all(func(k): return c14.c9.follows[k].active))
	await wait_talk(func(): return not dlg.is_busy(), 15.0)
	ok("c14_walk_out_back", await walk_out_back(), str(world.player.global_position))
	ok("c14_walk_fence", await run_route([c14.ESCAPE[1]]) or game.has_flag("ch14_separation"), str(world.player.global_position))   # the choice stops the walk
	ok("c14_separation", await wait_talk(func(): return p4.choice.is_open() and said.has("My leg's caught! Go! Find Noah!"), 30.0))
	p4.choice.pick(1)
	ok("c14_left", await wait_talk(func(): return game.has_flag("ch14_separation_made"), 30.0) and "Marcus" in c14.st()["missing"] and game.has_flag("ch14_marcus_missing"))
	ok("c14_walk_safe", await run_route([c14.ESCAPE[2]]), str(world.player.global_position))
	ok("c14_marcus_out_of_sight", not c14._node("Marcus").visible)
	ok("c14_ending", await wait_talk(func(): return game.has_flag("chapter_14_complete") and not c14._busy.get("ending", false), 90.0)
		and said.has("That was the last safe place we had.") and said.has("Back to where this started.") and not c14.house.visible)
	ok("c14_end_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter15_end")) and FileAccess.file_exists(game.checkpoint_path("chapter15_safe")))
	# after the card, the finale (displayed Chapter 16) begins (chapter15.gd)
	ok("c14_next_chapter", await wait_until(func(): return game.has_flag("ch15_started") and c14.chapter15 != null, 60 * 10) and game.chapter_number() == 16)
	await wait_talk(func(): return game.has_flag("ch15_opening_done"), 90.0)
	ok("c14_ending_restored", c14.report.get("ending_fov_restored", false) and world.player.controls_enabled and root.get_viewport().get_camera_3d() == world.player.camera)

	# ---- loads
	await reload()
	ok("c14_load_complete", c14 != null and not c14.house.visible and not c14._node("Marcus").visible and c14.present() == ["Eddie", "Ruth", "Sarah"]
		and c14.report["ending_runs"] == 0 and c14.hounds.is_empty() and c14.crab == null
		and c14.chapter15 != null)
	# the other choice at the fence: go back for Marcus
	await boot_checkpoint("chapter15_evacuation")
	ok("c14_load_evac", c14 != null and await wait_talk(func(): return game.has_flag("ch14_evac_started") and world.player.controls_enabled and not dlg.is_busy(), 30.0)
		and not game.has_flag("ch14_separation") and c14._node("Marcus").visible)
	await frames(60)
	ok("c14_walk_out_back2", await walk_out_back(), str(world.player.global_position))
	ok("c14_walk_fence2", await run_route([c14.ESCAPE[1]]) or game.has_flag("ch14_separation"))
	await wait_talk(func(): return p4.choice.is_open(), 30.0)
	var hp: float = world.player.health
	p4.choice.pick(0)
	ok("c14_went_back", await wait_talk(func(): return game.has_flag("ch14_separation_made") and world.player.controls_enabled, 30.0)
		and not ("Marcus" in c14.st()["missing"]) and world.player.health < hp and c14.c9.follows["Marcus"].active)
	# a failed rescue (from the siege checkpoint): seriously hurt, never killed
	await boot_checkpoint("chapter15_siege")
	ok("c14_siege_resumes", await wait_talk(func(): return c14._busy.get("brace_open", false), 60.0))
	c14._brace_window(null)
	ok("c14_rescue_again", await wait_talk(func(): return c14._rescue_left > 0.0, 60.0))
	ok("c14_rescue_failed", await wait_until(func(): return game.has_flag("ch14_hounds_done"), 60 * 40) and String(c14.st()["rescue"]) == "hurt"
		and world.survivors.health("Sarah") == "serious" and world.survivors.alive("Sarah") and c14._node("Sarah").visible)

	# ---- without Marcus
	world.free()
	said.clear()
	DEV.prepare(game, true)
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	await wait_until(func(): return c14 != null and not c14._busy.get("opening", false), 60 * 8)
	ok("c14_lost_roster", c14.present() == ["Eddie", "Ruth", "Sarah"] and not c14._node("Marcus").visible and c14.separation_target() == "Ruth")
	await walk_world([hl(Vector3(0.0, 0.7, 5.6)), hl(Vector3(-1.2, 0.7, 4.4))])
	ok("c14_lost_meeting", await wait_talk(func(): return game.has_flag("ch14_meeting_done"), 60.0) and said.has("Prepare for what?"))
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
