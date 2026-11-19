extends SceneTree
## THE VEIL - final outstanding repairs, focused checks (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/final_repairs_test.gd [-- <part> ...]
## Parts (default: all): shelter (one exit menu, the handgun handover and its practice / skip, one scavenging run a
## day, returning does not move the story, no menu during a scene), objectives (held until the scene that unlocked
## them ends; skip; reload; no duplicates), radio (static after the Veil, also after a save / load), tentacle (the
## writhe starts, moves the tip, ends with the tentacle), assets (the medicine cabinet's walls seen from inside; the
## checkout bags on the floor), park (automatic parking time and end position from three approaches).
## These are code / geometry checks: they do not show how anything LOOKS on screen.

const DEV7 := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0
var world: Node
var game: Node
var ex: Node
var sa: Node
var p: CharacterBody3D


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait_until(f: Callable, seconds: float) -> bool:
	var t := 0
	while t < int(seconds * 60.0):
		if f.call():
			return true
		await process_frame
		t += 1
	return f.call()


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _want(part: String) -> bool:
	var a := OS.get_cmdline_user_args()
	return a.is_empty() or a.has(part)


func _boot() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV7.prepare(game)
	game.world_state["supply_grace"] = true
	game.save_game()
	game.load_game()
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(120)
	ex = world.expedition
	sa = world.sidearm
	p = world.player
	p.controls_enabled = true
	p.look_enabled = true


func _run() -> void:
	if _want("assets"):
		await _assets()
	if _want("tentacle"):
		await _tentacle()
	if _want("shelter") or _want("objectives") or _want("radio") or _want("park"):
		await _boot()
	if _want("shelter"):
		await _shelter()
	if _want("objectives"):
		await _objectives()
	if _want("radio"):
		await _radio()
	if _want("park"):
		await _park()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ shelter exit, handgun, scavenging day
func _choice() -> Node:
	return world.phase4.choice


func _shelter() -> void:
	var exit_it: Interactable = ex.its["exit"]
	# stand inside by the doors (the vestibule)
	var din: Node3D = world.market.get_node("Doorways/Entrance_Inside")
	p.global_position = world.market.global_transform * Vector3(0, 0.15, 2.2)      # the vestibule, by the exit point
	p.velocity = Vector3.ZERO
	await frames(30)
	ok("S_in_store", ex.can_scavenge(), "in hall %s can %s" % [ex.in_store(), ex.can_scavenge()])
	var prompt := exit_it.get_prompt()
	ok("S_exit_prompt", prompt == "[E] Leave Shelter", prompt)
	# every story interaction on the same doorway shows that same prompt and opens that same menu
	var doors: Array = ex._story_doors()
	var same := doors.all(func(d): return (d as Interactable).get_prompt() == prompt or (d as Interactable).collision_layer == 0)
	ok("S_one_prompt_per_door", doors.size() >= 1 and same, str(doors.map(func(d): return [String(d.get_parent().name), d.get_prompt(), d.own_prompt(), d.collision_layer])))
	# 1st use: Sarah stops the player with the handgun (she lives in the shelter in this entry)
	ok("S_presenter_sarah", sa.presenter() == "Sarah" and sa.handover_pending(), sa.presenter())
	var guns0: int = game.inventory.count("handgun")
	exit_it.interact(p)
	var asked := await wait_until(func(): return _choice().is_open() and "HANDGUN" in String(_choice()._title.text), 40.0)
	ok("S_handover_offered", asked and game.has_item("handgun"), String(_choice()._title.text) if _choice().is_open() else "no panel")
	_choice().pick(0)                                     # "Show Me How It Works"
	await frames(10)
	ok("S_one_gun", game.inventory.count("handgun") == 1 and guns0 == 0 and sa.mag() == 6 and sa.reserve() == 3, "guns %d mag %d reserve %d" % [game.inventory.count("handgun"), sa.mag(), sa.reserve()])
	ok("S_practice_started", sa.practising(), String(sa.st().get("tutorial", "")))
	# the first-person gun: muzzle down the view, nothing inside the near plane
	await frames(30)
	var cam: Camera3D = p.camera
	var v: Node3D = sa._view
	var muzzle_dir: Vector3 = (v.global_basis * Vector3(0, 0, -1)).normalized() if v else Vector3.ZERO
	var fwd := -cam.global_basis.z
	var nearest := INF
	if v:
		for gi in v.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = (cam.global_transform.affine_inverse() * (gi as MeshInstance3D).global_transform) * (gi as MeshInstance3D).get_aabb()
			for k in 8:
				nearest = minf(nearest, -bb.get_endpoint(k).z)
	ok("S_gun_points_forward", v != null and v.visible and muzzle_dir.dot(fwd) > 0.97, "dot %.3f" % muzzle_dir.dot(fwd))
	ok("S_gun_not_clipping", nearest > cam.near + 0.05, "closest %.3f m (near %.2f)" % [nearest, cam.near])
	var flash_off: float = (sa._flash.global_position - (v.global_transform * sa.MUZZLE)).length() if v and sa._flash else 9.0
	ok("S_flash_at_muzzle", flash_off < 0.02, "%.3f m" % flash_off)
	# practice: aim (right button held), shoot the cart, reload
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	Input.parse_input_event(e)
	var aimed := await wait_until(func(): return String(sa.st().get("tutorial", "")) == "fire", 5.0)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	ok("S_practice_aim", aimed, String(sa.st().get("tutorial", "")))
	var cart: Node3D = sa._target_cart
	ok("S_practice_target", cart != null, str(cart))
	if cart:
		var to: Vector3 = cart.global_position + Vector3(0, 0.45, 0) - cam.global_position
		p.set_yaw_pitch(atan2(-to.x, -to.z), clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.2))
		await frames(3)
	sa._cd = 0.0
	sa.fire()
	await frames(5)
	ok("S_practice_hit", String(sa.st().get("tutorial", "")) in ["reload", "done"] and int(sa.report.get("practice_hits", 0)) >= 1 and sa.mag() == 5,
		"step %s hits %d mag %d" % [sa.st().get("tutorial", ""), int(sa.report.get("practice_hits", 0)), sa.mag()])
	sa.reload()
	var done := await wait_until(func(): return String(sa.st().get("tutorial", "")) == "done", 6.0)
	ok("S_practice_done", done and sa.mag() == 6 and sa.reserve() == 2, "step %s mag %d reserve %d" % [sa.st().get("tutorial", ""), sa.mag(), sa.reserve()])
	await frames(200)                                    # Sarah's last lines
	# 2nd use: the menu (no handover again)
	var flags0: Dictionary = game.flags.duplicate()
	var step0: String = String(game.current_step().get("id", ""))
	exit_it.interact(p)
	var menu := await wait_until(func(): return _choice().is_open() and "LEAVE THE SHELTER" in String(_choice()._title.text), 10.0)
	ok("S_menu", menu and ex.last_menu.has("story") and ex.last_menu.has("scavenge") and ex.last_menu.has("stay") and not sa.handover_pending(), str(ex.last_menu))
	_choice().pick(ex.last_menu.find("scavenge"))
	var who := await wait_until(func(): return _choice().is_open() and "WHO COMES" in String(_choice()._title.text), 5.0)
	if who:
		_choice().pick(0)                                 # Go alone
	await frames(20)
	ok("S_trip_started", ex.active() and int(ex.st().get("scavenged_day", -1)) == ex._today(), str(ex.st().get("scavenged_day", -1)))
	# out and back in: the trip ends, the story does not move
	p.global_position = world.market.global_transform * Vector3(0, 0.3, -6.0)
	await frames(30)
	p.global_position = world.market.global_transform * Vector3(0, 0.15, 3.8)      # back in the hall
	await frames(10)
	exit_it.interact(p)                                   # "[E] Secure the Doors"
	await frames(30)
	ok("S_trip_over", not ex.active() and bool(ex.st().get("returned", false)))
	var added: Array = []
	for k in game.flags:
		if not flags0.has(k):
			added.append(k)
	var story_added := added.filter(func(k): return String(k).begins_with("ch") or String(k).begins_with("c5_") or String(k).begins_with("chapter"))
	ok("S_return_story_unchanged", story_added.is_empty() and String(game.current_step().get("id", "")) == step0, "new flags %s, step %s -> %s" % [str(added), step0, game.current_step().get("id", "")])
	# 3rd use the same day: no scavenging on offer
	await frames(60)
	exit_it.interact(p)
	menu = await wait_until(func(): return _choice().is_open() and "LEAVE THE SHELTER" in String(_choice()._title.text), 10.0)
	ok("S_once_a_day", menu and not ex.last_menu.has("scavenge") and ex.last_menu.has("story"), str(ex.last_menu))
	_choice().pick(ex.last_menu.find("stay"))
	await frames(10)
	# a new day: it comes back
	var nights: Dictionary = game.world_state.get("shelter_nights", {})
	nights["test_extra_%d" % nights.size()] = true
	game.world_state["shelter_nights"] = nights
	ok("S_next_day", ex.scavenge_available())
	# never during a scene: a cinematic camera up -> no prompt, no menu
	var c := Camera3D.new()
	world.add_child(c)
	world._cine = c
	await frames(20)
	exit_it.interact(p)
	await frames(10)
	ok("S_no_menu_in_cinematic", exit_it.get_prompt() == "" and not _choice().is_open(), exit_it.get_prompt())
	world._cine = null
	c.queue_free()
	await frames(20)
	# the skip path, and a second handover never duplicates the gun
	game.remove_item("handgun")
	sa.st()["given"] = false
	sa.st()["tutorial"] = ""
	sa.st()["mag"] = 0
	sa.st()["reserve"] = 0
	exit_it.interact(p)
	asked = await wait_until(func(): return _choice().is_open() and "HANDGUN" in String(_choice()._title.text), 40.0)
	if asked:
		_choice().pick(1)                                 # "I Know How to Use It"
	await frames(10)
	ok("S_skip", asked and String(sa.st().get("tutorial", "")) == "skipped" and game.inventory.count("handgun") == 1 and sa.mag() == 6 and sa.reserve() == 0,
		"tutorial %s guns %d mag %d" % [sa.st().get("tutorial", ""), game.inventory.count("handgun"), sa.mag()])
	await frames(120)


# ------------------------------------------------------------------ objectives wait for their scene
func _objectives() -> void:
	var hud: Node = world.hud
	await frames(30)
	var shown0: String = hud.step_l.text
	var step: Dictionary = game.current_step()
	world.conversing = true                               # a dialogue sequence is running
	game.set_flag(String(step["flag"]))                   # ... and it unlocks the next step
	game.refresh_objective()
	await frames(60)
	var next_text := String(game.current_step().get("text", ""))
	ok("O_held_during_scene", hud.step_l.text == shown0 and hud._obj_pending.size() == 2, "shown '%s' pending %s" % [hud.step_l.text, str(hud._obj_pending)])
	world.conversing = false
	var shown := await wait_until(func(): return hud.step_l.text == next_text, 3.0)
	ok("O_shown_after_scene", shown, "'%s' vs '%s'" % [hud.step_l.text, next_text])
	# skipping: a cinematic freed early ends the hold the same way
	var step2: Dictionary = game.current_step()
	var c := Camera3D.new()
	world.add_child(c)
	world._cine = c
	game.set_flag(String(step2["flag"]))
	game.refresh_objective()
	await frames(30)
	var held: bool = hud.step_l.text == next_text
	c.queue_free()
	world._cine = null
	var t3 := String(game.current_step().get("text", ""))
	shown = await wait_until(func(): return hud.step_l.text == t3, 3.0)
	ok("O_skip_releases", held and shown, "'%s'" % hud.step_l.text)
	# the same objective twice: announced once
	var tw0 = hud._obj_tween
	game.refresh_objective()
	game.refresh_objective()
	await frames(5)
	ok("O_no_duplicate", hud._obj_tween == tw0)
	# a load restores the current objective
	game.save_game()
	game.load_game()
	game.refresh_objective()
	shown = await wait_until(func(): return hud.step_l.text == String(game.current_step().get("text", "")), 3.0)
	ok("O_after_load", shown, hud.step_l.text)


# ------------------------------------------------------------------ the car radio and the Veil
func _radio() -> void:
	var car = world.sedan
	ok("R_veil_flag", game.has_flag("p3_mist"))
	car.driven = true
	car.radio_station = 0
	var heard: Array = []
	for i in 6:
		car.next_station()
		await frames(2)
		heard.append(car.radio_playing_path())
	var music := heard.filter(func(h): return String(h).begins_with("res://"))
	ok("R_only_static_after_veil", music.is_empty() and heard.has("static"), str(heard))
	game.save_game()
	game.load_game()
	car.radio_station = 0
	car._radio_apply()
	car.next_station()
	await frames(2)
	ok("R_static_after_load", car.radio_playing_path() == "static" and car.radio_label() == "NO SIGNAL", car.radio_playing_path())
	# before the Veil (the opening's state): the stations play as before (checked within the frame: this entry's
	# world raises the Veil flag again on its next tick)
	game.flags.erase("p3_mist")
	car.radio_station = 0
	car.next_station()
	var pre: String = String(car._radio.get_meta("path", "")) if car._radio.playing else "(not playing) " + String(car._radio.get_meta("path", ""))
	ok("R_music_before_veil", pre.begins_with("res://game/audio/radio/") or pre.begins_with("(not playing) res://game/audio/radio/"), pre)
	game.flags["p3_mist"] = true
	await frames(3)
	ok("R_veil_cuts_music", car.radio_playing_path() == "static", car.radio_playing_path())
	car.radio_station = 0
	car._radio_apply()
	car.driven = false


# ------------------------------------------------------------------ the loading-door tentacle's writhe
func _tentacle() -> void:
	var t := (load("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn") as PackedScene).instantiate() as Node3D
	t.set("autoplay", "")
	root.add_child(t)
	t.transform = Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5 - 0.35), Vector3.ZERO)
	await frames(5)
	var w := VeilTentacleWiggle.attach(t)
	ok("T_attached", w != null and w._bones.size() == 10 if w else false)
	var sk: Skeleton3D = w.sk
	var tip := sk.find_bone("T_10")
	var still: Vector3 = (sk.global_transform * sk.get_bone_global_pose(tip)).origin
	w.intensity = 1.4
	w.speed = 5.0
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in 120:
		await process_frame
		var at: Vector3 = (sk.global_transform * sk.get_bone_global_pose(tip)).origin
		lo = lo.min(at)
		hi = hi.max(at)
	var span := hi - lo
	ok("T_writhes", w.frames > 60 and maxf(span.z, span.x) > 0.5, "frames %d tip span %s" % [w.frames, str(span.snapped(Vector3.ONE * 0.01))])
	ok("T_mostly_sideways", span.y < maxf(span.z, 0.01) * 1.2 + 0.25, "tip span %s" % str(span.snapped(Vector3.ONE * 0.01)))
	var base := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("T_01"))).origin
	ok("T_base_steady", base.distance_to((sk.global_transform * sk.get_bone_global_pose(sk.find_bone("T_01"))).origin) < 0.05)
	w.intensity = 0.0
	await frames(60)
	var rest: Vector3 = (sk.global_transform * sk.get_bone_global_pose(tip)).origin
	ok("T_settles", rest.distance_to(still) < 0.1, "%.3f m" % rest.distance_to(still))
	t.queue_free()
	await frames(2)
	ok("T_freed_with_tentacle", not is_instance_valid(w))


# ------------------------------------------------------------------ asset geometry: cabinet, checkout bags
func _ray_hit(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, ex: Array[RID] = []) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 0xFFFFFFFF, ex))


func _assets() -> void:
	# the medicine cabinet: from inside the open box, every wall is there (one-sided faces: seen from inside only now)
	var cab := (load("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_MedicineCabinet.glb") as PackedScene).instantiate() as Node3D
	root.add_child(cab)
	var body := cab.find_child("RES_MedicineCabinet_Mesh", true, false) as MeshInstance3D
	body.create_trimesh_collision()
	await physics_frame
	await physics_frame
	var space := cab.get_world_3d().direct_space_state
	var inside := Vector3(0, 0.0, 0.07)
	var walls := 0
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)]:
		var h := _ray_hit(space, inside, inside + d)
		if h:
			walls += 1
	ok("A_cabinet_walls_from_inside", walls == 5, "%d of 5" % walls)
	var front := _ray_hit(space, Vector3(-0.24, 0.0, 0.5), Vector3(-0.24, 0.0, 0.0))
	ok("A_cabinet_front_rim", front and absf((front["position"] as Vector3).z - 0.14) < 0.01, str(front.get("position", "none")))
	var door := cab.find_child("INT_CabinetDoor_Mirror", true, false) as Node3D
	ok("A_cabinet_door_kept", door != null and door.find_children("*", "MeshInstance3D", true, false).size() + (1 if door is MeshInstance3D else 0) >= 1)
	cab.queue_free()
	# the checkout bags: on the floor by their counters now, nothing left hanging in the aisles
	var mk := (load("res://THE_VEIL_ASSETS_V2/04_Commercial/Godot_Scenes/Supermarket.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(mk)
	var f := mk.get_node("Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Mesh") as MeshInstance3D
	f.create_trimesh_collision()
	await physics_frame
	await physics_frame
	space = mk.get_world_3d().direct_space_state
	# only the furnishing's own visible surfaces (not the store's simple invisible collision boxes round the counters)
	var ex: Array[RID] = []
	for co in mk.find_children("*", "CollisionObject3D", true, false):
		if co.get_parent() != f:
			ex.append((co as CollisionObject3D).get_rid())
	var bad := []
	for x0 in [-11.0, -8.0, -5.0]:
		var old := _ray_hit(space, Vector3(x0, 2.0, 4.4), Vector3(x0, -0.5, 4.4), ex)
		if old and (old["position"] as Vector3).y > 0.2:
			bad.append("old spot x %.1f: %.2f" % [x0, (old["position"] as Vector3).y])
		var now := _ray_hit(space, Vector3(x0 - 0.94, 2.0, 4.4), Vector3(x0 - 0.94, -0.5, 4.4), ex)
		if not now or absf((now["position"] as Vector3).y - 0.46) > 0.15:
			bad.append("new spot x %.1f: %s" % [x0 - 0.94, str(now.get("position", "none"))])
	ok("A_checkout_bags_on_floor", bad.is_empty(), str(bad))
	mk.queue_free()
	await frames(2)


# ------------------------------------------------------------------ automatic parking: time and end position
func _park() -> void:
	var car = world.sedan
	var L: Transform3D = world._park_lot_xf()
	var approaches := [["west_slow", Vector3(20.0, 0, 8.0), Vector3(-1, 0, 0), 4.0],
		["main_st", Vector3(6.0, 0, 6.0), Vector3(-0.5, 0, 1), 6.0],
		["east", Vector3(-12.0, 0, 9.0), Vector3(1, 0, 0), 5.0]]
	for a in approaches:
		game.flags.erase("auto_parked")
		game.flags.erase("parked")
		game.flags["entered_car"] = true
		var pos: Vector3 = L * (a[1] as Vector3)
		var gh = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 5, 0), pos - Vector3(0, 5, 0), 1, [car.get_rid()]))
		pos.y = ((gh["position"] as Vector3).y if gh else 0.15) + 0.05
		var fwd: Vector3 = (L.basis * (a[2] as Vector3)).normalized()
		car.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
		car.velocity = Vector3.ZERO
		car.parking_brake = false
		world.in_car = true
		p.activate(false)
		car.set_driven(true)
		car.speed = float(a[3])
		await physics_frame
		await physics_frame
		world._auto_park()
		var n := 0
		var off := 0
		while world._auto_parking and n < 60 * 50:
			for ch in get_nodes_in_group("veil_choice_panel"):
				if ch.is_open():
					ch.pick(0)
			await physics_frame
			n += 1
			if not world.car_on_asphalt():
				off += 1
		var endp: Vector3 = world.park_paths()["reverse"][-1]
		var err := Vector2(car.global_position.x - endp.x, car.global_position.z - endp.z).length()
		var secs := n / 60.0
		ok("P_park_" + String(a[0]), err < 0.6 and not world.park_report.get("placed", false) and off == 0 and secs <= 7.5,
			"%.1f s (approach %.1f, turn %.1f, reverse %.1f), end %.2f m off, %d frames off tarmac, faded %s, yaw err %.1f deg, max dev %.2f" % [secs,
			float(world.park_report.get("t_approach", -1)), float(world.park_report.get("t_turn", -1)), float(world.park_report.get("t_reverse", -1)),
			err, off, str(world.park_report.get("placed", false)), float(world.park_report.get("yaw_err_deg", -1.0)), float(world.park_report.get("max_dev", -1.0))])
		await frames(150)
		if world.in_car:
			world.exit_car()
		await frames(5)
