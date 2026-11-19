extends SceneTree
## dev tool: the interactable rim, the hold ring and the sliding choice highlight (needs a window)
##   godot --path . --script res://game/tests/ui_shots.gd -- <out_dir>
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var out := ""


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(2)
	root.get_texture().get_image().save_png("%s/ui_%s.png" % [out, name])


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	world.player.controls_enabled = true
	world.hud.fade_to(0.0, 0.01)
	var best: Interactable = null
	var bd := 1e9
	for d in world.get_tree().get_nodes_in_group("veil_door"):
		var dd: float = (d as Node3D).global_position.distance_to(world.player.global_position)
		if dd < bd and dd > 0.5:
			bd = dd
			best = d
	print("door ", best, " dist ", bd)
	if best:
		var p: Vector3 = best.focus_point()
		var from: Vector3 = world.player.global_position
		var dir := (p - from) * Vector3(1, 0, 1)
		world.player.set_yaw_pitch(atan2(-dir.x, -dir.z), 0.0)
		world.player.global_position = p - dir.normalized() * 1.4 + Vector3(0, 0.05, 0)
		await frames(40)
		await shot("rim")
	world.hud.set_hold(0.6)
	await shot("hold")
	world.hud.set_hold(0.0)
	var panel := root.get_tree().get_first_node_in_group("veil_choice_panel")
	if panel:
		panel.ask("Which way?", ["Go through the door", "Wait here", "Turn back"], world.player)
		await frames(20)
		var btns := []
		for c in panel._box.get_children():
			if c is Button:
				btns.append(c)
		await shot("choice_first")
		(btns[2] as Button).grab_focus()
		await frames(3)
		await shot("choice_sliding")
		await frames(30)
		await shot("choice_settled")
		panel.pick(0)
	quit(0)
