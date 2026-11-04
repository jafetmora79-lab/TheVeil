extends SceneTree
## DEVELOPER-ONLY Chapter 6 entry point (game/tools is excluded from exports).
##   godot --path . --script res://game/tools/dev_chapter6.gd
## Fabricates "Chapter 5 complete + slept" on top of the Chapter 5 dev state and loads the world (overwrites
## user://veil_save.json). Use a real playthrough for real saves.

const DEV5 := preload("res://game/tools/dev_chapter5.gd")
const C5_FLAGS := ["c5_started", "c5_eddie_talked", "c5_marcus_talked", "c5_talked_both", "c5_supplies_checked", "c5_prepared",
	"c5_house_reached", "c5_got_food", "c5_got_batteries", "c5_got_medical", "c5_supplies_done", "c5_found_said", "c5_street_said",
	"c5_radio_used", "c5_radio_done", "c5_return_said", "c5_survivor_left", "c5_returned", "c5_reported", "c5_complete", "c5_rested"]


static func prepare(game: Node) -> void:
	DEV5.prepare(game)
	for f in C5_FLAGS:
		game.flags[f] = true
	game.world_state["c5"] = {"eddie": "shelter", "survivor": "house"}
	for i in ["canned_food", "painkillers"]:
		if not i in game.inventory:
			game.inventory.append(i)
	game.world_state["flashlight"] = {"charge": 0.9, "spares": 3, "on": false}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
