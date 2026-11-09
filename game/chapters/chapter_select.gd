extends RefCounted
## THE VEIL - chapter select: start a new playthrough at the beginning of any chapter (1-16, the displayed numbers
## of game/data/chapters.json). Unlocked once the game has been finished (an ending recorded in
## user://veil_endings.json) or by user://veil_chapters.json {"all_chapters": true}.
##
## A chapter start is a complete "everything before this chapter is done" state, never a half-built one:
##   - every objective flag before the chapter's first step, the story flags the game sets on the way;
##   - what the player would carry by then (the car keys from Chapter 2 on: the car needs them; groceries and the
##     game once bought; flashlight, batteries, hammer... from the chapter set-ups);
##   - the car where the story left it: parked in the supermarket stall the auto-park uses (it stays there,
##     dead since the Veil, until the player repairs it - an optional side quest);
##   - the survivors where they belong (the world's own save restore puts them there; Chapters 2-5, which begin in
##     the middle of the opening, get the last placements from the world's chapter-start hook - see
##     world.gd _chapter_start_hook).
## Chapters 6-16 reuse the chapter set-ups the chapter tests are built on (game/tools/dev_chapterN.gd, N = n - 1).
## Starting a chapter replaces the save slot, as New Game does.

const UNLOCK_PATH := "user://veil_chapters.json"
const ENDINGS_PATH := "user://veil_endings.json"
const COUNT := 16
## the car at rest in the auto-park stall in front of the supermarket (world.gd: PARK_STALL_X -3.7, PARK_FINAL_Z
## 16.6 in the lot module's frame), backed in: its nose (its -Z) to the aisle
const CAR_PARKED := {"pos": [34.7, 0.3, -22.6], "yaw": PI, "fuel": 1.0, "condition": 1.0}
## the first objective of Chapters 2-5 (everything before it is done)
const FIRST_STEP := {2: "buy_groceries", 3: "go_home", 4: "mist_market", 5: "p4_flashlight"}
const EXTRA_FLAGS := {
	2: ["arrival_shot", "auto_parked"],
	3: ["arrival_shot", "auto_parked"],
	4: ["arrival_shot", "auto_parked", "phase2_done", "p3_mist", "p3_market_doors_dead", "p3_two_hours_later"],
	5: ["arrival_shot", "auto_parked", "phase2_done", "p3_mist", "p3_market_doors_dead", "p3_two_hours_later",
		"p3_fled_together"],
}


static func unlocked() -> bool:
	var u := _read(UNLOCK_PATH)
	if u.get("all_chapters", false):
		return true
	return not (_read(ENDINGS_PATH).get("endings", []) as Array).is_empty()


static func unlock_all() -> void:
	var f := FileAccess.open(UNLOCK_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"all_chapters": true}, " "))
		f.close()


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## Build the state for chapter `n` in Game (and write it to the save slot). The world then loads from it.
static func prepare(game: Node, n: int) -> void:
	n = clampi(n, 1, COUNT)
	var who := String(game.get("player_name"))
	if n == 1:
		game.new_game(who)                                   # the whole opening, the intro first
		game.load_requested = false
		return
	if n >= 6:
		load("res://game/tools/dev_chapter%d.gd" % (n - 1)).prepare(game)
	else:
		game.new_game(who)
		for o in game.objectives:
			if String(o["id"]) == FIRST_STEP[n]:
				break
			game.flags[o["flag"]] = true
		for f in EXTRA_FLAGS[n]:
			game.flags[f] = true
		var inv: Array = []
		if n >= 3:
			inv = ["groceries", "horror_game"]
		game.inventory = inv
		game.player_state = {"in_vehicle": false, "pos": [34.7, 0.3, -18.5], "yaw": 0.0, "health": 100.0}   # placed by the hook
	game.player_name = who
	game.flags["intro_seen"] = true
	if not game.has_item("car_keys"):
		game.inventory.append("car_keys")                    # the car needs them; nothing in the story takes them away
	if (game.vehicle_state as Dictionary).get("pos", []).is_empty():
		game.vehicle_state = CAR_PARKED.duplicate(true)
	game.world_state["chapter_start"] = n
	game.save_game()
	game.load_game()
	game.load_requested = true


## From a menu: the state, then the world.
static func start(tree: SceneTree, n: int) -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	prepare(tree.root.get_node("Game"), n)
	tree.change_scene_to_file("res://game/scenes/World.tscn")
