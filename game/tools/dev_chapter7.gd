extends SceneTree
## DEVELOPER-ONLY Chapter 7 entry point (game/tools is excluded from exports).
##   godot --path . --script res://game/tools/dev_chapter7.gd
## Fabricates "Chapter 6 complete + slept" on top of the Chapter 6 dev state (Ruth and Sarah invited, voice
## investigated) and loads the world (overwrites user://veil_save.json).

const DEV6 := preload("res://game/tools/dev_chapter6.gd")


static func prepare(game: Node) -> void:
	DEV6.prepare(game)
	for o in game.objectives:
		if String(o["id"]).begins_with("c6_") and o["flag"] != "ch7_started":
			game.flags[o["flag"]] = true
	for f in ["ch6_started", "ch6_eddie_following", "ch6_ruth_sarah_heard", "ch6_ruth_sarah_choice_invite", "ch6_voice_heard",
			"ch6_voice_choice_investigate", "ch6_investigation_reached", "ch6_hound_encounter_started", "ch6_walk_said",
			"ch6_return_said", "chapter_6_complete", "ch6_rested"]:
		game.flags[f] = true
	game.world_state["ch6"] = {"eddie": "shelter", "ruth_sarah": "shelter", "ruth_sarah_choice": "invite", "voice_choice": "investigate"}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
