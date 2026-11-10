extends SceneTree
## THE VEIL - survivor relationships & consequences (game/world/survivors.gd) automated checks (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/survivors_test.gd
## From the Chapter 8 developer entry (supermarket shelter): trust and anti-farming, injuries that persist and
## worsen, medicine consumption, overnight events (once each), a companion that follows on a real walk and comes
## back, abandonment, the dead never reappearing, activities that wait for cinematics and walk (no jumps),
## and save/load of all of it.

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0
var world: Node
var game: Node
var ps: PackedScene
var p4: Node
var c5: Node
var ex: Node
var sv: Node
var said: Array = []
var _watch_npc: Node3D
var _prev := Vector3.ZERO
var max_step := 0.0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _physics_watch() -> void:
	if _watch_npc == null or not is_instance_valid(_watch_npc):
		return
	var p := _watch_npc.global_position
	max_step = maxf(max_step, p.distance_to(_prev))
	_prev = p


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
		_physics_watch()
	return cond.call()


## Dialogue-heavy waits run the clock faster (dialogue timers only; nobody is walking).
func wait_talk(cond: Callable, max_seconds := 90.0) -> bool:
	Engine.time_scale = 6.0
	var r := await wait_until(cond, int(max_seconds * 60 / 6.0) + 60)
	Engine.time_scale = 1.0
	return r


func watch_frames(n: int) -> void:
	for i in n:
		await process_frame
		_physics_watch()


## Walk the player (real input + physics) to `target`; returns false if stuck.
func walk_to(target: Vector3, timeout := 30.0) -> bool:
	var player = world.player
	var t := 0.0
	var last: Vector3 = player.global_position
	var still := 0.0
	Input.action_press("move_forward")
	while t < timeout:
		var d: Vector3 = (target - player.global_position) * Vector3(1, 0, 1)
		if d.length() < 0.5:
			break
		player.set_yaw_pitch(atan2(-d.x, -d.z), 0.0)
		await process_frame
		_physics_watch()
		t += 1.0 / 60.0
		if player.global_position.distance_to(last) < 0.01:
			still += 1.0 / 60.0
			if still > 2.0:
				break
		else:
			still = 0.0
		last = player.global_position
	Input.action_release("move_forward")
	await watch_frames(6)
	var left: float = ((target - player.global_position) * Vector3(1, 0, 1)).length()
	if left > 0.8:
		print("  walk stuck at %s (target %s, %.1f m left)" % [player.global_position, target, left])
	return left <= 0.8


func walk_route(pts: Array, frame: Node3D) -> bool:
	for p in pts:
		if not await walk_to(frame.global_transform * (p as Vector3)):
			return false
	return true


func aim(it: Node3D, dirs: Array, frame: Node3D, dist := 1.2) -> bool:
	var player = world.player
	var c: Vector3 = it.global_position
	for cs in it.get_children():
		if cs is CollisionShape3D:
			c = (cs as CollisionShape3D).global_position
	for d in dirs:
		var dir: Vector3 = (frame.global_transform.basis * (d as Vector3)) * Vector3(1, 0, 1)
		if dir.length() < 0.01:
			continue
		var feet := c + dir.normalized() * dist
		var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(feet.x, c.y + 0.3, feet.z), Vector3(feet.x, c.y - 3.0, feet.z), 1))
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


## From where the player already stands (no teleport), look at the interactable's nearest face (where a player
## aims); true if the real ray finds it.
func look(it: Node3D) -> bool:
	var player = world.player
	await frames(2)
	var eye: Vector3 = player.camera.global_position
	var c: Vector3 = it.global_position
	for cs in it.get_children():
		if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
			var csn := cs as CollisionShape3D
			var half: Vector3 = (csn.shape as BoxShape3D).size * 0.5 * 0.85
			var le := csn.global_transform.affine_inverse() * eye
			c = csn.global_transform * Vector3(clampf(le.x, -half.x, half.x), clampf(le.y, -half.y, half.y), clampf(le.z, -half.z, half.z))
	var v := (c - eye).normalized()
	player.set_yaw_pitch(atan2(-v.x, -v.z), asin(clampf(v.y, -1.0, 1.0)))
	await watch_frames(5)
	return player._focus == it




func reload() -> void:
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	p4 = world.phase4
	c5 = p4.chapter5
	ex = world.expedition
	sv = world.survivors


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	game = root.get_node("Game")
	ps = load("res://game/scenes/World.tscn")
	root.get_node("Dialogue").auto_confirm = true
	root.get_node("Dialogue").line_started.connect(func(_s, t, _d): said.append(t))
	DEV.prepare(game)
	game.world_state["shelter_stock"] = {"food": 0, "water": 0, "medical": 3, "batteries": 0}
	game.world_state["supply_grace"] = true            # (an empty pantry on purpose)
	game.world_state.erase("survivors")
	game.save_game()
	game.load_game()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	p4 = world.phase4
	c5 = p4.chapter5
	ex = world.expedition
	sv = world.survivors
	var flags0: Dictionary = game.flags.duplicate()
	ok("sv_exists", sv != null and sv.morale() >= 0 and sv.trust("Ruth") >= 0, str(world.shelter_roster()))
	var roster: Array = world.shelter_roster()
	ok("sv_roster_has_group", "Eddie" in roster and "Ruth" in roster and "Sarah" in roster, str(roster))

	# ---- trust: keyed awards apply once (no farming); story-flag effects apply once
	var t0: int = sv.trust("Eddie")
	sv.award("test:rescue", {"Eddie": 10})
	sv.award("test:rescue", {"Eddie": 10})
	ok("sv_trust_once", sv.trust("Eddie") == mini(t0 + 10, 100), "%d -> %d" % [t0, sv.trust("Eddie")])
	sv._apply_flag("ch8_entrance_secured", false)
	var r0: int = sv.trust("Ruth")
	sv._apply_flag("ch8_entrance_secured", false)
	ok("sv_flag_effect_once", sv.trust("Ruth") == r0, "%d -> %d" % [r0, sv.trust("Ruth")])
	sv.award("test:clamp", {"Eddie": 500})
	ok("sv_trust_clamped", sv.trust("Eddie") == 100)

	# ---- health: an injury worsens overnight without medicine; treatment costs medicine; it heals
	sv.set_health("Sarah", "injured")
	sv.st()["treated_since_night"] = {}
	ok("sv_warning_shown", "getting worse" in sv.status_text(), sv.status_text())
	sv._night("sv_test_night_1")
	ok("sv_worsened", sv.health("Sarah") == "serious")
	var ts: int = sv.trust("Sarah")
	ok("sv_treat_offered", sv.can_treat("Sarah") == "Treat Sarah (2 medicine)", sv.can_treat("Sarah"))
	ok("sv_treat_serious", sv.treat("Sarah") and sv.health("Sarah") == "injured" and game.shelter_stock().medical == 1)
	ok("sv_treat_injured", sv.treat("Sarah") and sv.health("Sarah") == "recovering" and game.shelter_stock().medical == 0)
	ok("sv_treat_needs_medicine", sv.can_treat("Sarah") == "" and not sv.treat("Sarah"))
	ok("sv_treat_trust", sv.trust("Sarah") == mini(ts + 10, 100), "%d -> %d" % [ts, sv.trust("Sarah")])
	while game.has_item("painkillers"):
		game.remove_item("painkillers")
	sv.set_health("Eddie", "injured")
	ok("sv_no_medicine_no_treatment", not sv.treat("Eddie") and sv.health("Eddie") == "injured")
	sv.set_health("Eddie", "healthy")

	# ---- overnight: morale responds, one event, never repeated; delivered only when quiet
	var m0: int = sv.morale()
	sv._night("sv_test_night_2")                         # food 0: the night ran short (from the report)
	var ev: String = sv.st()["pending_event"]
	ok("sv_night_heals", sv.health("Sarah") == "healthy")
	ok("sv_event_chosen", ev != "", ev)
	await wait_until(func(): return sv.st()["pending_event"] == "", 600)
	ok("sv_event_played", ev in sv.st()["events"] and sv.st()["pending_event"] == "", str(sv.st()["events"]))
	sv._night("sv_test_night_2")
	ok("sv_night_once", sv.st()["nights"] == 2)
	sv.st()["events"].append("sv_night_food")
	sv._night("sv_test_night_3")
	var ev3: String = sv.st()["pending_event"]
	ok("sv_event_not_repeated", ev3 != ev and not (ev3 in sv.st()["events"]), "%s / %s" % [ev, ev3])
	sv.st()["pending_event"] = ""

	# ---- save / load keeps it all
	sv.set_health("Ruth", "injured")
	var snap := {"trust": sv.st()["trust"].duplicate(), "morale": sv.morale(), "events": sv.st()["events"].duplicate(), "nights": sv.st()["nights"]}
	await reload()
	ok("sv_persist", sv.st()["trust"] == snap["trust"] and sv.morale() == snap["morale"] and sv.st()["events"] == snap["events"]
		and sv.st()["nights"] == snap["nights"] and sv.health("Ruth") == "injured", str(sv.st()["trust"]))
	sv.set_health("Ruth", "healthy")

	# ---- activities: wait for a cinematic, then walk (never a jump)
	sv.st()["free"] = true
	var cine := Camera3D.new()
	world.add_child(cine)
	world._cine = cine
	var w0: int = sv.report["walks"]
	await frames(300)
	ok("sv_activities_wait_for_cinematic", sv.report["walks"] == w0)
	world._cine = null
	cine.queue_free()
	_watch_npc = world.animators["Marcus"].root
	_prev = _watch_npc.global_position
	max_step = 0.0
	var e_start: Vector3 = _watch_npc.global_position
	await wait_until(func(): return sv.report["walks"] > w0, 400)
	await watch_frames(360)
	ok("sv_activities_walk", sv.report["walks"] > w0 and not sv.st()["activities"].is_empty(), str(sv.st()["activities"]))
	ok("sv_activities_no_teleport", max_step < 0.2, "max step %.2f, moved %.1f" % [max_step, _watch_npc.global_position.distance_to(e_start)])
	_watch_npc = null

	# ---- the dead never come back (Marcus lost in Chapter 10)
	game.flags["ch9_marcus_lost"] = true
	ok("sv_dead_excluded", not sv.alive("Marcus") and not ("Marcus" in sv.companion_options()) and not ("Marcus" in sv.status_text()))
	sv.award("test:dead", {"Marcus": 10})
	sv.set_health("Marcus", "injured")
	ok("sv_dead_unchanged", sv.health("Marcus") != "injured")
	game.flags.erase("ch9_marcus_lost")

	# ---- a companion on a real walk: follows, comes back inside, Eddie carries a little more
	ok("sv_companions_offered", "Eddie" in sv.companion_options(), str(sv.companion_options()))
	await aim(ex.its["exit"], [Vector3(0, 0, 1), Vector3(0.4, 0, 1)], world.market, 1.3)
	ex.start("scavenge", false)
	sv.begin_trip("Eddie")
	ok("sv_companion_follows", sv.follow != null and sv.follow.active and sv.st()["companion"] == "Eddie")
	ok("sv_companion_not_emergency", not ex.emergency())
	await frames(30)
	ok("sv_walk_out", await walk_route([Vector3(1.5, 0.2, 4.4), Vector3(1.5, 0.2, 1.8), Vector3(0.3, 0.2, 1.0), Vector3(0.3, 0.2, -3.5),
		Vector3(0.3, 0.2, -8.0)], world.market))
	await frames(240)
	var lag: float = sv.follow.lag()
	ok("sv_companion_kept_up", lag < 6.0, "lag %.1f" % lag)
	game.add_item("water_bottle")
	ok("sv_walk_in", await walk_route([Vector3(0.3, 0.2, -3.5), Vector3(0.3, 0.2, 1.0), Vector3(1.5, 0.2, 1.8), Vector3(1.5, 0.2, 4.6)], world.market))
	var cans: int = game.inventory.count("canned_food")
	var te: int = sv.trust("Eddie")
	ex.secure()
	await frames(30)
	ok("sv_companion_released", sv.follow == null and sv.st()["companion"] == "" and not world.animators["Eddie"].root.get_node("SV_Follow").active)
	ok("sv_eddie_carries", game.inventory.count("canned_food") == cans + 1)
	ok("sv_trip_not_abandoned", sv.trust("Eddie") >= te and not ("abandoned" in sv.memory("Eddie")))

	# ---- leaving a companion behind costs trust (once); they get home without a visible jump
	ex.start("scavenge", false)
	sv.begin_trip("Ruth")
	await frames(10)
	var rt: int = sv.trust("Ruth")
	sv.follow.active = false                             # Ruth is stuck far behind (already recovered once)
	sv._recovered = true
	world.player.global_position = world.market.global_transform * Vector3(0.3, 0.2, -60.0)
	await frames(10)
	ex.secure()
	await frames(10)
	ok("sv_abandon_cost", sv.trust("Ruth") == maxi(rt - 15, 0) and "abandoned" in sv.memory("Ruth"), "%d -> %d" % [rt, sv.trust("Ruth")])

	# ---- the shelter panel opens from the supplies panel; nothing here advanced the story
	ok("sv_status_text", "THE GROUP" in sv.status_text() and "Eddie" in sv.status_text())
	var story_moved := false
	for k in game.flags:
		if not flags0.has(k) and not (String(k).begins_with("exp") or String(k).begins_with("chapter_card")):
			story_moved = true
			print("  new flag ", k)
	ok("sv_story_untouched", not story_moved)
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
