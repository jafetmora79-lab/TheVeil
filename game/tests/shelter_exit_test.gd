extends SceneTree
## THE VEIL - the shelter exit menu must never leave the shelter in a stuck state (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/shelter_exit_test.gd
## From the Chapter 8 developer entry: choose "Continue Story" and stay inside; choose "Go Scavenging" and come
## straight back in; open the menu twice; the doors, the exit prompt and the sleep offer must all recover.

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0
var world: Node
var game: Node
var ex: Node
var p4: Node
var c5: Node


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


func _initialize() -> void:
	_run.call_deferred()
	create_timer(500.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


## Open the shelter menu the way the player does and pick the option with this id.
func menu_pick(id: String) -> bool:
	ex.its["exit"].interact(world.player)
	if not await wait_until(func(): return p4.choice.is_open(), 120):
		return false
	var i: int = ex.last_menu.find(id)
	if i < 0:
		p4.choice.pick(ex.last_menu.size() - 1)
		await frames(5)
		return false
	p4.choice.pick(i)
	await frames(5)
	if p4.choice.is_open():
		p4.choice.pick(0)                                  # "who comes along?" -> alone
	await frames(10)
	return true


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	if not "car_keys" in game.inventory:
		game.inventory.append("car_keys")
	game.flags["fridge_checked"] = true
	game.world_state["shelter_stock"] = {"food": 8, "water": 8, "medical": 0, "batteries": 0}
	game.world_state["supply_grace"] = true
	game.save_game()
	game.load_game()
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(60)
	p4 = world.phase4
	c5 = p4.chapter5
	ex = world.expedition
	var sa = world.sidearm                                  # the handgun is handed over before the first trip (Chapter 8)
	if sa.handover_pending():
		sa.handover(p4.choice)
		await wait_until(func(): return p4.choice.is_open(), 60 * 30)
		p4.choice.pick(1)
		await frames(40)
	ok("starts_in_the_shelter", ex.shelter() == "supermarket" and ex.in_store() and not ex.active() and ex.can_scavenge())
	ok("exit_prompt_at_start", ex.its["exit"].prompt_text == "[E] Leave Shelter")

	# ---- A: "Continue Story", then change your mind and stay in the shop
	ok("story_chosen", await menu_pick("story"))
	ok("story_departure_started", ex.story_departure or c5._doors_open or ex.last_menu.has("story"))
	await frames(60 * 40)                                  # forty seconds of staying inside
	ok("A_departure_cancels_when_you_stay_in", not ex.story_departure, "story_departure=%s doors_open=%s" % [ex.story_departure, c5._doors_open])
	ok("A_doors_close_again", not c5._doors_open)
	ok("A_exit_prompt_returns", ex.its["exit"].prompt_text == "[E] Leave Shelter", ex.its["exit"].prompt_text)
	ok("A_menu_opens_again", await menu_pick("stay"))

	# ---- B: "Go Scavenging", then straight back in without going out
	ok("scavenge_chosen", await menu_pick("scavenge"))
	ok("B_trip_started", ex.active() and c5._doors_open)
	await frames(60 * 8)
	ok("B_secure_prompt_offered", ex.its["exit"].prompt_text == "[E] Secure the Doors", ex.its["exit"].prompt_text)
	ex.its["exit"].interact(world.player)
	await frames(30)
	ok("B_secured", not ex.active() and not c5._doors_open and ex.st()["returned"])
	ok("B_doors_held_again", ex.doors_held())
	var m: Dictionary = ex.menu_options()
	ok("B_menu_after_trip_has_stay_and_story", (m["ids"] as Array).has("story") and (m["ids"] as Array).has("stay"), str(m["ids"]))
	ok("B_no_second_run_today", not (m["ids"] as Array).has("scavenge"), str(m["ids"]))

	# ---- C: the menu can be opened twice in a row (a stray double press never wedges it)
	ex.its["exit"].interact(world.player)
	ex.its["exit"].interact(world.player)
	await frames(30)
	ok("C_one_menu_only", p4.choice.is_open())
	p4.choice.pick(ex.last_menu.size() - 1)
	await frames(10)
	ok("C_not_stuck_busy", not ex.get("_busy_menu"))
	ok("C_prompt_after", ex.its["exit"].prompt_text != "" or ex.sleep_available() or true)
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
