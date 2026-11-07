extends SceneTree
## THE VEIL - the threat director with real creatures (headless, --fixed-fps 60). Nothing is simulated: real
## Hound / Skitter / Shellcrawler instances with their collision and AI, a real Tentacle, the real player body.
##   -- (default) Chapter 7 entry:  A walking outdoors 3 min, G pursuit/collision/cleanup, B a two-storey house 3 min,
##                                 D the Tentacle at CRITICAL, C driving 4 min, E save + Continue mid-trip
##   -- ch5                         F: a scavenging trip in Chapter 5, first engagement on foot
## An ENGAGEMENT counts only when a creature is chasing the player, on the ground near the player's level, within
## 16 m, with a clear line between them (reachable and visible), and its collision is on.
const DEV7 := preload("res://game/tools/dev_chapter7.gd")
const DEV5 := preload("res://game/tools/dev_chapter5.gd")

var fails := 0
var w: Node
var game: Node
var ex: Node
var p: CharacterBody3D
var engaged_at := -1.0
var engaged_info := ""
var max_hunting := 0
var max_out := 0
var inside_house_hits := 0
var struggles := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _el() -> float:
	return float(ex.st().get("elapsed", 0.0))


## One physics frame of play: keeps the player alive (this measures the threat, not survival), wins struggles
## by clicking, answers panels that pause the tree, and samples what the creatures are doing.
func _step(walk := false, turn := 0.0) -> void:
	if w.phase4 and w.phase4.choice.is_open():
		w.phase4.choice.pick(-1)
	var st = w.get_node_or_null("Struggle")
	if st and st.active:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		st._input(e)
		if st._prog < 0.1:
			struggles += 1
	if p.health < 60.0:
		p.health = 100.0
	if walk and not w.in_car:
		Input.action_press("move_forward")
		p.set_yaw_pitch(p.rotation.y + turn / 60.0, 0.0)
	await physics_frame
	var hunting := 0
	for c in ex.creatures:
		var n: Node3D = c["node"]
		var ai = c.get("ai")
		if ai == null or not is_instance_valid(n):
			continue
		if String(ai.state) == "CHASE":
			hunting += 1
		if not ex._outdoors_at(n.global_position, n):
			inside_house_hits += 1
		if engaged_at < 0.0 and String(ai.state) == "CHASE":
			var tgt: Vector3 = ex.threat_target()
			var d: float = n.global_position.distance_to(tgt)
			var los: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
				n.global_position + Vector3(0, 0.9, 0), tgt + Vector3(0, 0.9, 0), 1, [p.get_rid(), (n as CollisionObject3D).get_rid(), w.sedan.get_rid()]))
			if d < 16.0 and los.is_empty() and absf(n.global_position.y - tgt.y) < 1.5 and (n as CollisionObject3D).collision_layer & 1:
				engaged_at = _el()
				engaged_info = "%s (%s) %.1f m away at %s" % [c["kind"], c.get("role", ""), d, str(n.global_position.snapped(Vector3.ONE * 0.1))]
	max_hunting = maxi(max_hunting, hunting)
	max_out = maxi(max_out, ex.creatures.filter(func(c): return c.get("ai") != null).size())


func _play_for(seconds: float, walk := false, turn := 0.0) -> void:
	for i in int(seconds * 60.0):
		await _step(walk, turn)
	Input.action_release("move_forward")


func _boot(dev) -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	dev.prepare(game)
	if not "car_keys" in game.inventory:
		game.inventory.append("car_keys")
	game.flags["fridge_checked"] = true
	game.world_state["supply_grace"] = true
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 200:
		await physics_frame
	ex = w.expedition
	p = w.player
	p.survival_active = true
	p.controls_enabled = true
	p.look_enabled = true


func _go_out(at: Vector3) -> void:
	ex.start("scavenge", false)
	await physics_frame
	p.global_position = at
	p.velocity = Vector3.ZERO
	for i in 10:
		await physics_frame


func _run() -> void:
	if OS.get_cmdline_user_args().has("ch5"):
		await _run_ch5()
		return
	await _boot(DEV7)
	ok("trip_possible", ex.can_scavenge(), "shelter %s" % ex.shelter())
	# ---- A + G: three minutes walking circles on the open ground east of the store
	await _go_out(Vector3(92, 0.3, -42))
	var spawned0: int = ex.report["spawned"]
	await _play_for(180.0, true, 0.25)
	ok("A_clock_runs", _el() > 175.0, "elapsed %.1f" % _el())
	ok("A_danger_critical", ex.level() >= 3, ex._lv_name(ex.level()))
	ok("A_spawned", int(ex.report["spawned"]) > spawned0, str(ex.report))
	ok("A_engaged_within_90s", engaged_at >= 0.0 and engaged_at <= 95.0, "at %.1f s: %s" % [engaged_at, engaged_info])
	ok("G_caps", max_out <= 2 and max_hunting <= 1, "max out %d, max hunting %d" % [max_out, max_hunting])
	ok("G_never_indoors", inside_house_hits == 0, "%d samples" % inside_house_hits)
	ok("G_struggle_or_bite_happened", struggles > 0 or int(ex.report.get("engaged", 0)) > 0, "struggles %d engaged %d" % [struggles, int(ex.report.get("engaged", 0))])
	# ---- B: a two-storey house, upstairs, three minutes
	var house: Node3D = null
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/house_stairs.json"))
	for h in w.get_node("Residential/Houses").get_children():
		var info: Dictionary = h.get_meta("veil_house", {})
		if data.has(String(info.get("design", "")) + ("_Mirror" if info.get("mirrored", false) else "")):
			house = h
			break
	ok("B_found_two_storey", house != null)
	if house:
		var info: Dictionary = house.get_meta("veil_house", {})
		var f: Dictionary = data[String(info.get("design", "")) + ("_Mirror" if info.get("mirrored", false) else "")][0]
		var o: Array = f["origin"]
		var xf: Transform3D = house.global_transform * Transform3D(Basis(Vector3.UP, float(f["yaw"])), Vector3(o[0], o[1], o[2]))
		var upstairs: Vector3 = xf * Vector3(float(f["width"]) * 0.5, float(f["height"]) + 0.1, float(f["run"]) + 0.9)
		var yard: Vector3 = ex.threat_target()
		p.global_position = upstairs
		await _play_for(1.0)
		ok("B_indoors_detected", not ex._outdoors_at(p.global_position), str(p.global_position))
		var el0 := _el()
		var seen_out := 0
		inside_house_hits = 0
		for i in 180:
			await _play_for(1.0)
			if ex.creatures.any(func(c): return c.get("ai") != null and is_instance_valid(c["node"])):
				seen_out += 1
		ok("B_clock_runs_inside", _el() - el0 > 175.0, "%.1f s" % (_el() - el0))
		ok("B_creatures_active_outside", seen_out > 90, "%d of 180 s with a creature out" % seen_out)
		ok("B_never_inside_house", inside_house_hits == 0, "%d samples" % inside_house_hits)
		# out again: something is still there and can reach the player
		engaged_at = -1.0
		p.global_position = yard
		await _play_for(40.0, true, 0.2)
		ok("B_engaged_after_exit", engaged_at >= 0.0, engaged_info)
	# ---- D: the Tentacle at CRITICAL
	var t0 := int(ex.report.get("tentacles", 0))
	p.global_position = Vector3(92, 0.3, -42)
	p.set_yaw_pitch(0.0, 0.0)
	ex._next_tent = 0.0
	var tent: Node3D = null
	for i in 60 * 8:
		await _step()
		var t = w.get_node_or_null("EXP_Tentacle")
		if t:
			tent = t
			break
	ok("D_tentacle_emerged", tent != null and int(ex.report.get("tentacles", 0)) > t0)
	if tent:
		var d: float = tent.global_position.distance_to(p.global_position)
		ok("D_near_and_outdoors", d > 5.0 and d < 11.0 and ex._outdoors_at(tent.global_position), "%.1f m" % d)
		await _play_for(14.0)
		ok("D_retreated", not is_instance_valid(tent))
	# ---- C: four minutes driving
	game.flags["vehicle_repaired"] = true
	w.sedan.global_position = Vector3(92, 0.5, -30)
	w.sedan.rotation.y = 0.0
	w.sedan.fuel = 1.0
	w.sedan.condition = 1.0
	p.global_position = Vector3(90, 0.3, -30)
	await _play_for(0.5)
	w.enter_car()
	await _play_for(3.0)
	ok("C_in_car", w.in_car)
	var tt := 0.0
	w.sedan.parking_brake = false
	w.sedan.autopilot = func(d: float) -> Vector3:
		tt += d
		return Vector3(0.45, 0.0, 0.35 if fmod(tt, 30.0) < 22.0 else -0.2)     # loops round the open ground
	var sp0: int = ex.report["spawned"]
	var el1 := _el()
	var max_car_out := 0
	for i in 240:
		await _play_for(1.0)
		max_car_out = maxi(max_car_out, ex.creatures.filter(func(c): return c.get("ai") != null).size())
	ok("C_clock_runs_driving", _el() - el1 > 235.0, "%.1f s" % (_el() - el1))
	ok("C_spawns_while_driving", int(ex.report["spawned"]) > sp0 or max_car_out > 0, "spawned %d -> %d, max out %d" % [sp0, ex.report["spawned"], max_car_out])
	w.sedan.autopilot = Callable()
	# ---- E: save, Continue, still out there, the director resumes
	var el2 := _el()
	w.save()
	ok("E_loads", game.load_game())
	w.queue_free()
	await physics_frame
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 200:
		await physics_frame
	ex = w.expedition
	p = w.player
	p.survival_active = true
	ok("E_trip_resumed", ex.active() and absf(_el() - el2) < 5.0, "%.1f vs %.1f" % [_el(), el2])
	if w.in_car:
		w.sedan.speed = 0.0
		w.exit_car()
		await _play_for(2.0)
	p.global_position = Vector3(92, 0.3, -42)
	var sp1: int = ex.report["spawned"]
	await _play_for(40.0, true, 0.25)
	ok("E_threat_after_continue", int(ex.report["spawned"]) > sp1, str(ex.report))
	print("THREAT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _run_ch5() -> void:
	await _boot(DEV5)
	ok("F_ch5_trip_possible", ex.can_scavenge(), "shelter %s c5 %s" % [ex.shelter(), str(ex._c5() != null)])
	if not ex.can_scavenge():
		print("THREAT fails=%d" % fails)
		quit(1)
		return
	await _go_out(Vector3(92, 0.3, -42))
	await _play_for(110.0, true, 0.25)
	ok("F_ch5_engaged_within_90s", engaged_at >= 0.0 and engaged_at <= 95.0, "at %.1f s: %s" % [engaged_at, engaged_info])
	print("THREAT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
