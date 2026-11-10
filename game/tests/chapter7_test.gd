extends SceneTree
## THE VEIL - Chapter 7 "A Trace of Noah" automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter7_test.gd
## Starts from the developer entry (game/chapters/setups/dev_chapter7.gd = Chapter 6 complete and slept). The player WALKS
## every route (physics), opens the real front doors both ways, reads the note in the inventory screen, and both
## of Marcus's choices are played; Marcus's follow is checked every frame for jumps and wall crossings.

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")

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
	create_timer(1500.0).timeout.connect(func():
		print("RESULT FAIL (watchdog: test did not finish)")
		quit(1))


const TO_DOORS := [Vector3(1.5, 0.2, 4.4), Vector3(1.5, 0.2, 1.8), Vector3(0.3, 0.2, 1.0)]
const OUT_DOORS := [Vector3(0.3, 0.2, -3.5)]
const TO_CAR := [Vector3(32.7, 0.2, -2.0), Vector3(-20.0, 0.2, 0.0), Vector3(-55.5, 0.2, -0.5)]
const TO_ROAD := [Vector3(-80.0, 0.2, 0.0), Vector3(-99.0, 0.2, 0.0)]
const HOME := [Vector3(-60.0, 0.2, -1.0), Vector3(0.0, 0.2, 1.5), Vector3(30.0, 0.2, 1.5), Vector3(32.7, 0.2, -2.0), Vector3(32.7, 0.2, -25.0)]
const INTO := [Vector3(0.3, 0.2, 1.2), Vector3(1.5, 0.2, 1.8), Vector3(1.5, 0.2, 4.6), Vector3(2.0, 0.2, 6.0)]


func read_note() -> bool:
	if not world.hud.inv_panel.visible:
		world.hud.toggle_inventory()
	await frames(5)
	var inv = world.hud.inv_panel
	var idx: int = inv._ids.find("noahs_note")
	if idx < 0:
		return false
	inv.select(idx)
	await frames(100)
	world.hud.toggle_inventory()
	await frames(5)
	return true


func _run() -> void:
	game = root.get_node("Game")
	ps = load("res://game/scenes/World.tscn")
	root.get_node("Dialogue").auto_confirm = true     # the "player" confirms each conversation line
	root.get_node("Dialogue").line_started.connect(func(_s, t, _d): said.append(t))
	DEV.prepare(game)
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	p4 = world.phase4
	c5 = p4.chapter5
	c6 = c5.chapter6
	c7 = c6.chapter7 if c6 else null
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	ok("c7_entry_after_c6_rest", c7 != null and game.has_flag("ch7_started") and game.current_step().get("id", "") == "c7_marcus",
		game.current_step().get("id", ""))
	ok("c7_title_card", await wait_until(func(): return world.hud.chapter_l.text.begins_with("CHAPTER 8  —  A TRACE OF NOAH"), 60 * 6), world.hud.chapter_l.text)
	ok("c7_marcus_at_notes", c7.marcus.get_parent() == world.market and c7.marcus.position.distance_to(c7.MARCUS_NOTES) < 0.3)
	ok("c7_doors_closed_no_prompt", c7.doors != null and c7.doors.prompt_text == "" and not c5._doors_open)
	# ---- scene 1-2
	ok("c7_marcus_reach", await aim(c7.its["npc_Marcus"], [-Z, Z, X, -X], world.market, 1.4))
	c7.its["npc_Marcus"].interact(world.player)
	await frames(40)
	var vc := root.get_viewport().get_camera_3d()
	ok("c7_talk_camera_locks", world.conversing and not world.player.controls_enabled and vc != null and vc.name == "TalkCam",
		"conversing=%s controls=%s cam=%s" % [world.conversing, world.player.controls_enabled, vc.name if vc else "-"])
	ok("c7_briefing", await wait_talk(func(): return game.has_flag("ch7_marcus_briefing_complete")) and game.current_step().get("id", "") == "c7_prepare"
		and said.has("Someone told me about a car near the old service road."))
	await reload()
	ok("c7_load_after_briefing", c7.its["npc_Marcus"].prompt_text == "" and c7.its["npc_Eddie"].prompt_text == "[E] Talk")
	ok("c7_eddie_reach", await aim(c7.its["npc_Eddie"], [Z, -Z, X, -X], world.market, 1.4))
	c7.its["npc_Eddie"].interact(world.player)
	ok("c7_eddie_warning", await wait_talk(func(): return game.has_flag("ch7_eddie_warning_complete"))
		and game.current_step().get("id", "") == "c7_leave" and c7.marcus_follow.active)
	ok("c7_eddie_stays", c7.eddie.get_parent() == world.market)
	await reload()
	ok("c7_load_marcus_following", c7.marcus_follow.active and world.find_children("Marcus", "", true, false).size() == 1)
	# ---- scene 3: the real front doors
	_eddie_prev = c7.marcus.global_position
	_watch = true
	ok("c7_walk_to_doors", await walk_route(TO_DOORS, world.market))
	ok("c7_doors_prompt", c7.doors.prompt_text == "[E] Open the Doors")
	ok("c7_doors_reach", await look(c7.doors))
	c7.doors.interact(world.player)
	await watch_frames(60)
	ok("c7_doors_open", c5._doors_open)
	ok("c7_leave", await walk_route(OUT_DOORS, world.market) and await wait_until(func(): return game.has_flag("ch7_departure_complete"), 60 * 4)
		and game.current_step().get("id", "") == "c7_vehicle")
	ok("c7_marker_vehicle", await wait_until(func(): return world.hud.marker_visible and world._beacons.has("c7"), 60))
	# ---- scene 4-5: the walk, the car
	ok("c7_walk_partway", await walk_world(TO_CAR.slice(0, 2)), str(world.player.global_position))
	ok("c7_walk_line_once", game.has_flag("ch7_walk_said") and said.count("Noah used to ride his bike around here.") == 1)
	ok("c7_doors_closed_behind", not c5._doors_open)
	ok("c7_not_reached_early", not game.has_flag("ch7_vehicle_reached") and c7.its["backpack"].prompt_text == "")
	await reload()
	ok("c7_load_travel", game.current_step().get("id", "") == "c7_vehicle" and c7.marcus_follow.active and said.count("Noah used to ride his bike around here.") == 1)
	_eddie_prev = c7.marcus.global_position
	# (QA-004) the Skitters are already at the car, moving about it, before the player gets near
	ok("c7_walk_short_of_car", await walk_world([Vector3(-30.0, 0.2, 0.0)]), str(world.player.global_position))
	ok("c7_skitters_before_arrival", c7.skitters.size() == 2 and not game.has_flag("ch7_skitters_seen")
		and c7.skitters.all(func(sk): return sk.global_position.distance_to(c7.CAR_POS) < 4.5))
	var sk0: Vector3 = c7.skitters[0].global_position
	await watch_frames(60 * 6)
	ok("c7_skitters_patrol", c7.skitters[0].global_position.distance_to(sk0) > 0.5 or c7.skitters[1].global_position.distance_to(c7.SKITTER_SPOTS[1]) > 0.5)
	# (QA-008) the first sight: a look at the car, the talk, then the marker to the alarm (not the backpack)
	await walk_world([Vector3(-36.0, 0.2, 0.0)])
	ok("c7_intro_plays", await wait_until(func(): return game.has_flag("ch7_skitters_seen") and not world.player.controls_enabled, 60 * 3))
	ok("c7_intro_done", await wait_talk(func(): return world.player.controls_enabled and not c7._busy.get("intro", false), 40.0)
		and c7.qa_report.get("intro_facing", 0.0) > 0.95 and said.has("Something loud. Away from the car.") and world.player.camera.fov > 60.0,
		str(c7.qa_report))
	ok("c7_vehicle_reached", game.has_flag("ch7_vehicle_reached") and game.current_step().get("id", "") == "c7_search")
	ok("c7_marker_alarm", await wait_until(func(): return world.hud._mk_name == "CAR ALARM", 30))
	ok("c7_backpack_not_auto", not game.has_flag("ch7_backpack_found") and not game.has_item("noahs_backpack"))
	ok("c7_skitters_at_car", c7.skitters.size() == 2 and c7.its["backpack"].prompt_text == "" and c7.its["alarm"].prompt_text != "")
	# (QA-006) a lunge: turns, Attack_Lunge, the bite lands at the contact moment, not at once
	var hp0: float = world.player.health
	c7._lunge(c7.skitters[0])
	await watch_frames(2)
	var hp_now: float = world.player.health
	ok("c7_lunge_anim", c7.qa_report.get("lunge_anim", false) and hp_now == hp0)
	await watch_frames(90)
	world.player.health = hp0
	await walk_world([c7.ALARM_POS + Vector3(0.0, 0.05, -2.6)])          # walked back (no teleport: Marcus follows the trail)
	ok("c7_alarm_reach", await look(c7.its["alarm"]))
	c7.its["alarm"].interact(world.player)
	ok("c7_alarm_not_instant", not game.has_flag("ch7_skitters_gone") and c7.its["backpack"].prompt_text == "")
	ok("c7_skitters_drawn_off", await wait_until(func(): return game.has_flag("ch7_skitters_gone"), 60 * 8) and c7.its["alarm"].prompt_text == ""
		and c7.skitters.any(func(sk): return sk.global_position.distance_to(c7.ALARM_POS) < 8.0))
	ok("c7_skitters_leave_unseen", await wait_until(func(): return c7.skitters.is_empty(), 60 * 20), str(c7.skitters.size()))
	ok("c7_backpack_prompt", c7.its["backpack"].prompt_text == "E - EXAMINE BACKPACK")
	# walk up to the open rear door (the marker points at the backpack)
	var bp: Vector3 = c7.its["backpack"].global_position
	var out: Vector3 = (bp - c7.CAR_POS) * Vector3(1, 0, 1)
	ok("c7_walk_to_door", await walk_world([bp + out.normalized() * 1.1 * Vector3(1, 0, 1) + Vector3(0, -bp.y + 0.2, 0)]))
	ok("c7_backpack_reach", await look(c7.its["backpack"]), str(world.player.global_position))
	c7.its["backpack"].interact(world.player)
	ok("c7_backpack_found", await wait_talk(func(): return game.has_flag("ch7_backpack_found"), 60.0)
		and game.has_item("noahs_backpack") and game.has_item("noahs_note") and said.has("He complained about the color for a week.")
		and game.current_step().get("id", "") == "c7_examine")
	ok("c7_key_item", game.item_info("noahs_backpack").get("category", "") == "key")
	await frames(120)
	ok("c7_note_not_auto", not game.has_flag("noah_clue_backpack"))
	await reload()
	ok("c7_load_after_bag", game.inventory.count("noahs_backpack") == 1 and not c7.backpack.visible and c7.its["backpack"].collision_layer == 0)
	_eddie_prev = c7.marcus.global_position
	# ---- scene 6: read the note in the inventory screen
	ok("c7_read_note", await read_note())
	ok("c7_note_clue", await wait_talk(func(): return game.has_flag("noah_clue_backpack"), 60.0) and said.has("After all of this started, he was alive.")
		and game.current_step().get("id", "") == "c7_road")
	await reload()
	ok("c7_load_clue", game.has_flag("noah_clue_backpack") and game.current_step().get("id", "") == "c7_road")
	_eddie_prev = c7.marcus.global_position
	# ---- scene 7: the old service road (only once the player is there)
	ok("c7_walk_to_road", await walk_world(TO_ROAD.slice(0, 1)))
	ok("c7_road_not_early", not game.has_flag("ch7_road_reached"))
	await walk_world(TO_ROAD.slice(1))
	ok("c7_road_choice_offered", await wait_talk(func(): return p4.choice.is_open(), 60.0) and game.has_flag("ch7_road_reached"))
	var road_snap := snapshot()
	p4.choice.pick(0)
	ok("c7_choice_trust", await wait_talk(func(): return game.has_flag("ch7_road_investigation_complete"), 40.0)
		and game.has_flag("marcus_trust_search") and not game.has_flag("marcus_cautious_search")
		and game.current_step().get("id", "") == "c7_return")
	# ---- scene 8: home through the doors
	ok("c7_walk_home", await walk_world(HOME), str(world.player.global_position))
	ok("c7_doors_closed_on_return", not c5._doors_open and c7.doors.prompt_text == "[E] Open the Doors")
	await walk_route([Vector3(0.3, 0.2, -1.6)], world.market)
	ok("c7_doors_reach_outside", await look(c7.doors))
	c7.doors.interact(world.player)
	await watch_frames(60)
	ok("c7_walk_in", await walk_route(INTO, world.market))
	ok("c7_returned", await wait_until(func(): return game.has_flag("ch7_returned_to_supermarket"), 60 * 20)
		and game.current_step().get("id", "") == "c7_report")
	_watch = false
	ok("c7_marcus_no_teleport", eddie_max_step < 0.2, "max %.3f" % eddie_max_step)
	ok("c7_marcus_no_wall_crossing", eddie_wall_hits == 0, "%d" % eddie_wall_hits)
	ok("c7_marcus_lag", eddie_max_lag < 16.0, "%.1f" % eddie_max_lag)
	await frames(90)
	ok("c7_doors_shut_home", not c5._doors_open)
	# ---- scene 9: report to Eddie
	ok("c7_eddie_reach_back", await aim(c7.its["npc_Eddie"], [Z, -Z, X, -X], world.market, 1.4))
	c7.its["npc_Eddie"].interact(world.player)
	ok("c7_complete", await wait_talk(func(): return game.has_flag("chapter_7_complete") and game.has_flag("ch7_report_complete"), 120.0)
		and said.has("One thing at a time."))
	ok("c7_complete_card", world.hud.chapter_l.text.begins_with("CHAPTER 8 COMPLETE"), world.hud.chapter_l.text)
	ok("c7_no_chapter8", not game.has_flag("ch8_started") and game.current_step().get("id", "") == "c7_complete")
	ok("c7_marcus_alive", c7.marcus != null and is_instance_valid(c7.marcus) and c7.marcus.visible)
	await reload()
	ok("c7_load_complete", game.has_flag("chapter_7_complete") and game.has_flag("noah_clue_backpack") and game.has_flag("marcus_trust_search")
		and world.find_children("Marcus", "", true, false).size() == 1 and p4.rest.interactable.prompt_text == "[E] Sleep"
		and game.inventory.count("noahs_backpack") == 1)
	# the survival rule: enough food and water for everyone tonight (deposited supplies)
	game.world_state["shelter_stock"] = {"food": 12, "water": 12, "medical": int(game.shelter_stock().get("medical", 0)), "batteries": 0}
	p4.rest.interactable.interact(world.player)
	ok("c7_rest_confirm", await wait_until(func(): return p4.choice.is_open(), 60))
	p4.choice.pick(0)
	ok("c7_rest_starts_ch8", await wait_until(func(): return game.has_flag("ch7_rested"), 60 * 8) and game.has_flag("ch8_started")
		and c7.chapter8 != null and not game.has_flag("ch9_started"))
	# ---- the other choice, and a load between reaching the road and choosing
	await restore(road_snap)
	ok("c7_road_reoffered_after_load", await wait_talk(func(): return p4.choice.is_open(), 40.0))
	p4.choice.pick(1)
	ok("c7_choice_cautious", await wait_talk(func(): return game.has_flag("ch7_road_investigation_complete"), 40.0)
		and game.has_flag("marcus_cautious_search") and not game.has_flag("marcus_trust_search"))
	await reload()
	ok("c7_choice_persists", game.has_flag("marcus_cautious_search") and not game.has_flag("marcus_trust_search")
		and c7.st()["marcus_choice"] == "cautious" and c7.marcus_follow.active)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
