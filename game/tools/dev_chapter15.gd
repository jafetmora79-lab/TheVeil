extends SceneTree
## DEVELOPER-ONLY entry point for displayed CHAPTER 16 "What Remains" (chapter15.gd; game/tools is excluded from
## exports).   godot --path . --script res://game/tools/dev_chapter15.gd
## Fabricates "The Last Shelter complete" on top of its dev state: the group in the field after the shelter fell,
## Sarah saved at the door; at the fence the player went back for Marcus - or left him (left_marcus = true); Marcus
## alive (or lost in Chapter 10 with marcus_lost = true). Overwrites user://veil_save.json (dev only).

const DEV14 := preload("res://game/tools/dev_chapter14.gd")


static func prepare(game: Node, marcus_lost := false, left_marcus := false) -> void:
	DEV14.prepare(game, marcus_lost)
	for o in game.objectives:
		if String(o["id"]).begins_with("c14_") and o["flag"] != "ch15_started":
			game.flags[o["flag"]] = true
	for f in ["ch14_started", "chapter_card_15", "ch14_window_seen", "ch14_meeting_done", "ch14_supplies_checked", "ch14_escape_ready", "ch14_prepared",
			"ch14_siege_started", "ch14_skitters_done", "ch14_rescue_saved", "ch14_hounds_done", "ch14_crab_seen", "ch14_evac_started", "ch14_separation",
			"ch14_separation_made", "ch14_safe", "chapter_14_complete"]:
		game.flags[f] = true
	var sep := "" if marcus_lost else ("left" if left_marcus else "went_back")
	var missing := ["Marcus"] if left_marcus and not marcus_lost else []
	if left_marcus and not marcus_lost:
		game.flags["ch14_marcus_missing"] = true
	var roster := ["Eddie", "Ruth", "Sarah"] if marcus_lost or left_marcus else ["Eddie", "Ruth", "Sarah", "Marcus"]
	game.world_state["ch14"] = {"roster": roster, "defenses": {"front": true, "window": true}, "escape": "on_foot", "provisions": "short", "rescue": "saved",
		"rescue_target": "Sarah", "separated": "" if marcus_lost else "Marcus", "separation": sep, "missing": missing, "talked": {}, "run": "",
		"window": "held", "completed": {"roster": roster, "missing": missing, "rescue": "saved", "separation": sep}}
	game.player_state = {"in_vehicle": false, "pos": [-102.0, 0.3, 56.0], "yaw": PI, "health": 100.0}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
