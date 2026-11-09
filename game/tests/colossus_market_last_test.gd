extends SceneTree
## THE VEIL - the Colossus when the supermarket is the last stop: its doors die behind the player, the clerk comes
## out with them and flees at the footfall, the foot comes down beside the way to the game shop (not on it), the
## legs are solid, and the objective / marker is the game shop, where getting in works. Headless, short.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/colossus_market_last_test.gd

var fails := 0
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func until(f: Callable, s: float) -> bool:
	for i in int(s * 60.0):
		if f.call():
			return true
		await physics_frame
	return f.call()


func _initialize() -> void:
	_run.call_deferred()
	create_timer(240.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	game.new_game()
	for f in ["has_keys", "fridge_checked", "left_house", "entered_car", "game_bought"]:
		game.flags[f] = true
	if not game.has_item("car_keys"):
		game.add_item("car_keys")
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(150)
	var mk: Node3D = w.market
	w.player.global_position = mk.global_transform * Vector3(0.0, 0.2, 6.0)      # inside, at the tills
	await frames(10)
	game.set_flag("groceries_done")                                             # the last errand done in here
	ok("veil_starts", await until(func(): return game.has_flag("p3_mist"), 10.0))
	ok("clerk_stays_and_heads_out", w._clerk_out and w.cashier.visible)
	await frames(60 * 4)
	# out of the doors (they are open while powered) onto the pavement
	var door_out: Vector3 = (mk.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var door_in: Vector3 = (mk.get_node("Doorways/Entrance_Inside") as Node3D).global_position
	var nrm := ((door_out - door_in) * Vector3(1, 0, 1)).normalized()
	w.player.global_position = door_out + nrm * 1.2 + Vector3(0, 0.2, 0)
	ok("encounter_starts", await until(func(): return w._encounter_running, 6.0))
	ok("doors_died", game.has_flag("p3_market_doors_dead") and not w._doors_powered)
	ok("clerk_beside", w.enc_report.get("clerk_out", false) and w.cashier.visible)
	ok("foot_off_route", float(w.enc_report.get("route_clearance_m", -1.0)) >= 8.5, "%.1f m" % float(w.enc_report.get("route_clearance_m", -1.0)))
	ok("legs_solid", w.enc_report.get("leg_blockers", false))
	# while it stands there: the straight way to the shop is not blocked by a leg
	await until(func(): return w.enc_report.has("foot_error_m"), 30.0)
	await frames(10)
	var shop_door: Vector3 = (w.game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var sp: PhysicsDirectSpaceState3D = (w.get_world_3d() as World3D).direct_space_state
	var leg_hit := 0
	var legs := w.find_children("LegBlockers", "", true, false)
	var leg_rids: Array = []
	if not legs.is_empty():
		for b in (legs[0] as Node).find_children("*", "AnimatableBody3D", true, false):
			leg_rids.append((b as CollisionObject3D).get_rid())
	ok("leg_bodies", leg_rids.size() == 8, "%d" % leg_rids.size())
	var P: Vector3 = w.player.global_position
	for k in 21:
		var pt := P.lerp(shop_door, k / 20.0) + Vector3(0, 1.0, 0)
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.5
		q.shape = sph
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), pt)
		for h in sp.intersect_shape(q, 8):
			if leg_rids.has(h["rid"]):
				leg_hit += 1
	ok("route_to_shop_clear_of_legs", leg_hit == 0, "%d" % leg_hit)
	ok("clerk_fled", await until(func(): return w.enc_report.get("clerk_fled", false), 15.0))
	ok("control_back", await until(func(): return not w._encounter_running and w.player.controls_enabled, 40.0))
	var bc = w._beacons.get("store_back")
	var bpos: Vector3 = (bc as Node3D).global_position if bc is Node3D else (bc if bc is Vector3 else Vector3.INF)
	ok("marker_on_game_shop", bpos.is_finite() and Vector2(bpos.x - shop_door.x, bpos.z - shop_door.z).length() < 1.0, str(bpos))
	ok("clerk_gone", await until(func(): return not w.cashier.visible, 25.0))
	# into the game shop: the story goes on there
	w.player.global_position = w.game_shop.global_transform * Vector3(0.0, 0.2, 4.0)
	ok("back_inside_shop", await until(func(): return game.has_flag("p3_back_inside"), 10.0))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
