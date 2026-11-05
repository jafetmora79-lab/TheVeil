extends SceneTree
## THE VEIL - survival expansion (game/world/expedition.gd) automated checks (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/expedition_test.gd
## From the Chapter 8 developer entry (displayed "A Trace of Noah": the supermarket is the shelter, no story trip
## under way): the exit menu, a scavenging trip on foot, the danger levels and warnings, dynamic spawns (outdoors,
## out of view, capped), a one-time cache, save/load mid-trip, the return and the secured doors, the sleep supply
## rule, the car repair, and that none of it advances the story.
## THE VEIL - Chapter 7 "A Trace of Noah" automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter7_test.gd
## Starts from the developer entry (game/tools/dev_chapter7.gd = Chapter 6 complete and slept). The player WALKS
## every route (physics), opens the real front doors both ways, reads the note in the inventory screen, and both
## of Marcus's choices are played; Marcus's follow is checked every frame for jumps and wall crossings.

const DEV := preload("res://game/tools/dev_chapter7.gd")
var ex: Node

var fails := 0
var world: Node
var game: Node
var ps: PackedScene
var c5: Node
var c6: Node
var c7: Node
var p4: Node
var said: Array = []                 # every dialogue line shown (text)
var eddie_max_step := 0.0
var eddie_max_lag := 0.0
var eddie_wall_hits := 0
var _eddie_prev := Vector3.ZERO
var _watch := false


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
		_physics_watch()                          # the follow check keeps sampling every frame while waiting
	return cond.call()


## Dialogue-heavy waits run the clock faster (dialogue timers only; nobody is walking).
func wait_talk(cond: Callable, max_seconds := 90.0) -> bool:
	Engine.time_scale = 6.0
	var r := await wait_until(cond, int(max_seconds * 60 / 6.0) + 60)
	Engine.time_scale = 1.0
	return r


var _trace := false
var _trace_t := 0


func _physics_watch() -> void:
	if false:
		_trace_t += 1
		if _trace_t % 60 == 0:
			var hv: bool = c6.hound != null and is_instance_valid(c6.hound)
			print("  trace player %s hound %s %s aw %.2f" % [world.player.global_position.snapped(Vector3.ONE * 0.1),
				c6.hound.global_position.snapped(Vector3.ONE * 0.1) if hv else "-", c6.hound_ai.state if hv else "-",
				c6.hound_ai.awareness if hv else 0.0])
	# called every frame while walking: Eddie must never jump or cross a wall between two frames
	if not _watch or c5 == null:
		return
	var e: Vector3 = (c7.marcus if c7 else c5.eddie).global_position
	var step := e.distance_to(_eddie_prev)
	step /= maxf(Engine.time_scale, 1.0)            # per real 1/60 s, so the 6x dialogue clock is not a "jump"
	if step > 0.2 and eddie_max_step <= 0.2:
		print("  eddie jump %.2f m: %s -> %s (player %s)" % [step, _eddie_prev, e, world.player.global_position])
	eddie_max_step = maxf(eddie_max_step, step)
	if step > 0.02:
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(_eddie_prev + Vector3(0, 0.5, 0), e + Vector3(0, 0.5, 0), 1)
		var wh := space.intersect_ray(q)
		if wh:
			eddie_wall_hits += 1
			print("  eddie wall crossing at %s (%s) eddie %s -> %s doors_open=%s" % [wh["position"], (wh["collider"] as Node).name,
				_eddie_prev, e, c5._doors_open])
	eddie_max_lag = maxf(eddie_max_lag, e.distance_to(world.player.global_position))
	_eddie_prev = e


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


## The loot sits inside its container: within the container piece's footprint and below its top.
func _inside(item: Interactable, container: Interactable) -> bool:
	var piece := container.get_parent().get_parent() as Node3D
	var a: AABB = Interactable.aabb_of(piece).grow(0.02)
	var p := piece.to_local(item.target.global_position + Vector3(0, 0.03, 0))
	if container.kind == "slide":
		p = piece.to_local(item.target.global_position + Vector3(0, 0.03, 0))
	return a.has_point(p)


func walk_world(pts: Array) -> bool:
	for p in pts:
		if not await walk_to(p as Vector3):
			return false
	return true


func reload() -> void:
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(40)
	c5 = world.phase4.chapter5 if world.phase4 else null
	p4 = world.phase4
	c6 = c5.chapter6 if c5 else null
	c7 = c6.chapter7 if c6 else null





func snapshot() -> Dictionary:
	return {"flags": game.flags.duplicate(true), "ws": game.world_state.duplicate(true), "inv": game.inventory.duplicate(),
		"ps": game.player_state.duplicate(true)}


func restore(snap: Dictionary) -> void:
	world.free()
	game.flags = snap["flags"].duplicate(true)
	game.world_state = snap["ws"].duplicate(true)
	game.inventory = snap["inv"].duplicate()
	game.player_state = snap["ps"].duplicate(true)
	game.save_game()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(40)
	p4 = world.phase4
	c5 = p4.chapter5
	c6 = c5.chapter6
	c7 = c6.chapter7



func _initialize() -> void:
	_run.call_deferred()
	create_timer(1200.0).timeout.connect(func():
		print("RESULT FAIL (watchdog: test did not finish)")
		quit(1))


func story_flags() -> Dictionary:
	var out := {}
	for k in game.flags:
		if String(k).begins_with("ch7_") or String(k).begins_with("ch8_") or (String(k).begins_with("chapter_") and not String(k).begins_with("chapter_card")):
			out[k] = game.flags[k]
	return out


func _run() -> void:
	game = root.get_node("Game")
	ps = load("res://game/scenes/World.tscn")
	root.get_node("Dialogue").auto_confirm = true
	root.get_node("Dialogue").line_started.connect(func(_s, t, _d): said.append(t))
	DEV.prepare(game)
	if not "car_keys" in game.inventory:
		game.inventory.append("car_keys")                # the protagonist's own keys (Chapter 1)
	game.flags["fridge_checked"] = true
	game.world_state["shelter_stock"] = {"food": 0, "water": 0, "medical": 0, "batteries": 0}
	game.save_game()
	game.load_game()
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	p4 = world.phase4
	c5 = p4.chapter5
	c6 = c5.chapter6
	c7 = c6.chapter7
	ex = world.expedition
	var story0 := story_flags()
	var step0: String = game.current_step().get("id", "")
	ok("exp_controller", ex != null and ex.shelter() == "supermarket" and not ex.active() and ex.can_scavenge())
	ok("exp_exit_prompt", ex.its["exit"].prompt_text == "[E] Plan a Trip")

	# ---- the exit menu: Story / Scavenge (no car yet) / Stay
	ok("exp_exit_reach", await aim(ex.its["exit"], [Vector3(0, 0, 1), Vector3(0.4, 0, 1)], world.market, 1.3))
	ex.its["exit"].interact(world.player)
	ok("exp_menu_opens", await wait_until(func(): return p4.choice.is_open(), 60))
	var labels: Array = []
	for b in p4.choice._box.get_children():
		if b is Button:
			labels.append(String((b as Button).text).get_slice(".  ", 1) if String((b as Button).text).contains(".  ") else (b as Button).text)
	ok("exp_menu_options", labels.size() == 3 and String(labels[0]).begins_with("Continue Story") and labels[1] == "Scavenge for Supplies"
		and labels[2] == "Stay Inside", str(labels))
	p4.choice.pick(1)
	await frames(5)
	if p4.choice.is_open():
		p4.choice.pick(0)                                # survivors: "WHO COMES ALONG?" -> Go alone
	ok("exp_started", await wait_until(func(): return ex.active(), 60) and ex.st()["type"] == "scavenge" and c5._doors_open
		and ex.st()["shelter"] == "supermarket")
	ex.start("scavenge", false)                          # a second start while one is running: ignored
	await frames(5)
	ok("exp_single_instance", ex.st()["trips"] == 1 and ex.active() and ex.its["exit"].prompt_text == "[E] Secure the Doors")

	# ---- outside: the clock runs only out there
	ok("exp_walk_out", await walk_route([Vector3(1.5, 0.2, 4.4), Vector3(1.5, 0.2, 1.8), Vector3(0.3, 0.2, 1.0), Vector3(0.3, 0.2, -3.5),
		Vector3(0.3, 0.2, -8.0)], world.market), str(world.market.to_local(world.player.global_position)))
	var e0: float = ex.st()["elapsed"]
	await frames(120)
	ok("exp_clock_outside", ex.st()["elapsed"] > e0 + 1.5 and not ex.in_store(), "%.1f -> %.1f" % [e0, ex.st()["elapsed"]])
	world.hud.set_paused(true)
	var e1: float = ex.st()["elapsed"]
	await frames(60)
	ok("exp_clock_pauses_in_menu", absf(ex.st()["elapsed"] - e1) < 0.01)
	world.hud.set_paused(false)

	# ---- a one-time cache (never refilled)
	var cache: Interactable = ex.its["exp/cache_lot_food"]
	var food0: int = game.inventory.count("canned_food")
	ok("exp_cache_reach", await aim(cache, [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)], world.market, 0.9),
		str(cache.global_position))
	cache.interact(world.player)
	await frames(5)
	cache.interact(world.player)
	await frames(5)
	ok("exp_cache_once", game.inventory.count("canned_food") == food0 + 1 and cache.taken)

	# ---- danger levels (time fast-forwarded) and warnings; nobody is following, so the protagonist's own lines
	for lv in [1, 2, 3]:
		ex.st()["elapsed"] = float(ex.cfg["danger_thresholds_s"][lv - 1]) - 0.5
		ex.set("_warn_t", 0.0)
		await frames(60)
		ok("exp_level_%d" % lv, ex.level() == lv, "level %d" % ex.level())
	ok("exp_warnings", await wait_until(func(): return said.has("I've been out too long. I need to get back."), 60 * 12)
		and said.has("Something's out there. Moving.") and ex.report["warnings"] >= 2, str(ex.report))

	# ---- dynamic encounters: out of view, outdoors, a fair distance off, capped
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var spawned_ok := true
	for i in 6:
		var n0: int = ex.creatures.size()
		ex.encounter(3)
		await frames(2)
		if ex.creatures.size() > n0:
			var c: Dictionary = ex.creatures[ex.creatures.size() - 1]
			var at: Vector3 = (c["node"] as Node3D).global_position
			if at.distance_to(world.player.global_position) < 20.0 or c5._in_store(world.market.to_local(at), 0.0):
				spawned_ok = false
	ok("exp_spawns_fair", spawned_ok and ex.report["spawned"] >= 1, str(ex.report))
	ok("exp_spawn_cap", ex.creatures.size() <= int(ex.cfg["max_dynamic_creatures"]), "%d active" % ex.creatures.size())

	# ---- save / load mid-trip: the trip goes on, nothing duplicated
	var el: float = ex.st()["elapsed"]
	await reload()
	ex = world.expedition
	ok("exp_load_mid_trip", ex.active() and absf(ex.st()["elapsed"] - el) < 1.0 and ex.creatures.is_empty()
		and game.inventory.count("canned_food") == food0 + 1 and ex.its["exp/cache_lot_food"].taken)

	# ---- back inside: secure the doors; the trip ends with a summary; the story did not move
	if not c5._doors_open:
		ok("exp_outside_reach", await aim(ex.its["outside"], [Vector3(0, 0, -1)], world.market, 1.0))
		ex.its["outside"].interact(world.player)
		await frames(40)
	ok("exp_walk_in", await walk_route([Vector3(0.3, 0.2, -3.5), Vector3(0.3, 0.2, 1.0), Vector3(1.5, 0.2, 1.8), Vector3(1.5, 0.2, 4.6)], world.market),
		str(world.market.to_local(world.player.global_position)))
	ok("exp_secure_reach", ex.its["exit"].prompt_text == "[E] Secure the Doors" and await aim(ex.its["exit"], [Vector3(0, 0, 1), Vector3(0.4, 0, 1)], world.market, 1.3))
	ex.its["exit"].interact(world.player)
	await frames(10)
	ok("exp_secured", not ex.active() and ex.st()["returned"] and not c5._doors_open and ex.st()["collected"].get("canned_food", 0) == 1,
		str(ex.st()["collected"]))
	ok("exp_story_untouched", story_flags() == story0 and game.current_step().get("id", "") == step0 and game.chapter_number() == 8)

	# ---- sleep: one food and one water per person (the protagonist too)
	var need: Dictionary = ex.supply_need()
	ok("exp_sleep_blocked", ex.sleep_gate() != "" and need["need"] == world.shelter_roster().size() + 1, ex.sleep_gate())
	game.world_state["shelter_stock"] = {"food": need["need"], "water": need["need"], "medical": 0, "batteries": 0}
	ok("exp_sleep_allowed", ex.sleep_gate() == "")

	# ---- the car: inspect, find the parts, repair once, drive
	game.world_state["shelter_stock"] = {"food": 0, "water": 0, "medical": 0, "batteries": 0}
	world.enter_car()
	await frames(5)
	ok("exp_car_found", game.has_flag("vehicle_found") and not world.in_car and said.has("This thing might actually run."))
	for k in ["car_battery", "fuel_can", "car_fuse"]:
		var it: Interactable = ex.its["exp/part_" + k]
		ok("exp_part_reach_" + k, await aim(it, [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)], world.market, 0.9),
			str(it.global_position))
		it.interact(world.player)
		await frames(5)
	ok("exp_parts", game.has_item("car_battery") and game.has_item("fuel_can") and game.has_item("car_fuse"))
	world.enter_car()
	ok("exp_repaired", await wait_until(func(): return game.has_flag("vehicle_repaired") and said.has("It's running. We've got wheels again."), 60 * 6)
		and not game.has_item("car_battery") and not game.has_item("fuel_can") and not game.has_item("car_fuse"))
	await frames(10)
	world.enter_car()
	ok("exp_drive", await wait_until(func(): return world.in_car, 60 * 2))
	world.exit_car()
	await wait_until(func(): return not world.in_car, 60 * 3)
	await reload()
	ex = world.expedition
	ok("exp_car_persists", game.has_flag("vehicle_repaired") and game.inventory.count("car_battery") == 0)
	ok("exp_menu_car", ex.can_scavenge())
	ok("exp_story_still_untouched", story_flags() == story0 and game.chapter_number() == 8)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
