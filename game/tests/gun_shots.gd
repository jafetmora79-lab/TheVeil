extends SceneTree
## dev tool: screenshots of the first-person handgun in several states (needs a window, not headless)
##   godot --path . --script res://game/tests/gun_shots.gd -- <out_dir> <tag>
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var out_dir := ""
var tag := ""


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(3)
	var img := root.get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [out_dir, tag, name])
	print("saved ", name)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[0]
	tag = a[1]
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	world.player.controls_enabled = true
	world.hud.fade_to(0.0, 0.01)
	var sa = world.sidearm
	game.add_item("handgun")
	await frames(10)
	sa.st()["reserve"] = 12
	sa.set_drawn(true)
	await frames(40)
	await shot("rest")
	# aimed: force the aim state through the same path the right mouse button uses
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	Input.parse_input_event(e)
	await frames(30)
	await shot("aimed")
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(30)
	sa.fire()
	await frames(2)
	await shot("kick")
	await frames(40)
	sa.reload()
	await frames(50)
	await shot("reload")
	await frames(120)
	sa.force_sprint = true
	await frames(40)
	await shot("sprint")
	quit(0)
