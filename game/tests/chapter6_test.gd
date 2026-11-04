extends SceneTree
## THE VEIL - Chapter 6 "Voices in the Mist" automated playthrough (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter6_test.gd
## Starts from the developer entry (game/tools/dev_chapter6.gd = Chapter 5 complete and slept), then plays the
## chapter with the real interaction / dialogue / save systems: the player WALKS every route (physics, collisions),
## Eddie's follow is checked every frame, the Hound's detection / chase / bite / loss run on the real AI.
## Main run: invite Ruth + Sarah, investigate the voice. Then, from saves: directions / leave, and the retreat branch.

const DEV := preload("res://game/tools/dev_chapter6.gd")

var fails := 0
var world: Node
var game: Node
var ps: PackedScene
var c5: Node
var c6: Node
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
	if _trace and c6 != null:
		_trace_t += 1
		if _trace_t % 60 == 0:
			var hv: bool = c6.hound != null and is_instance_valid(c6.hound)
			print("  trace player %s hound %s %s aw %.2f" % [world.player.global_position.snapped(Vector3.ONE * 0.1),
				c6.hound.global_position.snapped(Vector3.ONE * 0.1) if hv else "-", c6.hound_ai.state if hv else "-",
				c6.hound_ai.awareness if hv else 0.0])
	# called every frame while walking: Eddie must never jump or cross a wall between two frames
	if not _watch or c5 == null:
		return
	if c6 != null and c6._busy.get("checkpoint", false):
		_eddie_prev = c5.eddie.global_position     # the checkpoint moves everyone behind a black fade
		return
	var e: Vector3 = c5.eddie.global_position
	var step := e.distance_to(_eddie_prev)
	step /= maxf(Engine.time_scale, 1.0)            # per real 1/60 s, so the 6x dialogue clock is not a "jump"
	if step > 0.2 and eddie_max_step <= 0.2:
		print("  eddie jump %.2f m: %s -> %s (player %s)" % [step, _eddie_prev, e, world.player.global_position])
	eddie_max_step = maxf(eddie_max_step, step)
	if step > 0.02:
		var space: PhysicsDirectSpaceState3D = c5.eddie.get_world_3d().direct_space_state
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


func _initialize() -> void:
	_run.call_deferred()
	# watchdog: a script error inside _run must not leave the test hanging
	create_timer(1500.0).timeout.connect(func():
		print("RESULT FAIL (watchdog: test did not finish)")
		quit(1))


const OUT_STORE := [Vector3(1.5, 0.2, 4.4), Vector3(1.5, 0.2, 1.8), Vector3(0.3, 0.2, 1.0), Vector3(0.3, 0.2, -3.5)]
const TO_RS := [Vector3(33.0, 0.2, -23.5), Vector3(57.0, 0.2, -23.5), Vector3(57.0, 0.2, -55.0), Vector3(51.0, 0.2, -55.0), Vector3(51.0, 0.2, -59.5)]
const LEAVE_YARD := [Vector3(51.0, 0.2, -56.0), Vector3(57.0, 0.2, -55.0)]
const TO_ALLEY := [Vector3(60.0, 0.2, -56.0), Vector3(60.0, 0.2, -77.0), Vector3(50.0, 0.2, -77.0), Vector3(47.0, 0.2, -77.0)]
const HOME_EAST := [Vector3(60.0, 0.2, -56.0), Vector3(57.0, 0.2, -40.0), Vector3(57.0, 0.2, -23.5), Vector3(32.7, 0.2, -23.5)]
const HOME_WEST := [Vector3(51.0, 0.2, -55.0), Vector3(11.5, 0.2, -55.0), Vector3(11.5, 0.2, -23.5), Vector3(32.7, 0.2, -23.5)]
const INTO_STORE := [Vector3(0.3, 0.2, -2.5), Vector3(0.3, 0.2, 1.2), Vector3(1.5, 0.2, 1.8), Vector3(1.5, 0.2, 4.6), Vector3(-0.5, 0.2, 6.2)]


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
	c5 = p4.chapter5 if p4 else null
	c6 = c5.chapter6 if c5 else null
	var mk: Node3D = world.market
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	var inv0: Array = game.inventory.duplicate()
	ok("c6_entry_after_c5_rest", c6 != null and game.has_flag("ch6_started") and game.current_step().get("id", "") == "c6_marcus",
		game.current_step().get("id", ""))
	ok("c6_eddie_waits", c6.its["npc_Eddie"].prompt_text == "" and c5.its["exit"].prompt_text == "")
	# ---- scene 1-2
	ok("c6_marcus_reach", await aim(c6.its["npc_Marcus"], [Z, -Z, X, -X], mk, 1.4))
	c6.its["npc_Marcus"].interact(world.player)
	ok("c6_marcus_briefing", await wait_talk(func(): return game.has_flag("ch6_marcus_briefing_complete")) and game.current_step().get("id", "") == "c6_eddie")
	await reload()
	ok("c6_load_after_briefing", game.has_flag("ch6_marcus_briefing_complete") and c6.its["npc_Marcus"].prompt_text == "" and c6.its["npc_Eddie"].prompt_text == "[E] Talk")
	ok("c6_eddie_reach", await aim(c6.its["npc_Eddie"], [Z, -Z, X, -X], world.market, 1.4))
	c6.its["npc_Eddie"].interact(world.player)
	ok("c6_eddie_talk", await wait_talk(func(): return game.has_flag("ch6_eddie_talked")) and game.current_step().get("id", "") == "c6_prepare")
	ok("c6_stash_reach", await aim(c5.its["stash"], [-Z, Z, X, -X], world.market, 1.0))
	c5.its["stash"].interact(world.player)
	await frames(5)
	ok("c6_prepared", game.has_flag("ch6_eddie_ready") and world.hud.inv_panel.visible and game.inventory == inv0)
	if world.hud.inv_panel.visible:
		world.hud.toggle_inventory()                 # the inventory screen holds the controls while it is open
	await frames(5)
	ok("c6_exit_reach", await aim(c5.its["exit"], [Z, -Z], world.market, 1.2))
	c5.its["exit"].interact(world.player)
	ok("c6_exit_confirm", await wait_until(func(): return p4.choice.is_open(), 60))
	p4.choice.pick(0)
	ok("c6_eddie_following", await wait_talk(func(): return game.has_flag("ch6_eddie_following"), 30.0) and c5.eddie_follow.active)
	await reload()
	ok("c6_load_eddie_following", c5.eddie_follow.active and world.find_children("Eddie", "", true, false).size() == 1)
	# ---- scene 3: the street (no teleports from here)
	mk = world.market
	_eddie_prev = c5.eddie.global_position
	_watch = true
	ok("c6_walk_out", await walk_route(OUT_STORE, mk) and await walk_world([TO_RS[0]]), str(world.player.global_position))
	ok("c6_left_supermarket", await wait_until(func(): return game.has_flag("ch6_left_supermarket"), 60 * 6)
		and game.current_step().get("id", "") == "c6_search", "eddie %s" % world.market.to_local(c5.eddie.global_position))
	ok("c6_beacon_to_house", world._beacons.has("c6"))
	ok("c6_walk_to_house", await walk_world(TO_RS.slice(1)), str(world.player.global_position))
	ok("c6_walk_line", game.has_flag("ch6_walk_said"))
	# ---- scene 4: Ruth and Sarah
	ok("c6_house_found", game.has_flag("ch6_house_found"))
	var rs_snap := snapshot()
	ok("c6_rs_choice_offered", await wait_talk(func(): return p4.choice.is_open(), 60.0))
	ok("c6_rs_visible", c6.ruth.visible and c6.sarah.visible and c6.ruth.get_node_or_null("VeilFace") != null)
	var sp2: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var bh := sp2.intersect_ray(PhysicsRayQueryParameters3D.create(c6.hl(Vector3(2.6, 1.5, 1.0)), c6.hl(Vector3(2.6, 1.5, 6.0)), 1))
	ok("c6_rs_house_not_enterable", bh and (bh["collider"] as Node).name == "C6_RuthSarahDoorway")
	p4.choice.pick(0)
	ok("c6_rs_invite", await wait_talk(func(): return game.has_flag("ch6_ruth_sarah_met"), 30.0)
		and c6.st()["ruth_sarah_choice"] == "invite" and c6.ruth_follow.active and c6.sarah_follow.active)
	ok("c6_objective_voice", game.current_step().get("id", "") == "c6_voice")
	# ---- scene 5: the voice
	ok("c6_leave_yard", await walk_world(LEAVE_YARD))
	ok("c6_voice_choice_offered", await wait_talk(func(): return p4.choice.is_open(), 60.0) and game.has_flag("ch6_voice_heard"))
	var voice_snap := snapshot()
	p4.choice.pick(0)
	ok("c6_investigate", await wait_talk(func(): return game.has_flag("ch6_voice_choice_made"), 20.0)
		and c6.st()["voice_choice"] == "investigate")
	# BUG FIX CHECK: nothing advances while the player stays where the choice was made
	await wait_until(func(): return false, 60 * 10)
	ok("c6_investigate_waits_at_choice", c6.hound == null and c6.hound_spawns == 0 and not game.has_flag("ch6_hound_encounter_started")
		and not game.has_flag("ch6_hound_encounter_complete") and game.current_step().get("id", "") == "c6_voice"
		and world._beacons.has("c6") and world.hud.marker_visible, game.current_step().get("id", ""))
	c6._voice()
	ok("c6_voice_once", c6.voice_runs == 1)
	await reload()
	ok("c6_load_mid_branch", c6.hound == null and game.current_step().get("id", "") == "c6_voice" and c6.ruth_follow.active
		and c5.eddie_follow.active and world.find_children("Ruth", "", true, false).size() == 1)
	_eddie_prev = c5.eddie.global_position
	# ---- scene 6: the Hound (investigate)
	_trace = true
	# partway down the side street: still travelling, still the voice objective (also across a save / load)
	ok("c6_walk_partway", await walk_world([TO_ALLEY[0], Vector3(60.0, 0.2, -66.0)]))
	ok("c6_partway_still_active", game.current_step().get("id", "") == "c6_voice" and c6.hound == null and world.hud.marker_visible)
	await reload()
	ok("c6_partway_load", game.current_step().get("id", "") == "c6_voice" and c6.hound == null and c5.eddie_follow.active
		and world._beacons.has("c6"))
	_eddie_prev = c5.eddie.global_position
	ok("c6_walk_to_alley", await walk_world([Vector3(60.0, 0.2, -77.0), Vector3(53.5, 0.2, -77.0)]), str(world.player.global_position))
	ok("c6_not_before_area", not game.has_flag("ch6_investigation_reached") and c6.hound == null)
	ok("c6_reach_investigation_area", await walk_world([Vector3(48.5, 0.2, -77.0)]) and await wait_until(func(): return game.has_flag("ch6_investigation_reached"), 60 * 2)
		and c6.hound != null and c6.hound_spawns == 1 and not world.hud.marker_visible)
	ok("c6_encounter_started", await wait_until(func(): return game.has_flag("ch6_hound_encounter_started"), 60 * 25)
		and game.current_step().get("id", "") == "c6_avoid" and await wait_until(func(): return said.has("What the hell is that?"), 60 * 2))
	ok("c6_hound_on_floor", is_instance_valid(c6.hound) and absf(c6.hound.global_position.y - 0.15) < 0.25, str(c6.hound.global_position))
	var hound_snap := snapshot()
	# A) stay in its sight, get noticed, sprint away up the side street: it must lose the player
	ok("c6_hound_detects", await wait_until(func(): return is_instance_valid(c6.hound) and c6.hound_ai.state == "CHASE", 60 * 15))
	ok("c6_run_line", await wait_until(func(): return said.has("RUN!"), 60 * 3))
	Input.action_press("sprint")
	await walk_world([Vector3(60.0, 0.2, -77.0), Vector3(60.0, 0.2, -56.0), Vector3(57.0, 0.2, -40.0), Vector3(57.0, 0.2, -30.0)])
	Input.action_release("sprint")
	ok("c6_hound_loses_player", await wait_until(func(): return not is_instance_valid(c6.hound) or c6.hound_ai.state in ["SEARCH", "RETURN", "PATROL"], 60 * 10)
		and c6.hound_ai.chases >= 1)
	ok("c6_encounter_complete", await wait_until(func(): return game.has_flag("ch6_hound_encounter_complete"), 60 * 15)
		and game.current_step().get("id", "") == "c6_return")
	ok("c6_eddie_escaped_too", c5.eddie.global_position.distance_to(world.player.global_position) < 18.0,
		"%.1f m" % c5.eddie.global_position.distance_to(world.player.global_position))
	var main_snap := snapshot()
	# B) (from the save at first sight) stand in its way: bites, never a death, the checkpoint takes over
	_watch = false
	await restore(hound_snap)
	ok("c6_load_in_encounter_no_dupes", c6.hound != null and c6.hound_spawns == 1 and game.has_flag("ch6_investigation_reached")
		and world.player.global_position.distance_to(c6.hound.global_position) >= 11.0)
	await walk_world([Vector3(47.0, 0.2, -77.0)])
	await wait_until(func(): return is_instance_valid(c6.hound) and c6.hound_ai.state == "CHASE", 60 * 15)
	var hp0: float = world.player.health
	ok("c6_hound_bites", await wait_until(func(): return world.player.health < hp0, 60 * 12), "hp %.0f" % world.player.health)
	ok("c6_checkpoint_not_death", await wait_until(func(): return c6._busy.get("checkpoint", false), 60 * 25) and world.player.health > 0.0)
	await wait_until(func(): return not c6._busy.get("checkpoint", false), 60 * 4)
	ok("c6_checkpoint_safe", world.player.health > 40.0 and (not is_instance_valid(c6.hound)
		or world.player.global_position.distance_to(c6.hound.global_position) > 15.0), "hp %.0f" % world.player.health)
	# back to the main run (escaped by losing it)
	await restore(main_snap)
	await frames(10)                               # the load's one-time placement (screen black) is not a "jump"
	_eddie_prev = c5.eddie.global_position
	_watch = true
	ok("c6_no_ammo_needed", not game.has_item("ammo") and game.has_flag("ch6_hound_encounter_complete"))
	# ---- scene 7: home
	ok("c6_walk_home", await walk_world([Vector3(57.0, 0.2, -23.5), Vector3(32.7, 0.2, -23.5)]) and await walk_route(INTO_STORE, world.market),
		str(world.market.to_local(world.player.global_position)))
	ok("c6_return_line", game.has_flag("ch6_return_said"))
	mk = world.market
	ok("c6_returned", await wait_until(func(): return game.has_flag("ch6_returned_to_supermarket"), 60 * 25),
		"eddie %s ruth %s" % [mk.to_local(c5.eddie.global_position), mk.to_local(c6.ruth.global_position)])
	_watch = false
	ok("c6_eddie_no_teleport", eddie_max_step < 0.2, "max %.3f" % eddie_max_step)
	ok("c6_eddie_no_wall_crossing", eddie_wall_hits == 0, "%d" % eddie_wall_hits)
	ok("c6_eddie_lag", eddie_max_lag < 16.0, "%.1f" % eddie_max_lag)
	ok("c6_rs_in_shelter", c6.st()["ruth_sarah"] == "shelter" and c6.ruth.get_parent() == mk)
	ok("c6_hound_gone", c6.hound == null or not is_instance_valid(c6.hound))
	await frames(120)
	ok("c6_doors_closed", not c5._doors_open)
	# ---- scene 8: report
	ok("c6_report_prompt", c6.its["npc_Marcus"].prompt_text == "[E] Talk")
	ok("c6_marcus_reach_back", await aim(c6.its["npc_Marcus"], [Z, -Z, X, -X], world.market, 1.4))
	said.clear()
	c6.its["npc_Marcus"].interact(world.player)
	ok("c6_complete", await wait_talk(func(): return game.has_flag("chapter_6_complete"), 120.0))
	ok("c6_report_invite_line", said.has("Two survivors. Ruth and Sarah. We offered them shelter.") and said.has("Thank God."))
	ok("c6_complete_card", world.hud.title.text.begins_with("CHAPTER 6 COMPLETE"), world.hud.title.text)
	ok("c6_no_chapter7", not game.has_flag("ch7_started") and game.current_step().get("id", "") == "c6_complete")
	await reload()
	ok("c6_load_complete", game.has_flag("chapter_6_complete") and c6.hound == null and c6.ruth.visible
		and c6.st()["ruth_sarah"] == "shelter" and world.find_children("Ruth", "", true, false).size() == 1
		and p4.rest.interactable.prompt_text == "[E] Sleep")
	p4.rest.interactable.interact(world.player)
	ok("c6_rest_confirm", await wait_until(func(): return p4.choice.is_open(), 60))
	p4.choice.pick(0)
	ok("c6_rest_starts_ch7", await wait_until(func(): return game.has_flag("ch6_rested"), 60 * 8) and game.has_flag("ch7_started")
		and game.current_step().get("id", "") == "c7_marcus")
	# ---- survivor choices B and C persist (from the save before the conversation)
	for pick in [[1, "directions"], [2, "leave"]]:
		await restore(rs_snap)
		var offered := await wait_talk(func(): return p4.choice.is_open(), 60.0)
		p4.choice.pick(pick[0])
		var set := await wait_talk(func(): return game.has_flag("ch6_ruth_sarah_met"), 30.0)
		await reload()
		ok("c6_rs_choice_persists_" + pick[1], offered and set and c6.st()["ruth_sarah_choice"] == pick[1]
			and game.has_flag("ch6_ruth_sarah_choice_" + pick[1]) and not c6.ruth.visible and not c6.ruth_follow.active
			and world.find_children("Sarah", "", true, false).size() == 1)
	# ---- retreat branch (from the save at the voice choice), home by the west lane, avoiding the Hound
	await restore(voice_snap)
	ok("c6_retreat_offered", await wait_talk(func(): return p4.choice.is_open(), 30.0))
	p4.choice.pick(1)
	ok("c6_retreat", await wait_talk(func(): return game.has_flag("ch6_voice_choice_made"), 20.0)
		and c6.st()["voice_choice"] == "retreat")
	await wait_until(func(): return false, 60 * 6)
	ok("c6_retreat_no_immediate_hound", c6.hound == null and not game.has_flag("ch6_hound_encounter_started"))
	var retreat_snap := snapshot()
	ok("c6_retreat_walk_home", await walk_world(HOME_WEST) and await walk_route(INTO_STORE, world.market), str(world.player.global_position))
	ok("c6_retreat_complete", game.has_flag("ch6_hound_encounter_complete") and await wait_until(func(): return game.has_flag("ch6_returned_to_supermarket"), 60 * 25))
	said.clear()
	c6.its["npc_Marcus"].interact(world.player)
	ok("c6_retreat_report", await wait_talk(func(): return game.has_flag("chapter_6_complete"), 120.0)
		and said.has("Two survivors. Ruth and Sarah. We offered them shelter."))
	# retreat by the east route: the Hound only at the designated point on the way home, then escape back west
	await restore(retreat_snap)
	await walk_world([Vector3(57.0, 0.2, -55.0), Vector3(57.0, 0.2, -51.0)])
	ok("c6_retreat_east_not_yet", c6.hound == null)
	await walk_world([Vector3(57.0, 0.2, -47.0)])
	ok("c6_retreat_area_triggers", await wait_until(func(): return game.has_flag("ch6_retreat_route_reached") and c6.hound != null, 60 * 2)
		and await wait_until(func(): return game.has_flag("ch6_hound_encounter_started"), 60 * 6))
	await reload()
	ok("c6_retreat_load_in_encounter", c6.hound != null and c6.hound_spawns == 1)
	Input.action_press("sprint")
	await walk_world([Vector3(57.0, 0.2, -55.0), Vector3(30.0, 0.2, -55.0), Vector3(11.5, 0.2, -55.0)])
	Input.action_release("sprint")
	ok("c6_retreat_east_escaped", await wait_until(func(): return game.has_flag("ch6_hound_encounter_complete"), 60 * 20))
	ok("c6_retreat_east_home", await walk_world([Vector3(11.5, 0.2, -23.5), Vector3(32.7, 0.2, -23.5)]) and await walk_route(INTO_STORE, world.market)
		and await wait_until(func(): return game.has_flag("ch6_returned_to_supermarket"), 60 * 25))
	c6.its["npc_Marcus"].interact(world.player)
	ok("c6_retreat_east_complete", await wait_talk(func(): return game.has_flag("chapter_6_complete"), 120.0))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
