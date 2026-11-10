extends SceneTree
## THE VEIL - navigation help (game/ui/nav_map.gd + the HUD marker), headless:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/navigation_test.gd
## From the Chapter 8 developer entry (the supermarket is the shelter): the marker's off-screen arrow, its hiding
## during a cinematic, the way back to the shelter, the shelter moving with the story (never a fallen one), and the
## map on M (opens, holds the player still, closes and gives control back).

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var u := InputEventKey.new()
	u.physical_keycode = k
	u.keycode = k
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(90)
	var hud = w.hud
	var nav = w.nav
	var p = w.player
	p.controls_enabled = true
	ok("nav_present", nav != null and hud.marker_fallback.is_valid())
	# ---- the off-screen arrow
	var cam: Camera3D = p.camera
	hud.set_marker(cam.global_position + cam.global_transform.basis.z * 30.0, "BEHIND")
	await frames(3)
	ok("arrow_when_behind", hud.marker_visible and hud._mk_arrow.visible and not hud._mk_dot.visible)
	hud.set_marker(cam.global_position - cam.global_transform.basis.z * 30.0, "AHEAD")
	await frames(3)
	ok("dot_when_on_screen", hud.marker_visible and hud._mk_dot.visible and not hud._mk_arrow.visible)
	var cine := Camera3D.new()
	w.add_child(cine)
	w._cine = cine
	await frames(3)
	ok("hidden_in_cinematic", not hud.marker_visible)
	w._cine = null
	cine.queue_free()
	# ---- the way back to the shelter (the supermarket now)
	var s: Array = nav.shelter()
	ok("shelter_supermarket", not s.is_empty() and s[0].distance_to(w.market.global_transform * Vector3(0, 1.3, -0.9)) < 0.1)
	p.global_position = w.market.global_transform * Vector3(0.3, 0.3, -40.0)
	await frames(3)
	ok("points_home_when_out", not nav.shelter_marker().is_empty())
	p.global_position = w.market.global_transform * Vector3(0.3, 0.3, -3.0)
	await frames(3)
	ok("quiet_near_shelter", nav.shelter_marker().is_empty())
	# ---- the shelter moves with the story; a fallen one is never shown
	game.flags["ch9_supermarket_lost"] = true
	game.flags["ch10_started"] = true
	s = nav.shelter()
	ok("shelter_mill_house", not s.is_empty() and Vector2(s[0].x, s[0].z).distance_to(Vector2(-92, 14)) < 6.0, str(s))
	game.flags["ch14_evac_started"] = true
	ok("no_fallen_shelter", nav.shelter().is_empty())
	game.flags["ch15_started"] = true
	ok("refuge_in_finale", nav.shelter().size() == 2 and nav.shelter()[1] == "REFUGE")
	for f in ["ch9_supermarket_lost", "ch10_started", "ch14_evac_started", "ch15_started"]:
		game.flags.erase(f)
	# ---- the map
	var names: Array = nav.places().map(func(x): return x[0])
	ok("places_known", names.has("Home") and names.has("Video Game Shop") and names.has("Supermarket") and not names.has("Old District"), str(names))
	game.set_flag("map_acquired")                       # (Eddie hands it over in the supermarket: map_test.gd)
	await key(KEY_M)
	ok("map_opens", nav.open and nav.panel.visible and not p.controls_enabled)
	Input.action_press("move_forward")
	var before: Vector3 = p.global_position
	await frames(30)
	Input.action_release("move_forward")
	ok("cannot_move_on_map", p.global_position.distance_to(before) < 0.05)
	await key(KEY_M)
	ok("map_closes", not nav.open and not nav.panel.visible and p.controls_enabled and p.look_enabled)
	await key(KEY_M)
	await key(KEY_ESCAPE)
	ok("esc_closes", not nav.open and p.controls_enabled and not hud.is_paused())
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
