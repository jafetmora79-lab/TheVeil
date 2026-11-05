extends SceneTree
## THE VEIL - displayed CHAPTER 11 "No Safe Road" (chapter10.gd) automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter10_test.gd
## From the developer entry (game/tools/dev_chapter10.gd: the group at the rendezvous after the evacuation). The
## player walks the whole way (physics): the talk with Eddie (talk camera, E continue, hold-E skip), the abandoned
## sedan, the roadblock (it cannot be walked through, at three points across the road), the side route and the
## gate, the follower, Sarah's choice (skip stops at the choice; both answers), the mill-worker house, the rest,
## the window, the completion, the separate checkpoints, loads, and the roster without Marcus.

const DEV := preload("res://game/tools/dev_chapter10.gd")

var fails := 0
var world: Node
var game: Node
var dlg: Node
var ps: PackedScene
var c8: Node
var c9: Node
var c10: Node
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


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	DEV.prepare(game)
	if FileAccess.file_exists(game.checkpoint_path("chapter11_start")):
		DirAccess.remove_absolute(game.checkpoint_path("chapter11_start"))
	if FileAccess.file_exists(game.checkpoint_path("chapter11_end")):
		DirAccess.remove_absolute(game.checkpoint_path("chapter11_end"))
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	var _inv0: Array = game.inventory.duplicate()
	ok("c10_entry", c10 != null and game.has_flag("ch10_started") and game.chapter_number() == 11 and game.current_step().get("id", "") == "c10_eddie",
		game.current_step().get("id", ""))
	ok("c10_title_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 11  —  NO SAFE ROAD", 60 * 5), world.hud.chapter_l.text)
	ok("c10_start_checkpoint", FileAccess.file_exists(game.checkpoint_path("chapter11_start"))
		and "ch10_started" in FileAccess.get_file_as_string(game.checkpoint_path("chapter11_start")),
		"exists %s" % FileAccess.file_exists(game.checkpoint_path("chapter11_start")))
	ok("c10_roster_with_marcus", c10.group() == ["Eddie", "Ruth", "Sarah", "Marcus"] and c10.marcus.visible and c10.eddie.visible)
	ok("c10_supplies_carried", game.inventory.count("painkillers") == 2 and game.inventory.count("canned_food") == 2
		and game.inventory.count("water_bottle") == 1)
	ok("c10_npcs_apart_start", npcs_ok() == "", npcs_ok())

	# ---- scene 1: the shared talk camera; E continues, HOLD E skips (the story still advances)
	dlg.auto_confirm = false
	ok("c10_eddie_reach", await aim_w(c10.its["npc_Eddie"], [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)], 1.4))
	c10.its["npc_Eddie"].interact(world.player)
	await frames(30)
	var vc: Camera3D = root.get_viewport().get_camera_3d()
	ok("c10_zoom_in", vc != null and vc.name == "TalkCam" and not world.player.controls_enabled
		and absf(1.0 - vc.fov / world.player.camera.fov - 0.1) < 0.025 and vc.global_position.distance_to(world.player.camera.global_position) < 0.03,
		vc.name if vc else "-")
	ok("c10_speaker_eddie", world.hud.speaker_l.text == "EDDIE" and world.hud.confirm_l.visible, world.hud.speaker_l.text)
	await wait_until(func(): return dlg.is_waiting(), 60 * 5)
	var n0 := said.size()
	await press_e()
	ok("c10_e_continues", await wait_until(func(): return said.size() == n0 + 1, 30))
	await frames(30)
	Input.action_press("interact")
	await wait_until(func(): return dlg.skipped > 0, 90)
	Input.action_release("interact")
	ok("c10_skip_applies_story", await wait_until(func(): return game.has_flag("ch10_plan_done"), 60 * 3) and not said.has("Then we should go before something finds us."))
	ok("c10_zoom_out", await wait_until(func(): return root.get_viewport().get_camera_3d() == world.player.camera and world.player.controls_enabled, 60 * 2))
	dlg.auto_confirm = true
	ok("c10_group_follows", c10.c9.follows["Eddie"].active and c10.c9.follows["Marcus"].active and c10.c9.follows["Sarah"].active)
	await reload()
	ok("c10_load_following", game.has_flag("ch10_plan_done") and c10.c9.follows["Ruth"].active and world.find_children("Eddie", "", true, false).size() == 1)

	# ---- the walk out, the abandoned sedan
	ok("c10_walk_to_car", await walk_world(c10.ROUTE), str(world.player.global_position))
	ok("c10_car_found", await wait_until(func(): return game.has_flag("ch10_car_found"), 60 * 3) and game.current_step().get("id", "") == "c10_car")
	ok("c10_npcs_apart_road", npcs_ok() == "", npcs_ok())
	var spares0: int = p4.flashlight.spares
	for k in 3:
		ok("c10_driver_reach_%d" % k, await aim_w(c10.its["driver"], [Vector3(0, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, -1)], 1.0))
		c10.its["driver"].interact(world.player)
		await frames(20)
	ok("c10_driver_side", game.has_flag("ch10_car_door") and game.has_flag("ch10_car_fuel") and game.has_flag("ch10_car_glove")
		and p4.flashlight.spares == spares0 + 1)
	ok("c10_trunk_reach", await aim_w(c10.its["trunk"], [Vector3(-1, 0, 0), Vector3(-1, 0, -1)], 1.0))
	c10.its["trunk"].interact(world.player)
	await frames(10)
	c10.its["trunk"].interact(world.player)
	c10.its["driver"].interact(world.player)
	await frames(10)
	ok("c10_car_items_once", game.inventory.count("water_bottle") == 2 and p4.flashlight.spares == spares0 + 1 and c10.report["car_items"] == 2)
	ok("c10_car_talk", await wait_talk(func(): return game.has_flag("ch10_car_done"), 40.0) and said.has("A few supplies. That's it."))
	await reload()
	ok("c10_load_car", game.has_flag("ch10_car_done") and game.inventory.count("water_bottle") == 2 and c10.its["trunk"].prompt_text == ""
		and c10.car.find_child("Trunk", true, false).has_meta("c10_open"))

	# ---- the roadblock: it cannot be walked through anywhere across the road
	ok("c10_walk_to_block", await walk_world([Vector3(-38.0, 0.2, 0.0)]))
	ok("c10_roadblock_seen", await wait_until(func(): return game.has_flag("ch10_roadblock_seen"), 60 * 2))
	var through := false
	for z in [-5.6, 0.2, 5.2]:
		await walk_to(Vector3(-41.0, 0.2, z), 8.0)
		await walk_to(Vector3(-54.0, 0.2, z), 8.0)
		if world.player.global_position.x < c10.BLOCK_X - 1.5:
			through = true
	ok("c10_roadblock_solid", not through, str(world.player.global_position))
	ok("c10_side_route", await walk_world([Vector3(-36.0, 0.2, 0.0)] + c10.SIDE_ROUTE), str(world.player.global_position))
	var gate: Interactable = c10.its["gate"]
	ok("c10_gate_closed_blocks", not gate.is_open and not await walk_to(Vector3(-48.0, 0.2, -13.2), 4.0))
	ok("c10_gate_reach", await aim_w(gate, [Vector3(1, 0, 0), Vector3(1, 0, 0.5)], 1.0))
	gate.interact(world.player)
	await frames(40)
	ok("c10_gate_open", gate.is_open)
	ok("c10_through_gate", await walk_world([Vector3(-40.0, 0.2, -13.2), Vector3(-48.0, 0.2, -13.2)]), str(world.player.global_position))
	ok("c10_around", await wait_until(func(): return game.has_flag("ch10_around_done"), 60 * 2))
	ok("c10_followed_scene", await wait_until(func(): return said.has("Nobody stop."), 60 * 20) and game.has_flag("ch10_creature_seen"))
	ok("c10_creature_gone", await wait_until(func(): return c10.hound == null, 60 * 20) and world.player.controls_enabled)
	ok("c10_back_to_road", await walk_world(c10.BACK_TO_ROAD) and await wait_until(func(): return game.has_flag("ch10_followed_done"), 60 * 2),
		str(world.player.global_position))
	ok("c10_group_through", await wait_until(func(): return c10.group().all(func(k): return c10._node(k).global_position.x < c10.FENCE_X), 60 * 25),
		str(c10.group().map(func(k): return c10._node(k).global_position.snapped(Vector3.ONE * 0.1))))
	await reload()
	ok("c10_load_after_follower", game.has_flag("ch10_followed_done") and c10.report["creature_runs"] == 0 and c10.hound == null)

	# ---- scene 5: Sarah - the choice is never skipped or picked automatically
	await walk_world([Vector3(-58.0, 0.2, 0.0), Vector3(-62.0, 0.2, 0.0)])
	ok("c10_sarah_stops", await wait_until(func(): return dlg.is_busy() or world.conversing, 60 * 6))
	dlg.auto_confirm = false
	await wait_until(func(): return dlg.is_active(), 60 * 6)
	Input.action_press("interact")
	await wait_until(func(): return dlg.skipped > 0, 90)
	Input.action_release("interact")
	ok("c10_choice_waits_after_skip", await wait_until(func(): return p4.choice.is_open(), 60 * 4) and not game.has_flag("ch10_choice_made")
		and not game.has_flag("ch10_choice_help") and not game.has_flag("ch10_choice_push"))
	dlg.auto_confirm = true
	var choice_snap := snapshot()
	var water0: int = game.inventory.count("water_bottle")
	p4.choice.pick(0)
	ok("c10_help", await wait_talk(func(): return game.has_flag("ch10_choice_made"), 40.0) and game.has_flag("ch10_choice_help")
		and not game.has_flag("ch10_choice_push") and game.inventory.count("water_bottle") == water0 - 1 and c10.st()["sarah"] == "rested"
		and c10.sarah.visible)
	ok("c10_control_after_choice", await wait_until(func(): return world.player.controls_enabled and root.get_viewport().get_camera_3d() == world.player.camera, 60 * 4))

	# ---- scenes 6-7: the outskirts, the mill-worker house
	ok("c10_walk_outskirts", await walk_world([Vector3(-72.0, 0.2, 0.0), Vector3(-80.0, 0.2, 0.0)]))
	ok("c10_building_seen", await wait_until(func(): return game.has_flag("ch10_building_seen"), 60 * 3)
		and await wait_talk(func(): return said.has("Let's check it."), 30.0))
	ok("c10_walk_to_porch", await walk_world([Vector3(-88.0, 0.2, 6.0), c10.hl(Vector3(0.6, 0.1, 0.2)), c10.hl(Vector3(0.6, 0.7, 2.4))]),
		str(world.player.global_position))
	var door: Interactable = c10.its["door"]
	ok("c10_door_reach", await aim_w(door, [c10.house.global_transform.basis.z * -1.0], 1.0))
	door.interact(world.player)
	await frames(40)
	ok("c10_walk_inside", door.is_open and await walk_world([c10.hl(Vector3(0.6, 0.7, 4.2)), c10.hl(Vector3(0.0, 0.7, 6.0))]), str(world.player.global_position))
	ok("c10_room_checked", await wait_until(func(): return game.has_flag("ch10_refuge_checked"), 60 * 4))
	ok("c10_refuge_talk", await wait_talk(func(): return game.has_flag("ch10_refuge_talk_done"), 90.0) and said.has("Tomorrow, we keep looking for Noah."))
	ok("c10_group_inside", c10.group().all(func(k): return c10.inside_room(c10._node(k))) and npcs_ok() == "",
		npcs_ok() + str(c10.group().map(func(k): return "%s %s %s" % [k, c10.inside_room(c10._node(k)), c10.house.to_local(c10._node(k).global_position).snapped(Vector3.ONE * 0.1)])))
	ok("c10_rest_reach", await aim_w(c10.its["rest"], [Vector3(-1, 0, 0).rotated(Vector3.UP, c10.house.rotation.y), Vector3(0, 0, -1)], 1.0))
	c10.its["rest"].interact(world.player)
	ok("c10_complete", await wait_until(func(): return game.has_flag("chapter_10_complete"), 60 * 20) and c10.report["rest_runs"] == 1)
	ok("c10_complete_card", await wait_until(func(): return world.hud.chapter_l.text == "CHAPTER 11 COMPLETE  —  NO SAFE ROAD", 60 * 4), world.hud.chapter_l.text)
	var slot := FileAccess.get_file_as_string(game.SAVE_PATH)
	world.save_checkpoint("probe")
	ok("c10_end_checkpoint_separate", FileAccess.file_exists(game.checkpoint_path("chapter11_end"))
		and "chapter_10_complete" in FileAccess.get_file_as_string(game.checkpoint_path("chapter11_end"))
		and FileAccess.get_file_as_string(game.SAVE_PATH) == slot and FileAccess.file_exists(game.checkpoint_path("probe")))
	# the farm road (displayed Chapter 12) starts in the refuge right after the completion card
	ok("c10_next_chapter_starts", await wait_until(func(): return game.has_flag("ch11_started"), 60 * 8) and c10.chapter11 != null
		and game.chapter_number() == 12 and not game.has_flag("ch12_started"))
	ok("c10_control_at_end", world.player.controls_enabled and root.get_viewport().get_camera_3d() == world.player.camera)
	await reload()
	ok("c10_load_complete", game.has_flag("chapter_10_complete") and c10.group().all(func(k): return c10.inside_room(c10._node(k)))
		and c10.its["rest"].prompt_text == "" and game.inventory.count("painkillers") == 2,
		str(c10.group().map(func(k): return "%s %s" % [k, c10.inside_room(c10._node(k))])) + " pk %d" % game.inventory.count("painkillers"))
	# the end checkpoint loads like a save
	ok("c10_checkpoint_loads", game.load_checkpoint("chapter11_end") and game.has_flag("chapter_10_complete"))

	# ---- the other answer: keep moving (nothing used, Sarah stays exhausted, nobody dies)
	await restore(choice_snap)
	ok("c10_choice_reoffered", await wait_talk(func(): return p4.choice.is_open(), 40.0))
	p4.choice.pick(1)
	ok("c10_push", await wait_talk(func(): return game.has_flag("ch10_choice_made"), 40.0) and game.has_flag("ch10_choice_push")
		and game.has_flag("ch10_sarah_exhausted") and game.inventory.count("water_bottle") == water0 and c10.sarah.visible)

	# ---- without Marcus (he was lost in the evacuation): never spawned, the plan's line changes
	DEV.prepare(game, true)
	world.free()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("c10_roster_without_marcus", c10.group() == ["Eddie", "Ruth", "Sarah"] and not c10.marcus.visible)
	ok("c10_lost_eddie_reach", await aim_w(c10.its["npc_Eddie"], [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)], 1.4))
	c10.its["npc_Eddie"].interact(world.player)
	ok("c10_lost_plan", await wait_talk(func(): return game.has_flag("ch10_plan_done"), 60.0) and said.has("Noah's note pointed that way. We follow it - for Marcus.")
		and not c10.c9.follows["Marcus"].active and not c10.marcus.visible)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
