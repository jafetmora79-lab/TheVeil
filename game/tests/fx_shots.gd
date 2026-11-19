extends SceneTree
## dev tool: the same view with the film look off and on (needs a window)
##   godot --path . --script res://game/tests/fx_shots.gd -- <out_dir>
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var game := root.get_node("Game")
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	world.player.controls_enabled = true
	world.hud.fade_to(0.0, 0.01)
	world.player.set_yaw_pitch(world.player.rotation.y + 2.4, -0.05)
	await frames(40)
	for on in [false, true]:
		game.settings["film_look"] = on
		world.screen_fx._apply_setting()
		await frames(8)
		root.get_texture().get_image().save_png("%s/fx_%s.png" % [out, "on" if on else "off"])
	quit(0)
