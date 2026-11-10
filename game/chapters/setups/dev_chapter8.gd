extends SceneTree
## DEVELOPER-ONLY Chapter 8 entry point (game/tools is excluded from exports).
##   godot --path . --script res://game/chapters/setups/dev_chapter8.gd
## Fabricates "Chapter 7 complete + slept" on top of the Chapter 7 dev state (Ruth and Sarah invited, the backpack
## and the note found, Marcus trusted) and loads the world (overwrites user://veil_save.json).

const DEV7 := preload("res://game/chapters/setups/dev_chapter7.gd")


static func prepare(game: Node, painkillers := true) -> void:
	DEV7.prepare(game)
	for o in game.objectives:
		if String(o["id"]).begins_with("c7_") and o["flag"] != "ch8_started":
			game.flags[o["flag"]] = true
	for f in ["ch7_started", "ch7_walk_said", "ch7_road_reached", "ch7_note_read", "noah_clue_backpack", "marcus_trust_search",
			"chapter_7_complete", "ch7_rested"]:
		game.flags[f] = true
	game.world_state["ch7"] = {"marcus": "shelter", "marcus_choice": "trust"}
	for id in ["noahs_backpack", "noahs_note"]:
		if not id in game.inventory:
			game.inventory.append(id)
	if painkillers:
		if not "painkillers" in game.inventory:
			game.inventory.append("painkillers")
	else:
		game.inventory.erase("painkillers")
		var stock: Dictionary = game.world_state.get("shelter_stock", {"food": 0, "water": 0, "medical": 0, "batteries": 0})
		stock["medical"] = 0
		game.world_state["shelter_stock"] = stock
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
