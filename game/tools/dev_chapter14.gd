extends SceneTree
## DEVELOPER-ONLY entry point for displayed CHAPTER 15 "The Last Shelter" (chapter14.gd; game/tools is excluded from
## exports).   godot --path . --script res://game/tools/dev_chapter14.gd
## Fabricates "Into the Veil complete" on top of its dev state: back at the mill-worker house, Eddie went along and the
## evidence was secured (Eddie injured, trust down) - or he was helped (choice = "help"); Marcus alive (or lost with
## marcus_lost = true). Overwrites user://veil_save.json (dev only; checkpoints use separate files).

const DEV13 := preload("res://game/tools/dev_chapter13.gd")


static func prepare(game: Node, marcus_lost := false, choice := "evidence") -> void:
	DEV13.prepare(game, marcus_lost)
	for o in game.objectives:
		if String(o["id"]).begins_with("c13_") and o["flag"] != "ch14_started":
			game.flags[o["flag"]] = true
	for f in ["ch13_started", "chapter_card_14", "ch13_sign1", "ch13_sign_again", "ch13_street_seen", "ch13_crank_found", "ch13_crab_seen",
			"ch13_voice_heard", "ch13_winch_turned", "ch13_beam_moved", "ch13_collapsed", "ch13_mist_warned", "chapter_13_complete",
			"ch13_choice_evidence" if choice == "evidence" else "ch13_choice_help"]:
		game.flags[f] = true
	if choice == "evidence" and not "ancient_rubbing" in game.inventory:
		game.inventory.append("ancient_rubbing")
	if not "checkpoint_note" in game.inventory:
		game.inventory.append("checkpoint_note")
	var roster := ["Eddie", "Ruth", "Sarah"] if marcus_lost else ["Eddie", "Ruth", "Sarah", "Marcus"]
	game.world_state["ch13"] = {"roster": roster, "companion": "Eddie", "expedition": "story", "exposure": 0.0, "choice": choice, "clues": {},
		"completed": {"roster": roster, "companion": "Eddie", "choice": choice, "evidence": choice == "evidence"}}
	var sv: Dictionary = game.world_state.get("survivors", {})
	if not sv.is_empty() and choice == "evidence":
		sv["health"]["Eddie"] = "injured"
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
