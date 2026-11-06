extends SceneTree
## THE VEIL - Chapter 8 "Something at the Doors" automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter8_test.gd
## Starts from the developer entry (game/tools/dev_chapter8.gd = Chapter 7 complete and slept). Checks the global
## conversation camera on Eddie (zoom in at the protagonist's eye, framing, E / click continue, hold-E skip that
## still applies the story flag, zoom out, control back), then plays the chapter: barricade, materials, repair,
## power, the attack (one scripted death), securing the doorway, both medical outcomes, the aftermath, loads.

const DEV := preload("res://game/tools/dev_chapter8.gd")

var fails := 0
var world: Node
var game: Node
var dlg: Node
var ps: PackedScene
var c5: Node
var c6: Node
var c7: Node
var c8: Node
var p4: Node
var said: Array = []
var speakers: Array = []


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


## Stand `dist` metres from the interactable (first clear direction) and aim at it; true if the real ray finds it.
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
	c5 = p4.chapter5 if p4 else null
	c6 = c5.chapter6 if c5 else null
	c7 = c6.chapter7 if c6 else null
	c8 = c7.chapter8 if c7 else null


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1500.0).timeout.connect(func():
		print("RESULT FAIL (watchdog: test did not finish)")
		quit(1))


## No two visible NPCs closer than a body width, none sunk into or floating above the floor below them.
func npcs_ok() -> String:
	var bodies: Array = []
	for k in ["Eddie", "Marcus", "Ruth", "Sarah", "Survivor"]:
		var a = world.animators.get(k)
		if a and a.root.is_visible_in_tree():
			bodies.append(a.root)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var d: float = Vector2(bodies[i].global_position.x - bodies[j].global_position.x, bodies[i].global_position.z - bodies[j].global_position.z).length()
			if d < 0.55:
				return "%s/%s %.2f m apart" % [bodies[i].name, bodies[j].name, d]
		var p: Vector3 = bodies[i].global_position
		var d2: float = Vector2(p.x - world.player.global_position.x, p.z - world.player.global_position.z).length()
		if d2 < 0.45:
			return "%s merged with the player (%.2f m)" % [bodies[i].name, d2]
	return ""


## The global conversation camera, measured while a talk is on.
func talk_cam_state(npc_name: String) -> Dictionary:
	var vc: Camera3D = root.get_viewport().get_camera_3d()
	var out := {"cam": vc.name if vc else "-", "controls": world.player.controls_enabled}
	if vc == null:
		return out
	out["fov_drop"] = 1.0 - vc.fov / world.player.camera.fov
	out["eye_off"] = vc.global_position.distance_to(world.player.camera.global_position)
	var head = world._speaker_head(npc_name)
	if head != null:
		var to: Vector3 = ((head as Vector3) - vc.global_position).normalized()
		out["aim_deg"] = rad_to_deg((-vc.global_transform.basis.z).angle_to(to))
	return out


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(s, t, _d):
		said.append(t)
		speakers.append(s))
	DEV.prepare(game)
	var nights0: int = game.world_state.get("shelter_nights", {}).size()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	ok("c8_entry_after_c7_rest", c8 != null and game.has_flag("ch8_started") and game.current_step().get("id", "") == "c8_eddie",
		game.current_step().get("id", ""))
	ok("c8_title_card", await wait_until(func(): return world.hud.chapter_l.text.begins_with("CHAPTER 9  —  SOMETHING AT THE DOORS"), 60 * 6), world.hud.chapter_l.text)
	ok("c8_objective_text", game.current_step().get("text", "") == "Talk to Eddie" and game.current_goal() == "Something at the Doors")
	ok("c8_night_once", game.world_state.get("shelter_nights", {}).size() == nights0)
	ok("c8_cast_present", c8.ruth.visible and c8.sarah.visible and c8.temp.visible and c8.eddie.visible and c8.marcus.visible
		and c8.marcus.position.distance_to(c8.MARCUS_BACK) < 0.4, str(c8.marcus.position))
	ok("c8_npcs_apart_start", npcs_ok() == "", npcs_ok())
	ok("c8_no_ch7_markers", world.hud._mk_name == "EDDIE")

	# ---- GLOBAL CONVERSATION CAMERA (Eddie): manual confirm, continue, hold-to-skip
	dlg.auto_confirm = false
	var rep0: Dictionary = world.talk_report.duplicate()
	ok("c8_eddie_reach", await aim(c8.its["npc_Eddie"], [Z, -Z, X, -X], 1.4))
	c8.its["npc_Eddie"].interact(world.player)
	await frames(30)                                    # ~0.5 s: the camera has turned and zoomed
	var cs := talk_cam_state("Eddie")
	ok("dlg_zoom_in", cs["cam"] == "TalkCam" and not cs["controls"] and cs.get("fov_drop", 0.0) >= 0.08 and cs.get("fov_drop", 0.0) <= 0.12, str(cs))
	ok("dlg_eye_position", cs.get("eye_off", 9.0) < 0.03, str(cs))
	ok("dlg_frames_speaker", cs.get("aim_deg", 99.0) < 12.0, str(cs))
	ok("dlg_speaker_name", world.hud.speaker_l.text == "EDDIE", world.hud.speaker_l.text)
	ok("dlg_prompt_visible", world.hud.confirm_l.visible and world.hud.confirm_l.text.contains("CONTINUE"), world.hud.confirm_l.text)
	ok("dlg_waits_for_player", await wait_until(func(): return dlg.is_waiting(), 60 * 6) and said.size() > 0 and dlg.is_active())
	var n0 := said.size()
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var ev2 := InputEventAction.new()
	ev2.action = "interact"
	ev2.pressed = false
	Input.parse_input_event(ev2)
	ok("dlg_e_continues", await wait_until(func(): return said.size() == n0 + 1, 30) and speakers[speakers.size() - 1] == ""
		and world.hud.speaker_l.text == game.player_name.to_upper(), "%d -> %d %s" % [n0, said.size(), world.hud.speaker_l.text])
	ok("dlg_no_side_interaction", world.player.controls_enabled == false and not game.has_flag("ch8_eddie_talked"))
	await frames(30)
	var ev3 := InputEventMouseButton.new()
	ev3.button_index = MOUSE_BUTTON_LEFT
	ev3.pressed = true
	var n1 := said.size()
	Input.parse_input_event(ev3)
	await frames(2)
	var ev4 := InputEventMouseButton.new()
	ev4.button_index = MOUSE_BUTTON_LEFT
	ev4.pressed = false
	Input.parse_input_event(ev4)
	ok("dlg_click_continues", await wait_until(func(): return said.size() == n1 + 1, 30), "%d -> %d" % [n1, said.size()])
	await frames(30)
	# HOLD E: the rest of the conversation is skipped, the story consequence still happens, the view comes back
	Input.action_press("interact")
	var progress_seen := await wait_until(func(): return world.hud.skip_progress > 0.3 and world.hud.confirm_l.text.begins_with("SKIPPING"), 60)
	var skipped0: int = dlg.skipped
	await wait_until(func(): return dlg.skipped > skipped0, 90)
	Input.action_release("interact")
	ok("dlg_hold_skip_feedback", progress_seen)
	ok("dlg_hold_skips", dlg.skipped == skipped0 + 1 and said.size() < 9, "%d lines shown" % said.size())
	ok("dlg_skip_applies_story", await wait_until(func(): return game.has_flag("ch8_eddie_talked"), 60 * 3)
		and game.current_step().get("id", "") == "c8_inspect")
	ok("dlg_zoom_out", await wait_until(func(): return root.get_viewport().get_camera_3d() == world.player.camera, 60 * 2)
		and world.talk_report["zoom_outs"] == rep0["zoom_outs"] + 1 and world.talk_report["released"] == rep0["released"] + 1,
		str(world.talk_report))
	ok("dlg_control_restored", world.player.controls_enabled and not world.conversing and not dlg.confirm_mode and not dlg.is_busy())
	ok("dlg_no_clipping", world.talk_report["cam_hits"] == 0, str(world.talk_report))
	ok("dlg_no_retrigger", await wait_until(func(): return not world.conversing, 30) and c8.its["npc_Eddie"].prompt_text == "")
	dlg.auto_confirm = true
	# interrupted by a scripted event: the lock is still released
	var tc0: int = world.talk_report["count"]
	world.converse(["c8_power_back"], [c8.eddie])
	await frames(20)
	var mid_cam: String = root.get_viewport().get_camera_3d().name
	world.end_conversation()
	await frames(4)
	ok("dlg_interrupt_releases", mid_cam == "TalkCam" and world.talk_report["count"] == tc0 + 1 and world.player.controls_enabled
		and root.get_viewport().get_camera_3d() == world.player.camera and not dlg.is_busy() and not world.conversing, mid_cam)

	# ---- scene 2: the damaged barricade
	await reload()
	ok("c8_load_after_eddie", game.has_flag("ch8_eddie_talked") and c8.its["barricade"].prompt_text == "[E] Inspect the Barricade"
		and root.get_viewport().get_camera_3d() == world.player.camera and world.player.controls_enabled and not dlg.confirm_mode)
	ok("c8_barricade_damaged", c8.report.get("barricade", "") == "damaged" and p4._pallets["back"].position.distance_to(c8.BACK_PALLET_DAMAGED) < 0.05
		and c8._boards_loose[0].visible and not c8._boards_up[0].visible)
	ok("c8_materials_not_glowing_yet", not game.has_flag("ch8_barricade_inspected"))
	world.player.global_position = world.market.global_transform * Vector3(8.2, 0.2, 12.4)
	await frames(4)
	ok("c8_walk_to_back", await walk_route([Vector3(8.4, 0.2, 13.4), Vector3(8.5, 0.2, 14.8), Vector3(8.6, 0.2, 15.7)]), "")
	ok("c8_barricade_reach", await aim(c8.its["barricade"], [-Z, X, -X], 1.3))
	var talks0: int = world.talk_report["count"]
	c8.its["barricade"].interact(world.player)
	ok("c8_inspected", await wait_talk(func(): return game.has_flag("ch8_barricade_inspected"), 60.0)
		and said.has("The backup power's barely holding.") and game.current_step().get("id", "") == "c8_materials")
	ok("c8_marcus_talk_camera", world.talk_report["count"] == talks0 + 1, str(world.talk_report))
	ok("c8_materials_objective", world.hud.objective_l.text.contains("(0/3)") if world.hud.get("objective_l") else true)

	# ---- scene 3: materials (each once), reload in between
	var order := [["boards", [Z, -Z, X, -X]], ["hammer", [-X, -Z, Z]], ["tape", [-Z, Z, X]]]
	for i in order.size():
		var k: String = order[i][0]
		var it: Interactable = c8.its["mat_" + k]
		ok("c8_reach_" + k, await aim(it, order[i][1], 0.9), str(world.market.to_local(it.global_position)))
		it.interact(world.player)
		await frames(10)
		ok("c8_got_" + k, it.taken and game.inventory.count(it.item_id) == 1 and c8._materials_count() == i + 1)
		it.interact(world.player)
		await frames(5)
		ok("c8_once_" + k, game.inventory.count(it.item_id) == 1)
		if i == 0:
			await reload()
			ok("c8_load_materials", c8.its["mat_boards"].taken and not c8.its["mat_boards"].target.visible
				and game.inventory.count("repair_boards") == 1 and c8._materials_count() == 1)
	ok("c8_materials_done", game.has_flag("ch8_materials_collected") and game.current_step().get("id", "") == "c8_repair")

	# ---- repair, then the lights fail
	ok("c8_barricade_reach_2", await aim(c8.its["barricade"], [-Z, X, -X], 1.3))
	ok("c8_repair_prompt", c8.its["barricade"].prompt_text == "[E] Repair the Barricade")
	c8.its["barricade"].interact(world.player)
	ok("c8_repaired", await wait_talk(func(): return game.has_flag("ch8_barricade_repaired"), 60.0) and said.has("I'd rather not find out.")
		and c8._boards_up[0].visible and p4._pallets["back"].position.distance_to(c8.BACK_PALLET_BLOCK) < 0.05)
	ok("c8_repair_consumes", not game.has_item("repair_boards") and not game.has_item("duct_tape") and game.has_item("hammer"))
	ok("c8_power_fails", await wait_talk(func(): return game.has_flag("ch8_power_failed"), 30.0)
		and c8.st()["power"] == "failed" and c8.report["lights_on"] <= 1 and game.current_step().get("id", "") == "c8_power")
	ok("c8_power_lines", await wait_talk(func(): return said.has("There's a maintenance panel near the storage area."), 30.0))
	await wait_talk(func(): return not dlg.is_busy(), 20.0)
	await reload()
	ok("c8_load_power_out", c8.st()["power"] == "failed" and c8.report["lights_on"] <= 1 and c8._boards_up[0].visible
		and c8.its["panel"].prompt_text == "[E] Inspect the Panel" and world.player.controls_enabled)

	# ---- the panel (the Chapter 4 breaker): inspect, reseat
	world.player.global_position = world.market.global_transform * Vector3(14.5, 0.2, 15.8)
	await frames(4)
	ok("c8_panel_reach", await aim(c8.its["panel"], [-Z, X, -X], 1.0))
	c8.its["panel"].interact(world.player)
	ok("c8_panel_inspected", await wait_until(func(): return game.has_flag("ch8_panel_inspected"), 60 * 4)
		and c8.its["panel"].prompt_text == "[E] Reseat the Loose Cable" and not game.has_flag("ch8_power_restored"))
	await frames(10)
	ok("c8_panel_reach_2", await aim(c8.its["panel"], [-Z, X, -X], 1.0))
	c8.its["panel"].interact(world.player)
	ok("c8_power_partial", await wait_until(func(): return game.has_flag("ch8_power_restored"), 60 * 4) and c8.st()["power"] == "partial"
		and c8.report["lights_on"] > 2 and c8.report["lights_on"] < p4._lights.size(), str(c8.report.get("lights_on")))
	ok("c8_power_back_lines", await wait_talk(func(): return said.has("I'm surprised by anything that works anymore."), 30.0))
	await wait_talk(func(): return not dlg.is_busy(), 20.0)
	ok("c8_npcs_apart_before_attack", npcs_ok() == "", npcs_ok())

	# ---- scenes 5-6: on the way back, the impacts and the attack (once)
	ok("c8_walk_to_doorway", await walk_route([Vector3(12.0, 0.2, 15.6), Vector3(8.6, 0.2, 15.4), Vector3(8.4, 0.2, 14.3), Vector3(8.2, 0.2, 13.0)]))
	ok("c8_no_attack_at_doorway", not game.has_flag("ch8_attack_started"))
	ok("c8_walk_down_aisle", await walk_route([Vector3(8.0, 0.2, 10.6)]))
	ok("c8_attack_starts", await wait_until(func(): return game.has_flag("ch8_attack_started"), 60 * 2) and not world.player.controls_enabled)
	ok("c8_attack_no_talk_camera", await wait_until(func(): return said.has("Please tell me that's the wind."), 60 * 20)
		and root.get_viewport().get_camera_3d() == world.player.camera)
	ok("c8_barricade_gives_way", await wait_until(func(): return c8.st()["barricade"] == "broken", 60 * 20))
	ok("c8_one_death", await wait_until(func(): return game.has_flag("ch8_temp_survivor_died"), 60 * 12) and c8.deaths == 1
		and not c8.temp.visible)
	ok("c8_sarah_injured", game.has_flag("ch8_sarah_injured") and c8.sarah.visible and world.animators["Sarah"].seated)
	ok("c8_named_alive", c8.eddie.visible and c8.marcus.visible and c8.ruth.visible and c8.sarah.visible)
	ok("c8_control_back", await wait_until(func(): return world.player.controls_enabled, 60 * 6)
		and game.current_step().get("id", "") == "c8_secure")
	ok("c8_hound_guards", c8.hound != null and is_instance_valid(c8.hound) and c8.hound_spawns == 1
		and world.market.to_local(c8.hound.global_position).z > 14.4, str(world.market.to_local(c8.hound.global_position)))
	ok("c8_doorway_blocked", c8._blocker.collision_layer == 1 and c8.its["secure"].prompt_text != "")
	ok("c8_npcs_apart_after_attack", npcs_ok() == "", npcs_ok())
	var secure_snap := snapshot()
	await reload()
	ok("c8_load_mid_attack", game.has_flag("ch8_temp_survivor_died") and c8.deaths == 0 and c8.attack_runs == 0 and not c8.temp.visible
		and c8.hound != null and c8.hound_spawns == 1 and world.player.controls_enabled and c8.its["secure"].prompt_text != "")

	# ---- secure the doorway (no combat)
	ok("c8_secure_reach", await aim(c8.its["secure"], [X, -Z], 1.5))
	c8.its["secure"].interact(world.player)
	ok("c8_secured", await wait_until(func(): return game.has_flag("ch8_entrance_secured"), 60 * 12)
		and c8._secure_pallet.position.distance_to(c8.SECURE_BLOCK) < 0.05 and game.current_step().get("id", "") == "c8_help")
	ok("c8_hound_withdraws", await wait_until(func(): return c8.hound == null, 60 * 4) and world.find_children("C8_Hound", "", true, false).is_empty())
	ok("c8_not_trapped", await walk_route([Vector3(11.8, 0.2, 12.4), Vector3(12.0, 0.2, 9.0), Vector3(8.0, 0.2, 7.0)]))
	await reload()
	ok("c8_load_secured", game.has_flag("ch8_entrance_secured") and c8.hound == null and c8._secure_pallet.position.distance_to(c8.SECURE_BLOCK) < 0.05
		and c8.st()["barricade"] == "broken" and c8.its["sarah"].prompt_text == "[E] Help Sarah")
	var help_snap := snapshot()

	# ---- scene 7 A: medicine (a carried painkiller pack, used once)
	var pk0: int = game.inventory.count("painkillers")
	var med0: int = int(game.shelter_stock().get("medical", 0))
	ok("c8_has_painkillers", pk0 >= 1)
	ok("c8_sarah_reach", await aim(c8.its["sarah"], [-Z, X, -X, Z], 1.1))
	c8.its["sarah"].interact(world.player)
	ok("c8_treated", await wait_talk(func(): return game.has_flag("ch8_survivor_helped"), 60.0) and game.has_flag("ch8_sarah_treated")
		and not game.has_flag("ch8_sarah_untreated") and said.has("You got to her in time."))
	ok("c8_medicine_once", game.inventory.count("painkillers") == pk0 - 1 and int(game.shelter_stock().get("medical", 0)) == med0 and c8.medical_used == 1)
	ok("c8_gathered", await wait_until(func(): return world.player.controls_enabled and not c8._busy.get("after", false), 60 * 5)
		and c8.sarah.position.distance_to(c8.FRONT_BOX) < 1.0 and npcs_ok() == "", npcs_ok())
	await reload()
	ok("c8_load_treated", game.has_flag("ch8_sarah_treated") and game.inventory.count("painkillers") == pk0 - 1 and c8.its["sarah"].prompt_text == "")

	# ---- scene 8: the aftermath
	var talks1: int = world.talk_report["count"]
	ok("c8_walk_to_group", await walk_route([Vector3(5.0, 0.2, 8.6)]))
	ok("c8_aftermath", await wait_talk(func(): return game.has_flag("chapter_8_complete"), 120.0)
		and said.has("We make sure these doors hold one more night.") and world.talk_report["count"] == talks1 + 1)
	ok("c8_group_speaker_focus", speakers.has("Ruth") and speakers.has("Marcus"))
	ok("c8_complete_card", await wait_until(func(): return world.hud.chapter_l.text.begins_with("CHAPTER 9 COMPLETE"), 60 * 3), world.hud.chapter_l.text)
	ok("c8_flags", game.has_flag("ch8_aftermath_complete") and game.has_flag("shelter_evacuation_concern") and game.has_flag("ch8_temp_survivor_died")
		and game.has_flag("ch8_power_restored") and game.has_flag("ch8_entrance_secured"))
	ok("c8_no_chapter9", not game.has_flag("ch9_started") and game.current_step().get("id", "") == "c8_complete")
	ok("c8_control_after", await wait_until(func(): return world.player.controls_enabled and root.get_viewport().get_camera_3d() == world.player.camera, 60 * 3))
	await reload()
	ok("c8_load_complete", game.has_flag("chapter_8_complete") and not c8.temp.visible and c8.hound == null and c8.deaths == 0
		and c8.st()["barricade"] == "broken" and c8.st()["power"] == "partial" and p4.rest.interactable.prompt_text == "[E] Sleep"
		and game.inventory.count("painkillers") == pk0 - 1 and world.find_children("Sarah", "", true, false).size() == 1)
	# the survival rule: enough food and water for everyone tonight (deposited supplies)
	game.world_state["shelter_stock"] = {"food": 12, "water": 12, "medical": int(game.shelter_stock().get("medical", 0)), "batteries": 0}
	p4.rest.interactable.interact(world.player)
	ok("c8_rest_confirm", await wait_until(func(): return p4.choice.is_open(), 60))
	p4.choice.pick(0)
	ok("c8_rest_starts_next", await wait_until(func(): return game.has_flag("ch8_rested"), 60 * 8) and game.has_flag("ch9_started")
		and c8.chapter9 != null and game.world_state["shelter_nights"].has("ch8_rested") and game.chapter_number() == 10)

	# ---- scene 7 B: no medical supplies (Sarah stays seriously hurt; the chapter still completes)
	await restore(help_snap, func():
		game.inventory.erase("painkillers")
		while "painkillers" in game.inventory:
			game.inventory.erase("painkillers")
		var stock: Dictionary = game.shelter_stock()
		stock["medical"] = 0
		game.world_state["shelter_stock"] = stock)
	ok("c8_b_sarah_reach", await aim(c8.its["sarah"], [-Z, X, -X, Z], 1.1))
	c8.its["sarah"].interact(world.player)
	ok("c8_untreated", await wait_talk(func(): return game.has_flag("ch8_survivor_helped"), 60.0) and game.has_flag("ch8_sarah_untreated")
		and not game.has_flag("ch8_sarah_treated") and not game.has_flag("ch8_medical_used") and said.has("Then we need to find some.")
		and c8.st()["injured_condition"] == "serious" and c8.sarah.visible)
	await wait_until(func(): return world.player.controls_enabled and not c8._busy.get("after", false), 60 * 5)
	ok("c8_b_walk_to_group", await walk_route([Vector3(5.0, 0.2, 8.6)]))
	ok("c8_b_complete", await wait_talk(func(): return game.has_flag("chapter_8_complete"), 120.0) and c8.sarah.visible)
	await reload()
	ok("c8_b_load", game.has_flag("ch8_sarah_untreated") and c8.st()["injured_condition"] == "serious" and c8.sarah.visible)

	# ---- a load inside the attack before the death: it plays again from its start, still one death
	await restore(secure_snap, func():
		game.flags.erase("ch8_temp_survivor_died")
		game.flags.erase("ch8_sarah_injured")
		game.world_state["ch8"]["barricade"] = "repaired")
	ok("c8_attack_replays_once", await wait_until(func(): return game.has_flag("ch8_temp_survivor_died"), 60 * 40) and c8.deaths == 1 and c8.attack_runs == 1)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
