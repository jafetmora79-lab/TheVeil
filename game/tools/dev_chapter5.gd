extends SceneTree
## DEVELOPER-ONLY Chapter 5 entry point (game/tools is excluded from exports).
## Starts the game at the Chapter 5 morning without playing Chapters 1-4:
##   godot --path . --script res://game/tools/dev_chapter5.gd
## It fabricates a "Chapter 4 finished" state (every objective flag before Chapter 5, the Act I story flags,
## flashlight + batteries, the player on the office bedroll) and loads the world from it. Use a normal
## playthrough for real saves; this overwrites user://veil_save.json.

const PRE_FLAGS := ["phase2_done", "groceries_done", "game_bought", "p3_mist", "p3_stepped_out", "p3_back_inside",
	"p3_in_shop", "p3_in_market", "p3_doors_shut", "p4_started", "p4_flashlight", "p4_breaker", "p4_loading_down",
	"p4_loading_secured", "p4_backexit_closed", "p4_backexit_secured", "p4_exits_secured", "p4_choice_made",
	"p4_choice_wait", "p4_talk_done", "p4_threat_done", "p4_slept"]


static func prepare(game: Node) -> void:
	game.new_game()
	for o in game.objectives:
		if String(o["id"]).begins_with("c5_"):
			break
		game.flags[o["flag"]] = true
	for f in PRE_FLAGS:
		game.flags[f] = true
	game.inventory = ["groceries", "horror_game", "flashlight", "batteries"]
	game.world_state["flashlight"] = {"charge": 0.8, "spares": 1, "on": false}
	game.world_state["day"] = "saturday"
	# office bedroll (supermarket-local (-17.6, 0.9, 15.75); the store sits at (33, 0.15, -27) turned 180 degrees)
	game.player_state = {"in_vehicle": false, "pos": [50.6, 1.05, -42.75], "yaw": PI * 0.5}
	game.save_game()
	game.load_game()
	game.load_requested = true


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	prepare(root.get_node("Game"))
	change_scene_to_file("res://game/scenes/World.tscn")
