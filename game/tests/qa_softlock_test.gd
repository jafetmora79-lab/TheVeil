extends SceneTree
## THE VEIL - QA-001/002/003: saves made at awkward moments in the last three chapters load into a state that can
## still be finished (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/qa_softlock_test.gd

const DEV13 := preload("res://game/chapters/setups/dev_chapter13.gd")
const DEV14 := preload("res://game/chapters/setups/dev_chapter14.gd")
const DEV15 := preload("res://game/chapters/setups/dev_chapter15.gd")
var fails := 0
var world: Node
var game: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


## Save the state as it is, then load it into a fresh world (as the Continue button does).
func load_saved() -> void:
	if world:
		world.free()
	game.save_game()
	game.load_game()
	game.load_requested = true
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(60)


func chapter(n: int) -> Node:
	var c = world.phase4.chapter5
	for k in ["chapter6", "chapter7", "chapter8", "chapter9", "chapter10", "chapter11", "chapter12", "chapter13", "chapter14", "chapter15"]:
		if c == null:
			return null
		c = c.get(k)
		if k == "chapter%d" % n:
			return c
	return null


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true

	# ---- QA-002: the crank marked found but missing, the gate still shut
	DEV13.prepare(game)
	game.set_flag("ch13_started")
	game.set_flag("ch13_crank_found")
	game.inventory.erase("gate_crank")
	await load_saved()
	ok("qa002_crank_repaired", game.has_item("gate_crank") and game.inventory.count("gate_crank") == 1)
	await load_saved()
	ok("qa002_no_duplicate", game.inventory.count("gate_crank") == 1)
	var c13 = chapter(13)
	game.flags.erase("ch13_crank_found")
	game.inventory.erase("gate_crank")
	var saved_inv := [false]
	game.flag_set.connect(func(f): if f == "ch13_crank_found": saved_inv[0] = game.has_item("gate_crank"))
	c13._take_crank(null)
	ok("qa002_item_before_flag", saved_inv[0] and game.inventory.count("gate_crank") == 1)

	# ---- QA-003: saved after the fence separation began, before the choice was made
	DEV14.prepare(game)
	for f in ["ch14_started", "ch14_meeting_done", "ch14_siege_started", "ch14_evac_started", "ch14_separation"]:
		game.set_flag(f)
	await load_saved()
	var c14 = chapter(14)
	ok("qa003_choice_offered_again", not game.has_flag("ch14_separation") and not game.has_flag("ch14_separation_made"))
	# ... and after the choice was made (its consequences already applied): completed, not repeated
	game.set_flag("ch14_separation")
	c14.st()["separation"] = "went_back"
	c14.st()["separated"] = "Marcus"
	await load_saved()
	ok("qa003_made_choice_completed", game.has_flag("ch14_separation_made") and String(chapter(14).st()["separation"]) == "went_back")

	# ---- QA-010: the finale's road marker never points back to a waypoint already reached
	DEV15.prepare(game)
	for f in ["ch15_started", "ch15_opening_done", "ch15_plan_done", "ch15_supplies_done", "ch15_set_out"]:
		game.set_flag(f)
	await load_saved()
	var c15r = chapter(15)
	var R: Array = c15r.ROUTE
	world.player.global_position = R[3] + Vector3(0.5, 0.2, 0.5)
	c15r._guide()
	var ahead: bool = world.hud._mk_target is Vector3 and Vector2(world.hud._mk_target.x - R[4].x, world.hud._mk_target.z - R[4].z).length() < 0.5
	world.player.global_position = (R[1] + R[2]) * 0.5 + Vector3(0, 0.2, 0)
	c15r._guide()
	var still: bool = world.hud._mk_target is Vector3 and Vector2(world.hud._mk_target.x - R[4].x, world.hud._mk_target.z - R[4].z).length() < 0.5
	ok("qa010_route_forward_only", ahead and still, str(world.hud._mk_target))

	# ---- QA-001: saved after choosing an ending, before it finished
	DEV15.prepare(game)
	for f in ["ch15_started", "ch15_set_out", "ch15_colossus_seen", "ch15_crossed", "ch15_in_passage", "ch15_chamber_reached",
			"ch15_mechanism_done", "ch15_decided", "ch15_choice_b"]:
		game.set_flag(f)
	await load_saved()
	var c15 = chapter(15)
	var roster: Array = c15.present()
	c15.st()["decision"] = "B"
	game.set_flag("ch15_decided")
	game.set_flag("ch15_choice_b")
	await load_saved()
	c15 = chapter(15)
	var p4 = world.phase4
	ok("qa001_back_at_decision", not game.has_flag("ch15_decided") and not game.has_flag("ch15_choice_b") and String(c15.st()["decision"]) == "")
	var asked := false
	for i in 60 * 40:
		if p4.choice.is_open():
			asked = true
			break
		await process_frame
	ok("qa001_decision_offered", asked and c15.present() == roster)
	if asked:
		p4.choice.pick(0)
		var going := false
		for i in 60 * 30:
			if c15._busy.get("outer_open", false):
				going = true
				break
			await process_frame
		ok("qa001_ending_runs", going and game.has_flag("ch15_decided") and String(c15.st()["decision"]) == "A")
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
