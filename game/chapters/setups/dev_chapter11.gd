extends SceneTree
## DEVELOPER-ONLY entry point for displayed CHAPTER 12 "The Farm Road" (chapter11.gd; game/tools is excluded from
## exports).   godot --path . --script res://game/chapters/setups/dev_chapter11.gd
## Fabricates "No Safe Road complete" on top of its dev state: the group in the mill-worker house after the rest,
## Sarah helped on the road, Marcus alive (or lost with marcus_lost = true). Overwrites user://veil_save.json
## (dev only; the game's own chapter checkpoints use separate files).

const DEV10 := preload("res://game/chapters/setups/dev_chapter10.gd")


static func prepare(game: Node, marcus_lost := false) -> void:
	DEV10.prepare(game, marcus_lost)
	for o in game.objectives:
		if String(o["id"]).begins_with("c10_") and o["flag"] != "ch11_started":
			game.flags[o["flag"]] = true
	for f in ["ch10_started", "chapter_card_11", "ch10_car_door", "ch10_car_fuel", "ch10_car_glove", "ch10_car_trunk", "ch10_creature_seen",
			"ch10_choice_help", "ch10_sarah_rested", "ch10_entrance_checked", "ch10_refuge_rested", "chapter_10_complete"]:
		game.flags[f] = true
	var roster := ["Eddie", "Ruth", "Sarah"] if marcus_lost else ["Eddie", "Ruth", "Sarah", "Marcus"]
	game.world_state["ch10"] = {"roster": roster, "sarah": "rested", "choice": "help", "help_cost": "water_bottle"}
	game.inventory.erase("water_bottle")
	game.world_state["ch10/MILL_HOUSE/INT_Door_Front"] = {"open": true}      # No Safe Road opened it
	# inside the mill-worker house (-92, 14): the living room
	game.player_state = {"in_vehicle": false, "pos": [-92.0, 0.9, 19.5], "yaw": PI, "health": 100.0}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
