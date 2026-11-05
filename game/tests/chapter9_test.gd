extends SceneTree
## THE VEIL - displayed CHAPTER 10 "The Fall of the Supermarket" (chapter9.gd) automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter9_test.gd
## Also checks the central chapter numbering (game/data/chapters.json): sequential, unique, the right chapter for
## every transition flag, completion labels, save and main-menu labels, an old save without the new fields.
## Then plays the chapter from the developer entry (game/tools/dev_chapter9.gd): Marcus's talk (talk camera), the
## preparation (real units from the communal stock, a depleted stock, the flashlight check), the warning, the fall,
## the escape on foot through the staff door and the rear exit, Marcus's moment both ways, the rendezvous, loads.

const DEV := preload("res://game/tools/dev_chapter9.gd")

var fails := 0
var world: Node
var game: Node
var dlg: Node
var ps: PackedScene
var c8: Node
var c9: Node
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


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1500.0).timeout.connect(func():
		print("RESULT FAIL (watchdog: test did not finish)")
		quit(1))


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


## Chapter numbering: the central mapping and every display that uses it.
func numbering() -> void:
	var nums: Array = []
	for c in game.chapters:
		nums.append(int(c["n"]))
	var seq := true
	for i in nums.size():
		seq = seq and nums[i] == i + 1
	ok("num_sequential_unique", seq and nums.size() == 10, str(nums))
	ok("num_titles", game.chapter_title(1) == "An Ordinary Evening" and game.chapter_title(2) == "One Last Stop"
		and game.chapter_title(10) == "The Fall of the Supermarket")
	var cases := [[{}, 1], [{"arrival_shot": true}, 2], [{"arrival_shot": true, "p3_mist": true}, 3],
		[{"p3_mist": true, "p3_fled_together": true}, 4], [{"p3_in_market": true}, 4], [{"p3_doors_shut": true}, 5],
		[{"p3_doors_shut": true, "p4_slept": true}, 6], [{"c5_started": true, "ch6_started": true}, 7], [{"ch7_started": true}, 8],
		[{"ch8_started": true}, 9], [{"ch8_started": true, "ch9_started": true}, 10]]
	var bad := []
	for c in cases:
		if game.chapter_number(c[0]) != c[1]:
			bad.append("%s -> %d (want %d)" % [str(c[0].keys()), game.chapter_number(c[0]), c[1]])
	ok("num_transitions", bad.is_empty(), str(bad))
	ok("num_labels", game.chapter_label(2) == "CHAPTER 2  —  ONE LAST STOP" and game.chapter_label(10, true) == "CHAPTER 10 COMPLETE  —  THE FALL OF THE SUPERMARKET"
		and game.chapter_name(9) == "Chapter 9: Something at the Doors")
	var steps := []
	for o in game.objectives:
		if String(o["text"]).begins_with("Chapter "):
			steps.append(o["text"])
	ok("num_objective_completion_texts", steps == ["Chapter 6 complete - The First Search", "Chapter 7 complete - Voices in the Mist",
		"Chapter 8 complete - A Trace of Noah", "Chapter 9 complete - Something at the Doors",
		"Chapter 10 complete - The Fall of the Supermarket"], str(steps))
	# an existing save written before the numbering fix (no "chapter" fields): its label comes from its flags
	var f := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": game.SAVE_VERSION, "flags": {"ch7_started": true, "c5_started": true}, "inventory": [],
		"world_state": {}, "player": {}, "vehicle": {}, "play_time": 1.0}))
	f.close()
	ok("num_old_save_label", game.saved_chapter_name() == "Chapter 8: A Trace of Noah", game.saved_chapter_name())
	var menu = load("res://game/scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await frames(3)
	var cont: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if String((b as Button).text).begins_with("Continue"):
			cont = b
	ok("num_menu_continue_label", cont != null and cont.text == "Continue  -  Chapter 8: A Trace of Noah", cont.text if cont else "-")
	menu.free()


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.auto_confirm = true
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	await numbering()
	DEV.prepare(game)
	var nights0: int = game.world_state.get("shelter_nights", {}).size()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	ok("c9_entry", c9 != null and game.has_flag("ch9_started") and game.current_step().get("id", "") == "c9_marcus" and game.chapter_number() == 10,
		game.current_step().get("id", ""))
	ok("c9_title_card", await wait_until(func(): return world.hud.chapter_l.text == game.chapter_label(10), 60 * 6), world.hud.chapter_l.text)
	world.save()
	ok("c9_save_has_chapter", game._read_save().get("chapter", 0) == 10 and game.saved_chapter_name() == "Chapter 10: The Fall of the Supermarket")
	ok("c9_night_once", game.world_state.get("shelter_nights", {}).size() == nights0)
	ok("c9_atmosphere", world.market.get_node("Lights/Light_SALES_30").visible == false and c8.st()["barricade"] == "broken"
		and c9.marcus.visible and c9.eddie.visible and c9.ruth.visible and c9.sarah.visible)
	ok("c9_npcs_apart_start", npcs_ok() == "", npcs_ok())
	ok("c9_no_sleep_here", not p4.rest.can_rest.call())
	ok("c9_trust", c9.st()["marcus_trust"] == 2 and c9.pin_window() == 12.0)

	# ---- scene 1: Marcus (the shared talk camera)
	ok("c9_marcus_reach", await aim(c9.its["npc_Marcus"], [-Z, Z, X, -X], 1.4))
	c9.its["npc_Marcus"].interact(world.player)
	await frames(30)
	var vc: Camera3D = root.get_viewport().get_camera_3d()
	ok("c9_talk_camera", vc != null and vc.name == "TalkCam" and not world.player.controls_enabled
		and absf(1.0 - vc.fov / world.player.camera.fov - 0.1) < 0.025 and vc.global_position.distance_to(world.player.camera.global_position) < 0.03,
		vc.name if vc else "-")
	ok("c9_speaker_name", world.hud.speaker_l.text in ["MARCUS", "PROTAGONIST", "EDDIE", "RUTH"], world.hud.speaker_l.text)
	ok("c9_decision", await wait_talk(func(): return game.has_flag("ch9_marcus_talked"), 90.0) and said.has("We won't know until we try.")
		and game.current_step().get("id", "") == "c9_gather")
	ok("c9_talk_released", await wait_until(func(): return world.player.controls_enabled and root.get_viewport().get_camera_3d() == world.player.camera, 120))
	await reload()
	ok("c9_load_after_talk", game.has_flag("ch9_marcus_talked") and c9.its["medical"].prompt_text != "" and world.player.controls_enabled)

	# ---- scene 2: preparation (real units; nothing that is not there)
	var stock0: Dictionary = game.shelter_stock().duplicate()
	ok("c9_medical_reach", await aim(c9.its["medical"], [-Z, Z, X, -X], 0.9))
	c9.its["medical"].interact(world.player)
	await frames(10)
	ok("c9_medical_taken", game.has_flag("ch9_medical_done") and game.inventory.count("painkillers") == int(stock0["medical"])
		and game.shelter_stock()["medical"] == 0)
	c9.its["medical"].interact(world.player)
	await frames(5)
	ok("c9_medical_once", game.inventory.count("painkillers") == int(stock0["medical"]))
	ok("c9_food_reach", await aim(c9.its["food"], [-Z, Z, X, -X], 1.1))
	c9.its["food"].interact(world.player)
	await frames(10)
	ok("c9_food_water_real_units", game.inventory.count("canned_food") >= 2 and game.shelter_stock()["food"] == int(stock0["food"]) - 2
		and game.shelter_stock()["water"] == 0 and c9.st()["water_taken"] == 1, str(game.shelter_stock()))
	await reload()
	ok("c9_load_supplies_once", game.inventory.count("painkillers") == int(stock0["medical"]) and game.shelter_stock()["medical"] == 0
		and c9.its["medical"].prompt_text == "" and c9.its["food"].prompt_text == "")
	for k in ["Eddie", "Ruth", "Sarah"]:
		var it: Interactable = c9.its["npc_" + k]
		ok("c9_reach_" + k, await aim(it, [-Z, Z, X, -X], 1.3))
		it.interact(world.player)
		ok("c9_talk_" + k, await wait_talk(func(): return c9.st()["talked"].get(k, false), 40.0))
		await wait_until(func(): return world.player.controls_enabled and not world.conversing, 120)
	ok("c9_not_ready_without_light", not game.has_flag("ch9_prepared"))
	if p4.flashlight.on:
		p4.flashlight.set_on(false)
	p4.flashlight.set_on(true)
	ok("c9_prepared", await wait_until(func(): return game.has_flag("ch9_prepared"), 60) and game.has_flag("ch9_light_checked"))

	# ---- scenes 3-4: the warning, the fall (first person, then the player keeps control)
	ok("c9_warning", await wait_until(func(): return game.has_flag("ch9_warning_started"), 60 * 8))
	ok("c9_warning_lines", await wait_until(func(): return said.has("Get away from the windows."), 60 * 25))
	ok("c9_fall", await wait_until(func(): return game.has_flag("ch9_fall_started"), 60 * 25) and c9.report["warning_runs"] == 1)
	ok("c9_control_in_escape", world.player.controls_enabled and game.current_step().get("id", "") == "c9_escape")
	var hin: Node3D = c9.hound_in
	ok("c9_hound_inside_away", hin != null and is_instance_valid(hin) and world.market.to_local(hin.global_position).z > 12.0
		and world.market.to_local(hin.global_position).x < 6.0, str(world.market.to_local(hin.global_position)) if hin else "-")
	var fh: Node3D = c9.front_hound
	ok("c9_front_threat_outside", fh != null and is_instance_valid(fh) and world.market.to_local(fh.global_position).z < 0.0,
		str(world.market.to_local(fh.global_position)) if fh and is_instance_valid(fh) else "-")
	ok("c9_group_follows", c9.follows["Eddie"].active and c9.follows["Ruth"].active and c9.follows["Sarah"].active and c9.follows["Marcus"].active)
	var fall_snap := snapshot()
	await reload()
	ok("c9_load_mid_escape", game.has_flag("ch9_fall_started") and c9.report["warning_runs"] == 0 and c9.report["fall_runs"] == 0
		and c9.follows["Marcus"].active and c9.hound_in != null and world.player.controls_enabled)

	# ---- the escape on foot: east, the staff door, the corridor
	ok("c9_walk_east", await walk_route([Vector3(8.0, 0.2, 7.2), Vector3(12.2, 0.2, 7.2), Vector3(12.2, 0.2, 12.8), Vector3(15.4, 0.2, 13.4)]))
	var staff: Interactable = p4.its["INT_Door_Staff"]
	if not staff.is_open:
		ok("c9_staff_door_reach", await aim(staff, [-Z, X, -X], 1.0))
		staff.interact(world.player)
		await frames(40)
	ok("c9_staff_door_open", staff.is_open)
	ok("c9_walk_corridor", await walk_route([Vector3(15.4, 0.2, 15.6), Vector3(12.0, 0.2, 15.6), Vector3(9.6, 0.2, 15.9)]))
	ok("c9_marcus_pinned", await wait_until(func(): return c9._busy.get("pinned", false) and c9.its["pinned"].prompt_text != "", 60 * 4))
	ok("c9_others_head_out", not c9.follows["Eddie"].active and not c9.follows["Ruth"].active)
	var pin_snap := snapshot()
	# Outcome A: pull him free in time
	await frames(60)
	ok("c9_pin_reach", await aim(c9.its["pinned"], [-X, -Z, Z], 1.1))
	c9.its["pinned"].interact(world.player)
	ok("c9_marcus_saved", await wait_until(func(): return game.has_flag("ch9_marcus_saved"), 60 * 3) and not game.has_flag("ch9_marcus_lost")
		and c9.marcus.visible and c9.follows["Marcus"].active and c9.st()["marcus_outcome"] == "survived")
	ok("c9_walk_out", await walk_route([Vector3(8.6, 0.2, 16.4), Vector3(8.0, 0.2, 17.6), Vector3(8.0, 0.2, 19.6)]))
	ok("c9_escaped", await wait_until(func(): return game.has_flag("ch9_escaped"), 60 * 3) and game.has_flag("ch9_supermarket_lost")
		and game.shelter_stock()["food"] == 0 and c9.st()["abandoned_stock"]["food"] == int(stock0["food"]) - 2)
	ok("c9_lookback", await wait_until(func(): return game.has_flag("ch9_lookback_done"), 60 * 6))
	ok("c9_roll_call_alive", await wait_talk(func(): return said.has("All of us. Barely.") and said.has("We don't have another choice."), 40.0)
		and not said.has("Not Marcus."))
	ok("c9_store_closed", p4.rest.interactable.prompt_text == "" and not p4.rest.can_rest.call())
	await reload()
	ok("c9_load_outside", game.has_flag("ch9_escaped") and c9.follows["Eddie"].active and c9.follows["Marcus"].active and c9.hounds.is_empty()
		and game.current_step().get("id", "") == "c9_rendezvous")
	var rv: Vector3 = c9.c6.hl(c9.RV_LOCAL)
	await walk_world([world.market.global_transform * Vector3(8.0, 0.2, 21.0), Vector3(40.0, 0.2, -52.0),
		Vector3(51.0, 0.2, -55.0), Vector3(51.0, 0.2, -59.5), Vector3(rv.x, 0.2, rv.z)])
	ok("c9_walk_to_rendezvous", await wait_until(func(): return game.has_flag("ch9_rendezvous_reached"), 120), str(world.player.global_position))
	ok("c9_rendezvous", await wait_talk(func(): return game.has_flag("chapter_9_complete"), 60.0) and said.has("Together.")
		and game.has_flag("supermarket_evacuated") and game.has_flag("next_destination_farms"))
	ok("c9_complete_card", await wait_until(func(): return world.hud.chapter_l.text == game.chapter_label(10, true), 60 * 3), world.hud.chapter_l.text)
	ok("c9_roster", c9.st()["roster"] == ["Eddie", "Ruth", "Sarah", "Marcus"] and c9.st()["marcus_outcome"] == "survived")
	ok("c9_npcs_apart_rendezvous", npcs_ok() == "", npcs_ok())
	ok("c9_no_next_chapter", not game.has_flag("ch10_started") and game.current_step().get("id", "") == "c9_complete" and game.chapter_number() == 10)
	await reload()
	ok("c9_load_complete", game.has_flag("chapter_9_complete") and c9.marcus.visible and not c9.follows["Eddie"].active
		and c9.eddie.global_position.distance_to(rv) < 4.0 and game.inventory.count("painkillers") == int(stock0["medical"]),
		"vis %s/%s/%s/%s eddie %.1f m from rv, follow %s, pk %d" % [c9.marcus.visible, c9.eddie.visible, c9.ruth.visible, c9.sarah.visible,
		c9.eddie.global_position.distance_to(rv), c9.follows["Eddie"].active, game.inventory.count("painkillers")])

	# ---- Outcome B: (from the pin) nobody pulls him free in time: he is lost; the others escape
	await restore(pin_snap)
	ok("c9_b_repinned", await wait_until(func(): return c9._busy.get("pinned", false), 60 * 6), str(world.market.to_local(world.player.global_position)))
	ok("c9_b_lost", await wait_until(func(): return game.has_flag("ch9_marcus_lost"), 60 * 16) and not c9.marcus.visible
		and c9.st()["marcus_outcome"] == "lost" and c9.report["lost_runs"] == 1)
	ok("c9_b_walk_out", await walk_route([Vector3(8.6, 0.2, 16.4), Vector3(8.0, 0.2, 17.6), Vector3(8.0, 0.2, 19.6)]))
	ok("c9_b_roll_call", await wait_talk(func(): return said.has("Not Marcus."), 40.0))
	await reload()
	ok("c9_b_load", game.has_flag("ch9_marcus_lost") and not c9.marcus.visible and not c9.follows["Marcus"].active and c9.follows["Eddie"].active)
	var rv2: Vector3 = c9.c6.hl(c9.RV_LOCAL)
	await walk_world([world.market.global_transform * Vector3(8.0, 0.2, 21.0), Vector3(40.0, 0.2, -52.0),
		Vector3(51.0, 0.2, -55.0), Vector3(51.0, 0.2, -59.5), Vector3(rv2.x, 0.2, rv2.z)])
	ok("c9_b_walk_to_rendezvous", await wait_until(func(): return game.has_flag("ch9_rendezvous_reached"), 120))
	ok("c9_b_complete", await wait_talk(func(): return game.has_flag("chapter_9_complete"), 60.0) and said.has("Then we find him. For Marcus.")
		and c9.st()["roster"] == ["Eddie", "Ruth", "Sarah"])
	ok("c9_b_others_alive", c9.eddie.visible and c9.ruth.visible and c9.sarah.visible, "%s/%s/%s" % [c9.eddie.visible, c9.ruth.visible, c9.sarah.visible])

	# ---- trust from the earlier choices: a shorter (never zero) window without it
	await restore(fall_snap, func(): game.world_state["ch9"]["marcus_trust"] = 0)
	ok("c9_trust_window", c9.pin_window() == 4.0)

	# ---- a depleted stock: the preparation still completes, with a warning
	DEV.prepare(game, 2, {"food": 0, "water": 0, "medical": 0, "batteries": 0})
	world.free()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	game.flags["ch9_marcus_talked"] = true
	c9._refresh_prompts()
	var inv0: int = game.inventory.size()
	ok("c9_empty_medical_reach", await aim(c9.its["medical"], [-Z, Z, X, -X], 0.9))
	c9.its["medical"].interact(world.player)
	ok("c9_empty_food_reach", await aim(c9.its["food"], [-Z, Z, X, -X], 1.1))
	c9.its["food"].interact(world.player)
	await frames(10)
	ok("c9_depleted_progresses", game.has_flag("ch9_medical_done") and game.has_flag("ch9_food_done") and game.inventory.size() == inv0
		and said.has("Not much left. It'll have to do."))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
