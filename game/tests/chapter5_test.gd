extends SceneTree
## THE VEIL - Chapter 5 "The First Search" automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter5_test.gd
## Starts from the developer entry (game/tools/dev_chapter5.gd = a finished Chapter 4 state), then plays the
## chapter with the real interaction / pickup / dialogue / save systems. The player WALKS the route (physics,
## collisions) and Eddie's companion follow is checked every frame for jumps and wall crossings.
## The Chapter 4 -> 5 hand-over itself is covered by opening_test.gd (c5_starts_after_ch4).

const DEV := preload("res://game/tools/dev_chapter5.gd")

var fails := 0
var world: Node
var game: Node
var ps: PackedScene
var c5: Node
var p4: Node
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
	return cond.call()


## Dialogue-heavy waits run the clock faster (dialogue timers only; nobody is walking).
func wait_talk(cond: Callable, max_seconds := 90.0) -> bool:
	Engine.time_scale = 6.0
	var r := await wait_until(cond, int(max_seconds * 60 / 6.0) + 60)
	Engine.time_scale = 1.0
	return r


func _physics_watch() -> void:
	# called every frame while walking: Eddie must never jump or cross a wall between two frames
	if not _watch or c5 == null:
		return
	var e: Vector3 = c5.eddie.global_position
	var step := e.distance_to(_eddie_prev)
	if step > 0.2 and eddie_max_step <= 0.2:
		print("  eddie jump %.2f m: %s -> %s (player %s)" % [step, _eddie_prev, e, world.player.global_position])
	eddie_max_step = maxf(eddie_max_step, step)
	if step > 0.02:
		var space: PhysicsDirectSpaceState3D = c5.eddie.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(_eddie_prev + Vector3(0, 0.5, 0), e + Vector3(0, 0.5, 0), 1)
		var wh := space.intersect_ray(q)
		if wh:
			eddie_wall_hits += 1
			print("  eddie wall crossing at %s (%s)" % [wh["position"], (wh["collider"] as Node).name])
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


## From where the player already stands (no teleport), look at the interactable; true if the real ray finds it.
func look(it: Node3D) -> bool:
	var player = world.player
	var c: Vector3 = it.global_position
	for cs in it.get_children():
		if cs is CollisionShape3D:
			c = (cs as CollisionShape3D).global_position
	await frames(2)
	var eye: Vector3 = player.camera.global_position
	var v := (c - eye).normalized()
	player.set_yaw_pitch(atan2(-v.x, -v.z), asin(clampf(v.y, -1.0, 1.0)))
	await watch_frames(5)
	return player._focus == it


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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	ps = load("res://game/scenes/World.tscn")
	DEV.prepare(game)
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	p4 = world.phase4
	c5 = p4.chapter5 if p4 else null
	var mk: Node3D = world.market
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	ok("c5_entry", c5 != null and game.has_flag("c5_started") and game.current_step().get("id", "") == "c5_talk",
		game.current_step().get("id", ""))
	ok("c5_no_colossus", world.get_node_or_null("Colossus") == null and not world.find_children("*Colossus*", "", true, false).any(func(n): return n.is_visible_in_tree() if n is Node3D else false))
	ok("c5_npcs_present", c5.eddie.visible and c5.marcus.visible and c5.eddie.get_parent() == mk)
	var inv0: Array = game.inventory.duplicate()
	var spares0: int = p4.flashlight.spares if p4.flashlight else -1
	# ---- scene 1: talk to both
	ok("c5_cant_leave_yet", c5.its["exit"].prompt_text == "")
	ok("c5_eddie_reach", await aim(c5.its["npc_Eddie"], [Z, -Z, X, -X], mk, 1.4))
	c5.its["npc_Eddie"].interact(world.player)
	ok("c5_eddie_talk", await wait_talk(func(): return game.has_flag("c5_eddie_talked")))
	ok("c5_marcus_reach", await aim(c5.its["npc_Marcus"], [Z, -Z, X, -X], mk, 1.4))
	c5.its["npc_Marcus"].interact(world.player)
	ok("c5_marcus_talk", await wait_talk(func(): return game.has_flag("c5_marcus_talked")))
	ok("c5_objective_prepare", game.has_flag("c5_talked_both") and game.current_step().get("id", "") == "c5_prepare",
		game.current_step().get("id", ""))
	ok("c5_hud_objective", world.hud.step_l.text == "Prepare for the search" or await wait_until(func(): return world.hud.step_l.text == "Prepare for the search", 90),
		world.hud.step_l.text)
	# ---- scene 2: prepare
	ok("c5_stash_reach", await aim(c5.its["stash"], [-Z, Z, X, -X], mk, 1.0))
	c5.its["stash"].interact(world.player)
	await frames(5)
	ok("c5_inventory_shown", game.has_flag("c5_supplies_checked") and world.hud.inv_panel.visible)
	ok("c5_no_duplicate_gear", game.inventory == inv0, str(game.inventory))
	ok("c5_exit_reach", await aim(c5.its["exit"], [Z, -Z], mk, 1.2))
	c5.its["exit"].interact(world.player)
	ok("c5_exit_confirm", await wait_until(func(): return p4.choice.is_open(), 60))
	p4.choice.pick(0)
	ok("c5_prepared", await wait_talk(func(): return game.has_flag("c5_prepared"), 40.0)
		and c5.st()["eddie"] == "following" and c5.eddie_follow.active)
	ok("c5_doors_open", c5._doors_open)
	await reload()
	ok("c5_load_following", c5 != null and c5.eddie_follow.active and c5.eddie.get_parent() == world
		and c5.eddie.global_position.distance_to(world.player.global_position) < 4.0
		and world.find_children("Eddie", "", true, false).size() == 1)
	# ---- scene 3: the street (player walks, Eddie follows) - route measured with a collision map:
	# out of the front doors, west along the store front, south down the x = 11.5 m lane, through the gap in the
	# back-yard fence row (z = -58) to the cottage's front path. No teleports from here until the report.
	mk = world.market
	_eddie_prev = c5.eddie.global_position
	_watch = true
	var out_store := [Vector3(1.5, 0.2, 4.4), Vector3(1.5, 0.2, 1.8), Vector3(0.3, 0.2, 1.0), Vector3(0.3, 0.2, -3.5)]
	var walked := await walk_route(out_store, mk)
	walked = walked and await walk_world([Vector3(11.5, 0.2, -23.5), Vector3(11.5, 0.2, -60.5), Vector3(15.6, 0.2, -62.5),
		Vector3(15.6, 0.2, -66.6)])
	ok("c5_house_reachable_walk", walked, str(world.player.global_position))
	ok("c5_doors_shut_behind", not c5._doors_open)
	ok("c5_street_line", game.has_flag("c5_street_said"))
	ok("c5_eddie_kept_up", await wait_until(func(): return c5.eddie.global_position.distance_to(world.player.global_position) < 4.5, 60 * 12),
		"lag %.1f m" % c5.eddie.global_position.distance_to(world.player.global_position))
	# ---- scene 4: the house (walked room to room; doors opened through the real ray)
	var h: Node3D = c5.house
	var fd: Interactable = c5.its["c5/HOUSE_04/INT_Door_Front"]
	ok("c5_front_door_reach", await look(fd))
	fd.interact(world.player)
	await watch_frames(40)
	ok("c5_enter_house", await walk_route([Vector3(-1.6, 0.8, 2.6), Vector3(-1.6, 0.8, 4.6)], h) and game.has_flag("c5_house_reached"))
	for k in ["food", "batteries", "medical"]:
		var item: Interactable = c5.its["item_" + k]
		ok("c5_item_hidden_" + k, not item.target.visible and item.collision_layer == 0)
	var stands := {
		"food": [[Vector3(-2.0, 0.8, 6.0), Vector3(-2.0, 0.8, 7.4), Vector3(-2.7, 0.8, 8.6), Vector3(-2.7, 0.8, 10.25), Vector3(-1.8, 0.8, 10.25)], ""],
		"medical": [[Vector3(-0.6, 0.8, 10.25), Vector3(-0.5, 0.8, 8.6)], "c5/HOUSE_04/INT_Door_Bath",
			[Vector3(-0.45, 0.8, 8.5), Vector3(0.5, 0.8, 8.5), Vector3(0.9, 0.8, 8.3)]],
		"batteries": [[Vector3(-0.5, 0.8, 8.6), Vector3(-0.5, 0.8, 10.25), Vector3(-2.7, 0.8, 10.25), Vector3(-2.7, 0.8, 8.6),
			Vector3(-2.0, 0.8, 7.4), Vector3(-2.0, 0.8, 6.0), Vector3(-0.2, 0.8, 5.2)], "c5/HOUSE_04/INT_Door_Bed",
			[Vector3(1.3, 0.8, 5.2), Vector3(1.25, 0.8, 3.6), Vector3(1.4, 0.8, 2.75), Vector3(2.6, 0.8, 2.7)]],
	}
	for k in ["food", "medical", "batteries"]:
		var plan: Array = stands[k]
		var reached := await walk_route(plan[0], h)
		if plan[1] != "":
			var door: Interactable = c5.its[plan[1]]
			ok("c5_door_reach_" + k, await look(door))
			if not door.is_open:
				door.interact(world.player)
			await watch_frames(40)
			reached = reached and await walk_route(plan[2], h)
		var sk: Interactable = c5.its[c5.SEARCH[k][0]]
		var item: Interactable = c5.its["item_" + k]
		ok("c5_search_reach_" + k, reached and await look(sk), str(h.to_local(world.player.global_position)))
		sk.interact(world.player)
		await watch_frames(20)
		ok("c5_item_reach_" + k, await look(item))
		item.interact(world.player)
		await watch_frames(10)
		if k == "food":
			ok("c5_eddie_follows_inside", await wait_until(func(): return c5._in_house(c5.eddie.global_position), 60 * 10),
				"eddie %s" % h.to_local(c5.eddie.global_position))
	ok("c5_food_in_inventory", game.has_item("canned_food"))
	ok("c5_medical_in_inventory", game.has_item("first_aid_kit"))
	ok("c5_batteries_real", game.has_item("batteries") and p4.flashlight.spares == spares0 + 2, "spares %d -> %d" % [spares0, p4.flashlight.spares])
	ok("c5_supplies_done", game.has_flag("c5_supplies_done") and game.current_step().get("id", "") == "c5_radio")
	ok("c5_found_line", game.has_flag("c5_found_said"))
	# ---- scene 5: the radio (from the bedroom back to the living-room side of the dining table)
	ok("c5_walk_to_radio", await walk_route([Vector3(1.4, 0.8, 2.75), Vector3(1.25, 0.8, 3.6), Vector3(1.3, 0.8, 5.2),
		Vector3(-0.2, 0.8, 5.2), Vector3(-2.0, 0.8, 6.0), Vector3(-2.0, 0.8, 7.4), Vector3(-1.6, 0.8, 8.3)], h))
	_watch = false
	await reload()
	ok("c5_load_no_dupes", game.inventory.count("canned_food") == 1 and p4.flashlight.spares == spares0 + 2
		and c5.its["item_food"].taken and not c5.its["item_food"].target.visible and c5.eddie_follow.active)
	_eddie_prev = c5.eddie.global_position
	_watch = true
	h = c5.house
	var rit: Interactable = c5.its["radio"]
	ok("c5_radio_static", c5._static.playing)
	ok("c5_radio_reach", await look(rit))
	rit.interact(world.player)
	ok("c5_radio_done", await wait_talk(func(): return game.has_flag("c5_radio_done"), 120.0) and not c5._static.playing)
	rit.interact(world.player)
	await frames(5)
	ok("c5_radio_once", c5.radio_runs == 1 and rit.prompt_text == "")
	_watch = false
	await reload()
	ok("c5_radio_persists", game.has_flag("c5_radio_done") and not c5._static.playing and c5.its["radio"].prompt_text == "")
	# ---- scene 6: survivor (choice A in the main run; B and C are checked from the same save below)
	var snap := {"flags": game.flags.duplicate(true), "ws": game.world_state.duplicate(true), "inv": game.inventory.duplicate(),
		"ps": game.player_state.duplicate(true)}
	_eddie_prev = c5.eddie.global_position
	_watch = true
	h = c5.house
	ok("c5_leave_house", await walk_route([Vector3(-2.0, 0.8, 7.4), Vector3(-2.0, 0.8, 6.0), Vector3(-1.6, 0.8, 4.6),
		Vector3(-1.6, 0.8, 2.4), Vector3(-1.6, 0.4, 1.0)], h))
	ok("c5_walk_to_neighbour", await walk_world([Vector3(15.6, 0.2, -62.5), Vector3(22.0, 0.2, -62.0), Vector3(30.9, 0.2, -64.6)]))
	ok("c5_return_line", game.has_flag("c5_return_said"))
	ok("c5_survivor_choice_offered", await wait_talk(func(): return p4.choice.is_open(), 40.0))
	ok("c5_survivor_visible", c5.survivor.visible)
	p4.choice.pick(0)
	ok("c5_survivor_helped", await wait_talk(func(): return game.has_flag("c5_survivor_helped") and c5.survivor_follow.active, 30.0))
	# ---- scene 7: back to the supermarket (out through the neighbour's front path gap at x 29-32)
	mk = world.market
	ok("c5_walk_back", await walk_world([Vector3(30.6, 0.2, -61.5), Vector3(30.6, 0.2, -50.0), Vector3(11.5, 0.2, -50.0),
		Vector3(11.5, 0.2, -23.5), Vector3(32.7, 0.2, -23.5)]) and await walk_route([Vector3(0.3, 0.2, -2.5), Vector3(0.3, 0.2, 1.2),
		Vector3(1.5, 0.2, 1.8), Vector3(1.5, 0.2, 4.6), Vector3(-0.5, 0.2, 6.2)], mk), str(mk.to_local(world.player.global_position)))
	ok("c5_returned", await wait_until(func(): return game.has_flag("c5_returned"), 60 * 20),
		"eddie local %s" % mk.to_local(c5.eddie.global_position))
	_watch = false
	ok("c5_eddie_no_teleport", eddie_max_step < 0.2, "max step %.3f m/frame" % eddie_max_step)
	ok("c5_eddie_no_wall_crossing", eddie_wall_hits == 0, "%d crossings" % eddie_wall_hits)
	ok("c5_eddie_lag_reasonable", eddie_max_lag < 14.0, "max %.1f m" % eddie_max_lag)
	ok("c5_eddie_inside", mk.to_local(c5.eddie.global_position).z > 1.0 and c5.eddie.get_parent() == mk)
	ok("c5_survivor_inside", c5.st()["survivor"] == "shelter" and c5.survivor.get_parent() == mk)
	await frames(100)
	ok("c5_doors_closed_home", not c5._doors_open)
	# ---- scene 8: report
	ok("c5_report_prompt", c5.its["npc_Marcus"].prompt_text == "[E] Talk")
	ok("c5_marcus_reach_back", await aim(c5.its["npc_Marcus"], [Z, -Z, X, -X], mk, 1.4))
	c5.its["npc_Marcus"].interact(world.player)
	ok("c5_reported", await wait_talk(func(): return game.has_flag("c5_reported") and game.has_flag("c5_complete"), 90.0))
	ok("c5_complete_card", world.hud.title.text.begins_with("CHAPTER 5 COMPLETE"), world.hud.title.text)
	ok("c5_no_chapter6", not game.has_flag("c6_started") and game.current_step().get("id", "") == "c5_complete")
	ok("c5_sleep_available", p4.rest.interactable.prompt_text == "[E] Sleep")
	await reload()
	ok("c5_load_complete", game.has_flag("c5_complete") and c5.eddie.get_parent() == world.market
		and c5.survivor.visible and c5.st()["survivor"] == "shelter" and world.phase4.rest.interactable.prompt_text == "[E] Sleep"
		and game.has_item("first_aid_kit") and world.find_children("Eddie", "", true, false).size() == 1)
	p4.rest.interactable.interact(world.player)
	ok("c5_rest_confirm", await wait_until(func(): return p4.choice.is_open(), 60))
	p4.choice.pick(0)
	ok("c5_rest", await wait_until(func(): return game.has_flag("c5_rested"), 60 * 8)
		and not game.has_flag("c6_started") and await wait_until(func(): return world.player.controls_enabled, 60 * 5))
	# ---- survivor choices B and C persist (from the snapshot taken before the encounter)
	for pick in [[1, "c5_survivor_informed"], [2, "c5_survivor_left"]]:
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
		c5 = world.phase4.chapter5
		await walk_route([Vector3(-2.0, 0.8, 7.4), Vector3(-2.0, 0.8, 6.0), Vector3(-1.6, 0.8, 4.6), Vector3(-1.6, 0.8, 2.4),
			Vector3(-1.6, 0.4, 1.0)], c5.house)
		await walk_world([Vector3(15.6, 0.2, -62.5), Vector3(22.0, 0.2, -62.0), Vector3(30.9, 0.2, -64.6)])
		var offered := await wait_talk(func(): return world.phase4.choice.is_open(), 40.0)
		world.phase4.choice.pick(pick[0])
		var set := await wait_talk(func(): return game.has_flag(pick[1]), 20.0)
		await reload()
		ok("c5_choice_persists_" + pick[1].trim_prefix("c5_survivor_"), offered and set and game.has_flag(pick[1])
			and not game.has_flag("c5_survivor_helped") and c5.st()["survivor"] == "house" and not c5.survivor_follow.active)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
