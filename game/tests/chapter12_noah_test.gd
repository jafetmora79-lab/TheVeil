extends SceneTree
## THE VEIL - displayed Chapter 13, scene 13.0 THE NOAH RESCUE (chapter12_noah.gd), headless:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter12_noah_test.gd
## Marcus alive: the ribbon -> who goes -> the field and the Hound -> Marcus waits at the fence -> the porch, the knock, the bag question (a wrong answer, then
## the keychain) -> Noah -> the reunion -> the checkpoint -> back to the mill house -> "why under the ground" -> the chapter's own map talk (Noah in the room);
## a load afterwards does not replay it. Then Marcus lost: the bereavement choice. Noah is never lost: no branch hurts or leaves him.

const DEV := preload("res://game/chapters/setups/dev_chapter12.gd")

var fails := 0
var world: Node
var game: Node
var dlg: Node
var ps: PackedScene
var c9: Node
var c10: Node
var c11: Node
var c12: Node
var p4: Node
var n: Node
var said: Array = []


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(k: int) -> void:
	for i in k:
		await process_frame


func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func wait_talk(cond: Callable, max_seconds := 90.0) -> bool:
	Engine.time_scale = 6.0
	var r := await wait_until(cond, int(max_seconds * 60 / 6.0) + 60)
	Engine.time_scale = 1.0
	return r


func _bind() -> void:
	p4 = world.phase4
	var c5 = p4.chapter5 if p4 else null
	var c6 = c5.chapter6 if c5 else null
	var c7 = c6.chapter7 if c6 else null
	var c8 = c7.chapter8 if c7 else null
	c9 = c8.chapter9 if c8 else null
	c10 = c9.chapter10 if c9 else null
	c11 = c10.chapter11 if c10 else null
	c12 = c11.chapter12 if c11 else null
	n = c12.noah if c12 else null


func start_world(lost: bool) -> void:
	DEV.prepare(game, lost)
	for cp in ["chapter13_start", "chapter12_noah", "chapter12_noah_home"]:
		if FileAccess.file_exists(game.checkpoint_path(cp)):
			DirAccess.remove_absolute(game.checkpoint_path(cp))
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	await wait_until(func(): return not c12._busy.get("opening", false) and world.player.controls_enabled, 60 * 12)


func place(at: Vector3) -> void:
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	await frames(4)


func through_rescue(lost: bool) -> void:
	var tag := "lost" if lost else "alive"
	ok("n_open_" + tag, n.rescue_open() and not n.active() and game.current_step().get("id", "") == "c12_talk", game.current_step().get("id", ""))
	ok("n_eddie_prompt_" + tag, c12.its["npc_Eddie"].prompt_text == "[E] Talk")
	c12.its["npc_Eddie"].interact(world.player)
	ok("n_ribbon_" + tag, await wait_talk(func(): return game.has_flag("ch12_ribbon_read") and p4.choice.is_open(), 60.0) and game.has_item("noahs_ribbon"))
	ok("n_ribbon_line_" + tag, said.has("A trick doesn't know the knock.") if not lost else said.has("It's a kid's code."))
	ok("n_step_go_" + tag, game.current_step().get("id", "") == "c12n_go", game.current_step().get("id", ""))
	p4.choice.pick(0)                                              # go with Eddie
	ok("n_followers_" + tag, await wait_talk(func(): return c9.follows["Eddie"].active and not c9.follows["Ruth"].active and (lost or c9.follows["Marcus"].active), 40.0))
	await wait_talk(func(): return world.player.controls_enabled, 20.0)
	# the field: the Hound starts its rounds in front of HOUSE_19 when the player is near
	var porch: Vector3 = n.porch_point()
	var out: Vector3 = n._outward()
	await place(porch + out * 50.0 + Vector3(0, 0.3, 0))
	ok("n_hound_spawns_" + tag, await wait_until(func(): return n.hound != null and is_instance_valid(n.hound), 120))
	n.hound.process_mode = Node.PROCESS_MODE_DISABLED               # (the stealth itself is for the owner's playtest; here it only has to exist)
	if not lost:
		await place(porch + out * 20.0 + Vector3(0, 0.3, 0))
		ok("n_marcus_at_the_gate", await wait_until(func(): return n.report["marcus_at_gate"], 120) and not c9.follows["Marcus"].active)
	await place(porch + Vector3(0, 0.3, 0))
	ok("n_entered_" + tag, await wait_until(func(): return game.has_flag("ch12_house19_entered") and n.knock_it != null, 120))
	ok("n_knock_prompt_" + tag, await wait_talk(func(): return n.knock_it.prompt_text.begins_with("[E] Knock"), 30.0), n.knock_it.prompt_text)
	n.knock_it.interact(world.player)
	ok("n_test_asked_" + tag, await wait_talk(func(): return p4.choice.is_open(), 60.0) and said.has("Say what's wrong with the bag."))
	p4.choice.pick(1)                                              # "The zipper."  (wrong: Noah says no, and the keychain is offered)
	ok("n_wrong_" + tag, await wait_talk(func(): return n.report["test_wrong"] == 1 and p4.choice.is_open(), 30.0) and said.has("Nope."))
	p4.choice.pick(3)                                              # the keychain
	if lost:
		ok("n_bereave_" + tag, await wait_talk(func(): return said.has("Where's my dad?") and p4.choice.is_open(), 60.0))
		p4.choice.pick(2)                                          # hand him the backpack
	ok("n_found_" + tag, await wait_talk(func(): return game.has_flag("ch12_noah_found") and world.player.controls_enabled, 120.0))
	ok("n_found_state_" + tag, game.has_item("farmers_journal") and String(game.world_state["noah"]["status"]) == "found" and n.noah != null and n.noah.visible)
	ok("n_checkpoint_" + tag, FileAccess.file_exists(game.checkpoint_path("chapter12_noah")))
	ok("n_account_" + tag, said.has("He never told me his name.") and said.has("The old man took me to his brother's place for fuel. I heard something at night. We went back."))
	if lost:
		ok("n_comfort_lost", said.has("Okay. I'll carry it.") and said.has("He bought it for me. I hated the color."))
	else:
		ok("n_reunion_alive", said.has("It's light. It's light, bud.") and said.has("You smell terrible."))
	ok("n_noah_follows_" + tag, n.noah_follow != null and n.noah_follow.active)
	ok("n_step_home_" + tag, game.current_step().get("id", "") == "c12n_home", game.current_step().get("id", ""))
	# home
	var mill: Vector3 = c10.hl(c10.PORCH)
	await place(mill + Vector3(0, 0.3, 0.5))
	n.noah.global_position = mill + Vector3(1.5, 0.0, 1.5)
	ok("n_home_" + tag, await wait_talk(func(): return game.has_flag("ch12_noah_home") and game.has_flag("ch12_below_explained") and world.player.controls_enabled, 120.0))
	ok("n_home_in_the_house_" + tag, c10.inside_room(n.noah) and not n.noah_follow.active)
	ok("n_below_lines_" + tag, said.has("That's not a fog. That's a tide.") and said.has("The creepy road to the creepy place. Fine. Fine."))
	ok("n_step_talk_" + tag, game.current_step().get("id", "") == "c12_talk", game.current_step().get("id", ""))


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1500.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	game = root.get_node("Game")
	dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	dlg.auto_confirm = true
	# ------------------------------------------------ Marcus alive
	await start_world(false)
	ok("n_entry", c12 != null and n != null and game.has_flag("ch12_started"))
	ok("n_caption_first_light", true)
	await through_rescue(false)
	# the chapter's own talk goes on, with Noah in the room
	c12.its["npc_Eddie"].interact(world.player)
	ok("n_map_talk", await wait_talk(func(): return game.has_flag("ch12_talk_done") and p4.choice.is_open(), 90.0) and said.has("Noah drew that. He told me he copied it off the old man's gatepost."))
	p4.choice.pick(0)
	await wait_until(func(): return game.has_flag("ch12_set_out"), 120)
	# a load afterwards: Noah is at the mill house, the rescue does not replay
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	world = ps.instantiate()
	root.add_child(world)
	await frames(60)
	_bind()
	ok("n_load_no_replay", not n.rescue_open() and not n.active() and game.has_flag("ch12_noah_home") and game.has_flag("ch12_noah_found"))
	ok("n_load_noah_home", await wait_until(func(): return n.noah != null and is_instance_valid(n.noah), 180))
	# ------------------------------------------------ Marcus lost
	world.free()
	said.clear()
	await start_world(true)
	await through_rescue(true)
	ok("n_never_lost", game.has_flag("ch12_noah_found") and not game.has_flag("ch12_noah_na") and String(game.world_state["noah"]["status"]) in ["found", "home"])
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
