extends SceneTree
## THE VEIL - street tentacle, supermarket arrival, doorway tentacle: the hand-offs, checked headless.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/tentacle_entrance_test.gd [-- street|arrival|doorway]
## Code / numbers only (cue order, control, flags, distances): how it LOOKS is for the playtest.

var fails := 0
var w: Node
var game: Node
var p: CharacterBody3D


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait_until(f: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if f.call():
			return true
		await process_frame
	return f.call()


func _want(part: String) -> bool:
	var a := OS.get_cmdline_user_args()
	return a.is_empty() or a.has(part)


func _initialize() -> void:
	_run.call_deferred()
	create_timer(600.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _boot(flags: Array) -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	for f in flags:
		game.flags[f] = true
	for o in game.objectives:                          # every step before the run is done
		if String(o["id"]) == "mist_market":
			break
		game.flags[o["flag"]] = true
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(90)
	p = w.player
	p.controls_enabled = true
	p.look_enabled = true


func _run() -> void:
	await _boot(["groceries_done", "game_bought", "phase2_done", "p3_mist", "p3_stepped_out", "p3_back_inside", "p3_in_shop", "p3_two_hours_later"])
	if _want("street"):
		await _street()
	if _want("arrival"):
		await _arrival()
	if _want("doorway"):
		await _doorway()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ 1. the street tentacle, outside the game shop
func _street() -> void:
	var out := w.game_shop.get_node("Doorways/Entrance_Outside") as Node3D
	p.global_position = out.global_position + w.game_shop.global_basis * Vector3(0, 0.1, -1.2)
	p.velocity = Vector3.ZERO
	await frames(20)
	var before: int = w._tentacles.size()
	w._p3_shop_talked = true
	w._p3_npcs_moved = false
	var ran := await wait_until(func(): return w.enc_report.has("street_shot"), 30.0)
	ok("ST_fired_once", ran and w.enc_report.get("tentacle_escape_shot", false) == true)
	var r: Dictionary = w.enc_report.get("street_shot", {})
	var cues: Array = (r.get("cues", []) as Array).map(func(c): return c[0])
	var want := ["rumble", "crack", "emerge", "dodge", "lash", "impact", "eddie_run", "control"]
	ok("ST_cue_order_once_each", cues == want, str(cues))
	ok("ST_root_buried", float(r.get("root_below_street_m", 0.0)) > 0.3, "%.2f m" % float(r.get("root_below_street_m", 0.0)))
	ok("ST_emergence_2_3s", float(r.get("emergence_s", 0.0)) > 0.0, "emergence done %.2f s after the start (wall clock)" % float(r.get("emergence_s", 0.0)))
	ok("ST_lash_hits_vacated_spot", float(r.get("impact_to_spot_m", 9.0)) < 0.6, "tip %.2f m from where the player stood (solve %.2f)" % [float(r.get("impact_to_spot_m", 9.0)), float(r.get("lash_tip_error_m", 9.0))])
	ok("ST_dodge_clear_of_tip", float(r.get("camera_to_tip_m", 0.0)) > 0.5, "%.2f m" % float(r.get("camera_to_tip_m", 0.0)))
	await frames(10)
	ok("ST_control_back", p.controls_enabled and p.look_enabled and p.camera.current and not w._encounter_running)
	var t = w.get_node_or_null("MistTentacle_Street")
	ok("ST_tentacle_stays_in_chase", t != null and w._tentacles.has(t) and t.get_node_or_null("AI") != null and w._tentacles.size() == before + 1, "%d -> %d" % [before, w._tentacles.size()])
	ok("ST_mound_at_street", w.get_node_or_null("TentacleMound") != null and absf((w.get_node("TentacleMound") as Node3D).global_position.y - (r.get("ground", Vector3.ZERO) as Vector3).y) < 0.05)
	ok("ST_chase_started", game.has_flag("p3_fled_together"))
	# nothing emerges again once the chase is on
	var emerges := 0
	for tt in w._tentacles:
		var ai = (tt as Node).get_node_or_null("AI")
		if ai and ai.state == "hidden":
			emerges += 1
	ok("ST_no_tentacle_waiting_to_reemerge", emerges == 0 and w._tentacles.all(func(tt): return (tt as Node).get_node("AI").retract_after > 999.0))
	await frames(120)
	ok("ST_no_second_run", w.get_node_or_null("TentacleEscapeShot") == null and not w._encounter_running)


# ------------------------------------------------------------------ 2. the supermarket arrival
func _arrival() -> void:
	if not game.has_flag("p3_fled_together"):
		w._p3_flee_together()
	await frames(10)
	var o := w.market.get_node("Doorways/Entrance_Outside") as Node3D
	p.global_position = o.global_position + w.market.global_basis * Vector3(0.3, 0.1, -5.0)
	p.velocity = Vector3.ZERO
	var started := await wait_until(func(): return w.arrival_report.get("started", false), 10.0)
	ok("AR_starts_at_the_entrance", started and not game.has_flag("p3_in_market"))
	ok("AR_control_held", not p.controls_enabled)
	ok("AR_no_door_prompt_during_scene", w.shut_it.prompt_text == "")
	var done := await wait_until(func(): return w.arrival_report.get("done", false), 40.0)
	ok("AR_walked_in", done and w.arrival_report.get("walked_in", false) and not w.arrival_report.get("skipped", false), str(w.arrival_report))
	var lp: Vector3 = w.market.to_local(p.global_position)
	ok("AR_player_inside", lp.z > 3.0 and absf(lp.x) < 3.0, str(lp.snapped(Vector3.ONE * 0.01)))
	ok("AR_eddie_inside", w.eddie != null and w.market.to_local(w.eddie.global_position).z > 2.0, str(w.market.to_local(w.eddie.global_position).snapped(Vector3.ONE * 0.01)) if w.eddie else "none")
	ok("AR_control_back_then_objective", p.controls_enabled and game.has_flag("p3_in_market") and String(game.current_step().get("id", "")) == "mist_doors"
		and w.shut_it.prompt_text == "[E] Pull the Doors Shut", String(game.current_step().get("id", "")))
	# it never runs twice
	w._p3_market_arrival()
	await frames(5)
	ok("AR_once", not w._arrival_running)
	# the doors: the player still closes them, and the story moves on
	w.shut_it.interact(p)
	var shut := await wait_until(func(): return game.has_flag("p3_doors_shut"), 15.0)
	ok("AR_door_closes_progression", shut and w.phase4 != null, "phase4 %s" % str(w.phase4))


# ------------------------------------------------------------------ 3. the doorway tentacle (geometry)
func _doorway() -> void:
	var g := VeilGarageTentacle.new()
	w.add_child(g)
	g.world = w
	g.player = p
	if w.phase4:
		g.p4 = w.phase4
	else:
		var stub := GDScript.new()
		stub.source_code = "extends Node
var market: Node3D
"
		stub.reload()
		var n: Node = stub.new()
		n.set("market", w.market)
		w.add_child(n)
		g.p4 = n
	g.tentacle = VeilDoorwayTentacle.create(w.market)
	ok("DW_asset", g.tentacle.skeleton.get_bone_count() == 14 and g.tentacle.mesh_instance.mesh.get_surface_count() == 1
		and g.tentacle.mesh_instance.mesh.surface_get_material(0) != null, "%d triangles" % int(g.tentacle.report.get("triangles", 0)))
	# the player at the loading handle, looking at the door
	var stand := Vector3(18.75, 0.04, 16.2)
	p.global_position = w.market.to_global(stand)
	await frames(5)
	var eye: Vector3 = w.market.to_global(stand + Vector3(0, 1.6, 0))
	var door_c: Vector3 = w.market.to_global(Vector3(20.05, 1.0, 15.9))
	g._aim_path(eye, door_c - eye)
	g.tentacle.head = 0.0
	g.tentacle.pose()
	ok("DW_hidden_at_start", w.market.to_local(g.tentacle.tip_global()).x > 20.3, str(w.market.to_local(g.tentacle.tip_global()).snapped(Vector3.ONE * 0.01)))
	g.tentacle.head = g.ROOT_TO_GAP + 0.3
	g.tentacle.pose()
	var js: PackedVector3Array = g.tentacle.joints()
	var first_in := -1
	for i in js.size():
		if js[i].x < 20.05:
			first_in = i
			break
	ok("DW_tip_first", first_in == js.size() - 1, "first joint inside: %d of %d" % [first_in, js.size() - 1])
	g.tentacle.head = g.tentacle.path_length()
	g.tentacle.pose()
	js = g.tentacle.joints()
	var under := true
	for q in js:
		if q.x > 19.95 and q.x < 20.15 and (q.y < 0.08 or q.y > 0.8):
			under = false
	ok("DW_through_the_gap", under)
	ok("DW_root_fixed", js[0].distance_to(Vector3(21.7, -0.55, js[0].z)) < 0.01, str(js[0]))
	var tip := g.tentacle.tip_global()
	var view := (door_c - eye).normalized()
	var off := rad_to_deg(view.angle_to(tip - eye))
	ok("DW_tip_in_gaze", tip.distance_to(eye) < 1.2 and off < 30.0, "%.2f m from the eye, %.0f deg off the view at the door" % [tip.distance_to(eye), off])
	var hits: Array = g._clearance()
	ok("DW_clearance", hits.is_empty(), str(hits))
	g.tentacle.queue_free()
	g.queue_free()
