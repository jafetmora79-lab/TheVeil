extends SceneTree
## Records the REAL chapter 4 "ACCEPT" scene: the Skitter ambush at the supermarket's front doors (it leaps off the roof across the street, charges, slams into the shut doors,
## recoils and scuttles off). Same start as game/tests/accept_branch_test.gd. Needs a window; overwrites user://veil_save.json (like that test).
##   godot --path . --fixed-fps 24 --resolution 960x540 --script res://game/prototypes/monsters_meshy/skitter_door_record.gd -- frames <out_dir>
const DEV5 := preload("res://game/chapters/setups/dev_chapter5.gd")
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "frames" and i + 1 < a.size():
			out = a[i + 1]
	_go.call_deferred()


func _go() -> void:
	var game := root.get_node("Game")
	DEV5.prepare(game)
	for f in ["p4_threat_done", "p4_slept", "p4_night_banging", "p4_choice_wait", "p4_hound_charged", "c5_started"]:
		game.flags.erase(f)
	game.flags["p4_choice_noah"] = true
	game.world_state["day"] = "friday"
	game.player_state = {"in_vehicle": false, "pos": [31.5, 0.2, -33.0], "yaw": 0.0}
	game.save_game()
	game.load_game()
	game.load_requested = true
	change_scene_to_file("res://game/scenes/World.tscn")
	for i in 30:
		await process_frame
	var world: Node = current_scene
	var waited := 0
	while world.phase4 == null and waited < 600:
		await process_frame
		waited += 1
	var p4: Node = world.phase4
	var idx := 0
	var started := false
	var k := 0
	var after := 0
	while k < 4000:
		await process_frame
		k += 1
		if p4.charge_report.get("spawned", false):
			started = true
		if started and k % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/sk_%03d.png" % [out, idx])
			idx += 1
		if game.has_flag("p4_threat_done"):
			after += 1
			if after > 36:
				break
	print("RECORD frames ", idx, " report ", p4.charge_report.get("start", "?"))
	quit()
