extends SceneTree
## DEVELOPER-ONLY entry point for displayed CHAPTER 11 "No Safe Road" (chapter10.gd; game/tools is excluded from
## exports).   godot --path . --script res://game/chapters/setups/dev_chapter10.gd
## Fabricates "The Fall of the Supermarket complete" on top of its dev state: the group at the rendezvous (Ruth and
## Sarah's yard), the supplies carried out of the store, Marcus saved (or lost with marcus_lost = true).
## Overwrites user://veil_save.json (dev only; the game's own chapter checkpoints use separate files).

const DEV9 := preload("res://game/chapters/setups/dev_chapter9.gd")


static func prepare(game: Node, marcus_lost := false, sarah := "stable") -> void:
	DEV9.prepare(game)
	for o in game.objectives:
		if String(o["id"]).begins_with("c9_") and o["flag"] != "ch10_started":
			game.flags[o["flag"]] = true
	for f in ["ch9_started", "ch9_medical_done", "ch9_food_done", "ch9_light_checked", "ch9_warning_started", "ch9_lookback_done",
			"ch9_supermarket_lost", "shelter_compromised", "supermarket_evacuated", "next_destination_farms", "chapter_9_complete",
			"chapter_card_10"]:
		game.flags[f] = true
	game.flags["ch9_marcus_lost" if marcus_lost else "ch9_marcus_saved"] = true
	var roster := ["Eddie", "Ruth", "Sarah"] if marcus_lost else ["Eddie", "Ruth", "Sarah", "Marcus"]
	game.world_state["ch9"] = {"talked": {"Eddie": true, "Ruth": true, "Sarah": true}, "medical_taken": 2, "food_taken": 2, "water_taken": 1,
		"marcus_trust": 2, "marcus_outcome": "lost" if marcus_lost else "survived", "roster": roster, "next_destination": "farms",
		"abandoned_stock": {"food": 1, "water": 0, "medical": 0, "batteries": 0}}
	game.world_state["ch8"]["injured_condition"] = sarah
	game.world_state["shelter_stock"] = {"food": 0, "water": 0, "medical": 0, "batteries": 0}
	for id in ["painkillers", "canned_food", "water_bottle"]:
		while id in game.inventory:
			game.inventory.erase(id)
	for id in ["painkillers", "painkillers", "canned_food", "canned_food", "water_bottle"]:
		game.inventory.append(id)
	game.player_state = {"in_vehicle": false, "pos": [47.0, 0.3, -60.5], "yaw": 0.0, "health": 100.0}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
