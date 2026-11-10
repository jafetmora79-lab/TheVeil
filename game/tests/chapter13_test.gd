extends SceneTree
## THE VEIL - displayed CHAPTER 14 "Into the Veil" (chapter13.gd) automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter13_test.gd
## From the developer entry (game/chapters/setups/dev_chapter13.gd: Chapter 13 complete). The player walks (physics) the road
## to the district (the sign seen twice), stands in a dense mist zone and recovers in clear air (Mist Exposure),
## passes the street Skitter, opens the checkpoint gate, runs from the Shellcrawler (sprinting) into the passage,
## hears the voice, opens the ancient entrance, makes the decision (the evidence), crawls out, escapes the district,
## returns, sees the night scene. Then: loads (no duplicates, no replays), the other decision from its checkpoint,
## and the roster without Marcus.

const DEV := preload("res://game/chapters/setups/dev_chapter13.gd")

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



func D(p: Vector3) -> Vector3:
	return c13.D(p)


func UL(p: Vector3) -> Vector3:
	return c13.UL(p)


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	dlg.auto_confirm = true
	DEV.prepare(game)
	for cp in ["chapter14_start", "chapter14_district", "chapter14_courtyard", "chapter14_entrance", "chapter14_decision", "chapter14_return", "chapter14_end"]:
		if FileAccess.file_exists(game.checkpoint_path(cp)):
			DirAccess.remove_absolute(game.checkpoint_path(cp))
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c13_entry", c13 != null and game.has_flag("ch13_started") and game.chapter_number() == 14, str(game.chapter_number()))
	ok("c13_previous_kept", game.has_flag("chapter_12_complete") and game.inventory.count("underground_records") == 1 and game.has_flag("ch12_left_now"))
	ok("c13_title_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 14  —  INTO THE VEIL", 60 * 8), world.hud.chapter_l.text)
	ok("c13_start_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter14_start")))
	ok("c13_group_home", c13.group().all(func(k): return c13.c10.inside_room(c13._node(k))) and c13._node("Marcus").visible and c12.map_prop != null)

	# ---- scene 1: the map; preparation and the companion
	c13.its["npc_Eddie"].interact(world.player)
	ok("c13_talk", await wait_talk(func(): return game.has_flag("ch13_talk_done") and p4.choice.is_open(), 90.0)
		and said.has("Great. The creepy road to the creepy place. Love that.") and said.has("If Noah saw that symbol, he might have followed it. Find out where it goes."))
	var labels: Array = []
	for b in p4.choice._box.get_children():
		if b is Button:
			labels.append((b as Button).text)
	ok("c13_companion_options", labels.size() == 5 and "Eddie" in str(labels[0]) and "Marcus" in str(labels) and "INTO THE VEIL" in p4.choice._title.text, str(labels))
	p4.choice.pick(0)
	ok("c13_set_out", await wait_until(func(): return game.has_flag("ch13_set_out"), 60) and c13.companion() == "Eddie" and c13.c9.follows["Eddie"].active
		and not c13.c9.follows["Ruth"].active)
	await wait_talk(func(): return not dlg.is_busy(), 10.0)

	# ---- scene 2: the road; the sign twice; the district
	ok("c13_walk_out", await walk_world([c13.c10.hl(Vector3(0.6, 0.7, 4.4)), c13.c10.hl(Vector3(0.6, 0.7, 2.4)), c13.c10.hl(Vector3(0.6, 0.1, 0.0))]),
		str(world.player.global_position))
	ok("c13_walk_road", await walk_world(c13.ROAD), str(world.player.global_position))
	ok("c13_sign1", game.has_flag("ch13_sign1"))
	ok("c13_district", await wait_until(func(): return game.has_flag("ch13_district_reached"), 60) and FileAccess.file_exists(game.checkpoint_path("chapter14_district")))
	ok("c13_walk_sign2", await walk_world([D(Vector3(0.0, 0.2, 5.0))]))
	ok("c13_sign_again", await wait_talk(func(): return said.has("Okay. That's officially not normal."), 20.0))

	# ---- Mist Exposure: it rises in the dense zone, never takes control, falls in clear air
	ok("c13_walk_mist", await walk_world([D(Vector3(-3.5, 0.2, 12.0))]))
	await frames(60 * 7)
	var e1: float = c13.exposure()
	ok("c13_exposure_rises", e1 > 45.0 and c13._heart.playing and c13._overlay.visible and c13._lp_idx >= 0 and world.player.controls_enabled, "%.0f" % e1)
	ok("c13_walk_clear", await walk_world([D(Vector3(0.0, 0.2, 2.5))]))
	await frames(60 * 6)
	ok("c13_exposure_falls", c13.exposure() < 5.0 and not c13._overlay.visible and c13._lp_idx < 0, "%.0f" % c13.exposure())
	ok("c13_health_untouched", world.player.health == 100.0)

	# ---- the street: a Skitter on the roof, a second one patrols; past it on the far side
	ok("c13_walk_street", await walk_world([D(Vector3(4.5, 0.2, 6.0)), D(Vector3(4.5, 0.2, 12.0))]))
	ok("c13_roof_skitter", await wait_talk(func(): return game.has_flag("ch13_street_seen") and said.has("I see it."), 20.0))
	ok("c13_patroller", await wait_until(func(): return c13.skitters.size() == 1, 60 * 6) and world.get_node_or_null("C13_RoofSkitter") == null)
	var hp0: float = world.player.health
	ok("c13_sneak", await walk_world([D(Vector3(4.5, 0.2, 24.0)), D(Vector3(4.5, 0.2, 34.0)), D(Vector3(4.2, 0.2, 36.0)), D(Vector3(4.2, 0.2, 40.0)),
		D(Vector3(7.5, 0.2, 40.0))]), str(world.player.global_position - c13.D_ORIGIN))

	# ---- the checkpoint: note, crank, release
	c13._read_note(null)
	ok("c13_note", game.has_item("checkpoint_note"))
	c13._use_release(null)
	ok("c13_release_needs_crank", not game.has_flag("ch13_gate_open"))
	await wait_talk(func(): return not dlg.is_busy(), 10.0)
	ok("c13_crank", await use(c13.its["crank"], [Vector3(-1, 0, 0)], 1.1) and game.has_flag("ch13_crank_found"))
	ok("c13_walk_release", await walk_world([D(Vector3(7.5, 0.2, 40.0)), D(Vector3(4.2, 0.2, 40.0)), D(Vector3(3.2, 0.2, 42.4))]))
	ok("c13_release", await use(c13.its["release"], [Vector3(0, 0, -1)], 1.0) and await wait_until(func(): return game.has_flag("ch13_gate_open"), 60 * 6)
		and c13.crab != null and FileAccess.file_exists(game.checkpoint_path("chapter14_courtyard")))
	if c13.crab == null:
		print("RESULT FAIL (gate not opened)")
		quit(1)
		return
	ok("c13_crab_hidden", c13.crab.get_meta("hidden", false))

	# ---- the Shellcrawler
	ok("c13_walk_gate", await walk_world([D(Vector3(0.0, 0.2, 42.0)), D(Vector3(0.0, 0.2, 48.5))]), str(world.player.global_position - c13.D_ORIGIN))
	ok("c13_crab_reveal", await wait_talk(func(): return game.has_flag("ch13_crab_seen") and world.player.controls_enabled, 40.0) and said.has("Back up. Slowly."))
	var crab_hp: float = world.player.health
	var esc: bool = await run_route([D(Vector3(-9.0, 0.2, 52.0)), D(Vector3(-15.0, 0.2, 60.0)), D(Vector3(-14.0, 0.2, 72.0)), D(Vector3(-2.0, 0.2, 73.6))])
	ok("c13_crab_escape", esc, str(world.player.global_position - c13.D_ORIGIN))
	ok("c13_crab_moved", c13.crab != null and c13.crab.global_position.distance_to(D(c13.CRAB_HIDE)) > 4.0 and float(c13.report["crab_max_step"]) < 0.3,
		"step %.2f hits %d" % [c13.report["crab_max_step"], c13.report["crab_hits"]])
	ok("c13_player_alive", world.player.health > 0.0, "%.0f -> %.0f" % [crab_hp, world.player.health])
	await wait_until(func(): return c13._comp().global_position.distance_to(world.player.global_position) < 5.0, 60 * 10)
	ok("c13_passage", await use(c13.its["passage"], [Vector3(0, 0, -1), Vector3(0.6, 0, -1), Vector3(-0.6, 0, -1)], 1.5) and await wait_until(func(): return (game.has_flag("ch13_in_passage")
		and world.player.global_position.y < -40.0 and c13.crab == null), 300), "comp %.1f m, focus %s, prompt '%s', pos %s" % [c13._comp().global_position.distance_to(world.player.global_position),
		world.player._focus, c13.its["passage"].prompt_text, str(world.player.global_position - c13.D_ORIGIN)])
	await frames(30)
	ok("c13_comp_in_passage", c13._comp().global_position.distance_to(world.player.global_position) < 4.0)

	# ---- the passage of echoes
	ok("c13_voice", await wait_talk(func(): return said.has("Don't follow it."), 30.0) and said.has("That sounded like Ruth. But Ruth is back at the house."))
	ok("c13_walk_passage", await walk_world([UL(Vector3(0, 0.2, 12.0)), UL(Vector3(12.0, 0.2, 12.0)), UL(Vector3(12.0, 0.2, 26.0))]),
		str(world.player.global_position - c13.U))
	ok("c13_chamber", await wait_talk(func(): return game.has_flag("ch13_chamber_reached") and said.has("Whatever this place is, it wasn't built by the town."), 20.0))
	c13._examine(null, "plaque")
	await wait_talk(func(): return not dlg.is_busy(), 10.0)
	ok("c13_walk_winch", await walk_world([UL(Vector3(17.5, 0.2, 33.0))]))
	ok("c13_winch", await use(c13.its["winch"], [Vector3(-1, 0, 0)], 1.0) and game.has_flag("ch13_winch_turned"))
	await wait_talk(func(): return not dlg.is_busy(), 10.0)
	ok("c13_walk_beam", await walk_world([UL(Vector3(12.0, 0.2, 35.5))]))
	await wait_until(func(): return c13._comp().global_position.distance_to(world.player.global_position) < 6.0, 60 * 6)
	c13._move_beam(null)
	ok("c13_entrance", await wait_talk(func(): return game.has_flag("ch13_entrance_open") and said.has("I don't know what that is."), 60.0)
		and c13.report["mist_runs"] == 1 and FileAccess.file_exists(game.checkpoint_path("chapter14_entrance")))
	ok("c13_decision_panel", await wait_talk(func(): return game.has_flag("ch13_collapsed") and p4.choice.is_open(), 40.0)
		and FileAccess.file_exists(game.checkpoint_path("chapter14_decision")))
	ok("c13_mist_fov", c13.report.get("mist_fov_restored", false))
	var trust0: int = world.survivors.trust("Eddie")
	p4.choice.pick(1)
	ok("c13_evidence", await wait_talk(func(): return game.has_flag("ch13_choice_made") and world.player.controls_enabled and not dlg.is_busy(), 30.0)
		and game.has_flag("ch13_choice_evidence") and game.inventory.count("ancient_rubbing") == 1)
	await frames(20)
	ok("c13_evidence_cost", world.survivors.health("Eddie") == "injured" and world.survivors.trust("Eddie") == trust0 - 10 and c13.c9.follows["Eddie"].walk_speed < 1.6,
		"%s %d -> %d" % [world.survivors.health("Eddie"), trust0, world.survivors.trust("Eddie")])

	# ---- out through the damaged passage, the district in the mist, home
	ok("c13_walk_crawl", await walk_world([UL(Vector3(12.0, 0.2, 31.0)), UL(Vector3(5.0, 0.2, 30.0)), UL(Vector3(3.6, 0.2, 30.0))]), str(world.player.global_position - c13.U))
	ok("c13_crawl", await use(c13.its["crawl"], [Vector3(1, 0, 0)], 1.0) and await wait_until(func(): return (game.has_flag("ch13_out_of_passage")
		and world.player.global_position.y > -5.0), 300))
	await frames(60)
	ok("c13_comp_out", c13._comp().global_position.distance_to(world.player.global_position) < 5.0)
	var back: Array = c13.ROAD.duplicate()
	back.reverse()
	ok("c13_escape_route", await run_route([D(Vector3(-4.0, 0.2, 46.0)), D(Vector3(0.0, 0.2, 45.5)), D(Vector3(0.0, 0.2, 42.0)), D(Vector3(4.5, 0.2, 36.0)),
		D(Vector3(4.5, 0.2, 8.0)), D(Vector3(4.0, 0.2, 1.0))] + back + [c13.c10.hl(Vector3(0.6, 0.1, 0.0)), c13.c10.hl(Vector3(0.6, 0.7, 2.4)), c13.c10.hl(Vector3(0.6, 0.7, 4.6))]),
		str(world.player.global_position))
	ok("c13_returned", await wait_until(func(): return game.has_flag("ch13_returned"), 120) and FileAccess.file_exists(game.checkpoint_path("chapter14_return")))
	ok("c13_ending", await wait_talk(func(): return game.has_flag("chapter_13_complete") and not c13._busy.get("night", false), 120.0)
		and said.has("We get ready.") and said.has("And what did it cost?") and c13.report["ending_runs"] == 1)
	ok("c13_end_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter14_end")))
	# after the card, displayed Chapter 15 begins in the same house (chapter14.gd)
	ok("c13_next_chapter", await wait_until(func(): return game.has_flag("ch14_started") and c13.chapter14 != null, 60 * 10) and game.chapter_number() == 15)
	await wait_until(func(): return not c13.chapter14._busy.get("opening", false), 60 * 12)
	ok("c13_ending_restored", c13.report.get("ending_fov_restored", false) and world.player.controls_enabled and c13._lp_idx < 0
		and root.get_viewport().get_camera_3d() == world.player.camera)

	# ---- loads: nothing duplicated, nothing replayed, the choice kept
	await reload()
	ok("c13_load_complete", c13 != null and game.inventory.count("ancient_rubbing") == 1 and c13.crab == null and c13.skitters.is_empty()
		and c13.report["ending_runs"] == 0 and c13.report["mist_runs"] == 0 and String(c13.st()["choice"]) == "evidence"
		and world.survivors.health("Eddie") == "injured")
	# the other decision, from the checkpoint before it
	game.load_checkpoint("chapter14_decision")
	game.save_game()
	game.load_game()
	game.load_requested = true
	world.free()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c13_decision_again", await wait_until(func(): return p4.choice.is_open(), 60 * 5) and game.has_flag("ch13_collapsed") and not game.has_flag("ch13_choice_made"))
	var ex0: float = c13.exposure()
	var food0: int = game.inventory.size()
	p4.choice.pick(0)
	ok("c13_help", await wait_talk(func(): return game.has_flag("ch13_choice_help") and world.player.controls_enabled and not dlg.is_busy(), 30.0)
		and c13.exposure() > ex0 + 5.0 and world.survivors.health("Eddie") == "healthy" and not game.has_item("ancient_rubbing"), "%.0f -> %.0f" % [ex0, c13.exposure()])

	# ---- without Marcus
	world.free()
	said.clear()
	DEV.prepare(game, true)
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	await wait_until(func(): return c13 != null and not c13._busy.get("opening", false), 60 * 6)
	c13.its["npc_Eddie"].interact(world.player)
	ok("c13_lost_talk", await wait_talk(func(): return game.has_flag("ch13_talk_done") and p4.choice.is_open(), 90.0)
		and not said.has("If Noah saw that symbol, he might have followed it. Find out where it goes.") and not c13._node("Marcus").visible
		and not ("Marcus" in str(c13.companion_options())))
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
