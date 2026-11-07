extends SceneTree
## DEVELOPER-ONLY entry point for displayed CHAPTER 13 "The Truth Beneath Greyhaven" (chapter12.gd; game/tools is
## excluded from exports).   godot --path . --script res://game/tools/dev_chapter12.gd
## Fabricates "The Farm Road complete" on top of its dev state: the group in the field below the farmhouses after
## the escape, both of Noah's notes found and read, Marcus alive (or lost with marcus_lost = true). Overwrites
## user://veil_save.json (dev only; the game's own chapter checkpoints use separate files).

const DEV11 := preload("res://game/tools/dev_chapter11.gd")


static func prepare(game: Node, marcus_lost := false) -> void:
	DEV11.prepare(game, marcus_lost)
	for o in game.objectives:
		if String(o["id"]).begins_with("c11_") and o["flag"] != "ch12_started":
			game.flags[o["flag"]] = true
	for f in ["ch11_started", "chapter_card_12", "ch11_campsite_reached", "ch11_skitter_seen", "ch11_note_found", "ch11_note_read",
			"noah_clue_campsite", "ch11_field_seen", "ch11_farmhouse_reached", "ch11_group_waiting", "ch11_message_found",
			"ch11_message_read", "noah_clue_farmhouse", "ch11_search_done", "ch11_regrouped", "ch11_attack_started", "ch11_escaped",
			"ch11_light_seen", "chapter_11_complete"]:
		game.flags[f] = true
	for item in ["campsite_note", "noahs_message"]:
		if not item in game.inventory:
			game.inventory.append(item)
	var roster := ["Eddie", "Ruth", "Sarah"] if marcus_lost else ["Eddie", "Ruth", "Sarah", "Marcus"]
	game.world_state["ch11"] = {"roster": roster, "searched": {"living": true, "kitchen": true, "bedroom": true, "rear": true},
		"completed": {"roster": roster, "clues": ["noah_clue_campsite", "noah_clue_farmhouse"]}}
	game.player_state = {"in_vehicle": false, "pos": [-104.0, 0.3, -99.0], "yaw": 0.0, "health": 100.0}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
