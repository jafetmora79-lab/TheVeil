extends SceneTree
## Companion follow AI (VeilCompanionFollow), headless:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/follow_ai_test.gd
## The player is walked along a collision-checked route through the town (a walk, a sprint, a sudden jump of 40 m, a doubling back)
## with Eddie following. Passing means he keeps up (never far for long), never circles (distance walked vs net progress), and
## catches up after a jump without a visible teleport while the player is looking at him.

const CS := preload("res://game/chapters/chapter_select.gd")
const FOLLOW := preload("res://game/npc/companion_follow.gd")

var fails := 0
var game: Node
var w: Node
var player: CharacterBody3D
var eddie: VeilSurvivorBody
var fol: Node
var _backup := {}
var report := {}


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(k: int) -> void:
	for i in k:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _floor(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p + Vector3(0, -3.0, 0), 1)
	var h: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(q)
	return (h["position"] as Vector3) if not h.is_empty() else p


## The player is carried along `pts` at `speed` (teleported a small step per frame, as a scene would), and the companion is
## sampled every 0.5 s: lag (distance to the player), and how far he walked against how far he got closer.
func walk_player(pts: Array, speed: float, tag: String) -> void:
	var lag_max := 0.0
	var bad_s := 0.0                                 # seconds spent more than 14 m behind
	var circle_s := 0.0                              # seconds he spent covering ground that went nowhere
	var sample_t := 0.0
	var hist: Array = []                             # [t, companion_pos, lag]
	var t := 0.0
	var idx := 1
	var pos: Vector3 = pts[0]
	player.global_position = _floor(pos) + Vector3(0, 0.05, 0)
	while idx < pts.size():
		var to: Vector3 = pts[idx]
		var d := to - pos
		d.y = 0.0
		var step := speed / 60.0
		if d.length() <= step:
			pos = to
			idx += 1
		else:
			pos += d.normalized() * step
		player.global_position = _floor(pos) + Vector3(0, 0.05, 0)
		player.velocity = Vector3.ZERO
		await process_frame
		t += 1.0 / 60.0
		sample_t += 1.0 / 60.0
		if sample_t >= 0.5:
			sample_t = 0.0
			var lag := eddie.global_position.distance_to(player.global_position)
			lag_max = maxf(lag_max, lag)
			if lag > 14.0:
				bad_s += 0.5
			hist.append([t, eddie.global_position, lag])
			if hist.size() > 8:
				# circling = ground covered in the last 4 s that goes nowhere (net displacement under a third of the path walked)
				var walked := 0.0
				for i in range(hist.size() - 8, hist.size()):
					walked += (hist[i][1] as Vector3).distance_to(hist[i - 1][1])
				var net := (hist[hist.size() - 1][1] as Vector3).distance_to(hist[hist.size() - 9][1] as Vector3)
				if lag > 6.0 and walked > 4.0 and net < walked * 0.33:
					circle_s += 0.5
	report[tag] = {"lag_max": lag_max, "bad_s": bad_s, "circle_s": circle_s}
	print("NOTE %s: max lag %.1f m, %.1f s over 14 m, %.1f s circling" % [tag, lag_max, bad_s, circle_s])


func settle(seconds: float, near: float) -> float:
	var t := 0.0
	while t < seconds and eddie.global_position.distance_to(player.global_position) > near:
		await process_frame
		t += 1.0 / 60.0
	return t


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	_backup[game.SAVE_PATH] = FileAccess.get_file_as_string(game.SAVE_PATH) if FileAccess.file_exists(game.SAVE_PATH) else null
	CS.prepare(game, 7)
	var ps: PackedScene = load("res://game/scenes/World.tscn")
	w = ps.instantiate()
	root.add_child(w)
	await frames(120)
	player = w.player
	eddie = w.eddie as VeilSurvivorBody
	player.controls_enabled = false
	eddie.visible = true
	fol = FOLLOW.new()
	w.add_child(fol)
	fol.setup(eddie, player)
	var start: Vector3 = _floor(Vector3(34.7, 0.3, -18.5))
	player.global_position = start + Vector3(0, 0.05, 0)
	eddie.place_at(start + Vector3(-2.4, 0, 0))
	fol.recover_behind(2.4)
	fol.start()
	await frames(60)
	# a long walkable route through the town (the world's own router)
	var far := _floor(Vector3(120.0, 0.3, -20.0))
	var route: Array = w.npc_route(w, start, far, null, true)
	if route.is_empty():
		route = [start, far]
	else:
		route.push_front(start)
	print("NOTE route points: %d" % route.size())
	await walk_player(route, 1.9, "walk")
	ok("walk_keeps_up", report["walk"]["lag_max"] < 9.0, "%.1f m" % report["walk"]["lag_max"])
	ok("walk_no_circling", report["walk"]["circle_s"] < 1.0, "%.1f s" % report["walk"]["circle_s"])
	await settle(8.0, 5.0)
	var back := route.duplicate()
	back.reverse()
	await walk_player(back, 5.0, "sprint_back")                    # sprint all the way back, doubling back past him
	ok("sprint_keeps_up", report["sprint_back"]["bad_s"] < 4.0, "%.1f s over 14 m" % report["sprint_back"]["bad_s"])
	ok("sprint_no_circling", report["sprint_back"]["circle_s"] < 1.5, "%.1f s" % report["sprint_back"]["circle_s"])
	var t1: float = await settle(20.0, 6.0)
	ok("catches_up_after_sprint", eddie.global_position.distance_to(player.global_position) <= 6.0, "%.1f s, %.1f m" % [t1, eddie.global_position.distance_to(player.global_position)])
	# a sudden jump of the player (a scene teleport, a ride) 40+ m away: he must arrive on his own
	player.global_position = _floor(far) + Vector3(0, 0.05, 0)
	var t2: float = await settle(35.0, 6.0)
	var lag2 := eddie.global_position.distance_to(player.global_position)
	ok("arrives_after_jump", lag2 <= 6.0, "%.1f s, %.1f m (recoveries %d)" % [t2, lag2, fol.recoveries])
	# harder: the player is put behind the supermarket (a walk round the building) with the recovery teleport off
	fol.allow_recover = false
	var till: Vector3 = _floor(Vector3(34.7, 0.3, -62.0))
	player.global_position = till + Vector3(0, 0.05, 0)
	var r0: int = fol.watchdog_routes
	var t3 := 0.0
	for k in 12:
		t3 += await settle(5.0, 6.0)
		print("NOTE t=%.0f eddie %s lag %.1f walking=%s route pts=%d jams=%d" % [t3, eddie.global_position.snappedf(0.1), eddie.global_position.distance_to(player.global_position), fol.anim.is_walking(), fol.last_route.size(), fol.anim.jams])
		if eddie.global_position.distance_to(player.global_position) <= 6.0:
			break
	var lag3 := eddie.global_position.distance_to(player.global_position)
	ok("walks_round_the_building_by_himself", lag3 <= 6.0, "%.1f s, %.1f m, routes %d" % [t3, lag3, fol.watchdog_routes - r0])
	fol.allow_recover = true
	ok("no_stuck_in_solid", eddie.is_clear(eddie.global_position), str(eddie.global_position.snappedf(0.1)))
	for p in _backup:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(_backup[p])
			f.close()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
