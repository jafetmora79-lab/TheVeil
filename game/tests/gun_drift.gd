extends SceneTree
## dev tool: does the player drift while the gun is out?  (needs a window)
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	world.player.controls_enabled = true
	world.hud.fade_to(0.0, 0.01)
	var sa = world.sidearm
	await frames(60)
	var p0: Vector3 = world.player.global_position
	await frames(120)
	print("DRIFT no gun: ", world.player.global_position - p0, " vel ", world.player.velocity)
	game.add_item("handgun")
	await frames(10)
	sa.set_drawn(true)
	var p1: Vector3 = world.player.global_position
	for i in 6:
		await frames(60)
		print("DRIFT gun t=", i + 1, " pos ", world.player.global_position - p1, " vel ", world.player.velocity, " on_floor ", world.player.is_on_floor(), " wall ", sa._wall)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	Input.parse_input_event(e)
	for i in 4:
		await frames(60)
		sa.fire()
		print("DRIFT aim+fire t=", i + 1, " pos ", world.player.global_position - p1, " vel ", world.player.velocity, " fov ", world.player.camera.fov)
	quit(0)
