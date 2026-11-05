extends SceneTree
## THE VEIL - the hidden golden-face Easter egg (game/easter_egg/golden_peek.gd), automated checks (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/easter_egg_test.gd
## A new game; the player is put in the woods off the county road (on foot, before town) and turned slowly as if
## looking around. Checks: nothing before 30 s; nothing on the road; the peek behind a tree 20+ m away; the 10 m
## trigger; the lunge, the sound (3 s) at impact, the flash timing; control, position, health and items untouched;
## the line once the sound is over, with movement free; never again; the flag through save/load.

var fails := 0
var world: Node
var game: Node
var dlg: Node
var egg: Node
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


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


## A spot in the woods off the route, with trees 20-45 m around it.
func woods_spot() -> Vector3:
	var route: Array = egg.route
	for i in range(3, route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var ab := (b - a)
		if ab.length() < 1.0:
			continue
		for t in [0.5]:
			for side in [1.0, -1.0]:
				for off in [16.0, 22.0, 28.0]:
					var m: Vector2 = a + ab * t + Vector2(-ab.y, ab.x).normalized() * side * off
					var p := Vector3(m.x, 0.0, m.y)
					var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 30, 0), p - Vector3(0, 30, 0), 1))
					if hit.is_empty():
						continue
					p.y = (hit["position"] as Vector3).y
					var far: Array = egg.trees_near(p, 45.0).filter(func(tr): return Vector2(tr["pos"].x - p.x, tr["pos"].z - p.z).length() > 20.0)
					if egg.in_woods(p) and far.size() >= 4 and egg.trees_near(p, 2.0).is_empty():
						return p
	return Vector3.INF


func put(p: Vector3) -> void:
	world.player.global_position = p + Vector3(0, 0.15, 0)
	world.player.velocity = Vector3.ZERO
	await frames(3)


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	dlg.auto_confirm = true
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	game.new_game()
	game.delete_save()
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(30)
	egg = world.get_node("EasterEggGolden")
	ok("egg_present", egg != null and not egg.route.is_empty() and not egg.done())
	await wait_until(func(): return world.player.controls_enabled and world.player.visible, 60 * 40)
	var spot: Vector3 = egg.woods_spot() if egg.has_method("woods_spot") else woods_spot()
	ok("woods_spot", spot.is_finite(), str(spot))
	if not spot.is_finite():
		print("RESULT FAIL (no woods spot)")
		quit(1)
		return
	world.player.controls_enabled = true
	await put(spot)
	ok("in_woods", egg.in_woods(world.player.global_position) and egg._in_opening() and egg.route_distance(world.player.global_position) > 8.0)
	var hp: float = world.player.health
	var inv: Array = game.inventory.duplicate()
	var flags0: Dictionary = game.flags.duplicate()
	var ch0: int = game.chapter_number()

	# ---- not before 30 s (looking around slowly the whole time)
	var yaw := 0.0
	for i in 60 * 25:
		yaw += 0.004
		world.player.set_yaw_pitch(yaw, 0.0)
		await process_frame
	ok("not_before_30s", not egg.report["placed"] and egg.peek == null, "woods %.1f s" % egg.st()["woods_time"])

	# ---- not on the road: the clock stops and nothing is placed there
	var on_road := Vector3(egg.route[4].x, spot.y, egg.route[4].y)
	await put(on_road)
	var wt: float = egg.st()["woods_time"]
	for i in 60 * 8:
		yaw += 0.004
		world.player.set_yaw_pitch(yaw, 0.0)
		await process_frame
	ok("not_on_route", not egg.report["placed"] and absf(float(egg.st()["woods_time"]) - wt) < 0.01 and egg.route_distance(world.player.global_position) < 8.0)

	# ---- back in the woods: past 30 s it peeks out behind a tree 20+ m away (placed while out of view)
	await put(spot)
	var placed_frame := -1
	for i in 60 * 40:
		yaw += 0.004
		world.player.set_yaw_pitch(yaw, 0.0)
		await process_frame
		if egg.peek != null:
			placed_frame = i
			break
	ok("peek_placed", egg.peek != null and float(egg.st()["woods_time"]) >= 30.0, "woods %.1f s" % egg.st()["woods_time"])
	if egg.peek == null:
		print("RESULT FAIL (no peek)")
		quit(1)
		return
	var tree: Vector3 = egg.peek.get_meta("tree")
	var d := Vector2(tree.x - spot.x, tree.z - spot.z).length()
	ok("peek_far_tree", d >= 20.0 and d <= 45.0, "%.1f m" % d)
	ok("character_hidden_until_rush", not egg.peek.visible)
	var cue: Node = egg.lure
	ok("selected_tree_mesh_found", cue != null and not cue.targets.is_empty())
	await frames(2)
	var first_pulses: int = cue.pulses
	await frames(120)
	ok("tree_pulses_every_two_seconds", cue.pulses == first_pulses + 1)
	ok("rustle_and_leaves", cue.audio.stream.get_length() > 0.5 and cue.leaves.size() > 0)
	ok("selected_tree_actually_moves", cue.targets.any(func(target): return not target.applied.is_equal_approx(target.original)))
	# the trunk hides the back of the head: a ray to the peek's left edge (as seen) meets the tree first
	var cam: Camera3D = world.player.camera
	var to_tree := (tree - cam.global_position) * Vector3(1, 0, 1)
	var right := to_tree.normalized().cross(Vector3.UP) * -1.0
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hidden_part: Vector3 = egg.peek.global_position - right * 0.22
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, hidden_part, 1, [world.player.get_rid()]))
	ok("peek_behind_trunk", not hit.is_empty() and String((hit["collider"] as Node).name).begins_with("VG_Tree"), str(hit.get("collider", "-")))

	# ---- walk toward it: the trigger at ~10 m
	Input.action_press("move_forward")
	var trig_d := -1.0
	for i in 60 * 30:
		var dv: Vector3 = (tree - world.player.global_position) * Vector3(1, 0, 1)
		if world.player.controls_enabled:
			world.player.set_yaw_pitch(atan2(-dv.x, -dv.z), 0.0)
		await process_frame
		if egg.report["triggered"]:
			trig_d = dv.length()
			break
	Input.action_release("move_forward")
	ok("trigger_10m", egg.report["triggered"] and trig_d > 8.5 and trig_d <= 10.5, "%.2f m" % trig_d)
	var pos_at: Vector3 = world.player.global_position
	ok("control_held", not world.player.controls_enabled)
	ok("tree_stops_at_jumpscare", not cue.active and cue.restored and not cue.audio.playing)
	ok("tree_transform_restored", cue.targets.all(func(target): return target.applied.is_equal_approx(target.original)))
	ok("scare_runs", await wait_until(func(): return egg.report["flash_s"] > 0.0, 60 * 5))
	ok("lunge_fast", egg.report["lunge_s"] >= 0.14 and egg.report["lunge_s"] <= 0.3, "%.3f s" % egg.report["lunge_s"])
	ok("audio_at_impact", egg.report["audio_at_impact"])
	ok("face_meets_lens_center", egg.report.get("face_center_error_px", INF) < 1.0)
	ok("front_portrait_at_impact", egg.report.get("front_at_impact", false))
	ok("both_audio_sample_synchronized", egg.report.get("audio_synchronized", false))
	ok("grenade_source_seconds_1_to_4", absf(egg.IMPACT_MIX.get_length() - 3.0) < 0.05)
	ok("rush_face_centered_every_frame", egg.report.get("rush_max_face_error_px", INF) < 1.0)
	ok("front_viewport_sized", egg.report["front_rect_size"].x >= 1000 and egg.report["front_rect_size"].y >= 600)
	ok("audio_3s", absf(egg.SCARE.get_length() - 3.0) < 0.05, "%.2f s" % egg.SCARE.get_length())
	ok("flash_timing", egg.report["flash_s"] >= 1.5 and egg.report["flash_s"] <= 1.8, "%.2f s" % egg.report["flash_s"])
	ok("control_back", world.player.controls_enabled and world.player.global_position.distance_to(pos_at) < 0.05)
	ok("peek_gone", egg.peek == null and world.get_node_or_null("GoldenPeek") == null)
	# the line: after the sound, movement free while it shows
	ok("line_after_audio", await wait_until(func(): return said.any(func(t): return "gummies" in t), 60 * 8)
		and egg.report["line_at"] > egg.report["audio_end"] and egg.report["audio_end"] >= 2.9, "line %.2f s, audio end %.2f s" % [egg.report["line_at"], egg.report["audio_end"]])
	ok("line_moves_free", world.player.controls_enabled and not world.conversing and not dlg.confirm_mode)
	ok("nothing_else_changed", world.player.health == hp and game.inventory == inv and game.chapter_number() == ch0
		and game.flags.keys().filter(func(k): return not flags0.has(k) and not String(k).begins_with("egg_") and not String(k).begins_with("said_")).is_empty(),
		str(game.flags.keys().filter(func(k): return not flags0.has(k))))
	# ---- never again
	var n_said := said.filter(func(t): return "gummies" in t).size()
	egg._try_place()
	await frames(120)
	ok("no_repeat", egg.peek == null and egg.done() and said.filter(func(t): return "gummies" in t).size() == n_said)
	# ---- the flag through save / load
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(40)
	egg = world.get_node("EasterEggGolden")
	ok("save_load_flag", game.has_flag("egg_golden_seen") and game.has_flag("egg_golden_reaction") and egg.done())
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)

