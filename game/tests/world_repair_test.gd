extends SceneTree
## THE VEIL - opening guidance, the fall safeguard, the maintenance-station sign, the underground fog and the
## underground tunnels' enclosure (headless).
const DEV13 := preload("res://game/tools/dev_chapter13.gd")
var fails := 0
var game: Node
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func boot() -> void:
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(90)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	# ---- the opening
	game.new_game()
	await boot()
	var og = w.get_node("OpeningGuide")
	var door: Interactable = w.interactables["home/INT_Door_Front"]
	ok("opening_marker_fridge", og.step()[1] == "FRIDGE")
	door.interact(w.player)
	await frames(40)
	ok("door_shut_before_kitchen", not door.is_open)
	game.set_flag("fridge_checked")
	ok("opening_marker_keys", og.step()[1] == "CAR KEYS")
	door.interact(w.player)
	await frames(40)
	ok("door_shut_before_keys", not door.is_open)
	game.add_item("car_keys")
	ok("opening_marker_door", og.step()[1] == "FRONT DOOR")
	door.interact(w.player)
	await frames(40)
	ok("door_opens_when_ready", door.is_open)
	# parking from anywhere: the car on the grass behind the lot, side-on -> it ends in the stall, on the tarmac
	ok("straight_on_arrows", w.get_node("RoadArrows").arrows.size() >= 6)
	game.set_flag("left_house")
	w.player.global_position = w.sedan.global_position + w.sedan.global_basis.x * 1.6
	await frames(5)
	w.enter_car()
	await frames(40)
	var lot: Transform3D = w._park_lot_xf()
	w.sedan.global_transform = Transform3D(Basis(Vector3.UP, 1.1), lot * Vector3(-6.0, 0.0, 22.5) + Vector3(0, w.sedan.global_position.y - (lot * Vector3.ZERO).y, 0))
	await frames(10)
	var paths: Dictionary = w.park_paths()
	await w._auto_park()
	await frames(10)
	var endp: Vector3 = paths["reverse"][-1]
	ok("park_from_anywhere", game.has_flag("parked") and w.car_on_asphalt() and Vector2(w.sedan.global_position.x - endp.x, w.sedan.global_position.z - endp.z).length() < 0.3,
		"%s placed %s" % [w.sedan.global_position, w.park_report.get("placed", false)])
	# ---- the shopping list: a diamond per grocery still needed, then the cashier's
	for id in w.GROCERIES:
		game.inventory.erase(id)
	game.flags.erase("groceries_done")
	w.player.global_position = w.market.global_transform * Vector3(-3.0, 0.3, 6.0)
	await frames(10)
	var groc: Array = w.hud.world_diamonds.keys().filter(func(k): return String(k).begins_with("grocery_"))
	ok("grocery_diamonds", groc.size() == 3 and not w.hud.world_diamonds.has("cashier"), str(w.hud.world_diamonds.keys()))
	game.add_item(w.GROCERIES.keys()[0])
	await frames(5)
	ok("grocery_diamond_goes", w.hud.world_diamonds.keys().filter(func(k): return String(k).begins_with("grocery_")).size() == 2)
	for id in w.GROCERIES:
		if not game.has_item(id):
			game.add_item(id)
	await frames(5)
	ok("cashier_diamond_when_ready", w.hud.world_diamonds.has("cashier") and w.hud.world_diamonds.keys().filter(func(k): return String(k).begins_with("grocery_")).is_empty())
	# ---- out of the supermarket, groceries done, the game not yet bought: one look across to Game Haven
	game.set_flag("groceries_done")
	game.flags.erase("game_bought")
	await frames(5)
	ok("diamonds_cleared_after_shop", w.hud.world_diamonds.is_empty())
	var said: Array = []
	root.get_node("Dialogue").line_started.connect(func(_s, t, _d): said.append(t))
	var fov0: float = w.player.camera.fov
	w.player.controls_enabled = true
	w.player.global_position = w.market.global_transform * Vector3(0.0, 0.3, -6.0)
	await frames(20)
	var og2 = w.get_node("OpeningGuide")
	ok("gh_look_starts", og2.gh_reminders == 1 and not w.player.controls_enabled)
	await frames(60 * 6)
	ok("gh_look_done", said.has("Oh, right. Wasn't I gonna buy a game?") and w.player.controls_enabled and absf(w.player.camera.fov - fov0) < 0.01)
	w.player.global_position = w.market.global_transform * Vector3(0.0, 0.3, -7.0)
	await frames(30)
	ok("gh_look_once", og2.gh_reminders == 1)
	# ---- the fall safeguard
	var p = w.player
	p.controls_enabled = true
	await frames(60)
	var safe: Vector3 = p._safe_pos
	p.global_position = safe + Vector3(0, -40, 0)
	p.velocity = Vector3(0, -25, 0)
	p._air_t = 1.5                                      # (as after a long fall)
	await frames(3)
	ok("fall_recovered", p.fall_recoveries == 1 and p.global_position.distance_to(safe) < 1.0, str(p.global_position))
	w.free()
	# ---- the station sign, the underground
	DEV13.prepare(game)
	await boot()
	var c = w.phase4.chapter5
	for k in ["chapter6", "chapter7", "chapter8", "chapter9", "chapter10", "chapter11", "chapter12", "chapter13"]:
		c = c.get(k) if c else null
	var c12 = c.c12
	var sign: Label3D = null
	for l in w.find_children("*", "Label3D", true, false):
		if String((l as Label3D).text).begins_with("GREYHAVEN PUBLIC WORKS\nMAINTENANCE"):
			sign = l
	ok("sign_faces_street", sign != null and sign.global_basis.z.dot(Vector3(0, 0, 1)) > 0.99 and sign.global_position.z > c12.STATION_DOOR.z
		and not sign.double_sided)
	var fz = w.fog_zones
	await frames(10)
	var env: Environment = fz._env()
	var h_above: float = env.fog_height_density
	p = w.player
	p.global_position = c.UL(Vector3(0, 0.2, 3.0))
	p.velocity = Vector3.ZERO
	await frames(15)
	ok("under_fog_local", fz.mode == "under" and env.fog_height_density == 0.0 and env.fog_density <= fz._base_d * 0.5, "%s %.4f" % [fz.mode, env.fog_density])
	# save / load underground: the same settings come back
	w.save()
	w.free()
	game.load_game()
	game.load_requested = true
	await boot()
	fz = w.fog_zones
	await frames(15)
	env = fz._env()
	ok("under_fog_after_load", fz.mode == "under" and env.fog_height_density == 0.0)
	w.player.global_position = Vector3(-110.0, 1.0, 10.0)
	await frames(15)
	ok("surface_fog_restored", fz.mode == "" and env.fog_height_density == h_above, "%.4f / %.4f" % [env.fog_height_density, h_above])
	# the tunnels: walls, floor and ceiling all along the route (no view out, no way out)
	c = w.phase4.chapter5
	for k in ["chapter6", "chapter7", "chapter8", "chapter9", "chapter10", "chapter11", "chapter12", "chapter13"]:
		c = c.get(k) if c else null
	var space = w.get_world_3d().direct_space_state
	var route := [[Vector3(0, 0, 1.2), Vector3(0, 0, 12)], [Vector3(0, 0, 12), Vector3(12, 0, 12)], [Vector3(12, 0, 12), Vector3(12, 0, 39)],
		[Vector3(12, 0, 30), Vector3(4, 0, 30)], [Vector3(0, 0, 8), Vector3(-9.5, 0, 8)], [Vector3(12, 0, 18), Vector3(19.5, 0, 18)]]
	var open := []
	for seg in route:
		var n := int(seg[0].distance_to(seg[1]))
		for k in n + 1:
			var gp: Vector3 = c.UL(seg[0].lerp(seg[1], float(k) / maxf(n, 1)) + Vector3(0, 1.4, 0))
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(gp, gp + Vector3(0, 25, 0), 1)):
				open.append("up@%s" % gp)
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(gp, gp - Vector3(0, 6, 0), 1)):
				open.append("floor@%s" % gp)
			for j in 12:
				var dir := Vector3(sin(TAU * j / 12.0), 0, cos(TAU * j / 12.0))
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(gp, gp + dir * 60.0, 1)):
					open.append("side@%s" % gp)
	ok("tunnels_enclosed", open.is_empty(), str(open.slice(0, 5)))
	# the chamber's plaque reads the right way (faces into the chamber, single-sided), as every fixed sign
	var plaque: Label3D = null
	for l in w.find_children("*", "Label3D", true, false):
		if String((l as Label3D).text).begins_with("GREYHAVEN PUBLIC WORKS\nSERVICE GALLERY"):
			plaque = l
	ok("plaque_faces_chamber", plaque != null and plaque.global_basis.z.x > 0.99 and not plaque.double_sided,
		str(plaque.global_basis.z if plaque else null))
	ok("no_double_sided_signs", w.find_children("*", "Label3D", true, false).all(func(l): return l.billboard != BaseMaterial3D.BILLBOARD_DISABLED or not l.double_sided))
	# past the doorway: the passage into the Veil is closed all round (no sky, no town), dark mist layers in it
	var seen_out := []
	var from: Vector3 = c.UL(Vector3(12.0, 2.0, 41.5))
	for d in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0.5, 0.3, 1).normalized(), Vector3(-0.5, 0.3, 1).normalized()]:
		var r = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + d * 40.0, 1))
		var shell := false
		for m in w.find_children("*", "MeshInstance3D", true, false):
			pass
		if not r:
			seen_out.append(str(d))
	ok("veil_passage_has_fog", c.veil_fog.size() >= 6)
	c._veil_tentacles()
	await frames(30)
	var tn: int = c.under.find_children("C13_VeilTentacle_*", "", true, false).size()
	await frames(60 * 6)
	ok("veil_tentacles_come_and_go", c.veil_tentacles == 3 and tn == 3 and c.under.find_children("C13_VeilTentacle_*", "", true, false).is_empty(), "%d spawned" % tn)
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
