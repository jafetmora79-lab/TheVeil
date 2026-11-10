extends SceneTree
## DEVELOPER-ONLY entry point for displayed CHAPTER 14 "Into the Veil" (chapter13.gd; game/tools is excluded from
## exports).   godot --path . --script res://game/chapters/setups/dev_chapter13.gd
## Fabricates "The Truth Beneath Greyhaven complete" on top of its dev state: the group at the mill-worker house,
## the records and the map recovered, the supplies left (or taken with took_supplies = true), Marcus alive (or lost
## with marcus_lost = true). Overwrites user://veil_save.json (dev only; checkpoints use separate files).

const DEV12 := preload("res://game/chapters/setups/dev_chapter12.gd")


static func prepare(game: Node, marcus_lost := false, took_supplies := false) -> void:
	DEV12.prepare(game, marcus_lost)
	for o in game.objectives:
		if String(o["id"]).begins_with("c12_") and o["flag"] != "ch13_started":
			game.flags[o["flag"]] = true
	for f in ["ch12_started", "chapter_card_13", "ch12_fog_talk", "ch12_low_locker", "ch12_chase_started", "chapter_12_complete",
			"ch12_supplies_taken" if took_supplies else "ch12_left_now"]:
		game.flags[f] = true
	for item in ["utility_map", "maintenance_log", "underground_records"]:
		if not item in game.inventory:
			game.inventory.append(item)
	var roster := ["Eddie", "Ruth", "Sarah"] if marcus_lost else ["Eddie", "Ruth", "Sarah", "Marcus"]
	game.world_state["ch12"] = {"roster": roster, "companion": "Eddie", "expedition": "story", "clues": {}, "supplies": "taken" if took_supplies else "left",
		"completed": {"roster": roster, "records": true, "supplies": "taken" if took_supplies else "left"}}
	game.player_state = {"in_vehicle": false, "pos": [-92.0, 0.9, 19.5], "yaw": PI, "health": 100.0}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
