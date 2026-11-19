extends SceneTree
## DEVELOPER-ONLY entry point for displayed CHAPTER 10 "The Fall of the Supermarket" (chapter9.gd; game/tools is
## excluded from exports).   godot --path . --script res://game/chapters/setups/dev_chapter9.gd
## Fabricates "the previous chapter (Something at the Doors) complete + slept" on top of its dev state: Sarah
## treated, the barricade broken, partial power; Marcus's trust from p4_choice_noah + marcus_trust_search (2) unless
## `trust` says otherwise. Overwrites user://veil_save.json.

const DEV8 := preload("res://game/chapters/setups/dev_chapter8.gd")


static func prepare(game: Node, trust := 2, stock := {"food": 3, "water": 1, "medical": 2, "batteries": 0}) -> void:
	DEV8.prepare(game)
	for o in game.objectives:
		if String(o["id"]).begins_with("c8_") and o["flag"] != "ch9_started":
			game.flags[o["flag"]] = true
	for f in ["ch8_started", "ch8_eddie_talked", "ch8_got_boards", "ch8_got_tape", "ch8_got_hammer", "ch8_power_failed",
			"ch8_panel_inspected", "ch8_temp_survivor_died", "ch8_sarah_injured", "ch8_sarah_treated", "ch8_medical_used",
			"shelter_evacuation_concern", "chapter_8_complete", "ch8_rested"]:
		game.flags[f] = true
	game.flags.erase("p4_choice_noah")
	game.flags.erase("p4_choice_wait")
	game.flags.erase("marcus_trust_search")
	game.flags.erase("marcus_cautious_search")
	game.flags["p4_choice_noah" if trust >= 1 else "p4_choice_wait"] = true
	game.flags["marcus_trust_search" if trust >= 2 else "marcus_cautious_search"] = true
	game.world_state["ch8"] = {"barricade": "broken", "power": "partial", "injured": "sarah", "injured_condition": "stable",
		"ruth_sarah_arrived": false, "casualty": "temporary_survivor"}
	for k in ["repair_boards", "duct_tape", "painkillers"]:
		game.inventory.erase(k)
	if not "hammer" in game.inventory:
		game.inventory.append("hammer")
	game.world_state["shelter_stock"] = stock.duplicate()
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
