extends SceneTree
## THE VEIL - displayed CHAPTER 16 "What Remains" (chapter15.gd), the finale, automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter15_test.gd
## From the developer entry (game/tools/dev_chapter15.gd: Chapter 15 complete, Sarah saved, Marcus brought back at the
## fence). The refuge (supplies, a talk, the plan); the road and its finds; the Colossus reveal and the crossing (a
## detection and its retry, then cover to cover); the district; the passage, the rubble, the doorway, the ancient
## passage, the great chamber, the records, the controls under falling stone; the decision. Ending A played; then B
## and C from the pre-decision checkpoint; the epilogues, the credits, the menu, the save left before the decision.
## Then the epilogue for other rosters (Marcus left at the fence; Marcus lost in Chapter 10).

const DEV := preload("res://game/tools/dev_chapter15.gd")

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
var c15: Node
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
	c15 = c14.chapter15 if c14 else null


func _initialize() -> void:
	_run.call_deferred()
	create_timer(3600.0).timeout.connect(func():
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





func UL(p: Vector3) -> Vector3:
	return c15.UL(p)


func D(p: Vector3) -> Vector3:
	return c13.D(p)


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


func pick_label(contains: String) -> void:
	var labels: Array = []
	for b in p4.choice._box.get_children():
		if b is Button:
			labels.append((b as Button).text)
	for i in labels.size():
		if contains in String(labels[i]):
			p4.choice.pick(i)
			return
	print("  no option with ", contains, " in ", labels)


func credits_up() -> bool:
	return c15._menu != null and is_instance_valid(c15._menu)


## The seal steps (B and C): lever (west), then wheel (east).
func seal_steps() -> bool:
	var a := await walk_world([UL(Vector3(12.0, 0.2, 74.0)), UL(Vector3(-1.8, 0.2, 74.0))])
	a = a and await use(c15.its["ctrl_A"], [Vector3(1, 0, 0)], 1.2)
	await frames(10)
	var b := await walk_world([UL(Vector3(12.0, 0.2, 74.0)), UL(Vector3(25.8, 0.2, 74.0))])
	b = b and await use(c15.its["ctrl_B"], [Vector3(-1, 0, 0)], 1.2)
	return a and b


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	dlg.auto_confirm = true
	DEV.prepare(game)
	for cp in ["chapter16_start", "chapter16_colossus", "chapter16_passage", "chapter16_chamber", "chapter16_decision"]:
		if FileAccess.file_exists(game.checkpoint_path(cp)):
			DirAccess.remove_absolute(game.checkpoint_path(cp))
	if FileAccess.file_exists("user://veil_endings.json"):
		DirAccess.remove_absolute("user://veil_endings.json")
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c15_entry", c15 != null and game.has_flag("ch15_started") and game.chapter_number() == 16, str(game.chapter_number()))
	ok("c15_previous_kept", game.has_flag("chapter_14_complete") and game.has_item("ancient_rubbing") and String(game.world_state["ch14"]["rescue"]) == "saved")
	ok("c15_opening", await wait_talk(func(): return game.has_flag("ch15_opening_done"), 60.0) and said.has("I really need to stop asking questions.")
		and said.has("So... that's it? No more supermarket. No more shelter. Nothing?"))
	ok("c15_title_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 16  —  WHAT REMAINS", 60 * 8), world.hud.chapter_l.text)
	ok("c15_start_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter16_start")))
	ok("c15_roster", c15.present() == ["Eddie", "Ruth", "Sarah", "Marcus"] and c15.present().all(func(k): return (c15._node(k).visible
		and c15._node(k).global_position.distance_to(c15.F(c15.REFUGE_SPOTS[k])) < 1.0)) and not c14.house.visible)

	# ---- the refuge: what was carried, a find, a talk, the plan
	world.survivors.set_health("Sarah", "injured")
	game.add_item("painkillers")
	c15._supplies(null)
	ok("c15_supplies_panel", await wait_until(func(): return p4.choice.is_open(), 60) and "Underground Records" in p4.choice._title.text
		and "Sarah  -  Injured" in p4.choice._title.text, p4.choice._title.text)
	var pk: int = game.inventory.count("painkillers")
	pick_label("Treat Sarah")
	await frames(10)
	ok("c15_treated", world.survivors.health("Sarah") == "recovering" and game.inventory.count("painkillers") == pk - 1)
	pick_label("Done")
	await frames(10)
	var w0: int = game.inventory.count("water_bottle")
	(c15.props["ch15/refuge0"].get_node("Interact") as Interactable).interact(world.player)
	(c15.props["ch15/refuge0"].get_node("Interact") as Interactable).interact(world.player)
	ok("c15_refuge_find_once", game.inventory.count("water_bottle") == w0 + 1)
	c15.its["talk_Eddie"].interact(world.player)
	ok("c15_talk_eddie", await wait_talk(func(): return said.has("I would've picked something less scary if I'd known."), 30.0))
	await wait_talk(func(): return not dlg.is_busy() and not world.conversing, 10.0)
	c15._plan(null)
	ok("c15_plan", await wait_talk(func(): return game.has_flag("ch15_plan_done"), 40.0) and said.has("Of course it is.")
		and said.has("The marks on the rubbing match the doorway. Whatever's down there, someone tried to shut it in before."))
	await wait_talk(func(): return not dlg.is_busy() and not world.conversing, 10.0)
	c15._set_out(null)
	ok("c15_set_out", await wait_until(func(): return game.has_flag("ch15_set_out") and world.player.controls_enabled, 300)
		and world.player.global_position.y > -1.0 and c15.present().all(func(k): return c15.c9.follows[k].active))

	# ---- the road: the finds; the Colossus
	var notes0: bool = game.has_item("last_note")
	ok("c15_walk_road", await walk_world(c15.ROUTE), str(world.player.global_position))
	for i in c15.FINDS.size():
		var it := c15.props["ch15/find%d" % i].get_node("Interact") as Interactable
		it.interact(world.player)
	ok("c15_finds", game.has_item("last_note") and not notes0)
	ok("c15_colossus_reveal", await wait_talk(func(): return game.has_flag("ch15_colossus_seen") and world.player.controls_enabled and not c15._busy.get("colossus", false), 40.0)
		and said.has("Everybody down!") and c15.colossus != null and c15.report.get("colossus_in_view", false) and FileAccess.file_exists(game.checkpoint_path("chapter16_colossus")))
	# seen in the open while it looks: it reacts, then back to the last cover
	await wait_until(func(): return c15._col_phase == "look", 60 * 12)
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	ok("c15_detected", await wait_until(func(): return c15.report["detections"] >= 1, 60 * 2))
	ok("c15_retry", await wait_until(func(): return c15.report["retries"] >= 1 and world.player.controls_enabled, 60 * 8)
		and c15._cover_index(world.player.global_position) == c15._last_cover)
	# cover to cover, moving only while it walks
	var crossed := true
	for i in range(c15._last_cover + 1, c15.COVERS.size() + 1):
		await wait_until(func(): return c15._col_phase == "walk" and c15._col_t > 4.0 and world.player.controls_enabled, 60 * 20)
		var to: Vector3 = c15.COVERS[i] if i < c15.COVERS.size() else c15.CROSS_END
		crossed = crossed and await sprint_to(to)
	ok("c15_crossed", crossed and await wait_until(func(): return game.has_flag("ch15_crossed"), 120), "%s retries %d" % [str(world.player.global_position), c15.report["retries"]])

	# ---- the district: a Skitter on the roofs, a Hound behind; the passage
	ok("c15_run_district", await run_route([D(Vector3(4.5, 0.2, 6.0)), D(Vector3(4.5, 0.2, 36.0)), D(Vector3(0.0, 0.2, 42.0)), D(Vector3(0.0, 0.2, 48.0)),
		D(Vector3(-9.0, 0.2, 52.0)), D(Vector3(-15.0, 0.2, 60.0)), D(Vector3(-14.0, 0.2, 72.0)), D(Vector3(-2.0, 0.2, 73.6))]), str(world.player.global_position - c13.D_ORIGIN))
	ok("c15_pressure", said.has("Roof! Left side!"))
	await wait_until(func(): return c15.present().all(func(k): return c15._node(k).global_position.distance_to(world.player.global_position) < 9.0), 60 * 8)
	ok("c15_passage", await use(c13.its["passage"], [Vector3(0, 0, -1), Vector3(0.6, 0, -1), Vector3(-0.6, 0, -1)], 1.5)
		and await wait_until(func(): return game.has_flag("ch15_in_passage") and world.player.global_position.y < -40.0 and world.player.controls_enabled, 300)
		and FileAccess.file_exists(game.checkpoint_path("chapter16_passage")) and c15.creatures.is_empty())
	ok("c15_entrance_talk", await wait_talk(func(): return said.has("I hate that we've gotten used to places like this."), 20.0))

	# ---- below: the rubble, the doorway, the ancient passage, the chamber
	ok("c15_walk_below", await walk_world([UL(Vector3(0, 0.2, 12.0)), UL(Vector3(12.0, 0.2, 12.0)), UL(Vector3(12.0, 0.2, 22.0))]), str(world.player.global_position - c13.U))
	ok("c15_gap", await use(c15.its["gap"], [Vector3(0, 0, -1)], 1.0) and await wait_until(func(): return game.has_flag("ch15_gap_cleared") and world.player.controls_enabled, 300))
	ok("c15_walk_doorway", await walk_world([UL(Vector3(12.6, 0.2, 26.0)), UL(Vector3(12.0, 0.2, 34.0)), UL(Vector3(12.0, 0.2, 44.0)), UL(Vector3(12.0, 0.2, 60.0))]),
		str(world.player.global_position - c13.U))
	ok("c15_chamber", await wait_until(func(): return world.player.global_position.distance_to(UL(Vector3(12, 0, 60))) < 1.5, 10) and await walk_world([UL(Vector3(12.0, 0.2, 66.0))])
		and await wait_talk(func(): return game.has_flag("ch15_chamber_reached") and said.has("Not forever."), 40.0)
		and FileAccess.file_exists(game.checkpoint_path("chapter16_chamber")))
	ok("c15_group_below", c15.present().all(func(k): return c15._node(k).global_position.distance_to(world.player.global_position) < 12.0),
		str(c15.present().map(func(k): return c15._node(k).global_position.distance_to(world.player.global_position))))
	c15._examine(null, "records")
	ok("c15_records_evidence", await wait_talk(func(): return said.any(func(t): return "Closing it is possible." in t), 15.0))
	await wait_talk(func(): return not dlg.is_busy(), 10.0)
	# ---- the controls under falling stone
	ok("c15_walk_ctrl_a", await walk_world([UL(Vector3(-1.8, 0.2, 74.0))]))
	ok("c15_ctrl_a", await use(c15.its["ctrl_A"], [Vector3(1, 0, 0)], 1.2) and await wait_talk(func(): return st_has("A") and world.player.controls_enabled, 40.0)
		and said.has("We need to go!") and c15.report.get("horror_fov_restored", false))
	ok("c15_walk_ctrl_b", await sprint_to(UL(Vector3(25.8, 0.2, 74.0))))
	ok("c15_ctrl_b", await use(c15.its["ctrl_B"], [Vector3(-1, 0, 0)], 1.2) and st_has("B"))
	ok("c15_walk_ctrl_c", await sprint_to(UL(Vector3(12.0, 0.2, 78.6))))
	ok("c15_ctrl_c", await use(c15.its["ctrl_C"], [Vector3(0, 0, -1)], 1.1) and await wait_talk(func(): return p4.choice.is_open(), 30.0)
		and FileAccess.file_exists(game.checkpoint_path("chapter16_decision")))
	ok("c15_choice_needs_pick", p4.choice.is_open() and not game.has_flag("ch15_decided") and p4.choice._box.get_child_count() >= 3)
	ok("c15_survived_stones", world.player.health > 0.0, "hits %d, health %.0f" % [c15.report["debris_hits"], world.player.health])

	# ---- ENDING A
	pick_label("LEAVE GREYHAVEN")
	ok("c15_a_tunnel", await wait_until(func(): return c15._busy.get("outer_open", false), 120) and await walk_world([UL(Vector3(28.6, 0.2, 70.0)), UL(Vector3(42.4, 0.2, 70.0))]))
	ok("c15_a_out", await use(c15.its["outer"], [Vector3(-1, 0, 0)], 1.0) and await wait_talk(func(): return said.has("We keep going."), 60.0)
		and world.player.global_position.distance_to(c15.BEYOND) < 3.0)
	ok("c15_a_end", await wait_talk(func(): return credits_up(), 120.0) and world.hud.title.text != "" and String(c15.st()["ending"]) == "A"
		and game.has_flag("chapter_15_complete"))
	var epi: Array = c15.st()["epilogue"]
	ok("c15_a_epilogue", epi.any(func(l): return String(l).begins_with("Sarah made it out")) and epi.has("Noah was never found.")
		and epi.any(func(l): return String(l).begins_with("Marcus made it out")), str(epi))
	var rec = JSON.parse_string(FileAccess.get_file_as_string("user://veil_endings.json"))
	ok("c15_endings_file", rec is Dictionary and "A" in rec["endings"])
	game.load_game()
	ok("c15_save_before_decision", game.has_flag("ch15_mechanism_done") and not game.has_flag("ch15_decided") and "A" in game.world_state["ch15"]["endings_seen"])

	# ---- ENDING B (from the pre-decision checkpoint)
	await boot_checkpoint("chapter16_decision")
	ok("c15_b_choice_again", await wait_talk(func(): return p4.choice.is_open(), 40.0) and c15.present().all(func(k): return c15._node(k).visible))
	pick_label("SEAL THE CHAMBER")
	await frames(30)
	ok("c15_b_seal", await seal_steps() and await wait_until(func(): return c15._busy.get("outer_open", false), 60 * 10), str(c15.st().get("seal_steps", -1)))
	ok("c15_b_tunnel", await walk_world([UL(Vector3(28.6, 0.2, 70.0)), UL(Vector3(42.4, 0.2, 70.0))]) and await use(c15.its["outer"], [Vector3(-1, 0, 0)], 1.0))
	ok("c15_b_end", await wait_talk(func(): return credits_up(), 160.0) and said.has("But it's getting smaller.") and String(c15.st()["ending"]) == "B")

	# ---- ENDING C
	await boot_checkpoint("chapter16_decision")
	await wait_talk(func(): return p4.choice.is_open(), 40.0)
	pick_label("SEND THE SURVIVORS AHEAD")
	ok("c15_c_stay", await wait_talk(func(): return said.has("That's not what I asked.") and c15._busy.get("seal_mode", false) and world.player.controls_enabled, 40.0))
	ok("c15_c_seal", await seal_steps())
	ok("c15_c_end", await wait_talk(func(): return credits_up(), 200.0) and String(c15.st()["ending"]) == "C"
		and c15.st()["epilogue"][0] == "They waited at the tunnel mouth until morning. Nobody came out.")
	rec = JSON.parse_string(FileAccess.get_file_as_string("user://veil_endings.json"))
	ok("c15_all_endings_recorded", rec is Dictionary and rec["endings"].has("A") and rec["endings"].has("B") and rec["endings"].has("C"), str(rec["endings"]))

	# ---- other rosters: the epilogue never invents a fate
	world.free()
	DEV.prepare(game, false, true)                       # Marcus left at the fence
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	await wait_until(func(): return c15 != null and game.has_flag("ch15_opening_done"), 60 * 30)
	var e2: Array = c15.epilogue_lines("A")
	ok("c15_left_marcus", c15.present() == ["Eddie", "Ruth", "Sarah"] and not c15._node("Marcus").visible
		and e2.any(func(l): return "Marcus was last seen at the fence" in String(l)) and not e2.any(func(l): return String(l).begins_with("Marcus made it out")), str(e2))
	world.free()
	DEV.prepare(game, true)                              # Marcus lost in Chapter 10
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	await wait_until(func(): return c15 != null and game.has_flag("ch15_opening_done"), 60 * 30)
	var e3: Array = c15.epilogue_lines("B")
	ok("c15_lost_marcus", not c15._node("Marcus").visible and e3.any(func(l): return "Marcus did not leave the supermarket" in String(l))
		and not e3.has("Noah was never found."), str(e3))

	# ---- back to the main menu from the credits
	c15._credits()
	await frames(5)
	c15._menu_main()
	await frames(30)
	ok("c15_main_menu", root.get_tree().current_scene != null and String(root.get_tree().current_scene.scene_file_path).ends_with("MainMenu.tscn"),
		str(root.get_tree().current_scene.scene_file_path if root.get_tree().current_scene else "-"))
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)


func st_has(k: String) -> bool:
	return c15.st().get("controls", {}).has(k)
