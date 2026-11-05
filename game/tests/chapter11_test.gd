extends SceneTree
## THE VEIL - displayed CHAPTER 12 "The Farm Road" (chapter11.gd) automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter11_test.gd
## From the developer entry (game/tools/dev_chapter11.gd: the group in the mill-worker house after No Safe Road).
## The player walks the farm road (physics), reads the campsite note and Noah's message in the inventory, sees the
## shape in the field (controlled view, FOV back afterwards), searches the farmhouse, survives the encounter (the
## Hound AI, never a killing bite), sees the distant light; loads at the way points; the roster without Marcus.

const DEV := preload("res://game/tools/dev_chapter11.gd")

var fails := 0
var world: Node
var game: Node
var dlg: Node
var ps: PackedScene
var c8: Node
var c9: Node
var c10: Node
var c11: Node
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


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1500.0).timeout.connect(func():
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


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	DEV.prepare(game)
	if FileAccess.file_exists(game.checkpoint_path("chapter12_start")):
		DirAccess.remove_absolute(game.checkpoint_path("chapter12_start"))
	if FileAccess.file_exists(game.checkpoint_path("chapter12_after_encounter")):
		DirAccess.remove_absolute(game.checkpoint_path("chapter12_after_encounter"))
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c11_entry", c11 != null and game.has_flag("ch11_started") and game.chapter_number() == 12 and game.current_step().get("id", "") == "c11_talk",
		game.current_step().get("id", ""))
	ok("c11_title_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 12  —  THE FARM ROAD", 60 * 5), world.hud.chapter_l.text)
	ok("c11_start_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter12_start")))
	ok("c11_roster", c11.group() == ["Eddie", "Ruth", "Sarah", "Marcus"] and c11._node("Marcus").visible and npcs_ok() == "", npcs_ok())

	# ---- scene 1: the shared talk camera; E continues, HOLD E skips; the zoom comes back off
	dlg.auto_confirm = false
	ok("c11_eddie_reach", await aim_w(c11.its["npc_Eddie"], [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)], 1.3))
	c11.its["npc_Eddie"].interact(world.player)
	await frames(30)
	var vc: Camera3D = root.get_viewport().get_camera_3d()
	ok("c11_zoom_in", vc != null and vc.name == "TalkCam" and not world.player.controls_enabled
		and absf(1.0 - vc.fov / world.player.camera.fov - 0.1) < 0.025, vc.name if vc else "-")
	ok("c11_speaker", world.hud.speaker_l.text == "EDDIE" and world.hud.confirm_l.visible, world.hud.speaker_l.text)
	await wait_until(func(): return dlg.is_waiting(), 60 * 5)
	var n0 := said.size()
	await press_e()
	ok("c11_e_continues", await wait_until(func(): return said.size() == n0 + 1, 30))
	await frames(30)
	Input.action_press("interact")
	await wait_until(func(): return dlg.skipped > 0, 90)
	Input.action_release("interact")
	ok("c11_skip_applies", await wait_until(func(): return game.has_flag("ch11_talk_done"), 60 * 3))
	ok("c11_zoom_out", await wait_until(func(): return root.get_viewport().get_camera_3d() == world.player.camera and world.player.controls_enabled, 60 * 2))
	dlg.auto_confirm = true
	ok("c11_group_follows", c11.group().all(func(k): return c11.c9.follows[k].active))

	# ---- scenes 2-3: the farm road, the camp, the note
	ok("c11_walk_out", await walk_world([c11.c10.hl(Vector3(0.6, 0.7, 4.4)), c11.c10.hl(Vector3(0.6, 0.7, 2.4)), c11.c10.hl(Vector3(0.6, 0.1, 0.0))]),
		str(world.player.global_position))
	ok("c11_walk_road", await walk_world(c11.ROAD), str(world.player.global_position))
	ok("c11_npcs_apart_road", npcs_ok() == "", npcs_ok())
	ok("c11_camp", await wait_until(func(): return game.has_flag("ch11_campsite_reached"), 60 * 3) and game.current_step().get("id", "") == "c11_clue")
	await reload()
	ok("c11_load_road", game.has_flag("ch11_campsite_reached") and c11.c9.follows["Eddie"].active and world.find_children("Eddie", "", true, false).size() == 1)
	for k in ["jacket", "tracks"]:
		ok("c11_inspect_" + k, await aim_w(c11.its["camp_" + k], [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)], 1.0))
		c11.its["camp_" + k].interact(world.player)
		await frames(5)
	ok("c11_camp_inspected", c11.st()["inspected"].get("jacket", false) and c11.its["camp_jacket"].prompt_text == "")
	ok("c11_note_reach", await aim_w(c11.its["camp_note"], [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)], 0.8))
	c11.its["camp_note"].interact(world.player)
	await frames(10)
	c11.its["camp_note"].interact(world.player)
	await frames(5)
	ok("c11_note_taken_once", game.inventory.count("campsite_note") == 1 and game.has_flag("noah_clue_campsite"))
	ok("c11_note_readable", game.item_info("campsite_note")["description"].contains("He went toward the old farmhouse."))
	ok("c11_note_read", await read_item("campsite_note") and await wait_until(func(): return game.has_flag("ch11_note_read"), 60))
	ok("c11_campsite_talk", await wait_talk(func(): return said.has("I'm not stopping now."), 40.0) and game.current_step().get("id", "") == "c11_farmhouse")
	await wait_until(func(): return not world.conversing and world.player.controls_enabled, 120)

	# ---- scene 4: the shape in the field (the view is controlled, then handed back with the normal FOV)
	var fov0: float = world.player.camera.fov
	ok("c11_walk_field", await walk_world([Vector3(-109.0, 0.2, -51.5), Vector3(-106.0, 0.2, -62.0), c11.FIELD_AT]) or game.has_flag("ch11_field_seen"))
	ok("c11_field_starts", await wait_until(func(): return game.has_flag("ch11_field_seen"), 60 * 3))
	ok("c11_field_zoom", await wait_until(func(): return float(c11.report.get("field_min_fov", 99.0)) < fov0 * 0.85, 60 * 6),
		"min fov %s" % str(c11.report.get("field_min_fov")))
	ok("c11_field_done", await wait_until(func(): return world.player.controls_enabled and not c11._busy.get("field", false), 60 * 10)
		and absf(world.player.camera.fov - fov0) < 0.01 and world.find_children("C11_FieldShape", "", true, false).is_empty())
	ok("c11_field_lines", await wait_talk(func(): return said.has("Keep going. We're almost there."), 30.0))
	await reload()
	ok("c11_load_field_once", game.has_flag("ch11_field_seen") and c11.report["field_runs"] == 0)

	# ---- scenes 5-6: the farmhouse, the search, Noah's message
	ok("c11_walk_farm", await walk_world([c11.FARM_WAY[0], c11.FARM_WAY[1], c11.fl(c11.PORCH)]), str(world.player.global_position))
	ok("c11_farm_reached", await wait_until(func(): return game.has_flag("ch11_farmhouse_reached"), 60 * 2) and game.current_step().get("id", "") == "c11_search")
	var front: Interactable = c11.its["INT_Door_Front"]
	ok("c11_front_reach", await aim_w(front, [c11.farm.global_transform.basis.z * -1.0], 1.2))
	front.interact(world.player)
	await frames(40)
	ok("c11_walk_in", front.is_open and await walk_world([c11.fl(Vector3(-1.8, 0.7, 2.6)), c11.fl(Vector3(-1.4, 0.7, 4.6)), c11.fl(Vector3(-1.0, 0.7, 6.2))]),
		str(c11.farm.to_local(world.player.global_position)))
	ok("c11_group_waits", await wait_until(func(): return game.has_flag("ch11_group_waiting"), 60 * 2)
		and await wait_until(func(): return c11.group().all(func(k): return c11.in_area(c11._node(k), "living")), 60 * 14) and npcs_ok() == "",
		npcs_ok() + str(c11.group().map(func(k): return c11.farm.to_local(c11._node(k).global_position).snapped(Vector3.ONE * 0.1))))
	ok("c11_search_living", c11.searched().get("living", false))
	ok("c11_walk_kitchen", await walk_world([c11.fl(Vector3(-1.0, 0.7, 4.6)), c11.fl(Vector3(1.0, 0.7, 5.8)), c11.fl(Vector3(1.75, 0.7, 7.6)),
		c11.fl(Vector3(1.75, 0.7, 9.4)), c11.fl(Vector3(0.6, 0.7, 10.0))])
		and c11.searched().get("kitchen", false), str(c11.farm.to_local(world.player.global_position)))
	ok("c11_rear_reach", await aim_w(c11.its["rear"], [c11.farm.global_transform.basis.z * -1.0], 0.9))
	c11.its["rear"].interact(world.player)
	await frames(5)
	ok("c11_rear_checked", c11.searched().get("rear", false))
	await walk_world([c11.fl(Vector3(1.75, 0.7, 9.4)), c11.fl(Vector3(1.75, 0.7, 7.6)), c11.fl(Vector3(1.0, 0.7, 5.8)), c11.fl(Vector3(-1.0, 0.7, 4.6)),
		c11.fl(Vector3(-2.0, 0.7, 4.1)), c11.fl(Vector3(-3.0, 0.7, 3.95))])
	await align(Vector3(-3.0, 0.65, 3.95))                     # onto the narrow stair's centre line
	for z in [5.6, 7.2, 8.9]:
		await walk_world([c11.fl(Vector3(-3.0, 0.0, z))])
		await align(Vector3(-3.0, c11.farm.to_local(world.player.global_position).y + 0.05, z))
	ok("c11_walk_upstairs", await walk_world([c11.fl(Vector3(-1.9, 3.7, 8.7)), c11.fl(Vector3(-1.9, 3.7, 4.9))])
		and c11.farm.to_local(world.player.global_position).y > 3.0,
		str(c11.farm.to_local(world.player.global_position)))
	var bed1: Interactable = c11.its["INT_Door_Bed1"]
	if not bed1.is_open:
		ok("c11_bed_door_reach", await aim_w(bed1, [Vector3(-1, 0, 0), Vector3(-1, 0, 0.5)], 1.0))
		bed1.interact(world.player)
		await frames(40)
	ok("c11_bedroom", await walk_world([c11.fl(Vector3(-1.75, 3.7, 4.4)), c11.fl(Vector3(-0.6, 3.7, 4.4)), c11.fl(Vector3(1.0, 3.7, 5.4))]) and c11.searched().get("bedroom", false),
		str(c11.farm.to_local(world.player.global_position)))
	ok("c11_message_reach", await aim_w(c11.its["message"], [Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0)], 0.9),
		str(c11.farm.to_local(c11.its["message"].global_position)))
	c11.its["message"].interact(world.player)
	await frames(10)
	ok("c11_message_taken", game.inventory.count("noahs_message") == 1 and game.has_flag("noah_clue_farmhouse") and game.has_flag("ch11_search_done"))
	ok("c11_message_read", await read_item("noahs_message") and await wait_until(func(): return game.has_flag("ch11_message_read"), 60)
		and game.item_info("noahs_message")["description"].contains("Please don't come after dark."))
	await reload()
	ok("c11_load_clues_saved", game.has_flag("ch11_message_read") and game.has_flag("noah_clue_campsite") and game.has_flag("noah_clue_farmhouse")
		and game.inventory.count("noahs_message") == 1 and not c11.its["message"].target.visible
		and c11.group().all(func(k): return c11.in_area(c11._node(k), "living")))

	# ---- back to the group, the encounter, the escape
	await walk_world([c11.fl(Vector3(-0.5, 3.7, 4.75))])
	await align(Vector3(-0.5, 3.65, 4.75))
	await walk_world([c11.fl(Vector3(-1.9, 3.7, 4.75)), c11.fl(Vector3(-1.9, 3.7, 8.7)), c11.fl(Vector3(-2.97, 3.7, 9.1))])
	for z in [9.1, 7.2, 5.6, 4.0]:
		await walk_world([c11.fl(Vector3(-3.0, 0.0, z))])
		await align(Vector3(-3.0, c11.farm.to_local(world.player.global_position).y + 0.05, z))
	ok("c11_walk_down", await walk_world([c11.fl(Vector3(-1.0, 0.7, 4.6))]) and c11.in_area(world.player, "living"),
		str(c11.farm.to_local(world.player.global_position)))
	ok("c11_regroup", await wait_talk(func(): return game.has_flag("ch11_regrouped"), 60.0) and said.has("We're close."))
	ok("c11_attack", await wait_until(func(): return game.has_flag("ch11_attack_started"), 60 * 4))
	ok("c11_attack_lines", await wait_until(func(): return said.has("Get to the front door. Now!"), 60 * 25))
	ok("c11_escape_control", await wait_until(func(): return world.player.controls_enabled and c11.hound != null, 60 * 10)
		and game.current_step().get("id", "") == "c11_escape")
	var hp0: float = world.player.health
	Input.action_press("sprint")
	ok("c11_run_out", await walk_world([c11.fl(Vector3(-1.0, 0.7, 4.6)), c11.fl(Vector3(-1.4, 0.7, 4.2)), c11.fl(Vector3(-1.8, 0.7, 2.6)), c11.fl(c11.PORCH),
		Vector3(-92.0, 0.2, -94.0), c11.SAFE]),
		str(world.player.global_position))
	Input.action_release("sprint")
	ok("c11_escaped", await wait_until(func(): return game.has_flag("ch11_escaped"), 60 * 3) and world.player.health > 0.0,
		"hp %.0f -> %.0f bites %d" % [hp0, world.player.health, c11.report["bites"]])
	ok("c11_hound_chased", c11.report.get("chased", false), "closest %.1f m" % float(c11.report.get("closest", 99.0)))
	ok("c11_encounter_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter12_after_encounter")))
	ok("c11_ending", await wait_talk(func(): return game.has_flag("chapter_11_complete"), 120.0) and said.has("At first light.")
		and c11.report["ending_fov_restored"] and world.player.controls_enabled)
	ok("c11_complete_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 12 COMPLETE  —  THE FARM ROAD", 60 * 4), world.hud.chapter_l.text)
	ok("c11_card_before_next", game.chapter_number() == 12 and game.current_step().get("id", "") == "c11_complete")
	# after the card, displayed Chapter 13 begins back at the mill house (chapter12.gd)
	ok("c11_next_chapter", await wait_until(func(): return game.has_flag("ch12_started") and c11.chapter12 != null, 60 * 10)
		and game.chapter_number() == 13)
	await wait_until(func(): return not c11.chapter12._busy.get("opening", false), 60 * 8)
	ok("c11_npcs_apart_end", npcs_ok() == "", npcs_ok())
	await reload()
	ok("c11_load_complete", game.has_flag("chapter_11_complete") and c11.hound == null and c11.report["ending_runs"] == 0 and c11.report["attack_runs"] == 0
		and c11.chapter12 != null and c11.group().all(func(k): return c11.c10.inside_room(c11._node(k)))
		and game.inventory.count("noahs_message") == 1 and game.inventory.count("campsite_note") == 1)

	# ---- without Marcus: never spawned; the essential lines come from the others
	DEV.prepare(game, true)
	world.free()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c11_roster_without_marcus", c11.group() == ["Eddie", "Ruth", "Sarah"] and not c11._node("Marcus").visible)
	ok("c11_lost_eddie_reach", await aim_w(c11.its["npc_Eddie"], [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)], 1.3))
	c11.its["npc_Eddie"].interact(world.player)
	ok("c11_lost_talk", await wait_talk(func(): return game.has_flag("ch11_talk_done"), 60.0)
		and said.has("Noah's trail goes this way. We follow it - like Marcus would have.") and not c11._node("Marcus").visible)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
