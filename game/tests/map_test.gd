extends SceneTree
## THE VEIL - the town map (Part 9): Eddie hands it over once; a house selected as the search destination (its
## own marker, the story's untouched); X at a house with no way in; a check after a supply is taken inside; the
## revisit hint once; "supplies may have returned" only after a real refill; saved (headless).
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0
var game: Node
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func boot() -> void:
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(90)


## A point in the middle of a house's first ground-floor room (world).
func room_centre(nav, z: String) -> Vector3:
	var h: Node3D = nav.houses[z]["node"]
	for rm in h.get_meta("veil_house", {}).get("rooms", []):
		if int(rm.get("level", 0)) == 0:
			var rc: Array = rm["rect"]
			return h.global_transform * Vector3((rc[0] + rc[2]) * 0.5, float(rm.get("floor_y", 0.6)) + 0.2, (rc[1] + rc[3]) * 0.5)
	return h.global_position


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	var dlg = root.get_node("Dialogue")
	dlg.auto_confirm = true
	var said: Array = []
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	DEV.prepare(game)
	game.flags.erase("map_acquired")
	game.world_state["shelter_nights"] = {}
	await boot()
	var nav = w.nav
	ok("map_collected", nav.houses.size() >= 60 and nav._roads.size() > 20, "%d houses, %d road pieces" % [nav.houses.size(), nav._roads.size()])
	# Eddie, in the store, in a quiet moment
	var p = w.player
	p.controls_enabled = true
	p.global_position = w.eddie.global_position + Vector3(1.2, 0.2, 0.0)
	for i in 60 * 70:
		if game.has_flag("map_acquired"):
			break
		await process_frame
	ok("eddie_gives_map", game.has_flag("map_acquired") and said.has("Map of Greyhaven. Old one, but the streets haven't moved. Probably."))
	var n_lines := said.size()
	await frames(60 * 20)
	ok("map_given_once", said.size() == n_lines)
	# select a house, mark it: its own marker, the story marker untouched
	await frames(30)
	var story_name: String = w.hud._mk_name
	nav.selected = "HOUSE_15"
	nav._toggle_dest()
	await frames(10)
	ok("destination_set", String(game.world_state.get("map_dest", "")) == "HOUSE_15" and nav.dest_point() != null and w.hud._mk_name == story_name)
	# a house the game does not open: at its front door -> X
	var closed := ""
	for z in nav.houses:
		if not nav.accessible(z) and String(z).begins_with("HOUSE_"):
			closed = z
			break
	var door: Vector3 = nav.houses[closed]["door"]
	p.global_position = door + Vector3(0, 0.3, 0)
	await frames(30)
	ok("no_way_in_x", nav.status(closed) == "no_way_in", closed)
	# into the explorable house: take its food -> check, the hint once
	var h = w.expedition.houses["HOUSE_15"]
	p.global_position = room_centre(nav, "HOUSE_15")
	await frames(30)
	ok("destination_reached_clears", not game.world_state.has("map_dest") and nav.status("HOUSE_15") == "visited")
	var food: Interactable = h.loot["canned_food_0"]
	h._loot_container["canned_food_0"].interact(p)
	await frames(40)
	food.interact(p)
	await frames(10)
	ok("looted_check", nav.status("HOUSE_15") == "looted" and game.has_flag("map_first_loot"))
	ok("revisit_hint_once", w.hud.hint.text.begins_with("Marked on your map"))
	# leave; another house entered with nothing taken -> searched, nothing found (not a check)
	p.global_position = room_centre(nav, "HOUSE_06")
	await frames(20)
	p.global_position = door + Vector3(0, 0.3, 4.0)
	await frames(20)
	ok("entered_nothing_found", nav.status("HOUSE_06") == "empty")
	ok("no_returned_same_day", not nav.returned("HOUSE_15"))
	# a new day: the house's real refill -> supplies may have returned
	var nights: Dictionary = game.world_state["shelter_nights"]
	nights["test_day_1"] = {}
	await frames(10)
	ok("returned_after_refill", nav.returned("HOUSE_15"))
	# save / load
	nav.selected = "HOUSE_22"
	nav._toggle_dest()
	w.save()
	w.free()
	game.load_game()
	game.load_requested = true
	await boot()
	nav = w.nav
	await frames(10)
	ok("saved_states", game.has_flag("map_acquired") and nav.status("HOUSE_15") == "looted" and nav.status(closed) == "no_way_in"
		and nav.status("HOUSE_06") == "empty" and String(game.world_state.get("map_dest", "")) == "HOUSE_22")
	# the map opens (M) and closes
	w.player.controls_enabled = true
	nav.show_map()
	await frames(5)
	ok("map_opens", nav.open and nav.panel.visible)
	nav.close()
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
